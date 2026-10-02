import UIKit

extension UIColor {

    /// `Color(0xAARRGGBB)` / `#RRGGBB` / `#AARRGGBB`.
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 6 { s = "FF" + s }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255,
                  alpha: CGFloat((value >> 24) & 0xFF) / 255)
    }

    convenience init(argb: UInt32) {
        self.init(red: CGFloat((argb >> 16) & 0xFF) / 255,
                  green: CGFloat((argb >> 8) & 0xFF) / 255,
                  blue: CGFloat(argb & 0xFF) / 255,
                  alpha: CGFloat((argb >> 24) & 0xFF) / 255)
    }

    // MARK: - Brand (hard-coded `Color(0xFFE67514)` used throughout the Flutter screens)

    static let appPrimary     = UIColor(argb: 0xFFE67514)
    static let appPrimaryLight = UIColor(argb: 0xFFFFF4E5)   // icon tiles / slider background
    static let appPrimaryBorder = UIColor(argb: 0xFFFFE0B2)
    static let appFieldFill   = UIColor(argb: 0xFFF8F9FB)
    static let appFieldBorder = grey200
    static let appBackground  = UIColor(argb: 0xFFF8F9FB)
    static let appTextDark    = UIColor(argb: 0xFF333333)
    static let appTextMid     = UIColor(argb: 0xFF444444)
    static let appTextLabel   = UIColor(argb: 0xFF555555)
    static let appTextBody    = UIColor(argb: 0xFF666666)
    static let appTextSub     = UIColor(argb: 0xFF777777)
    static let appTextHint    = UIColor(argb: 0xFF999999)
    static let appTextFaint   = UIColor(argb: 0xFFBBBBBB)

    // MARK: - Material 3 scheme (`ColorScheme.fromSeed(seedColor: 0xFFE67514)`, light, 2021 spec)

    enum Scheme {
        static let primary                 = UIColor(argb: 0xFF8B4F24)
        static let onPrimary               = UIColor.white
        static let primaryContainer        = UIColor(argb: 0xFFFFDBC7)
        static let onPrimaryContainer      = UIColor(argb: 0xFF6E380F)
        static let secondary               = UIColor(argb: 0xFF755846)
        static let secondaryContainer      = UIColor(argb: 0xFFFFDBC7)
        static let tertiary                = UIColor(argb: 0xFF606134)
        static let error                   = UIColor(argb: 0xFFBA1A1A)
        static let surface                 = UIColor(argb: 0xFFFFF8F5)
        static let onSurface               = UIColor(argb: 0xFF221A15)
        static let onSurfaceVariant        = UIColor(argb: 0xFF52443C)
        static let outline                 = UIColor(argb: 0xFF84746A)
        static let outlineVariant          = UIColor(argb: 0xFFD7C3B8)
        static let surfaceContainerLowest  = UIColor.white
        static let surfaceContainerLow     = UIColor(argb: 0xFFFFF1EA)
        static let surfaceContainer        = UIColor(argb: 0xFFFCEBE2)
        static let surfaceContainerHigh    = UIColor(argb: 0xFFF6E5DC)
        static let surfaceContainerHighest = UIColor(argb: 0xFFF0DFD7)
    }

    // MARK: - Flutter `Colors.*` palette entries used by the screens

    static let grey50  = UIColor(argb: 0xFFFAFAFA)
    static let grey100 = UIColor(argb: 0xFFF5F5F5)
    static let grey200 = UIColor(argb: 0xFFEEEEEE)
    static let grey300 = UIColor(argb: 0xFFE0E0E0)
    static let grey400 = UIColor(argb: 0xFFBDBDBD)
    static let grey500 = UIColor(argb: 0xFF9E9E9E)
    static let grey600 = UIColor(argb: 0xFF757575)
    static let grey700 = UIColor(argb: 0xFF616161)
    static let grey800 = UIColor(argb: 0xFF424242)
    static let grey900 = UIColor(argb: 0xFF212121)

    static let mGreen       = UIColor(argb: 0xFF4CAF50)
    static let mGreen50     = UIColor(argb: 0xFFE8F5E9)
    static let mGreen100    = UIColor(argb: 0xFFC8E6C9)
    static let mGreen600    = UIColor(argb: 0xFF43A047)
    static let mGreen700    = UIColor(argb: 0xFF388E3C)
    static let mGreen800    = UIColor(argb: 0xFF2E7D32)
    static let mRed         = UIColor(argb: 0xFFF44336)
    static let mRed50       = UIColor(argb: 0xFFFFEBEE)
    static let mRed100      = UIColor(argb: 0xFFFFCDD2)
    static let mRed300      = UIColor(argb: 0xFFE57373)
    static let mRed400      = UIColor(argb: 0xFFEF5350)
    static let mRed600      = UIColor(argb: 0xFFE53935)
    static let mRed700      = UIColor(argb: 0xFFD32F2F)
    static let mOrange      = UIColor(argb: 0xFFFF9800)
    static let mOrange50    = UIColor(argb: 0xFFFFF3E0)
    static let mOrange100   = UIColor(argb: 0xFFFFE0B2)
    static let mOrange700   = UIColor(argb: 0xFFF57C00)
    static let mOrange800   = UIColor(argb: 0xFFEF6C00)
    static let mDeepOrange  = UIColor(argb: 0xFFFF5722)
    static let mBlue        = UIColor(argb: 0xFF2196F3)
    static let mBlue50      = UIColor(argb: 0xFFE3F2FD)
    static let mBlue100     = UIColor(argb: 0xFFBBDEFB)
    static let mBlue700     = UIColor(argb: 0xFF1976D2)
    static let mBlue800     = UIColor(argb: 0xFF1565C0)
    static let mAmber       = UIColor(argb: 0xFFFFC107)
    static let mAmber50     = UIColor(argb: 0xFFFFF8E1)
    static let mAmber700    = UIColor(argb: 0xFFFFA000)
    static let mAmber800    = UIColor(argb: 0xFFFF8F00)
    static let mTeal        = UIColor(argb: 0xFF009688)
    static let mIndigo      = UIColor(argb: 0xFF3F51B5)
    static let mPurple      = UIColor(argb: 0xFF9C27B0)
    static let black87      = UIColor.black.withAlphaComponent(0.87)
    static let black54      = UIColor.black.withAlphaComponent(0.54)
    static let snackbarDark = UIColor(argb: 0xFF322F35)
}
