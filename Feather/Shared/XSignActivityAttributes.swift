//
//  XSignActivityAttributes.swift
//  XSign
//
//  Dùng chung giữa app (thư mục Feather/ đồng bộ) và XSignWidget extension
//  (thêm thủ công vào Sources của target XSignWidget trong project.pbxproj).
//
//  MỘT ActivityAttributes duy nhất cho mọi Live Activity / Dynamic Island của XSign.
//  ContentState chỉ chứa chuỗi ngắn và số (không có Data ảnh) để luôn < 4 KB.
//

import Foundation
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

/// 6 nhóm tác vụ (7 mode) mà một Live Activity của XSign có thể hiển thị.
enum XSignActivityMode: String, Codable, Hashable {
	case downloading
	case signingSingle
	case signingBatch
	case installingServer
	case postSignReady
	case archiveTask
	case certAlert
	
	/// Các mode thuộc cùng một luồng liên tiếp (tải → ký → cài → chốt),
	/// được cập nhật tại chỗ thay vì tắt rồi bật Live Activity mới.
	var isChainable: Bool {
		switch self {
		case .downloading, .signingSingle, .installingServer, .postSignReady: return true
		case .signingBatch, .archiveTask, .certAlert: return false
		}
	}
}

/// Giai đoạn của máy chủ cài đặt Bán cục bộ (127.0.0.1 + Cloudflare Worker).
enum XSignServerStage: String, Codable, Hashable {
	case manifest
	case transferring
	case transferred
	case installed
}

/// Trạng thái động. Mọi trường đều có giá trị mặc định để mỗi mode chỉ cần
/// điền phần của mình.
struct XSignLiveActivityState: Codable, Hashable {
	var mode: XSignActivityMode = .signingSingle
	/// "vi" hoặc "en" – ngôn ngữ XSign tại thời điểm cập nhật. Widget extension
	/// không đọc được UserDefaults của app (không có App Group), nên app gửi kèm.
	var lang: String = "en"
	
	// Chung
	var title: String = ""
	var subtitle: String = ""
	var statusText: String = ""
	var sfSymbol: String = "signature"
	var progress: Double = 0
	var isFinished: Bool = false
	var isFailed: Bool = false
	/// downloadID / signedAppID / appID cài đặt / đường dẫn thư mục tương đối.
	var itemID: String = ""
	
	// downloading
	var downloadedBytes: Int64 = 0
	var totalBytes: Int64 = 0
	var speedText: String = ""
	
	// signingSingle / signingBatch
	var stepIndex: Int = 0
	var stepTotal: Int = 6
	var batchCurrent: Int = 0
	var batchTotal: Int = 0
	
	// installingServer
	var serverStage: XSignServerStage = .manifest
	
	// archiveTask
	var isExtracting: Bool = true
	var processedCount: Int = 0
	
	// certAlert: "expiring" | "revoked"
	var certStatus: String = ""
	var daysRemaining: Int = 0
}

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
@available(iOS 16.2, *)
struct XSignLiveActivityAttributes: ActivityAttributes {
	typealias ContentState = XSignLiveActivityState
	
	/// Định danh phiên, cố định trong suốt vòng đời một activity.
	var sessionID: String
}
#endif
