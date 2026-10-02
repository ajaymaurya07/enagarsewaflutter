import UIKit

// Flutter form widgets rebuilt in UIKit: `TextFormField` with the app's filled
// `InputDecoration`, a tappable dropdown field, `InfoLabel`, and the filled/outlined buttons.

// MARK: - Text field

/// `TextFormField` with the app-wide decoration: fill #F8F9FB, radius 12, grey.shade200 border,
/// orange 1.5pt focus border, red border + message on validation errors.
final class ENSTextField: UIView, UITextFieldDelegate, UITextViewDelegate {

    struct Config {
        var placeholder: String = ""
        var icon: String? = nil
        var iconColor: UIColor = .appPrimary
        var keyboard: UIKeyboardType = .default
        var isSecure = false
        var maxLength: Int? = nil
        /// Regex a single character must match to be kept (`FilteringTextInputFormatter.allow`).
        var allow: String? = nil
        /// Regex of characters to strip (`FilteringTextInputFormatter.deny`).
        var deny: String? = nil
        var digitsOnly = false
        /// > 1 renders a multi-line `UITextView` (Flutter `maxLines`).
        var lines: Int = 1
        var capitalization: UITextAutocapitalizationType = .none
        var fill: UIColor = .appFieldFill
        var fontSize: CGFloat = 14
        var textAlignment: NSTextAlignment = .natural
        var height: CGFloat = 50
        var radius: CGFloat = 12
        var returnKey: UIReturnKeyType = .default
        /// `InputDecoration(labelText:)` — the placeholder floats to a small label once
        /// the field is focused or filled.
        var floatingLabel = false
        var labelColor: UIColor = UIColor(argb: 0xFF6B7280)
        var borderColor: UIColor = .grey200
        var textColor: UIColor = .black87
    }

    let config: Config
    let box = UIView()
    private(set) var textField: UITextField?
    private(set) var textView: UITextView?
    private let placeholderLabel = UILabel()
    private let errorLabel = UILabel()
    private let floatLabel = UILabel()
    private let floatHolder = UIView()
    private var accessoryButton: UIButton?
    private var hasError = false
    private var isEditingActive = false

    var validator: ((String) -> String?)?
    var onChange: ((String) -> Void)?
    var onSubmit: (() -> Void)?
    var onBeginEditing: (() -> Void)?
    /// `InputDecoration(hintText:)` — shown (small, grey) inside a focused, empty floating field.
    var hint: String? { didSet { updateFloatingLabel() } }

    var text: String {
        get { textField?.text ?? textView?.text ?? "" }
        set {
            textField?.text = newValue
            textView?.text = newValue
            placeholderLabel.isHidden = !newValue.isEmpty
            updateFloatingLabel()
        }
    }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isEnabled: Bool = true {
        didSet {
            textField?.isEnabled = isEnabled
            textView?.isEditable = isEnabled
            alpha = isEnabled ? 1 : 0.6
        }
    }

    init(_ config: Config) {
        self.config = config
        super.init(frame: .zero)
        build()
    }

    convenience init(placeholder: String, icon: String? = nil, keyboard: UIKeyboardType = .default,
                     maxLength: Int? = nil, secure: Bool = false) {
        var c = Config()
        c.placeholder = placeholder
        c.icon = icon
        c.keyboard = keyboard
        c.maxLength = maxLength
        c.isSecure = secure
        self.init(c)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        box.backgroundColor = config.fill
        box.layer.cornerRadius = config.radius
        box.layer.borderWidth = 1
        box.layer.borderColor = config.borderColor.cgColor

        let row = UIStackView.h(0, alignment: config.lines > 1 ? .top : .center, [])
        floatLabel.text = config.placeholder
        floatLabel.font = .poppins(12)
        floatLabel.textColor = config.labelColor
        floatHolder.addSubview(floatLabel)
        floatLabel.pinToEdges(of: floatHolder, insets: UIEdgeInsets(top: 8, left: 16, bottom: 0, right: 12))
        floatHolder.isHidden = true
        let column = UIStackView.v(0, [floatHolder, row])
        column.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(column)

        if let icon = config.icon {
            let iv = UIImageView(symbol: icon, size: 18, color: config.iconColor)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 46).isActive = true
            if config.lines > 1 { iv.heightAnchor.constraint(equalToConstant: 44).isActive = true }
            row.addArrangedSubview(iv)
        } else {
            row.addSpacer(16)
        }

