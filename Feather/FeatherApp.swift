//
//  FeatherApp.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import Nuke
import IDeviceSwift
import OSLog

@main
struct FeatherApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	let heartbeat = HeartbeatManager.shared
	
	@StateObject var downloadManager = DownloadManager.shared
	let storage = Storage.shared
@State private var _showLaunchOverlay = true
@Environment(\.accessibilityReduceMotion) private var _reduceMotion
	@AppStorage("XSign.appLanguage") private var _appLanguage: String = "system"
	
	init() {
		XSignLanguage.install()
	}
	
	var body: some Scene {
		WindowGroup {
ZStack {
			VStack {
				DownloadHeaderView(downloadManager: downloadManager)
					.transition(.move(edge: .top).combined(with: .opacity))
				VariedTabbarView()
					.id(_appLanguage)
				.environment(\.managedObjectContext, storage.context)
					.onOpenURL(perform: _handleURL)
					.transition(.move(edge: .top).combined(with: .opacity))
			}
			.animation(.smooth, value: downloadManager.manualDownloads.description)
			.modifier(XSignOnboardingPresenter())
			.onReceive(NotificationCenter.default.publisher(for: .heartbeatInvalidHost)) { _ in
				DispatchQueue.main.async {
					UIAlertController.showAlertWithOk(
						title: "InvalidHostID",
						message: .localized("Your pairing file is invalid and is incompatible with your device, please import a valid pairing file.")
					)
				}
			}
			// dear god help me
			.onAppear {
				if let style = UIUserInterfaceStyle(rawValue: UserDefaults.standard.integer(forKey: "XSign.userInterfaceStyle")) {
					UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
				}
				
				UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: UserDefaults.standard.string(forKey: "XSign.userTintColor") ?? "#848ef9"))
			}
.scaleEffect(_showLaunchOverlay && !_reduceMotion ? 0.97 : 1.0)
.animation(.easeOut(duration: 0.42), value: _showLaunchOverlay)
if _showLaunchOverlay {
XSignLaunchOverlayView(reduceMotion: _reduceMotion) {
_showLaunchOverlay = false
}
.zIndex(999)
}
}
			.environment(\.locale, _appLanguage == "system" ? .current : Locale(identifier: _appLanguage))
		}
	}
	
	private func _handleURL(_ url: URL) {
		if let scheme = url.scheme?.lowercased(), ["xsign", "feather"].contains(scheme) {
			/// Live Activity / Dynamic Island: install/<signedAppID>, reinstall/<id>, share/<id>,
			/// certificates, files?path=, live-action/<command>. Xem XSignDeepLinkRouter.
			if MainActor.assumeIsolated({ XSignDeepLinkRouter.handle(url) }) {
				return
			}
			/// xsign://import-certificate?p12=<base64>&mobileprovision=<base64>&password=<base64>
			if url.host == "import-certificate" {
				guard
					let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
					let queryItems = components.queryItems
				else {
					return
				}
				
				func queryValue(_ name: String) -> String? {
					queryItems.first(where: { $0.name == name })?.value?.removingPercentEncoding
				}
				
				guard
					let p12Base64 = queryValue("p12"),
					let provisionBase64 = queryValue("mobileprovision"),
					let passwordBase64 = queryValue("password"),
					let passwordData = Data(base64Encoded: passwordBase64),
					let password = String(data: passwordData, encoding: .utf8)
				else {
					return
				}
				
				let generator = UINotificationFeedbackGenerator()
				generator.prepare()
				
				guard
					let p12URL = FileManager.default.decodeAndWrite(base64: p12Base64, pathComponent: ".p12"),
					let provisionURL = FileManager.default.decodeAndWrite(base64: provisionBase64, pathComponent: ".mobileprovision"),
					FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL)
				else {
					generator.notificationOccurred(.error)
					return
				}
				
				FR.handleCertificateFiles(
					p12URL: p12URL,
					provisionURL: provisionURL,
					p12Password: password
				) { error in
					if let error = error {
						UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
					} else {
						generator.notificationOccurred(.success)
					}
				}
				
				return
			}
			/// xsign://export-certificate?callback_template=<template>
			/// ?callback_template=: This is how we callback to the application requesting the certificate, this will be a url scheme
			/// 	example: livecontainer%3A%2F%2Fcertificate%3Fcert%3D%24%28BASE64_CERT%29%26password%3D%24%28PASSWORD%29
			/// 	decoded: livecontainer://certificate?cert=$(BASE64_CERT)&password=$(PASSWORD)
			/// $(BASE64_CERT) and $(PASSWORD) must be presenting in the callback template so we can replace them with the proper content
			if url.host == "export-certificate" {
				guard
					let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
				else {
					return
				}
				
				let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name.lowercased()] = $1.value } ?? [:]
				guard let callbackTemplate = queryItems["callback_template"]?.removingPercentEncoding else { return }
				
				FR.exportCertificateAndOpenUrl(using: callbackTemplate)
			}
			/// xsign://source/<url>
			if let fullPath = url.validatedScheme(after: "/source/") {
				FR.handleSource(fullPath) { }
			}
			/// xsign://install/<url.ipa>
			if
				let fullPath = url.validatedScheme(after: "/install/"),
				let downloadURL = URL(string: fullPath)
			{
				UIAlertController.showAlertWithCancel(
					title: .localized("Install"),
					message: .localized("Do you want to download and install this file?") + "\n\n\(downloadURL)",
					actions: [
						UIAlertAction(title: .localized("Install"), style: .default) { _ in
							_ = DownloadManager.shared.startDownload(from: downloadURL)
						}
					]
				)
			}
		} else {
			if url.pathExtension == "ipa" || url.pathExtension == "tipa" {
				if FileManager.default.isFileFromFileProvider(at: url) {
					guard url.startAccessingSecurityScopedResource() else { return }
					FR.handlePackageFile(url) { error in
if error == nil {
DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
NotificationCenter.default.post(name: Notification.Name("XSign.importedIPA"), object: nil)
}
}
											  }
				} else {
					FR.handlePackageFile(url) { error in
if error == nil {
DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
NotificationCenter.default.post(name: Notification.Name("XSign.importedIPA"), object: nil)
}
}
											  }
				}
				
				return
			}
		}
	}
}

