//
//  XSignLiveActivityWidget.swift
//  XSignWidget
//
//  Live Activity / Dynamic Island hợp nhất cho 7 mode của XSign
//  (XSignLiveActivityAttributes / XSignLiveActivityState).
//  Mỗi vùng (Compact / Minimal / Expanded / Lock Screen) là một view con riêng
//  để tránh Swift type-check timeout.
//

import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

// MARK: - Helpers

private extension XSignLiveActivityState {
	func t(_ vi: String, _ en: String) -> String {
		lang == "vi" ? vi : en
	}
	
	var clampedProgress: Double {
		if isFinished && !isFailed && mode != .signingBatch { return 1 }
		guard progress.isFinite else { return 0 }
		return min(max(progress, 0), 1)
	}
	
	var percent: Int {
		Int((clampedProgress * 100).rounded())
	}
	
	var showsProgress: Bool {
		mode != .postSignReady && mode != .certAlert
	}
	
	var tint: Color {
		if isFailed { return .red }
		switch mode {
		case .certAlert: return certStatus == "revoked" ? .red : .orange
		case .postSignReady: return .green
		case .installingServer: return .green
		case .downloading: return isFinished ? .green : .blue
		case .archiveTask: return isFinished ? .green : .teal
		case .signingSingle, .signingBatch:
			return isFinished ? .green : Color(red: 0.518, green: 0.557, blue: 0.976)
		}
	}
	
	/// Phần chữ ngắn ở compact trailing.
	var compactText: String {
		switch mode {
		case .signingBatch: return "\(batchCurrent)/\(batchTotal)"
		case .certAlert: return certStatus == "revoked" ? "!" : "\(daysRemaining)d"
		default: return "\(percent)%"
		}
	}
	
	/// Dòng chi tiết phụ dưới tiêu đề ở chế độ mở rộng.
	var detailLine: String {
		switch mode {
		case .downloading:
			return speedText.isEmpty ? subtitle : speedText
		case .signingSingle, .signingBatch:
			return subtitle.isEmpty ? "" : t("Chứng chỉ: ", "Certificate: ") + subtitle
		case .archiveTask:
			let count = processedCount > 0 ? " · \(processedCount) " + t("mục", "items") : ""
			return subtitle + count
		case .certAlert:
			return certStatus == "revoked" ? t("Đã bị thu hồi", "Revoked") : t("Sắp hết hạn", "Expiring soon")
		default:
			return subtitle
		}
	}
}

private enum XSignLinks {
	static func url(_ string: String) -> URL {
		URL(string: string) ?? URL(string: "xsign://")!
	}
	
	static func encoded(_ value: String) -> String {
		value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
	}
	
	static func install(_ id: String) -> URL { url("xsign://install/\(encoded(id))") }
	static func reinstall(_ id: String) -> URL { url("xsign://reinstall/\(encoded(id))") }
	static func share(_ id: String) -> URL { url("xsign://share/\(encoded(id))") }
	static let certificates = url("xsign://certificates")
	
	static func files(_ path: String) -> URL {
		var components = URLComponents()
		components.scheme = "xsign"
		components.host = "files"
		components.queryItems = [URLQueryItem(name: "path", value: path)]
		return components.url ?? url("xsign://files")
	}
}

// MARK: - Components

/// Icon XSign (glyph chữ ký trên nền màu thương hiệu #848EF9).
private struct XSignBadge: View {
	var size: CGFloat = 36
	
	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
				.fill(
					LinearGradient(
						colors: [
							Color(red: 0.518, green: 0.557, blue: 0.976),
							Color(red: 0.380, green: 0.420, blue: 0.920)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
				)
			Image(systemName: "signature")
				.font(.system(size: size * 0.48, weight: .semibold))
				.foregroundStyle(.white)
		}
		.frame(width: size, height: size)
	}
}

/// Icon của mode hiện tại trong ô tròn màu.
private struct XSignModeIcon: View {
	let state: XSignLiveActivityState
	var size: CGFloat = 36
	
	var body: some View {
		ZStack {
			Circle()
				.fill(state.tint.opacity(0.22))
			Image(systemName: state.sfSymbol)
				.font(.system(size: size * 0.5, weight: .semibold))
				.foregroundStyle(state.tint)
		}
		.frame(width: size, height: size)
	}
}

private struct XSignProgressBar: View {
	let progress: Double
	let tint: Color
	var height: CGFloat = 6
	
	var body: some View {
		GeometryReader { geo in
			ZStack(alignment: .leading) {
				Capsule()
					.fill(Color.white.opacity(0.18))
				Capsule()
					.fill(tint)
					.frame(width: max(height, geo.size.width * progress))
			}
		}
		.frame(height: height)
	}
}

private struct XSignProgressRing: View {
	let progress: Double
	let tint: Color
	var size: CGFloat = 16
	var lineWidth: CGFloat = 2.5
	
	var body: some View {
		ZStack {
			Circle()
				.stroke(tint.opacity(0.25), lineWidth: lineWidth)
			Circle()
				.trim(from: 0, to: progress)
				.stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
				.rotationEffect(.degrees(-90))
		}
		.frame(width: size, height: size)
	}
}

