//
//  AppearanceView.swift
//  Feather
//
//  Created by samara on 7.05.2025.
//

import SwiftUI
import NimbleViews
import UIKit

// MARK: - View
// dear god help me
struct AppearanceView: View {
	@AppStorage(AppStyleStore.interfaceStyleKey)
	private var _userIntefacerStyle: Int = UIUserInterfaceStyle.unspecified.rawValue

	@AppStorage(AppStyleStore.styleKey)
	private var _appStyle: String = AppStyle.seal.rawValue

	@AppStorage(AppStyleStore.densityKey)
	private var _density: Int = AppDensity.comfortable.rawValue

	@AppStorage(AppStyleStore.cardShapeKey)
	private var _cardShape: Int = AppCardShape.rounded.rawValue

	@AppStorage(AppStyleStore.backdropKey)
	private var _backdrop: Int = AppBackdropStyle.system.rawValue

	@AppStorage("SEUsign.shouldTintIcons")
	private var _shouldTintIcons: Bool = false

	@AppStorage("SEUsign.shouldChangeIconsBasedOffStyle")
	private var _shouldChangeIconsBasedOffStyle: Bool = false

	@AppStorage("SEUsign.storeCellAppearance")
	private var _storeCellAppearance: Int = 0
	private let _storeCellAppearanceMethods: [(name: String, desc: String)] = [
		(.localized("Standard"), .localized("Default style for the app, only includes subtitle.")),
		(.localized("Big Description"), .localized("Adds the localized description of the app."))
	]

	@AppStorage(AppStyleStore.tintKey)
	private var _selectedColorHex: String = "#C8873A"

	private var _tintColorBinding: Binding<Color> {
		Binding(
			get: { Color(hex: _selectedColorHex) },
			set: { _selectedColorHex = $0.toHex() }
		)
	}

	// MARK: Body
	var body: some View {
		NBList(.localized("Appearance")) {
			Section {
				Picker(.localized("Appearance"), selection: $_userIntefacerStyle) {
					ForEach(UIUserInterfaceStyle.allCases.sorted(by: { $0.rawValue < $1.rawValue }), id: \.rawValue) { style in
						Text(style.label).tag(style.rawValue)
					}
				}
				.pickerStyle(.segmented)
			}

			NBSection(.localized("Styles"), systemName: "paintpalette") {
				_stylePresets
					.listRowInsets(EdgeInsets())
					.listRowBackground(EmptyView())
			} footer: {
				Text(.localized("Styles set the accent colour, the light or dark appearance, and the shape of the cards used throughout the app."))
			}

			NBSection(.localized("Theme")) {
				AppearanceTintColorView()
					.listRowInsets(EdgeInsets())
					.listRowBackground(EmptyView())
			}

			Section {
				ColorPicker(
					.localized("Custom Theme Color"),
					selection: _tintColorBinding,
					supportsOpacity: false
				)
			}

			NBSection(.localized("Layout")) {
				Picker(.localized("Density"), selection: $_density) {
					ForEach(AppDensity.allCases) { density in
						NBTitleWithSubtitleView(
							title: density.title,
							subtitle: density.detail
						)
						.tag(density.rawValue)
					}
				}
				.labelsHidden()
				.pickerStyle(.inline)

				Picker(.localized("Card Shape"), selection: $_cardShape) {
					ForEach(AppCardShape.allCases) { shape in
						Text(shape.title).tag(shape.rawValue)
					}
				}
				.pickerStyle(.segmented)

				Picker(.localized("Background"), selection: $_backdrop) {
					ForEach(AppBackdropStyle.allCases) { backdrop in
						Text(backdrop.title).tag(backdrop.rawValue)
					}
				}
				.pickerStyle(.segmented)

				_preview
			} footer: {
				Text(.localized("Density changes how much content fits on screen, and the background tints the space behind the app."))
			}

			if #available(iOS 18.0, *) {
				NBSection(.localized("Library")) {
					Toggle(.localized("Dynamic Icons"), isOn: $_shouldChangeIconsBasedOffStyle)
					if #available(iOS 18.2, *) {
						Toggle(.localized("Tinted Icons"), isOn: $_shouldTintIcons)
					}
				}
			}

