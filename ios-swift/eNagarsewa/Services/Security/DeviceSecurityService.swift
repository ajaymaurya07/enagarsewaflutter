import Foundation
import UIKit
import CryptoKit

/// Jailbreak detection + device fingerprinting.
/// Mirrors Flutter's device_service.dart and the iOS side of the device_security MethodChannel.
final class DeviceSecurityService {

    static let shared = DeviceSecurityService()
    private init() {}

    // MARK: - Device ID (SHA-256 of identifierForVendor)

    lazy var deviceId: String = {
        let raw = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let hash = SHA256.hash(data: Data(raw.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }()

    // MARK: - Jailbreak detection

    var isJailbroken: Bool {
        guard !isRunningInSimulator else { return false }
        return hasJailbreakFiles
            || canWriteOutsideSandbox
            || hasInjectedLibraries
    }

    // isDeveloperModeEnabled — not applicable on iOS (return false)
    var isDeveloperModeEnabled: Bool { false }

    // isTamperingDetected — check for Substrate/hook injection
    var isTamperingDetected: Bool {
        hasInjectedLibraries
    }

    // MARK: - Private checks

    private var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private var hasJailbreakFiles: Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/bin/bash",
            "/bin/sh",
            "/usr/sbin/sshd",
            "/usr/libexec/sftp-server",
            "/usr/bin/sshd",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/etc/apt",
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private var canWriteOutsideSandbox: Bool {
        let testPath = "/private/jailbreak_test_\(UUID().uuidString).txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }

    private var hasInjectedLibraries: Bool {
        // Check for known Substrate/hook libraries in loaded images
        let suspectedLibs = ["MobileSubstrate", "SubstrateLoader", "CydiaSubstrate",
                             "FridaGadget", "frida", "cynject"]
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let name = _dyld_get_image_name(i) {
                let imageName = String(cString: name).lowercased()
                if suspectedLibs.contains(where: { imageName.contains($0.lowercased()) }) {
                    return true
                }
            }
        }
        return false
    }
}
