//
//  CertificatesAutoView.swift
//  Feather
//
//  Browse and import certificates published by sideloading.net.
//

import SwiftUI
import UIKit
import NimbleViews

// MARK: - View
struct CertificatesAutoView: View {
	@Environment(\.dismiss) private var dismiss
	@StateObject private var _service = SideloadingCertsService()

	@State private var _showAll = false
	@State private var _searchText = ""
	@State private var _importingID: Int?

	private var _certificates: [SideloadingCertificate] {
		let source = _showAll ? _service.certificates : _service.validCertificates
		guard !_searchText.isEmpty else { return source }
		return source.filter {
			$0.displayName.localizedCaseInsensitiveContains(_searchText)
				|| $0.name.localizedCaseInsensitiveContains(_searchText)
		}
	}

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Automatic Certificate"), displayMode: .inline) {
			List {
				Section {
					Picker(.localized("Show"), selection: $_showAll) {
						Text(.localized("Valid only")).tag(false)
						Text(.localized("All")).tag(true)
					}
					.pickerStyle(.segmented)
				} footer: {
					Text(.localized("Certificates are published by sideloading.net. Importing downloads the certificate, its provisioning profile and password, then adds it here."))
				}

				if _service.isLoading && _service.certificates.isEmpty {
					Section {
						HStack {
							Spacer()
							ProgressView()
							Spacer()
						}
					}
				} else if let error = _service.errorMessage, _service.certificates.isEmpty {
					Section {
						Text(error)
							.font(.footnote)
							.foregroundColor(.secondary)
						Button(.localized("Try Again")) {
							Task { await _service.load() }
						}
					}
				} else if _certificates.isEmpty {
					Section {
						Text(.localized("No certificates are available right now."))
							.font(.footnote)
							.foregroundColor(.secondary)
					}
				} else {
					Section {
						ForEach(_certificates) { cert in
							_row(for: cert)
						}
					} header: {
						Text(verbatim: "\(_certificates.count) " + String.localized("available"))
					}
				}
			}
			.listStyle(.insetGrouped)
			.searchable(text: $_searchText, placement: .platform())
			.refreshable {
				await _service.load()
			}
			.task {
				if _service.certificates.isEmpty {
					await _service.load()
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)

				if let best = _service.bestCertificate {
					NBToolbarButton(
						.localized("Best"),
						style: .text,
						placement: .confirmationAction,
						isDisabled: _importingID != nil
					) {
						_import(best)
					}
				}
			}
		}
	}
}

// MARK: - Extension: View
extension CertificatesAutoView {
	@ViewBuilder
	private func _row(for cert: SideloadingCertificate) -> some View {
		HStack(spacing: 12) {
			Image(systemName: cert.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
				.font(.title3)
				.foregroundColor(cert.isValid ? .green : .red)

			VStack(alignment: .leading, spacing: 3) {
				Text(cert.displayName)
					.font(.subheadline.weight(.semibold))
					.lineLimit(2)

				HStack(spacing: 5) {
					Text(cert.status)
						.font(.caption2)
						.foregroundColor(cert.isRevoked ? .red : .secondary)

					Text(verbatim: "\u{00b7}")
						.font(.caption2)
						.foregroundColor(.secondary)

					Text(cert.expiryDescription)
						.font(.caption2)
						.foregroundColor(.secondary)
				}
			}

			Spacer(minLength: 8)

			if _importingID == cert.id {
				ProgressView()
			} else if cert.isValid {
				Button {
					_import(cert)
				} label: {
					NBButton(.localized("Use"), style: .text)
				}
				.buttonStyle(.plain)
				.disabled(_importingID != nil)
			}
		}
		.padding(.vertical, 2)
	}

	private func _import(_ cert: SideloadingCertificate) {
		guard _importingID == nil else { return }
		_importingID = cert.id

		Task {
			do {
				try await _service.importCertificate(cert)
				await MainActor.run {
					_importingID = nil
					UINotificationFeedbackGenerator().notificationOccurred(.success)
					UIAlertController.showAlertWithOk(
						title: .localized("Certificate Added"),
						message: cert.displayName
					) {
						NotificationCenter.default.post(
							name: Notification.Name("SEUsign.certificateImported"),
							object: nil
						)
						dismiss()
					}
				}
			} catch {
				await MainActor.run {
					_importingID = nil
					UINotificationFeedbackGenerator().notificationOccurred(.error)
					UIAlertController.showAlertWithOk(
						title: .localized("Could Not Import"),
						message: error.localizedDescription
					)
				}
			}
		}
	}
}
