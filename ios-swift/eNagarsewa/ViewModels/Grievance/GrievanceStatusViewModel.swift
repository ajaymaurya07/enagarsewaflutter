import Foundation

@MainActor
final class GrievanceStatusViewModel: ObservableObject {

    @Published var grievances: [GrievanceData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let api      = APIService.shared
    private let defaults = UserDefaultsService.shared
    weak var coordinator: MainCoordinator?

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
    }

    func onViewAppear() {
        Task { await load() }
    }

    private func load() async {
        guard let email = defaults.emailId else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            grievances = try await api.fetchGrievanceDetails(emailId: email).data
        } catch { errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription }
    }

    func didSelect(_ grievance: GrievanceData) {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let r = try await api.fetchGrievanceStatus(grievanceNo: grievance.grievanceNo ?? "")
                if let data = r.data { coordinator?.showGrievanceStatusDetails(data) }
            } catch { errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription }
        }
    }
}
