//
//  InstallActivityController.swift
//  XSign
//
//  Drives the install progress Live Activity (Lock Screen + Dynamic Island).
//
//  Design notes:
//  - One controller per install sheet. Every method is called on the main
//    thread (SwiftUI onReceive / MainActor.run), so no locking is needed.
//  - Updates are throttled: a phase change is sent at once, progress at most
//    about once per second and only when it moved by 2% or more. The system
//    animates between updates, so the bar still looks smooth while the
//    device does very little work (ActivityKit also budgets updates).
//  - The last value is never lost: a single trailing update is scheduled
//    when an update is skipped by the throttle.
//  - Everything is a no-op on Mac Catalyst, below iOS 16.1, or when the
//    user turned Live Activities off for XSign.
//

import Foundation
import UIKit
import IDeviceSwift
import OSLog
#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(ActivityKit)
import ActivityKit
#endif

final class InstallActivityController {
	// MARK: Tuning
	
	/// Minimum time between two progress-only updates.
	private let _minInterval: TimeInterval = 1.0
	/// Minimum progress change for a progress-only update.
	private let _minDelta: Double = 0.02
	/// How long the finished activity stays on screen.
	private let _successLinger: TimeInterval = 4
	private let _failureLinger: TimeInterval = 8
	
	// MARK: State
	
	private var _activity: Any?
	private var _isStarting = false
	private var _isFinished = false
	private var _phase: InstallActivityPhaseValue = .packaging
	private var _progress: Double = 0
	private var _message: String?
	private var _sentPhase: InstallActivityPhaseValue?
	private var _sentProgress: Double = -1
	private var _lastSent: Date = .distantPast
	private var _trailingUpdate: DispatchWorkItem?
	
	// MARK: Public API
	
