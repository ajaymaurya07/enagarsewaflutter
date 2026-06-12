import UIKit

// MARK: - Layout helpers
extension UIView {

    func pinToEdges(of view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor,         constant:  insets.top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor,  constant:  insets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor,constant: -insets.right),
            bottomAnchor.constraint(equalTo: view.bottomAnchor,   constant: -insets.bottom),
        ])
    }

    func pinToSafeArea(of view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: g.topAnchor,         constant:  insets.top),
            leadingAnchor.constraint(equalTo: g.leadingAnchor,  constant:  insets.left),
            trailingAnchor.constraint(equalTo: g.trailingAnchor,constant: -insets.right),
            bottomAnchor.constraint(equalTo: g.bottomAnchor,   constant: -insets.bottom),
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

    /// Flutter card shadow: black 6% opacity, blur ≈20, offset (0,8)
    func addCardShadow() {
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowRadius  = 10
        layer.shadowOffset  = CGSize(width: 0, height: 8)
        clipsToBounds = false
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

    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-10, 10, -8, 8, -5, 5, 0]
        animation.duration = 0.4
        layer.add(animation, forKey: "shake")
    }

    // MARK: - Card container factory
    /// White card with radius-20 and Flutter-style shadow.
    static func cardContainer(padding: CGFloat = 24) -> UIView {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 20
        v.addCardShadow()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }
}

// MARK: - Primary button (matches Flutter ElevatedButton)
extension UIButton {
    /// Full-width orange button — height 52, corner-radius 14, Poppins-Bold 16.
    static func primaryButton(title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .appPrimary
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .disabled)
        button.titleLabel?.font = UIFont(name: "Poppins-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 14
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    func setLoading(_ loading: Bool) {
        if loading {
            isEnabled = false
            backgroundColor = .appPrimary?.withAlphaComponent(0.6) ?? UIColor.appPrimary.withAlphaComponent(0.6)
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = .white
            spinner.tag = 9_001
            spinner.translatesAutoresizingMaskIntoConstraints = false
            addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            spinner.startAnimating()
            titleLabel?.alpha = 0
        } else {
            isEnabled = true
            backgroundColor = .appPrimary
            viewWithTag(9_001)?.removeFromSuperview()
            titleLabel?.alpha = 1
        }
    }
}

// MARK: - UITextField factory

extension UITextField {
    static func styledTextField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        tf.backgroundColor = UIColor(hex: "#F8F9FB")
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor(hex: "#EEEEEE").cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        tf.rightViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return tf
    }
}

// MARK: - ENSInputField  (matches Flutter's InputDecoration style)
/// Container view: fill #F8F9FB, radius-12, border grey/orange on focus, prefix SF-symbol icon.
final class ENSInputField: UIView {

    let textField = UITextField()
    private let iconView   = UIImageView()
    private var normalBorderColor: UIColor { .appFieldBorder }
    private var focusBorderColor:  UIColor { .appPrimary    }

    // Optional right-side button (eye toggle)
    private var rightButton: UIButton?

    /// Create a standard text-input field.
    /// - Parameters:
    ///   - placeholder: Placeholder string (Poppins Regular 13, grey.shade400)
    ///   - icon: SF Symbol name for the prefix icon
    ///   - isPassword: Adds visibility-toggle button on the right
    ///   - keyboardType: Keyboard type
    convenience init(placeholder: String,
                     icon: String,
                     isPassword: Bool = false,
                     keyboardType: UIKeyboardType = .default) {
        self.init(frame: .zero)
        configure(placeholder: placeholder, icon: icon, isPassword: isPassword, keyboardType: keyboardType)
    }

    override init(frame: CGRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }

