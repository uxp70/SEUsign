//
//  AppStyle.swift
//  Feather
//

import SwiftUI
import UIKit

// MARK: - Presets
enum AppStyle: String, CaseIterable, Identifiable {
	case seal, midnight, paper, forest, rose, mono

	var id: String { rawValue }

	var title: String {
		switch self {
		case .seal: return .localized("Seal")
		case .midnight: return .localized("Midnight")
		case .paper: return .localized("Paper")
		case .forest: return .localized("Forest")
		case .rose: return .localized("Rose")
		case .mono: return .localized("Mono")
		}
	}

	var tintHex: String {
		switch self {
		case .seal: return "#C8873A"
		case .midnight: return "#3D6BD6"
		case .paper: return "#8A6A3B"
		case .forest: return "#2F7A5B"
		case .rose: return "#B4566F"
		case .mono: return "#6E7681"
		}
	}

	var interfaceStyle: UIUserInterfaceStyle {
		switch self {
		case .midnight: return .dark
		case .paper: return .light
		default: return .unspecified
		}
	}

	var symbol: String {
		switch self {
		case .seal: return "seal.fill"
		case .midnight: return "moon.stars.fill"
		case .paper: return "doc.plaintext.fill"
		case .forest: return "leaf.fill"
		case .rose: return "camera.filters"
		case .mono: return "circle.lefthalf.filled"
		}
	}

	/// Writes this preset into the settings the rest of the app already reads.
	func apply() {
		UserDefaults.standard.set(rawValue, forKey: AppStyleStore.styleKey)
		UserDefaults.standard.set(tintHex, forKey: AppStyleStore.tintKey)
		UserDefaults.standard.set(interfaceStyle.rawValue, forKey: AppStyleStore.interfaceStyleKey)

		guard let window = UIApplication.topViewController()?.view.window else { return }
		window.tintColor = UIColor(Color(hex: tintHex))
		window.overrideUserInterfaceStyle = interfaceStyle
	}
}

// MARK: - Layout options
enum AppDensity: Int, CaseIterable, Identifiable {
	case comfortable = 0, compact = 1

	var id: Int { rawValue }

	var title: String {
		switch self {
		case .comfortable: return .localized("Comfortable")
		case .compact: return .localized("Compact")
		}
	}

	var detail: String {
		switch self {
		case .comfortable: return .localized("Roomy cards with larger artwork and spacing.")
		case .compact: return .localized("Tighter cards so more fits on screen at once.")
		}
	}
}

enum AppCardShape: Int, CaseIterable, Identifiable {
	case rounded = 0, squircle = 1

	var id: Int { rawValue }

	var title: String {
		switch self {
		case .rounded: return .localized("Rounded")
		case .squircle: return .localized("Squircle")
		}
	}
}

enum AppBackdropStyle: Int, CaseIterable, Identifiable {
	case system = 0, gradient = 1, solid = 2

	var id: Int { rawValue }

	var title: String {
		switch self {
		case .system: return .localized("Default")
		case .gradient: return .localized("Gradient")
		case .solid: return .localized("Tinted")
		}
	}
}

// MARK: - Store
enum AppStyleStore {
	static let styleKey = "SEUsign.appStyle"
	static let tintKey = "SEUsign.userTintColor"
	static let interfaceStyleKey = "SEUsign.userInterfaceStyle"
	static let densityKey = "SEUsign.appDensity"
	static let cardShapeKey = "SEUsign.cardShape"
	static let backdropKey = "SEUsign.backdropStyle"

	static var style: AppStyle {
		AppStyle(rawValue: UserDefaults.standard.string(forKey: styleKey) ?? "") ?? .seal
	}

	static var tintHex: String {
		UserDefaults.standard.string(forKey: tintKey) ?? AppStyle.seal.tintHex
	}

	static var density: AppDensity {
		AppDensity(rawValue: UserDefaults.standard.integer(forKey: densityKey)) ?? .comfortable
	}

	static var cardShape: AppCardShape {
		AppCardShape(rawValue: UserDefaults.standard.integer(forKey: cardShapeKey)) ?? .rounded
	}

	static var backdrop: AppBackdropStyle {
		AppBackdropStyle(rawValue: UserDefaults.standard.integer(forKey: backdropKey)) ?? .system
	}

	static func cardCornerRadius() -> CGFloat {
		let base: CGFloat = {
			if #available(iOS 26.0, *) {
				return 28
			}
			return 10.5
		}()
		return cardShape == .squircle ? base + 10 : base
	}

	static var cardPadding: CGFloat {
		density == .compact ? 10 : 16
	}

	static var cellHeight: CGFloat {
		density == .compact ? 66 : 80
	}

	/// Metrics shared by the Library and Sources rows, so the layout settings
	/// shape every list in the app and not just the certificate cards.
	struct RowMetrics {
		let padding: CGFloat
		let spacing: CGFloat
		let iconSize: CGFloat
		let cornerRadius: CGFloat
		let rowInset: CGFloat
	}

	static func rowMetrics(density: Int, cardShape: Int) -> RowMetrics {
		let isCompact = AppDensity(rawValue: density) == .compact
		let isSquircle = AppCardShape(rawValue: cardShape) == .squircle

		return RowMetrics(
			padding: isCompact ? 6 : 16,
			spacing: isCompact ? 10 : 20,
			iconSize: isCompact ? 40 : 62,
			cornerRadius: isSquircle ? (isCompact ? 20 : 34) : (isCompact ? 10 : 20),
			rowInset: isCompact ? 3 : 7
		)
	}
}

// MARK: - Row chrome
extension View {
	/// The card surface the Library and Sources lists draw every row on.
	func appStyleCard(
		_ metrics: AppStyleStore.RowMetrics,
		highlighted: Bool = false
	) -> some View {
		self
			.padding(metrics.padding)
			.background(
				RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
					.fill(highlighted ? Color.accentColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
					.shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
			)
	}

	/// Lets the padded card fill its list row, so the density and card shape
	/// settings change the real lists and not just the settings preview.
	func appStyleRow(_ metrics: AppStyleStore.RowMetrics) -> some View {
		self
			.listRowInsets(
				EdgeInsets(
					top: metrics.rowInset,
					leading: 12,
					bottom: metrics.rowInset,
					trailing: 12
				)
			)
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
	}
}

// MARK: - Backdrop
struct AppBackdropView: View {
	@AppStorage(AppStyleStore.backdropKey) private var _style: Int = AppBackdropStyle.system.rawValue
	@AppStorage(AppStyleStore.tintKey) private var _tintHex: String = AppStyle.seal.tintHex

	var body: some View {
		ZStack {
			switch AppBackdropStyle(rawValue: _style) ?? .system {
			case .system:
				Color.clear
			case .gradient:
				LinearGradient(
					colors: [
						Color(hex: _tintHex).opacity(0.20),
						Color(hex: _tintHex).opacity(0.04),
						Color.clear
					],
					startPoint: .topLeading,
					endPoint: .bottomTrailing
				)
			case .solid:
				Color(hex: _tintHex).opacity(0.07)
			}
		}
		.ignoresSafeArea()
	}
}