        let font = UIFont.poppins(config.fontSize)
        if config.lines > 1 {
            let tv = UITextView()
            tv.font = font
            tv.textColor = .black87
            tv.backgroundColor = .clear
            tv.textContainerInset = UIEdgeInsets(top: 14, left: -4, bottom: 14, right: 0)
            tv.isScrollEnabled = false
            tv.delegate = self
            tv.keyboardType = config.keyboard
            tv.autocapitalizationType = config.capitalization
            tv.autocorrectionType = .no
            placeholderLabel.text = config.placeholder
            placeholderLabel.font = .poppins(13)
            placeholderLabel.textColor = .grey400
            placeholderLabel.numberOfLines = 0
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            tv.addSubview(placeholderLabel)
            NSLayoutConstraint.activate([
                placeholderLabel.topAnchor.constraint(equalTo: tv.topAnchor, constant: 14),
                placeholderLabel.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
                placeholderLabel.widthAnchor.constraint(equalTo: tv.widthAnchor),
                tv.heightAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(config.lines) * 21 + 28),
            ])
            textView = tv
            row.addArrangedSubview(tv)
        } else {
            let tf = UITextField()
            tf.font = font
            tf.textColor = .black87
            tf.textAlignment = config.textAlignment
            tf.keyboardType = config.keyboard
            tf.isSecureTextEntry = config.isSecure
            tf.autocapitalizationType = config.capitalization
            tf.autocorrectionType = .no
            tf.returnKeyType = config.returnKey
            tf.delegate = self
            tf.attributedPlaceholder = NSAttributedString(string: config.placeholder, attributes: [
                .font: UIFont.poppins(13), .foregroundColor: UIColor.grey400,
            ])
            tf.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
            tf.heightAnchor.constraint(equalToConstant: config.height).isActive = true
            textField = tf
            row.addArrangedSubview(tf)
        }

        if config.isSecure {
            let b = UIButton(type: .system)
            b.setImage(.symbol("eye.slash", size: 18), for: .normal)
            b.tintColor = .grey500
            b.widthAnchor.constraint(equalToConstant: 44).isActive = true
            b.onEvent { [weak self] in self?.toggleSecure() }
            accessoryButton = b
            row.addArrangedSubview(b)
        } else {
            row.addSpacer(12)
        }

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: box.topAnchor),
            column.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        textField?.textColor = config.textColor
        textView?.textColor = config.textColor

        errorLabel.font = .poppins(12)
        errorLabel.textColor = .appRedError
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let stack = UIStackView.v(6, [box, errorLabel])
        addSubview(stack)
        stack.pinToEdges(of: self)
        updateFloatingLabel()
    }

    /// Adds a trailing accessory view (e.g. a suffix icon button).
    /// The horizontal row holding icon / input / accessory.
    var inputRow: UIStackView? {
        (box.subviews.first as? UIStackView)?.arrangedSubviews.last as? UIStackView
    }

    func setTrailing(_ view: UIView) {
        guard let row = inputRow else { return }
        if let last = row.arrangedSubviews.last, accessoryButton == nil { last.removeFromSuperview() }
        accessoryButton?.removeFromSuperview()
        row.addArrangedSubview(view)
    }

    private func toggleSecure() {
        guard let tf = textField else { return }
        tf.isSecureTextEntry.toggle()
        accessoryButton?.setImage(.symbol(tf.isSecureTextEntry ? "eye.slash" : "eye", size: 18), for: .normal)
    }

    // MARK: Validation

    @discardableResult
    func validate() -> Bool {
        let message = validator?(text)
        setError(message)
        return message == nil
    }

    func setError(_ message: String?) {
        hasError = message != nil
        errorLabel.text = message
        errorLabel.isHidden = message == nil
        updateBorder()
    }

    private func updateFloatingLabel() {
        guard config.floatingLabel else { return }
        let floating = isEditingActive || !text.isEmpty
        floatHolder.isHidden = !floating
        floatLabel.textColor = isEditingActive ? .appPrimary : config.labelColor
        let placeholder = floating ? (isEditingActive ? hint ?? "" : "") : config.placeholder
        textField?.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .font: UIFont.poppins(floating ? 12 : 14), .foregroundColor: floating ? UIColor.grey500 : config.labelColor,
        ])
        placeholderLabel.text = placeholder
    }

    private func updateBorder() {
        updateFloatingLabel()
        if isEditingActive {
            box.layer.borderColor = (hasError ? UIColor.appRedError : .appPrimary).cgColor
            box.layer.borderWidth = 1.5
        } else {
            box.layer.borderColor = (hasError ? UIColor.mRed300 : config.borderColor).cgColor
            box.layer.borderWidth = 1
        }
    }

    override func becomeFirstResponder() -> Bool {
        (textField as UIResponder?)?.becomeFirstResponder() ?? textView?.becomeFirstResponder() ?? false
    }

    override func resignFirstResponder() -> Bool {
        textField?.resignFirstResponder()
        textView?.resignFirstResponder()
        return true
    }

    // MARK: Filtering

    private func filtered(_ input: String) -> String {
        var s = input
        if config.digitsOnly { s = s.filter(\.isNumber) }
        if let allow = config.allow {
            s = s.filter { String($0).range(of: allow, options: .regularExpression) != nil }
        }
        if let deny = config.deny {
            s = s.replacingOccurrences(of: deny, with: "", options: .regularExpression)
        }
        return s
    }

    private func apply(range: NSRange, replacement: String, current: String) -> String? {
        let cleaned = filtered(replacement)
        guard let r = Range(range, in: current) else { return nil }
        var next = current.replacingCharacters(in: r, with: cleaned)
        if let max = config.maxLength, next.count > max {
            next = String(next.prefix(max))
        }
        return next
    }

    // MARK: UITextFieldDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        guard let next = apply(range: range, replacement: string, current: current) else { return false }
        let expected = (current as NSString).replacingCharacters(in: range, with: string)
        if next == expected { return true }
        textField.text = next
        editingChanged()
        return false
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        isEditingActive = true
        updateBorder()
        onBeginEditing?()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        isEditingActive = false
        updateBorder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let onSubmit { onSubmit() } else { textField.resignFirstResponder() }
        return true
    }

    @objc private func editingChanged() {
        if hasError { setError(nil) }
        onChange?(text)
    }

    // MARK: UITextViewDelegate

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text ?? ""
        guard let next = apply(range: range, replacement: text, current: current) else { return false }
        let expected = (current as NSString).replacingCharacters(in: range, with: text)
        if next == expected { return true }
        textView.text = next
        textViewDidChange(textView)
        return false
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        if hasError { setError(nil) }
        onChange?(text)
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        isEditingActive = true
        updateBorder()
        onBeginEditing?()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        isEditingActive = false
        updateBorder()
    }
}

