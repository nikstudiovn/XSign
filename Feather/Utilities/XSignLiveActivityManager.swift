//
//  XSignLiveActivityManager.swift
//  XSign
//
//  Bộ điều phối tập trung cho MỘT Live Activity / Dynamic Island của XSign.
//  - 7 mode: downloading, signingSingle, signingBatch, installingServer,
//    postSignReady, archiveTask, certAlert (XSignActivityMode).
//  - Luồng liên tiếp tải → ký → cài → chốt được cập nhật tại chỗ.
//  - Throttle ~0.45s, cập nhật ngay khi đổi mode / đạt 100% / kết thúc.
//  - Trạng thái kết thúc / lỗi được giữ một thời gian rồi tự đóng
//    (lỗi 8s, chốt sau ký 120s, cảnh báo chứng chỉ 90s).
//  - Bật/tắt bằng UserDefaults "XSign.liveActivityEnabled" (mặc định bật).
//  - Nhận lệnh từ các LiveActivityIntent (iOS 17+) qua Darwin Notification Center.
//
//  Mọi hàm public có thể gọi từ bất kỳ luồng nào; trạng thái nội bộ luôn được
//  xử lý trên main thread.
//

import Foundation
import CoreData
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

extension Notification.Name {
	/// Widget yêu cầu hủy hàng đợi ký hàng loạt (XSignCancelBatchSignIntent).
	static let xsignCancelBatchSignRequested = Notification.Name("XSign.liveActivity.cancelBatchSign")
	/// Widget yêu cầu tắt máy chủ cài đặt (XSignStopInstallServerIntent).
	static let xsignStopInstallServerRequested = Notification.Name("XSign.liveActivity.stopInstallServer")
	/// Mở lại hộp thoại cài đặt của máy chủ đang chạy. object: appID (String).
	static let xsignReinstallRequested = Notification.Name("XSign.liveActivity.reinstall")
}

final class XSignLiveActivityManager {
	static let shared = XSignLiveActivityManager()
	
	static let enabledKey = "XSign.liveActivityEnabled"
	/// Chỉ hiện Live Activity nén/giải nén cho tệp lớn hơn ngưỡng này.
	static let archiveThreshold: Int64 = 5 * 1024 * 1024
	
	// MARK: Thời gian
	private let _throttle: TimeInterval = 0.45
	private let _errorLinger: TimeInterval = 8
	private let _postSignLinger: TimeInterval = 120
	private let _certAlertLinger: TimeInterval = 90
	private let _downloadDoneLinger: TimeInterval = 25
	private let _archiveDoneLinger: TimeInterval = 30
	private let _installDoneLinger: TimeInterval = 8
	
	// MARK: Trạng thái (chỉ truy cập trên main thread)
	private var _activity: Any?
	private var _state: XSignLiveActivityState?
	private var _lastPush: Date = .distantPast
	private var _pendingState: XSignLiveActivityState?
	private var _pendingWork: DispatchWorkItem?
	private var _autoEndWork: DispatchWorkItem?
	private var _expiresAt: Date?
	private var _lastTask: Task<Void, Never>?
	
	private var _didPrepare = false
	private var _certAlertShown = false
	
	/// Download đang được hiển thị trên Live Activity.
	private(set) var activeDownloadID: String?
	private var _downloadSampleBytes: Int64 = 0
	private var _downloadSampleTime: Date = .distantPast
	private var _downloadSpeed: Double = 0
	
	/// App (uuid) mà máy chủ cài đặt Bán cục bộ đang phục vụ.
	private(set) var activeInstallAppID: String?
	
	private init() {}
	
	// MARK: - Cài đặt
	
	var isEnabled: Bool {
		UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
	}
	
	/// Gọi một lần khi app khởi động: dọn activity cũ của phiên trước, đăng ký lệnh
	/// từ widget và theo dõi vòng đời app.
	func prepareOnLaunch() {
		_onMain {
			guard !self._didPrepare else { return }
			self._didPrepare = true
			self._registerDarwinObservers()
			self.endAll()
			
			let center = NotificationCenter.default
			center.addObserver(
				forName: Notification.Name("UIApplicationDidBecomeActiveNotification"),
				object: nil,
				queue: .main
			) { _ in
				XSignLiveActivityManager.shared._sweepExpired()
			}
			center.addObserver(
				forName: Notification.Name("UIApplicationWillTerminateNotification"),
				object: nil,
				queue: .main
			) { _ in
				XSignLiveActivityManager.shared.endAll()
			}
		}
	}
	
