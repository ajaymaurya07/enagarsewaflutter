import UIKit

// Dependency-free port of the `tutorial_coach_mark` walkthroughs in lib/tour_guides/*.dart:
// a #111827 @ 85% overlay with a rounded-rect cutout around the target, a white card
// (icon tile + title + body) above or below it, and "SKIP TOUR" bottom-right. Tapping the
// target or the overlay advances (`onClickTarget` / `onClickOverlay` → `next()`).

enum TourSpotlightShape {
    case roundedRect(radius: CGFloat)
    case circle
}

/// `ContentAlign.top` / `ContentAlign.bottom`.
enum TourCardEdge { case top, bottom }

struct TourStep {
    let target: UIView
    let icon: String
    let title: String
    let description: String
    let shape: TourSpotlightShape
    let edge: TourCardEdge
    let padding: CGFloat
    /// Runs before the step is shown (e.g. switching the search mode so the target exists).
    var prepare: (() -> Void)?

    init(target: UIView, icon: String = "info.circle", title: String, description: String,
         shape: TourSpotlightShape = .roundedRect(radius: 12), edge: TourCardEdge = .bottom,
         padding: CGFloat = 10, prepare: (() -> Void)? = nil) {
        self.prepare = prepare
        self.target = target
        self.icon = icon
        self.title = title
        self.description = description
        self.shape = shape
        self.edge = edge
        self.padding = padding
    }
}

final class TourCoachMarkView: UIView {

    private static weak var active: TourCoachMarkView?

    private let steps: [TourStep]
    private var index = 0
    private var onFinish: (() -> Void)?
    private weak var scrollContainer: UIScrollView?

    private let dimLayer = CAShapeLayer()
    private let card = UIView()
    private let iconTileView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let skipButton = UIButton(type: .system)
    private var cardConstraint: NSLayoutConstraint?
    private var spotlight: CGRect = .zero

    static var isActive: Bool { active != nil }