extension UIColor {
    /// Flutter's default `InputDecoration` error colour (M3 `colorScheme.error`).
    static let appRedError = Scheme.error
}

// MARK: - Dropdown / picker field

/// Tappable `InputDecorator` showing a value or placeholder with a trailing arrow — the
/// `DropdownButtonFormField` / bottom-sheet picker fields used throughout the app.
final class SelectField: UIView {

    let box = UIView()
    private let valueLabel = UILabel()
    private let arrow = UIImageView(symbol: "chevron.down", size: 13, color: .grey600, weight: .semibold)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let iconView: UIImageView?
    let placeholder: String
    var onTap: (() -> Void)?
    var validator: (() -> String?)?

    var value: String? {
        didSet { refresh() }
    }

    var isEnabled = true {
        didSet { alpha = isEnabled ? 1 : 0.55 }
    }

    var isLoading = false {
        didSet {
            isLoading ? spinner.startAnimating() : spinner.stopAnimating()
            arrow.isHidden = isLoading
            refresh()
        }
    }

    var loadingText: String?
    var valueFont: UIFont = .poppins(14) { didSet { refresh() } }
    var placeholderColor: UIColor = .grey400 { didSet { refresh() } }
    /// Replaces the hint shown when empty (Flutter rebuilds hints from state).
    var placeholderOverride: String? { didSet { refresh() } }
    var valueColor: UIColor = .black87 { didSet { refresh() } }
    var borderColor: UIColor = .grey200 {
        didSet { box.layer.borderColor = borderColor.cgColor }
    }

