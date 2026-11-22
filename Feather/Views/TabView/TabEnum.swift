//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews
import QuickLook
import Zip
import UniformTypeIdentifiers

enum TabEnum: String, CaseIterable, Hashable {
	case sources
	case library
	case files
	case settings
	case certificates
	
	var title: String {
		switch self {
		case .sources:     	return .localized("Sources")
		case .library: 		return .localized("Library")
		case .files:		return xsignT("Thư mục", "Files")
		case .settings: 	return .localized("Settings")
		case .certificates:	return .localized("Certificates")
		}
	}
	
	var icon: String {
		switch self {
		case .sources: 		return "globe"
		case .library: 		return "app.badge.checkmark"
		case .files:		return "folder"
		case .settings: 	return "gearshape"
		case .certificates: return "signature"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .sources: SourcesView()
		case .library: LibraryView()
		case .files:
			NBNavigationView(xsignT("Thư mục", "Files")) {
				XSignFolderBrowserView(
					directory: URL.documentsDirectory,
					title: xsignT("Thư mục", "Files"),
					isRootTab: true
				)
			}
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("Certificates")) { CertificatesView() }
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.sources,
			.library,
			.files,
			.settings
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return [
			.certificates
		]
	}
}

struct XSignFolderBrowserView: View {
	let directory: URL
	let title: String
	var isRootTab: Bool = false
	
	@State private var items: [URL] = []
	@State private var searchText: String = ""
	@State private var quickLookItem: QuickLookItem?
	@State private var isShowingImporter: Bool = false
	@State private var isShowingNewFolderAlert: Bool = false
	@State private var newFolderName: String = ""
	@State private var itemToRename: URL?
	@State private var renameText: String = ""
	@State private var isShowingRenameAlert: Bool = false
	@State private var errorMessage: String?
	@State private var isShowingError: Bool = false
	@State private var importSuccessMessage: String? = nil
	@State private var isShowingImportSuccess: Bool = false
@State private var isMultiSelecting: Bool = false
@State private var selectedURLs: Set<URL> = []
@State private var _certPendingP12: URL? = nil
@State private var _certPendingProvision: URL? = nil
@State private var _certPasswordInput: String = ""
@State private var _certNicknameInput: String = ""
@State private var _certTempDir: URL? = nil
@State private var _showCertPasswordAlert: Bool = false
@State private var _certAlertMessage: String? = nil
@State private var _isPickingMissingCertPair = false
@State private var _missingPairNeedsProvision = true

private var _allSelectedAreIPA: Bool {
!selectedURLs.isEmpty && selectedURLs.allSatisfy { !_isDirectory($0) && _isIPA($0) }
}
	
	
	private struct QuickLookItem: Identifiable {
		let id = UUID()
		let url: URL
	}
	
	private var filteredItems: [URL] {
		if searchText.isEmpty {
			return items
		}
		return items.filter {
			$0.lastPathComponent.localizedCaseInsensitiveContains(searchText)
		}
	}
	
