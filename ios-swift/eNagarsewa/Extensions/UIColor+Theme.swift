import UIKit

extension UIColor {
    // MARK: - Brand colors (match Flutter #E67514 orange theme)
    /// Primary orange — #E67514
    static let appPrimary    = UIColor(named: "AppPrimary")    ?? UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
    static let appSecondary  = UIColor(named: "AppSecondary")  ?? UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
    static let appBackground = UIColor(named: "AppBackground") ?? UIColor.white
    static let appSurface    = UIColor(named: "AppSurface")    ?? UIColor.white
    static let appSuccess    = UIColor.systemGreen
    static let appWarning    = UIColor.systemOrange
    static let appError      = UIColor.systemRed

    // MARK: - Form / card tokens (match Flutter)
    /// Field fill — #F8F9FB
    static let appFieldFill   = UIColor(red: 0.973, green: 0.976, blue: 0.984, alpha: 1)
    /// Field enabled border — ~grey.shade200
    static let appFieldBorder = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1)
    /// Card text dark — #333333
    static let appCardText    = UIColor(red: 0.200, green: 0.200, blue: 0.200, alpha: 1)
}
