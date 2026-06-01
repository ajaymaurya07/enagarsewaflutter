import UIKit
import Combine

final class AccountViewController: UIViewController {

    private let viewModel: AccountViewModel
    private var cancellables = Set<AnyCancellable>()

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

    private func setupLayout() {
        let defaults = UserDefaultsService.shared

        let avatarView = UIImageView(image: UIImage(systemName: "person.circle.fill"))
        avatarView.tintColor = .appPrimary; avatarView.contentMode = .scaleAspectFit
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.setSize(width: 80, height: 80)

        let emailLabel = UILabel()
        emailLabel.text = defaults.emailId ?? "-"
        emailLabel.font = .systemFont(ofSize: 16); emailLabel.textAlignment = .center

        let typeLabel = UILabel()
        typeLabel.text = "Account type: \(defaults.userType ?? "User")"
        typeLabel.font = .systemFont(ofSize: 14); typeLabel.textColor = .secondaryLabel
        typeLabel.textAlignment = .center

        let logoutButton = UIButton.primaryButton(title: "Log Out")
        logoutButton.backgroundColor = .appError
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [avatarView, emailLabel, typeLabel, UIView(), logoutButton])
        stack.axis = .vertical; stack.spacing = 12; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([
            logoutButton.widthAnchor.constraint(equalToConstant: 200),
            logoutButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    @objc private func logoutTapped() {
        showConfirmation(title: "Log Out", message: "Are you sure you want to log out?",
                         confirmTitle: "Log Out") { [weak self] in
            self?.viewModel.logout()
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
