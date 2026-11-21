//
//  CertificatesAddView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import UIKit
import NimbleViews
import UniformTypeIdentifiers

// MARK: - View
struct CertificatesAddView: View {
	@Environment(\.dismiss) private var dismiss
	
	@State private var _p12URL: URL? = nil
	@State private var _provisionURL: URL? = nil
	@State private var _p12Password: String = ""
	@State private var _certificateName: String = ""
	
	@State private var _isImportingP12Presenting = false
	@State private var _isImportingMobileProvisionPresenting = false
	@State private var _isAutoPresenting = false
	@State private var _isCracking = false
	
	var saveButtonDisabled: Bool {
		_p12URL == nil || _provisionURL == nil
	}
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("New Certificate"), displayMode: .inline) {
			Form {
				NBSection(.localized("Files")) {
					_importButton(.localized("Import Certificate File"), file: _p12URL) {
						_isImportingP12Presenting = true
					}
					_importButton(.localized("Import Provisioning File"), file: _provisionURL) {
						_isImportingMobileProvisionPresenting = true
					}
				}
				NBSection(.localized("Automatic")) {
					Button {
						_isAutoPresenting = true
					} label: {
						Label(.localized("Fetch from sideloading.net"), systemImage: "sparkles")
					}
				} footer: {
					Text(.localized("Downloads a ready to use certificate, its provisioning profile and password from sideloading.net, then adds it to the app."))
				}
				
				NBSection(.localized("Password")) {
					SecureField(.localized("Enter Password"), text: $_p12Password)
					Button {
						_crackPassword()
					} label: {
						HStack {
							Label(.localized("Try Common Passwords"), systemImage: "key.fill")
							Spacer()
							if _isCracking {
								ProgressView()
							}
						}
					}
					.disabled(_p12URL == nil || _isCracking)
				} footer: {
					Text(.localized("Enter the password associated with the private key. Leave it blank if theres no password required."))
					Text(.localized("Try Common Passwords asks sideloading.net to run a wordlist against the selected certificate file."))
				}
				
				Section {
					TextField(.localized("Nickname (Optional)"), text: $_certificateName)
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
				
				NBToolbarButton(
					.localized("Save"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: saveButtonDisabled
				) {
					_saveCertificate()
				}
			}
			.sheet(isPresented: $_isImportingP12Presenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.p12],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._p12URL = selectedFileURL
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isImportingMobileProvisionPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.mobileProvision],
					onDocumentsPicked: { urls in
						guard let selectedFileURL = urls.first else { return }
						self._provisionURL = selectedFileURL
					}
				)
				.ignoresSafeArea()
			}
			.sheet(isPresented: $_isAutoPresenting) {
				CertificatesAutoView()
			}
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name("SEUsign.certificateImported"))) { _ in
				dismiss()
			}
		}
	}
}

// MARK: - Extension: View
extension CertificatesAddView {
	@ViewBuilder
	private func _importButton(
		_ title: String,
		file: URL?,
		action: @escaping () -> Void
	) -> some View {
		Button(title) {
			action()
		}
		.foregroundColor(file == nil ? .accentColor : .disabled())
		.disabled(file != nil)
		.animation(.easeInOut(duration: 0.3), value: file != nil)
	}
}

// MARK: - Extension: View (import)
extension CertificatesAddView {
	private func _crackPassword() {
		guard let p12URL = _p12URL else { return }
		_isCracking = true
		
		Task {
			do {
				let password = try await SideloadingCertsService.shared.crackPassword(for: p12URL)
				await MainActor.run {
					_isCracking = false
					_p12Password = password
					UINotificationFeedbackGenerator().notificationOccurred(.success)
					UIAlertController.showAlertWithOk(
						title: .localized("Password Found"),
						message: password
					)
				}
			} catch {
				await MainActor.run {
					_isCracking = false
					UINotificationFeedbackGenerator().notificationOccurred(.error)
					UIAlertController.showAlertWithOk(
						title: .localized("No Password Found"),
						message: error.localizedDescription
					)
				}
			}
		}
	}
	
	private func _saveCertificate() {
		guard
			let p12URL = _p12URL,
			let provisionURL = _provisionURL,
			FR.checkPasswordForCertificate(for: p12URL, with: _p12Password, using: provisionURL)
		else {
			UIAlertController.showAlertWithOk(
				title: .localized("Bad Password"),
				message: .localized("Please check the password and try again.")
			)
			return
		}
		
		FR.handleCertificateFiles(
			p12URL: p12URL,
			provisionURL: provisionURL,
			p12Password: _p12Password,
			certificateName: _certificateName
		) { _ in
			dismiss()
		}
	}
}
