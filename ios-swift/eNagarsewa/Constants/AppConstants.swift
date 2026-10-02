import Foundation

enum AppConstants {

    static let appName = "eNagarSewa"

    /// `BASE_URL` comes from Info.plist (set per configuration in project.yml), the iOS
    /// counterpart of Flutter's `--dart-define=BASE_URL`. Always normalised to end with `/`.
    static let baseURL: String = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let value = raw.isEmpty ? "https://iamsup.in/ulb_property_tax/" : raw
        return value.hasSuffix("/") ? value : value + "/"
    }()

    /// `AppConstants.appDisplayVersion` (versionName).
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// `AppConstants.apiVersion` (versionCode) — sent as `X-App-Version`.
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    enum CertPins {
        // SPKI SHA-256 hashes — update before expiry dates
        static let leaf         = "9cfpRdt3u5byy0K2nxVHhWnByC+qBa0BS+RG60siZpQ="  // exp 2026-09-27
        static let intermediate = "E3tYcwo9CiqATmKtpMLW5V+pzIq+ZoDmpXSiJlXGmTo="  // exp 2027-11-02
        static let all: Set<String> = [leaf, intermediate]
    }

    enum Timeout {
        static let request:  TimeInterval = 30
        static let resource: TimeInterval = 120
    }

    enum Notification {
        static let channelId   = "high_importance_channel"
        static let channelName = "High Importance Notifications"
    }

    enum Database {
        static let name    = "property_database.db"
        static let version = 9
    }
}
