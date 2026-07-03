import UIKit

// MARK: - TourCoachMark
//
// A from-scratch, dependency-free re-implementation of the spotlight coach-mark
// walkthrough used on the Flutter side (`tutorial_coach_mark` package, see
// `lib/tour_guides/*.dart`). Presents a full-screen dimmed overlay with a
// rounded-rect/circle cutout ("spotlight") around a target view, plus a small
// text bubble with an icon, title, description, and Next/Skip controls.
//
// Usage (mirrors Flutter's `XyzTourGuide.buildSteps` + `createCoachMark`):
//
//   let steps = [
//       TourStep(target: propertyTaxCard, icon: "house.circle",
//                title: "Property Tax", description: "…"),
//       TourStep(target: bottomNavBar, icon: "arrow.left.arrow.right",
//                edge: .top, description: "…"),
//   ]
//   TourCoachMarkView.present(steps: steps) {
//       UserDefaultsService.shared.markTourSeen(.dashboard)
//   }

/// Spotlight cutout shape around the highlighted view.
enum TourSpotlightShape {
    case roundedRect(radius: CGFloat)
    case circle
}

/// Which side of the target the text bubble prefers to sit on.
/// Mirrors Flutter's `ContentAlign.top` / `ContentAlign.bottom`.
enum TourCardEdge {
    case top
    case bottom
}

/// One step of a coach-mark walkthrough.
struct TourStep {
    let target: UIView
    let icon: String
    let title: String
    let description: String
    let shape: TourSpotlightShape
    let edge: TourCardEdge
    /// Extra spotlight padding around the target's bounds (Flutter default paddingFocus: 10).
    let padding: CGFloat

    init(target: UIView,
         icon: String = "info.circle",
         title: String,
         description: String,
         shape: TourSpotlightShape = .roundedRect(radius: 14),
         edge: TourCardEdge = .bottom,
         padding: CGFloat = 10) {
        self.target = target
        self.icon = icon
        self.title = title
        self.description = description
        self.shape = shape
        self.edge = edge
        self.padding = padding
    }
}

/// Full-screen coach-mark overlay. Presented over the key window so it covers
/// navigation bars, tab bars, and the status bar — same visual effect as the
/// Flutter package's `TutorialCoachMark`.
final class TourCoachMarkView: UIView {

    private var steps: [TourStep]
    private var index = 0
    private var onFinish: (() -> Void)?

    private let dimLayer = CAShapeLayer()
    private let cardContainer = UIView()
    private let iconBubble = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let nextButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    private let progressLabel = UILabel()

    private var cardTopConstraint: NSLayoutConstraint?
    private var cardBottomConstraint: NSLayoutConstraint?

    // MARK: Init

