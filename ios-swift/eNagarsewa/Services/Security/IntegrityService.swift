import Foundation
import DeviceCheck
import CryptoKit

/// App Attest-based device integrity — iOS replacement for Play Integrity.
/// Mirrors Flutter's integrity_service.dart iOS path.
final class IntegrityService {

    static let shared = IntegrityService()
    private let network = NetworkService.shared
    private let keychain = KeychainService.shared
    private init() {}

    private let attester = DCAppAttestService.shared

    // MARK: - Public API

    /// Fetches or refreshes an integrity token. Caches in Keychain.
    func getIntegrityToken() async throws -> String {
        if let cached = keychain.integrityToken { return cached }
        return try await performAttestation()
    }

    func refreshIntegrityToken() async throws -> String {
        keychain.saveIntegrityToken("") // clear cache
        return try await performAttestation()
    }

    // MARK: - Attestation flow

    private func performAttestation() async throws -> String {
        guard attester.isSupported else {
            // Simulator or unsupported device — use a placeholder for dev builds
            #if DEBUG
            let placeholder = "debug-integrity-token-\(UUID().uuidString)"
            keychain.saveIntegrityToken(placeholder)
            return placeholder
            #else
            throw IntegrityError.notSupported
            #endif
        }

        // Step 1: get or generate key
        let keyId = try await resolveKeyId()

        // Step 2: fetch nonce from server
        let nonce = try await fetchNonce()

        // Step 3: hash nonce as clientDataHash
        let clientDataHash = Data(SHA256.hash(data: Data(nonce.utf8)))

        // Step 4: attest key with Apple
        let attestation = try await attester.attestKey(keyId, clientDataHash: clientDataHash)

        // Step 5: verify with backend
        let response: VerifyIntegrityResponse = try await network.request(
            .verifyIntegrity,
            method: .POST,
            body: VerifyIntegrityRequest(
                attestation: attestation.base64EncodedString(),
                keyId: keyId,
                nonce: nonce
            ),
            requiresAuth: false
        )

        guard response.success, let token = response.integrityToken else {
            throw IntegrityError.verificationFailed(response.message)
        }

        keychain.saveIntegrityToken(token)
        return token
    }

    // MARK: - Assertion (for payment calls)

    func generateAssertion(for requestData: String) async throws -> String {
        let keyId = try await resolveKeyId()
        let hash = Data(SHA256.hash(data: Data(requestData.utf8)))
        let assertion = try await attester.generateAssertion(keyId, clientDataHash: hash)
        return assertion.base64EncodedString()
    }

    // MARK: - Helpers

    private func resolveKeyId() async throws -> String {
        if let existing = keychain.appAttestKeyId { return existing }
        let keyId = try await attester.generateKey()
        keychain.saveAppAttestKeyId(keyId)
        return keyId
    }

    private func fetchNonce() async throws -> String {
        let fields = ["device_id": DeviceSecurityService.shared.deviceId]
        let response: GetNonceResponse = try await network.requestMultipart(
            .getNonce, fields: fields, requiresAuth: false
        )
        return response.nonce
    }
}

enum IntegrityError: LocalizedError {
    case notSupported
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSupported:               return "Device integrity check is not supported."
        case .verificationFailed(let m):  return "Integrity verification failed: \(m)"
        }
    }
}
