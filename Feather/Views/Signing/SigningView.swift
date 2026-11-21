//
//  SigningView.swift
//  Feather
//
//  Created by samara on 14.04.2025.
//

import SwiftUI
import PhotosUI
import NimbleViews

// MARK: - View
struct SigningView: View {
	@Environment(\.dismiss) var dismiss
	@StateObject private var _optionsManager = OptionsManager.shared
	
	@State private var _temporaryOptions: Options = OptionsManager.shared.options
	@State private var _temporaryCertificate: Int
	@State private var _isAltPickerPresenting = false
	@State private var _isFilePickerPresenting = false
	@State private var _isImagePickerPresenting = false
	@State private var _isSigning = false
	@State private var _selectedPhoto: PhotosPickerItem? = nil
	@State var appIcon: UIImage?
	@State private var _showProgressSheet = false
@State private var _signingProgress: Double = 0.08
@State private var _signingStepIndex: Int = 1
@State private var _signingDone = false
@State private var _signingError: String? = nil
@State private var _progressTimer: Timer? = nil
	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var certificates: FetchedResults<CertificatePair>
	
	private func _selectedCert() -> CertificatePair? {
		guard certificates.indices.contains(_temporaryCertificate) else { return nil }
		return certificates[_temporaryCertificate]
	}
	
	var app: AppInfoPresentable
	
	init(app: AppInfoPresentable) {
		self.app = app
		let storedCert = UserDefaults.standard.integer(forKey: "XSign.selectedCert")
		__temporaryCertificate = State(initialValue: storedCert)
	}
		
	// MARK: Body
	var body: some View {
		NBNavigationView("", displayMode: .inline) {
			Form {
				_customizationOptions(for: app)
				_cert()
				_customizationProperties(for: app)
				
				// horrible
				Rectangle()
					.foregroundStyle(.clear)
					.frame(height: 30)
					.listRowBackground(EmptyView())
			}
			.overlay {
				VStack(spacing: 0) {
					Spacer()
					NBVariableBlurView()
						.frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 60 : 80)
						.rotationEffect(.degrees(180))
						.overlay {
							Button {
								_start()
							} label: {
								NBSheetButton(title: .localized("Start Signing"), style: .prominent)
									.padding()
							}
							.buttonStyle(.plain)
							.offset(y: UIDevice.current.userInterfaceIdiom == .pad ? -20 : -40)
						}
				}
				.ignoresSafeArea(edges: .bottom)
			}

			.toolbar {
				NBToolbarButton(role: .dismiss)
				ToolbarItem(placement: .principal) {
					Image("Glyph")
						.resizable()
						.scaledToFit()
						.frame(height: 38)
				}
				NBToolbarButton(
					.localized("Reset"),
					style: .text,
					placement: .topBarTrailing
				) {
					_temporaryOptions = OptionsManager.shared.options
					appIcon = nil
				}
			}
			.sheet(isPresented: $_showProgressSheet) {
	XSignProgressSheet(
		app: app,
		appIcon: appIcon,
		cert: _selectedCert(),
		progress: _signingProgress,
		stepIndex: _signingStepIndex,
		isDone: _signingDone,
		errorMessage: _signingError,
		onRetry: {
			_start()
		},
		onInstallNow: {
			_showProgressSheet = false
			dismiss()
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
				NotificationCenter.default.post(name: Notification.Name("XSign.installApp"), object: nil)
			}
		},
		onClose: {
			_showProgressSheet = false
			dismiss()
		}
	)
			}
			.sheet(isPresented: $_isAltPickerPresenting) { SigningAlternativeIconView(app: app, appIcon: $appIcon, isModifing: .constant(true)) }
			.sheet(isPresented: $_isFilePickerPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes:  [.image],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self.appIcon = UIImage.fromFile(selectedFileURL)?.resizeToSquare()
					}
				)
				.ignoresSafeArea()
			}
			.photosPicker(isPresented: $_isImagePickerPresenting, selection: $_selectedPhoto)
			.onChange(of: _selectedPhoto) { newValue in
				guard let newValue else { return }
				
				Task {
					if let data = try? await newValue.loadTransferable(type: Data.self),
					   let image = UIImage(data: data)?.resizeToSquare() {
						appIcon = image
					}
				}
			}
			.disabled(_isSigning)
			.animation(.smooth, value: _isSigning)
		}
		.onAppear {
			// ppq protection
			if
				_optionsManager.options.ppqProtection,
				let identifier = app.identifier,
				let cert = _selectedCert(),
				cert.ppQCheck
			{
				_temporaryOptions.appIdentifier = "\(identifier).\(_optionsManager.options.ppqString)"
			}
			
			if
				let currentBundleId = app.identifier,
				let newBundleId = _temporaryOptions.identifiers[currentBundleId]
			{
				_temporaryOptions.appIdentifier = newBundleId
			}
			
			if
				let currentName = app.name,
				let newName = _temporaryOptions.displayNames[currentName]
			{
				_temporaryOptions.appName = newName
			}
		}
	}
}

