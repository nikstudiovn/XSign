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
