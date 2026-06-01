import UIKit
import Combine

final class PaymentDetailsViewController: UIViewController {

    private let viewModel: PaymentDetailsViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: PaymentDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private lazy var payuButton  = UIButton.primaryButton(title: "Pay via PayU")
    private lazy var sbiButton: UIButton = {
        var cfg = UIButton.Configuration.bordered()
        cfg.title = "Pay via SBI"
        let b = UIButton(configuration: cfg)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payment Details"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
    }

    private func setupLayout() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        let bill = viewModel.billDetails
        let amountLabel = UILabel()
        amountLabel.text = "Net Payable: ₹\(bill.netPayable ?? "0")"
        amountLabel.font = .boldSystemFont(ofSize: 22)
        amountLabel.textAlignment = .center

        let billNoLabel = UILabel()
        billNoLabel.text = "Bill No: \(bill.billNo ?? "-")"
        billNoLabel.textColor = .secondaryLabel
        billNoLabel.textAlignment = .center

        let ownerLabel = UILabel()
        ownerLabel.text = viewModel.property.ownerName
        ownerLabel.textAlignment = .center

        payuButton.addTarget(self, action: #selector(payuTapped), for: .touchUpInside)
        sbiButton.addTarget(self, action: #selector(sbiTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            ownerLabel, billNoLabel, amountLabel,
            UIView(), payuButton, sbiButton, activityIndicator
        ])
        stack.axis = .vertical; stack.spacing = 16; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            payuButton.heightAnchor.constraint(equalToConstant: 50),
            sbiButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
            self?.payuButton.isEnabled = !l; self?.sbiButton.isEnabled = !l
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            if let msg { self?.showAlert(message: msg) }
        }.store(in: &cancellables)
    }

    @objc private func payuTapped() {
        let email = UserDefaultsService.shared.emailId ?? ""
        viewModel.initiatePayUPayment(email: email, phone: "")
    }

    @objc private func sbiTapped() {
        let email = UserDefaultsService.shared.emailId ?? ""
        viewModel.initiateSBIPayment(email: email, phone: "")
    }
}
