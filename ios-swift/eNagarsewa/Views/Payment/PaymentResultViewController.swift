import UIKit

enum PaymentStatus { case success, failure, pending }

/// Port of lib/payment_result_screen.dart. Replaces the payment-details screen in the stack
/// (`pushReplacement`), so the bottom button pops back to the property list.
final class PaymentResultViewController: BaseViewController {

    override var hidesNavigationBar: Bool { true }
    override var screenBackground: UIColor { .appFieldFill }

    private let status: PaymentStatus
    private let txnId: String?
    private let amount: String?
    private let message: String?
    private let details: [(String, String)]
    private let isKrutidev: Bool
    private static let languageSensitive: Set<String> = ["Owner Name", "Father/Husband Name", "Address"]

    init(status: PaymentStatus, txnId: String? = nil, amount: String? = nil, message: String? = nil,
         details: [(String, String)] = [], isKrutidev: Bool = false) {
        self.status = status
        self.txnId = txnId
        self.amount = amount
        self.message = message
        self.details = details
        self.isKrutidev = isKrutidev
        super.init(nibName: nil, bundle: nil)
        interceptsBack = true
    }

    required init?(coder: NSCoder) { fatalError() }

    private var config: (icon: String, color: UIColor, bg: UIColor, title: String, message: String, button: String) {
        switch status {
        case .success:
            return ("checkmark", UIColor(argb: 0xFF16A34A), UIColor(argb: 0xFFECFDF3), "Payment Successful!",
                    "Your property tax payment has been processed successfully.", "Done")
        case .failure:
            return ("xmark", UIColor(argb: 0xFFDC2626), UIColor(argb: 0xFFFEF2F2), "Payment Failed",
                    "Your payment could not be processed. Please try again.", "Go Back")
        case .pending:
            return ("clock", UIColor(argb: 0xFFD97706), UIColor(argb: 0xFFFFFBEB), "Payment Pending",
                    "Your payment is being processed. Please check back later.", "Go Back")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let c = config

        let bottom = UIView()
        bottom.backgroundColor = .white
        bottom.addShadow(opacity: 0.06, blur: 10, offsetY: -4)
        let button = PrimaryButton(c.button, color: c.color, height: 54)
        button.onEvent { [weak self] in self?.navigationController?.popViewController(animated: true) }
        bottom.addSubview(button)
        view.addSubview(bottom)
        bottom.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottom.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottom.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            button.topAnchor.constraint(equalTo: bottom.topAnchor, constant: 12),
            button.leadingAnchor.constraint(equalTo: bottom.leadingAnchor, constant: 24),
            button.trailingAnchor.constraint(equalTo: bottom.trailingAnchor, constant: -24),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])

        installScrollStack(insets: UIEdgeInsets(top: 60, left: 24, bottom: 32, right: 24), above: bottom)
        contentStack.alignment = .center

        let outer = UIView()
        outer.backgroundColor = c.bg
        outer.layer.cornerRadius = 60
        outer.setSize(width: 120, height: 120)
        outer.layer.shadowColor = c.color.cgColor
        outer.layer.shadowOpacity = 0.25
        outer.layer.shadowRadius = 15
        outer.layer.shadowOffset = CGSize(width: 0, height: 10)
        let inner = iconTile(c.icon, color: .white, background: c.color, size: 80, iconSize: 40, radius: 40)
        outer.addSubview(inner)
        inner.center(in: outer)

        contentStack.add(outer)
        contentStack.addSpacer(28)
        contentStack.add(UILabel(c.title, font: .poppins(24, .bold), color: c.color, alignment: .center))
        contentStack.addSpacer(8)
        let msg = UILabel(message ?? c.message, font: .poppins(14), color: .grey600, lines: 0, alignment: .center)
        msg.setLineHeight(1.4)
        contentStack.add(msg.padded(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)))

        if let amount, !amount.isEmpty {
            contentStack.addSpacer(32)
            let card = CardView(radius: 16, padding: UIEdgeInsets(top: 20, left: 24, bottom: 20, right: 24),
                                spacing: 4, shadowOpacity: 0.04, shadowBlur: 16, shadowY: 6,
                                border: c.color.withAlphaComponent(0.2))
            card.stack.alignment = .center
            card.stack.add(UILabel(status == .success ? "Amount Paid" : "Amount", font: .poppins(13, .medium), color: .grey500),
                           UILabel("₹ \(amount)", font: .poppins(32, .extraBold), color: .appTextDark))
            contentStack.add(card)
        }

        var all: [(String, String)] = []
        if let txnId, !txnId.isEmpty { all.append(("Transaction ID", txnId)) }
        all += details
        if !all.isEmpty {
            contentStack.addSpacer(28)
            let card = CardView(radius: 16, padding: UIEdgeInsets(top: 20, left: 20, bottom: 8, right: 20),
                                shadowOpacity: 0.04, shadowBlur: 16, shadowY: 6)
            card.stack.add(UILabel("Transaction Details", font: .poppins(15, .bold), color: .appTextDark))
            card.stack.addSpacer(16)
            for (label, value) in all {
                let krutidev = isKrutidev && Self.languageSensitive.contains(label)
                let l = UILabel(label, font: .poppins(13, .medium), color: .grey600, lines: 0)
                let v = UILabel(value, font: UlbLanguageHelper.font(13, .semibold, krutidev: krutidev),
                                color: .appTextDark, lines: 0, alignment: .right)
                let row = UIStackView.h(8, alignment: .top, [l, v])
                l.widthAnchor.constraint(equalTo: v.widthAnchor, multiplier: 2.0 / 3.0).isActive = true
                card.stack.add(row)
                card.stack.addSpacer(12)
            }
            contentStack.add(card)
            card.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }
    }

    override func handleBack() {}
}
