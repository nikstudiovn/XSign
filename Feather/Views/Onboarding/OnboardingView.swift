//
//  OnboardingView.swift
//  XSign
//
//  Màn hình chào mừng hiển thị một lần khi mở app lần đầu:
//  1) Chọn ngôn ngữ (bắt buộc)  2) Nhập chứng chỉ  3-6) Giới thiệu chức năng.
//  Sau khi chọn ngôn ngữ, các bước còn lại có thể bỏ qua.
//

import SwiftUI
import UIKit
import CoreData

// MARK: - Presenter
/// Gắn ở cấp FeatherApp (bên ngoài view có `.id(_appLanguage)`) để việc đổi
/// ngôn ngữ trong màn chào mừng không làm đóng / reset màn hình này.
struct XSignOnboardingPresenter: ViewModifier {
	@AppStorage(OnboardingView.storageKey) private var _hasSeenOnboarding = false
	@State private var _isPresented = false
	
	func body(content: Content) -> some View {
		content
			.onAppear {
				if !_hasSeenOnboarding {
					_isPresented = true
				}
			}
			.fullScreenCover(isPresented: $_isPresented) {
				OnboardingView(isPresented: $_isPresented)
					.environment(\.managedObjectContext, Storage.shared.context)
			}
	}
}

// MARK: - View
struct OnboardingView: View {
	static let storageKey = "XSign.hasSeenOnboarding"
	
	@Binding var isPresented: Bool
	@AppStorage("XSign.appLanguage") private var _appLanguage: String = "system"
	
