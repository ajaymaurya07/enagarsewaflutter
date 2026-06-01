import Foundation

@MainActor
final class TransactionHistoryViewModel: ObservableObject {

    @Published var transactions: [TransactionData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let api      = APIService.shared
    private let defaults = UserDefaultsService.shared

    func onViewAppear() {
        Task { await load() }
    }

    private func load() async {
        guard let email = defaults.emailId else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            transactions = try await api.getTransactionsByEmail(emailId: email).data
        } catch { errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription }
    }
}
