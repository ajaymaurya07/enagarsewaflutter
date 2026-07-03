import Foundation
import Security

/// Typed interface over iOS Keychain — direct replacement for flutter_secure_storage.
final class KeychainService {

    static let shared = KeychainService()
    private init() {}

    private let service = Bundle.main.bundleIdentifier ?? "com.enagarsewa.app"

    // MARK: - Typed properties

    var accessToken:       String? { get(key: .accessToken)       }
    var refreshToken:      String? { get(key: .refreshToken)      }
    var integrityToken:    String? { get(key: .integrityToken)    }
    var rememberMeEmail:   String? { get(key: .rememberMeEmail)   }
    var rememberMePass:    String? { get(key: .rememberMePass)    }
    var sbiTxnId:          String? { get(key: .sbiTxnId)         }
    var payuTxnId:         String? { get(key: .payuTxnId)        }
    var appAttestKeyId:    String? { get(key: .appAttestKeyId)   }

    func saveAccessToken(_ value: String)    { save(key: .accessToken, value: value) }
    func saveRefreshToken(_ value: String)   { save(key: .refreshToken, value: value) }
    func saveIntegrityToken(_ value: String) { save(key: .integrityToken, value: value) }
    func saveRememberMe(email: String, password: String) {
        save(key: .rememberMeEmail, value: email)
        save(key: .rememberMePass, value: password)
    }
    func saveSbiTxnId(_ value: String)       { save(key: .sbiTxnId, value: value) }
    func savePayuTxnId(_ value: String)      { save(key: .payuTxnId, value: value) }
    func saveAppAttestKeyId(_ value: String) { save(key: .appAttestKeyId, value: value) }

    /// Matches Flutter's `StorageService.clearPayuMobileTransactionId()` — called once a PayU
    /// transaction has been successfully cross-verified against the server.
    func clearPayuTxnId() { delete(key: .payuTxnId) }
    func clearSbiTxnId()  { delete(key: .sbiTxnId) }

    /// Clears remembered credentials when "Remember me" is unchecked — matches Flutter clearRememberMeCredentials().
    func clearRememberMe() {
        delete(key: .rememberMeEmail)
        delete(key: .rememberMePass)
    }

    /// Deletes the cached integrity token — matches Flutter StorageService.clearIntegrityToken()
    /// (uses delete rather than writing an empty string, so the cache-check `!= nil` stays correct).
    func clearIntegrityToken() {
        delete(key: .integrityToken)
    }

    func clearAuthTokens() {
        delete(key: .accessToken)
        delete(key: .refreshToken)
        delete(key: .integrityToken)
    }

    func clearAll() {
        KeychainKey.allCases.forEach { delete(key: $0) }
    }

    // MARK: - Generic CRUD

    private func save(key: KeychainKey, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        var query = baseQuery(for: key)

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let update: [CFString: Any] = [kSecValueData: data]
            SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            query[kSecValueData] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    private func get(key: KeychainKey) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData]  = true
        query[kSecMatchLimit]  = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: KeychainKey) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: KeychainKey) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: key.rawValue]
    }
}

// MARK: - Keys

private enum KeychainKey: String, CaseIterable {
    case accessToken       = "access_token"
    case refreshToken      = "refresh_token"
    case integrityToken    = "integrity_token"
    case rememberMeEmail   = "remember_me_email"
    case rememberMePass    = "remember_me_password"
    case sbiTxnId          = "sbi_mobile_transaction_id"
    case payuTxnId         = "payu_mobile_transaction_id"
    case appAttestKeyId    = "app_attest_key_id"
}
