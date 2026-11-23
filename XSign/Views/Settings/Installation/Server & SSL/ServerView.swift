//
//  ServerView.swift
//  XSign
//
//  Created by samara on 6.05.2025.
//

import SwiftUI
import NimbleJSON
import NimbleViews

// MARK: - Extension: Model
extension ServerView {
	struct ServerPackModel: Decodable {
		var cert: String
		var ca: String
		var key: String
		var info: ServerPackInfo
		
		private enum CodingKeys: String, CodingKey {
			case cert, ca, key1, key2, info
		}
		
		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			cert = try container.decode(String.self, forKey: .cert)
			ca = try container.decode(String.self, forKey: .ca)
			let key1 = try container.decode(String.self, forKey: .key1)
			let key2 = try container.decode(String.self, forKey: .key2)
			key = key1 + key2
			info = try container.decode(ServerPackInfo.self, forKey: .info)
		}
		
		struct ServerPackInfo: Decodable {
			var issuer: Domains
			var domains: Domains
		}
		
		struct Domains: Decodable {
			var commonName: String
			
			private enum CodingKeys: String, CodingKey {
				case commonName = "commonName"
			}
		}
	}
}

// MARK: - View
struct ServerView: View {
	@AppStorage("XSign.serverMethod") private var _serverMethod: Int = 1
	@AppStorage(ServerInstaller.manifestServerKey) private var _manifestServer: String = ""
	@State private var _isChecking = false
	@State private var _checkResult: String?
	private let _serverMethods: [String] = [.localized("Fully Local"), .localized("Semi Local")]
	
	// MARK: Body
	// XSign: "Fully Local" and "Update SSL Certificates" are hidden because the
	// backloop.dev SSL pack they depend on was discontinued.
	// "Only use localhost address" is removed: Semi Local always uses 127.0.0.1 now.
	var body: some View {
		Group {
			Section {
				Picker(.localized("Server Type"), systemImage: "server.rack", selection: $_serverMethod) {
					Text(_serverMethods[1]).tag(1)
				}
				.onAppear { if _serverMethod != 1 { _serverMethod = 1 } }
			}
			
			Section {
				TextField(ServerInstaller.defaultManifestServer, text: $_manifestServer)
					.keyboardType(.URL)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.onChange(of: _manifestServer) { _ in _checkResult = nil }
				
				Button {
					_checkManifestServer()
				} label: {
					HStack {
						Label(String.localized("Check Manifest Server"), systemImage: "checkmark.shield")
						Spacer()
						if _isChecking {
							ProgressView()
						} else if let _checkResult {
							Text(_checkResult)
								.foregroundStyle(.secondary)
						}
					}
				}
				.disabled(_isChecking)
			} header: {
				Text(String.localized("Manifest Server"))
			} footer: {
				Text(String.localized("HTTPS server that generates the install manifest. Leave empty to use the default XSign server. If it is unreachable, XSign falls back to the default server, then api.palera.in."))
			}
		}
	}
	
	private func _checkManifestServer() {
		let raw = _manifestServer.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let base = ServerInstaller.normalizedManifestServer(raw.isEmpty ? ServerInstaller.defaultManifestServer : raw) else {
			_checkResult = String.localized("Invalid HTTPS URL")
			return
		}
		
		_isChecking = true
		_checkResult = nil
		
		Task {
			let ok = await ServerInstaller.isManifestServerHealthy(base, timeout: 5)
			await MainActor.run {
				_isChecking = false
				_checkResult = ok ? String.localized("Working") : String.localized("Unreachable")
			}
		}
	}
}
