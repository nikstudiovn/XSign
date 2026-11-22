//
//  XSignLiveActivityWidget.swift
//  XSignWidget
//
//  Live Activity / Dynamic Island: Đang ký → Đang gửi → Đang cài.
//  Chỉ dùng MỘT thanh tiến độ duy nhất, chạy theo giá trị `progress` thực tế (0.0 → 1.0).
//

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Helpers

private extension XSignActivityAttributes.ContentState.Stage {
	var title: String {
		switch self {
		case .signing: return "Đang ký"
		case .sending: return "Đang gửi"
		case .installing: return "Đang cài"
		case .completed: return "Hoàn tất"
		case .failed: return "Thất bại"
		}
	}
	
	var icon: String {
		switch self {
		case .signing: return "signature"
		case .sending: return "paperplane.fill"
		case .installing: return "square.and.arrow.down"
		case .completed: return "checkmark.circle.fill"
		case .failed: return "exclamationmark.triangle.fill"
		}
	}
	
	/// Màu của thanh tiến độ: xanh trong lúc chạy, xanh lá khi xong, đỏ khi lỗi.
	var tint: Color {
		switch self {
		case .completed: return .green
		case .failed: return .red
		default: return .blue
		}
	}
}

private extension XSignActivityAttributes.ContentState {
	var clampedProgress: Double {
		stage == .completed ? 1 : min(max(progress, 0), 1)
	}
	
	var percent: Int {
		Int((clampedProgress * 100).rounded())
	}
	
	/// Ví dụ: "Đang ký • 88%"
	var statusLine: String {
		switch stage {
		case .failed: return stage.title
		default: return "\(stage.title) • \(percent)%"
		}
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

/// Thanh tiến độ dạng capsule bo tròn, duy nhất.
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

/// Vòng tròn tiến độ nhỏ cho trạng thái minimal.
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

// MARK: - Widget

struct XSignLiveActivityWidget: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: XSignActivityAttributes.self) { context in
			// Lock Screen / banner
			VStack(alignment: .leading, spacing: 14) {
				HStack(spacing: 12) {
					XSignBadge(size: 40)
					VStack(alignment: .leading, spacing: 2) {
						Text(context.attributes.appName)
							.font(.headline)
							.foregroundStyle(.white)
							.lineLimit(1)
						Text(context.state.statusLine)
							.font(.subheadline.monospacedDigit())
							.foregroundStyle(.white.opacity(0.7))
							.lineLimit(1)
					}
					Spacer(minLength: 8)
					Image(systemName: context.state.stage.icon)
						.font(.title3)
						.foregroundStyle(context.state.stage.tint)
				}
				XSignProgressBar(
					progress: context.state.clampedProgress,
					tint: context.state.stage.tint,
					height: 8
				)
			}
			.padding(16)
			.activityBackgroundTint(Color.black.opacity(0.6))
			.activitySystemActionForegroundColor(.white)
		} dynamicIsland: { context in
			DynamicIsland {
				// Expanded: hàng trên = icon + tên app + trạng thái & phần trăm
				DynamicIslandExpandedRegion(.leading) {
					HStack(spacing: 10) {
						XSignBadge(size: 36)
						VStack(alignment: .leading, spacing: 2) {
							Text(context.attributes.appName)
								.font(.subheadline.weight(.semibold))
								.lineLimit(1)
							Text(context.state.statusLine)
								.font(.caption.monospacedDigit())
								.foregroundStyle(.secondary)
								.lineLimit(1)
						}
					}
					.padding(.leading, 6)
					.dynamicIsland(verticalPlacement: .belowIfTooWide)
				}
				DynamicIslandExpandedRegion(.trailing) {
					Image(systemName: context.state.stage.icon)
						.font(.title3)
						.foregroundStyle(context.state.stage.tint)
						.padding(.trailing, 6)
						.frame(maxHeight: .infinity, alignment: .center)
				}
				// Expanded: hàng dưới = 1 thanh tiến độ duy nhất
				DynamicIslandExpandedRegion(.bottom) {
					XSignProgressBar(
						progress: context.state.clampedProgress,
						tint: context.state.stage.tint,
						height: 6
					)
					.padding(.horizontal, 6)
					.padding(.top, 10)
					.padding(.bottom, 4)
				}
			} compactLeading: {
				XSignBadge(size: 22)
			} compactTrailing: {
				switch context.state.stage {
				case .completed:
					Image(systemName: "checkmark.circle.fill")
						.foregroundStyle(.green)
				case .failed:
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundStyle(.red)
				default:
					Text("\(context.state.percent)%")
						.font(.caption.weight(.semibold).monospacedDigit())
						.foregroundStyle(context.state.stage.tint)
				}
			} minimal: {
				XSignProgressRing(
					progress: context.state.clampedProgress,
					tint: context.state.stage.tint
				)
			}
		}
	}
}
