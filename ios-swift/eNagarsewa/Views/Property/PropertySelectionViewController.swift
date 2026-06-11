import UIKit
import Combine

// MARK: - PropertySelectionViewController

final class PropertySelectionViewController: UIViewController {

    private let viewModel: PropertySelectionViewModel
    private var cancellables = Set<AnyCancellable>()

    // Loading overlay (matches Flutter's Stack + Container(color: Colors.black26))
    private let loadingOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        return v
    }()

    init(viewModel: PropertySelectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        bindViewModel()
    }

    private func setupLayout() {
        // Nav bar
        let navRow = makeNavBar()

        // List
        if viewModel.properties.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No properties found."
            emptyLabel.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
            emptyLabel.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
            emptyLabel.textAlignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(navRow)
            view.addSubview(emptyLabel)
            NSLayoutConstraint.activate([
                navRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                navRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                navRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                navRow.heightAnchor.constraint(equalToConstant: 52),
                emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        } else {
            let scroll = UIScrollView()
            let content = UIView()
            scroll.translatesAutoresizingMaskIntoConstraints = false
            content.translatesAutoresizingMaskIntoConstraints = false

            var cardViews: [UIView] = []
            for (i, property) in viewModel.properties.enumerated() {
                cardViews.append(makePropertyCard(property, index: i))
            }

            let cardsStack = UIStackView(arrangedSubviews: cardViews)
            cardsStack.axis = .vertical
            cardsStack.spacing = 16
            cardsStack.translatesAutoresizingMaskIntoConstraints = false

            scroll.addSubview(content)
            content.addSubview(cardsStack)

            view.addSubview(navRow)
            view.addSubview(scroll)

            NSLayoutConstraint.activate([
                navRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                navRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
                navRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                navRow.heightAnchor.constraint(equalToConstant: 52),
                scroll.topAnchor.constraint(equalTo: navRow.bottomAnchor),
                scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                content.topAnchor.constraint(equalTo: scroll.topAnchor),
                content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
                content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
                content.widthAnchor.constraint(equalTo: scroll.widthAnchor),
                cardsStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
                cardsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
                cardsStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
                cardsStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            ])
        }

        // Overlay (on top of everything)
        view.addSubview(loadingOverlay)
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeNavBar() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let backBtn = UIButton(type: .system)
        let chevImg = UIImage(systemName: "chevron.backward")
        backBtn.setImage(chevImg, for: .normal)
        backBtn.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        backBtn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backBtn.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Select Property"
        titleLabel.font = UIFont(name: "Poppins-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let helpBtn = UIButton(type: .system)
        helpBtn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        helpBtn.tintColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        helpBtn.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(backBtn)
        container.addSubview(titleLabel)
        container.addSubview(helpBtn)
        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 36),
            backBtn.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: backBtn.trailingAnchor, constant: 4),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            helpBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            helpBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            helpBtn.widthAnchor.constraint(equalToConstant: 40),
            helpBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
        return container
    }

    private func makePropertyCard(_ property: PropertyData, index: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius = 8
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.translatesAutoresizingMaskIntoConstraints = false

        // Header: PID + Select button
        let pidLabel = UILabel()
        pidLabel.text = "PID: \(property.propertyId)"
        pidLabel.font = UIFont(name: "Poppins-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        pidLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        pidLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let selectBtn = UIButton(type: .custom)
        selectBtn.setTitle("Select", for: .normal)
        selectBtn.titleLabel?.font = UIFont(name: "Poppins-SemiBold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold)
        selectBtn.backgroundColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1)
        selectBtn.setTitleColor(.white, for: .normal)
        selectBtn.layer.cornerRadius = 10
        selectBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        selectBtn.tag = index
        selectBtn.addTarget(self, action: #selector(selectTapped(_:)), for: .touchUpInside)
        selectBtn.translatesAutoresizingMaskIntoConstraints = false
        selectBtn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        selectBtn.setContentCompressionResistancePriority(.required, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [pidLabel, selectBtn])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 8

        // Divider
        let divider = UIView()
        divider.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // Detail rows
        let detailsStack = UIStackView(arrangedSubviews: [
            makeDetailRow(label: "Owner Name", value: property.ownerName),
            makeDetailRow(label: "Father/Husband", value: property.fatherHusbandName),
            makeDetailRow(label: "House No", value: property.houseNo),
            makeDetailRow(label: "Address", value: property.address),
        ])
        detailsStack.axis = .vertical
        detailsStack.spacing = 8

        let cardStack = UIStackView(arrangedSubviews: [headerRow, divider, detailsStack])
        cardStack.axis = .vertical
        cardStack.spacing = 0
        cardStack.setCustomSpacing(12, after: headerRow)
        cardStack.setCustomSpacing(12, after: divider)
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeDetailRow(label: String, value: String?) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .top
        row.spacing = 0

        let keyLabel = UILabel()
        keyLabel.text = "\(label): "
        keyLabel.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        keyLabel.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
        keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        keyLabel.setContentHuggingPriority(.required, for: .horizontal)

        let valLabel = UILabel()
        valLabel.text = value ?? "N/A"
        valLabel.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        valLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        valLabel.numberOfLines = 0

        row.addArrangedSubview(keyLabel)
        row.addArrangedSubview(valLabel)
        return row
    }

    // MARK: - Bindings

    private func bindViewModel() {
        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] loading in
            self?.loadingOverlay.isHidden = !loading
        }.store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func selectTapped(_ sender: UIButton) {
        let property = viewModel.properties[sender.tag]
        viewModel.handlePropertySelection(property: property, from: self)
    }

    // MARK: - OTP Sheet

    func showOtpSheet(mobileNo: String, propertyId: String, property: PropertyData, details: PropertyDetailsData?) {
        let sheet = OtpVerifySheetViewController(
            mobileNo: mobileNo,
            propertyId: propertyId,
            property: property,
            details: details,
            viewModel: viewModel
        )
        sheet.modalPresentationStyle = .pageSheet
        sheet.isModalInPresentation = true
        if let s = sheet.sheetPresentationController {
            s.detents = [.medium(), .large()]
            s.prefersGrabberVisible = true
            s.preferredCornerRadius = 24
        }
        present(sheet, animated: true)
    }

    func showSnackBar(_ message: String, isError: Bool = true) {
        ENSSnackbar.show(in: view, message: message, isError: isError)
    }
}

