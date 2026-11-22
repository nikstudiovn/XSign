//
//  AppIconView.swift
//  Feather
//
//  Created by samara on 19.06.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View extension: Model
extension AppIconView {
	struct AltIcon: Identifiable {
		var displayName: String
		var author: String
		var key: String?
		var image: UIImage
		var id: String { key ?? displayName }
		
		init(displayName: String, author: String, key: String? = nil) {
			self.displayName = displayName
			self.author = author
			self.key = key
			self.image = altImage(key)
		}
	}
	
	static func altImage(_ name: String?) -> UIImage {
		let path = Bundle.main.bundleURL.appendingPathComponent((name ?? "AppIcon60x60") + "@2x.png")
		return UIImage(contentsOfFile: path.path) ?? UIImage()
	}
}

// MARK: - View
struct AppIconView: View {
	@Binding var currentIcon: String?
	@State private var _selectedIcon: String? = UIApplication.shared.alternateIconName
	
	// dont translate
	var sections: [String: [AltIcon]] = [
		"Main": [
			AltIcon(displayName: "XSign", author: "Samara", key: nil),
			AltIcon(displayName: "XSign Tím", author: "Samara", key: "V2Mac"),
			AltIcon(displayName: "XSign Xanh", author: "Samara", key: "V1"),
			AltIcon(displayName: "XSign Bạc",author: "Samara", key: "V1Mac"),
			AltIcon(displayName: "XSign Ngọc", author: "Samara", key: "V0"),
			AltIcon(displayName: "XSign Đen", author: "Samara", key: "Donor")
		],
		"Wingio": [
			AltIcon(displayName: "XSign Ruby", author: "Wingio", key: "Wing"),
		]
	]
	
	// MARK: Body
	var body: some View {
		NBList(.localized("App Icon")) {
			ForEach(sections.keys.sorted(), id: \.self) { section in
				if let icons = sections[section] {
					NBSection(section) {
						ForEach(icons) { icon in
							_icon(icon: icon)
						}
					}
				}
			}
		}
		.onAppear {
			let active = UIApplication.shared.alternateIconName
			_selectedIcon = active
			currentIcon = active
		}
	}
}

// MARK: - View extension
extension AppIconView {
	@ViewBuilder
	private func _icon(
		icon: AppIconView.AltIcon
	) -> some View {
		Button {
			guard UIApplication.shared.supportsAlternateIcons else { return }
			guard _selectedIcon != icon.key else { return }
			let previous = _selectedIcon
			// Move the checkmark immediately on the main thread
			_selectedIcon = icon.key
			currentIcon = icon.key
			UIApplication.shared.setAlternateIconName(icon.key) { error in
				// The completion handler is not guaranteed to run on the main thread
				DispatchQueue.main.async {
					let resolved = (error == nil) ? icon.key : previous
					_selectedIcon = resolved
					currentIcon = resolved
				}
			}
		} label: {
			HStack(spacing: 18) {
				Image(uiImage: icon.image)
					.appIconStyle()
				
				NBTitleWithSubtitleView(
					title: icon.displayName,
					subtitle: icon.author,
					linelimit: 0
				)
				
				if _selectedIcon == icon.key {
					Image(systemName: "checkmark").bold()
				}
			}
		}
	}
}
