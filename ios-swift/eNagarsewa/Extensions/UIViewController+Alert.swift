import UIKit

extension UIViewController {

    func showAlert(title: String = "Error", message: String, action: String = "OK", handler: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: action, style: .default) { _ in handler?() })
        present(alert, animated: true)
    }

    func showConfirmation(title: String, message: String, confirmTitle: String = "Confirm",
                          confirm: @escaping () -> Void, cancel: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in cancel?() })
        alert.addAction(UIAlertAction(title: confirmTitle, style: .destructive) { _ in confirm() })
        present(alert, animated: true)
    }

    func showLoadingOverlay(message: String = "Please wait…") -> UIViewController {
        let vc = UIViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle   = .crossDissolve
        vc.view.backgroundColor   = UIColor.black.withAlphaComponent(0.4)

        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [indicator, label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        vc.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
        ])
        present(vc, animated: true)
        return vc
    }
}
