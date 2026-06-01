import Foundation
import CryptoKit

extension String {
    var sha256: String {
        SHA256.hash(data: Data(utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }

    var sha512: String {
        SHA512.hash(data: Data(utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }

    var sha256Data: Data {
        Data(SHA256.hash(data: Data(utf8)))
    }
}

extension Data {
    var sha256Base64: String {
        Data(SHA256.hash(data: self)).base64EncodedString()
    }
}
