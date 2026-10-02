import UIKit

// MARK: - Dialog (Flutter `AlertDialog`, radius 16, icon + title row)

final class AppDialog: UIViewController {

    struct Action {
        enum Style { case text, filled, cancel, destructive }
        let title: String
        var style: Style = .text
        var color: UIColor? = nil
        var handler: (() -> Void)? = nil
    }

    private let card = UIView()
    private let contentStack = UIStackView.v(16, [])
    private let actionsRow = UIStackView.h(8, [])
    private let dismissible: Bool
    private var didRespond = false

    init(icon: String?, iconColor: UIColor, iconSize: CGFloat, title: String?, message: String?,
         customContent: UIView?, actions: [Action], dismissible: Bool) {
        self.dismissible = dismissible
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve

        var titleRowViews: [UIView] = []
        if let icon { titleRowViews.append(UIImageView(symbol: icon, size: iconSize, color: iconColor, weight: .medium)) }
        if let title {
            titleRowViews.append(UILabel(title, font: .poppins(16, .bold), color: .black87, lines: 0))
        }
        if !titleRowViews.isEmpty {
            contentStack.addArrangedSubview(UIStackView.h(10, titleRowViews))
        }
        if let message {
            let l = UILabel(message, font: .poppins(14), color: .black87.withAlphaComponent(0.8), lines: 0)
            l.setLineHeight(1.3)
            contentStack.addArrangedSubview(l)
        }
        if let customContent { contentStack.addArrangedSubview(customContent) }

        actionsRow.addArrangedSubview(FlexSpacer())
        for action in actions { actionsRow.addArrangedSubview(makeButton(action)) }
        if !actions.isEmpty {
            contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews.last ?? contentStack)
            contentStack.addArrangedSubview(actionsRow)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeButton(_ action: Action) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(action.title, for: .normal)
        b.titleLabel?.font = .poppins(14, .semibold)
        switch action.style {
        case .filled:
            b.backgroundColor = action.color ?? .appPrimary
            b.setTitleColor(.white, for: .normal)
            b.layer.cornerRadius = 10
            b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        case .cancel:
            b.setTitleColor(action.color ?? .grey600, for: .normal)
            b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        case .destructive:
            b.setTitleColor(action.color ?? .mRed600, for: .normal)
            b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        case .text:
            b.setTitleColor(action.color ?? .appPrimary, for: .normal)
            b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        }
        b.onEvent { [weak self] in
            guard let self, !self.didRespond else { return }
            self.didRespond = true
            self.dismiss(animated: true) { action.handler?() }
        }
        return b
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.54)

        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        view.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentStack)
        contentStack.pinToEdges(of: card, insets: UIEdgeInsets(top: 24, left: 24, bottom: 16, right: 16))
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor).withPriority(.defaultHigh),
            card.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -16),
            card.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            card.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -80).withPriority(.defaultHigh),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
        ])

        let backdrop = UIView()
        view.insertSubview(backdrop, belowSubview: card)
        backdrop.pinToEdges(of: view)
        backdrop.onTap { [weak self] in
            guard let self, self.dismissible else { return }
            self.view.endEditing(true)
            self.dismiss(animated: true)
        }
    }

    /// Dismisses the dialog programmatically (e.g. after a validated custom-content submit).
    func close(completion: (() -> Void)? = nil) {
        guard !didRespond else { return }
        didRespond = true
        dismiss(animated: true, completion: completion)
    }

    @discardableResult
    static func show(on vc: UIViewController, icon: String? = nil, iconColor: UIColor = .appPrimary,
                     iconSize: CGFloat = 26, title: String?, message: String? = nil,
                     content: UIView? = nil, actions: [Action], dismissible: Bool = true) -> AppDialog {
        let dialog = AppDialog(icon: icon, iconColor: iconColor, iconSize: iconSize, title: title,
                               message: message, customContent: content, actions: actions,
                               dismissible: dismissible)
        vc.topPresented.present(dialog, animated: true)
        return dialog
    }

    /// Async variant returning the index of the tapped action.
    @MainActor
    static func ask(on vc: UIViewController, icon: String? = nil, iconColor: UIColor = .appPrimary,
                    title: String?, message: String?, actions: [Action],
                    dismissible: Bool = false) async -> Int? {
        await withCheckedContinuation { continuation in
            var resumed = false
            let wrapped = actions.enumerated().map { index, action -> Action in
                var a = action
                let original = action.handler
                a.handler = {
                    original?()
                    if !resumed { resumed = true; continuation.resume(returning: index) }
                }
                return a
            }
            let dialog = show(on: vc, icon: icon, iconColor: iconColor, title: title, message: message,
                              actions: wrapped, dismissible: dismissible)
            dialog.onBackdropDismiss = {
                if !resumed { resumed = true; continuation.resume(returning: nil) }
            }
        }
    }

    var onBackdropDismiss: (() -> Void)?

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        let wasResponded = didRespond
        super.dismiss(animated: flag) { [weak self] in
            completion?()
            if !wasResponded { self?.onBackdropDismiss?() }
        }
    }
}

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

