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
						Label(.localized("App Icon"), systemImage: "app.badge")
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
            
			Button(.localized("Submit Feedback"), systemImage: "safari") {
				UIApplication.open(URL(string: "\(_githubUrl)/issues")!)
			}
			Button(.localized("GitHub Repository"), systemImage: "safari") {
				UIApplication.open(_githubUrl)
			} 
			Button("Kênh Telegram (@nikvn21)", systemImage: "paperplane.fill") {
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
				Label(.localized("Open Archives"), systemImage: "folder")
			}
			NavigationLink {
				XSignFolderBrowserView(
					directory: FileManager.default.certificates,
					title: .localized("Open Certificates")
				)
			} label: {
				Label(.localized("Open Certificates"), systemImage: "folder")
			}
		} footer: {
			Text(.localized("All of the apps files are contained in the documents directory, here are some quick links to these."))
		}
	}
}