class AppDelegate: NSObject, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
		XSignLanguage.install()
		_createPipeline()
		_createDocumentsDirectories()
		ResetView.clearWorkCache()
		_addDefaultCertificates()
		XSignLiveActivityManager.shared.prepareOnLaunch()
		return true
	}
	
	private func _createPipeline() {
		DataLoader.sharedUrlCache.diskCapacity = 0
		
		let pipeline = ImagePipeline {
			let dataLoader: DataLoader = {
				let config = URLSessionConfiguration.default
				config.urlCache = nil
				return DataLoader(configuration: config)
			}()
			let dataCache = try? DataCache(name: "XSign.datacache") // disk cache
			let imageCache = Nuke.ImageCache() // memory cache
			dataCache?.sizeLimit = 500 * 1024 * 1024
			imageCache.costLimit = 100 * 1024 * 1024
			$0.dataCache = dataCache
			$0.imageCache = imageCache
			$0.dataLoader = dataLoader
			$0.dataCachePolicy = .automatic
			$0.isStoringPreviewsInMemoryCache = false
		}
		
		ImagePipeline.shared = pipeline
	}
	
	private func _createDocumentsDirectories() {
		let fileManager = FileManager.default

		let directories: [URL] = [
			fileManager.archives,
			fileManager.certificates,
			fileManager.signed,
			fileManager.unsigned
		]
		
		for url in directories {
			try? fileManager.createDirectoryIfNeeded(at: url)
		}
	}
	
	private func _addDefaultCertificates() {
		guard
			UserDefaults.standard.bool(forKey: "XSign.didImportDefaultCertificates") == false,
			let signingAssetsURL = Bundle.main.url(forResource: "signing-assets", withExtension: nil)
		else {
			return
		}
		
		do {
			let folderContents = try FileManager.default.contentsOfDirectory(
				at: signingAssetsURL,
				includingPropertiesForKeys: nil,
				options: .skipsHiddenFiles
			)
			
			for folderURL in folderContents {
				guard folderURL.hasDirectoryPath else { continue }
				
				let certName = folderURL.lastPathComponent
				
				let p12Url = folderURL.appendingPathComponent("cert.p12")
				let provisionUrl = folderURL.appendingPathComponent("cert.mobileprovision")
				let passwordUrl = folderURL.appendingPathComponent("cert.txt")
				
				guard
					FileManager.default.fileExists(atPath: p12Url.path),
					FileManager.default.fileExists(atPath: provisionUrl.path),
					FileManager.default.fileExists(atPath: passwordUrl.path)
				else {
					Logger.misc.warning("Skipping \(certName): missing required files")
					continue
				}
				
				let password = try String(contentsOf: passwordUrl, encoding: .utf8)
				
				FR.handleCertificateFiles(
					p12URL: p12Url,
					provisionURL: provisionUrl,
					p12Password: password,
					certificateName: certName,
					isDefault: true
				) { _ in
					
				}
			}
			UserDefaults.standard.set(true, forKey: "XSign.didImportDefaultCertificates")
		} catch {
			Logger.misc.error("Failed to list signing-assets: \(error)")
		}
	}

}

