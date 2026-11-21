//
//  ContentView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct LibraryView: View {
	@StateObject var downloadManager = DownloadManager.shared
	@StateObject var updateManager = UpdateManager.shared
		@ObservedObject private var _presetManager = XSignPresetManager.shared
	@ObservedObject private var _ocspCache = XSignOCSPCache.shared
@FetchRequest(entity: CertificatePair.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]) private var _libraryCertificates: FetchedResults<CertificatePair>
@AppStorage("feather.selectedCert") private var _librarySelectedCertIndex: Int = 0
@State private var _isSavingPresetAlertPresented = false
@State private var _newPresetName = ""
	
	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _isBatchQueuePresenting = false
	@State private var _isImportingPresenting = false
	@State private var _isDownloadingPresenting = false
	@State private var _alertDownloadString: String = "" // for _isDownloadingPresenting
	@State private var _updateCheckRotation = 0.0
	@State private var _isUpdateCheckCompleteVisible = false
	
	// MARK: Selection State
	@State private var _selectedAppUUIDs: Set<String> = []
	@State private var _editMode: EditMode = .inactive
	
	@State private var _searchText = ""
	@State private var _selectedScope: Scope = .all
		@State private var _selectedLibrarySegment: Int = 0
	
	
	@Namespace private var _namespace
	
	// horror
	private func filteredAndSortedApps<T>(from apps: FetchedResults<T>) -> [T] where T: NSManagedObject {
		apps.filter {
			_searchText.isEmpty ||
				(($0.value(forKey: "name") as? String)?.localizedCaseInsensitiveContains(_searchText) ?? false)
		}
	}
	
	private var _filteredSignedApps: [Signed] {
		filteredAndSortedApps(from: _signedApps)
	}
	
	private var _filteredImportedApps: [Imported] {
		filteredAndSortedApps(from: _importedApps)
	}
	
	// MARK: Fetch
	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>
	
	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>
	
	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>
		private var _certificateWarningInfo: (title: String, message: String, color: Color, icon: String)? {
		guard !_libraryCertificates.isEmpty, _librarySelectedCertIndex >= 0, _librarySelectedCertIndex < _libraryCertificates.count else {
			return ("Chưa có chứng chỉ mặc định", "Vui lòng thêm hoặc chọn chứng chỉ trong Cài đặt.", .orange, "exclamationmark.triangle.fill")
		}
		let cert = _libraryCertificates[_librarySelectedCertIndex]
		if cert.revoked || _ocspCache.status(for: cert) == .revoked {
			return ("Chứng chỉ đã bị thu hồi", "Chứng chỉ mặc định hiện tại đã bị thu hồi.", .red, "xmark.octagon.fill")
		}
		if let expiration = cert.expiration {
			if expiration <= Date() {
				return ("Chứng chỉ đã hết hạn", "Chứng chỉ mặc định đã hết hạn.", .red, "exclamationmark.circle.fill")
			}
			let days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
			if days <= 7 {
				return ("Chứng chỉ sắp hết hạn", "Chứng chỉ mặc định còn \(days) ngày nữa sẽ hết hạn.", .orange, "exclamationmark.triangle.fill")
			}
		}
		return nil
		}
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Library")) {
			NBListAdaptable { 
				if let warning = _certificateWarningInfo {
					Section {
						HStack(spacing: 12) {
							Image(systemName: warning.icon)
								.font(.title3)
								.foregroundStyle(warning.color)
							VStack(alignment: .leading, spacing: 2) {
								Text(warning.title)
									.font(.subheadline.weight(.semibold))
								Text(warning.message)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							Spacer()
						}
						.padding(.vertical, 4)
					}
				}
				Section { Picker("", selection: $_selectedLibrarySegment) { Text("Đã nhập (\(_filteredImportedApps.count))").tag(0); Text("Đã ký (\(_filteredSignedApps.count))").tag(1) }.pickerStyle(.segmented) }
								if _selectedLibrarySegment == 0 {
					Section {
						Menu {
							ForEach(_presetManager.builtInPresets) { preset in
								Button {
									_presetManager.selectDefault(preset.id)
								} label: {
									if _presetManager.activePreset.id == preset.id {
										Label(preset.name, systemImage: "checkmark")
									} else {
										Text(preset.name)
									}
								}
							}
							if !_presetManager.customPresets.isEmpty {
								Divider()
								ForEach(_presetManager.customPresets) { preset in
									Button {
										_presetManager.selectDefault(preset.id)
									} label: {
										if _presetManager.activePreset.id == preset.id {
											Label(preset.name, systemImage: "checkmark")
										} else {
											Text(preset.name)
										}
									}
								}
							}
							Divider()
							Button {
								_newPresetName = ""
								_isSavingPresetAlertPresented = true
							} label: {
								Label("Lưu cấu hình hiện tại làm Preset...", systemImage: "plus.circle")
							}
						} label: {
							HStack {
								Label("Preset: \(_presetManager.activePreset.name)", systemImage: "slider.horizontal.3")
								Spacer()
								Image(systemName: "chevron.up.chevron.down")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
						}
					}
								}
				if _selectedLibrarySegment == 0 { Section { Button { _isBatchQueuePresenting = true } label: { Label("Chọn để ký hàng loạt", systemImage: "square.stack.3d.up") } } }
				if
					!_filteredSignedApps.isEmpty,
					_selectedLibrarySegment == 1
				{
					NBSection(
						.localized("Signed"),
						secondary: _filteredSignedApps.count.description
					) {
						ForEach(_filteredSignedApps, id: \.uuid) { app in
							LibraryCellView(
								app: app,
								selectedInfoAppPresenting: $_selectedInfoAppPresenting,
								selectedSigningAppPresenting: $_selectedSigningAppPresenting,
								selectedInstallAppPresenting: $_selectedInstallAppPresenting,
								selectedAppUUIDs: $_selectedAppUUIDs
							)
							.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
						}
					}
				}
				
				if
					!_filteredImportedApps.isEmpty,
					_selectedLibrarySegment == 0
				{
					NBSection(
						.localized("Imported"),
						secondary: _filteredImportedApps.count.description
					) {
						ForEach(_filteredImportedApps, id: \.uuid) { app in
							LibraryCellView(
								app: app,
								selectedInfoAppPresenting: $_selectedInfoAppPresenting,
								selectedSigningAppPresenting: $_selectedSigningAppPresenting,
								selectedInstallAppPresenting: $_selectedInstallAppPresenting,
								selectedAppUUIDs: $_selectedAppUUIDs
							)
							.compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
						}
					}
				}
			}
			.searchable(text: $_searchText, placement: .platform())
			.compatSearchScopes($_selectedScope) {
				ForEach(Scope.allCases, id: \.displayName) { scope in
					Text(scope.displayName).tag(scope)
				}
			}
			.scrollDismissesKeyboard(.interactively)
			.alert("Lưu Preset ký", isPresented: $_isSavingPresetAlertPresented) {
				TextField("Tên preset", text: $_newPresetName)
				Button("Lưu") {
					let trimmed = _newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
					if !trimmed.isEmpty {
						_presetManager.saveCustomPreset(name: trimmed, options: OptionsManager.shared.options)
					}
				}
				Button("Hủy", role: .cancel) {}
			} message: {
				Text("Lưu cấu hình tùy chọn ký hiện tại thành một preset mới.")
			}
			.overlay {
				if
					_filteredSignedApps.isEmpty,
					_filteredImportedApps.isEmpty
				{
					if #available(iOS 17, *) {
						ContentUnavailableView {
							Label(.localized("No Apps"), systemImage: "questionmark.app.fill")
						} description: {
							Text(.localized("Get started by importing your first IPA file."))
						} actions: {
							Menu {
								_importActions()
							} label: {
								NBButton(.localized("Import"), style: .text)
							}
						}
					}
				}
			}
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					EditButton()
				}
				
				if _editMode.isEditing {
					NBToolbarButton(
						.localized("Delete"),
						systemImage: "trash",
						isDisabled: _selectedAppUUIDs.isEmpty
					) {
						_bulkDeleteSelectedApps()
					}
				} else {
					ToolbarItem(placement: .topBarTrailing) {
						Button {
							Task {
								await _checkForUpdates()
							}
						} label: {
							Image(systemName: _isUpdateCheckCompleteVisible ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
								.rotationEffect(.degrees(_updateCheckRotation))
								.animation(
									updateManager.isChecking
										? .linear(duration: 0.8).repeatForever(autoreverses: false)
										: .default,
									value: _updateCheckRotation
								)
						}
						.disabled(updateManager.isChecking)
						.accessibilityLabel(.localized("Check for Updates"))
					}
					ToolbarItem(placement: .topBarTrailing) { Button { _isBatchQueuePresenting = true } label: { Label("Ký hàng loạt", systemImage: "square.stack.3d.up") } }
					
					NBToolbarMenu(
						systemImage: "plus",
						style: .icon,
						placement: .topBarTrailing
					) {
						_importActions()
					}
				}
			}
			.environment(\.editMode, $_editMode) .sheet(isPresented: $_isBatchQueuePresenting) { XSignBatchQueueSheet(apps: Array(_importedApps)) }
			.sheet(item: $_selectedInfoAppPresenting) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallAppPresenting) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(200)])
					.presentationDragIndicator(.visible)
			}
			.fullScreenCover(item: $_selectedSigningAppPresenting) { app in
				SigningView(app: app.base)
					.compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.ipa, .tipa],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						guard !urls.isEmpty else { return }
						
						for url in urls {
							let id = "FeatherManualDownload_\(UUID().uuidString)"
							let dl = downloadManager.startArchive(from: url, id: id)
							try? downloadManager.handlePachageFile(url: url, dl: dl)
						}
					}
				)
				.ignoresSafeArea()
			}
			.alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
				TextField(.localized("URL"), text: $_alertDownloadString)
					.textInputAutocapitalization(.never)
				Button(.localized("Cancel"), role: .cancel) {
					_alertDownloadString = ""
				}
				Button(.localized("OK")) {
					if let url = URL(string: _alertDownloadString) {
						_ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name("Feather.installApp"))) { _ in
				if let latest = _signedApps.first {
					_selectedInstallAppPresenting = AnyApp(base: latest)
				}
			}
			.onChange(of: _editMode) { mode in
				if mode == .inactive {
					_selectedAppUUIDs.removeAll()
				}
			}
			.onChange(of: updateManager.isChecking) { isChecking in
				_handleUpdateCheckStateChange(isChecking)
			}
		}
	}
}