// MARK: - OtpVerifySheetViewController

final class OtpVerifySheetViewController: UIViewController, UITextFieldDelegate {

    private let mobileNo: String
    private let propertyId: String
    private let property: PropertyData
    private let details: PropertyDetailsData?
    private let viewModel: PropertySelectionViewModel
    private var isVerifying = false

    private let otpField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        tf.defaultTextAttributes[.kern] = 4
        tf.backgroundColor = UIColor(red: 0.973, green: 0.976, blue: 0.984, alpha: 1)
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1).cgColor
        tf.textAlignment = .left
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.leftViewMode = .always
        tf.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return tf
    }()

    private let errorBox: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 1.0, green: 0.94, blue: 0.94, alpha: 1)
        v.layer.cornerRadius = 10
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(red: 0.87, green: 0.63, blue: 0.63, alpha: 1).cgColor
        v.isHidden = true
        return v
    }()
    private let errorLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        l.textColor = UIColor(red: 0.72, green: 0.12, blue: 0.12, alpha: 1)
        l.numberOfLines = 0
        return l
    }()

    private lazy var verifyButton = UIButton.primaryButton(title: "Verify OTP")
    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.titleLabel?.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        b.setTitleColor(UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1), for: .normal)
        return b
    }()

    init(mobileNo: String, propertyId: String, property: PropertyData, details: PropertyDetailsData?, viewModel: PropertySelectionViewModel) {
        self.mobileNo = mobileNo
        self.propertyId = propertyId
        self.property = property
        self.details = details
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        otpField.delegate = self
        verifyButton.addTarget(self, action: #selector(verifyTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        // Subtitle
        let last4 = mobileNo.count > 4 ? String(mobileNo.suffix(4)) : mobileNo
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Enter the code sent to your mobile number ending in \(last4)"
        subtitleLabel.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        subtitleLabel.textColor = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        subtitleLabel.numberOfLines = 0

        let titleLabel = UILabel()
        titleLabel.text = "Verify OTP"
        titleLabel.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        titleLabel.textColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)

        // Error box inner
        let errorIcon = UIImageView(image: UIImage(systemName: "exclamationmark.circle"))
        errorIcon.tintColor = UIColor(red: 0.72, green: 0.12, blue: 0.12, alpha: 1)
        errorIcon.contentMode = .scaleAspectFit
        errorIcon.translatesAutoresizingMaskIntoConstraints = false
        errorIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        errorIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        let errorRow = UIStackView(arrangedSubviews: [errorIcon, errorLabel])
        errorRow.axis = .horizontal
        errorRow.spacing = 8
        errorRow.alignment = .top
        errorRow.translatesAutoresizingMaskIntoConstraints = false
        errorBox.addSubview(errorRow)
        NSLayoutConstraint.activate([
            errorRow.topAnchor.constraint(equalTo: errorBox.topAnchor, constant: 10),
            errorRow.leadingAnchor.constraint(equalTo: errorBox.leadingAnchor, constant: 12),
            errorRow.trailingAnchor.constraint(equalTo: errorBox.trailingAnchor, constant: -12),
            errorRow.bottomAnchor.constraint(equalTo: errorBox.bottomAnchor, constant: -10),
        ])

        let otpLabel = UILabel()
        otpLabel.text = "Enter OTP"
        otpLabel.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        otpLabel.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)

        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, errorBox, otpLabel, otpField, verifyButton, cancelButton
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(4, after: titleLabel)
        stack.setCustomSpacing(16, after: subtitleLabel)
        stack.setCustomSpacing(16, after: errorBox)
        stack.setCustomSpacing(8, after: otpLabel)
        stack.setCustomSpacing(24, after: otpField)
        stack.setCustomSpacing(12, after: verifyButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            verifyButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func showError(_ msg: String) {
        errorLabel.text = msg
        errorBox.isHidden = false
    }

    private func hideError() {
        errorBox.isHidden = true
    }

    @objc private func verifyTapped() {
        let otp = otpField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if otp.isEmpty { showError("Please enter OTP"); return }
        if otp.count < 4 { showError("Please enter valid OTP"); return }

        hideError()
        isVerifying = true
        verifyButton.setLoading(true)
        cancelButton.isEnabled = false

        Task {
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.isVerifying = false
                    self?.verifyButton.setLoading(false)
                    self?.cancelButton.isEnabled = true
                }
            }
            do {
                let res = try await APIService.shared.verifyOtp(VerifyOtpRequest(phoneNumber: mobileNo, otp: otp))
                if res.success {
                    let userId = res.userId.map { "\($0)" } ?? "0"
                    let ulbId = AppState.shared.selectedUlbId ?? ""
                    let totalArv = property.totalArv ?? "0.0"
                    AppState.shared.selectedPropertyTotalArv = totalArv

                    let entity = PropertyEntity(
                        propertyId: propertyId,
                        ownerName: details?.ownerDetails?.ownerName ?? "N/A",
                        ward: details?.propertyDetailsInfo?.wardName ?? "N/A",
                        mohalla: details?.propertyDetailsInfo?.mohallaName ?? "N/A",
                        phoneNumber: mobileNo,
                        email: UserDefaultsService.shared.emailId ?? "",
                        userType: UserDefaultsService.shared.userType ?? "",
                        ulbId: ulbId,
                        arvValue: totalArv,
                        userId: userId,
                        fatherName: property.fatherHusbandName ?? "N/A",
                        address: property.address
                    )
                    AppState.shared.selectedProperty = entity
                    UserDefaultsService.shared.isPropertyVerified = true

                    await MainActor.run { [weak self] in
                        self?.dismiss(animated: true) {
                            self?.viewModel.coordinator?.propertySelected()
                        }
                    }
                } else {
                    await MainActor.run { [weak self] in
                        self?.showError(res.message.isEmpty ? "Invalid OTP" : res.message)
                    }
                }
            } catch {
                let msg = (error as? NetworkError)?.errorDescription ?? "Unable to verify OTP right now. Please try again."
                await MainActor.run { [weak self] in self?.showError(msg) }
            }
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor(red: 0.902, green: 0.459, blue: 0.078, alpha: 1).cgColor
        textField.layer.borderWidth = 1.5
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1).cgColor
        textField.layer.borderWidth = 1
    }
}