    private init(steps: [TourStep], scrollContainer: UIScrollView?, onFinish: (() -> Void)?) {
        self.steps = steps
        self.scrollContainer = scrollContainer
        self.onFinish = onFinish
        super.init(frame: .zero)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Presents the walkthrough over the key window.
    /// - Parameter scrollContainer: when given, each target is scrolled into view first
    ///   (Flutter dashboard's `Scrollable.ensureVisible(alignment: 0.18)`).
    @discardableResult
    static func present(steps: [TourStep], scrollContainer: UIScrollView? = nil,
                        onFinish: (() -> Void)? = nil) -> TourCoachMarkView? {
        guard active == nil, !steps.isEmpty, let window = UIApplication.shared.keyWindowInScene else { return nil }
        let overlay = TourCoachMarkView(steps: steps, scrollContainer: scrollContainer, onFinish: onFinish)
        window.addSubview(overlay)
        overlay.pinToEdges(of: window)
        window.layoutIfNeeded()
        active = overlay
        overlay.alpha = 0
        overlay.showStep(animated: false)
        UIView.animate(withDuration: 0.25) { overlay.alpha = 1 }
        return overlay
    }

    private func build() {
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor(argb: 0xFF111827).withAlphaComponent(0.85).cgColor
        layer.addSublayer(dimLayer)
        let tap = UITapGestureRecognizer(target: self, action: #selector(advance))
        tap.delegate = self
        addGestureRecognizer(tap)

        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.addShadow(opacity: 0.12, blur: 12, offsetY: 4)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        iconTileView.backgroundColor = UIColor(argb: 0xFFFFF3E8)
        iconTileView.layer.cornerRadius = 10
        iconTileView.setSize(width: 38, height: 38)
        iconImageView.tintColor = .appPrimary
        iconImageView.contentMode = .center
        iconTileView.addSubview(iconImageView)
        iconImageView.center(in: iconTileView)

        titleLabel.font = .poppins(16, .bold)
        titleLabel.textColor = UIColor(argb: 0xFF111827)
        titleLabel.numberOfLines = 0
        bodyLabel.font = .poppins(13)
        bodyLabel.textColor = UIColor(argb: 0xFF4B5563)
        bodyLabel.numberOfLines = 0

        let stack = UIStackView.v(12, [UIStackView.h(12, [iconTileView, titleLabel]), bodyLabel])
        card.addSubview(stack)
        stack.pinToEdges(of: card, insets: UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18))

        skipButton.setTitle("SKIP TOUR", for: .normal)
        skipButton.titleLabel?.font = .poppins(13, .semibold)
        skipButton.setTitleColor(.white, for: .normal)
        skipButton.onEvent { [weak self] in self?.finish() }
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skipButton)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            skipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            skipButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    // MARK: Steps

    private func showStep(animated: Bool) {
        guard index < steps.count else { finish(); return }
        let step = steps[index]
        if let prepare = step.prepare {
            prepare()
            step.target.window?.layoutIfNeeded()
        }
        guard step.target.window != nil, !step.target.isHidden, step.target.bounds.width > 0 else {
            index += 1
            showStep(animated: animated)
            return
        }

        if let scroll = scrollContainer, step.target.isDescendant(of: scroll) {
            let rect = step.target.convert(step.target.bounds, to: scroll)
            let visibleHeight = scroll.bounds.height - scroll.adjustedContentInset.top - scroll.adjustedContentInset.bottom
            let maxOffset = max(-scroll.adjustedContentInset.top,
                                scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let desired = rect.minY - visibleHeight * 0.18 - scroll.adjustedContentInset.top
            let target = min(max(desired, -scroll.adjustedContentInset.top), maxOffset)
            if abs(scroll.contentOffset.y - target) > 1 {
                card.alpha = 0
                UIView.animate(withDuration: 0.45, delay: 0, options: .curveEaseInOut, animations: {
                    scroll.contentOffset.y = target
                }, completion: { _ in self.render(step, animated: animated) })
                return
            }
        }
        render(step, animated: animated)
    }

    private func render(_ step: TourStep, animated: Bool) {
        layoutIfNeeded()
        spotlight = step.target.convert(step.target.bounds, to: self).insetBy(dx: -step.padding, dy: -step.padding)

        let path = UIBezierPath(rect: bounds)
        switch step.shape {
        case .roundedRect(let radius):
            path.append(UIBezierPath(roundedRect: spotlight, cornerRadius: radius))
        case .circle:
            let d = max(spotlight.width, spotlight.height)
            path.append(UIBezierPath(ovalIn: CGRect(x: spotlight.midX - d / 2, y: spotlight.midY - d / 2, width: d, height: d)))
        }
        dimLayer.frame = bounds
        if animated, let old = dimLayer.path {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = old
            anim.toValue = path.cgPath
            anim.duration = 0.25
            dimLayer.add(anim, forKey: "path")
        }
        dimLayer.path = path.cgPath

        iconImageView.image = .symbol(step.icon, size: 20)
        titleLabel.text = step.title
        bodyLabel.text = step.description
        bodyLabel.setLineHeight(1.35)

        cardConstraint?.isActive = false
        let estimated: CGFloat = 170
        let below: Bool
        switch step.edge {
        case .bottom: below = bounds.height - spotlight.maxY >= estimated || bounds.height - spotlight.maxY > spotlight.minY
        case .top:    below = !(spotlight.minY >= estimated || spotlight.minY > bounds.height - spotlight.maxY)
        }
        if below {
            cardConstraint = card.topAnchor.constraint(equalTo: topAnchor,
                                                       constant: min(spotlight.maxY + 16, bounds.height - estimated - 60))
        } else {
            cardConstraint = card.bottomAnchor.constraint(equalTo: topAnchor, constant: max(spotlight.minY - 16, estimated))
        }
        cardConstraint?.isActive = true
        layoutIfNeeded()
        card.alpha = 0
        UIView.animate(withDuration: 0.2) { self.card.alpha = 1 }
    }

    @objc private func advance() {
        index += 1
        if index >= steps.count { finish() } else { showStep(animated: true) }
    }

    private func finish() {
        let callback = onFinish
        onFinish = nil
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
            callback?()
        }
    }
}

extension TourCoachMarkView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let p = touch.location(in: self)
        return !skipButton.frame.contains(p)
    }
}

/// Shared "show once" helper (SharedPreferences `tour_*` flag set before showing).
enum TourGuide {
    static func autoStartIfFirstVisit(_ key: TourKey, start: () -> Void) {
        guard !UserDefaultsService.shared.hasTourBeenSeen(key) else { return }
        UserDefaultsService.shared.markTourSeen(key)
        start()
    }
}