	var body: some View {
_applyCertAlerts(_applyFileAlerts(_applySheets(_mainListView)))
}

@ViewBuilder
private var _listContent: some View {
		List {
			if filteredItems.isEmpty {
				Text(searchText.isEmpty ? "Thư mục trống" : "Không tìm thấy kết quả")
					.foregroundStyle(.secondary)
			} else {
				ForEach(filteredItems, id: \.self) { url in
_browserRow(for: url)
}
}
}
}

@ViewBuilder
private func _browserRow(for url: URL) -> some View {
					let isDir = _isDirectory(url)
					Group {
					if isMultiSelecting {
Button {
if selectedURLs.contains(url) {
selectedURLs.remove(url)
} else {
selectedURLs.insert(url)
}
} label: {
HStack(spacing: 12) {
Image(systemName: selectedURLs.contains(url) ? "checkmark.circle.fill" : "circle")
.foregroundStyle(selectedURLs.contains(url) ? Color.accentColor : Color.secondary)
_rowView(for: url, isDirectory: isDir)
}
}
.tint(.primary)
} else 	if isDir {
							NavigationLink {
								XSignFolderBrowserView(
									directory: url,
									title: url.lastPathComponent
								)
							} label: {
								_rowView(for: url, isDirectory: true)
							}
					} else if _isIPA(url) {
						HStack {
							Button {
								quickLookItem = QuickLookItem(url: url)
							} label: {
								_rowView(for: url, isDirectory: false)
							}
							.tint(.primary)
							Spacer()
							Button(xsignT("Thêm vào thư viện", "Add to Library")) {
								_importIPAToLibrary(url)
							}
							.buttonStyle(.bordered)
							.controlSize(.small)
						}
							
} else if _isCertificateImportable(url) {
HStack {
Button {
quickLookItem = QuickLookItem(url: url)
} label: {
_rowView(for: url, isDirectory: false)
}
.tint(.primary)
Spacer()
Button(xsignT("Nhập chứng chỉ", "Import Certificate")) {
_prepareCertificateImport(from: url)
}
.buttonStyle(.bordered)
.controlSize(.small)
}
} else {
Button {
								quickLookItem = QuickLookItem(url: url)
							} label: {
								_rowView(for: url, isDirectory: false)
							}
							.tint(.primary)
						}
					}
					.swipeActions(edge: .trailing, allowsFullSwipe: true) {
						Button(role: .destructive) {
							_deleteItem(url)
						} label: {
							Label(xsignT("Xóa", "Delete"), systemImage: "trash")
						}
					}
					.contextMenu {
if !isDir && _isCertificateImportable(url) {
Button {
_prepareCertificateImport(from: url)
} label: {
Label(xsignT("Nhập chứng chỉ", "Import Certificate"), systemImage: "checkmark.seal")
}
}
					if !isDir && _isIPA(url) {
						Button {
							_importIPAToLibrary(url)
						} label: {
							Label(xsignT("Thêm vào thư viện", "Add to Library"), systemImage: "plus.app")
						}
					}
						Button {
							itemToRename = url
							renameText = url.lastPathComponent
							isShowingRenameAlert = true
						} label: {
							Label(xsignT("Đổi tên", "Rename"), systemImage: "pencil")
						}
						
						if !isDir && url.pathExtension.lowercased() == "zip" {
							Button {
								_unzipItem(url)
							} label: {
								Label(xsignT("Giải nén", "Extract"), systemImage: "archivebox.fill")
							}
						}
						
						ShareLink(item: url) {
							Label(xsignT("Chia sẻ", "Share"), systemImage: "square.and.arrow.up")
						}
						
						Button(role: .destructive) {
							_deleteItem(url)
						} label: {
							Label(xsignT("Xóa", "Delete"), systemImage: "trash")
						}
					}
				}
		
@ViewBuilder
private var _mainListView: some View {
_listContent
 .scrollContentBackground(.hidden)
		.background { XSignAmbientBackground() }
		.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: xsignT("Tìm kiếm tệp hoặc thư mục", "Search files or folders"))
		.navigationTitle(title)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				if isMultiSelecting {
Button("Xong") {
isMultiSelecting = false
selectedURLs.removeAll()
}
} else {
Menu {
					Button {
						newFolderName = ""
						isShowingNewFolderAlert = true
					} label: {
						Label(xsignT("Tạo thư mục mới", "New Folder"), systemImage: "folder.badge.plus")
					}
					
					Button {
						isShowingImporter = true
					} label: {
						Label(xsignT("Nhập tệp", "Import Files"), systemImage: "square.and.arrow.down")
					}
					
					Button {
						_loadItems()
					} label: {
						Label(xsignT("Làm mới", "Refresh"), systemImage: "arrow.clockwise")
					}
Button {
selectedURLs.removeAll()
isMultiSelecting = true
} label: {
Label(xsignT("Chọn nhiều", "Select Multiple"), systemImage: "checkmark.circle")
}
				} label: {
					Image(systemName: "ellipsis.circle")
				}
				}
			}
		}