// MARK: - Launch Overlay
private struct XSignLaunchOverlayView: View {
	let reduceMotion: Bool
let onFinished: () -> Void

@State private var _iconScale: CGFloat = 0.72
@State private var _iconOpacity: Double = 0
@State private var _titleOpacity: Double = 0
@State private var _titleOffset: CGFloat = 10
@State private var _shimmerOffset: CGFloat = -160
@State private var _isExiting = false
@State private var _overlayOpacity: Double = 1
@State private var _overlayScale: CGFloat = 1.0
    private var _launchColors: (glow1: Color, glow2: Color, accent: Color) {
		let altIcon = UIApplication.shared.alternateIconName
		switch altIcon {
case "V2Mac": return (Color.purple, Color.indigo, Color(red: 0.72, green: 0.48, blue: 1.0))
		case "V1": return (Color.cyan, Color.blue, Color.cyan)
case "V1Mac": return (Color.white, Color(white: 0.72), Color(white: 0.88))
case "V0": return (Color(red: 0.16, green: 0.84, blue: 0.60), Color.teal, Color.mint)
case "Donor": return (Color(white: 0.65), Color(white: 0.35), Color(white: 0.78))
case "Wing": return (Color(red: 0.95, green: 0.22, blue: 0.32), Color.red, Color(red: 1.0, green: 0.35, blue: 0.42))
default: return (Color.cyan, Color(red: 0.22, green: 0.56, blue: 0.98), Color(red: 0.35, green: 0.78, blue: 1.0))
}
	}
	
var body: some View {
ZStack {
LinearGradient(
colors: [
Color(red: 0.04, green: 0.05, blue: 0.10),
Color(red: 0.07, green: 0.09, blue: 0.17),
Color(red: 0.03, green: 0.04, blue: 0.08)
],
startPoint: .topLeading,
endPoint: .bottomTrailing
)
.ignoresSafeArea()

RadialGradient(
colors: [
_launchColors.glow1.opacity(0.28),
_launchColors.glow2.opacity(0.20),
Color.clear
],
center: .center,
startRadius: 12,
endRadius: 240
)
.blur(radius: 28)
.ignoresSafeArea()

VStack(spacing: 18) {
_iconContainer
.scaleEffect(reduceMotion ? 1.0 : _iconScale)
.opacity(_iconOpacity)

Text("XSign")
.font(.system(size: 28, weight: .bold, design: .rounded))
.tracking(1.6)
.foregroundStyle(
LinearGradient(
colors: [
.white,
_launchColors.accent
],
startPoint: .topLeading,
endPoint: .bottomTrailing
)
)
.opacity(_titleOpacity)
.offset(y: reduceMotion ? 0 : _titleOffset)
}
}
.scaleEffect(reduceMotion ? 1.0 : _overlayScale)
.opacity(_overlayOpacity)
.allowsHitTesting(false)
.onAppear {
_runAnimation()
}
}
    @ViewBuilder
private var _activeIconView: some View {
if let altIcon = UIApplication.shared.alternateIconName,
let uiImage = UIImage(named: altIcon) {
Image(uiImage: uiImage)
.resizable()
.scaledToFill()
.frame(width: 104, height: 104)
.clipShape(RoundedRectangle(cornerRadius: 23.4, style: .continuous))
} else {
FRAppIconView(size: 104)
}
}
	
@ViewBuilder
private var _iconContainer: some View {
let baseIcon = _activeIconView
.overlay {
if !reduceMotion {
LinearGradient(
colors: [
.clear,
.white.opacity(0.35),
.clear
],
startPoint: .topLeading,
endPoint: .bottomTrailing
)
.frame(width: 56)
.rotationEffect(.degrees(22))
.offset(x: _shimmerOffset)
.mask(RoundedRectangle(cornerRadius: 26, style: .continuous))
}
}
.padding(6)

if #available(iOS 26, *) {
baseIcon
.glassEffect(.regular, in: .rect(cornerRadius: 26))
.shadow(color: _launchColors.accent.opacity(0.25), radius: 24, y: 10)
} else {
baseIcon
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
.overlay(
RoundedRectangle(cornerRadius: 26, style: .continuous)
.strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
)
.shadow(color: _launchColors.accent.opacity(0.25), radius: 24, y: 10)
}
}

