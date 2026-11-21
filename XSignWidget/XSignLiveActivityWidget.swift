//
//  XSignLiveActivityWidget.swift
//  XSignWidget
//
//  Live Activity / Dynamic Island: Đang ký → Đang gửi → Đang cài.
//

import WidgetKit
import SwiftUI
import ActivityKit

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
	
	var index: Int {
		switch self {
		case .signing: return 0
		case .sending: return 1
		case .installing: return 2
		case .completed: return 3
		case .failed: return 0
		}
	}
}

private struct StageDots: View {
	let stage: XSignActivityAttributes.ContentState.Stage
	
	var body: some View {
		HStack(spacing: 6) {
			ForEach(0..<3, id: \.self) { i in
				Capsule()
					.fill(stage == .failed ? Color.red : (i <= stage.index ? Color.accentColor : Color.secondary.opacity(0.3)))
					.frame(height: 4)
			}
		}
	}
}

struct XSignLiveActivityWidget: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: XSignActivityAttributes.self) { context in
			// Lock screen / banner
			VStack(alignment: .leading, spacing: 10) {
				HStack {
					Image(systemName: context.state.stage.icon)
						.foregroundStyle(context.state.stage == .failed ? .red : Color.accentColor)
					Text(context.attributes.appName)
						.font(.headline)
						.lineLimit(1)
					Spacer()
					Text(context.state.stage.title)
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				StageDots(stage: context.state.stage)
				ProgressView(value: min(max(context.state.progress, 0), 1))
			}
			.padding()
			.activityBackgroundTint(Color.black.opacity(0.35))
		} dynamicIsland: { context in
			DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					Image(systemName: context.state.stage.icon)
						.font(.title2)
						.foregroundStyle(context.state.stage == .failed ? .red : Color.accentColor)
				}
				DynamicIslandExpandedRegion(.trailing) {
					Text(context.state.stage.title)
						.font(.subheadline)
				}
				DynamicIslandExpandedRegion(.center) {
					Text(context.attributes.appName)
						.font(.headline)
						.lineLimit(1)
				}
				DynamicIslandExpandedRegion(.bottom) {
					VStack(spacing: 8) {
						StageDots(stage: context.state.stage)
						ProgressView(value: min(max(context.state.progress, 0), 1))
					}
				}
			} compactLeading: {
				Image(systemName: context.state.stage.icon)
					.foregroundStyle(Color.accentColor)
			} compactTrailing: {
				Text(context.state.stage.title)
					.font(.caption2)
			} minimal: {
				Image(systemName: context.state.stage.icon)
					.foregroundStyle(Color.accentColor)
			}
		}
	}
}
