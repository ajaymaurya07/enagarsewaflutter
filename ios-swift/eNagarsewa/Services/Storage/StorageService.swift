import Foundation

/// Port of lib/services/storage_service.dart — same method names and the same split between
/// secure storage (Keychain) and plain preferences (UserDefaults).
enum StorageService {

    private static var keychain: KeychainService { .shared }
    private static var prefs: UserDefaultsService { .shared }

    // MARK: - Session

    static func saveLoginData(_ data: SignIn) {
        if let token = data.accessToken { keychain.set(token, for: .accessToken) }
        if let token = data.refreshToken { keychain.set(token, for: .refreshToken) }
        if let email = data.emailId { prefs.set(email, for: .emailId) }
        if let type = data.userType { prefs.set(type, for: .userType) }
        if let userId = data.userId, !userId.isEmpty { prefs.set(userId, for: .userId) }
    }

    static func updateAccessToken(_ token: String) { keychain.set(token, for: .accessToken) }

    static var accessToken: String? { keychain.string(.accessToken) }
    static var refreshToken: String? { keychain.string(.refreshToken) }

    static var isLoggedIn: Bool {
        guard let token = accessToken else { return false }
        return !token.isEmpty
    }

    static func setPropertyVerified(_ verified: Bool) { prefs.set(verified, for: .isPropertyVerified) }
    static var isPropertyVerified: Bool { prefs.bool(.isPropertyVerified) }

    static func saveUlbId(_ ulbId: String) { prefs.set(ulbId, for: .selectedUlbId) }
    static var ulbId: String? { prefs.string(.selectedUlbId) }

    /// Login (`verify_otp`) `user_id` — no other source exists at property selection time.
    static func saveUserId(_ userId: String) { prefs.set(userId, for: .userId) }
    static var userId: String? { prefs.string(.userId) }

    /// Login response `mobile`, compared against the property owner's mobile on selection.
    static func saveLoginMobile(_ mobile: String) { keychain.set(mobile, for: .loginMobile) }
    static var loginMobile: String? { keychain.string(.loginMobile) }
    static func clearLoginMobile() { keychain.delete(.loginMobile) }

    static func saveTotalArv(_ arv: String) { prefs.set(arv, for: .selectedPropertyTotalArv) }
    static var totalArv: String? { prefs.string(.selectedPropertyTotalArv) }

    static func saveEmailId(_ email: String) { prefs.set(email, for: .emailId) }
    static var emailId: String? { prefs.string(.emailId) }
    static var userType: String? { prefs.string(.userType) }

    static func logout() {
        keychain.delete(.accessToken)
        keychain.delete(.refreshToken)
        [.emailId, .userType, .userId, .isPropertyVerified, .selectedUlbId, .selectedPropertyTotalArv]
            .forEach { prefs.remove($0) }
        clearIntegrityToken()
        clearUlbLanguageCache()
        clearLoginMobile()
    }

    // MARK: - Remember me

    static func saveRememberMeCredentials(email: String, password: String) {
        keychain.set(email, for: .rememberMeEmail)
        keychain.set(password, for: .rememberMePass)
    }

    static var rememberMeCredentials: (email: String, password: String)? {
        guard let email = keychain.string(.rememberMeEmail), !email.isEmpty,
              let password = keychain.string(.rememberMePass), !password.isEmpty else { return nil }
        return (email, password)
    }

    static func clearRememberMeCredentials() {
        keychain.delete(.rememberMeEmail)
        keychain.delete(.rememberMePass)
    }

    // MARK: - Integrity token

    static func saveIntegrityToken(_ token: String) { keychain.set(token, for: .integrityToken) }
    static var integrityToken: String? { keychain.string(.integrityToken) }
    static func clearIntegrityToken() { keychain.delete(.integrityToken) }

    // MARK: - Payment transaction ids

    static func saveSbiMobileTransactionId(_ id: String) { keychain.set(id, for: .sbiTxnId) }
    static var sbiMobileTransactionId: String? { keychain.string(.sbiTxnId) }
    static func clearSbiMobileTransactionId() { keychain.delete(.sbiTxnId) }

    static func savePayuMobileTransactionId(_ id: String) { keychain.set(id, for: .payuTxnId) }
    static var payuMobileTransactionId: String? { keychain.string(.payuTxnId) }
    static func clearPayuMobileTransactionId() { keychain.delete(.payuTxnId) }

    // MARK: - ULB language / ULB id cache

    static func saveLanguageCache(_ language: String) { keychain.set(language, for: .ulbLanguage) }
    static var languageCache: String? { keychain.string(.ulbLanguage) }

    static func saveUlbCache(_ ulbId: String) { keychain.set(ulbId, for: .ulbIdCache) }
    static var ulbCache: String? { keychain.string(.ulbIdCache) }

    static func clearUlbLanguageCache() {
        keychain.delete(.ulbLanguage)
        keychain.delete(.ulbIdCache)
    }
}