    private func configure(placeholder: String,
                           icon: String,
                           isPassword: Bool,
                           keyboardType: UIKeyboardType) {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .appFieldFill
        layer.cornerRadius = 12
        layer.borderWidth  = 1
        layer.borderColor  = normalBorderColor.cgColor
        clipsToBounds = true

        // Prefix icon
        iconView.image = UIImage(systemName: icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        iconView.tintColor = .appPrimary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // TextField
        textField.placeholder = placeholder
        textField.font = UIFont(name: "Poppins-Regular", size: 14) ?? .systemFont(ofSize: 14)
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.keyboardType = keyboardType
        textField.isSecureTextEntry = isPassword
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13),
                .foregroundColor: UIColor(red: 0.741, green: 0.741, blue: 0.741, alpha: 1), // grey.shade400
            ]
        )

        addSubview(iconView)
        addSubview(textField)

        var trailingAnchor = self.trailingAnchor

        if isPassword {
            let btn = UIButton(type: .custom)
            btn.setImage(UIImage(systemName: "eye.slash"), for: .normal)
            btn.setImage(UIImage(systemName: "eye"),       for: .selected)
            btn.tintColor = UIColor(red: 0.620, green: 0.620, blue: 0.620, alpha: 1)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.addTarget(self, action: #selector(toggleVisibility), for: .touchUpInside)
            addSubview(btn)
            NSLayoutConstraint.activate([
                btn.widthAnchor.constraint(equalToConstant: 44),
                btn.centerYAnchor.constraint(equalTo: centerYAnchor),
                btn.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            ])
            trailingAnchor = btn.leadingAnchor
            rightButton = btn
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 50),

            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),

            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Focus border
        textField.addTarget(self, action: #selector(didBeginEditing), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(didEndEditing),   for: .editingDidEnd)
    }

    @objc private func didBeginEditing() {
        layer.borderColor = focusBorderColor.cgColor
        layer.borderWidth = 1.5
    }

    @objc private func didEndEditing() {
        layer.borderColor = normalBorderColor.cgColor
        layer.borderWidth = 1
    }

    @objc private func toggleVisibility() {
        guard let btn = rightButton else { return }
        btn.isSelected.toggle()
        textField.isSecureTextEntry = !btn.isSelected
    }
}

// MARK: - Field label helper
extension UILabel {
    /// Small grey label above an input — matches Flutter's field labels (Poppins Medium 13, grey.shade700).
    static func fieldLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont(name: "Poppins-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        l.textColor = UIColor(red: 0.424, green: 0.424, blue: 0.424, alpha: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }
}

// MARK: - Checkbox (matches Flutter Checkbox: orange fill, rounded 4)
final class ENSCheckbox: UIControl {

    var isChecked: Bool = false { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        translatesAutoresizingMaskIntoConstraints = false
        setSize(width: 20, height: 20)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let path = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 4)
        if isChecked {
            UIColor.appPrimary.setFill(); path.fill()
            UIColor.appPrimary.setStroke()
            // Checkmark
            let ck = UIBezierPath()
            ck.move(to:   CGPoint(x: rect.width * 0.20, y: rect.height * 0.52))
            ck.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.72))
            ck.addLine(to: CGPoint(x: rect.width * 0.80, y: rect.height * 0.28))
            ck.lineWidth = 2; ck.lineCapStyle = .round; ck.lineJoinStyle = .round
            UIColor.white.setStroke(); ck.stroke()
        } else {
            UIColor.white.setFill(); path.fill()
            UIColor(red: 0.741, green: 0.741, blue: 0.741, alpha: 1).setStroke()
            path.lineWidth = 1; path.stroke()
        }
    }

    @objc private func tapped() {
        isChecked.toggle()
        sendActions(for: .valueChanged)
    }
}

// MARK: - Floating Snackbar (matches Flutter SnackBar floating behavior)
final class ENSSnackbar {

    static func show(in view: UIView, message: String, isError: Bool) {
        let container = UIView()
        container.backgroundColor = isError
            ? UIColor.systemRed.withAlphaComponent(0.92)
            : UIColor.systemGreen.withAlphaComponent(0.92)
        container.layer.cornerRadius = 10
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alpha = 0

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])

        // Place above safe-area bottom
        let window = view.window ?? view
        window.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])

        UIView.animate(withDuration: 0.3) { container.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UIView.animate(withDuration: 0.3, animations: { container.alpha = 0 }) { _ in
                container.removeFromSuperview()
            }
        }
    }
}
