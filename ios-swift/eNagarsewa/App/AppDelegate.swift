import UIKit
import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// False when GoogleService-Info.plist is missing from the bundle — Firebase-dependent
    /// services (push, Crashlytics) are then skipped instead of crashing at launch.
    static private(set) var isFirebaseConfigured = false

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Mirrors main.dart: Firebase starts before the UI; crash reporting only in release.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            Self.isFirebaseConfigured = true
            #if DEBUG
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
            #else
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            #endif
        } else {
            print("⚠️ [Launch] GoogleService-Info.plist not found in the app bundle — Firebase disabled.")
        }
        print("[Launch] didFinishLaunching (BASE_URL=\(AppConstants.baseURL))")
        return true
    }

    // MARK: - APNs token passthrough to Firebase

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard Self.isFirebaseConfigured else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    // MARK: - Scene lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        // Set explicitly so the window never depends on the Info.plist class-name lookup.
        config.delegateClass = SceneDelegate.self
        return config
    }
}