	/// Kết thúc mọi Live Activity của XSign ngay lập tức.
	func endAll() {
		_onMain {
			self._cancelTimers()
			self._activity = nil
			self._state = nil
			self.activeDownloadID = nil
			self.activeInstallAppID = nil
			#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
			if #available(iOS 16.2, *) {
				let previous = self._lastTask
				self._lastTask = Task {
					await previous?.value
					for activity in Activity<XSignLiveActivityAttributes>.activities {
						await activity.end(nil, dismissalPolicy: .immediate)
					}
				}
			}
			#endif
		}
	}
	
	// MARK: - 1. downloading
	
	func downloadStarted(id: String, name: String) {
		_onMain {
			if let active = self.activeDownloadID, active != id { return }
			var state = self._base(.downloading)
			state.title = name
			state.statusText = xsignT("Đang tải xuống", "Downloading")
			state.sfSymbol = "arrow.down.circle.fill"
			state.itemID = id
			if self._begin(state, preempt: false) {
				self.activeDownloadID = id
				self._downloadSampleBytes = 0
				self._downloadSampleTime = Date()
				self._downloadSpeed = 0
			}
		}
	}
	
	func downloadProgress(id: String, received: Int64, total: Int64) {
		_onMain {
			guard id == self.activeDownloadID, var state = self._state, state.mode == .downloading else { return }
			let now = Date()
			let elapsed = now.timeIntervalSince(self._downloadSampleTime)
			if elapsed >= 0.5 {
				let instant = Double(max(0, received - self._downloadSampleBytes)) / elapsed
				self._downloadSpeed = self._downloadSpeed == 0 ? instant : (self._downloadSpeed * 0.6 + instant * 0.4)
				self._downloadSampleBytes = received
				self._downloadSampleTime = now
			}
			state.downloadedBytes = received
			state.totalBytes = total
			state.progress = total > 0 ? Double(received) / Double(total) : 0
			state.speedText = self._downloadSpeed > 0 ? "\(Self.formatBytes(Int64(self._downloadSpeed)))/s" : ""
			state.statusText = total > 0
				? "\(Self.formatBytes(received)) / \(Self.formatBytes(total))"
				: Self.formatBytes(received)
			self._update(state)
		}
	}
	
	func downloadFinished(id: String, success: Bool) {
		_onMain {
			guard id == self.activeDownloadID else { return }
			self.activeDownloadID = nil
			guard var state = self._state, state.mode == .downloading else { return }
			if success {
				state.progress = 1
				state.isFinished = true
				state.speedText = ""
				state.sfSymbol = "checkmark.circle.fill"
				state.statusText = xsignT("Đã tải xong · Sẵn sàng ký", "Downloaded · Ready to sign")
				self._finish(state, linger: self._downloadDoneLinger)
			} else {
				state.isFailed = true
				state.speedText = ""
				state.sfSymbol = "exclamationmark.triangle.fill"
				state.statusText = xsignT("Tải xuống thất bại", "Download failed")
				self._finish(state, linger: self._errorLinger)
			}
		}
	}
	
	func downloadCancelled(id: String) {
		_onMain {
			guard id == self.activeDownloadID else { return }
			self.activeDownloadID = nil
			if self._state?.mode == .downloading {
				self._endCurrent()
			}
		}
	}
	
	// MARK: - 2. signingSingle
	
	/// 6 bước, khớp với XSignProgressSheet.
	static func signStepTitle(_ index: Int) -> String {
		switch index {
		case 1: return xsignT("Chuẩn bị tệp & cấu hình", "Preparing files & configuration")
		case 2: return xsignT("Giải nén gói IPA", "Extracting IPA package")
		case 3: return xsignT("Nhúng chứng chỉ & hồ sơ", "Embedding certificate & profile")
		case 4: return xsignT("Ký mã thực thi & frameworks", "Signing executable & frameworks")
		case 5: return xsignT("Đóng gói lại IPA", "Repackaging IPA")
		default: return xsignT("Hoàn tất & sẵn sàng cài đặt", "Done & ready to install")
		}
	}
	
	func signingStarted(appName: String, certName: String) {
		_onMain {
			var state = self._base(.signingSingle)
			state.title = appName
			state.subtitle = certName
			state.sfSymbol = "signature"
			state.stepIndex = 1
			state.stepTotal = 6
			state.progress = 0.05
			state.statusText = self._stepLine(1)
			_ = self._begin(state, preempt: true)
		}
	}
	
	func signingStep(index: Int, progress: Double) {
		_onMain {
			guard var state = self._state, state.mode == .signingSingle, !state.isFinished else { return }
			let step = min(max(index, 1), 6)
			let stepChanged = step != state.stepIndex
			state.stepIndex = step
			state.progress = progress
			state.statusText = self._stepLine(step)
			self._update(state, force: stepChanged)
		}
	}
	
	/// Ký xong. Nếu tự cài sau khi ký, activity chuyển tại chỗ sang installingServer;
	/// ngược lại chuyển sang postSignReady (2 nút Cài đặt ngay / Chia sẻ IPA, tự đóng sau 120s).
	func signingFinished(appName: String, signedAppID: String?, autoInstall: Bool) {
		_onMain {
			guard let current = self._state, current.mode == .signingSingle else { return }
			if autoInstall {
				var state = current
				state.mode = .installingServer
				state.title = appName
				state.subtitle = ""
				state.sfSymbol = "arrow.down.app.fill"
				state.serverStage = .manifest
				state.progress = 0
				state.itemID = signedAppID ?? ""
				state.statusText = xsignT("Đang chuẩn bị cài đặt", "Preparing installation")
				self._update(state, force: true)
				return
			}
			var state = current
			state.mode = .postSignReady
			state.title = appName
			state.progress = 1
			state.stepIndex = 6
			state.isFinished = true
			state.sfSymbol = "checkmark.circle.fill"
			state.itemID = signedAppID ?? ""
			state.statusText = xsignT("Đã ký xong \(appName)", "Signed \(appName)")
			self._finish(state, linger: self._postSignLinger)
		}
	}
	
	func signingFailed(message: String) {
		_onMain {
			guard var state = self._state, state.mode == .signingSingle else { return }
			state.isFailed = true
			state.sfSymbol = "exclamationmark.triangle.fill"
			state.statusText = xsignT("Ký thất bại", "Signing failed")
			state.subtitle = String(message.prefix(80))
			self._finish(state, linger: self._errorLinger)
		}
	}
	
	// MARK: - 3. signingBatch
	
	func batchStarted(total: Int) {
		_onMain {
			var state = self._base(.signingBatch)
			state.title = xsignT("Ký hàng loạt", "Batch signing")
			state.sfSymbol = "app.badge.checkmark"
			state.batchCurrent = 0
			state.batchTotal = total
			state.statusText = xsignT("Đang chờ", "Waiting")
			_ = self._begin(state, preempt: true)
		}
	}
	
	func batchItem(current: Int, total: Int, appName: String, certName: String) {
		_onMain {
			guard var state = self._state, state.mode == .signingBatch else { return }
			state.batchCurrent = current
			state.batchTotal = total
			state.title = appName
			state.subtitle = certName
			state.progress = total > 0 ? (Double(current) - 0.5) / Double(total) : 0
			state.statusText = xsignT("Đang ký \(current)/\(total)", "Signing \(current)/\(total)")
			self._update(state, force: true)
		}
	}
	
	func batchFinished(succeeded: Int, total: Int, cancelled: Bool) {
		_onMain {
			guard var state = self._state, state.mode == .signingBatch else { return }
			state.isFinished = true
			state.progress = cancelled ? state.progress : 1
			state.title = xsignT("Ký hàng loạt", "Batch signing")
			state.subtitle = ""
			if cancelled {
				state.sfSymbol = "xmark.circle.fill"
				state.statusText = xsignT("Đã hủy · Xong \(succeeded)/\(total)", "Cancelled · Done \(succeeded)/\(total)")
			} else {
				state.isFailed = succeeded == 0 && total > 0
				state.sfSymbol = succeeded == total ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
				state.statusText = xsignT("Hoàn tất \(succeeded)/\(total)", "Completed \(succeeded)/\(total)")
			}
			self._finish(state, linger: self._errorLinger)
		}
	}
	
	// MARK: - 4. installingServer
	
	func installStage(appName: String, appID: String, stage: XSignServerStage, progress: Double) {
		_onMain {
			self.activeInstallAppID = appID
			var state: XSignLiveActivityState
			let isSameMode = self._state?.mode == .installingServer && self._state?.isFinished == false
			if isSameMode, let current = self._state {
				state = current
			} else {
				state = self._base(.installingServer)
			}
			let stageChanged = state.serverStage != stage || !isSameMode
			state.mode = .installingServer
			state.title = appName
			state.itemID = appID
			state.serverStage = stage
			state.progress = progress
			state.sfSymbol = "arrow.down.app.fill"
			state.statusText = self._serverStageText(stage)
			if isSameMode {
				self._update(state, force: stageChanged)
			} else {
				_ = self._begin(state, preempt: true)
			}
		}
	}
	
	func installFinished(success: Bool) {
		_onMain {
			self.activeInstallAppID = nil
			guard var state = self._state, state.mode == .installingServer else { return }
			if success {
				state.progress = 1
				state.isFinished = true
				state.serverStage = .installed
				state.sfSymbol = "checkmark.circle.fill"
				state.statusText = xsignT("Đã cài đặt xong", "Installed")
				self._finish(state, linger: self._installDoneLinger)
			} else {
				state.isFailed = true
				state.sfSymbol = "exclamationmark.triangle.fill"
				state.statusText = xsignT("Cài đặt thất bại", "Installation failed")
				self._finish(state, linger: self._errorLinger)
			}
		}
	}
	
	/// Máy chủ bị tắt / sheet cài đặt đóng khi chưa xong.
	func installClosed() {
		_onMain {
			self.activeInstallAppID = nil
			if let state = self._state, state.mode == .installingServer, !state.isFinished, !state.isFailed {
				self._endCurrent()
			}
		}
	}
	
	// MARK: - 5. archiveTask
	
	func archiveStarted(fileName: String, isExtracting: Bool, folderPath: String) {
		_onMain {
			var state = self._base(.archiveTask)
			state.title = fileName
			state.isExtracting = isExtracting
			state.itemID = folderPath
			state.sfSymbol = "doc.zipper"
			state.subtitle = folderPath.isEmpty ? xsignT("Thư mục", "Files") : folderPath
			state.statusText = isExtracting ? xsignT("Đang giải nén", "Extracting") : xsignT("Đang nén", "Compressing")
			_ = self._begin(state, preempt: true)
		}
	}
	
	func archiveProgress(_ progress: Double, processed: Int) {
		_onMain {
			guard var state = self._state, state.mode == .archiveTask, !state.isFinished else { return }
			state.progress = progress
			state.processedCount = processed
			self._update(state)
		}
	}
	
	func archiveFinished(success: Bool, processed: Int) {
		_onMain {
			guard var state = self._state, state.mode == .archiveTask else { return }
			state.processedCount = processed
			if success {
				state.progress = 1
				state.isFinished = true
				state.sfSymbol = "checkmark.circle.fill"
				state.statusText = state.isExtracting
					? xsignT("Đã giải nén xong", "Extraction complete")
					: xsignT("Đã nén xong", "Compression complete")
				self._finish(state, linger: self._archiveDoneLinger)
			} else {
				state.isFailed = true
				state.sfSymbol = "exclamationmark.triangle.fill"
				state.statusText = state.isExtracting
					? xsignT("Giải nén thất bại", "Extraction failed")
					: xsignT("Nén thất bại", "Compression failed")
				self._finish(state, linger: self._errorLinger)
			}
		}
	}
	
	// MARK: - 6. certAlert
	
	/// Gọi sau mỗi lần kiểm tra OCSP chứng chỉ mặc định. Chỉ hiện tối đa 1 lần/phiên,
	/// khi chứng chỉ bị thu hồi hoặc còn ≤ 3 ngày.
	func reportCertificate(name: String, revoked: Bool, daysRemaining: Int) {
		_onMain {
			guard !self._certAlertShown else { return }
			guard revoked || daysRemaining <= 3 else { return }
			var state = self._base(.certAlert)
			state.title = name
			state.certStatus = revoked ? "revoked" : "expiring"
			state.daysRemaining = max(0, daysRemaining)
			state.sfSymbol = "exclamationmark.shield.fill"
			state.isFinished = true
			if revoked {
				state.statusText = xsignT("OCSP: Chứng chỉ đã bị thu hồi", "OCSP: Certificate revoked")
			} else if daysRemaining <= 0 {
				state.statusText = xsignT("Chứng chỉ đã hết hạn", "Certificate expired")
			} else {
				state.statusText = xsignT("Còn \(daysRemaining) ngày là hết hạn", "Expires in \(daysRemaining) days")
			}
			if self._begin(state, preempt: false) {
				self._certAlertShown = true
				self._scheduleAutoEnd(after: self._certAlertLinger)
			}
		}
	}
	
	// MARK: - Lệnh từ widget (AppIntent / xsign://live-action/...)
	
	func handle(_ command: XSignLiveActivityCommand) {
		_onMain {
			switch command {
			case .cancelDownload:
				if let id = self.activeDownloadID,
				   let download = DownloadManager.shared.getDownload(by: id) {
					DownloadManager.shared.cancelDownload(download)
				}
				if let id = self.activeDownloadID {
					self.downloadCancelled(id: id)
				}
			case .cancelBatchSign:
				NotificationCenter.default.post(name: .xsignCancelBatchSignRequested, object: nil)
			case .stopInstallServer:
				NotificationCenter.default.post(name: .xsignStopInstallServerRequested, object: nil)
				self.installClosed()
			}
		}
	}
	
	// MARK: - Helpers (public)
	
	static func formatBytes(_ bytes: Int64) -> String {
		ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
	}
	
	/// uuid của ứng dụng vừa ký gần nhất.
	static func latestSignedAppID() -> String? {
		let request = NSFetchRequest<Signed>(entityName: "Signed")
		request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
		request.fetchLimit = 1
		return (try? Storage.shared.context.fetch(request))?.first?.uuid
	}
	
	/// Đường dẫn tương đối so với thư mục Documents (rỗng = gốc).
	static func relativeDocumentsPath(for url: URL) -> String {
		let root = URL.documentsDirectory.standardizedFileURL.path
		let path = url.standardizedFileURL.path
		guard path.hasPrefix(root) else { return path }
		return String(path.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
	}
	
	/// Kích thước tệp hoặc tổng kích thước thư mục.
	static func sizeOfItem(at url: URL) -> Int64 {
		let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey]
		guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
		if values.isDirectory != true {
			return Int64(values.fileSize ?? 0)
		}
		var total: Int64 = 0
		if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) {
			for case let file as URL in enumerator {
				total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
			}
		}
		return total
	}
	
	// MARK: - Core
	
	private func _onMain(_ work: @escaping @Sendable () -> Void) {
		if Thread.isMainThread {
			work()
		} else {
			DispatchQueue.main.async(execute: work)
		}
	}
	
	private func _lang() -> String {
		switch UserDefaults.standard.string(forKey: "XSign.appLanguage") ?? "system" {
		case "vi": return "vi"
		case "en": return "en"
		default:
			return (Locale.preferredLanguages.first ?? "en").hasPrefix("vi") ? "vi" : "en"
		}
	}
	
	private func _base(_ mode: XSignActivityMode) -> XSignLiveActivityState {
		var state = XSignLiveActivityState()
		state.mode = mode
		state.lang = _lang()
		return state
	}
	
	private func _stepLine(_ step: Int) -> String {
		xsignT("Bước \(step)/6: ", "Step \(step)/6: ") + Self.signStepTitle(step)
	}
	
	private func _serverStageText(_ stage: XSignServerStage) -> String {
		switch stage {
		case .manifest: return xsignT("Đang tạo manifest HTTPS", "Creating HTTPS manifest")
		case .transferring: return xsignT("Đang truyền IPA sang iOS", "Sending IPA to iOS")
		case .transferred: return xsignT("Hoàn tất truyền · Có thể thoát XSign", "Transfer done · Safe to leave XSign")
		case .installed: return xsignT("Đã cài đặt xong", "Installed")
		}
	}
	
	private func _clamp(_ value: Double) -> Double {
		guard value.isFinite else { return 0 }
		return min(max(value, 0), 1)
	}
	
	/// Bắt đầu (hoặc nối tiếp tại chỗ) một activity. Trả về false nếu bị bỏ qua.
	private func _begin(_ newState: XSignLiveActivityState, preempt: Bool) -> Bool {
		guard isEnabled else { return false }
		var state = newState
		state.lang = _lang()
		state.progress = _clamp(state.progress)
		
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return false }
		guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
		
		if let current = _state, _activity != nil {
			let currentBusy = !current.isFinished && !current.isFailed
			// Luồng liên tiếp tải → ký → cài → chốt: cập nhật tại chỗ, không giật đảo.
			if current.mode.isChainable && state.mode.isChainable && (preempt || !currentBusy) {
				_cancelTimers()
				_state = state
				_push(state, staleDate: nil)
				return true
			}
			if currentBusy && !preempt {
				return false
			}
			_endCurrent()
		}
		
		do {
			let activity = try Activity.request(
				attributes: XSignLiveActivityAttributes(sessionID: UUID().uuidString),
				content: ActivityContent(state: state, staleDate: nil),
				pushType: nil
			)
			_activity = activity
			_state = state
			_lastPush = Date()
			return true
		} catch {
			_activity = nil
			_state = nil
			return false
		}
		#else
		return false
		#endif
	}
	
	/// Cập nhật có throttle. Đổi mode / đạt 100% / kết thúc thì đẩy ngay.
	private func _update(_ newState: XSignLiveActivityState, force: Bool = false) {
		guard _activity != nil, let current = _state else { return }
		var state = newState
		state.lang = _lang()
		state.progress = _clamp(state.progress)
		
		let immediate = force
			|| state.mode != current.mode
			|| state.progress >= 1
			|| state.isFinished
			|| state.isFailed
		_state = state
		
		let elapsed = Date().timeIntervalSince(_lastPush)
		if immediate || elapsed >= _throttle {
			_pendingWork?.cancel()
			_pendingWork = nil
			_pendingState = nil
			_push(state, staleDate: nil)
			return
		}
		
		// Giữ giá trị mới nhất và đẩy khi hết khoảng throttle.
		_pendingState = state
		if _pendingWork == nil {
			let work = DispatchWorkItem { [weak self] in
				guard let self else { return }
				self._pendingWork = nil
				if let pending = self._pendingState {
					self._pendingState = nil
					self._push(pending, staleDate: nil)
				}
			}
			_pendingWork = work
			DispatchQueue.main.asyncAfter(deadline: .now() + (_throttle - elapsed), execute: work)
		}
	}
	
	/// Đẩy trạng thái cuối, giữ activity để nút trên Dynamic Island còn dùng được,
	/// rồi tự đóng sau `linger` giây.
	private func _finish(_ newState: XSignLiveActivityState, linger: TimeInterval) {
		guard _activity != nil else { return }
		var state = newState
		state.lang = _lang()
		state.progress = _clamp(state.progress)
		_pendingWork?.cancel()
		_pendingWork = nil
		_pendingState = nil
		_state = state
		_push(state, staleDate: Date().addingTimeInterval(linger))
		_scheduleAutoEnd(after: linger)
	}
	
	private func _scheduleAutoEnd(after seconds: TimeInterval) {
		_autoEndWork?.cancel()
		_expiresAt = Date().addingTimeInterval(seconds)
		let work = DispatchWorkItem { [weak self] in
			self?._endCurrent()
		}
		_autoEndWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
	}
	
	/// App quay lại foreground sau khi bị treo: đóng activity đã quá hạn.
	private func _sweepExpired() {
		if let expiresAt = _expiresAt, expiresAt <= Date() {
			_endCurrent()
		}
	}
	
	private func _cancelTimers() {
		_pendingWork?.cancel()
		_pendingWork = nil
		_pendingState = nil
		_autoEndWork?.cancel()
		_autoEndWork = nil
		_expiresAt = nil
	}
	
	private func _push(_ state: XSignLiveActivityState, staleDate: Date?) {
		_lastPush = Date()
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		guard let activity = _activity as? Activity<XSignLiveActivityAttributes> else { return }
		let previous = _lastTask
		_lastTask = Task {
			await previous?.value
			await activity.update(ActivityContent(state: state, staleDate: staleDate))
		}
		#endif
	}
	
	private func _endCurrent() {
		_cancelTimers()
		let finalState = _state
		_state = nil
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		if #available(iOS 16.2, *), let activity = _activity as? Activity<XSignLiveActivityAttributes> {
			let previous = _lastTask
			_lastTask = Task {
				await previous?.value
				let content = finalState.map { ActivityContent(state: $0, staleDate: nil) }
				await activity.end(content, dismissalPolicy: .immediate)
			}
		}
		#endif
		_activity = nil
	}
	
	// MARK: - Darwin bridge (widget → app)
	
	private func _registerDarwinObservers() {
		let center = CFNotificationCenterGetDarwinNotifyCenter()
		let observer = Unmanaged.passUnretained(self).toOpaque()
		for command in XSignLiveActivityCommand.allCases {
			CFNotificationCenterAddObserver(
				center,
				observer,
				{ _, _, name, _, _ in
					guard let cfName = name?.rawValue else { return }
					XSignLiveActivityManager.handleDarwinNotification(cfName as String)
				},
				command.darwinName as CFString,
				nil,
				.deliverImmediately
			)
		}
	}
	
	fileprivate static func handleDarwinNotification(_ name: String) {
		guard let command = XSignLiveActivityCommand.allCases.first(where: { $0.darwinName == name }) else { return }
		XSignLiveActivityManager.shared.handle(command)
	}
}
