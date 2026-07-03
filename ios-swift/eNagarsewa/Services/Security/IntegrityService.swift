import Foundation
import DeviceCheck
import CryptoKit

/// App Attest-based device integrity — iOS replacement for Play Integrity.
/// Mirrors Flutter's integrity_service.dart iOS path (_verifyIos / _fetchBackendNonce / _sendToBackend):
///   - First run: generate an App Attest key, attest it with Apple, register it with the backend.
///   - Subsequent runs: generate an assertion for the existing key and verify it with the backend.
///   - The key id is only persisted after the backend confirms success, so a failed attempt
///     retries fresh (a new key) on next launch rather than replaying an already-attested key
///     (Apple only allows `attestKey` to be called once per key).
final class IntegrityService {

    static let shared = IntegrityService()
    private let network = NetworkService.shared
    private let keychain = KeychainService.shared
    private init() {}

    private let attester = DCAppAttestService.shared

    // MARK: - Public API

    /// Returns a cached token if one exists, otherwise runs the full verify flow and caches
    /// the result. Mirrors Dart's `getValidToken()` / `verify()` — call before integrity-gated
    /// requests (and once, non-blocking, from the splash screen).
    func getValidToken() async throws -> String {
        if let cached = keychain.integrityToken, !cached.isEmpty { return cached }
        return try await performAttestation()
    }

    /// Back-compat name used by existing call sites (SplashViewModel, PaymentDetailsViewModel).
    /// Same semantics as `getValidToken()`.
    func getIntegrityToken() async throws -> String {
        try await getValidToken()
    }

    /// Forces a full re-verify, ignoring any cached token. Called by
    /// APIService.performWithIntegrity when a request comes back with
    /// NetworkError.integrityExpired (HTTP 412) — matches Dart's refreshIntegrityToken(),
    /// invoked when a payment API responds with status_code 412.
    func refreshIntegrityToken() async throws -> String {
        keychain.clearIntegrityToken()
        return try await performAttestation()
    }

    // MARK: - Attestation flow (mirrors Dart's _verifyIos)

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

        if let existingKeyId = keychain.appAttestKeyId {
            // Subsequent runs: generate an assertion for the already-attested key.
            return try await performAssertion(keyId: existingKeyId)
        } else {
            // First run: generate a key and attest it with Apple.
            return try await performInitialAttestation()
        }
    }

    /// First-time flow: generateKey → attestKey → verify with backend.
    /// The keyId is persisted only after the backend confirms success (matches Dart's comment
    /// "Persist keyId only after successful backend attestation").
    private func performInitialAttestation() async throws -> String {
        do {
            let keyId = try await attester.generateKey()
            let nonce = try await fetchNonce()
            let clientDataHash = Data(SHA256.hash(data: Data(nonce.utf8)))
            let attestation = try await attester.attestKey(keyId, clientDataHash: clientDataHash)

            let token = try await verifyWithBackend(fields: [
                "keyId": keyId,
                "attestation": attestation.base64EncodedString(),
                "nonce": nonce,
            ])

            keychain.saveAppAttestKeyId(keyId)
            keychain.saveIntegrityToken(token)
            return token
        } catch let error as DCError {
            // Attestation failed — nothing was persisted, so the next launch retries with a
            // fresh key. Mirrors Dart's ATTEST_ERROR handling (deletes the stored key id).
            throw IntegrityError.verificationFailed(error.localizedDescription)
        }
    }

    /// Subsequent-run flow: generateAssertion → verify with backend.
    private func performAssertion(keyId: String) async throws -> String {
        let nonce = try await fetchNonce()
        let clientDataHash = Data(SHA256.hash(data: Data(nonce.utf8)))
        let assertion = try await attester.generateAssertion(keyId, clientDataHash: clientDataHash)

        let token = try await verifyWithBackend(fields: [
            "keyId": keyId,
            "assertion": assertion.base64EncodedString(),
            "nonce": nonce,
        ])

        keychain.saveIntegrityToken(token)
        return token
    }

    // MARK: - Assertion (for signing arbitrary payment request data, if needed by callers)

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

    /// Fetches a server-generated nonce.
    /// Mirrors Dart's _fetchBackendNonce: POST api/Play_integrity/get_nonce (multipart/form-data,
    /// field `device_id`), validating `status_code == "200"` and a non-empty `nonce`.
    private func fetchNonce() async throws -> String {
        let fields = ["device_id": DeviceSecurityService.shared.deviceId]
        let response: GetNonceResponse = try await network.requestMultipart(
            .getNonce, fields: fields, requiresAuth: false
        )
        guard response.statusCode == "200", let nonce = response.nonce, !nonce.isEmpty else {
            throw IntegrityError.verificationFailed("Failed to fetch integrity nonce")
        }
        return nonce
    }

    /// POSTs the integrity payload to the backend and returns the backend-issued
    /// integrity_token on success. Mirrors Dart's _sendToBackend: POST
    /// api/house_tax/verify-integrity (application/x-www-form-urlencoded), with
    /// `platform` always set to "ios" alongside the caller-supplied fields
    /// (keyId + attestation|assertion + nonce), validating `status_code == "200"`.
    private func verifyWithBackend(fields: [String: String]) async throws -> String {
        var body = fields
        body["platform"] = "ios"

        let response: VerifyIntegrityResponse = try await network.requestForm(
            .verifyIntegrity, fields: body, requiresAuth: false
        )
        guard response.statusCode == "200",
              let token = response.integrityToken,
              !token.isEmpty else {
            throw IntegrityError.verificationFailed("Integrity verification failed")
        }
        return token
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