// MARK: - Extension: View
extension LibraryView {
	@ViewBuilder
	private func _importActions() -> some View {
		Button(.localized("Import from Files"), systemImage: "folder") {
			_isImportingPresenting = true
		}
		Button(.localized("Import from URL"), systemImage: "globe") {
			_isDownloadingPresenting = true
		}
	}
}

// MARK: - Extension: Bulk Delete
extension LibraryView {
	private func _bulkDeleteSelectedApps() {
		let selectedApps = _getAllApps().filter { app in
			guard let uuid = app.uuid else { return false }
			return _selectedAppUUIDs.contains(uuid)
		}
		
		for app in selectedApps {
			Storage.shared.deleteApp(for: app)
		}
		
		_selectedAppUUIDs.removeAll()
		
		// _editMode = .inactive
	}
	
	private func _getAllApps() -> [AppInfoPresentable] {
		var allApps: [AppInfoPresentable] = []
		
		if _selectedScope == .all || _selectedScope == .signed {
			allApps.append(contentsOf: _filteredSignedApps)
		}
		
		if _selectedScope == .all || _selectedScope == .imported {
			allApps.append(contentsOf: _filteredImportedApps)
		}
		
		return allApps
	}
	
	private func _checkForUpdates() async {
		let localApps = _signedApps.map { $0 as AppInfoPresentable } + _importedApps.map { $0 as AppInfoPresentable }
		await updateManager.checkForUpdates(
			sources: Array(_sources),
			localApps: localApps
		)
	}
	