extension UIViewController {
    /// The top-most presented controller (so dialogs stack over sheets).
    var topPresented: UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }

    /// Generic error/info alert (`showDialog` with a single OK).
    func showAlert(title: String = "Error", message: String, action: String = "OK", handler: (() -> Void)? = nil) {
        AppDialog.show(on: self, title: title, message: message,
                       actions: [.init(title: action, style: .text, handler: handler)])
    }
}

// MARK: - Snackbar

enum SnackStyle {
    case error, success, info, warning

    var color: UIColor {
        switch self {
        case .error:   return .mRed600
        case .success: return .mGreen600
        case .info:    return .snackbarDark
        case .warning: return .mOrange700
        }
    }
}

/// Floating `SnackBar` (radius 10, bottom of the window).
enum Snackbar {
    private static weak var current: UIView?

    static func show(_ message: String, style: SnackStyle = .info, duration: TimeInterval = 3, in view: UIView? = nil) {
        guard let window = view?.window ?? UIApplication.shared.keyWindowInScene else { return }
        current?.removeFromSuperview()

        let container = UIView()
        container.backgroundColor = style.color
        container.layer.cornerRadius = 10
        container.alpha = 0
        let label = UILabel(message, font: .poppins(14), color: .white, lines: 0)
        container.addSubview(label)
        label.pinToEdges(of: container, insets: UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        window.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: window.keyboardLayoutGuide.topAnchor, constant: -16),
        ])
        current = container
        UIView.animate(withDuration: 0.25) { container.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.25, animations: { container.alpha = 0 }) { _ in
                container.removeFromSuperview()
            }
        }
    }
}

