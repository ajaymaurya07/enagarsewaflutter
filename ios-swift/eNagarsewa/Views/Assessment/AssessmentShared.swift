import UIKit

/// Shared widgets of the assessment / reassessment screens (white fields with grey.shade300
/// borders, floating labels, `_sectionTitle`, info cards, list cards …).
enum AssessmentUI {

    static let textColor = UIColor.appTextDark
    static let softPrimary = UIColor(argb: 0xFFFFF4E8)

    static func textField(_ label: String, required: Bool = false, keyboard: UIKeyboardType = .default,
                          digitsOnly: Bool = false, lines: Int = 1, hint: String? = nil,
                          floating: Bool = true) -> ENSTextField {
        var c = ENSTextField.Config()
        c.placeholder = floating ? label : (hint ?? label)
        c.floatingLabel = floating
        c.keyboard = keyboard
        c.digitsOnly = digitsOnly
        c.lines = lines
        c.fill = .white
        c.borderColor = .grey300
        c.labelColor = .grey600
        c.textColor = textColor
        let f = ENSTextField(c)
        if required {
            f.validator = { $0.trimmingCharacters(in: .whitespaces).isEmpty ? "Please enter \(label)" : nil }
        }
        return f
    }

    static func selectField(_ placeholder: String) -> SelectField {
        let f = SelectField(placeholder: placeholder, fill: .white)
        f.borderColor = .grey300
        f.placeholderColor = .grey600
        f.valueColor = textColor
        return f
    }

    static func labeled(_ label: String, _ field: UIView) -> UIView {
        UIStackView.v(6, [UILabel(label, font: .poppins(13), color: .grey700, lines: 0), field])
    }

    static func sectionTitle(_ text: String, icon: String? = nil, size: CGFloat = 16) -> UIView {
        let label = UILabel(text, font: .poppins(size, .bold), color: textColor, lines: 0)
        guard let icon else { return label }
        return UIStackView.h(10, [iconTile(icon, background: softPrimary, size: 28, iconSize: 14, radius: 8), label, FlexSpacer()])
    }

    static func readOnlyBox(_ value: String) -> UIView {
        let v = UILabel(value, font: .poppins(14), color: textColor, lines: 0)
            .padded(UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16))
        v.backgroundColor = UIColor(argb: 0xFFF3F4F6)
        v.layer.cornerRadius = 12
        v.addBorder(color: .grey300)
        return v
    }

    /// Label (flex 4) / value (flex 6, right aligned) rows separated by dividers.
    static func infoCard(_ rows: [(String, String, Bool)], krutidev: Bool, padding: CGFloat = 12,
                         border: UIColor = .grey200, labelFont: UIFont = .poppins(12)) -> UIView {
        let card = CardView(radius: 12, padding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
                            shadowOpacity: 0, border: border)
        for (i, row) in rows.enumerated() {
            if i > 0 { card.stack.add(divider(color: .grey300, thickness: 0.5).padded(UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0))) }
            let l = UILabel(row.0, font: labelFont, color: .grey600, lines: 0)
            let v = UILabel(row.1, font: UlbLanguageHelper.font(13, .semibold, krutidev: row.2 && krutidev),
                            color: textColor, lines: 0, alignment: .right)
            let r = UIStackView.h(0, alignment: .top, [l, v])
            l.widthAnchor.constraint(equalTo: v.widthAnchor, multiplier: 4.0 / 6.0).isActive = true
            card.stack.add(r)
        }
        return card
    }

    static func actionButton(_ title: String, icon: String? = nil) -> PrimaryButton {
        PrimaryButton(title, height: 48, radius: 12, fontSize: 15, weight: .semibold, icon: icon)
    }

    /// Icon circle + title + subtitle (+ Retry) used for empty / error states.
    static func messageState(icon: String, title: String, subtitle: String, retry: (() -> Void)?) -> UIView {
        var views: [UIView] = [
            iconTile(icon, background: softPrimary, size: 84, iconSize: 40, radius: 42),
            UILabel(title, font: .poppins(16, .bold), color: textColor, lines: 0, alignment: .center),
            UILabel(subtitle, font: .poppins(13), color: .grey600, lines: 0, alignment: .center),
        ]
        if let retry {
            let b = PrimaryButton("Retry", height: 46, radius: 12, fontSize: 14, weight: .semibold, icon: "arrow.clockwise")
            b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
            b.onEvent(retry)
            views.append(b)
        }
        let stack = UIStackView.v(0, alignment: .center, views)
        stack.setCustomSpacing(20, after: views[0])
        stack.setCustomSpacing(8, after: views[1])
        stack.setCustomSpacing(20, after: views[2])
        return stack.padded(UIEdgeInsets(top: 40, left: 16, bottom: 40, right: 16))
    }

    static func statusChip(completed: Bool) -> UIView {
        let color = completed ? UIColor(argb: 0xFF1E9E5A) : .appPrimary
        let row = UIStackView.h(4, [
            UIImageView(symbol: completed ? "checkmark.circle.fill" : "hourglass.bottomhalf.filled", size: 11, color: color),
            UILabel(completed ? "Completed" : "In Progress", font: .poppins(11, .semibold), color: color),
        ]).padded(UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10))
        row.backgroundColor = color.withAlphaComponent(0.1)
        row.layer.cornerRadius = 12
        row.setContentHuggingPriority(.required, for: .horizontal)
        row.setContentCompressionResistancePriority(.required, for: .horizontal)
        return row
    }

    static func outlineAction(_ title: String, icon: String, color: UIColor) -> OutlineButton {
        let b = OutlineButton(title, color: color, borderColor: color, height: 40, radius: 10, fontSize: 13, icon: icon)
        b.setImage(.symbol(icon, size: 14, weight: .semibold), for: .normal)
        return b
    }
}

