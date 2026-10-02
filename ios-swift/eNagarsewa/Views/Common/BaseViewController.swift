import UIKit

/// Navigation controller that keeps the swipe-back gesture working with custom back buttons
/// and lets a screen veto it (Flutter `PopScope(canPop: false)`).
final class AppNavigationController: UINavigationController, UIGestureRecognizerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer, viewControllers.count > 1 else { return false }
        if let top = topViewController as? BaseViewController, top.interceptsBack || top.blocksBackNavigation {
            return false
        }
        return true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        topViewController?.preferredStatusBarStyle ?? .darkContent
    }

    /// Flutter `Navigator.pushAndRemoveUntil(..., (route) => false)`.
    func setRoot(_ vc: UIViewController, animated: Bool = true) {
        setViewControllers([vc], animated: animated)
    }

    /// `Navigator.popUntil((route) => route.isFirst)`.
    func popToFirst(animated: Bool = true) {
        popToRootViewController(animated: animated)
    }
}

/// Base screen: a Flutter-style `AppBar` (custom back chevron, Poppins title, optional
/// actions) and an optional scrolling column (`SingleChildScrollView(child: Column(...))`).
class BaseViewController: UIViewController {

    /// `Scaffold.backgroundColor`
    var screenBackground: UIColor { .white }

    /// When true the back button / swipe call `handleBack()` instead of popping.
    var interceptsBack = false
    /// Temporarily blocks back navigation entirely (e.g. while a tour overlay is up).
    var blocksBackNavigation = false

    /// Hides the navigation bar (screens that draw their own header).
    var hidesNavigationBar: Bool { false }

    private(set) lazy var scrollView: UIScrollView = {
        let s = UIScrollView()
        s.alwaysBounceVertical = true
        s.keyboardDismissMode = .interactive
        s.showsVerticalScrollIndicator = false
        return s
    }()

    private(set) lazy var contentStack = UIStackView.v(0, [])

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = screenBackground
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(hidesNavigationBar, animated: animated)
    }

    @objc func dismissKeyboard() { view.endEditing(true) }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    // MARK: - App bar

    /// Configures the navigation bar like the screen's Flutter `AppBar`.
    func configureNav(title: String?, background: UIColor = .white, titleColor: UIColor = .black87,
                      backColor: UIColor? = nil, titleSize: CGFloat = 18,
                      titleWeight: UIFont.PoppinsWeight = .bold, centerTitle: Bool = true,
                      showsBack: Bool = true, rightItems: [UIBarButtonItem] = []) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.font: UIFont.poppins(titleSize, titleWeight), .foregroundColor: titleColor]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance

        var left: [UIBarButtonItem] = []
        if showsBack {
            let back = UIBarButtonItem(image: .symbol("chevron.backward", size: 18, weight: .semibold),
                                       style: .plain, target: self, action: #selector(backTapped))
            back.tintColor = backColor ?? titleColor
            left.append(back)
        }
        if centerTitle {
            navigationItem.title = title
            navigationItem.titleView = nil
        } else {
            navigationItem.title = nil
            let label = UILabel(title, font: .poppins(titleSize, titleWeight), color: titleColor)
            left.append(UIBarButtonItem(customView: label))
        }
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItems = left
        navigationItem.rightBarButtonItems = Array(rightItems.reversed())
    }

    /// The orange "?" tour-guide action.
    func helpItem(color: UIColor = .appPrimary, action: @escaping () -> Void) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: .symbol("questionmark.circle", size: 20), primaryAction: UIAction { _ in action() })
        item.tintColor = color
        return item
    }

    func barItem(_ symbol: String, color: UIColor, size: CGFloat = 20, action: @escaping () -> Void) -> UIBarButtonItem {
        let item = UIBarButtonItem(image: .symbol(symbol, size: size), primaryAction: UIAction { _ in action() })
        item.tintColor = color
        return item
    }

    @objc private func backTapped() {
        guard !blocksBackNavigation else { return }
        if interceptsBack { handleBack() } else { navigationController?.popViewController(animated: true) }
    }

    /// Override for `PopScope(onPopInvoked:)` screens.
    func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Scrolling column

    /// Installs `scrollView` + `contentStack` filling the safe area (bottom follows the keyboard).
    func installScrollStack(insets: UIEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16),
                            spacing: CGFloat = 0, below topView: UIView? = nil, above bottomView: UIView? = nil) {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.spacing = spacing
        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topView?.bottomAnchor ?? view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomView?.topAnchor ?? view.keyboardLayoutGuide.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: insets.top),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: insets.left),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -insets.right),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -insets.bottom),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(insets.left + insets.right)),
        ])
    }

    /// Centered spinner used while a screen loads its first data.
    private(set) lazy var loadingView: UIView = {
        let v = UIView()
        v.backgroundColor = screenBackground
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .appPrimary
        spinner.startAnimating()
        v.addSubview(spinner)
        spinner.center(in: v)
        return v
    }()

    func setLoading(_ loading: Bool) {
        if loading {
            if loadingView.superview == nil {
                view.addSubview(loadingView)
                loadingView.pinToSafeArea(of: view)
            }
            view.bringSubviewToFront(loadingView)
            loadingView.isHidden = false
        } else {
            loadingView.isHidden = true
        }
    }

    // MARK: - Navigation helpers

    var appNavigation: AppNavigationController? { navigationController as? AppNavigationController }

    func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
    }
}

/// A full-width row inside a stack that stays centered (Flutter `Center`).
func centered(_ view: UIView) -> UIView {
    let container = UIView()
    container.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        view.topAnchor.constraint(equalTo: container.topAnchor),
        view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        view.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
    ])
    return container
}
