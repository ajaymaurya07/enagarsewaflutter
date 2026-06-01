import UIKit

/// Shown when there is no network connectivity.
/// Mirrors Flutter's unable_to_connect_screen.dart.
final class NoConnectionViewController: UIViewController {

    private let onRetry: () -> Void

    init(onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLayout()
    }

    private func setupLayout() {
        let icon = UIImageView(image: UIImage(systemName: "wifi.slash"))
        icon.tintColor = .secondaryLabel; icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false; icon.setSize(width: 72, height: 72)

        let title = UILabel()
        title.text = "No Connection"; title.font = .boldSystemFont(ofSize: 22); title.textAlignment = .center

        let message = UILabel()
        message.text = "Please check your internet connection and try again."
        message.font = .systemFont(ofSize: 16); message.textColor = .secondaryLabel
        message.textAlignment = .center; message.numberOfLines = 0

        let retryButton = UIButton.primaryButton(title: "Retry")
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, title, message, retryButton])
        stack.axis = .vertical; stack.spacing = 20; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            retryButton.widthAnchor.constraint(equalToConstant: 160),
            retryButton.heightAnchor.constraint(equalToConstant: 50),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    @objc private func retryTapped() { onRetry() }
}