	private func _handleUpdateCheckStateChange(_ isChecking: Bool) {
		if isChecking {
			_isUpdateCheckCompleteVisible = false
			_updateCheckRotation = 0
			withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
				_updateCheckRotation = 360
			}
		} else {
			withAnimation(.none) {
				_updateCheckRotation = 0
			}
			
			_isUpdateCheckCompleteVisible = true
			Task { @MainActor in
				try? await Task.sleep(nanoseconds: 900_000_000)
				if !updateManager.isChecking {
					_isUpdateCheckCompleteVisible = false
				}
			}
		}
	}
}

// MARK: - Extension: View (Sort)
extension LibraryView {
	enum Scope: CaseIterable {
		case all
		case signed
		case imported
		
		var displayName: String {
			switch self {
			case .all: return .localized("All")
			case .signed: return .localized("Signed")
			case .imported: return .localized("Imported")
			}
		}
	}

private struct XSignBatchQueueSheet: View {
	let apps: [Imported]

	@Environment(\.dismiss) private var dismiss

	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
	) private var certificates: FetchedResults<CertificatePair>

	@State private var _selectedIds: Set<NSManagedObjectID> = []
	@State private var _selectedCerts: [NSManagedObjectID: CertificatePair] = [:]
	@State private var _statuses: [NSManagedObjectID: String] = [:]
	@State private var _isRunning = false
	@State private var _completedCount = 0

	private var _selectedApps: [Imported] {
		apps.filter { _selectedIds.contains($0.objectID) }
	}

	private func _certName(for cert: CertificatePair?) -> String {
		guard let cert else { return "Chưa có chứng chỉ" }
		return cert.nickname ?? Storage.shared.getProvisionFileDecoded(for: cert)?.Name ?? .localized("Unknown")
	}

