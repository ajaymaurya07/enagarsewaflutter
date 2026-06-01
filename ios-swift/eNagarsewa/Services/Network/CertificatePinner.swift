import Foundation
import Security
import CryptoKit

/// Validates URLSession server trust against SPKI SHA-256 pins from AppConstants.CertPins.
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
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var secResult = SecTrustResultType.invalid
        SecTrustEvaluate(serverTrust, &secResult)

        let certCount = SecTrustGetCertificateCount(serverTrust)
        for i in 0..<certCount {
            guard let cert = SecTrustGetCertificateAtIndex(serverTrust, i) else { continue }
            if let pin = spkiHash(for: cert), AppConstants.CertPins.all.contains(pin) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    // MARK: - SPKI extraction

    private func spkiHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }

        // Prepend ASN.1 header for RSA-2048 public key (most common)
        let rsaHeader: [UInt8] = [
            0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09,
            0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
            0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
        ]
        var spkiData = Data(rsaHeader)
        spkiData.append(publicKeyData)

        let hash = SHA256.hash(data: spkiData)
        return Data(hash).base64EncodedString()
    }
}
