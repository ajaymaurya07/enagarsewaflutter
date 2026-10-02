import UIKit

/// Port of lib/transaction_history_screen.dart.
final class TransactionHistoryViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }

    private var transactions: [TransactionData] = []
    private var firstCard: UIView?
    private var firstBadge: UIView?
    private var queuedAutoTour = false
    private let refresh = UIRefreshControl()
    private let stateContainer = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "Transaction History",
                     rightItems: [helpItem { [weak self] in self?.startTour(showUnavailable: true) }])
        installScrollStack(insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), spacing: 16)
        refresh.tintColor = UIColor(argb: 0xFF0E3B90)
        refresh.addAction(UIAction { [weak self] _ in Task { await self?.fetch(showSpinner: false) } }, for: .valueChanged)
        scrollView.refreshControl = refresh
        view.addSubview(stateContainer)
        stateContainer.pinToSafeArea(of: view)
        Task { await fetch(showSpinner: true) }
    }

    private func showState(_ content: UIView?) {
        stateContainer.subviews.forEach { $0.removeFromSuperview() }
        stateContainer.isHidden = content == nil
        guard let content else { return }
        stateContainer.backgroundColor = screenBackground
        stateContainer.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.centerYAnchor.constraint(equalTo: stateContainer.centerYAnchor),
            content.leadingAnchor.constraint(equalTo: stateContainer.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: stateContainer.trailingAnchor, constant: -24),
        ])
    }

    private func fetch(showSpinner: Bool) async {
        if showSpinner {
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.color = UIColor(argb: 0xFF0E3B90)
            spinner.startAnimating()
            showState(centered(spinner))
        }
        defer { refresh.endRefreshing() }
        guard let email = StorageService.emailId, !email.isEmpty else {
            showError("Email not found. Please log in again.")
            return
        }
        do {
            let response = try await APIService.shared.getTransactionsByEmail(emailId: email)
            if response.status == true {
                transactions = response.data ?? []
                render()
            } else {
                showError(response.message ?? "Failed to load transactions")
            }
        } catch {
            showError(APIError.userMessage(error, fallback: "Unable to load transactions right now. Please try again."))
        }
    }

    private func showError(_ message: String) {
        let retry = PrimaryButton("Retry", color: UIColor(argb: 0xFF0E3B90), height: 40, radius: 20, fontSize: 14, weight: .medium)
        retry.contentEdgeInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        retry.onEvent { [weak self] in Task { await self?.fetch(showSpinner: true) } }
        let stack = UIStackView.v(0, alignment: .center, [
            UIImageView(symbol: "exclamationmark.circle", size: 56, color: .mRed),
            UILabel(message, font: .poppins(14), color: .black87, lines: 0, alignment: .center),
            retry,
        ])
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(24, after: stack.arrangedSubviews[1])
        showState(stack)
    }

    private func render() {
        contentStack.removeAllArranged()
        firstCard = nil
        firstBadge = nil
        guard !transactions.isEmpty else {
            let stack = UIStackView.v(16, alignment: .center, [
                UIImageView(symbol: "clock.arrow.circlepath", size: 72, color: .grey300),
                UILabel("No transactions found", font: .poppins(16, .medium), color: .grey600),
            ])
            showState(stack)
            return
        }
        showState(nil)
        for (i, txn) in transactions.enumerated() {
            contentStack.add(card(txn, first: i == 0))
        }
        if !queuedAutoTour {
            queuedAutoTour = true
            DispatchQueue.main.async { [weak self] in
                TourGuide.autoStartIfFirstVisit(.transactionHistory) { self?.startTour(showUnavailable: false) }
            }
        }
    }

    static func statusStyle(_ status: String) -> (color: UIColor, bg: UIColor, icon: String) {
        switch status {
        case "SUCCESS": return (.mGreen, UIColor(argb: 0xFFE8F5E9), "checkmark.circle")
        case "PENDING": return (UIColor(argb: 0xFFE6A23C), UIColor(argb: 0xFFFFF7E6), "clock")
        case "FAILED":  return (.mRed, UIColor(argb: 0xFFFFEBEE), "exclamationmark.circle")
        case "EXPIRED": return (UIColor(argb: 0xFF64748B), UIColor(argb: 0xFFF8FAFC), "timer")
        default:        return (UIColor(argb: 0xFF64748B), UIColor(argb: 0xFFF8FAFC), "questionmark.circle")
        }
    }

    private func card(_ txn: TransactionData, first: Bool) -> UIView {
        let status = txn.transactionStatus?.uppercased() ?? ""
        let style = Self.statusStyle(status)
        let card = CardView(radius: 16, shadowOpacity: 0.04, shadowBlur: 10, shadowY: 4)
        let iconCircle = iconTile(style.icon, color: style.color, background: style.bg, size: 44, iconSize: 22, radius: 22)

        let badgeView = UIView()
        badgeView.backgroundColor = style.color.withAlphaComponent(0.1)
        badgeView.layer.cornerRadius = 6
        let badgeLabel = UILabel(status.isEmpty ? "UNKNOWN" : status, font: .poppins(10, .bold), color: style.color)
        badgeView.addSubview(badgeLabel)
        badgeLabel.pinToEdges(of: badgeView, insets: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        badgeView.setContentHuggingPriority(.required, for: .horizontal)
        badgeView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let amount = UILabel("₹ \(txn.paymentAmount ?? "0.0")", font: .poppins(18, .bold), color: .appTextDark)
        amount.lineBreakMode = .byTruncatingTail
        let info = UIStackView.v(0, [
            UIStackView.h(8, [amount, FlexSpacer(), badgeView]),
            UILabel("TXN ID: \(txn.txnId ?? "N/A")", font: .poppins(13, .semibold), color: .appTextMid, lines: 0),
            UILabel(txn.dateTime ?? "", font: .poppins(12), color: .grey600),
        ])
        info.setCustomSpacing(8, after: info.arrangedSubviews[0])
        info.setCustomSpacing(4, after: info.arrangedSubviews[1])
        card.stack.add(UIStackView.h(16, alignment: .top, [iconCircle, info]))
        card.onTap { [weak self] in
            guard !TourCoachMarkView.isActive else { return }
            self?.push(TransactionDetailsViewController(transaction: txn))
        }
        if first {
            firstCard = card
            firstBadge = badgeView
        }
        return card
    }

    private func startTour(showUnavailable: Bool) {
        guard !TourCoachMarkView.isActive else { return }
        guard let firstCard, let firstBadge else {
            if showUnavailable { snack("Tour will be available once transaction records load.") }
            return
        }
        TourCoachMarkView.present(steps: [
            TourStep(target: firstCard, icon: "list.bullet.rectangle", title: "Transaction Card",
                     description: "This card shows your payment amount, transaction ID, date, and status. Tap it to open the full receipt details.",
                     shape: .roundedRect(radius: 16)),
            TourStep(target: firstBadge, icon: "checkmark.seal", title: "Payment Status",
                     description: "Use this badge to quickly check whether the transaction is successful, pending, or failed.",
                     shape: .roundedRect(radius: 14)),
        ], scrollContainer: scrollView)
    }
}