    private init(steps: [TourStep], onFinish: (() -> Void)?) {
        self.steps = steps
        self.onFinish = onFinish
        super.init(frame: .zero)
        setupOverlay()
        setupCard()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Public entry point

    /// Presents the coach mark over the current key window.
    /// - Parameters:
    ///   - steps: Ordered walkthrough steps. If empty, this is a no-op.
    ///   - onFinish: Called once when the tour is dismissed, whether by
    ///     finishing the last step, tapping "Skip", or tapping the overlay
    ///     past the final step. Callers should mark the tour as seen here
    ///     (e.g. `UserDefaultsService.shared.markTourSeen(.dashboard)`).
    @discardableResult
    static func present(steps: [TourStep], onFinish: (() -> Void)? = nil) -> TourCoachMarkView? {
        guard !steps.isEmpty else { return nil }
        guard let window = currentKeyWindow() else { return nil }

        let overlay = TourCoachMarkView(steps: steps, onFinish: onFinish)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: window.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: window.bottomAnchor),
        ])
        overlay.alpha = 0
        window.layoutIfNeeded()
        UIView.animate(withDuration: 0.25) { overlay.alpha = 1 }
        overlay.renderStep(animated: false)
        return overlay
    }

    private static func currentKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    // MARK: Setup

    private func setupOverlay() {
        backgroundColor = .clear
        dimLayer.fillRule = .evenOdd
        // #111827 @ 0.85, matches Flutter's colorShadow/opacityShadow.
        dimLayer.fillColor = UIColor(red: 0.067, green: 0.075, blue: 0.094, alpha: 0.85).cgColor
        layer.addSublayer(dimLayer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    private func setupCard() {
        cardContainer.backgroundColor = .white
        cardContainer.layer.cornerRadius = 16
        cardContainer.addCardShadow()
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardContainer)

        iconBubble.backgroundColor = UIColor(red: 1.0, green: 0.953, blue: 0.910, alpha: 1) // #FFF3E8
        iconBubble.layer.cornerRadius = 10
        iconBubble.translatesAutoresizingMaskIntoConstraints = false

        iconImageView.tintColor = .appPrimary
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconBubble.addSubview(iconImageView)

        titleLabel.font = UIFont(name: "Poppins-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor(red: 0.067, green: 0.075, blue: 0.094, alpha: 1) // #111827
        titleLabel.numberOfLines = 0

        bodyLabel.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        bodyLabel.textColor = UIColor(red: 0.294, green: 0.333, blue: 0.388, alpha: 1) // #4B5563
        bodyLabel.numberOfLines = 0

        progressLabel.font = UIFont(name: "Poppins-Medium", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        progressLabel.textColor = UIColor(red: 0.612, green: 0.639, blue: 0.686, alpha: 1)

        skipButton.setTitle("SKIP TOUR", for: .normal)
        skipButton.titleLabel?.font = UIFont(name: "Poppins-SemiBold", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold)
        skipButton.setTitleColor(.white, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skipButton)

        nextButton.titleLabel?.font = UIFont(name: "Poppins-SemiBold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold)
        nextButton.setTitleColor(.appPrimary, for: .normal)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.setContentHuggingPriority(.required, for: .horizontal)
        nextButton.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = UIStackView(arrangedSubviews: [iconBubble, titleLabel])
        headerRow.axis = .horizontal
        headerRow.spacing = 12
        headerRow.alignment = .center

        let footerSpacer = UIView()
        let footerRow = UIStackView(arrangedSubviews: [progressLabel, footerSpacer, nextButton])
        footerRow.axis = .horizontal
        footerRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [headerRow, bodyLabel, footerRow])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            iconBubble.widthAnchor.constraint(equalToConstant: 38),
            iconBubble.heightAnchor.constraint(equalToConstant: 38),
            iconImageView.centerXAnchor.constraint(equalTo: iconBubble.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBubble.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            stack.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -18),

            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            skipButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            skipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }

    // MARK: Rendering a step

    private func renderStep(animated: Bool) {
        guard index < steps.count else { finish(); return }
        let step = steps[index]

        // If the target has been removed from the hierarchy (e.g. section is
        // hidden/collapsed for this user), skip straight to the next step
        // rather than spotlighting a zero-sized rect.
        guard step.target.window != nil, step.target.bounds.width > 0, step.target.bounds.height > 0 else {
            advance()
            return
        }

        setNeedsLayout()
        layoutIfNeeded()

        var rect = step.target.convert(step.target.bounds, to: self)
        rect = rect.insetBy(dx: -step.padding, dy: -step.padding)

        let path = UIBezierPath(rect: bounds)
        let spotlightPath: UIBezierPath
        switch step.shape {
        case .roundedRect(let radius):
            spotlightPath = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        case .circle:
            let diameter = max(rect.width, rect.height)
            let square = CGRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2, width: diameter, height: diameter)
            spotlightPath = UIBezierPath(ovalIn: square)
        }
        path.append(spotlightPath)
        path.usesEvenOddFillRule = true

        dimLayer.frame = bounds
        if animated, let oldPath = dimLayer.path {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = oldPath
            anim.toValue = path.cgPath
            anim.duration = 0.25
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dimLayer.add(anim, forKey: "spotlightPath")
        }
        dimLayer.path = path.cgPath

        iconImageView.image = UIImage(systemName: step.icon)
        titleLabel.text = step.title
        bodyLabel.text = step.description
        progressLabel.text = "\(index + 1) / \(steps.count)"
        nextButton.setTitle(index == steps.count - 1 ? "DONE" : "NEXT", for: .normal)

        positionCard(around: rect, edge: step.edge)

        if animated {
            cardContainer.alpha = 0
            UIView.animate(withDuration: 0.2) { self.cardContainer.alpha = 1 }
        }
    }

    private func positionCard(around rect: CGRect, edge: TourCardEdge) {
        cardTopConstraint?.isActive = false
        cardBottomConstraint?.isActive = false

        let margin: CGFloat = 16
        // Rough height estimate used only for flip/clamp decisions; the card
        // itself is auto-sized by Auto Layout once positioned.
        let estimatedHeight: CGFloat = 170
        let spaceBelow = bounds.height - rect.maxY
        let spaceAbove = rect.minY

        let placeBelow: Bool
        switch edge {
        case .bottom:
            placeBelow = spaceBelow >= estimatedHeight || spaceBelow >= spaceAbove
        case .top:
            placeBelow = !(spaceAbove >= estimatedHeight || spaceAbove > spaceBelow)
        }

        if placeBelow {
            let maxTop = bounds.height - estimatedHeight - margin
            let top = min(rect.maxY + margin, max(margin, maxTop))
            let c = cardContainer.topAnchor.constraint(equalTo: topAnchor, constant: top)
            c.isActive = true
            cardTopConstraint = c
        } else {
            // Anchor the card's *bottom* edge above the target; Auto Layout
            // then grows the (auto-sized) card upward from that fixed edge,
            // so this stays correct regardless of the card's real height.
            let minBottom = estimatedHeight + margin
            let bottom = max(rect.minY - margin, minBottom)
            let c = cardContainer.bottomAnchor.constraint(equalTo: topAnchor, constant: bottom)
            c.isActive = true
            cardBottomConstraint = c
        }
    }

    // MARK: Actions

    @objc private func overlayTapped() { advance() }
    @objc private func nextTapped() { advance() }
    @objc private func skipTapped() { finish() }

    private func advance() {
        index += 1
        if index >= steps.count {
            finish()
        } else {
            renderStep(animated: true)
        }
    }

    private func finish() {
        let callback = onFinish
        onFinish = nil
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
            callback?()
        })
    }
}

// MARK: - UIGestureRecognizerDelegate

extension TourCoachMarkView: UIGestureRecognizerDelegate {
    /// Let taps on the card (title/body/Next button) or the Skip button reach
    /// their own controls instead of also advancing the tour via the
    /// overlay-wide tap recognizer.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        return !cardContainer.frame.contains(point) && !skipButton.frame.contains(point)
    }
}
