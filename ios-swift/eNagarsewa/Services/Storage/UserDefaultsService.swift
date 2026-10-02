import Foundation

/// Plain (non-secret) preferences — the `shared_preferences` keys the Flutter app uses.
final class UserDefaultsService {

    static let shared = UserDefaultsService()
    private let defaults = UserDefaults.standard
    private init() {}

    enum Key: String {
        case emailId                  = "email_id"
        case userType                 = "user_type"
        case userId                   = "user_id"
        case isPropertyVerified       = "is_property_verified"
        case selectedUlbId            = "selected_ulb_id"
        case selectedPropertyTotalArv = "selected_property_total_arv"
    }

    func string(_ key: Key) -> String? { defaults.string(forKey: key.rawValue) }
    func set(_ value: String?, for key: Key) { defaults.set(value, forKey: key.rawValue) }
    func bool(_ key: Key) -> Bool { defaults.bool(forKey: key.rawValue) }
    func set(_ value: Bool, for key: Key) { defaults.set(value, forKey: key.rawValue) }
    func remove(_ key: Key) { defaults.removeObject(forKey: key.rawValue) }

    // MARK: - Tour guide "seen" flags (SharedPreferences `tour_*` bools)

    func hasTourBeenSeen(_ tour: TourKey) -> Bool { defaults.bool(forKey: tour.rawValue) }
    func markTourSeen(_ tour: TourKey) { defaults.set(true, forKey: tour.rawValue) }

    // MARK: - Arbitrary flags (e.g. per-day payment notification guard)

    func flag(_ key: String) -> Bool { defaults.bool(forKey: key) }
    func setFlag(_ key: String) { defaults.set(true, forKey: key) }
}

enum TourKey: String {
    case dashboard              = "tour_dashboard"
    case applyGrievance         = "tour_apply_grievance"
    case transactionHistory     = "tour_transaction_history"
    case propertyTax            = "tour_property_tax"
    case paymentDetails         = "tour_payment_details"
    case searchProperty         = "tour_search_property"
    case account                = "tour_account"
    case grievanceStatus        = "tour_grievance_status"
    case propertySelection      = "tour_property_selection"
    case trackGrievance         = "tour_track_grievance"
    case transactionDetails     = "tour_transaction_details"
}
