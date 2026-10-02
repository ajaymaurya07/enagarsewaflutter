import Foundation
import Security
import CryptoKit

/// Pins the API host's TLS chain — the iOS equivalent of Flutter's `PinnedHttpClient`, which only
/// trusts the bundled leaf + RapidSSL intermediate. Here the chain must pass normal system
/// evaluation *and* contain a certificate whose SPKI SHA-256 matches one of `AppConstants.CertPins`.
final class CertificatePinner: NSObject, URLSessionDelegate {

    static let shared = CertificatePinner()
    private override init() {}

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let chain = (SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate]) ?? []
        if chain.contains(where: { spkiHash(for: $0).map(AppConstants.CertPins.all.contains) ?? false }) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    // MARK: - SPKI extraction

    /// SHA-256 over the DER SubjectPublicKeyInfo. `SecKeyCopyExternalRepresentation` returns the
    /// bare PKCS#1 key, so the RSA-2048 SPKI header is prepended (both pinned certs are RSA-2048).
    private func spkiHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        let rsa2048Header: [UInt8] = [
            0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09,
            0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
            0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00,
        ]
        var spki = Data(rsa2048Header)
        spki.append(publicKeyData)
        return Data(SHA256.hash(data: spki)).base64EncodedString()
    }
}
