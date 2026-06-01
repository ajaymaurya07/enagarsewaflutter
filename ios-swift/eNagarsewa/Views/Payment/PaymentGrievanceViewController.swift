import UIKit
import Combine

final class PaymentGrievanceViewController: UIViewController {

    private let viewModel: PaymentGrievanceViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: PaymentGrievanceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private lazy var descriptionField: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16); tv.layer.borderColor = UIColor.separator.cgColor
        tv.layer.borderWidth = 1; tv.layer.cornerRadius = 8
        tv.translatesAutoresizingMaskIntoConstraints = false; return tv
    }()
    private lazy var submitButton = UIButton.primaryButton(title: "Submit Grievance")
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payment Grievance"
        view.backgroundColor = .appBackground

        let txnLabel = UILabel()
        txnLabel.text = "Transaction: \(viewModel.txnId)"
        txnLabel.font = .systemFont(ofSize: 14); txnLabel.textColor = .secondaryLabel
        txnLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text = "Describe your issue:"; descLabel.font = .boldSystemFont(ofSize: 14)
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.hidesWhenStopped = true; activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [txnLabel, descLabel, descriptionField, submitButton, activityIndicator])
        stack.axis = .vertical; stack.spacing = 16; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            descriptionField.heightAnchor.constraint(equalToConstant: 120),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
            self?.submitButton.isEnabled = !l
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            if let msg { self?.showAlert(message: msg) }
        }.store(in: &cancellables)
    }

    @objc private func submitTapped() {
        viewModel.description = descriptionField.text
        viewModel.submit()
    }
}

// MARK: - ViewModel

@MainActor
final class PaymentGrievanceViewModel: ObservableObject {

    @Published var description: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    let txnId: String
    private let api = APIService.shared

    init(txnId: String) { self.txnId = txnId }

    func submit() {
        guard !description.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please describe the issue."; return
        }
        isLoading = true; errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let fields: [String: String] = [
                    "txnId": txnId,
                    "description": description,
                    "serviceCode": "PAYMENT_ISSUE",
                ]
                _ = try await api.saveGrievance(fields: fields, imageData: nil)
            } catch { errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription }
        }
    }
}
