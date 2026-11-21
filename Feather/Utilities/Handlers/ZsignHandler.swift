//
//  ZsignHandler.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import Foundation
import Zsign
import UIKit

final class ZsignHandler {
	var hadError: Error?
	
	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
	}
	
	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty else {
			return
		}
		
		let bundle = Bundle(url: _appUrl)
		let execPath = _appUrl.appendingPathComponent(bundle?.exec ?? "").relativePath
		
		if !Zsign.removeDylibs(appExecutable: execPath, using: _options.disInjectionFiles) {
			throw SigningFileHandlerError.disinjectFailed
		}
	}
	
	func sign() async throws {
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}
		
		// A revoked or expired certificate still signs an IPA, but iOS will never
		// let the user open it ("Unable to Verify App"), so stop here with an
		// actionable error instead of handing back a dead app.
		guard !cert.revoked else {
			throw ZsignCertificateError.revoked
		}
		if let expiration = cert.expiration, expiration <= Date() {
			throw ZsignCertificateError.expired
		}

		let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
			p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
			p12Password: cert.password ?? "",
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
	}
	
	func adhocSign() async throws {
		let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			adhoc: true,
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
	}
}

// MARK: - Errors
enum ZsignCertificateError: LocalizedError {
	case revoked
	case expired
	
	var errorDescription: String? {
		switch self {
		case .revoked:
			"This certificate has been revoked by Apple, so apps signed with it will never open (iOS shows “Unable to Verify App”). Import a working certificate, or fetch one from sideloading.net, and try again."
		case .expired:
			"This certificate has expired, so apps signed with it will not open. Import a working certificate and try again."
		}
	}
}
