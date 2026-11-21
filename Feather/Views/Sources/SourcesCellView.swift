//
//  SourcesCellView.swift
//  Feather
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import NukeUI

// MARK: - View
struct SourcesCellView: View {
	@AppStorage(AppStyleStore.densityKey) private var _styleDensity: Int = AppDensity.comfortable.rawValue
	@AppStorage(AppStyleStore.cardShapeKey) private var _styleCardShape: Int = AppCardShape.rounded.rawValue

	var source: AltSource

	private var _metrics: AppStyleStore.RowMetrics {
		AppStyleStore.rowMetrics(density: _styleDensity, cardShape: _styleCardShape)
	}

	// MARK: Body
	var body: some View {
		let metrics = _metrics

		FRIconCellView(
			title: source.name ?? .localized("Unknown"),
			subtitle: source.sourceURL?.absoluteString ?? "",
			iconUrl: source.iconURL,
			size: metrics.iconSize,
			spacing: metrics.spacing
		)
		.appStyleCard(metrics)
		.swipeActions {
			_actions(for: source)
			_contextActions(for: source)
		}
		.contextMenu {
			_contextActions(for: source)
			Divider()
			_actions(for: source)
		}
	}
}

// MARK: - Extension: View
extension SourcesCellView {
	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
	}

	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Copy"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
		}
	}
}
