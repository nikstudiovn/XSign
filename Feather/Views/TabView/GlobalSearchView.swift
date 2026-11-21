//
//  GlobalSearchView.swift
//  XSign
//
//  Tìm kiếm toàn app: Thư viện + Nguồn + Cài đặt.
//

import SwiftUI
import AltSourceKit
import NimbleViews

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
	
	var body: some View {
		let library = _libraryHits
		let sources = _sourceHits
		let settings = _settingsHits
		
		List {
			if _query.isEmpty {
				Text("Nhập tên ứng dụng, bundle ID hoặc mục cài đặt để tìm kiếm.")
					.foregroundStyle(.secondary)
			} else if library.isEmpty && sources.isEmpty && settings.isEmpty {
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
		.searchable(text: $_searchText, prompt: "Thư viện, Nguồn, Cài đặt")
		.autocorrectionDisabled()
		.textInputAutocapitalization(.never)
		.task {
			await _viewModel.fetchSources(_sources)
		}
		.sheet(item: $_selectedInfoApp) { app in
			LibraryInfoView(app: app.base)
		}
	}
}
