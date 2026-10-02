import UIKit

// MARK: - Layout helpers

extension UIView {

    func pinToEdges(of view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom),
        ])
    }

    func pinToSafeArea(of view: UIView, insets: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: g.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -insets.right),
            bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -insets.bottom),
        ])
    }

    func center(in view: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    @discardableResult
    func setSize(width: CGFloat? = nil, height: CGFloat? = nil) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        if let w = width { widthAnchor.constraint(equalToConstant: w).isActive = true }
        if let h = height { heightAnchor.constraint(equalToConstant: h).isActive = true }
        return self
    }

    /// Wraps the view in a container with padding (Flutter `Padding`).
    func padded(_ insets: UIEdgeInsets) -> UIView {
        let container = UIView()
        container.addSubview(self)
        pinToEdges(of: container, insets: insets)
        return container
    }

    func padded(_ all: CGFloat) -> UIView { padded(UIEdgeInsets(top: all, left: all, bottom: all, right: all)) }

    // MARK: - Styling

    func roundCorners(radius: CGFloat = 12) {
        layer.cornerRadius = radius
        clipsToBounds = true
    }

    /// `BoxShadow(color: black.withOpacity(opacity), blurRadius: blur, offset: (0, y))`.
    /// Flutter's blur radius is ~2× CoreAnimation's shadowRadius.
    func addShadow(opacity: Float = 0.05, blur: CGFloat = 15, offsetY: CGFloat = 8) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius = blur / 2
        layer.shadowOffset = CGSize(width: 0, height: offsetY)
        clipsToBounds = false
    }

    /// Default card shadow used across the Flutter screens (black 6%, blur 20, offset 8).
    func addCardShadow() { addShadow(opacity: 0.06, blur: 20, offsetY: 8) }

    func addBorder(color: UIColor = .grey200, width: CGFloat = 1) {
        layer.borderColor = color.cgColor
        layer.borderWidth = width
    }

    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-10, 10, -8, 8, -5, 5, 0]
        animation.duration = 0.4
        layer.add(animation, forKey: "shake")
    }

    // MARK: - Tap handling

    /// Closure-based tap (Flutter `GestureDetector(onTap:)`).
    func onTap(_ action: @escaping () -> Void) {
        isUserInteractionEnabled = true
        let recognizer = ClosureTapGestureRecognizer(action: action)
        addGestureRecognizer(recognizer)
    }

    /// Returns the nearest view controller in the responder chain.
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}

final class ClosureTapGestureRecognizer: UITapGestureRecognizer {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(fire))
        cancelsTouchesInView = false
    }

    @objc private func fire() { action() }
}

extension UIControl {
    /// Closure-based target action.
    func onEvent(_ event: UIControl.Event = .touchUpInside, _ action: @escaping () -> Void) {
        addAction(UIAction { _ in action() }, for: event)
    }
}

// MARK: - Stack helpers

extension UIStackView {
    convenience init(axis: NSLayoutConstraint.Axis, spacing: CGFloat = 0,
                     alignment: UIStackView.Alignment = .fill,
                     distribution: UIStackView.Distribution = .fill,
                     _ views: [UIView] = []) {
        self.init(arrangedSubviews: views)
        self.axis = axis
        self.spacing = spacing
        self.alignment = alignment
        self.distribution = distribution
    }

    static func v(_ spacing: CGFloat = 0, alignment: UIStackView.Alignment = .fill, _ views: [UIView]) -> UIStackView {
        UIStackView(axis: .vertical, spacing: spacing, alignment: alignment, views)
    }

    static func h(_ spacing: CGFloat = 0, alignment: UIStackView.Alignment = .center, _ views: [UIView]) -> UIStackView {
        UIStackView(axis: .horizontal, spacing: spacing, alignment: alignment, views)
    }

    func removeAllArranged() {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func add(_ views: UIView...) { views.forEach(addArrangedSubview) }

    /// `SizedBox(height:)` between arranged views.
    func addSpacer(_ size: CGFloat) {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        if axis == .vertical {
            spacer.heightAnchor.constraint(equalToConstant: size).isActive = true
        } else {
            spacer.widthAnchor.constraint(equalToConstant: size).isActive = true
        }
        addArrangedSubview(spacer)
    }
}

/// Flexible filler (`Spacer()` / `Expanded(child: SizedBox())`).
final class FlexSpacer: UIView {
    init() {
        super.init(frame: .zero)
        setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        setContentHuggingPriority(.defaultLow - 1, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow - 1, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow - 1, for: .vertical)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Labels / images

extension UILabel {
    convenience init(_ text: String?, font: UIFont, color: UIColor = .appTextDark, lines: Int = 1,
                     alignment: NSTextAlignment = .natural) {
        self.init(frame: .zero)
        self.text = text
        self.font = font
        self.textColor = color
        self.numberOfLines = lines
        self.textAlignment = alignment
    }

    /// Label + "\n" friendly line height like Flutter's `height: 1.5`.
    func setLineHeight(_ multiple: CGFloat) {
        guard let text else { return }
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = multiple
        style.alignment = textAlignment
        attributedText = NSAttributedString(string: text, attributes: [
            .font: font as Any, .foregroundColor: textColor as Any, .paragraphStyle: style,
        ])
    }
}

extension UIImage {
    /// SF Symbol at a given point size (Flutter `Icon(size:)`).
    static func symbol(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight))
    }
}

extension UIImageView {
    convenience init(symbol: String, size: CGFloat, color: UIColor, weight: UIImage.SymbolWeight = .regular) {
        self.init(image: .symbol(symbol, size: size, weight: weight))
        tintColor = color
        contentMode = .center
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
