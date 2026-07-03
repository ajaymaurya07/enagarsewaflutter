import UIKit

// MARK: - PaymentOtpSheetViewController
// Mirrors Flutter's `_showOtpAndPaymentDialog` bottom sheet.

final class PaymentOtpSheetViewController: UIViewController, UITextFieldDelegate {

    private let maskedNumber: String
    var onVerify: ((String) -> Void)?

    private let otpField = ENSInputField(placeholder: "Enter OTP", icon: "lock.fill", keyboardType: .numberPad)
    private weak var errorLabel: UILabel?
    private weak var verifyBtn: UIButton?
    private weak var cancelBtn: UIButton?

    init(maskedNumber: String) {
        self.maskedNumber = maskedNumber
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildUI()
        otpField.textField.delegate = self
        otpField.textField.keyboardType = .numberPad
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        otpField.textField.becomeFirstResponder()
    }

    private func buildUI() {
        let handle = UIView()
        handle.backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        handle.layer.cornerRadius = 2
        handle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(handle)

        let titleL = UILabel()
        titleL.text = "Verification Required"
        titleL.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        titleL.textColor = .appCardText

        let subL = UILabel()
        subL.text = "Enter the OTP sent to \(maskedNumber) to proceed with payment."
        subL.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        subL.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        subL.numberOfLines = 0

        let errL = UILabel()
        errL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        errL.textColor = .systemRed; errL.numberOfLines = 0; errL.isHidden = true
        errorLabel = errL

        let otpLbl = UILabel.fieldLabel("Enter OTP")

        let btn = UIButton.primaryButton(title: "Verify & Proceed")
        btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        btn.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        verifyBtn = btn

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.titleLabel?.font = UIFont(name: "Poppins-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        cancel.setTitleColor(UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1), for: .normal)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancel.heightAnchor.constraint(equalToConstant: 44).isActive = true
        cancelBtn = cancel

        let stack = UIStackView(arrangedSubviews: [titleL, subL, errL, otpLbl, otpField, btn, cancel])
        stack.axis = .vertical; stack.spacing = 0
        stack.setCustomSpacing(4,  after: titleL)
        stack.setCustomSpacing(16, after: subL)
        stack.setCustomSpacing(8,  after: errL)
        stack.setCustomSpacing(8,  after: otpLbl)
        stack.setCustomSpacing(24, after: otpField)
        stack.setCustomSpacing(12, after: btn)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: 4),
            stack.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    @objc private func verifyTapped() {
        let otp = otpField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if otp.isEmpty { showError("Please enter OTP"); return }
        if otp.count < 4 { showError("Please enter valid OTP"); return }
        hideError()
        onVerify?(otp)
    }

    @objc private func cancelTapped() { dismiss(animated: true) }

    func showError(_ msg: String) { errorLabel?.text = msg; errorLabel?.isHidden = false }
    private func hideError() { errorLabel?.isHidden = true }

    func setVerifying(_ on: Bool) {
        verifyBtn?.setLoading(on)
        cancelBtn?.isEnabled = !on
    }
}

// MARK: - PaymentAmountSheetViewController
// Mirrors Flutter's `_showAmountSelectionSheet` — full vs. partial payment.

final class PaymentAmountSheetViewController: UIViewController {

    private let fullAmount: String
    var onProceed: ((String) -> Void)?

    private var isPartial = false

    private let fullRadio = UIImageView()
    private let partialRadio = UIImageView()
    private lazy var fullCard = makeOptionCard(
        radio: fullRadio, title: "Full Payment", subtitle: "Pay the complete due amount",
        trailingText: "₹ \(fullAmount)", onTap: { [weak self] in self?.selectFull() }
    )
    private lazy var partialCard = makeOptionCard(
        radio: partialRadio, title: "Partial Payment", subtitle: "Pay a custom amount (min ₹1)",
        trailingText: nil, onTap: { [weak self] in self?.selectPartial() }
    )

    private let amountField = ENSInputField(placeholder: "Enter amount", icon: "indianrupeesign.circle",
                                            keyboardType: .decimalPad)
    private weak var amountErrorLabel: UILabel?
    private weak var amountContainer: UIView?

    init(fullAmount: String) {
        self.fullAmount = fullAmount
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildUI()
        updateSelectionUI()
    }

