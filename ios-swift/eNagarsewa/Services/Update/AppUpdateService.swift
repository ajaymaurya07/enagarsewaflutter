import Foundation

/// Checks the App Store for a newer published version of this app.
///
/// Flutter's splash screen (`lib/splash_screen.dart`) uses the `in_app_update` plugin, which
/// wraps Google Play's in-app-update API — an Android-only mechanism (backed by Play Core, not
/// a custom backend endpoint). The plugin has no iOS implementation, so on iOS
/// `InAppUpdate.checkForUpdate()` throws and Flutter's own `_checkForUpdate()` swallows the
/// error and returns null — meaning the Flutter app never shows this sheet on iOS today.
///
/// This service is the iOS platform equivalent of what Play Core does on Android: it asks the
/// store itself (via Apple's public iTunes Lookup API) what the currently published version is.
/// There is no custom backend "version check" endpoint involved on either platform.
final class AppUpdateService {

    static let shared = AppUpdateService()
    private init() {}

    struct UpdateInfo {
        let storeVersion: String
        let storeURL: URL
    }

    private struct LookupResponse: Decodable {
        let results: [LookupResult]
    }

    private struct LookupResult: Decodable {
        let version: String
        let trackViewUrl: String
    }

    /// Returns update info if the App Store's published version is newer than the currently
    /// running build, or nil if already up to date / the check fails for any reason.
    /// Never throws — mirrors Flutter's `_checkForUpdate()`, which catches all errors (store
    /// unavailable, no network, etc.) and simply continues the splash flow normally.
    func checkForUpdate() async -> UpdateInfo? {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else {
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let result = decoded.results.first,
                  let storeURL = URL(string: result.trackViewUrl) else { return nil }

            guard isNewer(result.version, than: AppConstants.appVersion) else { return nil }
            return UpdateInfo(storeVersion: result.version, storeURL: storeURL)
        } catch {
            return nil
        }
    }

    /// Dot-separated numeric version comparison (e.g. "1.3.0" > "1.2.9").
    /// Non-numeric / missing components are treated as 0.
    private func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
