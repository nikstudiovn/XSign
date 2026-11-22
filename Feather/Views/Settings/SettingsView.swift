//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
	@AppStorage("XSign.selectedCert") private var _storedSelectedCert: Int = 0
	@AppStorage("XSign.appLanguage") private var _appLanguage: String = "system"
	@State private var _currentIcon: String? = UIApplication.shared.alternateIconName
	
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}

    
	private let _donationsUrl = "https://github.com/sponsors/claration"
	private let _githubUrl = "https://github.com/nikstudiovn/XSign"
    
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				#if !NIGHTLY && !DEBUG
					// SettingsDonationCellView(site: _donationsUrl)
				#endif
                
				_feedback()
                
				Section {
					NavigationLink(destination: AppearanceView()) {
						Label(.localized("Appearance"), systemImage: "paintbrush")
					}
					NavigationLink(destination: AppIconView(currentIcon: $_currentIcon)) {
						Label(.localized("App Icon"), systemImage: "sparkles.square.filled.on.square")
					}
				Picker(selection: $_appLanguage) {
					Text(xsignT("Hệ thống", "System")).tag("system")
					Text("Tiếng Việt").tag("vi")
					Text("English").tag("en")
				} label: {
					Label(xsignT("Ngôn ngữ", "Language"), systemImage: "globe")
				}
				.onChange(of: _appLanguage) { newValue in
					if newValue == "system" {
						UserDefaults.standard.removeObject(forKey: "AppleLanguages")
					} else {
						UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
					}
				}
				NavigationLink(destination: XSignStorageCleanerView()) {
					Label(xsignT("Dọn dẹp bộ nhớ nhanh", "Quick Storage Cleaner"), systemImage: "sparkles")
				}
				}
                
				NBSection(.localized("Certificates")) {
                    
					if let cert = selectedCertificate {
						CertificatesCellView(cert: cert)
					} else {
						Text(.localized("No Certificate"))
							.font(.footnote)
							.foregroundColor(.disabled())
					}
					NavigationLink(destination: CertificatesView()) {
						Label(.localized("Certificates"), systemImage: "checkmark.seal")
					}
                 
				} footer: {
					Text(.localized("Add and manage certificates used for signing applications."))
				}
                
				NBSection(.localized("Features")) {
					NavigationLink(destination: ConfigurationView()) {
						Label(.localized("Signing Options"), systemImage: "signature")
					}
					NavigationLink(destination: ArchiveView()) {
						Label(.localized("Archive & Compression"), systemImage: "archivebox")
					}
					NavigationLink(destination: InstallationView()) {
						Label(.localized("Installation"), systemImage: "arrow.down.circle")
					}
				} footer: {
					Text(.localized("Configure the apps way of installing, its zip compression levels, and custom modifications to apps."))
				}
                
				_directories()
                
				Section {
					NavigationLink(destination: ResetView()) {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} footer: {
					Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
				}
			}
			.scrollContentBackground(.hidden)
			.background { XSignAmbientBackground() }
		}
	}
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _feedback() -> some View {
		Section {
			NavigationLink(destination: AboutView()) {
				Label {
					Text(verbatim: .localized("About %@", arguments: Bundle.main.name))
				} icon: {
					FRAppIconView(size: 23)
				}
			}
            
			Button(.localized("Submit Feedback"), systemImage: "exclamationmark.bubble") {
				UIApplication.open(URL(string: "\(_githubUrl)/issues")!)
			}
			Button(.localized("GitHub Repository"), systemImage: "chevron.left.forwardslash.chevron.right") {
				UIApplication.open(_githubUrl)
			} 
			Button(xsignT("Kênh Telegram (@nikvn21)", "Telegram Channel (@nikvn21)"), systemImage: "paperplane.fill") {
				UIApplication.open("https://t.me/nikvn21")
			}
		} footer: {
			Text(.localized("If any issues occur within the app please report it via the GitHub repository. When submitting an issue, make sure to submit detailed information."))
		}
	}
    
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
Button {
let path = URL.documentsDirectory.path
if let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
let filesURL = URL(string: "shareddocuments://\(encodedPath)") {
UIApplication.shared.open(filesURL)
}
} label: {
Label("Mở thư mục XSign trong Tệp", systemImage: "folder.badge.gearshape")
}
		NavigationLink {
				XSignFolderBrowserView(
					directory: URL.documentsDirectory,
					title: .localized("Open Documents")
				)
			} label: {
				Label(.localized("Open Documents"), systemImage: "folder")
			}
			NavigationLink {
				XSignFolderBrowserView(
					directory: FileManager.default.archives,
					title: .localized("Open Archives")
				)
			} label: {
				Label(.localized("Open Archives"), systemImage: "archivebox")
			}
			NavigationLink {
				XSignFolderBrowserView(
					directory: FileManager.default.certificates,
					title: .localized("Open Certificates")
				)
			} label: {
				Label(.localized("Open Certificates"), systemImage: "checkmark.seal")
			}
		} footer: {
			Text(.localized("All of the apps files are contained in the documents directory, here are some quick links to these."))
		}
	}
}
struct XSignStorageCleanerView: View {
	struct CleanTarget: Identifiable {
		let id: String
		let title: String
		let icon: String
		let directories: [URL]
		var size: Int64 = 0
		var isSelected: Bool
	}

