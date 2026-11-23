//
//  OptionsManager.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import Foundation
import UIKit

// MARK: - OptionsManager
class OptionsManager: ObservableObject {
	static let shared = OptionsManager()
	
	private let _key = "signing_options"
	
	@Published var options: Options {
		didSet {
			saveOptions()
		}
	}
	
	init() {
		let defaults = Options.defaultOptions
		
		if let data = UserDefaults.standard.data(forKey: _key) {
			do {
				let savedDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
				
				let defaultData = try JSONEncoder().encode(defaults)
				var mergedDict = try JSONSerialization.jsonObject(with: defaultData) as? [String: Any] ?? [:]

				for (key, value) in savedDict {
					mergedDict[key] = value
				}
				
				let mergedData = try JSONSerialization.data(withJSONObject: mergedDict)
				self.options = try JSONDecoder().decode(Options.self, from: mergedData)
				return
			} catch {
				print("Failed to decode or merge options, falling back to defaults :/ \(error)")
			}
		}
		
		self.options = defaults
		
		if let encoded = try? JSONEncoder().encode(defaults) {
			UserDefaults.standard.set(encoded, forKey: _key)
		}
	}
	
	/// Saves options
	func saveOptions() {
		if let encoded = try? JSONEncoder().encode(options) {
			UserDefaults.standard.set(encoded, forKey: _key)
		}
	}
}

// MARK: - Options
struct Options: Codable, Equatable {
	
	// MARK: Pre Modifications
	
	/// App name
	var appName: String?
	/// App version
	var appVersion: String?
	/// App bundle identifer
	var appIdentifier: String?
	/// App entitlements
	var appEntitlementsFile: URL?
	/// App apparence (i.e. Light/Dark/Default)
	var appAppearance: AppAppearance
	/// App minimum iOS requirement (i.e. iOS 11.0)
	var minimumAppRequirement: MinimumAppRequirement
	/// Signing options
	var signingOption: SigningOption
	
	// MARK: Options
	
	/// Inject path (i.e. `@rpath`)
	var injectPath: InjectPath
	/// Inject folder (i.e. `Frameworks/`)
	var injectFolder: InjectFolder
	/// Random string appended to the app identifier
	var ppqString: String
	/// Basic protection against PPQ
	var ppqProtection: Bool
	/// (Better) protection against PPQ
	var dynamicProtection: Bool
	/// App identifiers list which matches and replaces
	var identifiers: [String: String]
	/// App name list which matches and replaces
	var displayNames: [String: String]
	/// Array of files (`.dylib`, `.deb` ) to extract and inject
	var injectionFiles: [URL]
	/// Mach-o load paths to remove (i.e. `@executable_path/demo1.dylib`)
	var disInjectionFiles: [String]
	/// App files to remove from (i.e. `Frameworks/CydiaSubstrate.framework`)
	var removeFiles: [String]
	/// If app should have filesharing forcefully enabled
	var fileSharing: Bool
	/// If app should have iTunes filesharing forcefully enabled
	var itunesFileSharing: Bool
	/// If app should have Pro Motion enabled (may not be needed)
	var proMotion: Bool
	/// If app should have Game Mode enabled
	var gameMode: Bool
	/// If app should use fullscreen (iPad mainly)
	var ipadFullscreen: Bool
	/// If app shouldn't have URL Schemes
	var removeURLScheme: Bool
	/// If app should not include a `embedded.mobileprovision` (useful for JB detection)
	var removeProvisioning: Bool
	/// Forcefully rename string files for App name
	var changeLanguageFilesForCustomDisplayName: Bool
	/// If tweaks should be injected into all app extensions (PlugIns and Extensions)
	var injectIntoExtensions: Bool
	/// If app should merge entitlements with the binary.
	var mergeEntitlements: Bool

	// MARK: Experiments
	
	/// Modifies app to support liquid glass
	var experiment_supportLiquidGlass: Bool
	/// Modifies app to disable liquid glass
	var experiment_disableLiquidGlass: Bool
	/// Modifies application to use ElleKit instead of CydiaSubstrate
	var experiment_replaceSubstrateWithEllekit: Bool
	
	// MARK: Post Modifications
	
	var post_installAppAfterSigned: Bool
	/// This will delete your imported application after signing, to save on using unneeded space.
	var post_deleteAppAfterSigned: Bool
	
	// MARK: - Defaults
	static let defaultOptions = Options(
		
		// MARK: Pre Modifications
		
		appAppearance: .default,
		minimumAppRequirement: .default,
		signingOption: .default,
		
		// MARK: Options
		
		injectPath: .executable_path,
		injectFolder: .frameworks,
		ppqString: randomString(),
		ppqProtection: false,
		dynamicProtection: false,
		identifiers: [:],
		displayNames: [:],
		injectionFiles: [],
		disInjectionFiles: [],
		removeFiles: [],
		fileSharing: false,
		itunesFileSharing: false,
		proMotion: false,
		gameMode: false,
		ipadFullscreen: false,
		removeURLScheme: false,
		removeProvisioning: false,
		changeLanguageFilesForCustomDisplayName: false,
		injectIntoExtensions: false,
		mergeEntitlements: false,
		
		// MARK: Experiments
		
		experiment_supportLiquidGlass: false,
		experiment_disableLiquidGlass: false,
		experiment_replaceSubstrateWithEllekit: false,
		
		// MARK: Post Modifications
		
		post_installAppAfterSigned: false,
		post_deleteAppAfterSigned: false
	)
	
	// MARK: duplicate values are not recommended!

