//
//  InstallPreview.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import SwiftUI
import NimbleViews
import IDeviceSwift
import OSLog

// MARK: - View
struct InstallPreviewView: View {
	@Environment(\.dismiss) var dismiss

	@AppStorage("Feather.useShareSheetForArchiving") private var _useShareSheet: Bool = false
	@AppStorage("Feather.installationMethod") private var _installationMethod: Int = 0
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 1
	@State private var _isWebviewPresenting = false
	@State private var progressTask: Task<Void, Never>?
	/// XSign: guards against onAppear firing twice (archive + .ready twice).
	@State private var _didStartInstall = false
	/// XSign: guards against opening the itms-services link more than once,
	/// which showed the iOS install prompt twice.
	@State private var _didOpenInstallLink = false
	/// XSign: Lock Screen / Dynamic Island progress for this install.
	@State private var _liveActivity = InstallActivityController()
	
	var app: AppInfoPresentable
	@StateObject var viewModel: InstallerStatusViewModel
	@StateObject var installer: ServerInstaller
	
	@State var isSharing: Bool
	
	init(app: AppInfoPresentable, isSharing: Bool = false) {
		self.app = app
		self.isSharing = isSharing
		let viewModel = InstallerStatusViewModel(isIdevice: UserDefaults.standard.integer(forKey: "Feather.installationMethod") == 1)
		self._viewModel = StateObject(wrappedValue: viewModel)
		self._installer = StateObject(wrappedValue: try! ServerInstaller(app: app, viewModel: viewModel))
	}
	
	// MARK: Body
	var body: some View {
		let cornerRadius = {
			if #available(iOS 26.0, *) {
				28.0
			} else {
				10.5
			}
		}()
		
		ZStack {
			InstallProgressView(app: app, viewModel: viewModel)
			_status()
			_button()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
		.background(Color(UIColor.secondarySystemBackground))
		.cornerRadius(cornerRadius)
		.padding()
		.sheet(isPresented: $_isWebviewPresenting) {
			SafariRepresentableView(url: installer.pageEndpoint).ignoresSafeArea()
		}
		.onReceive(viewModel.$status) { newStatus in
			_liveActivity.update(status: newStatus, progress: viewModel.overallProgress)
			
			if _installationMethod == 0 {
				if case .ready = newStatus, !_didOpenInstallLink {
					// XSign: open the itms-services link directly with an HTTPS manifest.
					// The manifest server is the custom URL from Server settings, then the
					// XSign Cloudflare Worker (both health-checked), then api.palera.in.
					// No in-app Safari page: no "connection not secure" warning and no
					// "Open in iTunes?" prompt.
					// The flag is set before the async health check so a repeated
					// .ready cannot open the link a second time.
					_didOpenInstallLink = true
					let installer = installer
					Task {
						let link = await installer.resolveITunesLinkExternal()
						if let url = URL(string: link) {
							await MainActor.run {
								UIApplication.shared.open(url)
							}
						}
					}
				}
				
				if case .sendingPayload = newStatus, _serverMethod == 1 {
					_isWebviewPresenting = false
				}
				
				if case .installing = newStatus {
					if progressTask == nil {
						progressTask = startInstallProgressPolling(
							bundleID: app.identifier!,
							viewModel: viewModel
						)
					}
				}
				
				switch newStatus {
				case .completed, .broken(_):
					progressTask?.cancel()
					progressTask = nil
					#if !targetEnvironment(macCatalyst)
					BackgroundAudioManager.shared.stop()
					#endif
				default:
					break
				}
			}
		}
		// XSign: progress-only updates; the controller throttles them.
		.onChange(of: viewModel.overallProgress) { newProgress in
			_liveActivity.update(progress: newProgress)
		}
		.onAppear(perform: _install)
		
		#if !targetEnvironment(macCatalyst)
		.onAppear {
			BackgroundAudioManager.shared.start()
		}
		#endif
		
		.onDisappear {
			progressTask?.cancel()
			progressTask = nil
			_liveActivity.sheetDidClose()
			
			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.stop()
			#endif
		}
	}
	
