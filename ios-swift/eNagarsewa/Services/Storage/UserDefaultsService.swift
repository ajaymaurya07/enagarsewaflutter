import Foundation

/// Typed wrapper over UserDefaults — replacement for shared_preferences plaintext keys.
final class UserDefaultsService {

    static let shared = UserDefaultsService()
    private let defaults = UserDefaults.standard
    private init() {}

    // MARK: - User session

    var emailId: String? {
        get { defaults.string(forKey: DefaultsKey.emailId.rawValue) }
        set { defaults.set(newValue, forKey: DefaultsKey.emailId.rawValue) }
    }

    var userType: String? {
        get { defaults.string(forKey: DefaultsKey.userType.rawValue) }
        set { defaults.set(newValue, forKey: DefaultsKey.userType.rawValue) }
    }

    var isPropertyVerified: Bool {
        get { defaults.bool(forKey: DefaultsKey.isPropertyVerified.rawValue) }
        set { defaults.set(newValue, forKey: DefaultsKey.isPropertyVerified.rawValue) }
    }

    var selectedUlbId: String? {
        get { defaults.string(forKey: DefaultsKey.selectedUlbId.rawValue) }
        set { defaults.set(newValue, forKey: DefaultsKey.selectedUlbId.rawValue) }
    }

    var selectedPropertyTotalArv: String? {
        get { defaults.string(forKey: DefaultsKey.selectedPropertyTotalArv.rawValue) }
        set { defaults.set(newValue, forKey: DefaultsKey.selectedPropertyTotalArv.rawValue) }
    }

    // MARK: - Tour guide seen flags

    func hasTourBeenSeen(_ tour: TourKey) -> Bool {
        defaults.bool(forKey: tour.rawValue)
    }

    func markTourSeen(_ tour: TourKey) {
        defaults.set(true, forKey: tour.rawValue)
    }

    // MARK: - Clear

    func clearSession() {
        [DefaultsKey.emailId, .userType, .isPropertyVerified,
         .selectedUlbId, .selectedPropertyTotalArv].forEach {
            defaults.removeObject(forKey: $0.rawValue)
        }
    }
}

// MARK: - Keys

private enum DefaultsKey: String {
    case emailId                    = "email_id"
    case userType                   = "user_type"
    case isPropertyVerified         = "is_property_verified"
    case selectedUlbId              = "selected_ulb_id"
    case selectedPropertyTotalArv   = "selected_property_total_arv"
}

enum TourKey: String {
    case dashboard          = "tour_dashboard"
    case applyGrievance     = "tour_apply_grievance"
    case transactionHistory = "tour_transaction_history"
    case propertyTax        = "tour_property_tax"
    case paymentHistory     = "tour_payment_history"
    case searchProperty     = "tour_search_property"
}
