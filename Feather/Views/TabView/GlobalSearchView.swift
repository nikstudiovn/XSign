//
//  GlobalSearchView.swift
//  XSign
//
//  Tìm kiếm toàn app: Thư viện + Nguồn + Cài đặt.
//

import SwiftUI
import AltSourceKit
import NimbleViews
import QuickLook

// MARK: - Settings search index
private struct SettingsSearchItem: Identifiable {
	enum Destination {
		case appearance, appIcon, certificates, signingOptions, archive, installation, reset, about
	}
	
	let id: String
	let title: String
	let icon: String
	let keywords: [String]
	let destination: Destination
	
	func matches(_ query: String) -> Bool {
		title.localizedCaseInsensitiveContains(query) ||
		keywords.contains { $0.localizedCaseInsensitiveContains(query) }
	}
	
	static let all: [SettingsSearchItem] = [
		.init(id: "appearance", title: .localized("Appearance"), icon: "paintbrush",
			  keywords: ["giao diện", "màu", "tint", "theme", "dark", "tối"], destination: .appearance),
		.init(id: "appIcon", title: .localized("App Icon"), icon: "app.badge",
			  keywords: ["biểu tượng", "icon"], destination: .appIcon),
		.init(id: "certificates", title: .localized("Certificates"), icon: "checkmark.seal",
			  keywords: ["chứng chỉ", "p12", "mobileprovision", "cert"], destination: .certificates),
		.init(id: "signing", title: .localized("Signing Options"), icon: "signature",
			  keywords: ["ký", "sign", "tùy chọn", "configuration"], destination: .signingOptions),
		.init(id: "archive", title: .localized("Archive & Compression"), icon: "archivebox",
			  keywords: ["nén", "zip", "compression", "chia sẻ"], destination: .archive),
		.init(id: "installation", title: .localized("Installation"), icon: "arrow.down.circle",
			  keywords: ["cài đặt", "install", "server", "ssl", "idevice"], destination: .installation),
		.init(id: "reset", title: .localized("Reset"), icon: "trash",
			  keywords: ["đặt lại", "xóa", "reset", "clear"], destination: .reset),
		.init(id: "about", title: .localized("About"), icon: "info.circle",
			  keywords: ["giới thiệu", "phiên bản", "version", "credits"], destination: .about)
	]
}

private struct SettingsSearchDestinationView: View {
	let destination: SettingsSearchItem.Destination
	@State private var _currentIcon: String? = UIApplication.shared.alternateIconName
	
	var body: some View {
		switch destination {
		case .appearance: AppearanceView()
		case .appIcon: AppIconView(currentIcon: $_currentIcon)
		case .certificates: CertificatesView()
		case .signingOptions: ConfigurationView()
		case .archive: ArchiveView()
		case .installation: InstallationView()
		case .reset: ResetView()
		case .about: AboutView()
		}
	}
}

// MARK: - View
struct GlobalSearchView: View {
	@StateObject private var _viewModel = SourcesViewModel.shared
	@State private var _searchText = ""
	@State private var _selectedInfoApp: AnyApp?
var onExitSearch: (() -> Void)? = nil
@State private var _quickLookURL: URL? = nil
@State private var _allFiles: [URL] = []
@State private var _importNotice: String? = nil
	
	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
	) private var _signedApps: FetchedResults<Signed>
	
	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]
	) private var _importedApps: FetchedResults<Imported>
	
	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)]
	) private var _sources: FetchedResults<AltSource>
	
	private struct SourceHit: Identifiable {
		let id: String
		let sourceURL: URL?
		let repository: ASRepository
		let app: ASRepository.App
	}
	
	private var _query: String {
		_searchText.trimmingCharacters(in: .whitespacesAndNewlines)
	}
	
	private func _matches(_ name: String?, _ identifier: String?) -> Bool {
		(name?.localizedCaseInsensitiveContains(_query) ?? false) ||
		(identifier?.localizedCaseInsensitiveContains(_query) ?? false)
	}
	
	private var _libraryHits: [AnyApp] {
		guard !_query.isEmpty else { return [] }
		let signed = _signedApps.filter { _matches($0.name, $0.identifier) }.map { AnyApp(base: $0) }
		let imported = _importedApps.filter { _matches($0.name, $0.identifier) }.map { AnyApp(base: $0) }
		return signed + imported
	}
	
	private var _sourceHits: [SourceHit] {
		guard !_query.isEmpty else { return [] }
		var hits: [SourceHit] = []
		for source in _sources {
			guard let repo = _viewModel.sources[source] else { continue }
			for (index, app) in repo.apps.enumerated() where
				_matches(app.currentName, app.currentUniqueId) {
				hits.append(SourceHit(
					id: "\(source.identifier)|\(index)|\(app.currentUniqueId)",
					sourceURL: source.sourceURL,
					repository: repo,
					app: app
				))
				if hits.count >= 50 { return hits }
			}
		}
		return hits
	}
	
	private var _settingsHits: [SettingsSearchItem] {
		guard !_query.isEmpty else { return [] }
		return SettingsSearchItem.all.filter { $0.matches(_query) }
	}

