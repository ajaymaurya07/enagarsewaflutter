import Foundation
import Combine

/// Global mutable app state — shared across coordinators and view models.
/// Replaces Flutter's shared_preferences keys that were read across multiple screens.
@MainActor
final class AppState: ObservableObject {

    static let shared = AppState()
    private init() {}

    // MARK: - Selected property (persisted across sessions)

    var selectedProperty: PropertyEntity? {
        didSet { persistSelectedProperty() }
    }

    // MARK: - ULB selection

    var selectedUlbId: String? {
        get { UserDefaultsService.shared.selectedUlbId }
        set { UserDefaultsService.shared.selectedUlbId = newValue }
    }

    var selectedPropertyTotalArv: String? {
        get { UserDefaultsService.shared.selectedPropertyTotalArv }
        set { UserDefaultsService.shared.selectedPropertyTotalArv = newValue }
    }

    // MARK: - Connectivity

    @Published var isConnected: Bool = true

    // MARK: - Persist selected property

    private func persistSelectedProperty() {
        guard let p = selectedProperty else { return }
        DatabaseService.shared.insertOrReplace(p)
        UserDefaultsService.shared.selectedUlbId = p.ulbId
        UserDefaultsService.shared.selectedPropertyTotalArv = p.arvValue
    }

    func restoreLastProperty(completion: @escaping (PropertyEntity?) -> Void) {
        DatabaseService.shared.fetchAll { entities in
            completion(entities.first)
        }
    }
}
