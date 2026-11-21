//
//  SideloadingCertsService.swift
//  Feather
//
//  Talks to the public sideloading.net certificate API:
//  list, download, remote verification and password recovery.
//

import Foundation
import UIKit
import Combine
import OSLog

// MARK: - Models
struct SideloadingCertificate: Codable, Identifiable, Hashable {
	let id: Int
	let name: String
	let status: String
	let valid_from: String?
	let valid_to: String?
	let folder_name: String?
	let nickname: String?

	var displayName: String {
		if let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return nickname
		}
		return name
	}

	var isRevoked: Bool {
		status.localizedCaseInsensitiveContains("revoked")
	}

	var expirationDate: Date? {
		guard let valid_to else { return nil }
		return Self.formatter.date(from: valid_to.trimmingCharacters(in: .whitespacesAndNewlines))
	}

	var isExpired: Bool {
		guard let expirationDate else { return false }
		return expirationDate < Date()
	}

	var isValid: Bool {
		!isRevoked && !isExpired
	}

	var expiryDescription: String {
		guard let expirationDate else { return .localized("Unknown expiry") }
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter.string(from: expirationDate)
	}

	private static let formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "MMM d HH:mm:ss yyyy 'GMT'"
		formatter.timeZone = TimeZone(identifier: "GMT")
		return formatter
	}()
}

enum SideloadingCertsError: LocalizedError {
	case invalidResponse
	case server(String)
	case missingPassword
	case unreadableProfile
	case badPassword

	var errorDescription: String? {
		switch self {
		case .invalidResponse:
			return .localized("sideloading.net returned an unexpected response.")
		case .server(let message):
			return message
		case .missingPassword:
			return .localized("This certificate does not publish a password.")
		case .unreadableProfile:
			return .localized("The provisioning profile could not be read.")
		case .badPassword:
			return .localized("The password published for this certificate did not work.")
		}
	}
}

// MARK: - Service
final class SideloadingCertsService: ObservableObject {
	static let shared = SideloadingCertsService()
	static let baseURL = URL(string: "https://sideloading.net")!

	@Published private(set) var certificates: [SideloadingCertificate] = []
	@Published private(set) var isLoading = false
	@Published private(set) var errorMessage: String?

	private let _session: URLSession

	init() {
		let configuration = URLSessionConfiguration.default
		configuration.timeoutIntervalForRequest = 30
		configuration.timeoutIntervalForResource = 90
		configuration.waitsForConnectivity = true
		_session = URLSession(configuration: configuration)
	}

	// MARK: Listing
	func load() async {
		await MainActor.run {
			self.isLoading = true
			self.errorMessage = nil
		}

		do {
			let data = try await _get("/api/certificates/list/all")
			let list = try JSONDecoder().decode([SideloadingCertificate].self, from: data)
			await MainActor.run {
				self.certificates = list
				self.isLoading = false
			}
		} catch {
			Logger.misc.error("sideloading.net list failed: \(error.localizedDescription)")
			await MainActor.run {
				self.errorMessage = error.localizedDescription
				self.isLoading = false
			}
		}
	}

	var validCertificates: [SideloadingCertificate] {
		certificates
			.filter { $0.isValid }
			.sorted { ($0.expirationDate ?? .distantPast) > ($1.expirationDate ?? .distantPast) }
	}

	/// The signed certificate with the longest remaining validity.
	var bestCertificate: SideloadingCertificate? {
		validCertificates.first
	}

	// MARK: Import
	func importCertificate(_ cert: SideloadingCertificate, nickname: String? = nil) async throws {
		let directory = FileManager.default.temporaryDirectory
			.appendingPathComponent("SEUsignRemote-\(UUID().uuidString)", isDirectory: true)
		try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }

		let p12URL = directory.appendingPathComponent("cert.p12")
		let provisionURL = directory.appendingPathComponent("cert.mobileprovision")

		let p12Data = try await _get("/api/certificates/download/\(cert.id)/cert.p12")
		let provisionData = try await _get("/api/certificates/download/\(cert.id)/cert.mobileprovision")
		let passwordData = try await _get("/api/certificates/download/\(cert.id)/password")

		guard
			let password = String(data: passwordData, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines),
			!password.isEmpty
		else {
			throw SideloadingCertsError.missingPassword
		}

		try p12Data.write(to: p12URL, options: .atomic)
		try provisionData.write(to: provisionURL, options: .atomic)

		guard CertificateReader(provisionURL).decoded != nil else {
			throw SideloadingCertsError.unreadableProfile
		}

		guard FR.checkPasswordForCertificate(for: p12URL, with: password, using: provisionURL) else {
			throw SideloadingCertsError.badPassword
		}

