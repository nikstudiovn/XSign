//
//  ServerView.swift
//  Feather
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
	@AppStorage("Feather.ipFix") private var _ipFix: Bool = false
	@AppStorage("Feather.serverMethod") private var _serverMethod: Int = 1
	private let _serverMethods: [String] = [.localized("Fully Local"), .localized("Semi Local")]
	
	// MARK: Body
	// XSign: "Fully Local" and "Update SSL Certificates" are hidden because the
	// backloop.dev SSL pack they depend on was discontinued.
	var body: some View {
		Group {
			Section {
				Picker(.localized("Server Type"), systemImage: "server.rack", selection: $_serverMethod) {
					Text(_serverMethods[1]).tag(1)
				}
				.onAppear { if _serverMethod != 1 { _serverMethod = 1 } }
				Toggle(.localized("Only use localhost address"), systemImage: "lifepreserver", isOn: $_ipFix)
			}
		}
	}
}