.safeAreaInset(edge: .bottom) {
if isMultiSelecting {
HStack(spacing: 12) {
if _allSelectedAreIPA {
Button {
_importMultipleIPAs(Array(selectedURLs))
} label: {
Label("Nhập vào Thư viện (\(selectedURLs.count))", systemImage: "plus.app")
.font(.subheadline.weight(.semibold))
}
.buttonStyle(.borderedProminent)
}
Button {
_zipSelectedItems()
} label: {
Label("Nén ZIP", systemImage: "archivebox")
.font(.subheadline.weight(.medium))
}
.buttonStyle(.bordered)
.disabled(selectedURLs.isEmpty)
Button(role: .destructive) {
_deleteSelectedItems()
} label: {
Label(xsignT("Xóa", "Delete"), systemImage: "trash")
.font(.subheadline.weight(.medium))
}
.buttonStyle(.bordered)
.disabled(selectedURLs.isEmpty)
}
.padding(.horizontal, 16)
.padding(.vertical, 12)
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
.padding(.horizontal, 16)
.padding(.bottom, 8)
}
}
		.onAppear {
			_loadItems()
		}
		.refreshable {
			_loadItems()
		}
}

@ViewBuilder
private func _applySheets<Content: View>(_ content: Content) -> some View {
content
		.sheet(item: $quickLookItem) { item in
			XSignQuickLookSheet(url: item.url)
		}
		.sheet(isPresented: $isShowingImporter) {
			FileImporterRepresentableView(
				allowedContentTypes: [.item],
				allowsMultipleSelection: true,
				onDocumentsPicked: { urls in
					_importFiles(urls)
				}
			)
		}
.sheet(isPresented: $_isPickingMissingCertPair) {
	FileImporterRepresentableView(allowedContentTypes: [.item], allowsMultipleSelection: false, onDocumentsPicked: { urls in if let url = urls.first { if _missingPairNeedsProvision { _certPendingProvision = url } else { _certPendingP12 = url }; if _certPendingP12 != nil && _certPendingProvision != nil { _showCertPasswordAlert = true } } })
}
}

@ViewBuilder
private func _applyFileAlerts<Content: View>(_ content: Content) -> some View {
content
		.alert(xsignT("Tạo thư mục mới", "New Folder"), isPresented: $isShowingNewFolderAlert) {
			TextField("Tên thư mục", text: $newFolderName)
			Button("Tạo") {
				_createFolder()
			}
			Button("Hủy", role: .cancel) {}
		}
		.alert(xsignT("Đổi tên", "Rename"), isPresented: $isShowingRenameAlert) {
			TextField("Tên mới", text: $renameText)
			Button("Lưu") {
				_renameItem()
			}
			Button("Hủy", role: .cancel) {}
		}
		.alert("Lỗi", isPresented: $isShowingError) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(errorMessage ?? "Đã xảy ra lỗi")
		}
		.alert("Đã thêm vào Thư viện", isPresented: $isShowingImportSuccess) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(importSuccessMessage ?? "")
		}
}

@ViewBuilder
private func _applyCertAlerts<Content: View>(_ content: Content) -> some View {
content
.alert(xsignT("Nhập chứng chỉ", "Import Certificate"), isPresented: $_showCertPasswordAlert) {
TextField("Tên gợi nhớ (tùy chọn)", text: $_certNicknameInput)
SecureField("Mật khẩu .p12", text: $_certPasswordInput)
Button("Lưu") {
_confirmCertificateImport()
}
Button("Hủy", role: .cancel) {
_cleanupCertTempDir()
}
} message: {
Text("Nhập tên gợi nhớ và mật khẩu cho chứng chỉ.")
}
.alert("Thông báo chứng chỉ", isPresented: Binding(
get: { _certAlertMessage != nil },
set: { if !$0 { _certAlertMessage = nil } }
)) {
Button("OK", role: .cancel) {}
} message: {
Text(_certAlertMessage ?? "")
}
	}

	private func _isIPA(_ url: URL) -> Bool {
let ext = url.pathExtension.lowercased()
return ext == "ipa" || ext == "tipa"
	}