	enum AppAppearance: String, Codable, CaseIterable, LocalizedDescribable {
		case `default`
		case light = "Light"
		case dark = "Dark"

		var localizedDescription: String {
			switch self {
			case .default: .localized("Default")
			case .light: .localized("Light")
			case .dark: .localized("Dark")
			}
		}
	}

	enum MinimumAppRequirement: String, Codable, CaseIterable, LocalizedDescribable {
		case `default`
		case v16 = "16.0"
		case v15 = "15.0"
		case v14 = "14.0"
		case v13 = "13.0"
		case v12 = "12.0"

		var localizedDescription: String {
			switch self {
			case .default: .localized("Default")
			case .v16: "16.0"
			case .v15: "15.0"
			case .v14: "14.0"
			case .v13: "13.0"
			case .v12: "12.0"
			}
		}
	}
	
	enum SigningOption: String, Codable, CaseIterable, LocalizedDescribable {
		case `default`
		case onlyModify
//		case adhoc

		var localizedDescription: String {
			switch self {
			case .default: .localized("Default")
			case .onlyModify: .localized("Modify")
//			case .adhoc: .localized("Ad-hoc")
			}
		}
	}
	
	enum InjectPath: String, Codable, CaseIterable, LocalizedDescribable {
		case executable_path = "@executable_path"
		case rpath = "@rpath"
	}
	
	enum InjectFolder: String, Codable, CaseIterable, LocalizedDescribable {
		case root = "/"
		case frameworks = "/Frameworks/"
	}
	
	/// Default random value for `ppqString`
	static func randomString() -> String {
		String((0..<6).compactMap { _ in UUID().uuidString.randomElement() })
	}
}

// MARK: - LocalizedDescribable

protocol LocalizedDescribable {
	var localizedDescription: String { get }
}

extension LocalizedDescribable where Self: RawRepresentable, RawValue == String {
	var localizedDescription: String {
		let localized = NSLocalizedString(self.rawValue, comment: "")
		return localized == self.rawValue ? self.rawValue : localized
	}
}

// MARK: - XSign Presets
struct XSignPreset: Codable, Identifiable, Equatable {
	let id: UUID
	var name: String
	var isBuiltIn: Bool
	var options: Options
	var localizedName: String {
		guard isBuiltIn else { return name }
		switch name {
			case "Mặc định": return xsignT("Mặc định", "Default")
			case "Clone app": return xsignT("Clone app", "Clone App")
			case "Không tweak": return xsignT("Không tweak", "No Tweaks")
			default: return name
		}
	}
	init(id: UUID = UUID(), name: String, isBuiltIn: Bool = false, options: Options) {
		self.id = id
		self.name = name
		self.isBuiltIn = isBuiltIn
		self.options = options
	}
}

@MainActor
final class XSignPresetManager: ObservableObject {
	static let shared = XSignPresetManager()

	private let customPresetsKey = "xsign.customPresets"
	private let defaultPresetIDKey = "xsign.defaultPresetID"

	@Published private(set) var customPresets: [XSignPreset] = []
	@Published var defaultPresetID: UUID?

	let builtInPresets: [XSignPreset] = {
		var cloneOptions = Options.defaultOptions
		cloneOptions.ppqProtection = true
		cloneOptions.dynamicProtection = true
		cloneOptions.removeURLScheme = true
		cloneOptions.fileSharing = true

		var noTweakOptions = Options.defaultOptions
		noTweakOptions.injectionFiles = []
		noTweakOptions.injectIntoExtensions = false
		noTweakOptions.experiment_replaceSubstrateWithEllekit = false

		return [
			XSignPreset(
				id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
				name: "Mặc định",
				isBuiltIn: true,
				options: Options.defaultOptions
			),
			XSignPreset(
				id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
				name: "Clone app",
				isBuiltIn: true,
				options: cloneOptions
			),
			XSignPreset(
				id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
				name: "Không tweak",
				isBuiltIn: true,
				options: noTweakOptions
			)
		]
	}()

	var allPresets: [XSignPreset] {
		builtInPresets + customPresets
	}

	var effectiveOptions: Options {
		if let defaultID = defaultPresetID,
		   let preset = allPresets.first(where: { $0.id == defaultID }) {
			return preset.options
		}
		return Options.defaultOptions
	}

	private init() {
		load()
	}

	private func load() {
		if let data = UserDefaults.standard.data(forKey: customPresetsKey),
		   let decoded = try? JSONDecoder().decode([XSignPreset].self, from: data) {
			customPresets = decoded
		}
		if let idString = UserDefaults.standard.string(forKey: defaultPresetIDKey),
		   let uuid = UUID(uuidString: idString) {
			defaultPresetID = uuid
		} else {
			defaultPresetID = builtInPresets.first?.id
		}
	}

	private func saveCustomPresets() {
		if let data = try? JSONEncoder().encode(customPresets) {
			UserDefaults.standard.set(data, forKey: customPresetsKey)
		}
	}

	func saveCustomPreset(name: String, options: Options) {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		let preset = XSignPreset(name: trimmed, isBuiltIn: false, options: options)
		customPresets.append(preset)
		saveCustomPresets()
	}

	func deleteCustomPreset(id: UUID) {
		customPresets.removeAll { $0.id == id }
		saveCustomPresets()
		if defaultPresetID == id {
			selectDefault(builtInPresets.first?.id)
		}
	}

	func selectDefault(_ id: UUID?) {
		defaultPresetID = id
		if let id {
			UserDefaults.standard.set(id.uuidString, forKey: defaultPresetIDKey)
		} else {
			UserDefaults.standard.removeObject(forKey: defaultPresetIDKey)
		}
	}
}

