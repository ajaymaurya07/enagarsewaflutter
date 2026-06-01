import Foundation

@MainActor
final class TrackGrievanceViewModel: ObservableObject {

    @Published var grievanceNumber: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let api = APIService.shared
    weak var coordinator: MainCoordinator?

    init(coordinator: MainCoordinator) {
        self.coordinator = coordinator
    }

    func track() {
        guard !grievanceNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a grievance number."; return
        }
        isLoading = true; errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let r = try await api.fetchGrievanceStatus(grievanceNo: grievanceNumber)
                if let data = r.data {
                    coordinator?.showGrievanceStatusDetails(data)
                } else {
                    errorMessage = "No grievance found with that number."
                }
            } catch { errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription }
        }
    }
}
