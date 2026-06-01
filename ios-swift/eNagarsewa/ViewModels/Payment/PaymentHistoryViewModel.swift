import Foundation

@MainActor
final class PaymentHistoryViewModel: ObservableObject {

    @Published var transactions: [TransactionData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let api      = APIService.shared
    private let defaults = UserDefaultsService.shared

    func onViewAppear() {
        Task { await loadTransactions() }
    }

    func loadTransactions() async {
        guard let email = defaults.emailId else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let r = try await api.getTransactionsByEmail(emailId: email)
            transactions = r.data
        } catch { errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription }
    }
}
