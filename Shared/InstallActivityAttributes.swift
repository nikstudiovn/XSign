//
//  InstallActivityAttributes.swift
//  XSign
//
//  Shared between the XSign app target and the XSignLiveActivity
//  widget extension. Both targets compile this exact file, so the
//  ActivityKit payload always has the same shape on both sides.
//
//  Keep the payload small: ActivityKit rejects activities whose data is
//  larger than 4 KB. The optional icon is a tiny JPEG thumbnail.
//

#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(ActivityKit)

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct InstallActivityAttributes: ActivityAttributes {
	/// Static data, set once when the Live Activity starts.
	var appName: String
	var appVersion: String
	var bundleIdentifier: String
	/// Small JPEG thumbnail of the app icon (a few KB at most), or nil.
	var iconData: Data?
	
	/// Dynamic data, sent with every update.
	struct ContentState: Codable, Hashable {
		var phase: InstallActivityPhase
		/// Overall progress, 0...1, rounded to whole percents.
		var progress: Double
		/// Short error text when `phase == .failed`.
		var message: String?
	}
}

enum InstallActivityPhase: String, Codable, Hashable {
	case packaging
	/// The iOS install prompt is on screen and needs the user to tap Install.
	case waiting
	case sending
	case installing
	case completed
	case failed
	
	var isFinal: Bool {
		self == .completed || self == .failed
	}
}

#endif
