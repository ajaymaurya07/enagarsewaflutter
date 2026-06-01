import UIKit
import Combine

final class TransactionDetailsViewController: UIViewController {

    private let viewModel: TransactionDetailsViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: TransactionDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transaction Details"
        view.backgroundColor = .appBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain, target: self, action: #selector(shareTapped)
        )
        setupLayout()
    }

    private func setupLayout() {
        let txn = viewModel.transaction
        let rows: [(String, String)] = [
            ("Transaction ID",  txn.txnId ?? "-"),
            ("Bill No",         txn.billNo ?? "-"),
            ("Property ID",     txn.propertyId ?? "-"),
            ("Amount",          "₹\(txn.paymentAmount ?? "0")"),
            ("Date & Time",     txn.dateTime ?? "-"),
            ("Payment Mode",    txn.paymentMode ?? "-"),
            ("Status",          txn.transactionStatus ?? "-"),
        ]

        let stack = UIStackView()
        stack.axis = .vertical; stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (label, value) in rows {
            let row = makeRow(label: label, value: value)
            stack.addArrangedSubview(row)
        }

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.pinToEdges(of: view)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])
    }

    private func makeRow(label: String, value: String) -> UIView {
        let container = UIView()
        let lbl = UILabel(); lbl.text = label; lbl.font = .systemFont(ofSize: 14); lbl.textColor = .secondaryLabel
        let val = UILabel(); val.text = value; val.font = .systemFont(ofSize: 14, weight: .medium); val.textAlignment = .right; val.numberOfLines = 0
        let s = UIStackView(arrangedSubviews: [lbl, val]); s.distribution = .equalSpacing
        s.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(s)
        s.pinToEdges(of: container, insets: UIEdgeInsets(top: 14, left: 0, bottom: 14, right: 0))
        let sep = UIView(); sep.backgroundColor = .separator; sep.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sep)
        NSLayoutConstraint.activate([sep.heightAnchor.constraint(equalToConstant: 0.5),
                                      sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                                      sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                                      sep.bottomAnchor.constraint(equalTo: container.bottomAnchor)])
        return container
    }

    @objc private func shareTapped() {
        viewModel.generateAndSharePdf(from: self)
    }
}
