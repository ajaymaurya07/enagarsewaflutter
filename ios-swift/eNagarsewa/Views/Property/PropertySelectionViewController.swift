import UIKit

/// Port of lib/property_selection_screen.dart.
final class PropertySelectionViewController: BaseViewController {

    override var hidesNavigationBar: Bool { true }

    private let properties: [PropertyData]
    private var selected: PropertyData?
    private var details: PropertyDetailsData?
    private var headerView: UIView!
    private var firstCard: UIView?
    private var firstSelectButton: UIView?
    private let overlay = UIView()

    init(properties: [PropertyData]) {
        self.properties = properties
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let back = iconButton("chevron.backward", color: .appPrimary, size: 18) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        let help = iconButton("questionmark.circle", color: .appPrimary, size: 22) { [weak self] in self?.handleTourTap() }
        let header = UIStackView.h(4, [back, UILabel("Select Property", font: .poppins(18, .bold), color: .appTextDark), FlexSpacer(), help])
        headerView = header
        view.addSubview(header)
        header.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
        ])

        installScrollStack(insets: UIEdgeInsets(top: 8, left: 16, bottom: 24, right: 16), spacing: 16, below: header)
        if properties.isEmpty {
            let empty = UILabel("No properties found.", font: .poppins(14), color: .grey500, alignment: .center)
            view.addSubview(empty)
            empty.center(in: view)
        }
        for (i, p) in properties.enumerated() {
            contentStack.add(card(for: p, primary: i == 0))
        }

        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .appPrimary
        spinner.startAnimating()
        overlay.addSubview(spinner)
        spinner.center(in: overlay)
        overlay.isHidden = true
        view.addSubview(overlay)
        overlay.pinToEdges(of: view)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !properties.isEmpty else { return }
        TourGuide.autoStartIfFirstVisit(.propertySelection) { startTour() }
    }

    // MARK: - Card

    private func card(for p: PropertyData, primary: Bool) -> UIView {
        let card = CardView(radius: 16, padding: .zero, shadowOpacity: 0.06, shadowBlur: 16, shadowY: 6)
        let select = PrimaryButton("Select", height: 36, radius: 10, fontSize: 13, weight: .semibold)
        select.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        select.setContentHuggingPriority(.required, for: .horizontal)
        select.onEvent { [weak self] in self?.handleSelection(p) }
        let pid = UILabel("PID: \(p.propertyId ?? "N/A")", font: .poppins(14, .bold), color: .appTextDark, lines: 0)
        let top = UIStackView.h(8, [pid, select])
        card.stack.add(top.padded(UIEdgeInsets(top: 16, left: 16, bottom: 12, right: 16)))
        card.stack.add(divider(color: .grey100))

        let krutidev = UlbLanguageHelper.isKrutidevValue(p.ulbLang)
        let rows = UIStackView.v(8, [
            detailRow("Owner Name", p.ownerName, krutidev: krutidev),
            detailRow("Father/Husband", p.fatherHusbandName, krutidev: krutidev),
            detailRow("House No", p.houseNo, krutidev: false),
            detailRow("Address", p.address, krutidev: krutidev),
        ])
        card.stack.add(rows.padded(UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)))
        if primary {
            firstCard = card
            firstSelectButton = select
        }
        return card
    }

    private func detailRow(_ label: String, _ value: String?, krutidev: Bool) -> UIView {
        let l = UILabel("\(label): ", font: .poppins(13, .medium), color: .grey600)
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        let v = UILabel(value ?? "N/A", font: UlbLanguageHelper.font(13, .medium, krutidev: krutidev),
                        color: .appTextDark, lines: 0)
        return UIStackView.h(0, alignment: .top, [l, v])
    }

    // MARK: - Selection

    private func handleSelection(_ property: PropertyData) {
        guard let propertyId = property.propertyId, overlay.isHidden else { return }
        overlay.isHidden = false
        selected = property
        Task {
            do {
                let res = try await APIService.shared.getPropertyDetails(propertyId: propertyId)
                details = res.data
                guard let mobileNo = details?.ownerDetails?.mobileNo, !mobileNo.isEmpty else {
                    throw APIError.message("Mobile number not found for this property")
                }
                overlay.isHidden = true

                if let loginMobile = StorageService.loginMobile, !loginMobile.isEmpty,
                   !Self.isSameMobile(loginMobile, mobileNo) {
                    let proceed = await showMismatchDialog(loginMobile: loginMobile, propertyMobile: mobileNo)
                    guard proceed else { selected = nil; return }
                }
                await finalizeSelection(mobileNo: mobileNo, propertyId: propertyId)
            } catch {
                overlay.isHidden = true
                snack(APIError.userMessage(error, fallback: "Unable to select this property right now. Please try again."), .error)
            }
        }
    }

    /// Compares the last 10 digits so "+91"/"0" prefixes don't count as a mismatch.
    nonisolated static func isSameMobile(_ a: String, _ b: String) -> Bool {
        func normalize(_ v: String) -> String {
            let digits = v.filter(\.isNumber)
            return digits.count > 10 ? String(digits.suffix(10)) : digits
        }
        let l = normalize(a), r = normalize(b)
        if l.isEmpty || r.isEmpty { return true }
        return l == r
    }

    /// `9876596788` → `#####96788`
    nonisolated static func maskMobile(_ mobile: String?) -> String {
        let digits = (mobile ?? "").filter(\.isNumber)
        if digits.isEmpty { return "-" }
        if digits.count <= 5 { return digits }
        return String(repeating: "#", count: digits.count - 5) + digits.suffix(5)
    }

    private func showMismatchDialog(loginMobile: String, propertyMobile: String) async -> Bool {
        func row(_ label: String, _ value: String) -> UIView {
            let l = UILabel(label, font: .poppins(13, .medium), color: .grey600)
            l.setSize(width: 120)
            return UIStackView.h(0, alignment: .top, [l, UILabel(value, font: .poppins(13, .bold), color: .appTextDark, lines: 0)])
        }
        let content = UIStackView.v(0, [
            UILabel("Your login mobile number does not match the mobile number registered with this property.",
                    font: .poppins(13), color: .grey700, lines: 0),
        ])
        content.addSpacer(16)
        content.add(row("Login Number", Self.maskMobile(loginMobile)))
        content.addSpacer(8)
        content.add(row("Property Number", Self.maskMobile(propertyMobile)))
        content.addSpacer(16)
        content.add(UILabel("Do you still want to continue with this property?", font: .poppins(13, .medium),
                            color: .appTextDark, lines: 0))

        return await withCheckedContinuation { c in
            AppDialog.show(on: self, icon: "exclamationmark.triangle", iconColor: .appPrimary, iconSize: 22,
                           title: "Number Mismatch", content: content, actions: [
                .init(title: "Cancel", style: .cancel) { c.resume(returning: false) },
                .init(title: "Continue", style: .filled) { c.resume(returning: true) },
            ], dismissible: false)
        }
    }

    private func finalizeSelection(mobileNo: String, propertyId: String) async {
        let totalArv = selected?.totalArv.map(JSON.dartDoubleString) ?? "0.0"
        StorageService.saveTotalArv(totalArv)
        let info = details?.propertyDetailsInfo
        await DatabaseService.shared.insertProperty(PropertyEntity(
            propertyId: propertyId,
            ownerName: details?.ownerDetails?.ownerName ?? "N/A",
            ward: info?.wardName ?? "N/A",
            mohalla: info?.mohallaName ?? "N/A",
            phoneNumber: mobileNo,
            email: StorageService.emailId,
            userType: StorageService.userType,
            ulbId: StorageService.ulbId,
            arvValue: totalArv,
            userId: StorageService.userId ?? "0",
            fatherName: selected?.fatherHusbandName ?? "N/A",
            address: selected?.address ?? "N/A",
            zone: info?.zoneName,
            houseNo: info?.houseNo,
            totalArea: info?.totalArea,
            oldPropertyId: selected?.oldPropertyId,
            billDate: details?.billDetails?.billDate,
            netPayable: details?.billDetails?.netPayble,
            ulbLang: selected?.ulbLang))
        StorageService.setPropertyVerified(true)
        AppRouter.shared.showDashboard()
    }

    // MARK: - Tour

    private func handleTourTap() {
        guard !properties.isEmpty else {
            snack("Tour will be available once the property cards are loaded.", .success)
            return
        }
        startTour()
    }

    private func startTour() {
        guard let firstCard, let firstSelectButton else { return }
        TourCoachMarkView.present(steps: [
            TourStep(target: headerView, icon: "building.2", title: "Select Property",
                     description: "This screen displays the list of properties matched to your search. Please review the available property cards and select the correct property to proceed.",
                     shape: .roundedRect(radius: 14)),
            TourStep(target: firstCard, icon: "doc.text", title: "Check Property Details",
                     description: "Each property card includes key details such as the PID, owner name, father or husband name, house number, and address to help you identify the correct property.",
                     shape: .roundedRect(radius: 16)),
            TourStep(target: firstSelectButton, icon: "checkmark.circle", title: "Select And Verify",
                     description: "Tap Select on the appropriate property card to receive an OTP on the registered mobile number. After successful OTP verification, the selected property will be saved to your account.",
                     shape: .roundedRect(radius: 12)),
        ], scrollContainer: scrollView)
    }
}