    private func buildUI() {
        let handle = UIView()
        handle.backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        handle.layer.cornerRadius = 2
        handle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(handle)

        let titleL = UILabel()
        titleL.text = "Select Payment Amount"
        titleL.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        titleL.textColor = .appCardText

        let subL = UILabel()
        subL.text = "Pay the full amount or choose a partial payment."
        subL.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        subL.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        subL.numberOfLines = 0

        let errL = UILabel()
        errL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        errL.textColor = .systemRed; errL.numberOfLines = 0; errL.isHidden = true
        amountErrorLabel = errL

        let amountContainer = UIView()
        amountContainer.isHidden = true
        self.amountContainer = amountContainer
        let amountLbl = UILabel.fieldLabel("Enter Amount")
        let amountStack = UIStackView(arrangedSubviews: [amountLbl, amountField, errL])
        amountStack.axis = .vertical; amountStack.spacing = 8
        amountStack.translatesAutoresizingMaskIntoConstraints = false
        amountContainer.addSubview(amountStack)
        NSLayoutConstraint.activate([
            amountStack.topAnchor.constraint(equalTo: amountContainer.topAnchor),
            amountStack.leadingAnchor.constraint(equalTo: amountContainer.leadingAnchor),
            amountStack.trailingAnchor.constraint(equalTo: amountContainer.trailingAnchor),
            amountStack.bottomAnchor.constraint(equalTo: amountContainer.bottomAnchor),
        ])

        let proceedBtn = UIButton.primaryButton(title: "Proceed to Payment")
        proceedBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        proceedBtn.addTarget(self, action: #selector(proceedTapped), for: .touchUpInside)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.titleLabel?.font = UIFont(name: "Poppins-Medium", size: 14) ?? .systemFont(ofSize: 14, weight: .medium)
        cancelBtn.setTitleColor(UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1), for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            titleL, subL, fullCard, partialCard, amountContainer, proceedBtn, cancelBtn,
        ])
        stack.axis = .vertical; stack.spacing = 12
        stack.setCustomSpacing(4, after: titleL)
        stack.setCustomSpacing(20, after: subL)
        stack.setCustomSpacing(16, after: partialCard)
        stack.setCustomSpacing(24, after: amountContainer)
        stack.setCustomSpacing(12, after: proceedBtn)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: 4),
            stack.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func makeOptionCard(radio: UIImageView, title: String, subtitle: String,
                                trailingText: String?, onTap: @escaping () -> Void) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1

        radio.contentMode = .scaleAspectFit
        radio.tintColor = .appPrimary
        radio.widthAnchor.constraint(equalToConstant: 22).isActive = true
        radio.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let titleL = UILabel()
        titleL.text = title
        titleL.font = UIFont(name: "Poppins-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        titleL.textColor = .appCardText

        let subL = UILabel()
        subL.text = subtitle
        subL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        subL.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)

        let textStack = UIStackView(arrangedSubviews: [titleL, subL])
        textStack.axis = .vertical; textStack.spacing = 2

        var rowViews: [UIView] = [radio, textStack]
        if let trailingText {
            let amtL = UILabel()
            amtL.text = trailingText
            amtL.font = UIFont(name: "Poppins-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
            amtL.textColor = .appPrimary
            amtL.setContentHuggingPriority(.required, for: .horizontal)
            rowViews.append(amtL)
        }

        let row = UIStackView(arrangedSubviews: rowViews)
        row.axis = .horizontal; row.spacing = 12; row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        card.addGestureRecognizer(ClosureTapGesture(onTap))
        card.isUserInteractionEnabled = true
        return card
    }

    @objc private func selectFull()    { isPartial = false; updateSelectionUI() }
    @objc private func selectPartial() { isPartial = true;  updateSelectionUI() }

    private func updateSelectionUI() {
        let selectedBg = UIColor(red: 1, green: 0.957, blue: 0.898, alpha: 1)
        let idleBg = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
        let selectedBorder = UIColor.appPrimary
        let idleBorder = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)

        fullCard.backgroundColor = isPartial ? idleBg : selectedBg
        fullCard.layer.borderColor = (isPartial ? idleBorder : selectedBorder).cgColor
        fullCard.layer.borderWidth = isPartial ? 1 : 2
        fullRadio.image = UIImage(systemName: isPartial ? "circle" : "smallcircle.filled.circle.fill")

        partialCard.backgroundColor = isPartial ? selectedBg : idleBg
        partialCard.layer.borderColor = (isPartial ? selectedBorder : idleBorder).cgColor
        partialCard.layer.borderWidth = isPartial ? 2 : 1
        partialRadio.image = UIImage(systemName: isPartial ? "smallcircle.filled.circle.fill" : "circle")