	@ViewBuilder
	private func _status() -> some View {
		Label(viewModel.statusLabel, systemImage: viewModel.statusImage)
			.padding()
			.labelStyle(.titleAndIcon)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
			.animation(.smooth, value: viewModel.statusImage)
	}
	
	@ViewBuilder
	private func _button() -> some View {
		ZStack {
			if viewModel.isCompleted {
				Button {
					UIApplication.openApp(with: app.identifier ?? "")
				} label: {
					NBButton("Open", systemImage: "", style: .text)
				}
				.padding()
				.compatTransition()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
		.animation(.easeInOut(duration: 0.3), value: viewModel.isCompleted)
	}
	
	private func _install() {
		// XSign: onAppear can fire more than once for a sheet; only install once.
		guard !_didStartInstall else { return }
		_didStartInstall = true
		
		guard isSharing || app.identifier != Bundle.main.bundleIdentifier! || _installationMethod == 1 else {
			UIAlertController.showAlertWithOk(
				title: .localized("Install"),
				message: .localized("You cannot update ‘%@‘ with itself, please use an alternative tool to update it.", arguments: Bundle.main.name)
			)
			return
		}
		
		if !isSharing {
			_liveActivity.start(app: app)
		}
				
		Task.detached {
			do {
				let handler = await ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				
				let packageUrl = try await handler.archive()
				
				if await !isSharing {
					if await _installationMethod == 0 {
						await MainActor.run {
							installer.packageUrl = packageUrl
							viewModel.status = .ready
						}
						
						if case .installing = await viewModel.status {
							let task = await startInstallProgressPolling(
								bundleID: app.identifier!,
								viewModel: viewModel
							)

							await MainActor.run {
								progressTask = task
							}
						}
					} else if await _installationMethod == 1 {
						let handler = await InstallationProxy(viewModel: viewModel)
						try await handler.install(at: packageUrl, suspend: app.identifier == Bundle.main.bundleIdentifier!)
					}
				} else {
					let package = try await handler.moveToArchive(packageUrl, shouldOpen: !_useShareSheet)
					
					if await !_useShareSheet {
						await MainActor.run {
							dismiss()
						}
					} else {
						if let package {
							await MainActor.run {
								dismiss()
								UIActivityViewController.show(activityItems: [package])
							}
						}
					}
				}
			} catch {
				await progressTask?.cancel()
				
				await MainActor.run {
					_liveActivity.fail(error)
					UIAlertController.showAlertWithOk(
						title: .localized("Install"),
						message: String(describing: error),
						action: {
							HeartbeatManager.shared.start(true)
							dismiss()
						}
					)
				}
			}
		}
	}
	
	private func startInstallProgressPolling(
		bundleID: String,
		viewModel: InstallerStatusViewModel
	) -> Task<Void, Never> {

		Task.detached(priority: .background) {
			var hasStarted = false
			var lastLogged = -1.0

			while !Task.isCancelled {
				let rawProgress = await UIApplication.installProgress(for: bundleID) ?? 0.0

				if rawProgress > 0 {
					hasStarted = true
				}

				let progress = await hasStarted
					? _normalizeInstallProgress(rawProgress)
					: 0.0

				// XSign: log only real changes (was every loop).
				if abs(progress - lastLogged) >= 0.05 || (progress == 1 && lastLogged != 1) {
					lastLogged = progress
					Logger.misc.info("Install progress for \(bundleID): \(progress)")
				}

				// XSign: only publish real changes, so SwiftUI does not redraw
				// the sheet for identical values.
				await MainActor.run {
					if viewModel.installProgress != progress {
						viewModel.installProgress = progress
					}
				}

				if hasStarted && rawProgress == 0 {
					await MainActor.run {
						viewModel.installProgress = 1.0
						viewModel.status = .completed(.success(()))
					}
					break
				}

				// XSign: poll 4x per second instead of every 1 ms. The progress
				// ring animates between values, so it still looks smooth while
				// using far less CPU and battery.
				try? await Task.sleep(nanoseconds: 250_000_000) // 250 ms
			}
		}
	}

	private func _normalizeInstallProgress(_ rawProgress: Double) -> Double {
		min(1.0, max(0.0, (rawProgress - 0.6) / 0.3))
	}
}