extension UIApplication {
    var keyWindowInScene: UIWindow? {
        connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

extension UIViewController {
    func snack(_ message: String, _ style: SnackStyle = .info, duration: TimeInterval = 3) {
        Snackbar.show(message, style: style, duration: duration, in: view)
    }
}

// MARK: - Bottom sheet

/// `showModalBottomSheet` — a white panel with rounded top corners sliding over a dimmed
/// backdrop, sized to its content (capped by `maxHeightFraction`) and lifted by the keyboard.
class BottomSheetController: UIViewController {

    let sheet = UIView()
    let contentStack = UIStackView.v(0, [])
    private let scrollView = UIScrollView()
    private let backdrop = UIView()
    var isDismissible = true
    var showsHandle = true
    var cornerRadius: CGFloat = 24
    var maxHeightFraction: CGFloat = 0.9
    /// Fixed fraction of the screen height (e.g. the 0.75 city picker); nil = fit content.
    var fixedHeightFraction: CGFloat?
    var contentInsets = UIEdgeInsets(top: 12, left: 24, bottom: 16, right: 24)
    var onDismiss: (() -> Void)?
    /// When false the content is pinned directly (for sheets embedding their own table view).
    var scrollsContent = true

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.54)
        view.addSubview(backdrop)
        backdrop.pinToEdges(of: view)
        backdrop.onTap { [weak self] in
            guard let self, self.isDismissible else { return }
            self.close()
        }

        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = cornerRadius
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false

        let handle = UIView()
        handle.backgroundColor = .grey300
        handle.layer.cornerRadius = 2
        handle.isHidden = !showsHandle
        handle.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(handle)

        // Extends the white panel under the home indicator.
        let bottomFill = UIView()
        bottomFill.backgroundColor = .white
        view.addSubview(bottomFill)
        bottomFill.translatesAutoresizingMaskIntoConstraints = false

        let container: UIView
        if scrollsContent {
            scrollView.alwaysBounceVertical = false
            scrollView.keyboardDismissMode = .interactive
            scrollView.addSubview(contentStack)
            contentStack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: contentInsets.top),
                contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: contentInsets.left),
                contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -contentInsets.right),
                contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -contentInsets.bottom),
                contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor,
                                                    constant: -(contentInsets.left + contentInsets.right)),
            ])
            let fit = scrollView.heightAnchor.constraint(equalTo: scrollView.contentLayoutGuide.heightAnchor)
            fit.priority = .defaultHigh
            fit.isActive = true
            container = scrollView
        } else {
            container = UIView()
            container.addSubview(contentStack)
            contentStack.pinToEdges(of: container, insets: contentInsets)
        }
        sheet.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            sheet.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            sheet.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: maxHeightFraction),

            handle.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: sheet.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 40),
            handle.heightAnchor.constraint(equalToConstant: showsHandle ? 4 : 0),

            container.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: showsHandle ? 8 : 4),
            container.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: sheet.safeAreaLayoutGuide.bottomAnchor),

            bottomFill.topAnchor.constraint(equalTo: sheet.bottomAnchor),
            bottomFill.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFill.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFill.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        if let fixedHeightFraction {
            sheet.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: fixedHeightFraction)
                .withPriority(.defaultHigh).isActive = true
        }
        buildContent()
    }

    /// Subclasses add their views to `contentStack` here.
    func buildContent() {}

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sheet.transform = CGAffineTransform(translationX: 0, y: 400)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.sheet.transform = .identity
        }
    }

    func close(completion: (() -> Void)? = nil) {
        view.endEditing(true)
        UIView.animate(withDuration: 0.2, animations: {
            self.sheet.transform = CGAffineTransform(translationX: 0, y: self.sheet.bounds.height + 40)
        })
        dismiss(animated: true) { [onDismiss] in
            completion?()
            onDismiss?()
        }
    }

    /// Header row with a title and a close (×) button.
    func addHeader(_ title: String, fontSize: CGFloat = 16, showClose: Bool = true) {
        var views: [UIView] = [UILabel(title, font: .poppins(fontSize, .bold), color: .black87, lines: 0), FlexSpacer()]
        if showClose {
            views.append(iconButton("xmark", color: .grey500, size: 18) { [weak self] in self?.close() })
        }
        contentStack.addArrangedSubview(UIStackView.h(8, views))
    }
}

// MARK: - Option picker sheet

/// Bottom-sheet list picker with an optional search box — used for every dropdown
/// (`DropdownButtonFormField`) and the city/ULB/zone selectors.
final class OptionPickerSheet: BottomSheetController, UITableViewDataSource, UITableViewDelegate {

    private let titleText: String
    private let options: [String]
    private let selectedIndex: Int?
    private let searchable: Bool
    private let onSelect: (Int) -> Void
    private var filtered: [Int]
    private let table = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel("No results found", font: .poppins(13), color: .grey400, alignment: .center)
    private let font: UIFont

