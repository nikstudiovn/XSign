//
//  InstallLiveActivity.swift
//  XSignLiveActivity
//
//  Lock Screen + Dynamic Island UI for the install progress.
//
//  Performance: Live Activities cannot run their own animations, so this
//  UI is purely declarative. The system animates between updates (the
//  progress bar and ring slide, the percentage rolls with numericText).
//  The app sends at most about one update per second.
//

import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct InstallLiveActivity: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: InstallActivityAttributes.self) { context in
			InstallLockScreenView(attributes: context.attributes, state: context.state)
				.activitySystemActionForegroundColor(context.state.phase.tint)
				.widgetURL(XSignActivityStyle.openURL)
		} dynamicIsland: { context in
			DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					AppGlyph(attributes: context.attributes, size: 46)
						.padding(.leading, 4)
						.padding(.top, 4)
				}
				DynamicIslandExpandedRegion(.trailing) {
					StatusBadge(state: context.state, size: 30)
						.padding(.trailing, 4)
						.padding(.top, 4)
				}
				DynamicIslandExpandedRegion(.center) {
					VStack(alignment: .leading, spacing: 3) {
						Text(context.attributes.appName)
							.font(.headline)
							.lineLimit(1)
						PhaseLabel(state: context.state)
							.font(.subheadline)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.top, 4)
				}
				DynamicIslandExpandedRegion(.bottom) {
					VStack(spacing: 6) {
						ProgressView(value: context.state.progress)
							.tint(context.state.phase.tint)
						DetailLine(attributes: context.attributes, state: context.state)
					}
					.padding(.horizontal, 6)
					.padding(.top, 2)
				}
			} compactLeading: {
				AppGlyph(attributes: context.attributes, size: 22)
			} compactTrailing: {
				StatusBadge(state: context.state, size: 20)
			} minimal: {
				StatusBadge(state: context.state, size: 20)
			}
			.keylineTint(context.state.phase.tint)
			.widgetURL(XSignActivityStyle.openURL)
		}
	}
}

// MARK: - Lock Screen

private struct InstallLockScreenView: View {
	let attributes: InstallActivityAttributes
	let state: InstallActivityAttributes.ContentState
	
	var body: some View {
		HStack(alignment: .center, spacing: 14) {
			AppGlyph(attributes: attributes, size: 48)
			
			VStack(alignment: .leading, spacing: 7) {
				HStack(alignment: .firstTextBaseline, spacing: 8) {
					Text(attributes.appName)
						.font(.headline)
						.lineLimit(1)
					Spacer(minLength: 4)
					TrailingValue(state: state)
				}
				
				PhaseLabel(state: state)
					.font(.subheadline)
				
				ProgressView(value: state.progress)
					.tint(state.phase.tint)
				
				DetailLine(attributes: attributes, state: state)
			}
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 14)
	}
}

// MARK: - Components

/// App icon thumbnail, or a soft gradient tile with the first letter.
private struct AppGlyph: View {
	let attributes: InstallActivityAttributes
	let size: CGFloat
	
	var body: some View {
		let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
		
		Group {
			if
				let data = attributes.iconData,
				let image = UIImage(data: data)
			{
				Image(uiImage: image)
					.resizable()
					.interpolation(.high)
					.aspectRatio(contentMode: .fill)
			} else {
				ZStack {
					LinearGradient(
						colors: [XSignActivityStyle.accent, XSignActivityStyle.accent.opacity(0.65)],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					)
					Text(String(attributes.appName.prefix(1)).uppercased())
						.font(.system(size: size * 0.46, weight: .bold, design: .rounded))
						.foregroundStyle(.white)
				}
			}
		}
		.frame(width: size, height: size)
		.clipShape(shape)
		.overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
		.accessibilityHidden(true)
	}
}

/// Progress ring while working, a symbol once finished.
private struct StatusBadge: View {
	let state: InstallActivityAttributes.ContentState
	let size: CGFloat
	
