//
//  OnboardingView.swift
//  XSign
//
//  Màn hình chào mừng hiển thị một lần khi mở app lần đầu.
//

import SwiftUI

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
		.init(id: 0, icon: "signature",
			  title: "Chào mừng đến với XSign",
			  message: "XSign giúp bạn ký và cài đặt ứng dụng IPA ngay trên thiết bị, không cần máy tính."),
		.init(id: 1, icon: "person.text.rectangle",
			  title: "Nhập chứng chỉ",
			  message: "Vào Cài đặt › Chứng chỉ để thêm file .p12 và .mobileprovision. Bạn cũng có thể nhập trực tiếp file .zip chứa chứng chỉ."),
		.init(id: 2, icon: "globe.desk",
			  title: "Thêm nguồn hoặc IPA",
			  message: "Thêm nguồn ứng dụng ở tab Nguồn, hoặc nhập file IPA từ tab Thư viện và Thư mục."),
		.init(id: 3, icon: "bolt.fill",
			  title: "Ký & cài 1 chạm",
			  message: "Chọn một ứng dụng trong Thư viện, dùng nút Ký & cài để hoàn tất mọi bước chỉ bằng một lần chạm.")
	]
	
	private var _isLast: Bool { _page == _pages.count - 1 }
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Spacer()
				Button("Bỏ qua") {
					_finish()
				}
				.padding()
				.opacity(_isLast ? 0 : 1)
				.disabled(_isLast)
			}
			
			TabView(selection: $_page) {
				ForEach(_pages) { page in
					VStack(spacing: 24) {
						Image(systemName: page.icon)
							.font(.system(size: 76, weight: .regular))
							.foregroundStyle(Color.accentColor)
							.padding(.top, 40)
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
				Text(_isLast ? "Bắt đầu" : "Tiếp tục")
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