/// Nền nút: Liquid Glass trên iOS 26, vật liệu mờ trên iOS cũ.
private struct XSignChipBackground: ViewModifier {
	@ViewBuilder
	func body(content: Content) -> some View {
		if #available(iOS 26, *) {
			content.glassEffect(.regular, in: Capsule())
		} else {
			content.background(.ultraThinMaterial, in: Capsule())
		}
	}
}

private struct XSignChipLabel: View {
	let title: String
	let symbol: String
	let tint: Color
	
	var body: some View {
		HStack(spacing: 4) {
			Image(systemName: symbol)
				.font(.caption2.weight(.bold))
			Text(title)
				.font(.caption.weight(.semibold))
				.lineLimit(1)
				.minimumScaleFactor(0.8)
		}
		.foregroundStyle(tint)
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.frame(maxWidth: .infinity)
		.modifier(XSignChipBackground())
	}
}

/// Nút mở deep link xsign:// (mọi phiên bản iOS).
private struct XSignLinkChip: View {
	let title: String
	let symbol: String
	let tint: Color
	let destination: URL
	
	var body: some View {
		Link(destination: destination) {
			XSignChipLabel(title: title, symbol: symbol, tint: tint)
		}
	}
}

/// Nút AppIntent trên iOS 17+, dự phòng Link xsign://live-action/... trên iOS 16.x.
private struct XSignIntentChip: View {
	let command: XSignLiveActivityCommand
	let title: String
	let symbol: String
	let tint: Color
	
	var body: some View {
		if #available(iOS 17.0, *) {
			_intentButton
		} else {
			Link(destination: command.fallbackURL) {
				XSignChipLabel(title: title, symbol: symbol, tint: tint)
			}
		}
	}
	
	@available(iOS 17.0, *)
	@ViewBuilder
	private var _intentButton: some View {
		switch command {
		case .cancelDownload:
			Button(intent: XSignCancelDownloadIntent()) {
				XSignChipLabel(title: title, symbol: symbol, tint: tint)
			}
			.buttonStyle(.plain)
		case .cancelBatchSign:
			Button(intent: XSignCancelBatchSignIntent()) {
				XSignChipLabel(title: title, symbol: symbol, tint: tint)
			}
			.buttonStyle(.plain)
		case .stopInstallServer:
			Button(intent: XSignStopInstallServerIntent()) {
				XSignChipLabel(title: title, symbol: symbol, tint: tint)
			}
			.buttonStyle(.plain)
		}
	}
}

/// Hàng nút hành động theo mode.
private struct XSignActionRow: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		switch state.mode {
		case .downloading:
			_downloadActions
		case .signingBatch:
			_batchActions
		case .installingServer:
			_serverActions
		case .postSignReady:
			_postSignActions
		case .archiveTask:
			_archiveActions
		case .certAlert:
			XSignLinkChip(
				title: state.t("Quản lý chứng chỉ", "Manage Certificates"),
				symbol: "checkmark.seal",
				tint: state.tint,
				destination: XSignLinks.certificates
			)
		case .signingSingle:
			EmptyView()
		}
	}
	
	@ViewBuilder
	private var _downloadActions: some View {
		if !state.isFinished && !state.isFailed {
			XSignIntentChip(
				command: .cancelDownload,
				title: state.t("Hủy tải", "Cancel"),
				symbol: "xmark",
				tint: .red
			)
		}
	}
	
	@ViewBuilder
	private var _batchActions: some View {
		if !state.isFinished && !state.isFailed {
			XSignIntentChip(
				command: .cancelBatchSign,
				title: state.t("Hủy hàng đợi", "Cancel Queue"),
				symbol: "xmark",
				tint: .red
			)
		}
	}
	
	@ViewBuilder
	private var _serverActions: some View {
		if !state.isFinished && !state.isFailed {
			HStack(spacing: 8) {
				if !state.itemID.isEmpty {
					XSignLinkChip(
						title: state.t("Cài lại", "Reinstall"),
						symbol: "arrow.clockwise",
						tint: .green,
						destination: XSignLinks.reinstall(state.itemID)
					)
				}
				XSignIntentChip(
					command: .stopInstallServer,
					title: state.t("Tắt máy chủ", "Stop Server"),
					symbol: "power",
					tint: .red
				)
			}
		}
	}
	
	@ViewBuilder
	private var _postSignActions: some View {
		if !state.itemID.isEmpty {
			HStack(spacing: 8) {
				XSignLinkChip(
					title: state.t("Cài đặt ngay", "Install Now"),
					symbol: "arrow.down.app.fill",
					tint: .green,
					destination: XSignLinks.install(state.itemID)
				)
				XSignLinkChip(
					title: state.t("Chia sẻ IPA", "Share IPA"),
					symbol: "square.and.arrow.up",
					tint: .blue,
					destination: XSignLinks.share(state.itemID)
				)
			}
		}
	}
	
	@ViewBuilder
	private var _archiveActions: some View {
		if state.isFinished && !state.isFailed {
			XSignLinkChip(
				title: state.t("Mở thư mục", "Open Folder"),
				symbol: "folder",
				tint: .teal,
				destination: XSignLinks.files(state.itemID)
			)
		}
	}
}