private var _fileHits: [URL] {
guard !_query.isEmpty else { return [] }
return _allFiles.filter {
$0.lastPathComponent.localizedCaseInsensitiveContains(_query)
}
}
	
	var body: some View {
		let library = _libraryHits
		let sources = _sourceHits
		let settings = _settingsHits
		
		List {
			if _query.isEmpty {
				Text("Nhập tên ứng dụng, bundle ID hoặc mục cài đặt để tìm kiếm.")
					.foregroundStyle(.secondary)
			} else if library.isEmpty && sources.isEmpty && settings.isEmpty  && _fileHits.isEmpty{
				Text("Không tìm thấy kết quả")
					.foregroundStyle(.secondary)
			} else {
				if !library.isEmpty {
					Section("Thư viện") {
						ForEach(library) { app in
							Button {
								_selectedInfoApp = app
							} label: {
								VStack(alignment: .leading, spacing: 2) {
									Text(app.base.name ?? "Unknown")
										.foregroundStyle(.primary)
									Text([app.base.version, app.base.identifier]
										.compactMap { $0 }
										.joined(separator: " • "))
										.font(.caption)
										.foregroundStyle(.secondary)
								}
							}
						}
					}
				}
				
				if !sources.isEmpty {
					Section("Nguồn") {
						ForEach(sources) { hit in
							NavigationLink {
								SourceAppsDetailView(
									sourceURL: hit.sourceURL,
									source: hit.repository,
									app: hit.app
								)
							} label: {
								FRIconCellView(
									title: hit.app.currentName,
									subtitle: hit.app.currentVersion ?? (hit.repository.name ?? ""),
									iconUrl: hit.app.iconURL
								)
							}
						}
					}
				}
if !_fileHits.isEmpty {
Section("Tệp") {
ForEach(_fileHits, id: \.self) { url in
let ext = url.pathExtension.lowercased()
HStack(spacing: 12) {
Button {
_quickLookURL = url
} label: {
HStack(spacing: 10) {
Image(systemName: (ext == "ipa" || ext == "tipa") ? "shippingbox.fill" : "doc.fill")
.foregroundStyle(.secondary)
VStack(alignment: .leading, spacing: 2) {
Text(url.lastPathComponent)
.foregroundStyle(.primary)
.lineLimit(1)
Text(url.deletingLastPathComponent().lastPathComponent)
.font(.caption)
.foregroundStyle(.secondary)
}
}
.frame(maxWidth: .infinity, alignment: .leading)
}
.buttonStyle(.plain)

if ext == "ipa" || ext == "tipa" {
Button("Thêm") {
_importFileToLibrary(url)
}
.buttonStyle(.bordered)
.controlSize(.small)
}
}
}
}
}
				
				if !settings.isEmpty {
					Section("Cài đặt") {
						ForEach(settings) { item in
							NavigationLink {
								SettingsSearchDestinationView(destination: item.destination)
							} label: {
								Label(item.title, systemImage: item.icon)
							}
						}
					}
				}
			}
		}
		.navigationTitle("Tìm kiếm")
		.searchable(text: $_searchText, prompt: "Thư viện, Nguồn,Tệp,  Cài đặt")
		.autocorrectionDisabled()
		.textInputAutocapitalization(.never)
		.task {
_loadSearchableFiles()
			await _viewModel.fetchSources(_sources)
		}
		.sheet(item: $_selectedInfoApp) { app in
			LibraryInfoView(app: app.base)
		}
.quickLookPreview($_quickLookURL)
.alert("Thông báo", isPresented: Binding(get: { _importNotice != nil }, set: { if !$0 { _importNotice = nil } })) {
Button("OK", role: .cancel) {}
} message: {
Text(_importNotice ?? "")
}
.simultaneousGesture(DragGesture(minimumDistance: 35, coordinateSpace: .local).onEnded { value in if value.translation.width < -65 && abs(value.translation.height) < 55 { onExitSearch?() } })
	}

private func _loadSearchableFiles() {
let fm = FileManager.default
let docs = URL.documentsDirectory
let subDirs = ["InputFile", "Archives", "Certificates", "Signed", "Unsigned"]
var roots: [URL] = [docs]
for name in subDirs {
roots.append(docs.appendingPathComponent(name, isDirectory: true))
}
var collected: [URL] = []
for root in roots {
guard let items = try? fm.contentsOfDirectory(
at: root,
includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
options: [.skipsHiddenFiles]
) else { continue }
for item in items {
if item.lastPathComponent.hasPrefix(".") { continue }
let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
if isDir {
if item.pathExtension.lowercased() == "app" {
collected.append(item)
}
} else {
collected.append(item)
}
}
}
_allFiles = Array(Set(collected)).sorted {
$0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
}
}

private func _importFileToLibrary(_ url: URL) {
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
_importNotice = "Đã thêm \"\(url.lastPathComponent)\" vào Thư viện."
} catch {
_importNotice = error.localizedDescription
}
}
}