    init(placeholder: String, icon: String? = nil, fill: UIColor = .appFieldFill) {
        self.placeholder = placeholder
        self.iconView = icon.map { UIImageView(symbol: $0, size: 18, color: .appPrimary) }
        super.init(frame: .zero)

        box.backgroundColor = fill
        box.layer.cornerRadius = 12
        box.layer.borderWidth = 1
        box.layer.borderColor = UIColor.grey200.cgColor

        valueLabel.numberOfLines = 2
        spinner.color = .appPrimary
        spinner.hidesWhenStopped = true

        var views: [UIView] = []
        if let iconView { iconView.setSize(width: 30); views.append(iconView) }
        views += [valueLabel, FlexSpacer(), spinner, arrow]
        let row = UIStackView.h(8, views)
        box.addSubview(row)
        row.pinToEdges(of: box, insets: UIEdgeInsets(top: 14, left: iconView == nil ? 16 : 10, bottom: 14, right: 14))
        box.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true

        errorLabel.font = .poppins(12)
        errorLabel.textColor = .appRedError
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let stack = UIStackView.v(6, [box, errorLabel])
        addSubview(stack)
        stack.pinToEdges(of: self)

        box.onTap { [weak self] in
            guard let self, self.isEnabled, !self.isLoading else { return }
            self.parentViewController?.view.endEditing(true)
            self.onTap?()
        }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func refresh() {
        if isLoading, let loadingText {
            valueLabel.text = loadingText
            valueLabel.font = .poppins(13)
            valueLabel.textColor = placeholderColor
        } else if let value, !value.isEmpty {
            valueLabel.text = value
            valueLabel.font = valueFont
            valueLabel.textColor = valueColor
            if errorLabel.isHidden == false { setError(nil) }
        } else {
            valueLabel.text = placeholderOverride ?? placeholder
            valueLabel.font = .poppins(14)
            valueLabel.textColor = placeholderColor
        }
    }

    @discardableResult
    func validate() -> Bool {
        let message = validator?()
        setError(message)
        return message == nil
    }

    func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
        box.layer.borderColor = (message == nil ? borderColor : .mRed300).cgColor
    }
}

// MARK: - InfoLabel