	@State private var _targets: [CleanTarget] = [
		CleanTarget(
			id: "cache",
			title: xsignT("Tệp tạm & Bộ nhớ đệm", "Temp Files & Cache"),
			icon: "memorychip",
			directories: [
				FileManager.default.temporaryDirectory,
				FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
			].compactMap { $0 },
			isSelected: true
		),
		CleanTarget(
			id: "archives",
			title: xsignT("Thư mục Archives", "Archives Folder"),
			icon: "archivebox",
			directories: [FileManager.default.archives],
			isSelected: false
		),
		CleanTarget(
			id: "signed",
			title: xsignT("Ứng dụng đã ký (Signed)", "Signed Apps"),
			icon: "signature",
			directories: [FileManager.default.signed],
			isSelected: false
		),
		CleanTarget(
			id: "input",
			title: xsignT("Thư mục InputFile", "InputFile Folder"),
			icon: "tray.and.arrow.down",
			directories: [URL.documentsDirectory.appendingPathComponent("InputFile")],
			isSelected: false
		)
	]

	@State private var _isScanning = false
	@State private var _isCleaning = false
	@State private var _showConfirmAlert = false
	@State private var _showResultAlert = false
	@State private var _freedBytes: Int64 = 0

	private var _selectedSize: Int64 {
		_targets.filter(\.isSelected).reduce(0) { $0 + $1.size }
	}

	var body: some View {
		List {
			Section {
				ForEach($_targets) { $target in
					Toggle(isOn: $target.isSelected) {
						HStack {
							Label(target.title, systemImage: target.icon)
							Spacer()
							Text(_formatBytes(target.size))
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					}
				}
			} header: {
				Text(xsignT("Chọn mục cần dọn dẹp", "Select Items to Clean"))
			} footer: {
				Text("\(xsignT("Tổng dung lượng đã chọn:", "Total selected:")) \(_formatBytes(_selectedSize))")
			}

			Section {
				Button(role: .destructive) {
					_showConfirmAlert = true
				} label: {
					HStack {
						Spacer()
						if _isCleaning {
							ProgressView()
						} else {
							Label(xsignT("Dọn các mục đã chọn", "Clean Selected Items"), systemImage: "trash.slash")
								.fontWeight(.semibold)
						}
						Spacer()
					}
				}
				.disabled(_isScanning || _isCleaning || _targets.allSatisfy { !$0.isSelected })
			}
		}
		.navigationTitle(xsignT("Dọn dẹp bộ nhớ nhanh", "Quick Storage Cleaner"))
		.navigationBarTitleDisplayMode(.inline)
		.task {
			await _scanStorage()
		}
		.refreshable {
			await _scanStorage()
		}
		.alert(xsignT("Xác nhận dọn dẹp", "Confirm Cleanup"), isPresented: $_showConfirmAlert) {
			Button(xsignT("Hủy", "Cancel"), role: .cancel) {}
			Button(xsignT("Dọn ngay", "Clean Now"), role: .destructive) {
				Task { await _cleanSelected() }
			}
		} message: {
			Text("\(xsignT("Bạn có chắc muốn xóa các mục đã chọn", "Are you sure you want to delete the selected items")) (\(_formatBytes(_selectedSize)))? \(xsignT("Hành động này không thể hoàn tác.", "This action cannot be undone."))")
		}
		.alert(xsignT("Đã dọn dẹp xong", "Cleanup Complete"), isPresented: $_showResultAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text("\(xsignT("Đã giải phóng chính xác", "Freed")) \(_formatBytes(_freedBytes)) \(xsignT("bộ nhớ.", "of storage."))")
		}
	}

	private func _formatBytes(_ bytes: Int64) -> String {
		ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
	}

	private func _scanStorage() async {
		_isScanning = true
		let scanned = await Task.detached(priority: .utility) { () -> [Int64] in
			_targets.map { target in
				target.directories.reduce(0) { $0 + Self._directorySize($1) }
			}
		}.value
		for i in _targets.indices where i < scanned.count {
			_targets[i].size = scanned[i]
		}
		_isScanning = false
	}

	private func _cleanSelected() async {
		_isCleaning = true
		let selectedDirs = _targets.filter(\.isSelected).flatMap(\.directories)
		let beforeTotal = _selectedSize
		await Task.detached(priority: .userInitiated) {
			let fm = FileManager.default
			for dir in selectedDirs {
				guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
				for item in items {
					try? fm.removeItem(at: item)
				}
			}
		}.value
		await _scanStorage()
		let afterTotal = _targets.filter(\.isSelected).reduce(0) { $0 + $1.size }
		_freedBytes = max(0, beforeTotal - afterTotal)
		_isCleaning = false
		_showResultAlert = true
	}

	nonisolated private static func _directorySize(_ url: URL) -> Int64 {
		let fm = FileManager.default
		guard let enumerator = fm.enumerator(
			at: url,
			includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
			options: [.skipsHiddenFiles]
		) else { return 0 }
		var total: Int64 = 0
		for case let fileURL as URL in enumerator {
			guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
				  values.isRegularFile == true,
				  let size = values.fileSize else { continue }
			total += Int64(size)
		}
		return total
	}
}
