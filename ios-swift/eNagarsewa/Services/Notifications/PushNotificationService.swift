import Foundation
import FirebaseMessaging
import UserNotifications
import UIKit

/// FCM push notification setup — mirrors Flutter's push_notification_service.dart
final class PushNotificationService: NSObject {

    static let shared = PushNotificationService()
    private override init() {}

    // MARK: - Setup (call from AppDelegate after FirebaseApp.configure())

    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        requestPermission()
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Show local notification (foreground)

    func showLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - MessagingDelegate

extension PushNotificationService: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        // Store FCM token for login/signup requests
        UserDefaults.standard.set(token, forKey: "fcm_token")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    // Foreground notification — show it
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Notification tapped — handle routing
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationTap(userInfo: userInfo)
        completionHandler()
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // TODO: parse userInfo and route to the relevant screen via AppCoordinator
        // e.g. if let screen = userInfo["screen"] as? String { AppCoordinator.shared.navigate(to: screen) }
    }
}

// MARK: - Convenience

extension UserDefaults {
    var fcmToken: String? { string(forKey: "fcm_token") }
}
