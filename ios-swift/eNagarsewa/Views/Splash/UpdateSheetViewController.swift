import UIKit

/// Non-dismissible "Update Available" bottom sheet.
/// Mirrors Flutter's `_showUpdateSheet()` in splash_screen.dart: a modal bottom sheet that
/// cannot be swiped away or tapped-through — the only way out is tapping "Update Now", which
/// opens the App Store listing. There is no "Later" / soft-update variant on either platform:
/// Flutter only ever shows this one (force) style, so this view has no dismiss affordance.
final class UpdateSheetViewController: UIViewController {

    private let updateInfo: AppUpdateService.UpdateInfo

    init(updateInfo: AppUpdateService.UpdateInfo) {
        self.updateInfo = updateInfo
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
        isModalInPresentation  = true // blocks swipe-to-dismiss
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private let dimmingView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 28
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let handleBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.85, alpha: 1) // grey.shade300
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.appPrimary.withAlphaComponent(0.1)
        v.layer.cornerRadius = 36
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "arrow.down.circle.fill"))
        iv.tintColor = .appPrimary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Update Available"
        l.font = UIFont(name: "Poppins-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        l.textColor = UIColor(red: 0.102, green: 0.102, blue: 0.180, alpha: 1) // #1A1A2E
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "Poppins-Regular", size: 13) ?? .systemFont(ofSize: 13)
        l.textColor = UIColor(white: 0.459, alpha: 1) // grey.shade600
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let updateButton: UIButton = {
        let b = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .appPrimary
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: "arrow.down.to.line")
        config.imagePadding = 10
        config.cornerStyle = .fixed
        config.background.cornerRadius = 14
        config.attributedTitle = AttributedString("Update Now", attributes: AttributeContainer([
            .font: UIFont(name: "Poppins-SemiBold", size: 15) ?? UIFont.boldSystemFont(ofSize: 15),
        ]))
        b.configuration = config
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        subtitleLabel.text = "A new version of e-Nagarsewa is available " +
            "with improvements and important security updates. Please update to continue."
        setupLayout()
        updateButton.addTarget(self, action: #selector(updateNowTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        view.addSubview(dimmingView)
        view.addSubview(cardView)

        iconContainer.addSubview(iconView)
        cardView.addSubview(handleBar)
        cardView.addSubview(iconContainer)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(updateButton)

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            handleBar.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            handleBar.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 40),
            handleBar.heightAnchor.constraint(equalToConstant: 4),

            iconContainer.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 28),
            iconContainer.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 72),
            iconContainer.heightAnchor.constraint(equalToConstant: 72),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),

            updateButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            updateButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 28),
            updateButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -28),
            updateButton.heightAnchor.constraint(equalToConstant: 52),
            updateButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36),
        ])
    }

    // MARK: - Actions

    @objc private func updateNowTapped() {
        UIApplication.shared.open(updateInfo.storeURL, options: [:], completionHandler: nil)
    }
}
