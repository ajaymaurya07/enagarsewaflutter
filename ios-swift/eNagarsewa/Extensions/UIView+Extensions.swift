import UIKit

extension UIView {

    // MARK: - Layout helpers

    func pinToEdges(of view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor,       constant: insets.top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: view.bottomAnchor,  constant: -insets.bottom),
        ])
    }

    func center(in view: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func setSize(width: CGFloat? = nil, height: CGFloat? = nil) {
        translatesAutoresizingMaskIntoConstraints = false
        if let w = width  { widthAnchor.constraint(equalToConstant: w).isActive = true }
        if let h = height { heightAnchor.constraint(equalToConstant: h).isActive = true }
    }

    // MARK: - Styling

    func roundCorners(radius: CGFloat = 12) {
        layer.cornerRadius = radius
        clipsToBounds = true
    }

    func addShadow(opacity: Float = 0.15, radius: CGFloat = 8, offset: CGSize = CGSize(width: 0, height: 2)) {
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius  = radius
        layer.shadowOffset  = offset
        clipsToBounds = false
    }

    func addBorder(color: UIColor = .separator, width: CGFloat = 1) {
        layer.borderColor = color.cgColor
        layer.borderWidth = width
    }

    // MARK: - Animation

    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-10, 10, -8, 8, -5, 5, 0]
        animation.duration = 0.4
        layer.add(animation, forKey: "shake")
    }
}

// MARK: - Primary button factory

extension UIButton {
    static func primaryButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = UIColor(named: "AppPrimary") ?? .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}

// MARK: - Text field factory

extension UITextField {
    static func styledTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 16)
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }
}
