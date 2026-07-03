import UIKit
import Combine

final class TrackGrievanceViewController: UIViewController {

    private let viewModel: TrackGrievanceViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: TrackGrievanceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private lazy var numberField = UITextField.styledTextField(placeholder: "Enter grievance number")
    private lazy var trackButton = UIButton.primaryButton(title: "Track")
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var didPresentTour = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Track Grievance"
        view.backgroundColor = .appBackground

        activityIndicator.hidesWhenStopped = true; activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        trackButton.addTarget(self, action: #selector(trackTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [numberField, trackButton, activityIndicator])
        stack.axis = .vertical; stack.spacing = 20; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([
            trackButton.heightAnchor.constraint(equalToConstant: 50),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])

        viewModel.$isLoading.receive(on: DispatchQueue.main).sink { [weak self] l in
            l ? self?.activityIndicator.startAnimating() : self?.activityIndicator.stopAnimating()
            self?.trackButton.isEnabled = !l
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            if let msg { self?.showAlert(message: msg) }
        }.store(in: &cancellables)
    }

    @objc private func trackTapped() {
        view.endEditing(true)
        viewModel.grievanceNumber = numberField.text ?? ""
        viewModel.track()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentTourIfNeeded()
    }

    // MARK: - Tour guide (first-run coach mark, see lib/tour_guides/track_grievance_tour.dart)
    // Note: Flutter's TrackGrievanceScreen is a chooser with "Apply Now" and
    // "Track Status" cards that navigate elsewhere; this native screen instead
    // tracks a grievance inline by number, so the steps are adapted to the
    // number field and Track button rather than two navigation cards.

    private func presentTourIfNeeded() {
        guard !didPresentTour, !UserDefaultsService.shared.hasTourBeenSeen(.trackGrievance) else { return }
        didPresentTour = true

        let steps: [TourStep] = [
            TourStep(target: numberField, icon: "number",
                     title: "Grievance Number",
                     description: "Enter the grievance number you received when the request was raised.",
                     edge: .bottom),
            TourStep(target: trackButton, icon: "location.magnifyingglass",
                     title: "Track Status",
                     description: "Use this option to check grievance details and track your request.",
                     edge: .top),
        ]

        TourCoachMarkView.present(steps: steps) {
            UserDefaultsService.shared.markTourSeen(.trackGrievance)
        }
    }
}