/// Port of lib/widgets/info_label.dart — label with a tappable ⓘ that opens a help dialog.
final class InfoLabel: UIView {
    init(_ label: String, helpTitle: String, helpMessage: String) {
        super.init(frame: .zero)
        let text = UILabel(label, font: .poppins(13, .semibold), color: .grey700, lines: 0)
        let icon = UIImageView(symbol: "info.circle", size: 14, color: .appPrimary)
        icon.onTap { [weak self] in
            guard let vc = self?.parentViewController else { return }
            AppDialog.show(on: vc, icon: "info.circle", iconColor: .appPrimary, iconSize: 20,
                           title: helpTitle, message: helpMessage,
                           actions: [.init(title: "OK", style: .text)])
        }
        let row = UIStackView.h(4, [text, icon, FlexSpacer()])
        addSubview(row)
        row.pinToEdges(of: self)
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// Plain field label (`Text(label, style: poppins(13, w600))`).
func fieldLabel(_ text: String, color: UIColor = .appTextDark, size: CGFloat = 13,
                weight: UIFont.PoppinsWeight = .semibold) -> UILabel {
    UILabel(text, font: .poppins(size, weight), color: color, lines: 0)
}

// MARK: - Buttons

/// `ElevatedButton` / `FilledButton` — orange, radius 14, height 52, white Poppins 16 w700,
/// with an in-place spinner while loading.
final class PrimaryButton: UIButton {

    private let spinner = UIActivityIndicatorView(style: .medium)
    private var fill: UIColor
    private let titleText: String

    var isLoading = false {
        didSet {
            isEnabled = !isLoading
            isLoading ? spinner.startAnimating() : spinner.stopAnimating()
            titleLabel?.alpha = isLoading ? 0 : 1
            imageView?.alpha = isLoading ? 0 : 1
            updateBackground()
        }
    }

    override var isEnabled: Bool { didSet { updateBackground() } }

    init(_ title: String, color: UIColor = .appPrimary, height: CGFloat = 52, radius: CGFloat = 14,
         fontSize: CGFloat = 16, weight: UIFont.PoppinsWeight = .bold, icon: String? = nil) {
        self.fill = color
        self.titleText = title
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        setTitleColor(.white, for: .normal)
        setTitleColor(.white, for: .disabled)
        titleLabel?.font = .poppins(fontSize, weight)
        layer.cornerRadius = radius
        clipsToBounds = true
        if let icon {
            setImage(.symbol(icon, size: 18, weight: .semibold), for: .normal)
            tintColor = .white
            configurationEdgeInsets()
        }
        spinner.color = .white
        spinner.hidesWhenStopped = true
        addSubview(spinner)
        spinner.center(in: self)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
        updateBackground()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configurationEdgeInsets() {
        semanticContentAttribute = .forceLeftToRight
        imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
    }

    func setColor(_ color: UIColor) {
        fill = color
        updateBackground()
    }

    private func updateBackground() {
        backgroundColor = (isEnabled && !isLoading) ? fill : fill.withAlphaComponent(0.6)
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.85 : 1 }
    }
}

/// `OutlinedButton` with a grey.shade300 border.
final class OutlineButton: UIButton {
    init(_ title: String, color: UIColor = .grey600, borderColor: UIColor = .grey300,
         height: CGFloat = 52, radius: CGFloat = 12, fontSize: CGFloat = 16, icon: String? = nil) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        setTitleColor(color, for: .normal)
        titleLabel?.font = .poppins(fontSize, .semibold)
        layer.cornerRadius = radius
        layer.borderWidth = 1
        layer.borderColor = borderColor.cgColor
        if let icon {
            setImage(.symbol(icon, size: 18, weight: .semibold), for: .normal)
            tintColor = color
            imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
            titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
        }
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isEnabled: Bool { didSet { alpha = isEnabled ? 1 : 0.5 } }
}

/// `TextButton` — plain coloured text.
func textButton(_ title: String, color: UIColor = .appPrimary, size: CGFloat = 13,
                weight: UIFont.PoppinsWeight = .semibold, action: @escaping () -> Void) -> UIButton {
    let b = UIButton(type: .system)
    b.setTitle(title, for: .normal)
    b.setTitleColor(color, for: .normal)
    b.setTitleColor(color.withAlphaComponent(0.4), for: .disabled)
    b.titleLabel?.font = .poppins(size, weight)
    b.onEvent(.touchUpInside, action)
    return b
}

/// Small round icon button (`IconButton`).
func iconButton(_ symbol: String, color: UIColor, size: CGFloat = 22, action: @escaping () -> Void) -> UIButton {
    let b = UIButton(type: .system)
    b.setImage(.symbol(symbol, size: size), for: .normal)
    b.tintColor = color
    b.setSize(width: 44, height: 44)
    b.onEvent(.touchUpInside, action)
    return b
}