private func _isCertificateImportable(_ url: URL) -> Bool {
let ext = url.pathExtension.lowercased()
if ext == "p12" || ext == "mobileprovision" { return true }; if ext == "zip" { let name = url.lastPathComponent.lowercased(); return name.contains("certificate") || name.contains("cert") || name.contains("chứng chỉ") || name.contains("chungchi") }; return false
}

private func _prepareCertificateImport(from url: URL) {
_cleanupCertTempDir()
_certPasswordInput = ""
_certNicknameInput = url.deletingPathExtension().lastPathComponent
let ext = url.pathExtension.lowercased()

if ext == "p12" || ext == "mobileprovision" {
let contents = (try? FileManager.default.contentsOfDirectory(
at: directory,
includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
options: [.skipsHiddenFiles]
)) ?? []
let baseName = url.deletingPathExtension().lastPathComponent.lowercased()
var p12URL: URL? = ext == "p12" ? url : nil
var provURL: URL? = ext == "mobileprovision" ? url : nil

if p12URL == nil {
let p12Candidates = contents.filter { $0.pathExtension.lowercased() == "p12" }
p12URL = p12Candidates.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == baseName }) ?? p12Candidates.first
}
if provURL == nil {
let provCandidates = contents.filter { $0.pathExtension.lowercased() == "mobileprovision" }
provURL = provCandidates.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == baseName }) ?? provCandidates.first
}



for item in contents where item.pathExtension.lowercased() == "txt" {
if let pw = _readCertPasswordTxt(from: item) {
_certPasswordInput = pw
break
}
}

if let foundP12 = p12URL, let foundProv = provURL { _certPendingP12 = foundP12; _certPendingProvision = foundProv; _showCertPasswordAlert = true } else { _certPendingP12 = p12URL; _certPendingProvision = provURL; _missingPairNeedsProvision = (ext == "p12"); _isPickingMissingCertPair = true }
} else if ext == "zip" {
do {
let tempDir = FileManager.default.temporaryDirectory
.appendingPathComponent("XSignCertImport_\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
try Zip.unzipFile(url, destination: tempDir, overwrite: true, password: nil)
_certTempDir = tempDir

var foundP12: URL? = nil
var foundProv: URL? = nil
var foundPassword: String? = nil

if let enumerator = FileManager.default.enumerator(
at: tempDir,
includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
options: [.skipsHiddenFiles]
) {
for case let fileURL as URL in enumerator {
if fileURL.pathComponents.contains("__MACOSX") || fileURL.lastPathComponent.hasPrefix("._") {
continue
}
let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
guard values?.isRegularFile == true else { continue }
let fileExt = fileURL.pathExtension.lowercased()
if fileExt == "p12" && foundP12 == nil {
foundP12 = fileURL
} else if fileExt == "mobileprovision" && foundProv == nil {
foundProv = fileURL
} else if fileExt == "txt" && foundPassword == nil {
foundPassword = _readCertPasswordTxt(from: fileURL)
}
}
}

guard let p12 = foundP12, let prov = foundProv else {
_cleanupCertTempDir()
_certAlertMessage = "Tệp ZIP không chứa đủ cả .p12 và .mobileprovision."
return
}

_certPendingP12 = p12
_certPendingProvision = prov
if let pw = foundPassword {
_certPasswordInput = pw
}
_showCertPasswordAlert = true
} catch {
_cleanupCertTempDir()
_certAlertMessage = "Không thể giải nén tệp ZIP: \(error.localizedDescription)"
}
}
}

private func _readCertPasswordTxt(from url: URL) -> String? {
let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
guard values?.isRegularFile == true, (values?.fileSize ?? Int.max) <= 4096 else {
return nil
}
guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
return nil
}
let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
return trimmed.isEmpty ? nil : trimmed
}

private func _confirmCertificateImport() {
guard let p12 = _certPendingP12, let prov = _certPendingProvision else {
_cleanupCertTempDir()
return
}
guard FR.checkPasswordForCertificate(for: p12, with: _certPasswordInput, using: prov) else {
_cleanupCertTempDir()
_certAlertMessage = "Mật khẩu .p12 không đúng hoặc chứng chỉ không hợp lệ."
return
}
FR.handleCertificateFiles(
p12URL: p12,
provisionURL: prov,
p12Password: _certPasswordInput,
certificateName: _certNicknameInput
) { _ in
DispatchQueue.main.async {
_cleanupCertTempDir()
_certAlertMessage = "Đã nhập chứng chỉ thành công."
}
}
}