	/// Starts the Live Activity for `app`. Safe to call more than once.
	func start(app: AppInfoPresentable) {
		#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(ActivityKit)
		guard #available(iOS 16.1, *) else { return }
		guard _activity == nil, !_isStarting, !_isFinished else { return }
		guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
		_isStarting = true
		
		let name = app.name ?? "App"
		let version = app.version ?? ""
		let identifier = app.identifier ?? ""
		let bundleURL = Storage.shared.getAppDirectory(for: app)
		
		// The icon is rendered off the main thread, then the activity is
		// requested on the main thread with whatever state we reached.
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			let icon = bundleURL.flatMap { Self._thumbnail(for: $0) }
			DispatchQueue.main.async {
				guard let self else { return }
				self._isStarting = false
				guard !self._isFinished else { return }
				self._request(
					attributes: InstallActivityAttributes(
						appName: name,
						appVersion: version,
						bundleIdentifier: identifier,
						iconData: icon
					)
				)
			}
		}
		#endif
	}
	
	/// Feed every installer status change here.
	func update(status: InstallerStatusViewModel.InstallerStatus, progress: Double) {
		switch status {
		case .none:
			_set(phase: .packaging, progress: progress)
		case .ready:
			_set(phase: .waiting, progress: progress)
		case .sendingManifest, .sendingPayload:
			_set(phase: .sending, progress: progress)
		case .installing:
			_set(phase: .installing, progress: progress)
		case .completed(.success(_)):
			_finish(phase: .completed, message: nil)
		case .completed(.failure(let error)):
			_finish(phase: .failed, message: error.localizedDescription)
		case .broken(let error):
			_finish(phase: .failed, message: error.localizedDescription)
		}
	}
	
	/// Feed progress-only changes here (keeps the current phase).
	func update(progress: Double) {
		guard !_isFinished else { return }
		_set(phase: _phase, progress: progress)
	}
	
	/// Marks the install as failed (for errors that never reach the view model).
	func fail(_ error: Error) {
		_finish(phase: .failed, message: String(describing: error))
	}
	
	/// The install sheet closed. Ends a still running activity right away;
	/// a finished one keeps its short linger time.
	func sheetDidClose() {
		guard !_isFinished else { return }
		_isFinished = true
		_trailingUpdate?.cancel()
		_end(immediately: true)
	}
	
	/// Ends Live Activities left over from a previous run (for example when
	/// the app was killed during an install). Call once at launch.
	static func endStaleActivities() {
		#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(ActivityKit)
		guard #available(iOS 16.1, *) else { return }
		let stale = Activity<InstallActivityAttributes>.activities
		guard !stale.isEmpty else { return }
		Task {
			for activity in stale {
				if #available(iOS 16.2, *) {
					await activity.end(nil, dismissalPolicy: .immediate)
				} else {
					await activity.end(using: nil, dismissalPolicy: .immediate)
				}
			}
		}
		#endif
	}
	
	// MARK: Internals
	
	private func _set(phase: InstallActivityPhaseValue, progress: Double) {
		guard !_isFinished else { return }
		let clamped = min(1, max(0, progress.isFinite ? progress : 0))
		// Progress never moves backwards inside the same phase.
		_progress = (phase == _phase) ? max(_progress, clamped) : clamped
		_phase = phase
		_pushIfNeeded()
	}
	
	private func _finish(phase: InstallActivityPhaseValue, message: String?) {
		guard !_isFinished else { return }
		_isFinished = true
		_trailingUpdate?.cancel()
		_phase = phase
		if phase == .completed { _progress = 1 }
		_message = message.map { String($0.prefix(90)) }
		_end(immediately: false)
	}
	
	private func _pushIfNeeded() {
		guard _activity != nil else { return } // sent on request instead
		
		let phaseChanged = _sentPhase != _phase
		let delta = abs(_progress - _sentProgress)
		let elapsed = Date().timeIntervalSince(_lastSent)
		
		if phaseChanged || (delta >= _minDelta && elapsed >= _minInterval) {
			_trailingUpdate?.cancel()
			_trailingUpdate = nil
			_send()
		} else if delta > 0.004, _trailingUpdate == nil {
			// Coalesce: one delayed update carries the newest value.
			let item = DispatchWorkItem { [weak self] in
				guard let self, !self._isFinished else { return }
				self._trailingUpdate = nil
				self._send()
			}
			_trailingUpdate = item
			DispatchQueue.main.asyncAfter(
				deadline: .now() + max(0.1, _minInterval - elapsed),
				execute: item
			)
		}
	}
	
	private func _send() {
		#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(ActivityKit)
		guard #available(iOS 16.1, *) else { return }
		guard let activity = _activity as? Activity<InstallActivityAttributes> else { return }
		let state = _state()
		_sentPhase = _phase
		_sentProgress = state.progress
		_lastSent = Date()
		
		Task {
			if #available(iOS 16.2, *) {
				await activity.update(
					ActivityContent(state: state, staleDate: Date().addingTimeInterval(10 * 60))
				)
			} else {
				await activity.update(using: state)
			}
		}
		#endif
	}
	
	private func _end(immediately: Bool) {
		#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(ActivityKit)
		guard #available(iOS 16.1, *) else { return }
		guard let activity = _activity as? Activity<InstallActivityAttributes> else { return }
		_activity = nil
		let state = _state()
		let linger = (_phase == .completed) ? _successLinger : _failureLinger
		let policy: ActivityUIDismissalPolicy = immediately
			? .immediate
			: .after(Date().addingTimeInterval(linger))
		
		Task {
			if #available(iOS 16.2, *) {
				await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
			} else {
				await activity.end(using: state, dismissalPolicy: policy)
			}
		}
		#endif
	}
	
	#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(ActivityKit)
	@available(iOS 16.1, *)
	private func _state() -> InstallActivityAttributes.ContentState {
		InstallActivityAttributes.ContentState(
			phase: _phase,
			progress: (_progress * 100).rounded() / 100,
			message: _message
		)
	}
	
	@available(iOS 16.1, *)
	private func _request(attributes: InstallActivityAttributes) {
		// End leftovers first so only one install activity is ever visible.
		for old in Activity<InstallActivityAttributes>.activities {
			Task {
				if #available(iOS 16.2, *) {
					await old.end(nil, dismissalPolicy: .immediate)
				} else {
					await old.end(using: nil, dismissalPolicy: .immediate)
				}
			}
		}
		
		if let activity = _tryRequest(attributes) {
			_activity = activity
		} else if attributes.iconData != nil {
			// Most likely the payload was too large: retry without the icon.
			var fallback = attributes
			fallback.iconData = nil
			_activity = _tryRequest(fallback)
		}
		
		if _activity != nil {
			_sentPhase = _phase
			_sentProgress = _state().progress
			_lastSent = Date()
			// State may have moved while the icon was rendering.
			_pushIfNeeded()
		}
	}
	
	@available(iOS 16.1, *)
	private func _tryRequest(_ attributes: InstallActivityAttributes) -> Activity<InstallActivityAttributes>? {
		do {
			if #available(iOS 16.2, *) {
				return try Activity.request(
					attributes: attributes,
					content: ActivityContent(state: _state(), staleDate: Date().addingTimeInterval(10 * 60)),
					pushType: nil
				)
			} else {
				return try Activity.request(
					attributes: attributes,
					contentState: _state(),
					pushType: nil
				)
			}
		} catch {
			Logger.misc.error("Live Activity request failed: \(error.localizedDescription)")
			return nil
		}
	}
	#endif
	
	/// Renders a small, opaque JPEG of the app icon. Returns nil when the
	/// icon cannot be read or stays too large for the ActivityKit payload.
	private static func _thumbnail(for bundleURL: URL) -> Data? {
		guard let icon = iconTest(bundleURL) else { return nil }
		
		for (side, quality) in [(66.0, 0.72), (54.0, 0.62), (44.0, 0.55)] {
			let format = UIGraphicsImageRendererFormat()
			format.scale = 1
			format.opaque = true
			let size = CGSize(width: side, height: side)
			let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
				UIColor.white.setFill()
				context.fill(CGRect(origin: .zero, size: size))
				icon.draw(in: CGRect(origin: .zero, size: size))
			}
			if let data = image.jpegData(compressionQuality: quality), data.count <= 2_400 {
				return data
			}
		}
		return nil
	}
}

#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(ActivityKit)
typealias InstallActivityPhaseValue = InstallActivityPhase
#else
/// Mirror of `InstallActivityPhase` for platforms without ActivityKit.
enum InstallActivityPhaseValue {
	case packaging, waiting, sending, installing, completed, failed
}
#endif
