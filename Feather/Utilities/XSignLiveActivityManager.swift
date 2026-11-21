//
//  XSignLiveActivityManager.swift
//  XSign
//
//  Quản lý Live Activity / Dynamic Island cho các mốc Đang ký → Đang gửi → Đang cài,
//  và đồng bộ dữ liệu cho Widget màn hình chính.
//

import Foundation
import CoreData
import UIKit
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

final class XSignLiveActivityManager {
	static let shared = XSignLiveActivityManager()
	
	enum Stage {
		case signing, sending, installing, completed, failed
	}
	
	private var _activity: Any?
	
	// MARK: Live Activity
	func start(appName: String, stage: Stage = .signing, progress: Double = 0.1) {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
		
		// Kết thúc activity cũ (nếu có) trước khi tạo mới.
		_finishCurrent(immediately: true)
		
		let attributes = XSignActivityAttributes(appName: appName)
		let state = XSignActivityAttributes.ContentState(stage: _map(stage), progress: progress)
		do {
			_activity = try Activity.request(
				attributes: attributes,
				content: ActivityContent(state: state, staleDate: nil),
				pushType: nil
			)
		} catch {
			_activity = nil
		}
		#endif
	}
	
	func update(stage: Stage, progress: Double) {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		guard let activity = _activity as? Activity<XSignActivityAttributes> else { return }
		
		if stage == .completed || stage == .failed {
			end(stage: stage)
			return
		}
		
		let state = XSignActivityAttributes.ContentState(stage: _map(stage), progress: progress)
		Task {
			await activity.update(ActivityContent(state: state, staleDate: nil))
		}
		#endif
	}
	
	func end(stage: Stage) {
		#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
		guard #available(iOS 16.2, *) else { return }
		guard let activity = _activity as? Activity<XSignActivityAttributes> else { return }
		_activity = nil
		
		let state = XSignActivityAttributes.ContentState(
			stage: _map(stage),
			progress: stage == .completed ? 1.0 : 0
		)
		Task {
			await activity.end(
				ActivityContent(state: state, staleDate: nil),
				dismissalPolicy: .after(Date().addingTimeInterval(8))
			)
		}
		#endif
	}
	
	#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
	@available(iOS 16.2, *)
	private func _map(_ stage: Stage) -> XSignActivityAttributes.ContentState.Stage {
		switch stage {
		case .signing: return .signing
		case .sending: return .sending
		case .installing: return .installing
		case .completed: return .completed
		case .failed: return .failed
		}
	}
	
	@available(iOS 16.2, *)
	private func _finishCurrent(immediately: Bool) {
		guard let activity = _activity as? Activity<XSignActivityAttributes> else { return }
		_activity = nil
		Task {
			await activity.end(nil, dismissalPolicy: .immediate)
		}
	}
	#endif
	
	// MARK: Widget snapshot
	/// Ghi hạn chứng chỉ và các app ký gần đây vào App Group, rồi yêu cầu widget reload.
	func refreshWidgetSnapshot() {
		let context = Storage.shared.context
		context.perform {
			let certRequest = NSFetchRequest<NSManagedObject>(entityName: "CertificatePair")
			certRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
			let certs = (try? context.fetch(certRequest)) ?? []
			
			let index = UserDefaults.standard.integer(forKey: "XSign.selectedCert")
			let cert = (index >= 0 && index < certs.count) ? certs[index] : certs.first
			
			let signedRequest = NSFetchRequest<NSManagedObject>(entityName: "Signed")
			signedRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
			signedRequest.fetchLimit = 5
			let signed = (try? context.fetch(signedRequest)) ?? []
			
			let snapshot = XSignWidgetSnapshot(
				certificateName: cert?.value(forKey: "nickname") as? String,
				certificateExpiration: cert?.value(forKey: "expiration") as? Date,
				certificateRevoked: (cert?.value(forKey: "revoked") as? Bool) ?? false,
				recentApps: signed.map {
					XSignWidgetSnapshot.RecentApp(
						name: ($0.value(forKey: "name") as? String) ?? "Unknown",
						version: ($0.value(forKey: "version") as? String) ?? "",
						date: ($0.value(forKey: "date") as? Date) ?? Date()
					)
				},
				updatedAt: Date()
			)
			snapshot.save()
			
			#if canImport(WidgetKit)
			WidgetCenter.shared.reloadAllTimelines()
			#endif
		}
	}
}