private func _cleanupCertTempDir() {
if let tempDir = _certTempDir {
try? FileManager.default.removeItem(at: tempDir)
_certTempDir = nil
}
_certPendingP12 = nil
_certPendingProvision = nil
	}

	private func _importIPAToLibrary(_ url: URL) {
		do {
			let tempURL = FileManager.default.temporaryDirectory
				.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
			if FileManager.default.fileExists(atPath: tempURL.path) {
				try FileManager.default.removeItem(at: tempURL)
			}
			try FileManager.default.copyItem(at: url, to: tempURL)
			let dl = DownloadManager.shared.startArchive(
				from: tempURL,
				id: "FeatherManualDownload_\(UUID().uuidString)"
			)
			try DownloadManager.shared.handlePachageFile(url: tempURL, dl: dl)
			importSuccessMessage = "Đã thêm \"\(url.lastPathComponent)\" vào Thư viện."
			isShowingImportSuccess = true
		} catch {
			errorMessage = error.localizedDescription
			isShowingError = true
		}
	}

private func _importMultipleIPAs(_ urls: [URL]) {
do {
for url in urls {
let tempURL = FileManager.default.temporaryDirectory
.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
if FileManager.default.fileExists(atPath: tempURL.path) {
try FileManager.default.removeItem(at: tempURL)
}
try FileManager.default.copyItem(at: url, to: tempURL)
let dl = DownloadManager.shared.startArchive(
from: tempURL,
id: "FeatherManualDownload_\(UUID().uuidString)"
)
try DownloadManager.shared.handlePachageFile(url: tempURL, dl: dl)
}
importSuccessMessage = "Đã thêm \(urls.count) tệp IPA vào Thư viện."
isShowingImportSuccess = true
isMultiSelecting = false
selectedURLs.removeAll()
} catch {
errorMessage = error.localizedDescription
isShowingError = true
}
}

private func _zipSelectedItems() {
guard !selectedURLs.isEmpty else { return }
do {
let zipURL = directory.appendingPathComponent("Archive_\(Int(Date().timeIntervalSince1970)).zip")
try Zip.zipFiles(paths: Array(selectedURLs), zipFilePath: zipURL, password: nil, progress: nil)
_loadItems()
isMultiSelecting = false
selectedURLs.removeAll()
} catch {
errorMessage = error.localizedDescription
isShowingError = true
}
}

