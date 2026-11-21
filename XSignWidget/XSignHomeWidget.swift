//
//  XSignHomeWidget.swift
//  XSignWidget
//
//  Widget màn hình chính: hạn chứng chỉ + các app ký gần đây.
//

import WidgetKit
import SwiftUI

struct XSignEntry: TimelineEntry {
	let date: Date
	let snapshot: XSignWidgetSnapshot?
}

struct XSignProvider: TimelineProvider {
	func placeholder(in context: Context) -> XSignEntry {
		XSignEntry(date: Date(), snapshot: XSignProvider.sample)
	}
	
	func getSnapshot(in context: Context, completion: @escaping (XSignEntry) -> Void) {
		completion(XSignEntry(date: Date(), snapshot: context.isPreview ? XSignProvider.sample : XSignWidgetSnapshot.load()))
	}
	
	func getTimeline(in context: Context, completion: @escaping (Timeline<XSignEntry>) -> Void) {
		let entry = XSignEntry(date: Date(), snapshot: XSignWidgetSnapshot.load())
		// Số ngày còn lại thay đổi theo ngày, làm mới mỗi 6 giờ.
		let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21600)
		completion(Timeline(entries: [entry], policy: .after(next)))
	}
	
	static let sample = XSignWidgetSnapshot(
		certificateName: "Chứng chỉ của tôi",
		certificateExpiration: Date().addingTimeInterval(86400 * 21),
		certificateRevoked: false,
		recentApps: [
			.init(name: "App A", version: "1.0", date: Date()),
			.init(name: "App B", version: "2.3", date: Date().addingTimeInterval(-3600))
		],
		updatedAt: Date()
	)
}

private extension View {
	@ViewBuilder
	func xsignWidgetBackground() -> some View {
		if #available(iOS 17.0, *) {
			self.containerBackground(.fill.tertiary, for: .widget)
		} else {
			self.padding().background(Color(UIColor.secondarySystemBackground))
		}
	}
}

struct XSignHomeWidgetView: View {
	@Environment(\.widgetFamily) private var family
	let entry: XSignEntry
	
	private var daysLeft: Int? {
		guard let exp = entry.snapshot?.certificateExpiration else { return nil }
		return Calendar.current.dateComponents([.day], from: Date(), to: exp).day
	}
	
	private var certColor: Color {
		if entry.snapshot?.certificateRevoked == true { return .red }
		guard let d = daysLeft else { return .secondary }
		if d < 0 { return .red }
		if d <= 7 { return .orange }
		return .green
	}
	
	private var certText: String {
		if entry.snapshot?.certificateRevoked == true { return "Bị thu hồi" }
		guard let d = daysLeft else { return "—" }
		if d < 0 { return "Đã hết hạn" }
		return "\(d) ngày"
	}
	
	private var certBlock: some View {
		VStack(alignment: .leading, spacing: 4) {
			Label("Chứng chỉ", systemImage: "checkmark.seal.fill")
				.font(.caption)
				.foregroundStyle(.secondary)
			Text(certText)
				.font(.title2.bold())
				.foregroundStyle(certColor)
				.minimumScaleFactor(0.6)
				.lineLimit(1)
			if let name = entry.snapshot?.certificateName, !name.isEmpty {
				Text(name)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			if let exp = entry.snapshot?.certificateExpiration {
				Text("Hết hạn " + exp.formatted(date: .abbreviated, time: .omitted))
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
	}
	
	private var recentBlock: some View {
		VStack(alignment: .leading, spacing: 6) {
			Label("Ký gần đây", systemImage: "clock.fill")
				.font(.caption)
				.foregroundStyle(.secondary)
			let apps = Array((entry.snapshot?.recentApps ?? []).prefix(3))
			if apps.isEmpty {
				Text("Chưa có ứng dụng nào")
					.font(.caption)
					.foregroundStyle(.secondary)
			} else {
				ForEach(apps, id: \.self) { app in
					HStack {
						Text(app.name).font(.subheadline).lineLimit(1)
						Spacer(minLength: 4)
						Text(app.date, style: .relative)
							.font(.caption2)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
				}
			}
		}
	}
	
	var body: some View {
		Group {
			if entry.snapshot == nil {
				VStack(spacing: 6) {
					Image(systemName: "signature").font(.title2)
					Text("Mở XSign để đồng bộ dữ liệu")
						.font(.caption)
						.multilineTextAlignment(.center)
						.foregroundStyle(.secondary)
				}
			} else if family == .systemSmall {
				certBlock.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			} else {
				HStack(alignment: .top, spacing: 16) {
					certBlock.frame(maxWidth: .infinity, alignment: .topLeading)
					recentBlock.frame(maxWidth: .infinity, alignment: .topLeading)
				}
			}
		}
		.xsignWidgetBackground()
	}
}

struct XSignHomeWidget: Widget {
	var body: some WidgetConfiguration {
		StaticConfiguration(kind: "XSignHomeWidget", provider: XSignProvider()) { entry in
			XSignHomeWidgetView(entry: entry)
		}
		.configurationDisplayName("XSign")
		.description("Hạn chứng chỉ và các ứng dụng đã ký gần đây.")
		.supportedFamilies([.systemSmall, .systemMedium])
	}
}