        amountContainer?.isHidden = !isPartial
        if isPartial { amountField.textField.becomeFirstResponder() }
        amountErrorLabel?.isHidden = true
    }

    @objc private func proceedTapped() {
        let chosenAmount: String
        if isPartial {
            let input = amountField.textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard let parsed = Double(input), !input.isEmpty else {
                showAmountError("Please enter a valid amount"); return
            }
            guard parsed > 0 else { showAmountError("Amount must be greater than ₹0"); return }
            let full = Double(fullAmount) ?? 0
            guard parsed <= full || full == 0 else {
                showAmountError("Amount cannot exceed ₹\(fullAmount)"); return
            }
            chosenAmount = String(format: "%.2f", parsed)
        } else {
            chosenAmount = fullAmount
        }
        let handler = onProceed
        dismiss(animated: true) { handler?(chosenAmount) }
    }

    private func showAmountError(_ msg: String) {
        amountErrorLabel?.text = msg
        amountErrorLabel?.isHidden = false
    }

    @objc private func cancelTapped() { dismiss(animated: true) }
}

// MARK: - PaymentMethodSheetViewController
// Mirrors Flutter's `_showPaymentMethodSelection`. Flutter currently only exposes PayU (the SBI
// card is commented out pending backend readiness) — SBI is enabled here too since its WebView
// checkout is already fully wired and gives the flow a path that works end-to-end without a
// third-party SDK (see PaymentDetailsViewModel.createSBITransaction).

final class PaymentMethodSheetViewController: UIViewController {

    private let amount: String
    var onSelectPayU: ((String) -> Void)?
    var onSelectSBI: ((String) -> Void)?

    init(amount: String) {
        self.amount = amount
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        buildUI()
    }

    private func buildUI() {
        let handle = UIView()
        handle.backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        handle.layer.cornerRadius = 2
        handle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(handle)

        let titleL = UILabel()
        titleL.text = "Select Payment Gateway"
        titleL.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleL.textColor = .appCardText

        let subL = UILabel()
        subL.text = "Paying: ₹\(amount)"
        subL.font = UIFont(name: "Poppins-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        subL.textColor = .appPrimary

        let payuCard = makeCard(title: "Pay with PayU", subtitle: "Safe & Secure",
                                icon: "creditcard.fill") { [weak self] in
            guard let self else { return }
            let amount = self.amount
            self.dismiss(animated: true) { self.onSelectPayU?(amount) }
        }
        let sbiCard = makeCard(title: "Pay with SBI", subtitle: "Official SBI Gateway",
                               icon: "building.columns.fill") { [weak self] in
            guard let self else { return }
            let amount = self.amount
            self.dismiss(animated: true) { self.onSelectSBI?(amount) }
        }

        let stack = UIStackView(arrangedSubviews: [titleL, subL, payuCard, sbiCard])
        stack.axis = .vertical; stack.spacing = 16
        stack.setCustomSpacing(4, after: titleL)
        stack.setCustomSpacing(20, after: subL)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            handle.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: 4),
            stack.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func makeCard(title: String, subtitle: String, icon: String, onTap: @escaping () -> Void) -> UIView {
        let card = UIView()
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1).cgColor
        card.layer.cornerRadius = 12
        card.isUserInteractionEnabled = true

        let iconImg = UIImageView(image: UIImage(systemName: icon))
        iconImg.tintColor = .appPrimary; iconImg.contentMode = .scaleAspectFit
        iconImg.widthAnchor.constraint(equalToConstant: 28).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let titleL = UILabel()
        titleL.text = title
        titleL.font = UIFont(name: "Poppins-Bold", size: 15) ?? .boldSystemFont(ofSize: 15)
        titleL.textColor = .appCardText

        let subL = UILabel()
        subL.text = subtitle
        subL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        subL.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)

        let textStack = UIStackView(arrangedSubviews: [titleL, subL])
        textStack.axis = .vertical; textStack.spacing = 2

        let arrowImg = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrowImg.tintColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        arrowImg.contentMode = .scaleAspectFit
        arrowImg.widthAnchor.constraint(equalToConstant: 16).isActive = true

        let row = UIStackView(arrangedSubviews: [iconImg, textStack, arrowImg])
        row.axis = .horizontal; row.spacing = 16; row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        card.addGestureRecognizer(ClosureTapGesture(onTap))
        return card
    }
}
