import UIKit

/// `GoogleFonts.poppins(...)` — the bundled Poppins faces, falling back to the system font.
extension UIFont {

    enum PoppinsWeight {
        case regular, medium, semibold, bold, extraBold

        var faceName: String {
            switch self {
            case .regular:   return "Poppins-Regular"
            case .medium:    return "Poppins-Medium"
            case .semibold:  return "Poppins-SemiBold"
            case .bold:      return "Poppins-Bold"
            case .extraBold: return "Poppins-ExtraBold"
            }
        }

        var systemWeight: UIFont.Weight {
            switch self {
            case .regular:   return .regular
            case .medium:    return .medium
            case .semibold:  return .semibold
            case .bold:      return .bold
            case .extraBold: return .heavy
            }
        }
    }

    static func poppins(_ size: CGFloat, _ weight: PoppinsWeight = .regular) -> UIFont {
        UIFont(name: weight.faceName, size: size) ?? .systemFont(ofSize: size, weight: weight.systemWeight)
    }

    /// Kruti Dev 010 — used for Owner/Father name and address when the ULB language is Krutidev.
    static func krutidev(_ size: CGFloat) -> UIFont {
        UIFont(name: "KrutiDev010", size: size) ?? .systemFont(ofSize: size)
    }
}

/// Port of lib/utils/ulb_language_helper.dart.
enum UlbLanguageHelper {
    static func isKrutidevValue(_ language: String?) -> Bool {
        (language?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "") == "krutidev"
    }

    static var isKrutidev: Bool { isKrutidevValue(StorageService.languageCache) }

    /// Poppins, or Krutidev when the property's ULB language requires it.
    static func font(_ size: CGFloat, _ weight: UIFont.PoppinsWeight, krutidev: Bool) -> UIFont {
        krutidev ? .krutidev(size) : .poppins(size, weight)
    }
}