// MARK: - Compact / Minimal

private struct XSignCompactLeading: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		if state.mode == .installingServer && !state.isFailed {
			HStack(spacing: 3) {
				Circle()
					.fill(Color.green)
					.frame(width: 6, height: 6)
				Image(systemName: "arrow.down.app.fill")
					.foregroundStyle(.green)
			}
		} else {
			Image(systemName: state.sfSymbol)
				.foregroundStyle(state.tint)
		}
	}
}

private struct XSignCompactTrailing: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		if state.isFailed {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.red)
		} else if state.mode == .postSignReady {
			Image(systemName: "checkmark.circle.fill")
				.foregroundStyle(.green)
		} else if state.isFinished && state.mode != .certAlert && state.mode != .signingBatch {
			Image(systemName: "checkmark.circle.fill")
				.foregroundStyle(.green)
		} else {
			Text(state.compactText)
				.font(.caption.weight(.semibold).monospacedDigit())
				.foregroundStyle(state.tint)
		}
	}
}

private struct XSignMinimal: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		if state.showsProgress && !state.isFinished && !state.isFailed {
			XSignProgressRing(progress: state.clampedProgress, tint: state.tint)
		} else {
			Image(systemName: state.isFailed ? "exclamationmark.triangle.fill" : state.sfSymbol)
				.foregroundStyle(state.tint)
		}
	}
}

// MARK: - Expanded

private struct XSignExpandedLeading: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		XSignModeIcon(state: state, size: 36)
			.padding(.leading, 4)
			.frame(maxHeight: .infinity, alignment: .center)
	}
}

private struct XSignExpandedTrailing: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		Group {
			if state.mode == .postSignReady || (state.isFinished && state.mode != .certAlert && !state.isFailed) {
				Image(systemName: "checkmark.circle.fill")
					.font(.title3)
					.foregroundStyle(.green)
			} else if state.isFailed {
				Image(systemName: "exclamationmark.triangle.fill")
					.font(.title3)
					.foregroundStyle(.red)
			} else {
				Text(state.compactText)
					.font(.headline.monospacedDigit())
					.foregroundStyle(state.tint)
			}
		}
		.padding(.trailing, 4)
		.frame(maxHeight: .infinity, alignment: .center)
	}
}

private struct XSignExpandedCenter: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(state.title.isEmpty ? "XSign" : state.title)
				.font(.subheadline.weight(.semibold))
				.lineLimit(1)
			Text(state.statusText)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.minimumScaleFactor(0.85)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

private struct XSignExpandedBottom: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if !state.detailLine.isEmpty {
				Text(state.detailLine)
					.font(.caption2.monospacedDigit())
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			if state.showsProgress {
				XSignProgressBar(progress: state.clampedProgress, tint: state.tint, height: 6)
			}
			XSignActionRow(state: state)
		}
		.padding(.horizontal, 6)
		.padding(.top, 4)
	}
}

// MARK: - Lock Screen

private struct XSignLockScreenView: View {
	let state: XSignLiveActivityState
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			_header
			if state.showsProgress {
				XSignProgressBar(progress: state.clampedProgress, tint: state.tint, height: 8)
			}
			XSignActionRow(state: state)
		}
		.padding(16)
	}
	
	private var _header: some View {
		HStack(spacing: 12) {
			XSignBadge(size: 40)
			VStack(alignment: .leading, spacing: 2) {
				Text(state.title.isEmpty ? "XSign" : state.title)
					.font(.headline)
					.foregroundStyle(.white)
					.lineLimit(1)
				Text(state.statusText)
					.font(.subheadline)
					.foregroundStyle(.white.opacity(0.75))
					.lineLimit(1)
					.minimumScaleFactor(0.85)
				if !state.detailLine.isEmpty {
					Text(state.detailLine)
						.font(.caption.monospacedDigit())
						.foregroundStyle(.white.opacity(0.6))
						.lineLimit(1)
				}
			}
			Spacer(minLength: 8)
			XSignExpandedTrailing(state: state)
		}
	}
}

// MARK: - Widget

@available(iOS 16.2, *)
struct XSignLiveActivityWidget: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: XSignLiveActivityAttributes.self) { context in
			XSignLockScreenView(state: context.state)
				.activityBackgroundTint(Color.black.opacity(0.6))
				.activitySystemActionForegroundColor(.white)
		} dynamicIsland: { context in
			DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					XSignExpandedLeading(state: context.state)
				}
				DynamicIslandExpandedRegion(.trailing) {
					XSignExpandedTrailing(state: context.state)
				}
				DynamicIslandExpandedRegion(.center) {
					XSignExpandedCenter(state: context.state)
				}
				DynamicIslandExpandedRegion(.bottom) {
					XSignExpandedBottom(state: context.state)
				}
			} compactLeading: {
				XSignCompactLeading(state: context.state)
			} compactTrailing: {
				XSignCompactTrailing(state: context.state)
			} minimal: {
				XSignMinimal(state: context.state)
			}
		}
	}
}
