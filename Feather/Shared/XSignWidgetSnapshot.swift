//
//  XSignWidgetSnapshot.swift
//  XSign
//
//  Dữ liệu app ghi ra App Group để Widget màn hình chính đọc.
//  Nếu App Group không khả dụng (ví dụ ký bằng chứng chỉ không có group),
//  save() bỏ qua và widget hiển thị trạng thái "chưa có dữ liệu".
//

import Foundation

struct XSignWidgetSnapshot: Codable {
	struct RecentApp: Codable, Hashable {
		var name: String
		var version: String
		var date: Date
	}
	
	static let appGroupID = "group.com.nikstudiovn.xsign"
	private static let key = "XSign.widgetSnapshot"
	
	var certificateName: String?
	var certificateExpiration: Date?
	var certificateRevoked: Bool
	var recentApps: [RecentApp]
	var updatedAt: Date
	
	private static var _defaults: UserDefaults? {
		guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
			return nil
		}
		return UserDefaults(suiteName: appGroupID)
	}
	
	static func load() -> XSignWidgetSnapshot? {
		guard
			let data = _defaults?.data(forKey: key),
			let snapshot = try? JSONDecoder().decode(XSignWidgetSnapshot.self, from: data)
		else {
			return nil
		}
		return snapshot
	}
	
	func save() {
		guard
			let defaults = Self._defaults,
			let data = try? JSONEncoder().encode(self)
		else {
			return
		}
		defaults.set(data, forKey: Self.key)
	}
}
