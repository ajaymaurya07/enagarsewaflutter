import Foundation

/// Port of `ApiService._handleSessionExpired`: on an unrecoverable 403 the local session is torn
/// down and the whole navigation stack is replaced with the OTP login screen.
@MainActor
final class SessionManager {

    static let shared = SessionManager()
    private init() {}

    /// True while the teardown is replacing the navigation stack. Flows that also reset the
    /// stack (e.g. exiting an assessment) skip their own navigation while this is set.
    private(set) var isHandlingSessionExpiry = false

    /// Installed by `AppCoordinator` — resets the window to the OTP login screen.
    var onSessionExpired: (() -> Void)?

    func expireSession() async {
        guard !isHandlingSessionExpiry else { return }
        isHandlingSessionExpiry = true
        defer { isHandlingSessionExpiry = false }
        await DatabaseService.shared.clearDatabase()
        StorageService.logout()
        onSessionExpired?()
    }
}