		let name = nickname ?? cert.displayName

		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			FR.handleCertificateFiles(
				p12URL: p12URL,
				provisionURL: provisionURL,
				p12Password: password,
				certificateName: name
			) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}

		UserDefaults.standard.set(0, forKey: "seusign.selectedCert")
	}

	// MARK: Remote verification
	func check(_ cert: CertificatePair) async throws -> String {
		guard
			let p12URL = Storage.shared.getFile(.certificate, from: cert),
			let provisionURL = Storage.shared.getFile(.provision, from: cert)
		else {
			throw SideloadingCertsError.unreadableProfile
		}

		let boundary = "SEUsign-\(UUID().uuidString)"
		var body = Data()
		_appendFile(
			to: &body,
			boundary: boundary,
			field: "p12",
			filename: "cert.p12",
			mime: "application/octet-stream",
			data: try Data(contentsOf: p12URL)
		)
		_appendField(to: &body, boundary: boundary, name: "password", value: cert.password ?? "")
		_appendFile(
			to: &body,
			boundary: boundary,
			field: "mobileprovision",
			filename: "cert.mobileprovision",
			mime: "application/octet-stream",
			data: try Data(contentsOf: provisionURL)
		)
		body.append(Data("--\(boundary)--\r\n".utf8))

		guard let url = URL(string: "/api/certchecker/checkCert", relativeTo: Self.baseURL) else {
			throw SideloadingCertsError.invalidResponse
		}

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		request.httpBody = body

		let (data, response) = try await _session.data(for: request)
		try _validate(data: data, response: response)

		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			throw SideloadingCertsError.invalidResponse
		}

		if let error = json["error"] as? String {
			throw SideloadingCertsError.server(error)
		}

		var lines: [String] = []

		if let p12 = json["p12"] as? [String: Any] {
			if let commonName = p12["Common Name"] as? String {
				lines.append(commonName)
			}
			if let status = p12["Status"] as? String {
				lines.append("\(String.localized("Status")): \(status)")
			}
			if let validTo = p12["Valid To"] as? String {
				lines.append("\(String.localized("Valid To")): \(validTo)")
			}
			if let team = p12["Team ID"] as? String {
				lines.append("\(String.localized("Team ID")): \(team)")
			}
		}

		if let mobile = json["mobileprovision"] as? [String: Any] {
			if let name = mobile["Name"] as? String {
				lines.append("\(String.localized("Profile")): \(name)")
			}
			if let validTo = mobile["Valid To"] as? String {
				lines.append("\(String.localized("Profile Valid To")): \(validTo)")
			}
		}

		guard !lines.isEmpty else {
			throw SideloadingCertsError.invalidResponse
		}

		return lines.joined(separator: "\n")
	}

	// MARK: Password recovery
	func crackPassword(for p12URL: URL) async throws -> String {
		let boundary = "SEUsign-\(UUID().uuidString)"
		var body = Data()
		_appendFile(
			to: &body,
			boundary: boundary,
			field: "p12file",
			filename: "cert.p12",
			mime: "application/octet-stream",
			data: try Data(contentsOf: p12URL)
		)
		_appendField(to: &body, boundary: boundary, name: "wordlist_mode", value: "default")
		body.append(Data("--\(boundary)--\r\n".utf8))

		guard let url = URL(string: "/api/crackp12/crack", relativeTo: Self.baseURL) else {
			throw SideloadingCertsError.invalidResponse
		}

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		request.httpBody = body
		request.timeoutInterval = 90

		let (data, response) = try await _session.data(for: request)
		try _validate(data: data, response: response)

		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			throw SideloadingCertsError.invalidResponse
		}

		if let success = json["success"] as? Bool, success, let password = json["password"] as? String {
			return password
		}

		throw SideloadingCertsError.server(
			(json["message"] as? String) ?? .localized("No password could be found in the default wordlist.")
		)
	}

	// MARK: Networking
	private func _get(_ path: String) async throws -> Data {
		guard let url = URL(string: path, relativeTo: Self.baseURL) else {
			throw SideloadingCertsError.invalidResponse
		}

		let (data, response) = try await _session.data(from: url)
		try _validate(data: data, response: response)
		return data
	}

	private func _validate(data: Data, response: URLResponse) throws {
		guard let http = response as? HTTPURLResponse else {
			throw SideloadingCertsError.invalidResponse
		}

		guard (200...299).contains(http.statusCode) else {
			if
				let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				let message = (json["error"] as? String) ?? (json["detail"] as? String)
			{
				throw SideloadingCertsError.server(message)
			}
			throw SideloadingCertsError.server(
				"\(String.localized("sideloading.net responded with")) \(http.statusCode)."
			)
		}
	}

	private func _appendField(to body: inout Data, boundary: String, name: String, value: String) {
		body.append(Data("--\(boundary)\r\n".utf8))
		body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
		body.append(Data("\(value)\r\n".utf8))
	}

	private func _appendFile(
		to body: inout Data,
		boundary: String,
		field: String,
		filename: String,
		mime: String,
		data: Data
	) {
		body.append(Data("--\(boundary)\r\n".utf8))
		body.append(
			Data("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(filename)\"\r\n".utf8)
		)
		body.append(Data("Content-Type: \(mime)\r\n\r\n".utf8))
		body.append(data)
		body.append(Data("\r\n".utf8))
	}
}