// MARK: - Extension: View
extension SigningView {
	@ViewBuilder
	private func _customizationOptions(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("Customization")) {
			Menu {
				Button(.localized("Select Alternative Icon"), systemImage: "app.dashed") { _isAltPickerPresenting = true }
				Button(.localized("Choose from Files"), systemImage: "folder") { _isFilePickerPresenting = true }
				Button(.localized("Choose from Photos"), systemImage: "photo") { _isImagePickerPresenting = true }
			} label: {
				if let icon = appIcon {
					Image(uiImage: icon)
						.appIconStyle()
				} else {
					FRAppIconView(app: app, size: 56)
				}
			}
			
			_infoCell(.localized("Name"), desc: _temporaryOptions.appName ?? app.name) {
				SigningPropertiesView(
					title: .localized("Name"),
					initialValue: _temporaryOptions.appName ?? (app.name ?? ""),
					bindingValue: $_temporaryOptions.appName
				)
			}
			_infoCell(.localized("Identifier"), desc: _temporaryOptions.appIdentifier ?? app.identifier) {
				SigningPropertiesView(
					title: .localized("Identifier"),
					initialValue: _temporaryOptions.appIdentifier ?? (app.identifier ?? ""),
					bindingValue: $_temporaryOptions.appIdentifier
				)
			}
			_infoCell(.localized("Version"), desc: _temporaryOptions.appVersion ?? app.version) {
				SigningPropertiesView(
					title: .localized("Version"),
					initialValue: _temporaryOptions.appVersion ?? (app.version ?? ""),
					bindingValue: $_temporaryOptions.appVersion
				)
			}
		}
	}
	
	@ViewBuilder
	private func _cert() -> some View {
		NBSection(.localized("Signing")) {
			if let cert = _selectedCert() {
				NavigationLink {
					CertificatesView(selectedCert: $_temporaryCertificate)
				} label: {
					CertificatesCellView(
						cert: cert
					)
				}
			} else {
				Text(.localized("No Certificate"))
					.font(.footnote)
					.foregroundColor(.disabled())
			}
		}
	}
	
	@ViewBuilder
	private func _customizationProperties(for app: AppInfoPresentable) -> some View {
		NBSection(.localized("Advanced")) {
			DisclosureGroup(.localized("Modify")) {
				NavigationLink(.localized("Existing Dylibs")) {
					SigningDylibView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
				
				NavigationLink(.localized("Frameworks & PlugIns")) {
					SigningFrameworksView(
						app: app,
						options: $_temporaryOptions.optional()
					)
				}
			
				NavigationLink(.localized("Entitlements") + " (BETA)") {
					SigningEntitlementsView(
						bindingValue: $_temporaryOptions.appEntitlementsFile
					)
				}
				
				NavigationLink(.localized("Tweaks")) {
					SigningTweaksView(
						options: $_temporaryOptions
					)
				}
			}
			
			NavigationLink(.localized("Properties")) {
				Form { SigningOptionsView(
					options: $_temporaryOptions,
					temporaryOptions: _optionsManager.options
				)}
				.navigationTitle(.localized("Properties"))
			}
		}
	}
	
	@ViewBuilder
	private func _infoCell<V: View>(_ title: String, desc: String?, @ViewBuilder destination: () -> V) -> some View {
		NavigationLink {
			destination()
		} label: {
			LabeledContent(title) {
				Text(desc ?? .localized("Unknown"))
			}
		}
	}
}

// MARK: - Extension: View (import)
extension SigningView {
	private func _start() {
		guard
			_selectedCert() != nil || _temporaryOptions.signingOption != .default
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("No Certificate"),
				message: .localized("Please go to settings and import a valid certificate"),
				isCancel: true
			)
			return
		}

		let generator = UIImpactFeedbackGenerator(style: .light)
		generator.impactOccurred()
			_isSigning = true
		_showProgressSheet = true
		_signingProgress = 0.12
		_signingStepIndex = 1
		_signingDone = false
		_signingError = nil
		XSignLiveActivityManager.shared.start(appName: app.name ?? "XSign", stage: .signing, progress: _signingProgress)
		_progressTimer?.invalidate()
		_progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
			DispatchQueue.main.async {
				if _signingStepIndex < 5 {
					_signingStepIndex += 1
					_signingProgress = min(0.88, _signingProgress + 0.19)
				} else {
					_signingProgress = min(0.88, _signingProgress + 0.02)
				}
				XSignLiveActivityManager.shared.update(stage: .signing, progress: _signingProgress)
			}
		}

		FR.signPackageFile(
			app,
			using: _temporaryOptions,
			icon: appIcon,
			certificate: _selectedCert()
		) { error in
			DispatchQueue.main.async {
				_progressTimer?.invalidate()
				_progressTimer = nil

				if let error {
					_signingError = error.localizedDescription
					_isSigning = false
					XSignLiveActivityManager.shared.end(stage: .failed)
					return
				}

				_signingStepIndex = 6
				_signingProgress = 1.0
				_signingDone = true
				_isSigning = false
				XSignLiveActivityManager.shared.refreshWidgetSnapshot()
				// Nếu tự động cài sau khi ký thì activity tiếp tục ở bước cài đặt, ngược lại kết thúc tại đây.
				if _temporaryOptions.post_installAppAfterSigned {
					XSignLiveActivityManager.shared.update(stage: .sending, progress: 0.0)
				} else {
					XSignLiveActivityManager.shared.end(stage: .completed)
				}

				if _temporaryOptions.post_deleteAppAfterSigned, !app.isSigned {
					Storage.shared.deleteApp(for: app)
				}

				if _temporaryOptions.post_installAppAfterSigned {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
						_showProgressSheet = false
						dismiss()
						NotificationCenter.default.post(name: Notification.Name("XSign.installApp"), object: nil)
					}
				}
			}
		}
	}
}

