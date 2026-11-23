//
//  XSignDeepLinkRouter.swift
//  XSign
//
//  Deep link mới cho Live Activity / Dynamic Island:
//    xsign://install/<signedAppID>     → cài đặt ngay (Bán cục bộ) ứng dụng đã ký
//    xsign://reinstall/<appID>         → mở lại hộp thoại cài đặt của máy chủ đang chạy
//    xsign://share/<signedAppID>       → bảng chia sẻ tệp .ipa đã ký
//    xsign://certificates              → mục Chứng chỉ
//    xsign://files?path=<encoded>      → tab Thư mục tại đường dẫn đích
//    xsign://live-action/<command>     → dự phòng iOS 16 cho các nút AppIntent
//
//  `xsign://install/<url.ipa>` (tải & cài từ URL) vẫn do XSignApp xử lý như cũ:
//  router chỉ nhận install/<id> khi <id> là uuid của một ứng dụng đã ký.
//

import SwiftUI
import UIKit
import CoreData
import NimbleViews
import NimbleExtensions
import IDeviceSwift

/// Luôn chạy trên main thread (onOpenURL). XSignApp gọi qua MainActor.assumeIsolated.
@MainActor
enum XSignDeepLinkRouter {
	private final class WeakHost {
		weak var value: UIViewController?
	}
	
	private static let _installHost = WeakHost()
	private static var _didObserveStop = false
	
	/// Trả về true nếu URL đã được xử lý.
	static func handle(_ url: URL) -> Bool {
		guard let scheme = url.scheme?.lowercased(), ["xsign", "xsign"].contains(scheme) else { return false }
		let host = (url.host ?? "").lowercased()
		let identifier = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
		
		switch host {
		case "live-action":
			guard let command = XSignLiveActivityCommand(rawValue: identifier) else { return true }
			XSignLiveActivityManager.shared.handle(command)
			return true
			
		case "install":
			// Giữ nguyên xsign://install/<url.ipa> cho XSignApp.
			guard _looksLikeAppID(identifier), let signed = _signedApp(uuid: identifier) else { return false }
			_presentInstall(for: signed)
			return true
			
		case "reinstall":
			if let active = XSignLiveActivityManager.shared.activeInstallAppID,
			   identifier.isEmpty || identifier == active {
				NotificationCenter.default.post(name: .xsignReinstallRequested, object: active)
			} else if let signed = _signedApp(uuid: identifier) {
				_presentInstall(for: signed)
			}
			return true
			
		case "share":
			if let signed = _signedApp(uuid: identifier) {
				_share(signed)
			}
			return true
			
		case "certificates":
			_present {
				NBNavigationView(.localized("Certificates")) {
					CertificatesView()
				}
			}
			return true
			
		case "files":
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			let rawPath = components?.queryItems?.first(where: { $0.name == "path" })?.value ?? ""
			let directory = _resolveFolder(rawPath)
			let title = directory.standardizedFileURL == URL.documentsDirectory.standardizedFileURL
				? xsignT("Thư mục", "Files")
				: directory.lastPathComponent
			_present {
				NBNavigationView(title) {
					XSignFolderBrowserView(directory: directory, title: title)
				}
			}
			return true
			
		default:
			return false
		}
	}
	
	// MARK: - Helpers
	
	private static func _looksLikeAppID(_ value: String) -> Bool {
		!value.isEmpty
			&& !value.contains("://")
			&& !value.lowercased().hasPrefix("http")
			&& !value.contains("/")
	}
	
	private static func _signedApp(uuid: String) -> Signed? {
		guard !uuid.isEmpty else { return nil }
		let request = NSFetchRequest<Signed>(entityName: "Signed")
		request.predicate = NSPredicate(format: "uuid == %@", uuid)
		request.fetchLimit = 1
		return (try? Storage.shared.context.fetch(request))?.first
	}
	
	private static func _resolveFolder(_ rawPath: String) -> URL {
		let root = URL.documentsDirectory
		let decoded = rawPath.removingPercentEncoding ?? rawPath
		var isDirectory: ObjCBool = false
		if decoded.hasPrefix("/"),
		   FileManager.default.fileExists(atPath: decoded, isDirectory: &isDirectory),
		   isDirectory.boolValue {
			return URL(fileURLWithPath: decoded, isDirectory: true)
		}
		let relative = decoded.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
		guard !relative.isEmpty, !relative.contains("..") else { return root }
		let candidate = root.appendingPathComponent(relative, isDirectory: true)
		if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
			return candidate
		}
		return root
	}
	
	private static func _presentInstall(for signed: Signed) {
		_observeStopIfNeeded()
		_present(sheetHeight: 220, onPresent: { host in
			_installHost.value = host
		}) {
			InstallPreviewView(app: signed)
		}
	}
	
	private static func _observeStopIfNeeded() {
		guard !_didObserveStop else { return }
		_didObserveStop = true
		NotificationCenter.default.addObserver(
			forName: .xsignStopInstallServerRequested,
			object: nil,
			queue: .main
		) { _ in
			Task { @MainActor in
				XSignDeepLinkRouter._installHost.value?.dismiss(animated: true)
				XSignDeepLinkRouter._installHost.value = nil
			}
		}
	}
	
	private static func _share(_ signed: Signed) {
		Task { @MainActor in
			do {
				let viewModel = InstallerStatusViewModel(isIdevice: false)
				let handler = ArchiveHandler(app: signed, viewModel: viewModel)
				try await handler.move()
				let package = try await handler.archive()
				if let destination = try await handler.moveToArchive(package, shouldOpen: false) {
					UIActivityViewController.show(activityItems: [destination])
				}
			} catch {
				UIAlertController.showAlertWithOk(
					title: xsignT("Lỗi", "Error"),
					message: error.localizedDescription
				)
			}
		}
	}
	
	/// Trình bày bằng UIKit trên view controller trên cùng, để không xung đột với
	/// sheet SwiftUI đang mở ở các tab.
	private static func _present<Content: View>(
		sheetHeight: CGFloat? = nil,
		onPresent: (@MainActor (UIViewController) -> Void)? = nil,
		_ makeContent: @escaping @MainActor () -> Content
	) {
		// Đợi app vào foreground hẳn sau khi mở từ Dynamic Island / Màn hình khoá.
		Task { @MainActor in
			try? await Task.sleep(nanoseconds: 350_000_000)
			guard let top = UIApplication.topViewController() else { return }
			let root = makeContent().environment(\.managedObjectContext, Storage.shared.context)
			let host = UIHostingController(rootView: root)
			if let sheetHeight, let sheet = host.sheetPresentationController {
				sheet.detents = [.custom { _ in sheetHeight }]
				sheet.prefersGrabberVisible = true
			}
			top.present(host, animated: true)
			onPresent?(host)
		}
	}
}
