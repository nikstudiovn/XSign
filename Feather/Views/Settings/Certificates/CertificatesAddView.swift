//
//  CertificatesAddView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews
import UniformTypeIdentifiers
import Zip

// MARK: - View
struct CertificatesAddView: View {
	@Environment(\.dismiss) private var dismiss
	
	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""
	
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
@State private var _isImportingZipPresenting = false
@State private var _zipStatusMessage: String? = nil
@State private var _tempExtractDir: URL? = nil
@State private var _showPassword = false
	
	var saveButtonDisabled: Bool {
		_p12URL == nil || _provisionURL == nil
	}
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("New Certificate"), displayMode: .inline) {
			Form {
				NBSection(.localized("Files")) {
                    Button {
                        _isImportingZipPresenting = true
                    } label: {
                        Label(xsignT("Nhập nhanh từ tệp .zip", "Quick Import from .zip"), systemImage: "doc.zipper")
					}
					_importButton(.localized("Import Certificate File"), file: _p12URL) {
						_isImportingP12Presenting = true
					}
					_importButton(.localized("Import Provisioning File"), file: _provisionURL) {
						_isImportingMobileProvisionPresenting = true
					}
                    if let _zipStatusMessage {
                        Text(_zipStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
					}
				}
				NBSection(.localized("Password")) {
                    HStack {
                        if _showPassword {
                            TextField(.localized("Enter Password"), text: $_p12Password)
                        } else {
					SecureField(.localized("Enter Password"), text: $_p12Password)
                        }
                        Button {
                            _showPassword.toggle()
                        } label: {
                            Image(systemName: _showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
					}
				} footer: {
					Text(.localized("Enter the password associated with the private key. Leave it blank if theres no password required."))
				}
				
				Section {
					TextField(.localized("Nickname (Optional)"), text: $_certificateName)
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
				
				NBToolbarButton(
					.localized("Save"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.p12],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._p12URL = selectedFileURL
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.mobileProvision],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._provisionURL = selectedFileURL
					}
				)
				.ignoresSafeArea()
			}
            .sheet(isPresented: $_isImportingZipPresenting) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.zip],
                    onDocumentsPicked: { urls in
                        guard let selectedFileURL = urls.first else { return }
                        _handleZipImport(selectedFileURL)
                    }
                )
                .ignoresSafeArea()
            }
            .onDisappear {
                if let dir = _tempExtractDir {
                    try? FileManager.default.removeItem(at: dir)
                }
			}
		}
	}
}

// MARK: - Extension: View
extension CertificatesAddView {
	@ViewBuilder
	private func _importButton(
		_ title: String,
		file: URL?,
		action: @escaping () -> Void
	) -> some View {
		Button {
			action()
		} label: {
            HStack {
                Text(title)
                if let file {
                    Spacer()
                    Text(file.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
		}
		.foregroundColor(file == nil ? .accentColor : .disabled())
		.disabled(file != nil)
		.animation(.easeInOut(duration: 0.3), value: file != nil)
	}
}

// MARK: - Extension: View (import)
extension CertificatesAddView {
	private func _saveCertificate() {
		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("Bad Password"),
				message: .localized("Please check the password and try again.")
			)
			return
		}
		
		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _p12Password,
			certificateName: _certificateName
		) { _ in
			dismiss()
		}
	}

    private func _handleZipImport(_ zipURL: URL) {
        let didStartAccessing = zipURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                zipURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        if let oldDir = _tempExtractDir {
            try? fileManager.removeItem(at: oldDir)
            _tempExtractDir = nil
        }

        let localZip = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        let extractDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

        defer {
            try? fileManager.removeItem(at: localZip)
        }

        do {
            try fileManager.copyItem(at: zipURL, to: localZip)
            try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try Zip.unzipFile(localZip, destination: extractDir, overwrite: true, password: nil)
            _tempExtractDir = extractDir

            var foundP12: URL? = nil
            var foundProvision: URL? = nil
            var txtCandidates: [URL] = []

            if let enumerator = fileManager.enumerator(
                at: extractDir,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
            ) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathComponents.contains("__MACOSX") || fileURL.lastPathComponent.hasPrefix("._") {
                        continue
                    }

                    let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    guard values?.isRegularFile == true else { continue }

                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "p12" && foundP12 == nil {
                        foundP12 = fileURL
                    } else if ext == "mobileprovision" && foundProvision == nil {
                        foundProvision = fileURL
                    } else if ext == "txt", (values?.fileSize ?? Int.max) <= 4096 {
                        txtCandidates.append(fileURL)
                    }
                }
            }

            if let p12 = foundP12 {
                _p12URL = p12
            }
            if let provision = foundProvision {
                _provisionURL = provision
            }

            let keywords = ["pass", "pw", "mk", "matkhau"]
            let prioritizedTxt = txtCandidates.first { url in
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                return keywords.contains { name.contains($0) }
            } ?? txtCandidates.first

            var detectedPassword: String? = nil
            if let txtURL = prioritizedTxt,
               let content = try? String(contentsOf: txtURL, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if var firstLine = lines.first {
                    let lower = firstLine.lowercased()
                    if lower.hasPrefix("password:") {
                        firstLine = String(firstLine.dropFirst("password:".count))
                    } else if lower.hasPrefix("pass:") {
                        firstLine = String(firstLine.dropFirst("pass:".count))
                    }
                    let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        _p12Password = cleaned
                        detectedPassword = cleaned
                    }
                }
            }

            if _certificateName.isEmpty {
                _certificateName = zipURL.deletingPathExtension().lastPathComponent
            }

            if foundP12 == nil || foundProvision == nil {
                var missing: [String] = []
                if foundP12 == nil { missing.append(".p12") }
                if foundProvision == nil { missing.append(".mobileprovision") }
                let message = xsignT("Không tìm thấy tệp \(missing.joined(separator: " và ")) trong tệp .zip.", "Could not find \(missing.joined(separator: " and ")) in the .zip file.")
                _zipStatusMessage = message
                UIAlertController.showAlertWithOk(
                    title: xsignT("Thiếu tệp chứng chỉ", "Missing Certificate Files"),
                    message: message
                )
            } else {
                var parts: [String] = [
                    xsignT("Đã nạp: \(foundP12!.lastPathComponent)", "Loaded: \(foundP12!.lastPathComponent)"),
                    foundProvision!.lastPathComponent
                ]
                if detectedPassword != nil {
                    parts.append(xsignT("đã tự điền mật khẩu", "password auto-filled"))
                }
                _zipStatusMessage = parts.joined(separator: ", ")
            }
        } catch {
            try? fileManager.removeItem(at: extractDir)
            let message = xsignT("Không thể giải nén tệp .zip: \(error.localizedDescription)", "Could not extract the .zip file: \(error.localizedDescription)")
            _zipStatusMessage = message
            UIAlertController.showAlertWithOk(
                title: xsignT("Lỗi giải nén", "Extraction Error"),
                message: message
            )
        }
	}
}

