import UIKit
import Combine

final class PropertyTaxViewController: UIViewController {

    private let viewModel: PropertyTaxViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: PropertyTaxViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private let scrollView  = UIScrollView()
    private let contentView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    // Bill detail rows
    private let billStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Property Tax"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        viewModel.onViewAppear()
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        view.addSubview(activityIndicator)
        scrollView.pinToEdges(of: view)
        activityIndicator.center(in: view)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        billStack.axis = .vertical; billStack.spacing = 8
        billStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(billStack)

        let payButton = UIButton.primaryButton(title: "Pay Now")
        let assessButton: UIButton = {
            var cfg = UIButton.Configuration.bordered()
            cfg.title = "Self Assessment"
            let b = UIButton(configuration: cfg)
            b.translatesAutoresizingMaskIntoConstraints = false
            return b
        }()
        payButton.addTarget(self, action: #selector(payTapped), for: .touchUpInside)
        assessButton.addTarget(self, action: #selector(assessTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [payButton, assessButton])
        buttonStack.axis = .horizontal; buttonStack.spacing = 12; buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            billStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            billStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            billStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            buttonStack.topAnchor.constraint(equalTo: billStack.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 50),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
        }.store(in: &cancellables)

        viewModel.$propertyDetails.receive(on: DispatchQueue.main).sink { [weak self] details in
            guard let bill = details?.billDetails else { return }
            self?.populateBillDetails(bill)
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            if let msg { self?.showAlert(message: msg) }
        }.store(in: &cancellables)
    }

    private func populateBillDetails(_ bill: BillDetails) {
        billStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let rows: [(String, String?)] = [
            ("Owner",         bill.ownerName),
            ("Bill No",       bill.billNo),
            ("Annual Value",  bill.totalArv),
            ("General Tax",   bill.generalTax),
            ("Water Tax",     bill.waterTax),
            ("Total Tax",     bill.totalTax),
            ("Discount",      bill.totalDiscount),
            ("Interest",      bill.totalInterest),
            ("Net Payable",   bill.netPayable),
        ]

        for (label, value) in rows {
            let row = makeBillRow(label: label, value: value ?? "-")
            billStack.addArrangedSubview(row)
        }
    }

    private func makeBillRow(label: String, value: String) -> UIView {
        let container = UIView()
        let lbl = UILabel(); lbl.text = label; lbl.font = .systemFont(ofSize: 14); lbl.textColor = .secondaryLabel
        let val = UILabel(); val.text = value; val.font = .systemFont(ofSize: 14, weight: .medium); val.textAlignment = .right
        let stack = UIStackView(arrangedSubviews: [lbl, val])
        stack.distribution = .equalSpacing; stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack); stack.pinToEdges(of: container, insets: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0))
        let sep = UIView(); sep.backgroundColor = .separator; sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)
        NSLayoutConstraint.activate([sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                                      sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                                      sep.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                                      sep.heightAnchor.constraint(equalToConstant: 0.5)])
        return container
    }

    @objc private func payTapped() {
        guard let details = viewModel.propertyDetails, let bill = details.billDetails else { return }
        // Navigate to payment — handled by main coordinator
    }

    @objc private func assessTapped() { viewModel.didTapSelfAssessment() }
}