    init(title: String, options: [String], selectedIndex: Int?, searchable: Bool,
         font: UIFont = .poppins(14), onSelect: @escaping (Int) -> Void) {
        self.titleText = title
        self.options = options
        self.selectedIndex = selectedIndex
        self.searchable = searchable
        self.onSelect = onSelect
        self.filtered = Array(options.indices)
        self.font = font
        super.init()
        scrollsContent = false
        contentInsets = UIEdgeInsets(top: 4, left: 12, bottom: 0, right: 12)
        let rows = CGFloat(options.count) * 52 + (searchable ? 70 : 0) + 70
        fixedHeightFraction = searchable || rows > 520 ? 0.75 : nil
        if fixedHeightFraction == nil {
            table.heightAnchor.constraint(equalToConstant: min(CGFloat(options.count) * 52, 420)).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func buildContent() {
        let header = UIStackView.h(8, [
            UILabel(titleText, font: .poppins(16, .bold), color: .black87, lines: 0), FlexSpacer(),
            iconButton("xmark", color: .grey500, size: 18) { [weak self] in self?.close() },
        ])
        contentStack.addArrangedSubview(header.padded(UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)))
        if searchable {
            var c = ENSTextField.Config()
            c.placeholder = "Search..."
            c.icon = "magnifyingglass"
            let search = ENSTextField(c)
            search.onChange = { [weak self] q in self?.filter(q) }
            contentStack.addArrangedSubview(search.padded(UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)))
        }
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 52
        table.separatorColor = .grey100
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.keyboardDismissMode = .onDrag
        table.backgroundView = emptyLabel
        emptyLabel.isHidden = !options.isEmpty
        contentStack.addArrangedSubview(table)
    }

