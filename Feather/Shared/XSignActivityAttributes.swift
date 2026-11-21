//
//  XSignActivityAttributes.swift
//  XSign
//
//  Dùng chung giữa app và XSignWidget extension (Live Activity / Dynamic Island).
//

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct XSignActivityAttributes: ActivityAttributes {
	struct ContentState: Codable, Hashable {
		enum Stage: String, Codable, Hashable {
			case signing
			case sending
			case installing
			case completed
			case failed
		}
		
		var stage: Stage
		var progress: Double
	}
	
	var appName: String
}
#endif
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
