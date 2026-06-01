import UIKit
import Combine

final class PaymentHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let viewModel: PaymentHistoryViewModel
    weak var coordinator: MainCoordinator?
    private var cancellables = Set<AnyCancellable>()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    init(viewModel: PaymentHistoryViewModel, coordinator: MainCoordinator) {
        self.viewModel   = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payment History"
        view.backgroundColor = .appBackground
        tableView.dataSource = self; tableView.delegate = self
        tableView.register(TransactionCell.self, forCellReuseIdentifier: "TransactionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(tableView); view.addSubview(activityIndicator)
        tableView.pinToEdges(of: view)
        activityIndicator.center(in: view)
        bindViewModel()
        viewModel.onViewAppear()
    }

    private func bindViewModel() {
        viewModel.$transactions.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.tableView.reloadData()
        }.store(in: &cancellables)

        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
        }.store(in: &cancellables)
    }

    func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int { viewModel.transactions.count }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "TransactionCell", for: ip) as! TransactionCell
        cell.configure(with: viewModel.transactions[ip.row])
        return cell
    }

    func tableView(_ tv: UITableView, didSelectRowAt ip: IndexPath) {
        tv.deselectRow(at: ip, animated: true)
        coordinator?.showTransactionDetails(viewModel.transactions[ip.row])
    }

    func tableView(_ tv: UITableView, heightForRowAt ip: IndexPath) -> CGFloat { 80 }
}

// MARK: - Shared TransactionCell

final class TransactionCell: UITableViewCell {

    private let amountLabel = UILabel()
    private let dateLabel   = UILabel()
    private let statusLabel = UILabel()
    private let txnIdLabel  = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        amountLabel.font = .boldSystemFont(ofSize: 16)
        dateLabel.font   = .systemFont(ofSize: 13); dateLabel.textColor = .secondaryLabel
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        txnIdLabel.font  = .systemFont(ofSize: 11); txnIdLabel.textColor = .tertiaryLabel

        let right = UIStackView(arrangedSubviews: [statusLabel, amountLabel])
        right.axis = .vertical; right.alignment = .trailing; right.spacing = 4

        let left  = UIStackView(arrangedSubviews: [dateLabel, txnIdLabel])
        left.axis = .vertical; left.spacing = 4

        let h = UIStackView(arrangedSubviews: [left, right])
        h.distribution = .equalSpacing; h.alignment = .center
        h.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(h)
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            h.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            h.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            h.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with txn: TransactionData) {
        amountLabel.text = "₹\(txn.paymentAmount ?? "0")"
        dateLabel.text   = txn.dateTime ?? "-"
        txnIdLabel.text  = "TXN: \(txn.txnId ?? "-")"
        let status = txn.transactionStatus?.lowercased() ?? ""
        statusLabel.text      = txn.transactionStatus ?? "-"
        statusLabel.textColor = status == "success" ? .appSuccess : status == "pending" ? .appWarning : .appError
    }
}
