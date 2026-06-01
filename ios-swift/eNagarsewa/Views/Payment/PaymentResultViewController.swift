import UIKit
import Combine

final class PaymentResultViewController: UIViewController {

    private let viewModel: PaymentResultViewModel
    weak var coordinator: PaymentCoordinator?
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: PaymentResultViewModel, coordinator: PaymentCoordinator) {
        self.viewModel   = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private let iconView     = UIImageView()
    private let titleLabel   = UILabel()
    private let messageLabel = UILabel()
    private lazy var doneButton = UIButton.primaryButton(title: "Back to Home")
    private lazy var grievanceButton: UIButton = {
        var cfg = UIButton.Configuration.bordered()
        cfg.title = "Report Issue"
        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payment Status"
        navigationItem.hidesBackButton = true
        view.backgroundColor = .appBackground
        setupLayout()
        configureForStatus()
    }

    private func setupLayout() {
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .boldSystemFont(ofSize: 24); titleLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 16); messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0; messageLabel.textColor = .secondaryLabel

        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        grievanceButton.addTarget(self, action: #selector(grievanceTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel, doneButton, grievanceButton])
        stack.axis = .vertical; stack.spacing = 20; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 80),
            doneButton.heightAnchor.constraint(equalToConstant: 50),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    private func configureForStatus() {
        switch viewModel.status {
        case .success:
            iconView.image   = UIImage(systemName: "checkmark.circle.fill")
            iconView.tintColor = .appSuccess
            titleLabel.text   = "Payment Successful"
            messageLabel.text = "Transaction ID: \(viewModel.txnId)"
            grievanceButton.isHidden = true
        case .failure:
            iconView.image    = UIImage(systemName: "xmark.circle.fill")
            iconView.tintColor = .appError
            titleLabel.text   = "Payment Failed"
            messageLabel.text = "Your payment could not be processed. You can report this issue."
            grievanceButton.isHidden = false
        case .pending:
            iconView.image    = UIImage(systemName: "clock.fill")
            iconView.tintColor = .appWarning
            titleLabel.text   = "Payment Pending"
            messageLabel.text = "Your payment is being processed."
            grievanceButton.isHidden = false
        }
    }

    @objc private func doneTapped()      { coordinator?.dismiss() }
    @objc private func grievanceTapped() { coordinator?.showPaymentGrievance(txnId: viewModel.txnId) }
}

// MARK: - ViewModel

@MainActor
final class PaymentResultViewModel: ObservableObject {
    let status: PaymentStatus
    let txnId: String
    let gateway: PaymentGateway

    init(status: PaymentStatus, txnId: String, gateway: PaymentGateway) {
        self.status  = status
        self.txnId   = txnId
        self.gateway = gateway
    }
}