private struct XSignProgressSheet: View {
	let app: AppInfoPresentable
	let appIcon: UIImage?
	let cert: CertificatePair?
	let progress: Double
	let stepIndex: Int
	let isDone: Bool
	let errorMessage: String?
	let onRetry: () -> Void
	let onInstallNow: () -> Void
	let onClose: () -> Void

	private let steps: [String] = [
		"Chuẩn bị tệp & cấu hình",
		"Giải nén gói IPA",
		"Nhúng chứng chỉ & hồ sơ",
		"Ký mã thực thi & frameworks",
		"Đóng gói lại IPA",
		"Hoàn tất & sẵn sàng cài đặt"
	]

	private var certName: String {
		if let cert {
			return cert.nickname ?? Storage.shared.getProvisionFileDecoded(for: cert)?.Name ?? .localized("Unknown")
		}
		return "Default"
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 20) {
				HStack(spacing: 14) {
					if let icon = appIcon {
						Image(uiImage: icon)
							.resizable()
							.scaledToFill()
							.frame(width: 56, height: 56)
							.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
					} else {
						FRAppIconView(app: app, size: 56)
					}

					VStack(alignment: .leading, spacing: 4) {
						Text(app.name ?? .localized("Unknown"))
							.font(.headline)
							.lineLimit(1)
						Text("Chứng chỉ: \(certName)")
							.font(.subheadline)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
					Spacer()
				}
				.padding()
				.background(Color(.secondarySystemGroupedBackground))
				.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

				VStack(alignment: .leading, spacing: 8) {
					HStack {
						Text(errorMessage != nil ? "Ký thất bại" : (isDone ? "Đã ký thành công" : "Đang ký ứng dụng..."))
							.font(.subheadline.weight(.semibold))
						Spacer()
						Text("\(Int(progress * 100))%")
							.font(.subheadline.monospacedDigit())
							.foregroundStyle(.secondary)
					}
					ProgressView(value: progress, total: 1.0)
						.tint(errorMessage != nil ? .red : (isDone ? .green : .accentColor))
				}

				VStack(alignment: .leading, spacing: 12) {
					ForEach(Array(steps.enumerated()), id: \.offset) { offset, title in
						let idx = offset + 1
						HStack(spacing: 12) {
							if errorMessage != nil && idx == stepIndex {
								Image(systemName: "xmark.circle.fill")
									.foregroundStyle(.red)
									.frame(width: 22, height: 22)
							} else if isDone || idx < stepIndex {
								Image(systemName: "checkmark.circle.fill")
									.foregroundStyle(.green)
									.frame(width: 22, height: 22)
							} else if idx == stepIndex {
								ProgressView()
									.controlSize(.small)
									.frame(width: 22, height: 22)
							} else {
								Image(systemName: "circle")
									.foregroundStyle(.secondary.opacity(0.5))
									.frame(width: 22, height: 22)
							}

							Text("\(idx). \(title)")
								.font(.subheadline)
								.foregroundStyle(idx <= stepIndex || isDone ? .primary : .secondary)
							Spacer()
						}
					}
				}
				.padding()
				.background(Color(.secondarySystemGroupedBackground))
				.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

				if let errorMessage {
					VStack(alignment: .leading, spacing: 10) {
						Label("Lỗi khi ký", systemImage: "exclamationmark.triangle.fill")
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(.red)
						Text(errorMessage)
							.font(.caption)
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity, alignment: .leading)
						Button {
							onRetry()
						} label: {
							Text("Thử lại")
								.frame(maxWidth: .infinity)
						}
						.buttonStyle(.borderedProminent)
						.tint(.red)
					}
					.padding()
					.background(Color.red.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
				}

				Spacer()

				if isDone {
					HStack(spacing: 12) {
						Button {
							onClose()
						} label: {
							Text("Đóng")
								.frame(maxWidth: .infinity)
						}
						.buttonStyle(.bordered)

						Button {
							onInstallNow()
						} label: {
							Text("Cài đặt ngay")
								.frame(maxWidth: .infinity)
						}
						.buttonStyle(.borderedProminent)
					}
				}
			}
			.padding()
			.navigationTitle("Tiến trình ký")
			.navigationBarTitleDisplayMode(.inline)
		}
		.interactiveDismissDisabled(!isDone && errorMessage == nil)
	}
}	
