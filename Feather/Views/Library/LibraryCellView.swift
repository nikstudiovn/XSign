//
//  LibraryAppIconView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleExtensions
import NimbleViews

// MARK: - View
struct LibraryCellView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.editMode) private var editMode
	@ObservedObject private var updateManager = UpdateManager.shared
	@State private var _signedUpdateConfirmation: AppUpdate?
	@State private var _isSignedUpdateConfirmationPresented = false
	@FetchRequest(entity: CertificatePair.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]) private var _certificates: FetchedResults<CertificatePair>
	@AppStorage("XSign.selectedCert") private var _selectedCertIndex: Int = 0
	@State private var _isQuickSigning = false
	@State private var _selectedAppCertURI: String? = nil
	@State private var _isAppActionsDialogPresented = false

	private var _perAppCertKey: String? {
		guard let uuid = app.uuid else { return nil }
		return "XSign.appQuickCert.\(uuid)"
	}

	var certInfo: Date.ExpirationInfo? {
		Storage.shared.getCertificate(from: app)?.expiration?.expirationInfo()
	}
	
	var certRevoked: Bool {
		Storage.shared.getCertificate(from: app)?.revoked == true
	}
	
	var app: AppInfoPresentable
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedInstallAppPresenting: AnyApp?
	@Binding var selectedAppUUIDs: Set<String>
	
	// MARK: Selections
	private var _isSelected: Bool {
		guard let uuid = app.uuid else { return false }
		return selectedAppUUIDs.contains(uuid)
	}
	
	private func _toggleSelection() {
		guard let uuid = app.uuid else { return }
		if selectedAppUUIDs.contains(uuid) {
			selectedAppUUIDs.remove(uuid)
		} else {
			selectedAppUUIDs.insert(uuid)
		}
	}
	
	// MARK: Body
	var body: some View {
		let isEditing = editMode?.wrappedValue == .active
		
		Group {
			if isEditing {
				_rowContent(isEditing: true)
					.contentShape(Rectangle())
					.onTapGesture { _toggleSelection() }
			} else {
				// Nhấn 1 lần mở menu ngay; nhấn giữ cũng mở đúng menu này
				// (không gắn thêm contextMenu để tránh xung đột gesture).
				Button {
					_isAppActionsDialogPresented = true
				} label: {
					_rowContent(isEditing: false)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.foregroundStyle(.primary)
				.disabled(_isQuickSigning)
				.contextMenu {
					Button {
						_setAppCertificate(nil)
					} label: {
						if _selectedAppCertURI == nil {
							Label(xsignT("Mặc định (theo Cài đặt)", "Default (from Settings)"), systemImage: "checkmark")
						} else {
							Text(xsignT("Mặc định (theo Cài đặt)", "Default (from Settings)"))
						}
					}
					ForEach(_certificates, id: \.objectID) { cert in
						let certURI = cert.objectID.uriRepresentation().absoluteString
						Button {
							_setAppCertificate(cert)
						} label: {
							let title = cert.nickname ?? "Chứng chỉ"
							if _selectedAppCertURI == certURI {
								Label(title, systemImage: "checkmark")
							} else {
								Text(title)
							}
						}
					}
					if let effectiveCert = _effectiveCertificate() {
						Divider()
						Button {
							_quickSignAndInstall(app, certificate: effectiveCert)
						} label: {
							Label(xsignT("Ký & cài ngay", "Sign & Install Now"), systemImage: "signature")
						}
					}
				}
					.confirmationDialog(app.name ?? .localized("Unknown"), isPresented: $_isAppActionsDialogPresented, titleVisibility: .visible) { _menuActions(for: app) }
			}
		}
		.swipeActions {
			if !isEditing {
				_actions(for: app)
			}
		}
		.confirmationDialog(
			.localized("Update Available"),
			isPresented: $_isSignedUpdateConfirmationPresented,
			titleVisibility: .visible
		) {
			Button(.localized("Install Current Version"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			if let update = _signedUpdateConfirmation {
				Button(.localized("Download Update"), systemImage: "arrow.down.circle") {
					_startUpdateDownload(update)
				}
			}
			Button(.localized("Cancel"), role: .cancel) {}
		} message: {
			if let update = _signedUpdateConfirmation {
				Text(verbatim: "\(update.appName) \(update.remoteVersion)")
			}
		}
		.onAppear {
			if let key = _perAppCertKey {
				_selectedAppCertURI = UserDefaults.standard.string(forKey: key)
			}
		}
	}
	
	private var _desc: String {
		if let version = app.version, let id = app.identifier {
			return "\(version) • \(id)"
		} else {
			return .localized("Unknown")
		}
	}
	
	@ViewBuilder
	private func _rowContent(isEditing: Bool) -> some View {
		let isRegular = horizontalSizeClass != .compact
		HStack(spacing: 18) {
			if isEditing {
				Image(systemName: _isSelected ? "checkmark.circle.fill" : "circle")
					.foregroundColor(_isSelected ? .accentColor : .secondary)
					.font(.title2)
			}

			
			_appIcon(for: app)
			VStack(alignment: .leading, spacing: 4) {
			
			NBTitleWithSubtitleView(
				title: app.name ?? .localized("Unknown"),
				subtitle: _desc,
				linelimit: 0
			)
				if _selectedAppCertURI != nil, let customCert = _effectiveCertificate() {
					HStack(spacing: 4) { Image(systemName: "checkmark.seal.fill"); Text(customCert.nickname ?? .localized("Certificate")) }.font(.caption2.weight(.medium)).foregroundStyle(.tint).padding(.horizontal, 6).padding(.vertical, 2).background(.tint.opacity(0.12), in: Capsule())
				}
			}
			
			Spacer(minLength: 0)
			
			if !isEditing {
				_statusAccessory(for: app)
			}
		}
		.padding(isRegular ? 12 : 0)
		.background(
			isRegular
				? RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(_isSelected && isEditing ? Color.accentColor.opacity(0.1) : Color(.quaternarySystemFill))
				: nil
		)
	}
}


// MARK: - Extension: View
extension LibraryCellView {
	private func _appIcon(for app: AppInfoPresentable) -> some View {
		FRAppIconView(app: app, size: 57)
			.overlay(alignment: .topTrailing) {
				if updateManager.update(for: app) != nil {
					Image(systemName: "arrow.down.circle.fill")
						.font(.system(size: 18, weight: .semibold))
						.symbolRenderingMode(.palette)
						.foregroundStyle(.white, Color.accentColor)
						.background(
							Circle()
								.fill(Color(.systemBackground))
								.frame(width: 20, height: 20)
						)
						.offset(x: 5, y: -5)
						.accessibilityLabel(.localized("Update Available"))
				}
			}
	}
	
	@ViewBuilder
	private func _actions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}
	
	/// Chỉ hiển thị trạng thái (không tương tác) để hàng gọn gàng.
	@ViewBuilder
	private func _statusAccessory(for app: AppInfoPresentable) -> some View {
		if _isQuickSigning {
			ProgressView()
		} else if app.isSigned {
			FRExpirationPillView(
				title: .localized("Install"),
				revoked: certRevoked,
				expiration: certInfo
			)
			.allowsHitTesting(false)
		}
	}
	
	/// Menu tùy chọn dùng chung cho nhấn 1 lần và nhấn giữ.
	@ViewBuilder
	private func _menuActions(for app: AppInfoPresentable) -> some View {
		Button(xsignT("Xem thông tin", "View Info"), systemImage: "info.circle") {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
		
		if let update = updateManager.update(for: app) {
			Button(.localized("Update"), systemImage: "arrow.down.circle") {
				if app.isSigned {
					_signedUpdateConfirmation = update
					_isSignedUpdateConfirmationPresented = true
				} else {
					_startUpdateDownload(update)
				}
			}
		}
		
		Divider()
				let quickCertTitle: String = {
			if _selectedAppCertURI != nil, let name = _effectiveCertificate()?.nickname, !name.isEmpty {
				return "\(xsignT("Ký & cài", "Sign & Install")) (\(name))"
			}
			return xsignT("Ký & cài", "Sign & Install")
		}()
		Button(quickCertTitle, systemImage: "bolt.badge.checkmark") {
			_quickSignAndInstall(app, certificate: _effectiveCertificate())
		}
		if _certificates.count > 1 {
			Menu {
				ForEach(_certificates, id: \.objectID) { cert in
					Button(cert.nickname ?? .localized("Certificate"), systemImage: "checkmark.seal") {
						_quickSignAndInstall(app, certificate: cert)
					}
				}
			} label: {
				Label(xsignT("Ký & cài bằng chứng chỉ…", "Sign & Install with Certificate…"), systemImage: "checkmark.seal")
			}
		}
		if app.isSigned {
			Button(xsignT("Ký lại", "Re-sign"), systemImage: "signature") {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
		} else {
			Button(xsignT("Ký", "Sign"), systemImage: "signature") {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
		}
		
		if app.isSigned {
			Button(xsignT("Cài đặt", "Install"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			if let id = app.identifier {
				Button(.localized("Open"), systemImage: "app.badge.checkmark") {
					UIApplication.openApp(with: id)
				}
			}
			Button(.localized("Export"), systemImage: "square.and.arrow.up") {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		}
		
		Divider()
		
		Button(xsignT("Xóa", "Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}
	
	private func _startUpdateDownload(_ update: AppUpdate) {
		_ = DownloadManager.shared.startDownload(
			from: update.downloadURL,
			id: "FeatherManualDownload_Update_\(update.localUUID)",
			sourceProvenance: update.sourceProvenance
		)
	}
	
	private func _defaultCertificate() -> CertificatePair? {
		if _selectedCertIndex >= 0 && _selectedCertIndex < _certificates.count {
			return _certificates[_selectedCertIndex]
		}
		return _certificates.first
	}

	private func _effectiveCertificate() -> CertificatePair? {
		if let uri = _selectedAppCertURI,
		   let matched = _certificates.first(where: { $0.objectID.uriRepresentation().absoluteString == uri }) {
			return matched
		}
		return _defaultCertificate()
	}

	private func _setAppCertificate(_ cert: CertificatePair?) {
		let uri = cert?.objectID.uriRepresentation().absoluteString
		_selectedAppCertURI = uri
		if let key = _perAppCertKey {
			if let uri {
				UserDefaults.standard.set(uri, forKey: key)
			} else {
				UserDefaults.standard.removeObject(forKey: key)
			}
		}
	}
	
	private func _quickSignAndInstall(_ app: AppInfoPresentable, certificate: CertificatePair?) {
		guard let cert = certificate else {
			UIAlertController.showAlertWithOk(
				title: .localized("Error"),
				message: .localized("No certificate selected.")
			)
			return
		}
		_isQuickSigning = true
		XSignQuickSigner.signAndInstall(app, certificate: cert) { error in
			_isQuickSigning = false
			if let error {
				UIAlertController.showAlertWithOk(
					title: .localized("Error"),
					message: error.localizedDescription
				)
			}
		}
	}
}