private func _runAnimation() {
if reduceMotion {
_iconOpacity = 1
_titleOpacity = 1
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
withAnimation(.easeInOut(duration: 0.45)) {
_overlayOpacity = 0
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
onFinished()
}
}
return
}

withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
_iconScale = 1.0
_iconOpacity = 1.0
}

withAnimation(.easeOut(duration: 0.45).delay(0.14)) {
_titleOpacity = 1.0
_titleOffset = 0
}

withAnimation(.easeInOut(duration: 0.75).delay(0.22)) {
_shimmerOffset = 160
}

DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
guard !_isExiting else { return }
_isExiting = true
withAnimation(.easeOut(duration: 0.35)) {
_overlayScale = 1.12
_overlayOpacity = 0
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
onFinished()
}
}
}
}

// MARK: - Runtime language override
/// `.localized(...)` / `NSLocalizedString` mặc định dùng ngôn ngữ mà iOS nạp cho
/// Bundle.main lúc mở app, nên khi đổi ngôn ngữ trong XSign (Cài đặt hoặc màn chào
/// mừng) các chuỗi này vẫn giữ ngôn ngữ cũ tới khi khởi động lại app.
/// Lớp này chuyển việc tra chuỗi sang đúng .lproj theo "XSign.appLanguage".
enum XSignLanguage {
	private static let _lock = NSLock()
	private static var _cache: (key: String, bundle: Bundle?)?
	private static let _installOnce: Void = {
		object_setClass(Bundle.main, XSignLocalizedBundle.self)
	}()
	
	static func install() {
		_ = _installOnce
	}
	
	/// Bundle .lproj ứng với ngôn ngữ đang chọn (nil = dùng mặc định của hệ thống).
	static var bundle: Bundle? {
		let lang = UserDefaults.standard.string(forKey: "XSign.appLanguage") ?? "system"
		let code: String?
		if lang == "system" {
			code = Bundle.preferredLocalizations(
				from: Bundle.main.localizations,
				forPreferences: Locale.preferredLanguages
			).first
		} else {
			code = lang
		}
		guard let code else { return nil }
		
		_lock.lock()
		defer { _lock.unlock() }
		if let cache = _cache, cache.key == code {
			return cache.bundle
		}
		var resolved: Bundle? = nil
		if let path = Bundle.main.path(forResource: code, ofType: "lproj") {
			resolved = Bundle(path: path)
		}
		_cache = (code, resolved)
		return resolved
	}
}

private final class XSignLocalizedBundle: Bundle {
	override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
		if let bundle = XSignLanguage.bundle, bundle !== self {
			return bundle.localizedString(forKey: key, value: value, table: tableName)
		}
		return super.localizedString(forKey: key, value: value, table: tableName)
	}
}

func xsignT(_ vi: String, _ en: String) -> String {
let lang = UserDefaults.standard.string(forKey: "XSign.appLanguage") ?? "system"
switch lang {
case "en": return en
case "vi": return vi
default: return Locale.preferredLanguages.first?.hasPrefix("vi") == true ? vi : en
}
}
struct XSignLiquidGlassBackdrop: View {
	var body: some View {
ZStack {
Color.black
RadialGradient(colors: [Color.cyan.opacity(0.16), Color.clear], center: .topLeading, startRadius: 20, endRadius: 420)
RadialGradient(colors: [Color.indigo.opacity(0.18), Color.clear], center: .bottomTrailing, startRadius: 20, endRadius: 460)
}
.ignoresSafeArea()
}
}

struct XSignLiquidGlassRowBackground: View {
	var body: some View {
		if #available(iOS 26, *) {
			Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 14))
		} else {
			RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial)
		}
	}
}

