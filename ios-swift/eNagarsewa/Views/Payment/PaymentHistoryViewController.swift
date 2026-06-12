import UIKit
import Combine

final class PaymentHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let viewModel: PaymentHistoryViewModel
    weak var coordinator: MainCoordinator?
    private var cancellables = Set<AnyCancellable>()

    private let tableView  = UITableView(frame: .zero, style: .plain)
    private let spinner    = UIActivityIndicatorView(style: .large)
    private let emptyView  = UIView()

    init(viewModel: PaymentHistoryViewModel, coordinator: MainCoordinator? = nil) {
        self.viewModel   = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Payment History"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        viewModel.onViewAppear()
    }

    private func setupLayout() {
        spinner.color = .appPrimary; spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        tableView.separatorStyle = .none
        tableView.backgroundColor = .appBackground
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView.register(TransactionCell.self, forCellReuseIdentifier: "TransactionCell")
        tableView.dataSource = self; tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        let icon = UIImageView(image: UIImage(systemName: "creditcard"))
        icon.tintColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 70).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 70).isActive = true
        let lbl = UILabel()
        lbl.text = "No payment history found"
        lbl.font = UIFont(name: "Poppins-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        lbl.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1); lbl.textAlignment = .center
        let emptyStack = UIStackView(arrangedSubviews: [icon, lbl])
        emptyStack.axis = .vertical; emptyStack.spacing = 16; emptyStack.alignment = .center
        emptyStack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.isHidden = true; emptyView.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(emptyStack)
        view.addSubview(emptyView)

        tableView.pinToEdges(of: view)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyStack.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            emptyStack.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor),
        ])
    }

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.spinner.startAnimating() : self?.spinner.stopAnimating()
        }.store(in: &cancellables)

        viewModel.$transactions.receive(on: DispatchQueue.main).sink { [weak self] txns in
            self?.emptyView.isHidden = !txns.isEmpty
            self?.tableView.reloadData()
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

    func tableView(_ tv: UITableView, heightForRowAt ip: IndexPath) -> CGFloat { UITableView.automaticDimension }
    func tableView(_ tv: UITableView, estimatedHeightForRowAt ip: IndexPath) -> CGFloat { 104 }
}

// MARK: - TransactionCell (Flutter card style)

final class TransactionCell: UITableViewCell {

    private let card        = UIView()
    private let iconCircle  = UIView()
    private let iconImage   = UIImageView()
    private let amountLabel = UILabel()
    private let badge       = UIView()
    private let badgeLabel  = UILabel()
    private let txnIdLabel  = UILabel()
    private let dateLabel   = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .none
        buildCard()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildCard() {
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.addCardShadow()
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        iconCircle.layer.cornerRadius = 22
        iconCircle.clipsToBounds = true
        iconCircle.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconCircle.heightAnchor.constraint(equalToConstant: 44).isActive = true
        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(iconImage)
        NSLayoutConstraint.activate([
            iconImage.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 24),
            iconImage.heightAnchor.constraint(equalToConstant: 24),
        ])

        amountLabel.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        amountLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        amountLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        badge.layer.cornerRadius = 6; badge.clipsToBounds = true
        badgeLabel.font = UIFont(name: "Poppins-Bold", size: 10) ?? .boldSystemFont(ofSize: 10)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: badge.topAnchor, constant: 4),
            badgeLabel.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -8),
            badgeLabel.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -4),
        ])

        let topRow = UIStackView(arrangedSubviews: [amountLabel, badge])
        topRow.axis = .horizontal; topRow.alignment = .center; topRow.distribution = .equalSpacing

        txnIdLabel.font = UIFont(name: "Poppins-SemiBold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold)
        txnIdLabel.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)

        dateLabel.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        dateLabel.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)

        let infoStack = UIStackView(arrangedSubviews: [topRow, txnIdLabel, dateLabel])
        infoStack.axis = .vertical; infoStack.spacing = 8
        infoStack.setCustomSpacing(4, after: txnIdLabel)

        let mainRow = UIStackView(arrangedSubviews: [iconCircle, infoStack])
        mainRow.axis = .horizontal; mainRow.spacing = 16; mainRow.alignment = .center
        mainRow.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(mainRow)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            mainRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            mainRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            mainRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            mainRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
    }

    func configure(with txn: TransactionData) {
        let status    = txn.transactionStatus?.lowercased() ?? ""
        let isSuccess = status == "success" || status == "captured"
        let isPending = status == "pending"

        let statusColor: UIColor
        let bgColor: UIColor
        let iconName: String

        if isSuccess {
            statusColor = .systemGreen
            bgColor     = UIColor(red: 0.910, green: 0.961, blue: 0.910, alpha: 1)
            iconName    = "checkmark.circle"
        } else if isPending {
            statusColor = UIColor(red: 0.902, green: 0.635, blue: 0.235, alpha: 1)
            bgColor     = UIColor(red: 1.0, green: 0.969, blue: 0.902, alpha: 1)
            iconName    = "clock"
        } else {
            statusColor = .systemRed
            bgColor     = UIColor(red: 1.0, green: 0.922, blue: 0.922, alpha: 1)
            iconName    = "xmark.circle"
        }

        iconCircle.backgroundColor = bgColor
        iconImage.image    = UIImage(systemName: iconName)
        iconImage.tintColor = statusColor

        amountLabel.text      = "₹ \(txn.paymentAmount ?? "0.0")"
        badgeLabel.text       = txn.transactionStatus ?? "Unknown"
        badgeLabel.textColor  = statusColor
        badge.backgroundColor = statusColor.withAlphaComponent(0.1)
        txnIdLabel.text       = "TXN ID: \(txn.txnId ?? "N/A")"
        dateLabel.text        = txn.dateTime ?? ""
    }
}
