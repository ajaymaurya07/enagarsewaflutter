import UIKit

final class GrievanceStatusDetailsViewController: UIViewController {

    private let viewModel: GrievanceStatusDetailsViewModel

    init(viewModel: GrievanceStatusDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Grievance Details"
        view.backgroundColor = .appBackground

        let statusBadge = UILabel()
        statusBadge.text            = "  \(viewModel.status)  "
        statusBadge.font            = .boldSystemFont(ofSize: 14)
        statusBadge.textColor       = .white
        statusBadge.backgroundColor = viewModel.statusColor
        statusBadge.layer.cornerRadius = 8; statusBadge.clipsToBounds = true
        statusBadge.textAlignment   = .center
        statusBadge.translatesAutoresizingMaskIntoConstraints = false

        let rows: [(String, String)] = [
            ("Grievance No",    viewModel.grievanceNumber),
            ("Category",        viewModel.category),
            ("Sub-Category",    viewModel.subCategory),
            ("Registered On",   viewModel.registrationDate),
            ("Description",     viewModel.description),
            ("Assigned To",     viewModel.assignedTo),
            ("Department",      viewModel.department),
            ("Remarks",         viewModel.remarks),
            ("Owner",           viewModel.ownerName),
            ("Address",         viewModel.address),
        ]

        let rowStack = UIStackView()
        rowStack.axis = .vertical; rowStack.spacing = 0
        for (label, value) in rows { rowStack.addArrangedSubview(makeRow(label: label, value: value)) }

        let mainStack = UIStackView(arrangedSubviews: [statusBadge, rowStack])
        mainStack.axis = .vertical; mainStack.spacing = 20; mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); scroll.pinToEdges(of: view)
        scroll.addSubview(mainStack)
        NSLayoutConstraint.activate([
            statusBadge.heightAnchor.constraint(equalToConstant: 36),
            mainStack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            mainStack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40),
        ])
    }

    private func makeRow(label: String, value: String) -> UIView {
        let c = UIView()
        let lbl = UILabel(); lbl.text = label; lbl.font = .systemFont(ofSize: 13); lbl.textColor = .secondaryLabel; lbl.setContentHuggingPriority(.required, for: .horizontal)
        let val = UILabel(); val.text = value; val.font = .systemFont(ofSize: 14); val.numberOfLines = 0; val.textAlignment = .right
        let s = UIStackView(arrangedSubviews: [lbl, val]); s.distribution = .equalSpacing; s.spacing = 8; s.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(s); s.pinToEdges(of: c, insets: UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0))
        let sep = UIView(); sep.backgroundColor = .separator; sep.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(sep)
        NSLayoutConstraint.activate([sep.heightAnchor.constraint(equalToConstant: 0.5), sep.leadingAnchor.constraint(equalTo: c.leadingAnchor), sep.trailingAnchor.constraint(equalTo: c.trailingAnchor), sep.bottomAnchor.constraint(equalTo: c.bottomAnchor)])
        return c
    }
}