	@State private var _page = 0
	@State private var _isForward = true
	@State private var _isAddingCertificate = false
	
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .default
	) private var _certificates: FetchedResults<CertificatePair>
	
	private struct Feature: Identifiable {
		let id: Int
		let icon: String
		let title: String
		let message: String
		let points: [String]
	}
	
	/// Computed để luôn dịch lại theo ngôn ngữ vừa chọn.
	private var _features: [Feature] {
		[
			.init(id: 0, icon: "globe",
				  title: xsignT("Nguồn ứng dụng", "App Sources"),
				  message: xsignT("Duyệt và tải ứng dụng từ các nguồn bạn thêm vào.", "Browse and download apps from the sources you add."),
				  points: [
					xsignT("Thêm nguồn bằng đường dẫn ở tab Nguồn", "Add a source by URL in the Sources tab"),
					xsignT("Tìm kiếm nhanh ứng dụng trên mọi nguồn", "Quickly search apps across all sources"),
					xsignT("Tải về thẳng vào Thư viện", "Download straight into your Library")
				  ]),
			.init(id: 1, icon: "app.badge.checkmark",
				  title: xsignT("Thư viện & ký", "Library & Signing"),
				  message: xsignT("Quản lý IPA và tùy chỉnh trước khi ký.", "Manage your IPAs and customize them before signing."),
				  points: [
					xsignT("Nhập file IPA từ Tệp hoặc tab Thư mục", "Import IPA files from Files or the Files tab"),
					xsignT("Đổi tên, icon, bundle ID, chèn tweak", "Change name, icon, bundle ID, inject tweaks"),
					xsignT("Lưu cấu hình ký thành preset để dùng lại", "Save signing options as presets to reuse")
				  ]),
			.init(id: 2, icon: "bolt.fill",
				  title: xsignT("Ký & cài 1 chạm", "1-Tap Sign & Install"),
				  message: xsignT("Hoàn tất mọi bước chỉ với một lần chạm.", "Finish every step with a single tap."),
				  points: [
					xsignT("Chọn ứng dụng, bấm Ký & cài", "Pick an app and tap Sign & Install"),
					xsignT("Ký hàng loạt nhiều ứng dụng cùng lúc", "Batch-sign multiple apps at once"),
					xsignT("Ký và cài ngay trên thiết bị, không cần máy tính", "Sign and install on-device, no computer needed")
				  ]),
			.init(id: 3, icon: "folder",
				  title: xsignT("Thư mục & tiện ích", "Files & Tools"),
				  message: xsignT("Các công cụ giúp bạn quản lý app gọn gàng hơn.", "Handy tools to keep everything tidy."),
				  points: [
					xsignT("Quản lý tệp, nén và giải nén .zip", "Manage files, compress and extract .zip"),
					xsignT("Dọn dẹp bộ nhớ nhanh trong Cài đặt", "Quick Storage Cleaner in Settings"),
					xsignT("Đổi icon ứng dụng theo sở thích", "Change the app icon to your liking")
				  ])
		]
	}
	
	private var _pageCount: Int { 2 + _features.count }
	private var _isLast: Bool { _page == _pageCount - 1 }
	private var _canSkip: Bool { _page >= 1 && !_isLast }
	
	// MARK: Body
	var body: some View {
		VStack(spacing: 0) {
			_topBar
			
			ZStack {
				_pageContent
					.id(_page)
					.transition(.asymmetric(
						insertion: .move(edge: _isForward ? .trailing : .leading).combined(with: .opacity),
						removal: .move(edge: _isForward ? .leading : .trailing).combined(with: .opacity)
					))
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.clipped()
			.gesture(
				DragGesture(minimumDistance: 30).onEnded { value in
					if value.translation.width < -60 { _next() }
					else if value.translation.width > 60 { _back() }
				}
			)
			
			_pageDots
				.padding(.bottom, 12)
			
			Button {
				_isLast ? _finish() : _next()
			} label: {
				Text(_isLast ? xsignT("Bắt đầu", "Get Started") : xsignT("Tiếp tục", "Continue"))
					.font(.headline)
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
					.foregroundStyle(.white)
			}
			.padding(.horizontal, 24)
			.padding(.bottom, 20)
		}
		.background(XSignAmbientBackground())
		.interactiveDismissDisabled()
		.sheet(isPresented: $_isAddingCertificate) {
			CertificatesAddView()
				.environment(\.managedObjectContext, Storage.shared.context)
		}
	}
	
	// MARK: Top bar
	private var _topBar: some View {
		HStack {
			Button {
				_back()
			} label: {
				Image(systemName: "chevron.left")
					.font(.headline)
					.padding(10)
			}
			.opacity(_page > 0 ? 1 : 0)
			.disabled(_page == 0)
			
			Spacer()
			
			Button(xsignT("Bỏ qua", "Skip")) {
				_finish()
			}
			.padding(.horizontal, 6)
			.opacity(_canSkip ? 1 : 0)
			.disabled(!_canSkip)
		}
		.padding(.horizontal)
		.padding(.top, 8)
		.frame(height: 48)
	}
	
	private var _pageDots: some View {
		HStack(spacing: 8) {
			ForEach(0..<_pageCount, id: \.self) { index in
				Capsule()
					.fill(index == _page ? Color.accentColor : Color.secondary.opacity(0.3))
					.frame(width: index == _page ? 20 : 7, height: 7)
			}
		}
		.animation(.spring(response: 0.35, dampingFraction: 0.86), value: _page)
	}
	
	// MARK: Pages
	@ViewBuilder
	private var _pageContent: some View {
		switch _page {
		case 0: _languagePage
		case 1: _certificatePage
		default:
			if _features.indices.contains(_page - 2) {
				_featurePage(_features[_page - 2])
			}
		}
	}
	
	private var _appIcon: some View {
		Group {
			if let alt = UIApplication.shared.alternateIconName, let uiImg = UIImage(named: alt) {
				Image(uiImage: uiImg)
					.resizable()
					.scaledToFit()
					.frame(width: 88, height: 88)
					.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
			} else {
				FRAppIconView(size: 88)
			}
		}
	}
	
	private var _languagePage: some View {
		ScrollView {
			VStack(spacing: 20) {
				_appIcon
					.padding(.top, 24)
				Text(xsignT("Chào mừng đến với XSign", "Welcome to XSign"))
					.font(.title.bold())
					.multilineTextAlignment(.center)
				Text(xsignT("Chọn ngôn ngữ bạn muốn sử dụng. Bạn có thể đổi lại bất cứ lúc nào trong Cài đặt.", "Choose your language. You can change it anytime in Settings."))
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
				
				VStack(spacing: 10) {
					_languageRow(tag: "system", title: xsignT("Theo hệ thống", "System Default"), subtitle: _systemLanguageName)
					_languageRow(tag: "vi", title: "Tiếng Việt", subtitle: "Vietnamese")
					_languageRow(tag: "en", title: "English", subtitle: "Tiếng Anh")
				}
				.padding(.horizontal, 24)
				.padding(.top, 8)
			}
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
	}
	
	private var _systemLanguageName: String {
		Locale.preferredLanguages.first?.hasPrefix("vi") == true ? "Tiếng Việt" : "English"
	}
	
	private func _languageRow(tag: String, title: String, subtitle: String) -> some View {
		let isSelected = _appLanguage == tag
		return Button {
			_setLanguage(tag)
		} label: {
			HStack(spacing: 12) {
				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.headline)
						.foregroundStyle(.primary)
					Text(subtitle)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.font(.title3)
					.foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 14)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(Color(uiColor: .secondarySystemGroupedBackground))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
			)
		}
		.buttonStyle(.plain)
		.animation(.spring(response: 0.35, dampingFraction: 0.86), value: isSelected)
	}
	
	private var _certificatePage: some View {
		ScrollView {
			VStack(spacing: 20) {
				Image(systemName: "signature")
					.font(.system(size: 72, weight: .regular))
					.foregroundStyle(Color.accentColor)
					.padding(.top, 32)
				Text(xsignT("Nhập chứng chỉ", "Import Certificate"))
					.font(.title.bold())
					.multilineTextAlignment(.center)
				Text(xsignT("XSign cần chứng chỉ (.p12) và file cấp phép (.mobileprovision) để ký ứng dụng. Bạn có thể nhập nhanh một file .zip chứa cả hai.", "XSign needs a certificate (.p12) and a provisioning profile (.mobileprovision) to sign apps. You can quickly import a .zip containing both."))
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
				
				if !_certificates.isEmpty {
					Label(
						xsignT("Đã có \(_certificates.count) chứng chỉ", "\(_certificates.count) certificate(s) added"),
						systemImage: "checkmark.seal.fill"
					)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.green)
				}
				
				Button {
					_isAddingCertificate = true
				} label: {
					Label(
						_certificates.isEmpty ? xsignT("Nhập chứng chỉ", "Import Certificate") : xsignT("Thêm chứng chỉ khác", "Add Another Certificate"),
						systemImage: "plus.circle.fill"
					)
					.font(.headline)
					.padding(.horizontal, 20)
					.padding(.vertical, 12)
					.background(Color.accentColor.opacity(0.15), in: Capsule())
				}
				
				Text(xsignT("Chưa có chứng chỉ? Bấm Bỏ qua, bạn có thể thêm sau trong Cài đặt › Chứng chỉ.", "No certificate yet? Tap Skip, you can add one later in Settings › Certificates."))
					.font(.footnote)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
			}
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
	}
	
	private func _featurePage(_ feature: Feature) -> some View {
		ScrollView {
			VStack(spacing: 20) {
				Image(systemName: feature.icon)
					.font(.system(size: 72, weight: .regular))
					.foregroundStyle(Color.accentColor)
					.padding(.top, 32)
				Text(feature.title)
					.font(.title.bold())
					.multilineTextAlignment(.center)
				Text(feature.message)
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
				
				VStack(alignment: .leading, spacing: 14) {
					ForEach(feature.points, id: \.self) { point in
						HStack(alignment: .top, spacing: 12) {
							Image(systemName: "checkmark.circle.fill")
								.foregroundStyle(Color.accentColor)
							Text(point)
								.font(.callout)
								.fixedSize(horizontal: false, vertical: true)
							Spacer(minLength: 0)
						}
					}
				}
				.padding(18)
				.background(
					RoundedRectangle(cornerRadius: 16, style: .continuous)
						.fill(Color(uiColor: .secondarySystemGroupedBackground))
				)
				.padding(.horizontal, 24)
			}
			.frame(maxWidth: 520)
			.frame(maxWidth: .infinity)
		}
	}
	
	// MARK: Actions
	private func _setLanguage(_ tag: String) {
		_appLanguage = tag
		if tag == "system" {
			UserDefaults.standard.removeObject(forKey: "AppleLanguages")
		} else {
			UserDefaults.standard.set([tag], forKey: "AppleLanguages")
		}
	}
	
	private func _next() {
		guard _page < _pageCount - 1 else { return }
		_isForward = true
		withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { _page += 1 }
	}
	
	private func _back() {
		guard _page > 0 else { return }
		_isForward = false
		withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { _page -= 1 }
	}
	
	private func _finish() {
		UserDefaults.standard.set(true, forKey: Self.storageKey)
		isPresented = false
	}
}
