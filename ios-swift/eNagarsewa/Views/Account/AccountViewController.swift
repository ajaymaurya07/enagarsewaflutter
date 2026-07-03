import UIKit
import Combine

final class AccountViewController: UIViewController {

    private let viewModel: AccountViewModel
    private var cancellables = Set<AnyCancellable>()

    // Refs kept for the first-run tour guide (see lib/tour_guides/account_tour.dart)
    private weak var profileHeaderView: UIView?
    private weak var userIdCardView: UIView?
    private weak var userTypeCardView: UIView?
    private weak var logoutButtonView: UIView?
    private var didPresentTour = false

    init(viewModel: AccountViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Account"
        view.backgroundColor = .appBackground
        setupLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentTourIfNeeded()
    }

    private func setupLayout() {
        let defaults  = UserDefaultsService.shared
        let email     = defaults.emailId  ?? "N/A"
        let userType  = defaults.userType ?? "N/A"

        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor),
        ])

        // MARK: Profile header
        let avatarBg = UIView()
        avatarBg.backgroundColor = UIColor(red: 1, green: 0.957, blue: 0.898, alpha: 1)
        avatarBg.layer.cornerRadius = 50
        avatarBg.widthAnchor.constraint(equalToConstant: 100).isActive = true
        avatarBg.heightAnchor.constraint(equalToConstant: 100).isActive = true

        let personIcon = UIImageView(image: UIImage(systemName: "person.fill"))
        personIcon.tintColor = .appPrimary; personIcon.contentMode = .scaleAspectFit
        personIcon.translatesAutoresizingMaskIntoConstraints = false
        avatarBg.addSubview(personIcon)
        NSLayoutConstraint.activate([
            personIcon.centerXAnchor.constraint(equalTo: avatarBg.centerXAnchor),
            personIcon.centerYAnchor.constraint(equalTo: avatarBg.centerYAnchor),
            personIcon.widthAnchor.constraint(equalToConstant: 50),
            personIcon.heightAnchor.constraint(equalToConstant: 50),
        ])

        let typeL = UILabel()
        typeL.text = userType.uppercased()
        typeL.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        typeL.textColor = .appCardText; typeL.textAlignment = .center

        let headerStack = UIStackView(arrangedSubviews: [avatarBg, typeL])
        headerStack.axis = .vertical; headerStack.spacing = 16; headerStack.alignment = .center
        profileHeaderView = headerStack

        // MARK: Info cards
        let emailCard = buildInfoCard(icon: "envelope",
                                      label: "User ID",
                                      value: email)
        userIdCardView = emailCard
        let typeCard  = buildInfoCard(icon: "shield.lefthalf.filled",
                                      label: "User Type",
                                      value: userType)
        userTypeCardView = typeCard

        // MARK: Logout button
        let logoutBtn = buildLogoutButton()
        logoutButtonView = logoutBtn

        // MARK: Main stack
        let mainStack = UIStackView(arrangedSubviews: [headerStack, emailCard, typeCard, logoutBtn])
        mainStack.axis = .vertical; mainStack.spacing = 16
        mainStack.setCustomSpacing(32, after: headerStack)
        mainStack.setCustomSpacing(48, after: typeCard)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -32),
        ])
    }

    // MARK: - Helpers

    private func buildInfoCard(icon: String, label: String, value: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.addCardShadow()

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor(red: 1, green: 0.957, blue: 0.898, alpha: 1)
        iconBg.layer.cornerRadius = 12
        iconBg.widthAnchor.constraint(equalToConstant: 44).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let iconImg = UIImageView(image: UIImage(systemName: icon))
        iconImg.tintColor = .appPrimary; iconImg.contentMode = .scaleAspectFit
        iconImg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconImg)
        NSLayoutConstraint.activate([
            iconImg.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconImg.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconImg.widthAnchor.constraint(equalToConstant: 22),
            iconImg.heightAnchor.constraint(equalToConstant: 22),
        ])

        let labelL = UILabel()
        labelL.text = label
        labelL.font = UIFont(name: "Poppins-Regular", size: 12) ?? .systemFont(ofSize: 12)
        labelL.textColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)

        let valueL = UILabel()
        valueL.text = value
        valueL.font = UIFont(name: "Poppins-SemiBold", size: 15) ?? .systemFont(ofSize: 15, weight: .semibold)
        valueL.textColor = .appCardText
        valueL.numberOfLines = 1

        let textStack = UIStackView(arrangedSubviews: [labelL, valueL])
        textStack.axis = .vertical; textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconBg, textStack])
        row.axis = .horizontal; row.spacing = 16; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func buildLogoutButton() -> UIView {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = UIColor.systemRed.withAlphaComponent(0.10)
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        btn.heightAnchor.constraint(equalToConstant: 56).isActive = true
        btn.translatesAutoresizingMaskIntoConstraints = false

        let iconImg = UIImageView(image: UIImage(systemName: "rectangle.portrait.and.arrow.right"))
        iconImg.tintColor = .systemRed; iconImg.contentMode = .scaleAspectFit
        iconImg.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconImg.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let titleL = UILabel()
        titleL.text = "Logout"
        titleL.font = UIFont(name: "Poppins-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        titleL.textColor = .systemRed

        let inner = UIStackView(arrangedSubviews: [iconImg, titleL])
        inner.axis = .horizontal; inner.spacing = 10; inner.alignment = .center
        inner.isUserInteractionEnabled = false
        inner.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            inner.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
        ])
        btn.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        return btn
    }

    @objc private func logoutTapped() {
        showConfirmation(title: "Logout",
                         message: "Are you sure you want to logout?",
                         confirmTitle: "Logout") { [weak self] in
            self?.viewModel.logout()
        }
    }

    // MARK: - Tour guide (first-run coach mark, see lib/tour_guides/account_tour.dart)

    private func presentTourIfNeeded() {
        guard !didPresentTour, !UserDefaultsService.shared.hasTourBeenSeen(.account) else { return }
        guard let profileHeaderView, let userIdCardView, let userTypeCardView, let logoutButtonView else { return }
        didPresentTour = true

        let steps: [TourStep] = [
            TourStep(target: profileHeaderView, icon: "person.crop.circle",
                     title: "Profile Overview",
                     description: "This section shows your account profile and the role currently signed in to the app.",
                     shape: .roundedRect(radius: 18),
                     edge: .bottom),
            TourStep(target: userIdCardView, icon: "envelope",
                     title: "User Id",
                     description: "This card displays the email or user ID currently linked with your account.",
                     edge: .bottom),
            TourStep(target: userTypeCardView, icon: "shield.lefthalf.filled",
                     title: "User Type",
                     description: "This card shows the account type or access role you are using in the app.",
                     edge: .top),
            TourStep(target: logoutButtonView, icon: "rectangle.portrait.and.arrow.right",
                     title: "Logout",
                     description: "Use this button to safely log out from the app and return to the login screen.",
                     edge: .top),
        ]

        TourCoachMarkView.present(steps: steps) {
            UserDefaultsService.shared.markTourSeen(.account)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AccountViewModel: ObservableObject {
    let onLogout: () -> Void
    init(onLogout: @escaping () -> Void) { self.onLogout = onLogout }
    func logout() { onLogout() }
}