			NBSection(.localized("Sources")) {
				Picker(.localized("Store Cell Appearance"), selection: $_storeCellAppearance) {
					ForEach(0..<_storeCellAppearanceMethods.count, id: \.self) { index in
						let method = _storeCellAppearanceMethods[index]
						NBTitleWithSubtitleView(
							title: method.name,
							subtitle: method.desc
						)
						.tag(index)
					}

				}
				.labelsHidden()
				.pickerStyle(.inline)
			}
		}
		.onChange(of: _userIntefacerStyle) { value in
			if let style = UIUserInterfaceStyle(rawValue: value) {
				UIApplication.topViewController()?.view.window?.overrideUserInterfaceStyle = style
			}
		}
		.onChange(of: _selectedColorHex) { value in
			UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: value))
		}
	}
}

// MARK: - Extension: View
extension AppearanceView {
	private var _stylePresets: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				ForEach(AppStyle.allCases) { style in
					let isSelected = _appStyle == style.rawValue

					VStack(spacing: 8) {
						ZStack {
							RoundedRectangle(cornerRadius: 14, style: .continuous)
								.fill(Color(hex: style.tintHex).opacity(0.18))
								.frame(width: 54, height: 54)
							Image(systemName: style.symbol)
								.font(.title3)
								.foregroundColor(Color(hex: style.tintHex))
						}

						Text(style.title)
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
					.frame(width: 96, height: 104)
					.background(Color(uiColor: .secondarySystemGroupedBackground))
					.clipShape(
						RoundedRectangle(cornerRadius: AppStyleStore.cardCornerRadius(), style: .continuous)
					)
					.overlay(
						RoundedRectangle(cornerRadius: AppStyleStore.cardCornerRadius(), style: .continuous)
							.strokeBorder(isSelected ? Color(hex: style.tintHex) : .clear, lineWidth: 2)
					)
					.onTapGesture {
						_appStyle = style.rawValue
						_selectedColorHex = style.tintHex
						_userIntefacerStyle = style.interfaceStyle.rawValue
						style.apply()
					}
					.accessibilityLabel(Text(style.title))
				}
			}
			.padding(.vertical, 4)
		}
		.onChange(of: _selectedColorHex) { value in
			UIApplication.topViewController()?.view.window?.tintColor = UIColor(Color(hex: value))
		}
	}

	/// A real Library row, so the layout pickers above change a row exactly
	/// the way they change the Library and Sources lists.
	private var _preview: some View {
		let metrics = AppStyleStore.rowMetrics(density: _density, cardShape: _cardShape)

		return HStack(spacing: metrics.spacing) {
			RoundedRectangle(cornerRadius: metrics.iconSize * 0.24, style: .continuous)
				.fill(Color(hex: _selectedColorHex).opacity(0.20))
				.frame(width: metrics.iconSize, height: metrics.iconSize)
				.overlay(
					Image(systemName: "app.fill")
						.font(.system(size: metrics.iconSize * 0.44))
						.foregroundColor(Color(hex: _selectedColorHex))
				)

			VStack(alignment: .leading, spacing: 2) {
				Text(.localized("Sample App"))
					.font(.subheadline.weight(.semibold))
				Text(.localized("1.0 • com.example.app"))
					.font(.caption)
					.foregroundColor(.secondary)
			}

			Spacer(minLength: 6)

			Text(.localized("Install"))
				.font(.caption2.weight(.semibold))
				.padding(.horizontal, 8)
				.padding(.vertical, 4)
				.background(Color(hex: _selectedColorHex).opacity(0.16))
				.clipShape(Capsule())
		}
		.padding(metrics.padding)
		.background(
			RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
				.fill(Color(uiColor: .secondarySystemBackground))
				.shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
		)
		.listRowInsets(EdgeInsets())
		.listRowBackground(EmptyView())
		.animation(.easeInOut(duration: 0.2), value: metrics.padding)
		.animation(.easeInOut(duration: 0.2), value: metrics.cornerRadius)
	}
}
