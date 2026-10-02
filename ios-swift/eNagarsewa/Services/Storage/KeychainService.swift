import Foundation
import Security

/// Generic-password Keychain store — the iOS counterpart of `flutter_secure_storage`.
final class KeychainService {

    static let shared = KeychainService()
    private init() {}

    private let service = Bundle.main.bundleIdentifier ?? "com.vdsai.enagaesewa"

    enum Key: String, CaseIterable {
        case accessToken       = "access_token"
        case refreshToken      = "refresh_token"
        case integrityToken    = "integrity_token"
        case loginMobile       = "login_mobile_no"
        case rememberMeEmail   = "remember_me_email"
        case rememberMePass    = "remember_me_password"
        case sbiTxnId          = "sbi_mobile_transaction_id"
        case payuTxnId         = "payu_mobile_transaction_id"
        case ulbLanguage       = "ulb_language"
        case ulbIdCache        = "ulb_id_cache"
        case appAttestKeyId    = "app_attest_key_id"
    }

    // MARK: - CRUD

    func string(_ key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query = baseQuery(for: key)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    func delete(_ key: Key) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    func clearAll() {
        Key.allCases.forEach(delete)
    }

    private func baseQuery(for key: Key) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: service,
         kSecAttrAccount: key.rawValue]
    }
}
