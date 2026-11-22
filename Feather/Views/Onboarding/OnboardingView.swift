//
//  OnboardingView.swift
//  XSign
//
//  Màn hình chào mừng hiển thị một lần khi mở app lần đầu.
//

import SwiftUI
import UIKit
struct OnboardingView: View {
	static let storageKey = "XSign.hasSeenOnboarding"
	
	@Binding var isPresented: Bool
	@State private var _page = 0
	
	private struct Page: Identifiable {
		let id: Int
		let icon: String
		let title: String
		let message: String
	}
	
	private let _pages: [Page] = [
		.init(id: 0, icon: "checkmark.seal.fill",
			  title: xsignT("Chào mừng đến với XSign", "Welcome to XSign"),
			  message: xsignT("XSign giúp bạn ký và cài đặt ứng dụng IPA ngay trên thiết bị, không cần máy tính.", "XSign lets you sign and install IPA apps directly on your device, no computer required.")),
		.init(id: 1, icon: "globe",
			  title: xsignT("Nhập chứng chỉ", "Import Certificate"),
			  message: xsignT("Vào Cài đặt › Chứng chỉ để thêm file .p12 và .mobileprovision. Bạn cũng có thể nhập trực tiếp file .zip chứa chứng chỉ.", "Go to Settings › Certificates to add .p12 and .mobileprovision files. You can also import a .zip certificate file directly.")),
		.init(id: 2, icon: "app.badge.checkmark",
			  title: xsignT("Thêm nguồn hoặc IPA", "Add Sources or IPA"),
			  message: xsignT("Thêm nguồn ứng dụng ở tab Nguồn, hoặc nhập file IPA từ tab Thư viện và Thư mục.", "Add app sources in the Sources tab, or import IPA files from the Library and Files tabs.")),
		.init(id: 3, icon: "folder",
			  title: xsignT("Ký & cài 1 chạm", "1-Tap Sign & Install"),
			  message: xsignT("Chọn một ứng dụng trong Thư viện, dùng nút Ký & cài để hoàn tất mọi bước chỉ bằng một lần chạm.", "Select an app in Library and tap Sign & Install to complete everything in one tap."))
	]
	
	private var _isLast: Bool { _page == _pages.count - 1 }
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Spacer()
				Button(xsignT("Bỏ qua", "Skip")) {
					_finish()
				}
				.padding()
				.opacity(_isLast ? 0 : 1)
				.disabled(_isLast)
			}
			
			TabView(selection: $_page) {
				ForEach(_pages) { page in
					VStack(spacing: 24) {
						if page.id == 0 { if let alt = UIApplication.shared.alternateIconName, let uiImg = UIImage(named: alt) { Image(uiImage: uiImg).resizable().scaledToFit().frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).padding(.top, 40) } else { FRAppIconView(size: 88).padding(.top, 40) } } else { Image(systemName: page.icon)
							.font(.system(size: 76, weight: .regular))
							.foregroundStyle(Color.accentColor)
							.padding(.top, 40) }
						Text(page.title)
							.font(.title.bold())
							.multilineTextAlignment(.center)
						Text(page.message)
							.font(.body)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
							.padding(.horizontal, 32)
						Spacer()
					}
					.tag(page.id)
				}
			}
			.tabViewStyle(.page(indexDisplayMode: .always))
			.indexViewStyle(.page(backgroundDisplayMode: .always))
			
			Button {
				if _isLast {
					_finish()
				} else {
					withAnimation { _page += 1 }
				}
			} label: {
				Text(_isLast ? xsignT("Bắt đầu", "Get Started") : xsignT("Tiếp tục", "Continue"))
					.font(.headline)
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
					.foregroundStyle(.white)
			}
			.padding(.horizontal, 24)
			.padding(.vertical, 20)
		}
		.interactiveDismissDisabled()
	}
	
	private func _finish() {
		UserDefaults.standard.set(true, forKey: Self.storageKey)
		isPresented = false
	}
}
