import UIKit

/// Port of lib/account_screen.dart.
final class AccountViewController: BaseViewController {

    override var screenBackground: UIColor { UIColor.Scheme.surfaceContainerLowest }

    private var profileHeader: UIView!
    private var userIdCard: UIView!
    private var userTypeCard: UIView!
    private var logoutButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: "My Account", background: UIColor.Scheme.surface, titleColor: UIColor.Scheme.onSurface,
                     rightItems: [helpItem(color: UIColor.Scheme.primary) { [weak self] in self?.startTour() }])

        let userId = StorageService.userId ?? "N/A"
        let userType = StorageService.userType ?? "N/A"

        let avatar = iconTile("person.fill", color: UIColor.Scheme.primary, background: UIColor.Scheme.primaryContainer,
                              size: 100, iconSize: 48, radius: 50)
        let header = UIStackView.v(16, alignment: .center, [
            avatar, UILabel(userType.uppercased(), font: .poppins(20, .bold), color: UIColor.Scheme.onSurface),
        ])
        profileHeader = header
        userIdCard = infoCard("envelope", "User Id", userId)
        userTypeCard = infoCard("person.badge.shield.checkmark", "User Type", userType)

        let errorContainer = UIColor(argb: 0xFFFFDAD6)
        let logout = PrimaryButton("Logout", color: errorContainer, height: 56, radius: 16, icon: "rectangle.portrait.and.arrow.right")
        logout.setTitleColor(UIColor.Scheme.error, for: .normal)
        logout.tintColor = UIColor.Scheme.error
        logout.onEvent { [weak self] in self?.handleLogout() }
        logoutButton = logout

        installScrollStack(insets: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        contentStack.addSpacer(20)
        contentStack.add(header)
        contentStack.addSpacer(32)
        contentStack.add(userIdCard)
        contentStack.addSpacer(16)
        contentStack.add(userTypeCard)
        contentStack.addSpacer(48)
        contentStack.add(logout)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        TourGuide.autoStartIfFirstVisit(.account) { startTour() }
    }

    private func infoCard(_ icon: String, _ label: String, _ value: String) -> UIView {
        let card = CardView(radius: 16, background: UIColor.Scheme.surface, shadowOpacity: 0.04, shadowBlur: 10, shadowY: 4)
        let texts = UIStackView.v(0, [
            UILabel(label, font: .poppins(12), color: UIColor.Scheme.onSurfaceVariant),
            UILabel(value, font: .poppins(15, .semibold), color: UIColor.Scheme.onSurface, lines: 0),
        ])
        card.stack.add(UIStackView.h(16, [
            iconTile(icon, color: UIColor.Scheme.primary, background: UIColor.Scheme.primaryContainer, size: 42, iconSize: 20),
            texts,
        ]))
        return card
    }

    private func handleLogout() {
        guard !TourCoachMarkView.isActive else { return }
        AppDialog.show(on: self, title: "Logout", message: "Are you sure you want to logout?", actions: [
            .init(title: "Cancel", style: .cancel, color: UIColor.Scheme.onSurfaceVariant),
            .init(title: "Logout", style: .destructive, color: UIColor.Scheme.error) { [weak self] in
                guard let self else { return }
                LoadingOverlay.show(on: self)
                Task {
                    await SessionActions.logout()
                    await LoadingOverlay.hideAsync()
                    AppRouter.shared.showOtpLogin()
                }
            },
        ])
    }

    private func startTour() {
        guard !TourCoachMarkView.isActive else { return }
        TourCoachMarkView.present(steps: [
            TourStep(target: profileHeader, icon: "person", title: "Profile Overview",
                     description: "This section shows your account profile and the role currently signed in to the app.",
                     shape: .roundedRect(radius: 18)),
            TourStep(target: userIdCard, icon: "envelope", title: "User Id",
                     description: "This card displays the email or user ID currently linked with your account.",
                     shape: .roundedRect(radius: 16)),
            TourStep(target: userTypeCard, icon: "person.badge.shield.checkmark", title: "User Type",
                     description: "This card shows the account type or access role you are using in the app.",
                     shape: .roundedRect(radius: 16), edge: .top),
            TourStep(target: logoutButton, icon: "rectangle.portrait.and.arrow.right", title: "Logout",
                     description: "Use this button to safely log out from the app and return to the login screen.",
                     shape: .roundedRect(radius: 16), edge: .top),
        ], scrollContainer: scrollView)
    }
}