private func _deleteSelectedItems() {
guard !selectedURLs.isEmpty else { return }
do {
for url in selectedURLs {
try FileManager.default.removeItem(at: url)
}
_loadItems()
isMultiSelecting = false
selectedURLs.removeAll()
} catch {
errorMessage = error.localizedDescription
isShowingError = true
}
}
	
	@ViewBuilder
	private func _rowView(for url: URL, isDirectory: Bool) -> some View {
		HStack(spacing: 12) {
			Image(systemName: isDirectory ? "folder.fill" : _iconName(for: url))
				.font(.title3)
				.foregroundStyle(isDirectory ? Color.accentColor : Color.secondary)
				.frame(width: 28)
			
			VStack(alignment: .leading, spacing: 2) {
				Text(url.lastPathComponent)
					.font(.body)
					.lineLimit(1)
				
				Text(_subtitle(for: url, isDirectory: isDirectory))
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
		.padding(.vertical, 2)
	}
	
	private func _isDirectory(_ url: URL) -> Bool {
		(try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
	}
	
	private func _iconName(for url: URL) -> String {
		switch url.pathExtension.lowercased() {
		case "ipa", "tipa":
			return "shippingbox.fill"
			case "zip":
			return "doc.zipper"
		case "p12", "mobileprovision", "cer", "pem":
			return "checkmark.seal.fill"
		case "png", "jpg", "jpeg", "heic":
			return "photo"
		case "txt", "json", "plist", "xml", "log":
			return "doc.text"
		default:
			return "doc"
		}
	}
	
	private func _subtitle(for url: URL, isDirectory: Bool) -> String {
		let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
		let dateText: String
		if let date = values?.contentModificationDate {
			dateText = date.formatted(date: .abbreviated, time: .shortened)
		} else {
			dateText = ""
		}
		
		if isDirectory {
			let count = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).count) ?? 0
			return dateText.isEmpty ? "\(count) mục" : "\(count) mục • \(dateText)"
		} else {
			let size = Int64(values?.fileSize ?? 0)
			let sizeText = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
			return dateText.isEmpty ? sizeText : "\(sizeText) • \(dateText)"
		}
	}
	
	private func _loadItems() {
		if isRootTab {
					     try? FileManager.default.createDirectory(at: directory.appendingPathComponent("InputFile", isDirectory: true), withIntermediateDirectories: true)
		}
		do {
			let contents = try FileManager.default.contentsOfDirectory(
				at: directory,
				includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
				options: [.skipsHiddenFiles]
			)
			items = contents.sorted { lhs, rhs in
				let lDir = _isDirectory(lhs)
				let rDir = _isDirectory(rhs)
				if lDir != rDir {
					return lDir && !rDir
				}
				return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
			}
		} catch {
			items = []
		}
	}
	
	private func _createFolder() {
		let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		let target = directory.appendingPathComponent(trimmed, isDirectory: true)
		do {
			try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
			_loadItems()
		} catch {
			errorMessage = error.localizedDescription
			isShowingError = true
		}
	}
	
	private func _renameItem() {
		guard let source = itemToRename else { return }
		let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty, trimmed != source.lastPathComponent else { return }
		let destination = directory.appendingPathComponent(trimmed)
		do {
			try FileManager.default.moveItem(at: source, to: destination)
			_loadItems()
		} catch {
			errorMessage = error.localizedDescription
			isShowingError = true
		}
	}
	
	private func _deleteItem(_ url: URL) {
		do {
			try FileManager.default.removeItem(at: url)
			_loadItems()
		} catch {
			errorMessage = error.localizedDescription
			isShowingError = true
		}
	}
	
	private func _unzipItem(_ url: URL) {
		do {
			try Zip.unzipFile(url, destination: directory, overwrite: true, password: nil)
			_loadItems()
		} catch {
			errorMessage = error.localizedDescription
			isShowingError = true
		}
	}
	
	private func _importFiles(_ urls: [URL]) {
		for url in urls {
			let accessed = url.startAccessingSecurityScopedResource()
			defer {
				if accessed {
					url.stopAccessingSecurityScopedResource()
				}
			}
			let destination = directory.appendingPathComponent(url.lastPathComponent)
			do {
				if FileManager.default.fileExists(atPath: destination.path) {
					try FileManager.default.removeItem(at: destination)
				}
				try FileManager.default.copyItem(at: url, to: destination)
			} catch {
				errorMessage = error.localizedDescription
				isShowingError = true
			}
		}
		_loadItems()
	}
}

struct XSignQuickLookSheet: View {
	let url: URL
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		NavigationStack {
			QuickLookPreviewRepresentable(url: url)
				.ignoresSafeArea()
				.navigationTitle(url.lastPathComponent)
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .topBarTrailing) {
						Button("Đóng") {
							dismiss()
						}
					}
				}
		}
	}
}

private struct QuickLookPreviewRepresentable: UIViewControllerRepresentable {
	let url: URL
	
	func makeCoordinator() -> Coordinator {
		Coordinator(url: url)
	}
	
	func makeUIViewController(context: Context) -> QLPreviewController {
		let controller = QLPreviewController()
		controller.dataSource = context.coordinator
		return controller
	}
	
	func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
		context.coordinator.url = url
		uiViewController.reloadData()
	}
	
	final class Coordinator: NSObject, QLPreviewControllerDataSource {
		var url: URL
		
		init(url: URL) {
			self.url = url
		}
		
		func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
			1
		}
		
		func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
			url as QLPreviewItem
		}
	}
}
