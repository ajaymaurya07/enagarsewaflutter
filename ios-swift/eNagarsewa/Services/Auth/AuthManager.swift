import Foundation
import Combine

/// Central auth state controller.
/// Manages token lifecycle, token refresh on 403, and logout.
@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var emailId: String = ""
    @Published private(set) var userType: String = ""

    private let keychain  = KeychainService.shared
    private let defaults  = UserDefaultsService.shared
    private let network   = NetworkService.shared
    private var isRefreshing = false

    private init() {
        isAuthenticated = keychain.accessToken != nil
        emailId  = defaults.emailId  ?? ""
        userType = defaults.userType ?? ""
    }

    // MARK: - Post-login

    func handleLoginSuccess(_ data: LoginData) {
        keychain.saveAccessToken(data.accessToken)
        keychain.saveRefreshToken(data.refreshToken)
        defaults.emailId  = data.emailId
        defaults.userType = data.userType
        emailId           = data.emailId
        userType          = data.userType
        isAuthenticated   = true
    }

    // MARK: - Token refresh (called by APIService on 403)

    func refreshTokenIfNeeded() async throws {
        guard !isRefreshing else {
            // Wait briefly for the in-flight refresh
            try await Task.sleep(nanoseconds: 500_000_000)
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let refresh = keychain.refreshToken else {
            await logout()
            throw NetworkError.unauthorized
        }

        do {
            let response: RefreshTokenResponse = try await network.request(
                .refreshToken,
                method: .POST,
                body: RefreshTokenRequest(refreshToken: refresh),
                requiresAuth: false
            )
            guard response.success, let data = response.data else {
                await logout()
                throw NetworkError.unauthorized
            }
            keychain.saveAccessToken(data.accessToken)
        } catch {
            await logout()
            throw error
        }
    }

    // MARK: - Logout

    func logout() async {
        // Fire-and-forget server logout (don't block UI on network failure)
        if keychain.accessToken != nil {
            Task {
                _ = try? await network.request(
                    .logout, method: .POST,
                    body: EmptyBody(),
                    requiresAuth: true
                ) as LogoutResponse
            }
        }
        clearLocalState()
    }

    func clearLocalState() {
        keychain.clearAuthTokens()
        defaults.clearSession()
        DatabaseService.shared.deleteAll()
        isAuthenticated = false
        emailId  = ""
        userType = ""
    }
}

// Used for bodyless POST requests
private struct EmptyBody: Encodable {}
