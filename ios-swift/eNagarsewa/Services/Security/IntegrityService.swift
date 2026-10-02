import Foundation
import DeviceCheck
import CryptoKit

/// App Attest device integrity — port of the iOS path of lib/services/integrity_service.dart.
///
/// * `devMode` mirrors Dart's `_devMode` switch: while the backend verify-integrity API is not
///   live, verification always passes and payment requests carry `dev-mode-token`.
/// * First run: generate an App Attest key, attest it, register it with the backend.
///   Later runs: generate an assertion for the stored key. The key id is persisted only after
///   the backend accepts the attestation, so a failed attempt retries with a fresh key.
final class IntegrityService {

    static let shared = IntegrityService()
    private init() {}

    /// TODO: Set to false when the backend verify-integrity API goes live (same as Dart).
    static let devMode = true
    private static let devModeToken = "dev-mode-token"

    private let attester = DCAppAttestService.shared

    // MARK: - Public API

    /// Splash-screen check. Uses the cached token when present.
    func verify() async -> Bool {
        if Self.devMode { return true }
        if let cached = StorageService.integrityToken, !cached.isEmpty { return true }
        return await runFullVerify()
    }

    /// Token for integrity-protected (payment) requests; nil when verification failed.
    func getValidToken() async -> String? {
        if Self.devMode { return Self.devModeToken }
        if let cached = StorageService.integrityToken, !cached.isEmpty { return cached }
        guard await runFullVerify() else { return nil }
        return StorageService.integrityToken
    }

    /// Forces a full re-verify — used when a payment API answers with status 412.
    func refreshIntegrityToken() async -> String? {
        if Self.devMode { return Self.devModeToken }
        StorageService.clearIntegrityToken()
        guard await runFullVerify() else { return nil }
        return StorageService.integrityToken
    }

    // MARK: - App Attest flow

    private func runFullVerify() async -> Bool {
        // Simulator / unsupported hardware — Dart treats NOT_SUPPORTED as a pass.
        guard attester.isSupported else { return true }

        let keychain = KeychainService.shared
        let nonce = Self.generateNonce()
        let clientDataHash = Data(SHA256.hash(data: Data(nonce.utf8)))

        if let keyId = keychain.string(.appAttestKeyId) {
            do {
                let assertion = try await attester.generateAssertion(keyId, clientDataHash: clientDataHash)
                guard let token = await sendToBackend(["keyId": keyId,
                                                       "assertion": assertion.base64EncodedString(),
                                                       "nonce": nonce]) else { return false }
                StorageService.saveIntegrityToken(token)
                return true
            } catch {
                return false
            }
        }

        do {
            let keyId = try await attester.generateKey()
            let attestation: Data
            do {
                attestation = try await attester.attestKey(keyId, clientDataHash: clientDataHash)
            } catch {
                keychain.delete(.appAttestKeyId)
                return false
            }
            guard let token = await sendToBackend(["keyId": keyId,
                                                   "attestation": attestation.base64EncodedString(),
                                                   "nonce": nonce]) else { return false }
            keychain.set(keyId, for: .appAttestKeyId)
            StorageService.saveIntegrityToken(token)
            return true
        } catch {
            return false
        }
    }

    /// POST api/house_tax/verify-integrity (form-urlencoded, `platform=ios` + payload).
    private func sendToBackend(_ payload: [String: String]) async -> String? {
        if Self.devMode { return Self.devModeToken }
        let network = NetworkService.shared
        var fields: [(String, String)] = [("platform", "ios")]
        fields.append(contentsOf: payload.map { ($0.key, $0.value) })
        var request = network.formRequest("api/house_tax/verify-integrity",
                                          headers: ["X-App-Version": AppConstants.buildNumber,
                                                    "X-Device-Id": DeviceSecurityService.shared.deviceId],
                                          fields: fields)
        request.timeoutInterval = 10
        guard let result = try? await network.send(request), result.statusCode == 200,
              let json = try? result.json(),
              json["status_code"].str == "200" else { return nil }
        return json["integrity_token"].str
    }

    /// 32 random bytes, URL-safe Base64 without padding (Dart `_generateNonce`).
    private static func generateNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
