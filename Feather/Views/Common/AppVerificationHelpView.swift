//
//  AppVerificationHelpView.swift
//  Feather
//
//  Explains iOS's “Unable to Verify App” dialog and the steps that clear it.
//

import Foundation
import SwiftUI
import UIKit
import NimbleExtensions
import NimbleViews

// MARK: - View
struct AppVerificationHelpView: View {
	@Environment(\.dismiss) private var dismiss

	var certificate: CertificatePair? = nil

	@State private var _isChecking = false
	@State private var _serverResults: [ServerResult] = []

	struct ServerResult: Identifiable {
		let id = UUID()
		let host: String
		let reachable: Bool
	}

	private var _certificateNote: (title: String, detail: String, color: Color, symbol: String)? {
		guard let certificate else { return nil }

		if certificate.revoked {
			return (
				String.localized("This certificate is revoked"),
				String.localized("Apple revoked the certificate that signed this app, and iOS will not launch it. Import a working certificate and sign the app again."),
				.red,
				"xmark.seal.fill"
			)
		}

		if let expiration = certificate.expiration, expiration <= Date() {
			return (
				String.localized("This certificate has expired"),
				String.localized("iOS will not launch apps signed with an expired certificate. Import a working certificate and sign the app again."),
				.orange,
				"xmark.seal.fill"
			)
		}

		return (
			String.localized("This certificate is still valid"),
			String.localized("If the app still will not open, iOS is waiting for you to trust the developer while the device is online."),
			.green,
			"checkmark.seal.fill"
		)
	}

	// MARK: Body
	var body: some View {
		NBNavigationView(String.localized("Unable to Verify App"), displayMode: .inline) {
			List {
				Section {
					HStack(alignment: .top, spacing: 14) {
						Image(systemName: "exclamationmark.shield.fill")
							.font(.title2)
							.foregroundColor(.orange)

						Text(String.localized("iOS only opens an app from outside the App Store once it can verify the certificate that signed it. When that check fails it shows “Unable to Verify App” and refuses to launch the app."))
							.font(.subheadline)
					}
					.padding(.vertical, 4)
				}

				if let note = _certificateNote {
					Section {
						VStack(alignment: .leading, spacing: 5) {
							Label(note.title, systemImage: note.symbol)
								.font(.subheadline.weight(.semibold))
								.foregroundColor(note.color)

							Text(note.detail)
								.font(.footnote)
								.foregroundColor(.secondary)
						}
						.padding(.vertical, 2)
					} header: {
						Text(String.localized("Certificate"))
					}
				}

				Section {
					_step(
						"1",
						title: String.localized("Connect to the internet"),
						detail: String.localized("The check has to reach Apple. Turn off any VPN, DNS blocker or firewall that could block ocsp.apple.com or ppq.apple.com, then open the app again.")
					)
					_step(
						"2",
						title: String.localized("Trust the developer"),
						detail: String.localized("Open Settings → General → VPN & Device Management, tap the developer name shown in the dialog, then tap Trust. On iOS 18 and later the button is called Allow & Restart.")
					)
					_step(
						"3",
						title: String.localized("Reinstall if the developer is missing"),
						detail: String.localized("If the developer does not appear in that list, delete the app, install it again, open it once and tap Cancel, then repeat the step above.")
					)
					_step(
						"4",
						title: String.localized("Sign again with a working certificate"),
						detail: String.localized("A revoked or expired certificate can never be trusted again. Import a working certificate and sign the app once more.")
					)
				} header: {
					Text(String.localized("Steps"))
				} footer: {
					Text(String.localized("Apple verifies the developer of every app installed outside the App Store, so this dialog is expected the first time an app signed with a new certificate is opened."))
				}

				Section {
					Button {
						_checkAppleServers()
					} label: {
						HStack {
							Label(String.localized("Check Apple's verification servers"), systemImage: "network")
							Spacer()
							if _isChecking {
								ProgressView()
							}
						}
					}
					.disabled(_isChecking)

					ForEach(_serverResults) { result in
						HStack {
							Text(result.host)
								.font(.footnote.monospaced())
							Spacer()
							Label(
								result.reachable
									? String.localized("Reachable")
									: String.localized("Blocked"),
								systemImage: result.reachable
									? "checkmark.circle.fill"
									: "xmark.circle.fill"
							)
							.font(.caption)
							.foregroundColor(result.reachable ? .green : .red)
						}
					}
				} header: {
					Text(String.localized("Connection"))
				} footer: {
					Text(String.localized("Enterprise certificates check ocsp.apple.com, and development or ad hoc certificates check ppq.apple.com. A block here also stops iOS from verifying the app."))
				}

				Section {
					Button {
						_openDeviceManagement()
					} label: {
						Label(String.localized("Open VPN & Device Management"), systemImage: "gearshape")
					}
				} footer: {
					Text(String.localized("SEUsign cannot bypass this check. Only iOS can mark a developer as trusted, and only you can confirm it on the device."))
				}
			}
			.listStyle(.insetGrouped)
			.toolbar {
				NBToolbarButton(role: .dismiss)
			}
		}
	}
}

// MARK: - Extension: View
extension AppVerificationHelpView {
	@ViewBuilder
	private func _step(_ number: String, title: String, detail: String) -> some View {
		HStack(alignment: .top, spacing: 12) {
			Text(number)
				.font(.caption.weight(.bold))
				.foregroundColor(.white)
				.frame(width: 22, height: 22)
				.background(Circle().fill(Color.accentColor))

			VStack(alignment: .leading, spacing: 3) {
				Text(title)
					.font(.subheadline.weight(.semibold))
				Text(detail)
					.font(.footnote)
					.foregroundColor(.secondary)
			}
		}
		.padding(.vertical, 2)
	}
}

// MARK: - Extension: Actions
extension AppVerificationHelpView {
	private func _checkAppleServers() {
		guard !_isChecking else { return }

		_isChecking = true
		_serverResults = []

		Task {
			var results: [ServerResult] = []

			for host in ["ocsp.apple.com", "ppq.apple.com"] {
				let reachable = await Self._isReachable(host)
				results.append(ServerResult(host: host, reachable: reachable))
			}

			await MainActor.run {
				_serverResults = results
				_isChecking = false
			}
		}
	}

	private static func _isReachable(_ host: String) async -> Bool {
		guard let url = URL(string: "https://\(host)/") else { return false }

		var request = URLRequest(url: url)
		request.httpMethod = "HEAD"
		request.timeoutInterval = 8
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

		do {
			_ = try await URLSession.shared.data(for: request)
			return true
		} catch {
			return false
		}
	}

	private func _openDeviceManagement() {
		let fallback = URL(string: UIApplication.openSettingsURLString)

		guard let target = URL(string: "App-Prefs:root=General&path=ManagedConfigurationList") else {
			if let fallback {
				UIApplication.shared.open(fallback)
			}
			return
		}

		UIApplication.shared.open(target, options: [:]) { opened in
			guard !opened, let fallback else { return }
			UIApplication.shared.open(fallback)
		}
	}
}
