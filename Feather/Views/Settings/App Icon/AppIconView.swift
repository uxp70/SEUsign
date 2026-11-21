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
	
	// dont translate
	var sections: [String: [AltIcon]] = [
		"Main": [
			AltIcon(displayName: "Sigil", author: "Sigil", key: nil),
			AltIcon(displayName: "Sigil Mono", author: "Sigil", key: "V2Mac"),
			AltIcon(displayName: "Sigil Deep Sea", author: "Sigil", key: "V1"),
			AltIcon(displayName: "Sigil Slate", author: "Sigil", key: "V1Mac"),
			AltIcon(displayName: "Sigil Paper", author: "Sigil", key: "V0"),
			AltIcon(displayName: "Sigil Ember", author: "Sigil", key: "Donor")
		],
		"Alternates": [
			AltIcon(displayName: "Sigil Mint", author: "Sigil", key: "Wing"),
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
			currentIcon = UIApplication.shared.alternateIconName
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
			UIApplication.shared.setAlternateIconName(icon.key) { _ in
				currentIcon = UIApplication.shared.alternateIconName
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
				
				if currentIcon == icon.key {
					Image(systemName: "checkmark").bold()
				}
			}
		}
	}
}
