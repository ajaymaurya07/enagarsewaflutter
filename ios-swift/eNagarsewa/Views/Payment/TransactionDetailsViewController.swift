import UIKit
import Combine

/// Full parity port of `lib/transaction_details_screen.dart`: the printable receipt card
/// (header/status/table/footer) plus Share Receipt / Download action buttons.
final class TransactionDetailsViewController: UIViewController {

    private let viewModel: TransactionDetailsViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: TransactionDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private let scrollView = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Receipt"
        view.backgroundColor = UIColor(red: 0.941, green: 0.949, blue: 0.961, alpha: 1)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .black
        // Help button is a visual placeholder only — the coach-mark tour system is a separate
        // workstream and intentionally not wired up here.
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.circle"), style: .plain, target: nil, action: nil
        )
        navigationItem.rightBarButtonItem?.tintColor = .appPrimary
        setupLayout()

        viewModel.$isBusy.receive(on: DispatchQueue.main).sink { [weak self] busy in
            self?.view.isUserInteractionEnabled = !busy
        }.store(in: &cancellables)
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.pinToEdges(of: view)

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        let receiptCard = buildReceiptCard()
        let actionsRow = buildActionsRow()

        let stack = UIStackView(arrangedSubviews: [receiptCard, actionsRow])
        stack.axis = .vertical
        stack.setCustomSpacing(24, after: receiptCard)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.topAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
        ])
    }

    // MARK: - Receipt card (matches Flutter's _buildReceiptCard)

    private func buildReceiptCard() -> UIView {
        // Outer view casts the shadow (must not clip, or the shadow itself gets clipped away);
        // the inner `card` clips its content to the rounded corners.
        let shadowContainer = UIView()
        shadowContainer.backgroundColor = .white
        shadowContainer.layer.cornerRadius = 8
        shadowContainer.addShadow(opacity: 0.08, radius: 12, offset: CGSize(width: 0, height: 4))

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 8
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            card.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor),
        ])

        let green = UIColor(red: 0.298, green: 0.686, blue: 0.314, alpha: 1) // #4CAF50

        // Header
        let header = UIView()
        header.backgroundColor = UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
        let headerBorder = UIView(); headerBorder.backgroundColor = green
        headerBorder.translatesAutoresizingMaskIntoConstraints = false
        let headerLabel = UILabel()
        headerLabel.text = viewModel.headerTitle
        headerLabel.textAlignment = .center
        headerLabel.numberOfLines = 0
        headerLabel.font = UIFont(name: "Poppins-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        headerLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(headerLabel); header.addSubview(headerBorder)
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 14),
            headerLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            headerBorder.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 14),
            headerBorder.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            headerBorder.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            headerBorder.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            headerBorder.heightAnchor.constraint(equalToConstant: 2),
        ])

        // Status message
        let statusView = UIView()
        statusView.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        let statusLabel = UILabel()
        statusLabel.text = viewModel.statusMessage
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.font = UIFont(name: "Poppins-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = viewModel.isSuccess ? green : .systemRed
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusView.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: statusView.topAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: statusView.bottomAnchor, constant: -10),
        ])

        let topDivider = UIView(); topDivider.backgroundColor = green
        topDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // Table rows
        let rowsStack = UIStackView(arrangedSubviews: viewModel.receiptRows.map { buildReceiptRow($0.label, $0.value) })
        rowsStack.axis = .vertical
        rowsStack.spacing = 0

        // Footer
        let footer = UIView()
        footer.backgroundColor = UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
        let footerBorder = UIView(); footerBorder.backgroundColor = green
        footerBorder.translatesAutoresizingMaskIntoConstraints = false
        let footerL1 = UILabel()
        footerL1.text = "This is Computer Generated Receipt. It does not require a signature."
        footerL1.textAlignment = .center; footerL1.numberOfLines = 0
        footerL1.font = UIFont(name: "Poppins-Regular", size: 11) ?? .systemFont(ofSize: 11)
        footerL1.textColor = UIColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1)
        let footerL2 = UILabel()
        footerL2.text = "This receipt is printed through EODB, e-nagarsewa portal GoUP."
        footerL2.textAlignment = .center; footerL2.numberOfLines = 0
        footerL2.font = .italicSystemFont(ofSize: 11)
        footerL2.textColor = UIColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1)
        let footerStack = UIStackView(arrangedSubviews: [footerBorder, footerL1, footerL2])
        footerStack.axis = .vertical; footerStack.spacing = 4
        footerStack.setCustomSpacing(16, after: footerBorder)
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerBorder.heightAnchor.constraint(equalToConstant: 2).isActive = true
        footer.addSubview(footerStack)
        NSLayoutConstraint.activate([
            footerStack.topAnchor.constraint(equalTo: footer.topAnchor),
            footerStack.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 20),
            footerStack.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -20),
            footerStack.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -16),
        ])

        let cardStack = UIStackView(arrangedSubviews: [header, statusView, topDivider, rowsStack, footer])
        cardStack.axis = .vertical
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return shadowContainer
    }

    private func buildReceiptRow(_ label: String, _ value: String) -> UIView {
        let container = UIView()
        let border = UIView()
        border.backgroundColor = UIColor(red: 0.878, green: 0.878, blue: 0.878, alpha: 1)
        border.translatesAutoresizingMaskIntoConstraints = false

        let labelContainer = UIView()
        labelContainer.backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        let labelRightBorder = UIView()
        labelRightBorder.backgroundColor = UIColor(red: 0.878, green: 0.878, blue: 0.878, alpha: 1)
        labelRightBorder.translatesAutoresizingMaskIntoConstraints = false

        let labelL = UILabel()
        labelL.text = label
        labelL.numberOfLines = 0
        labelL.font = UIFont(name: "Poppins-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        labelL.textColor = UIColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
        labelL.translatesAutoresizingMaskIntoConstraints = false

        let valueL = UILabel()
        valueL.text = value
        valueL.numberOfLines = 0
        valueL.font = UIFont(name: "Poppins-SemiBold", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold)
        valueL.textColor = UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1)
        valueL.translatesAutoresizingMaskIntoConstraints = false

        labelContainer.addSubview(labelL)
        labelContainer.addSubview(labelRightBorder)
        container.addSubview(labelContainer)
        container.addSubview(valueL)
        container.addSubview(border)

        NSLayoutConstraint.activate([
            labelContainer.topAnchor.constraint(equalTo: container.topAnchor),
            labelContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            labelContainer.widthAnchor.constraint(equalToConstant: 150),

            labelL.topAnchor.constraint(equalTo: labelContainer.topAnchor, constant: 10),
            labelL.leadingAnchor.constraint(equalTo: labelContainer.leadingAnchor, constant: 12),
            labelL.trailingAnchor.constraint(equalTo: labelContainer.trailingAnchor, constant: -12),
            labelL.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor, constant: -10),

            labelRightBorder.topAnchor.constraint(equalTo: labelContainer.topAnchor),
            labelRightBorder.bottomAnchor.constraint(equalTo: labelContainer.bottomAnchor),
            labelRightBorder.trailingAnchor.constraint(equalTo: labelContainer.trailingAnchor),
            labelRightBorder.widthAnchor.constraint(equalToConstant: 0.5),

            valueL.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            valueL.leadingAnchor.constraint(equalTo: labelContainer.trailingAnchor, constant: 12),
            valueL.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            valueL.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            border.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 0.5),
        ])
        return container
    }

    // MARK: - Action buttons (matches Flutter's Share Receipt / Download row)

    private func buildActionsRow() -> UIView {
        let blue = UIColor(red: 0.055, green: 0.231, blue: 0.565, alpha: 1) // #0E3B90

        let shareBtn = makeActionButton(title: "Share Receipt", icon: "square.and.arrow.up",
                                        filled: true, tint: blue)
        shareBtn.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        let downloadBtn = makeActionButton(title: "Download", icon: "arrow.down.circle",
                                           filled: false, tint: blue)
        downloadBtn.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [shareBtn, downloadBtn])
        row.axis = .horizontal; row.spacing = 16; row.distribution = .fillEqually
        return row
    }

    private func makeActionButton(title: String, icon: String, filled: Bool, tint: UIColor) -> UIButton {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        config.baseBackgroundColor = filled ? tint : .white
        config.baseForegroundColor = filled ? .white : tint
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.cornerStyle = .large
        var attributedTitle = AttributedString(title)
        attributedTitle.font = UIFont(name: "Poppins-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        config.attributedTitle = attributedTitle
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)
        let btn = UIButton(configuration: config)
        btn.layer.cornerRadius = 16
        if !filled {
            btn.layer.borderWidth = 1.5
            btn.layer.borderColor = tint.cgColor
        } else {
            btn.addShadow(opacity: 0.2, radius: 6, offset: CGSize(width: 0, height: 3))
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    // MARK: - Actions

    @objc private func closeTapped() { navigationController?.popViewController(animated: true) }

    @objc private func shareTapped() {
        guard let url = viewModel.writePdfToTempFile() else {
            ENSSnackbar.show(in: view, message: "Unable to share receipt right now. Please try again.", isError: true)
            return
        }
        let av = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        av.popoverPresentationController?.sourceView = view
        av.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url) }
        present(av, animated: true)
    }

    @objc private func downloadTapped() {
        let data = viewModel.buildPdfData()
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Receipt_\(viewModel.transaction.txnId ?? "payment")"

        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printingItem = data
        printController.present(animated: true) { [weak self] _, completed, error in
            guard let self, !completed, error != nil else { return }
            ENSSnackbar.show(in: self.view, message: "Unable to download receipt right now. Please try again.", isError: true)
        }
    }
}