	var body: some View {
		ZStack {
			if state.phase.isFinal {
				Image(systemName: state.phase.symbol)
					.resizable()
					.scaledToFit()
					.foregroundStyle(state.phase.tint)
					.transition(.scale.combined(with: .opacity))
			} else {
				Circle()
					.stroke(state.phase.tint.opacity(0.25), lineWidth: size * 0.15)
				Circle()
					.trim(from: 0, to: max(0.02, state.progress))
					.stroke(
						state.phase.tint,
						style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round)
					)
					.rotationEffect(.degrees(-90))
			}
		}
		.frame(width: size, height: size)
		.accessibilityLabel(Text(state.phase.title))
	}
}

/// Percentage while working, a symbol once finished.
private struct TrailingValue: View {
	let state: InstallActivityAttributes.ContentState
	
	var body: some View {
		if state.phase.isFinal {
			Image(systemName: state.phase.symbol)
				.font(.title3)
				.foregroundStyle(state.phase.tint)
		} else {
			Text(state.progress, format: .percent.precision(.fractionLength(0)))
				.font(.headline)
				.monospacedDigit()
				.contentTransition(.numericText())
				.foregroundStyle(state.phase.tint)
		}
	}
}

private struct PhaseLabel: View {
	let state: InstallActivityAttributes.ContentState
	
	var body: some View {
		HStack(spacing: 5) {
			Image(systemName: state.phase.symbol)
				.foregroundStyle(state.phase.tint)
			Text(state.phase.title)
				.foregroundStyle(.secondary)
				.lineLimit(1)
		}
	}
}

/// One quiet line under the bar: a hint, the error, or the version.
private struct DetailLine: View {
	let attributes: InstallActivityAttributes
	let state: InstallActivityAttributes.ContentState
	
	var body: some View {
		Text(_text)
			.lineLimit(1)
			.font(.caption)
			.foregroundStyle(.secondary)
			.frame(maxWidth: .infinity, alignment: .leading)
	}
	
	private var _text: String {
		switch state.phase {
		case .waiting:
			return XSignActivityStyle.text(
				vi: "Nhấn “Cài đặt” trên hộp thoại của iOS",
				en: "Tap “Install” in the iOS prompt"
			)
		case .failed:
			return state.message ?? XSignActivityStyle.text(
				vi: "Mở XSign để xem chi tiết",
				en: "Open XSign for details"
			)
		case .completed:
			return XSignActivityStyle.text(
				vi: "Ứng dụng đã sẵn sàng trên Màn hình chính",
				en: "The app is ready on your Home Screen"
			)
		default:
			let version = attributes.appVersion.isEmpty ? "" : "v\(attributes.appVersion) · "
			return version + attributes.bundleIdentifier
		}
	}
}

// MARK: - Style

enum XSignActivityStyle {
	/// XSign default tint (#848ef9).
	static let accent = Color(red: 0x84 / 255, green: 0x8E / 255, blue: 0xF9 / 255)
	static let openURL = URL(string: "xsign://")
	
	static var isVietnamese: Bool {
		Locale.preferredLanguages.first?.lowercased().hasPrefix("vi") ?? false
	}
	
	static func text(vi: String, en: String) -> String {
		isVietnamese ? vi : en
	}
}

extension InstallActivityPhase {
	var tint: Color {
		switch self {
		case .waiting: .orange
		case .completed: .green
		case .failed: .red
		default: XSignActivityStyle.accent
		}
	}
	
	var symbol: String {
		switch self {
		case .packaging: "shippingbox.fill"
		case .waiting: "hand.tap.fill"
		case .sending: "paperplane.fill"
		case .installing: "arrow.down.circle.fill"
		case .completed: "checkmark.circle.fill"
		case .failed: "exclamationmark.triangle.fill"
		}
	}
	
	var title: String {
		switch self {
		case .packaging: XSignActivityStyle.text(vi: "Đang đóng gói", en: "Packaging")
		case .waiting: XSignActivityStyle.text(vi: "Chờ xác nhận cài đặt", en: "Waiting for confirmation")
		case .sending: XSignActivityStyle.text(vi: "Đang gửi tới iOS", en: "Sending to iOS")
		case .installing: XSignActivityStyle.text(vi: "Đang cài đặt", en: "Installing")
		case .completed: XSignActivityStyle.text(vi: "Đã cài xong", en: "Installed")
		case .failed: XSignActivityStyle.text(vi: "Cài đặt thất bại", en: "Installation failed")
		}
	}
}
