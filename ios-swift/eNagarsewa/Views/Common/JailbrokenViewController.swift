import UIKit

/// Shown when the device fails security checks (jailbroken / tampered).
/// Mirrors Flutter's rooted_device_screen.dart.
final class JailbrokenViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLayout()
    }

    private func setupLayout() {
        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.shield.fill"))
        icon.tintColor = .appError; icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false; icon.setSize(width: 80, height: 80)

        let titleLabel = UILabel()
        titleLabel.text = "Device Not Supported"
        titleLabel.font = .boldSystemFont(ofSize: 22); titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = "This app cannot run on a jailbroken or compromised device. " +
                            "For your security, please use an unmodified device."
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center; messageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, messageLabel])
        stack.axis = .vertical; stack.spacing = 20; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
