import UIKit
import Combine

final class TransactionHistoryViewController: UIViewController {

    private let viewModel: TransactionHistoryViewModel
    weak var coordinator: MainCoordinator?
    private var cancellables = Set<AnyCancellable>()

    private let tableView   = UITableView(frame: .zero, style: .plain)
    private let spinner     = UIActivityIndicatorView(style: .large)
    private let errorView   = UIView()
    private let emptyView   = UIView()
    private weak var errorLabel: UILabel?
    private var didPresentTour = false

    init(viewModel: TransactionHistoryViewModel, coordinator: MainCoordinator) {
        self.viewModel   = viewModel
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transaction History"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        viewModel.onViewAppear()
    }

    // MARK: - Layout

    private func setupLayout() {
        spinner.color = .appPrimary
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        tableView.separatorStyle = .none
        tableView.backgroundColor = .appBackground
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView.register(TxnCardCell.self, forCellReuseIdentifier: "TxnCardCell")
        tableView.dataSource = self; tableView.delegate = self
        tableView.isHidden = true
        tableView.translatesAutoresizingMaskIntoConstraints = false
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refresh
        view.addSubview(tableView)

        buildErrorView()
        errorView.isHidden = true
        errorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorView)

        buildEmptyView()
        emptyView.isHidden = true
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            tableView.topAnchor.constraint(equalTo: safe.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorView.topAnchor.constraint(equalTo: safe.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyView.topAnchor.constraint(equalTo: safe.topAnchor),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildErrorView() {
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.circle"))
        icon.tintColor = .systemRed; icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 60).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let lbl = UILabel()
        lbl.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        lbl.textColor = .appCardText; lbl.textAlignment = .center; lbl.numberOfLines = 0
        errorLabel = lbl

        let retryBtn = UIButton.primaryButton(title: "Retry")
        retryBtn.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryBtn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        retryBtn.widthAnchor.constraint(equalToConstant: 160).isActive = true

        let stack = UIStackView(arrangedSubviews: [icon, lbl, retryBtn])
        stack.axis = .vertical; stack.spacing = 20; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -24),
        ])
    }

    private func buildEmptyView() {
        let icon = UIImageView(image: UIImage(systemName: "clock.arrow.circlepath"))
        icon.tintColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 80).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let lbl = UILabel()
        lbl.text = "No transactions found"
        lbl.font = UIFont(name: "Poppins-Medium", size: 16) ?? .systemFont(ofSize: 16, weight: .medium)
        lbl.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1); lbl.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, lbl])
        stack.axis = .vertical; stack.spacing = 16; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            guard let self else { return }
            if loading && self.viewModel.transactions.isEmpty {
                self.spinner.startAnimating()
                self.tableView.isHidden = true
                self.errorView.isHidden = true
                self.emptyView.isHidden = true
            } else if !loading {
                self.spinner.stopAnimating()
                self.tableView.refreshControl?.endRefreshing()
            }
        }.store(in: &cancellables)

        viewModel.$transactions.receive(on: DispatchQueue.main).sink { [weak self] txns in
            guard let self, !self.viewModel.isLoading else { return }
            self.spinner.stopAnimating()
            self.errorView.isHidden  = true
            let empty = txns.isEmpty
            self.emptyView.isHidden  = !empty
            self.tableView.isHidden  = empty
            self.tableView.reloadData()
            if !empty {
                DispatchQueue.main.async { self.presentTourIfNeeded() }
            }
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            guard let msg else { return }
            self?.spinner.stopAnimating()
            self?.tableView.isHidden  = true
            self?.emptyView.isHidden  = true
            self?.errorView.isHidden  = false
            self?.errorLabel?.text    = msg
        }.store(in: &cancellables)
    }

    @objc private func refreshPulled() { viewModel.onViewAppear() }
    @objc private func retryTapped()   { viewModel.onViewAppear() }

    // MARK: - Tour guide (first-run coach mark, see lib/tour_guides/transaction_history_tour.dart)

    private func presentTourIfNeeded() {
        guard !didPresentTour, !UserDefaultsService.shared.hasTourBeenSeen(.transactionHistory) else { return }
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? TxnCardCell else { return }
        didPresentTour = true

        let steps: [TourStep] = [
            TourStep(target: cell.cardView, icon: "doc.text",
                     title: "Transaction Card",
                     description: "This card shows your payment amount, transaction ID, date, and status. Tap it to open the full receipt details.",
                     edge: .bottom),
            TourStep(target: cell.badgeView, icon: "checkmark.seal",
                     title: "Payment Status",
                     description: "Use this badge to quickly check whether the transaction is successful, pending, or failed.",
                     edge: .bottom),
        ]

        TourCoachMarkView.present(steps: steps) {
            UserDefaultsService.shared.markTourSeen(.transactionHistory)
        }
    }
}

extension TransactionHistoryViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tv: UITableView, numberOfRowsInSection s: Int) -> Int {
        viewModel.transactions.count
    }

    func tableView(_ tv: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "TxnCardCell", for: ip) as! TxnCardCell
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

// MARK: - TxnCardCell  (matches Flutter's _buildTransactionCard)

final class TxnCardCell: UITableViewCell {

    private let card        = UIView()
    private let iconCircle  = UIView()
    private let iconImage   = UIImageView()
    private let amountLabel = UILabel()
    private let badge       = UIView()
    private let badgeLabel  = UILabel()
    private let txnIdLabel  = UILabel()
    private let dateLabel   = UILabel()

    /// Exposed for the first-run tour guide to spotlight this cell's card/badge.
    var cardView: UIView { card }
    var badgeView: UIView { badge }

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

        // Status icon circle
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

        // Amount
        amountLabel.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        amountLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        amountLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Status badge
        badge.layer.cornerRadius = 6
        badge.clipsToBounds = true
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
        let status = txn.transactionStatus?.lowercased() ?? ""
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

        amountLabel.text        = "₹ \(txn.paymentAmount ?? "0.0")"
        badgeLabel.text         = txn.transactionStatus ?? "Unknown"
        badgeLabel.textColor    = statusColor
        badge.backgroundColor   = statusColor.withAlphaComponent(0.1)

        txnIdLabel.text = "TXN ID: \(txn.txnId ?? "N/A")"
        dateLabel.text  = txn.dateTime ?? ""
    }
}
