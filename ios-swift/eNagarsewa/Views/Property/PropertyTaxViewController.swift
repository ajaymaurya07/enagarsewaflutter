import UIKit

/// Port of lib/property_tax_screen.dart ("My Properties").
final class PropertyTaxViewController: BaseViewController {

    override var screenBackground: UIColor { UIColor.Scheme.surfaceContainerLowest }

    private var properties: [PropertyEntity] = []
    private var isLoadingList = true
    private var firstCard: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "My Properties", background: UIColor.Scheme.surface, titleColor: UIColor.Scheme.onSurface,
                     centerTitle: true, rightItems: [helpItem { [weak self] in self?.handleTourTap() }])
        installScrollStack(insets: UIEdgeInsets(top: 20, left: 16, bottom: 0, right: 16), spacing: 20)
        Task { await loadProperties() }
    }

    private func loadProperties() async {
        isLoadingList = true
        setLoading(true)
        properties = await DatabaseService.shared.getAllProperties()
        isLoadingList = false
        setLoading(false)
        render()
        if !properties.isEmpty {
            TourGuide.autoStartIfFirstVisit(.propertyTax) { startTour() }
        }
    }

    private func render() {
        contentStack.removeAllArranged()
        firstCard = nil
        if properties.isEmpty {
            let empty = emptyState(icon: "building.2", title: "No properties added yet",
                                   message: "Your verified properties will appear here for quick access.",
                                   iconColor: UIColor.Scheme.outline, circle: UIColor.Scheme.surface)
            let wrapper = empty.padded(UIEdgeInsets(top: 120, left: 16, bottom: 0, right: 16))
            contentStack.add(wrapper)
            return
        }
        for (i, p) in properties.enumerated() {
            let card = propertyCard(p)
            if i == 0 { firstCard = card }
            contentStack.add(card)
        }
    }

    private func propertyCard(_ p: PropertyEntity) -> UIView {
        let card = CardView(radius: 20, padding: .zero, background: UIColor.Scheme.surface,
                            shadowOpacity: 0.04, shadowBlur: 20, shadowY: 10)
        let header = UIStackView.h(12, [
            iconTile("building.2.crop.circle", color: UIColor.Scheme.primary, background: UIColor.Scheme.primaryContainer,
                     size: 42, iconSize: 20),
            UILabel("PID: \(p.propertyId)", font: .poppins(14, .bold), color: UIColor.Scheme.onSurface, lines: 0),
            FlexSpacer(),
            UIImageView(symbol: "chevron.forward", size: 14, color: UIColor.Scheme.onSurfaceVariant, weight: .semibold),
        ])
        card.stack.add(header.padded(16), divider(color: UIColor.Scheme.outlineVariant, thickness: 0.8))
        let krutidev = UlbLanguageHelper.isKrutidevValue(p.ulbLang)
        let rows = UIStackView.v(12, [
            detailRow("Owner", p.ownerName, krutidev: krutidev),
            detailRow("Ward", p.ward, krutidev: false),
            detailRow("Mohalla", p.mohalla, krutidev: false),
            detailRow("Mobile", p.phoneNumber, krutidev: false),
        ])
        card.stack.add(rows.padded(20))
        card.onTap { [weak self] in
            guard !TourCoachMarkView.isActive else { return }
            self?.push(PaymentDetailsViewController(propertyId: p.propertyId))
        }
        return card
    }

    private func detailRow(_ label: String, _ value: String, krutidev: Bool) -> UIView {
        let l = UILabel("\(label):", font: .poppins(13, .medium), color: UIColor.Scheme.onSurfaceVariant)
        l.setSize(width: 80)
        let v = UILabel(value, font: UlbLanguageHelper.font(13, .semibold, krutidev: krutidev),
                        color: UIColor.Scheme.onSurface, lines: 0)
        return UIStackView.h(8, alignment: .top, [l, v])
    }

    private func handleTourTap() {
        if isLoadingList { snack("Tour will be available after properties are loaded."); return }
        if properties.isEmpty { snack("Add or verify a property first to view this tour."); return }
        startTour()
    }

    private func startTour() {
        guard let firstCard, !TourCoachMarkView.isActive else { return }
        TourCoachMarkView.present(steps: [
            TourStep(target: firstCard, icon: "list.bullet.rectangle", title: "Property Card List",
                     description: "This screen can show a list of saved property cards. Tap any property card to open the tax payment screen, where you can review the details and proceed with payment.",
                     shape: .roundedRect(radius: 16)),
        ], scrollContainer: scrollView)
    }
}