	private func _statusColor(for status: String) -> Color {
		if status == "Thành công" { return .green }
		if status.hasPrefix("Lỗi") { return .red }
		if status == "Đang ký..." { return .accentColor }
		return .secondary
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				if _isRunning || _completedCount > 0 {
					VStack(alignment: .leading, spacing: 6) {
						HStack {
							Text(_isRunning ? "Đang ký hàng loạt..." : "Hoàn tất hàng đợi")
								.font(.subheadline.weight(.semibold))
							Spacer()
							Text("\(_completedCount)/\(_selectedApps.count)")
								.font(.subheadline.monospacedDigit())
								.foregroundStyle(.secondary)
						}
						ProgressView(
							value: Double(_completedCount),
							total: Double(max(1, _selectedApps.count))
						)
					}
					.padding()
					.background(Color(.secondarySystemGroupedBackground))
				}

				List {
					if apps.isEmpty {
						Text("Chưa có IPA nào được nhập.")
							.foregroundStyle(.secondary)
					} else {
						ForEach(apps, id: \.objectID) { app in
							let id = app.objectID
							let isSelected = _selectedIds.contains(id)
							let currentCert = _selectedCerts[id] ?? certificates.first
							let status = _statuses[id] ?? (isSelected ? "Đang chờ" : "")

							VStack(alignment: .leading, spacing: 8) {
								HStack(spacing: 12) {
									Button {
										guard !_isRunning else { return }
										if isSelected {
											_selectedIds.remove(id)
										} else {
											_selectedIds.insert(id)
											if _selectedCerts[id] == nil, let first = certificates.first {
												_selectedCerts[id] = first
											}
										}
									} label: {
										Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
											.font(.title3)
											.foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
									}
									.buttonStyle(.plain)

									FRAppIconView(app: app, size: 40)

									VStack(alignment: .leading, spacing: 2) {
										Text(app.name ?? .localized("Unknown"))
											.font(.headline)
											.lineLimit(1)
										if !status.isEmpty {
											Text(status)
												.font(.caption.weight(.medium))
												.foregroundStyle(_statusColor(for: status))
												.lineLimit(2)
										}
									}

									Spacer()
								}

								if isSelected && !certificates.isEmpty {
									HStack {
										Text("Chứng chỉ:")
											.font(.caption)
											.foregroundStyle(.secondary)
										Spacer()
										Menu {
											ForEach(certificates, id: \.objectID) { cert in
												Button {
													_selectedCerts[id] = cert
												} label: {
													Text(_certName(for: cert))
												}
											}
										} label: {
											HStack(spacing: 4) {
												Text(_certName(for: currentCert))
													.font(.caption.weight(.medium))
													.lineLimit(1)
												Image(systemName: "chevron.up.chevron.down")
													.font(.caption2)
											}
										}
										.disabled(_isRunning)
									}
									.padding(.leading, 36)
								}
							}
							.padding(.vertical, 4)
						}
					}
				}
			}
			.navigationTitle("Ký hàng loạt")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button("Đóng") {
						dismiss()
					}
					.disabled(_isRunning)
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button("Bắt đầu ký hàng loạt") {
						_startBatchSigning()
					}
					.disabled(_isRunning || _selectedApps.isEmpty || certificates.isEmpty)
				}
			}
			.onAppear {
				if let first = certificates.first {
					for app in apps where _selectedCerts[app.objectID] == nil {
						_selectedCerts[app.objectID] = first
					}
				}
			}
			.interactiveDismissDisabled(_isRunning)
		}
	}

	private func _startBatchSigning() {
		let targets = _selectedApps
		guard !targets.isEmpty else { return }

		_isRunning = true
		_completedCount = 0
		for app in targets {
			_statuses[app.objectID] = "Đang chờ"
		}

		Task {
			for app in targets {
				let id = app.objectID
				let cert = _selectedCerts[id] ?? certificates.first
				await MainActor.run {
					_statuses[id] = "Đang ký..."
				}

				let errorMessage: String? = await withCheckedContinuation { continuation in
					FR.signPackageFile(
						app,
						using: XSignPresetManager.shared.effectiveOptions, // using: OptionsManager.shared.options,
						icon: nil,
						certificate: cert
					) { error in
						continuation.resume(returning: error?.localizedDescription)
					}
				}

				await MainActor.run {
					if let errorMessage {
						_statuses[id] = "Lỗi: \(errorMessage)"
					} else {
						_statuses[id] = "Thành công"
					}
					_completedCount += 1
				}
			}

			await MainActor.run {
				_isRunning = false
			}
		}
	}
}
}
private extension XSignPresetManager {
	var activePreset: XSignPreset {
		if let id = defaultPresetID, let match = allPresets.first(where: { $0.id == id }) {
			return match
		}
		return builtInPresets[0]
	}
}

