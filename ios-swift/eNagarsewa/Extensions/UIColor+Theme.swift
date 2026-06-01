import UIKit

extension UIColor {
    // App brand colors — also define these in Assets.xcassets for dark-mode support
    static let appPrimary    = UIColor(named: "AppPrimary")    ?? UIColor(red: 0.18, green: 0.48, blue: 0.78, alpha: 1)
    static let appSecondary  = UIColor(named: "AppSecondary")  ?? UIColor(red: 0.96, green: 0.62, blue: 0.02, alpha: 1)
    static let appBackground = UIColor(named: "AppBackground") ?? UIColor.systemBackground
    static let appSurface    = UIColor(named: "AppSurface")    ?? UIColor.secondarySystemBackground
    static let appSuccess    = UIColor.systemGreen
    static let appWarning    = UIColor.systemOrange
    static let appError      = UIColor.systemRed
}