// MARK: - PropertySelectionViewModel

@MainActor
final class PropertySelectionViewModel: ObservableObject {

    let properties: [PropertyData]
    weak var coordinator: PropertyCoordinator?

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    init(properties: [PropertyData], coordinator: PropertyCoordinator) {
        self.properties = properties
        self.coordinator = coordinator
    }

    func handlePropertySelection(property: PropertyData, from vc: PropertySelectionViewController) {
        guard !property.propertyId.isEmpty else { return }
        isLoading = true

        let ulbId = AppState.shared.selectedUlbId ?? ""
        Task {
            do {
                // 1. Get property details (for mobileNo, ward, mohalla)
                let detailsRes = try await api.fetchPropertyDetails(
                    PropertyDetailsRequest(propertyId: property.propertyId, ulbId: ulbId)
                )
                let details = detailsRes.data
                guard let mobileNo = details?.ownerDetails?.mobileNo, !mobileNo.isEmpty else {
                    isLoading = false
                    vc.showSnackBar("Mobile number not found for this property")
                    return
                }

                // 2. Send OTP
                let otpRes = try await api.sendOtp(phoneNumber: mobileNo, propertyId: property.propertyId)
                isLoading = false

                if otpRes.success {
                    vc.showOtpSheet(mobileNo: mobileNo, propertyId: property.propertyId,
                                    property: property, details: details)
                } else {
                    vc.showSnackBar(otpRes.message.isEmpty ? "Failed to send OTP" : otpRes.message)
                }
            } catch {
                isLoading = false
                let msg = (error as? NetworkError)?.errorDescription ?? "Unable to send OTP right now. Please try again."
                vc.showSnackBar(msg)
            }
        }
    }
}
