//
//  XSignQuickSigner.swift
//  XSign
//
//  Luồng "Ký & cài" một chạm: ký bằng chứng chỉ được chọn, cập nhật Live Activity,
//  rồi tự động mở luồng cài đặt Semi Local OTA (InstallPreviewView) khi ký xong 100%.
//

import Foundation

extension Notification.Name {
	/// Yêu cầu LibraryView mở InstallPreviewView cho ứng dụng vừa ký gần nhất.
	static let xsignInstallApp = Notification.Name("XSign.installApp")
}

enum XSignQuickSigner {
	private final class ProgressBox {
		var value: Double = 0.05
	}
	
	/// Ký rồi tự động cài. `onFinish` được gọi trên main thread.
	static func signAndInstall(
		_ app: AppInfoPresentable,
		certificate: CertificatePair?,
		options: Options = OptionsManager.shared.options,
		onFinish: ((Error?) -> Void)? = nil
	) {
		let manager = XSignLiveActivityManager.shared
		let box = ProgressBox()
		let appName = app.name ?? "XSign"
		let certName: String = {
			guard let certificate else { return xsignT("Mặc định", "Default") }
			return certificate.nickname ?? Storage.shared.getProvisionFileDecoded(for: certificate)?.Name ?? .localized("Unknown")
		}()
		manager.signingStarted(appName: appName, certName: certName)
		
		// FR.signPackageFile không báo tiến độ chi tiết, nên tiến độ tiệm cận 90%
		// rồi nhảy lên 100% đúng lúc ký và đóng gói xong.
		let timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
			box.value = min(0.9, box.value + (0.9 - box.value) * 0.15)
			// Ước lượng bước 1...5 theo tiến độ (bước 6 = hoàn tất).
			let step = min(5, 1 + Int(box.value / 0.9 * 5))
			manager.signingStep(index: step, progress: box.value)
		}
		
		FR.signPackageFile(
			app,
			using: options,
			icon: nil,
			certificate: certificate
		) { error in
			DispatchQueue.main.async {
				timer.invalidate()
				if let error {
					manager.signingFailed(message: error.localizedDescription)
					onFinish?(error)
					return
				}
				manager.signingStep(index: 6, progress: 1.0)
				manager.signingFinished(
					appName: appName,
					signedAppID: XSignLiveActivityManager.latestSignedAppID(),
					autoInstall: true
				)
				onFinish?(nil)
				requestInstall()
			}
		}
	}
	
	/// Mở luồng cài đặt cho ứng dụng vừa ký. Có độ trễ nhỏ để CoreData lưu xong
	/// và mọi sheet/fullScreenCover đang đóng kịp kết thúc animation.
	static func requestInstall(after delay: TimeInterval = 0.35) {
		DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
			NotificationCenter.default.post(name: .xsignInstallApp, object: nil)
		}
	}
}
