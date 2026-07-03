import Foundation
import Security

/// RSA-OAEP(SHA-1) encryption using the server's public key — matches Flutter's RsaService
/// (pointycastle `OAEPEncoding(RSAEngine())`, which defaults to SHA-1).
/// Used only to encrypt the password / confirm-password fields before citizen self-registration.
enum RsaService {

    private static let publicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4s6sEpFv6IIu4goE2Qc6
    euzyElJsvAUVJVfnXRljjsSq8qiFVHJpGUlFzI4IWOAz8GTk65i3fxLmbuKos2QD
    +pxql2TluJ4lbvZXRqotAwVqilnDk52vW8OP6un/u+gG+2Wyhjsn67YNCBrXsJ8C
    O+d7zcR7vcjpXT6oXyWqw3ePwVXTLOWonKpGvTS/ypzY0cDPOHv/x80lXguQj65U
    qPy9eVljeSo8ackIc0ylM44weqIENTWFnUW05ueW1zrtUAwOCVyRjCPW5iNafy7B
    Venhh8Htxfn6NT57fTPgDTMqMD6BB3U0PgpYjm4mFIPuP7YMUbfD6L3U4QY/COjL
    EQIDAQAB
    -----END PUBLIC KEY-----
    """

    enum RsaError: Error {
        case invalidKeyFormat
        case keyCreationFailed(String)
        case encryptionFailed(String)
    }

    static func encrypt(_ plainText: String) throws -> String {
        let pkcs1Data = try pkcs1PublicKeyData(fromSPKIPem: publicKeyPEM)

        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
        ]
        var cfError: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(pkcs1Data as CFData, attributes as CFDictionary, &cfError) else {
            let message = cfError.map { (CFErrorCopyDescription($0.takeRetainedValue()) as String) } ?? "unknown"
            throw RsaError.keyCreationFailed(message)
        }

        let plainData = Data(plainText.utf8)
        guard SecKeyIsAlgorithmSupported(secKey, .encrypt, .rsaEncryptionOAEPSHA1) else {
            throw RsaError.encryptionFailed("OAEP-SHA1 not supported for this key")
        }

        var encError: Unmanaged<CFError>?
        guard let cipherData = SecKeyCreateEncryptedData(
            secKey, .rsaEncryptionOAEPSHA1, plainData as CFData, &encError
        ) as Data? else {
            let message = encError.map { (CFErrorCopyDescription($0.takeRetainedValue()) as String) } ?? "unknown"
            throw RsaError.encryptionFailed(message)
        }

        return cipherData.base64EncodedString()
    }

    // MARK: - Minimal DER parsing: extract the inner PKCS#1 RSAPublicKey TLV from an SPKI blob.
    //
    // SubjectPublicKeyInfo ::= SEQUENCE {
    //   SEQUENCE { algorithm OID, NULL }                 -- skipped
    //   BIT STRING {
    //     SEQUENCE { INTEGER modulus, INTEGER exponent } -- this is the PKCS#1 blob we need
    //   }
    // }

    private static func pkcs1PublicKeyData(fromSPKIPem pem: String) throws -> Data {
        let base64 = pem
            .split(separator: "\n")
            .filter { !$0.hasPrefix("-----BEGIN") && !$0.hasPrefix("-----END") }
            .joined()
        guard let keyBytes = Data(base64Encoded: base64) else { throw RsaError.invalidKeyFormat }
        let bytes = [UInt8](keyBytes)

        let outer = try derReadTag(bytes, offset: 0)                      // outer SEQUENCE
        let algoEnd = try derSkipObject(bytes, offset: outer.contentOffset) // skip algorithm SEQUENCE
        let bitString = try derReadTag(bytes, offset: algoEnd)             // BIT STRING

        // BIT STRING content starts with a leading 0x00 "unused bits" byte.
        let innerOffset = bitString.contentOffset + 1
        let inner = try derReadTag(bytes, offset: innerOffset)             // inner SEQUENCE (PKCS#1)

        let tlvStart = innerOffset
        let tlvEnd = inner.nextOffset
        guard tlvEnd <= bytes.count else { throw RsaError.invalidKeyFormat }
        return Data(bytes[tlvStart..<tlvEnd])
    }

    private struct DERTag {
        let contentOffset: Int
        let contentLength: Int
        let nextOffset: Int
    }

    private static func derReadTag(_ data: [UInt8], offset: Int) throws -> DERTag {
        guard offset + 1 < data.count else { throw RsaError.invalidKeyFormat }
        var pos = offset + 1
        var length = Int(data[pos]); pos += 1
        if length & 0x80 != 0 {
            let numBytes = length & 0x7F
            length = 0
            guard pos + numBytes <= data.count else { throw RsaError.invalidKeyFormat }
            for _ in 0..<numBytes {
                length = (length << 8) | Int(data[pos]); pos += 1
            }
        }
        let next = pos + length
        guard next <= data.count else { throw RsaError.invalidKeyFormat }
        return DERTag(contentOffset: pos, contentLength: length, nextOffset: next)
    }

    private static func derSkipObject(_ data: [UInt8], offset: Int) throws -> Int {
        try derReadTag(data, offset: offset).nextOffset
    }
}
