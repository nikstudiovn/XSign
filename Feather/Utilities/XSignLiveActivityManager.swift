//
//  XSignLiveActivityManager.swift
//  XSign
//
//  Quản lý Live Activity / Dynamic Island cho các mốc Đang ký → Đang gửi → Đang cài.
//  Một activity duy nhất được dùng xuyên suốt từ lúc ký tới lúc cài, progress luôn là
//  giá trị thực tế 0.0 → 1.0 của từng giai đoạn.
//

import Foundation
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

final class XSignLiveActivityManager {
	static let shared = XSignLiveActivityManager()
	
	enum Stage {
		case signing, sending, installing, completed, failed
	}
	
	private var _activity: Any?
	private var _appName: String?
	private var _lastStage: Stage?
	private var _lastProgress: Double = -1
	private var _lastUpdate: Date = .distantPast
	
	/// Tối thiểu giữa 2 lần cập nhật cùng giai đoạn (tránh bị hệ thống throttle).
	private let _minInterval: TimeInterval = 0.25
	
	// MARK: Live Activity
	func start(appName: String, stage: Stage = .signing, progress: Double = 0) {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
		
		// Ký xong chuyển sang cài cùng 1 app: giữ nguyên activity, chỉ cập nhật trạng thái.
		if _activity != nil, _appName == appName {
			update(stage: stage, progress: progress, force: true)
			return
		}
		
		// Kết thúc activity cũ (nếu có) trước khi tạo mới.
		_finishCurrent()
		
		let value = _clamp(progress)
		let attributes = XSignActivityAttributes(appName: appName)
		let state = XSignActivityAttributes.ContentState(stage: _map(stage), progress: value)
		do {
			_activity = try Activity.request(
				attributes: attributes,
				content: ActivityContent(state: state, staleDate: nil),
				pushType: nil
			)
			_appName = appName
			_lastStage = stage
			_lastProgress = value
			_lastUpdate = Date()
		} catch {
			_reset()
		}
		#endif
	}
	
	func update(stage: Stage, progress: Double, force: Bool = false) {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		guard let activity = _activity as? Activity<XSignActivityAttributes> else { return }
		
		if stage == .completed || stage == .failed {
			end(stage: stage)
			return
		}
		
		let value = _clamp(progress)
		let stageChanged = stage != _lastStage
		if !force && !stageChanged {
			if abs(value - _lastProgress) < 0.01 { return }
			if value < 1, Date().timeIntervalSince(_lastUpdate) < _minInterval { return }
		}
		
		_lastStage = stage
		_lastProgress = value
		_lastUpdate = Date()
		
		let state = XSignActivityAttributes.ContentState(stage: _map(stage), progress: value)
		Task {
			await activity.update(ActivityContent(state: state, staleDate: nil))
		}
		#endif
	}
	
	func end(stage: Stage) {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		guard let activity = _activity as? Activity<XSignActivityAttributes> else { return }
		let lastProgress = max(_lastProgress, 0)
		_reset()
		
		let state = XSignActivityAttributes.ContentState(
			stage: _map(stage),
			progress: stage == .completed ? 1.0 : lastProgress
		)
		Task {
			await activity.end(
				ActivityContent(state: state, staleDate: nil),
				dismissalPolicy: .after(Date().addingTimeInterval(8))
			)
		}
		#endif
	}
	
	/// Đóng activity ngay lập tức mà không đánh dấu thành công/thất bại
	/// (ví dụ người dùng tự đóng sheet cài đặt).
	func cancel() {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		_finishCurrent()
		#endif
	}
	
	private func _clamp(_ value: Double) -> Double {
		guard value.isFinite else { return 0 }
		return min(max(value, 0), 1)
	}
	
	private func _reset() {
		_activity = nil
		_appName = nil
		_lastStage = nil
		_lastProgress = -1
		_lastUpdate = .distantPast
	}
	
	#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
	@available(iOS 16.2, *)
	private func _map(_ stage: Stage) -> XSignActivityAttributes.ContentState.Stage {
		switch stage {
		case .signing: return .signing
		case .sending: return .sending
		case .installing: return .installing
		case .completed: return .completed
		case .failed: return .failed
		}
	}
	
	@available(iOS 16.2, *)
	private func _finishCurrent() {
		guard let activity = _activity as? Activity<XSignActivityAttributes> else { return }
		_reset()
		Task {
			await activity.end(nil, dismissalPolicy: .immediate)
		}
	}
	#endif
}
