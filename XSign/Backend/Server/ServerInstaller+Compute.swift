//
//  Server+Compute.swift
//  xsign
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR XSIGN
//

import Foundation
import UIKit.UIGraphicsImageRenderer

extension ServerInstaller {
	var plistEndpoint: URL {
		var comps = URLComponents()
		comps.scheme = self.getServerMethod() == 1 ? "http" : "https"
		comps.host = sni()
		comps.path = "/\(id).plist"
		comps.port = port
		return comps.url!
	}

	var payloadEndpoint: URL {
		var comps = URLComponents()
		comps.scheme = self.getServerMethod() == 1 ? "http" : "https"
		comps.host = sni()
		comps.path = "/\(id).ipa"
		comps.port = port
		return comps.url!
	}
	
	var pageEndpoint: URL {
		var comps = URLComponents()
		comps.scheme = self.getServerMethod() == 1 ? "http" : "https"
		comps.host = sni()
		comps.path = "/install"
		comps.port = port
		return comps.url!
	}
	
	/// Manifest URL (percent-encoded once more, ready to be used as the `url` value of an
	/// itms-services link) for the first configured manifest server.
	var externalServerLink: String {
		externalServerLink(base: Self.manifestServerCandidates.first ?? Self.defaultManifestServer)
	}
	
	/// Builds `<base>/genPlist?bundleid=&name=&version=&fetchurl=` with every value
	/// percent-encoded, then encodes the whole manifest URL for the itms-services `url` parameter.
	func externalServerLink(base: String) -> String {
		let name = (app.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		let version = (app.version ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
		let params: [(String, String)] = [
			("bundleid", app.identifier ?? ""),
			("name", name.isEmpty ? "App" : name),
			("version", version.isEmpty ? "1.0" : version),
			("fetchurl", payloadEndpoint.absoluteString),
		]
		let query = params.map { "\($0.0)=\(Self._percentEncode($0.1))" }.joined(separator: "&")
		return Self._percentEncode("\(base)/genPlist?\(query)")
	}

	var iTunesLink: String {
		_iTunesLink(with: plistEndpoint.absoluteString)
	}
	
	var iTunesLinkExternal: String {
		_iTunesLink(with: externalServerLink)
	}
	
	/// XSign: picks the first reachable manifest server (custom URL, then the XSign worker),
	/// checked via `/health`, and falls back to api.palera.in.
	func resolveITunesLinkExternal() async -> String {
		for base in Self.manifestServerCandidates where base != Self.legacyManifestServer {
			if await Self.isManifestServerHealthy(base) {
				return _iTunesLink(with: externalServerLink(base: base))
			}
		}
		return _iTunesLink(with: externalServerLink(base: Self.legacyManifestServer))
	}
	
	private func _iTunesLink(with url: String) -> String {
		return "itms-services://?action=download-manifest&url=\(url)"
	}

	var displayImageSmallEndpoint: URL {
		var comps = URLComponents()
		comps.scheme = "https"
		comps.host = sni()
		comps.path = "/app57x57.png"
		comps.port = port
		return comps.url!
	}

	var displayImageLargeEndpoint: URL {
		var comps = URLComponents()
		comps.scheme = "https"
		comps.host = sni()
		comps.path = "/app512x512.png"
		comps.port = port
		return comps.url!
	}
	
	var displayImageSmallData: Data {
		_createIcon(57)
	}
	
	var displayImageLargeData: Data {
		_createIcon(512)
	}
	
	private func _createIcon(_ r: CGFloat) -> Data {
		let renderer = UIGraphicsImageRenderer(size: .init(width: r, height: r))
		let image = renderer.image { ctx in
			UIColor.tintColor.setFill()
			ctx.fill(.init(x: 0, y: 0, width: r, height: r))
		}
		return image.pngData()!
	}

	var html: String {
		"""
		<html style="background-color: black;">
		<script type="text/javascript">window.location="\(iTunesLinkExternal)"</script>
		</html>
		"""
	}

	var installManifest: [String: Any] {[
		"items": [[
			"assets": [
				[
					"kind": "software-package",
					"url": payloadEndpoint.absoluteString,
				],
				[
					"kind": "display-image",
					"url": displayImageSmallEndpoint.absoluteString,
				],
				[
					"kind": "full-size-image",
					"url": displayImageLargeEndpoint.absoluteString,
				],
			],
			"metadata": [
				"bundle-identifier": app.identifier,
				"bundle-version": app.version,
				"kind": "software",
				"title": app.name,
			],
		],],
	]}

	var installManifestData: Data {
		(try? PropertyListSerialization.data(
			fromPropertyList: installManifest,
			format: .xml,
			options: .zero
		)) ?? .init()
	}
}

// MARK: - Manifest server (XSign)
extension ServerInstaller {
	/// UserDefaults key for the custom manifest server URL set in Server settings.
	static let manifestServerKey = "XSign.manifestServer"
	/// XSign Cloudflare Worker (see /worker in the repository).
	static let defaultManifestServer = "https://xsign.nikvix.workers.dev"
	/// Last-resort fallback, same /genPlist parameters, no /health endpoint.
	static let legacyManifestServer = "https://api.palera.in"
	
	private static let _unreserved = CharacterSet(
		charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
	)
	
	private static func _percentEncode(_ value: String) -> String {
		value.addingPercentEncoding(withAllowedCharacters: _unreserved) ?? value
	}
	
	/// Returns a trimmed `https://host[/path]` without trailing slash, or nil if invalid.
	static func normalizedManifestServer(_ raw: String) -> String? {
		var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		while value.hasSuffix("/") { value.removeLast() }
		guard
			!value.isEmpty,
			let url = URL(string: value),
			url.scheme?.lowercased() == "https",
			let host = url.host, !host.isEmpty,
			url.query == nil
		else { return nil }
		return value
	}
	
	/// Custom server (if valid), then the XSign worker, then api.palera.in.
	static var manifestServerCandidates: [String] {
		var list: [String] = []
		if let custom = normalizedManifestServer(UserDefaults.standard.string(forKey: manifestServerKey) ?? "") {
			list.append(custom)
		}
		for server in [defaultManifestServer, legacyManifestServer] where !list.contains(server) {
			list.append(server)
		}
		return list
	}
	
	/// `GET <base>/health` must answer `ok` within the timeout.
	static func isManifestServerHealthy(_ base: String, timeout: TimeInterval = 3) async -> Bool {
		guard let url = URL(string: base + "/health") else { return false }
		var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
		request.httpMethod = "GET"
		do {
			let (data, response) = try await URLSession.shared.data(for: request)
			guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
			return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) == "ok"
		} catch {
			return false
		}
	}
}
