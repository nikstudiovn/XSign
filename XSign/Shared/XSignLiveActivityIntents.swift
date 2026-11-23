//
//  XSignLiveActivityIntents.swift
//  XSign
//
//  Dùng chung giữa app và XSignWidget extension.
//  Nút tương tác trên Dynamic Island / Màn hình khoá (iOS 17+, LiveActivityIntent).
//  Vì tệp nằm trong cả 2 target, iOS chạy perform() trong tiến trình app. Lệnh được
//  phát qua Darwin Notification Center nên vẫn tới được app kể cả khi perform() chạy
//  trong tiến trình extension (không cần App Group).
//  iOS 16.x dùng Link tới xsign://live-action/<lệnh> thay cho nút intent.
//

import Foundation

enum XSignLiveActivityCommand: String, CaseIterable {
	case cancelDownload
	case cancelBatchSign
	case stopInstallServer
	
	var darwinName: String {
		"com.nikstudiovn.xsign.liveactivity.\(rawValue)"
	}
	
	/// Dự phòng cho iOS 16.x (không có Button(intent:)).
	var fallbackURL: URL {
		URL(string: "xsign://live-action/\(rawValue)") ?? URL(fileURLWithPath: "/")
	}
	
	func post() {
		let center = CFNotificationCenterGetDarwinNotifyCenter()
		CFNotificationCenterPostNotification(
			center,
			CFNotificationName(darwinName as CFString),
			nil,
			nil,
			true
		)
	}
}

#if canImport(AppIntents) && !targetEnvironment(macCatalyst)
import AppIntents

@available(iOS 17.0, *)
struct XSignCancelDownloadIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Cancel Download"
	
	init() {}
	
	func perform() async throws -> some IntentResult {
		XSignLiveActivityCommand.cancelDownload.post()
		return .result()
	}
}

@available(iOS 17.0, *)
struct XSignCancelBatchSignIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Cancel Batch Signing"
	
	init() {}
	
	func perform() async throws -> some IntentResult {
		XSignLiveActivityCommand.cancelBatchSign.post()
		return .result()
	}
}

@available(iOS 17.0, *)
struct XSignStopInstallServerIntent: LiveActivityIntent {
	static let title: LocalizedStringResource = "Stop Install Server"
	
	init() {}
	
	func perform() async throws -> some IntentResult {
		XSignLiveActivityCommand.stopInstallServer.post()
		return .result()
	}
}
#endif
