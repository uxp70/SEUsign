//
//  SideloadingUploadWarning.swift
//  Feather
//
//  Explicit consent before a certificate file leaves the device.
//

import UIKit
import NimbleExtensions

/// Remote verification and password recovery both upload the `.p12` (which
/// contains the private key) to sideloading.net. Nothing is sent until the
/// user confirms the warning shown by `confirm(purpose:onConfirm:)`.
enum SideloadingUploadWarning {
	enum Purpose {
		case verification
		case passwordRecovery

		var actionTitle: String {
			switch self {
			case .verification:
				return String.localized("Upload and Verify")
			case .passwordRecovery:
				return String.localized("Upload and Guess")
			}
		}

		var summary: String {
			switch self {
			case .verification:
				return String.localized("The certificate file contains your private key, and the password is sent with it. sideloading.net will receive both so it can check the certificate against Apple.")
			case .passwordRecovery:
				return String.localized("The certificate file contains your private key. sideloading.net will receive the file so it can run a wordlist against it.")
			}
		}
	}

	/// Shown inline under the buttons that upload the certificate.
	static var inlineNotice: String {
		String.localized("This uploads the certificate file, including your private key, to sideloading.net. You will be asked to confirm before anything leaves this device.")
	}

	static func confirm(purpose: Purpose, onConfirm: @escaping () -> Void) {
		let upload = UIAlertAction(title: purpose.actionTitle, style: .destructive) { _ in
			onConfirm()
		}

		let message = purpose.summary
			+ "\n\n"
			+ String.localized("Anyone who has this file and its password can sign apps as you. Only continue if you trust sideloading.net and understand that it is a third party.")
			+ "\n\n"
			+ String.localized("Choose Cancel to keep the certificate on this device.")

		UIAlertController.showAlertWithCancel(
			title: String.localized("Send your private key to sideloading.net?"),
			message: message,
			actions: [upload]
		)
	}
}
