# eNagarsewa — native iOS (Swift / UIKit)

Native port of the Flutter app in `../lib`. Same screens, navigation, API contracts and
storage keys; programmatic UIKit (no storyboards).

## Build

Requires a Mac with Xcode 15+ (iOS 16 deployment target).

```sh
brew install xcodegen cocoapods
cd ios-swift
xcodegen generate        # creates eNagarsewa.xcodeproj from project.yml
pod install              # Firebase + PayU CheckoutPro
open eNagarsewa.xcworkspace
```

- API host: `BASE_URL` build setting in `project.yml` (the Flutter `--dart-define=BASE_URL`).
- Version: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` (sent as `X-App-Version`).
- Bundle id `com.vdsai.enagaesewa`, team `NP8L4T2ATA` (same as `ios/Runner`), so the existing
  `GoogleService-Info.plist`, push certificates and App Attest setup apply unchanged.

CI: `.github/workflows/ios-swift-build.yml` builds for the simulator without signing.

## Layout

| Folder | Contents |
|---|---|
| `App/` | `AppDelegate` (Firebase, Crashlytics, push), `SceneDelegate`, `AppRouter` |
| `Core/` | Lenient JSON parser, `SessionManager` (session expiry / logout) |
| `Services/` | Network (`APIService` = `api_service.dart`, certificate pinning), storage (Keychain, UserDefaults, SQLite), security, OTP gate, PDF, PayU, media picker |
| `Models/` | Request/response models matching the Dart models |
| `Views/` | One folder per feature: Splash, Auth, Property, Dashboard, Payment, Grievance, Assessment, Mutation, Water, Account, Common |
| `Resources/` | Info.plist, entitlements, assets, fonts (Poppins, Kruti Dev 010) |