/// "Step X of Y" + percentage bar (lib/widgets/assessment_progress_bar.dart).
final class AssessmentProgressBar: UIView {
    init(step: Int, total: Int) {
        super.init(frame: .zero)
        backgroundColor = .white
        let progress = min(max(Double(step - 1) / Double(total), 0), 1)
        let percent = Int((progress * 100).rounded())
        let track = UIView()
        track.backgroundColor = UIColor(argb: 0xFFF3F4F6)
        track.layer.cornerRadius = 3
        track.clipsToBounds = true
        track.setSize(height: 6)
        let fill = UIView()
        fill.backgroundColor = .appPrimary
        track.addSubview(fill)
        fill.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: max(CGFloat(progress), 0.0001)),
        ])
        let row = UIStackView.h(8, [
            UILabel("Step \(step) of \(total)", font: .poppins(12), color: .grey600), FlexSpacer(),
            UILabel("\(percent)% Complete", font: .poppins(12, .semibold), color: .appPrimary),
        ])
        let stack = UIStackView.v(6, [row, track])
        addSubview(stack)
        stack.pinToEdges(of: self, insets: UIEdgeInsets(top: 0, left: 16, bottom: 14, right: 16))
    }

    required init?(coder: NSCoder) { fatalError() }
}

/// Base for the in-flow assessment screens: white app bar with an orange back chevron, the
/// progress bar, and `PopScope(canPop: false)` → "Close Assessment?" confirmation that exits
/// to the dashboard (lib/services/assessment_exit_guard.dart).
class AssessmentFlowViewController: BaseViewController {

    override var screenBackground: UIColor { .appFieldFill }

    let progressStep: Int
    let progressTotal: Int
    let screenTitle: String
    var showsProgress = true
    private(set) var progressView: UIView?

    init(title: String, step: Int, total: Int) {
        self.screenTitle = title
        self.progressStep = step
        self.progressTotal = total
        super.init(nibName: nil, bundle: nil)
        interceptsBack = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNav(title: screenTitle, titleColor: AssessmentUI.textColor, backColor: .appPrimary,
                     titleSize: 17, titleWeight: .semibold)
        if showsProgress {
            let bar = AssessmentProgressBar(step: progressStep, total: progressTotal)
            view.addSubview(bar)
            bar.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            progressView = bar
        }
    }

    /// Bottom "Continue" bar (`bottomNavigationBar: SafeArea(Padding(16, button))`).
    func installBottomButton(_ button: UIButton) -> UIView {
        let bar = UIView()
        bar.backgroundColor = screenBackground
        bar.addSubview(button)
        view.addSubview(bar)
        bar.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            button.topAnchor.constraint(equalTo: bar.topAnchor, constant: 16),
            button.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            button.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -16),
        ])
        return bar
    }

    override func handleBack() {
        AssessmentExitGuard.handleBack(from: self)
    }
}

/// Port of lib/services/assessment_exit_guard.dart.
@MainActor
enum AssessmentExitGuard {

    static func handleBack(from vc: UIViewController) {
        var responded = false
        AppDialog.show(on: vc, icon: "exclamationmark.triangle", iconColor: .appPrimary, iconSize: 26,
                       title: "Close Assessment?",
                       message: "Are you sure you want to close this assessment? Your progress will be lost.",
                       actions: [
                        .init(title: "Cancel", style: .cancel, color: .grey700) { responded = true },
                        .init(title: "Close", style: .filled) {
                            guard !responded else { return }
                            responded = true
                            exitToDashboard(from: vc)
                        },
                       ], dismissible: false)
    }

    /// `Navigator.popUntil((route) => route.isFirst)` — skipped while a session-expiry
    /// teardown is replacing the stack.
    static func exitToDashboard(from vc: UIViewController) {
        guard !SessionManager.shared.isHandlingSessionExpiry else { return }
        vc.navigationController?.popToRootViewController(animated: true)
    }
}