    private func filter(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        filtered = q.isEmpty ? Array(options.indices) : options.indices.filter { options[$0].lowercased().contains(q) }
        emptyLabel.isHidden = !filtered.isEmpty
        table.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filtered.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let index = filtered[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = options[index]
        content.textProperties.font = font
        content.textProperties.color = .black87
        content.textProperties.numberOfLines = 2
        cell.contentConfiguration = content
        if index == selectedIndex {
            let check = UIImageView(symbol: "checkmark.circle.fill", size: 20, color: .appPrimary)
            check.sizeToFit()
            cell.accessoryView = check
        } else {
            cell.accessoryView = nil
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let index = filtered[indexPath.row]
        close { [onSelect] in onSelect(index) }
    }

    static func present(on vc: UIViewController, title: String, options: [String], selected: Int?,
                        searchable: Bool = false, font: UIFont = .poppins(14), onSelect: @escaping (Int) -> Void) {
        let sheet = OptionPickerSheet(title: title, options: options, selectedIndex: selected,
                                      searchable: searchable, font: font, onSelect: onSelect)
        vc.topPresented.present(sheet, animated: true)
    }
}

// MARK: - Loading overlay (`showDialog(barrierDismissible: false, CircularProgressIndicator)`)

final class LoadingOverlay {
    private static var current: UIViewController?

    static func show(on vc: UIViewController, message: String? = nil) {
        guard current == nil else { return }
        let overlay = UIViewController()
        overlay.modalPresentationStyle = .overFullScreen
        overlay.modalTransitionStyle = .crossDissolve
        overlay.view.backgroundColor = UIColor.black.withAlphaComponent(0.54)
        let box = UIView()
        box.backgroundColor = .white
        box.layer.cornerRadius = 16
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .appPrimary
        spinner.startAnimating()
        var views: [UIView] = [spinner]
        if let message { views.append(UILabel(message, font: .poppins(14, .medium), color: .black87, lines: 0, alignment: .center)) }
        let stack = UIStackView.v(14, alignment: .center, views)
        box.addSubview(stack)
        stack.pinToEdges(of: box, insets: UIEdgeInsets(top: 24, left: 28, bottom: 24, right: 28))
        overlay.view.addSubview(box)
        box.center(in: overlay.view)
        box.widthAnchor.constraint(lessThanOrEqualTo: overlay.view.widthAnchor, constant: -80).isActive = true
        current = overlay
        vc.topPresented.present(overlay, animated: true)
    }

    static func hide(completion: (() -> Void)? = nil) {
        guard let overlay = current else { completion?(); return }
        current = nil
        overlay.dismiss(animated: true, completion: completion)
    }

    /// Hides and waits for the dismissal so a follow-up presentation does not collide.
    @MainActor
    static func hideAsync() async {
        await withCheckedContinuation { c in hide { c.resume() } }
    }
}

// MARK: - Cards & small views

/// White rounded card with the standard soft shadow.
final class CardView: UIView {
    let stack: UIStackView

    init(radius: CGFloat = 16, padding: UIEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
         spacing: CGFloat = 0, background: UIColor = .white, shadowOpacity: Float = 0.05,
         shadowBlur: CGFloat = 15, shadowY: CGFloat = 8, border: UIColor? = nil) {
        stack = UIStackView.v(spacing, [])
        super.init(frame: .zero)
        backgroundColor = background
        layer.cornerRadius = radius
        if shadowOpacity > 0 { addShadow(opacity: shadowOpacity, blur: shadowBlur, offsetY: shadowY) }
        if let border { addBorder(color: border) }
        addSubview(stack)
        stack.pinToEdges(of: self, insets: padding)
    }

    required init?(coder: NSCoder) { fatalError() }
}

/// Rounded tinted square holding an icon (the orange "icon tiles").
func iconTile(_ symbol: String, color: UIColor = .appPrimary, background: UIColor = .appPrimaryLight,
              size: CGFloat = 46, iconSize: CGFloat = 24, radius: CGFloat = 12) -> UIView {
    let tile = UIView()
    tile.backgroundColor = background
    tile.layer.cornerRadius = radius
    tile.setSize(width: size, height: size)
    let icon = UIImageView(symbol: symbol, size: iconSize, color: color)
    tile.addSubview(icon)
    icon.center(in: tile)
    return tile
}

/// Thin divider line (`Divider`).
func divider(color: UIColor = .grey200, thickness: CGFloat = 1) -> UIView {
    let v = UIView()
    v.backgroundColor = color
    v.setSize(height: thickness)
    return v
}

/// Centered empty-state block (icon circle + title + subtitle).
func emptyState(icon: String, title: String, message: String?, iconColor: UIColor = .grey400,
                circle: UIColor = .white) -> UIView {
    let iconCircle = UIView()
    iconCircle.backgroundColor = circle
    iconCircle.layer.cornerRadius = 56
    iconCircle.setSize(width: 112, height: 112)
    iconCircle.addShadow(opacity: 0.03, blur: 20, offsetY: 0)
    let iv = UIImageView(symbol: icon, size: 52, color: iconColor)
    iconCircle.addSubview(iv)
    iv.center(in: iconCircle)
    var views: [UIView] = [iconCircle, UILabel(title, font: .poppins(18, .semibold), color: UIColor.Scheme.onSurface, lines: 0, alignment: .center)]
    if let message {
        views.append(UILabel(message, font: .poppins(14), color: UIColor.Scheme.onSurfaceVariant, lines: 0, alignment: .center))
    }
    let stack = UIStackView.v(8, alignment: .center, views)
    stack.setCustomSpacing(24, after: iconCircle)
    return stack
}

/// Pill badge (status chips).
func badge(_ text: String, color: UIColor, fontSize: CGFloat = 11, background: UIColor? = nil,
           bordered: Bool = false) -> UIView {
    let v = UIView()
    v.backgroundColor = background ?? color.withAlphaComponent(0.12)
    v.layer.cornerRadius = 8
    if bordered { v.addBorder(color: color) }
    let l = UILabel(text, font: .poppins(fontSize, .semibold), color: color)
    v.addSubview(l)
    l.pinToEdges(of: v, insets: UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
    v.setContentHuggingPriority(.required, for: .horizontal)
    v.setContentCompressionResistancePriority(.required, for: .horizontal)
    return v
}
