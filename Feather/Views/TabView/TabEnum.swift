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
		case .files:		return "Thư mục"
		case .settings: 	return .localized("Settings")
		case .certificates:	return .localized("Certificates")
		}
	}
	
	var icon: String {
		switch self {
		case .sources: 		return "globe.desk"
		case .library: 		return "square.grid.2x2"
		case .files:		return "folder"
		case .settings: 	return "gearshape.2"
		case .certificates: return "person.text.rectangle"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .sources: SourcesView()
		case .library: LibraryView()
		case .files:
			NBNavigationView("Thư mục") {
				XSignFolderBrowserView(
					directory: URL.documentsDirectory,
					title: "Thư mục",
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
		List {
			if filteredItems.isEmpty {
				Text(searchText.isEmpty ? "Thư mục trống" : "Không tìm thấy kết quả")
					.foregroundStyle(.secondary)
			} else {
				ForEach(filteredItems, id: \.self) { url in
					let isDir = _isDirectory(url)
					Group {
						if isDir {
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
							Button("Thêm vào thư viện") {
								_importIPAToLibrary(url)
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
							Label("Xóa", systemImage: "trash")
						}
					}
					.contextMenu {
					if !isDir && _isIPA(url) {
						Button {
							_importIPAToLibrary(url)
						} label: {
							Label("Thêm vào thư viện", systemImage: "plus.square.on.square")
						}
					}
						Button {
							itemToRename = url
							renameText = url.lastPathComponent
							isShowingRenameAlert = true
						} label: {
							Label("Đổi tên", systemImage: "pencil")
						}
						
						if !isDir && url.pathExtension.lowercased() == "zip" {
							Button {
								_unzipItem(url)
							} label: {
								Label("Giải nén", systemImage: "doc.zipper")
							}
						}
						
						ShareLink(item: url) {
							Label("Chia sẻ", systemImage: "square.and.arrow.up")
						}
						
						Button(role: .destructive) {
							_deleteItem(url)
						} label: {
							Label("Xóa", systemImage: "trash")
						}
					}
				}
			}
		}
		.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Tìm kiếm tệp hoặc thư mục")
		.navigationTitle(title)
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Menu {
					Button {
						newFolderName = ""
						isShowingNewFolderAlert = true
					} label: {
						Label("Tạo thư mục mới", systemImage: "folder.badge.plus")
					}
					
					Button {
						isShowingImporter = true
					} label: {
						Label("Nhập tệp", systemImage: "square.and.arrow.down")
					}
					
					Button {
						_loadItems()
					} label: {
						Label("Làm mới", systemImage: "arrow.clockwise")
					}
				} label: {
					Image(systemName: "ellipsis.circle")
				}
			}
		}
		.onAppear {
			_loadItems()
		}
		.refreshable {
			_loadItems()
		}
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
		.alert("Tạo thư mục mới", isPresented: $isShowingNewFolderAlert) {
			TextField("Tên thư mục", text: $newFolderName)
			Button("Tạo") {
				_createFolder()
			}
			Button("Hủy", role: .cancel) {}
		}
		.alert("Đổi tên", isPresented: $isShowingRenameAlert) {
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

	private func _isIPA(_ url: URL) -> Bool {
		let ext = url.pathExtension.lowercased()
		return ext == "ipa" || ext == "tipa"
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
			try DownloadManager.shared.handlePackageFile(url: tempURL, dl: dl)
			importSuccessMessage = "Đã thêm \"\(url.lastPathComponent)\" vào Thư viện."
			isShowingImportSuccess = true
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
		case "zip", "ipa", "tipa":
			return "doc.zipper"
		case "p12", "mobileprovision", "cer", "pem":
			return "doc.badge.gearshape"
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
