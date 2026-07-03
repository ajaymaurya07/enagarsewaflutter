import UIKit
import Combine

final class TaxAssessmentViewController: UIViewController {

    private let viewModel: TaxAssessmentViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: TaxAssessmentViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    private lazy var builtUpField = UITextField.styledTextField(placeholder: "Built-up area (sq ft)")
    private lazy var plotAreaField = UITextField.styledTextField(placeholder: "Plot area (sq ft)")
    private lazy var yearField: UITextField = {
        let tf = UITextField.styledTextField(placeholder: "Construction year (e.g. 2005)")
        tf.keyboardType = .numberPad; return tf
    }()
    private lazy var calculateButton = UIButton.primaryButton(title: "Calculate Tax")
    private let resultCard = UIView()
    private let resultStack = UIStackView()

    // Refs kept for the first-run tour guide
    // (see lib/tour_guides/property_tax_assessment_tour.dart)
    private weak var roadWidthSectionView: UIView?
    private weak var constructionTypeSectionView: UIView?
    private weak var areaDetailsSectionView: UIView?
    private weak var constructionDetailsSectionView: UIView?
    private var didPresentTour = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Self Assessment"
        view.backgroundColor = .appBackground
        setupLayout()
        bindViewModel()
        calculateButton.addTarget(self, action: #selector(calculateTapped), for: .touchUpInside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentTourIfNeeded()
    }

    private func setupLayout() {
        let constructionSegment = UISegmentedControl(items: ["RCC", "Other", "Kacha"])
        constructionSegment.selectedSegmentIndex = 0
        constructionSegment.addTarget(self, action: #selector(constructionChanged(_:)), for: .valueChanged)

        let roadSegment = UISegmentedControl(items: ["Wide (>24m)", "Medium (12-24m)", "Narrow (<12m)"])
        roadSegment.selectedSegmentIndex = 1
        roadSegment.addTarget(self, action: #selector(roadChanged(_:)), for: .valueChanged)

        resultCard.backgroundColor = .appSurface
        resultCard.roundCorners(radius: 12)
        resultCard.isHidden = true
        resultStack.axis = .vertical; resultStack.spacing = 8
        resultStack.translatesAutoresizingMaskIntoConstraints = false
        resultCard.addSubview(resultStack)
        resultStack.pinToEdges(of: resultCard, insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        let constructionLabel = makeLabel("Construction Type")
        let roadLabel = makeLabel("Road Width")

        let constructionSection = UIStackView(arrangedSubviews: [constructionLabel, constructionSegment])
        constructionSection.axis = .vertical; constructionSection.spacing = 8
        constructionTypeSectionView = constructionSection

        let roadSection = UIStackView(arrangedSubviews: [roadLabel, roadSegment])
        roadSection.axis = .vertical; roadSection.spacing = 8
        roadWidthSectionView = roadSection

        let areaSection = UIStackView(arrangedSubviews: [builtUpField, plotAreaField])
        areaSection.axis = .vertical; areaSection.spacing = 12
        areaDetailsSectionView = areaSection

        let constructionDetailsSection = UIStackView(arrangedSubviews: [yearField])
        constructionDetailsSection.axis = .vertical
        constructionDetailsSectionView = constructionDetailsSection

        let mainStack = UIStackView(arrangedSubviews: [
            constructionSection, roadSection,
            areaSection, constructionDetailsSection,
            calculateButton, resultCard
        ])
        mainStack.axis = .vertical; mainStack.spacing = 16; mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.pinToEdges(of: view)
        scroll.addSubview(mainStack)
        NSLayoutConstraint.activate([
            calculateButton.heightAnchor.constraint(equalToConstant: 50),
            mainStack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -20),
            mainStack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -40),
        ])
    }

    private func bindViewModel() {
        viewModel.$result.receive(on: DispatchQueue.main).sink { [weak self] result in
            guard let r = result else { self?.resultCard.isHidden = true; return }
            self?.showResult(r)
        }.store(in: &cancellables)

        viewModel.$errorMessage.receive(on: DispatchQueue.main).sink { [weak self] msg in
            if let msg { self?.showAlert(message: msg) }
        }.store(in: &cancellables)
    }

    private func showResult(_ r: PropertyTaxCalculator.TaxResult) {
        resultStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows: [(String, String)] = [
            ("Annual Rental Value",  String(format: "₹%.2f", r.annualRentalValue)),
            ("Monthly Rental Value", String(format: "₹%.2f", r.monthlyRentalValue)),
            ("General Tax",          String(format: "₹%.2f", r.breakdown.generalTax)),
            ("Water Tax",            String(format: "₹%.2f", r.breakdown.waterTax)),
            ("Sewerage Tax",         String(format: "₹%.2f", r.breakdown.sewerageTax)),
            ("Total Tax",            String(format: "₹%.2f", r.totalTax)),
        ]
        for (l, v) in rows { resultStack.addArrangedSubview(makeResultRow(label: l, value: v)) }
        resultCard.isHidden = false
    }

    @objc private func calculateTapped() {
        viewModel.builtUpArea      = builtUpField.text ?? ""
        viewModel.plotArea         = plotAreaField.text ?? ""
        viewModel.constructionYear = yearField.text ?? ""
        viewModel.calculate()
    }

    @objc private func constructionChanged(_ s: UISegmentedControl) {
        viewModel.selectedConstructionType = [.rcc, .other, .kacha][s.selectedSegmentIndex]
    }

    @objc private func roadChanged(_ s: UISegmentedControl) {
        viewModel.selectedRoadWidth = [.wide, .medium, .narrow][s.selectedSegmentIndex]
    }

    private func makeLabel(_ text: String) -> UILabel {
        let l = UILabel(); l.text = text; l.font = .systemFont(ofSize: 13); l.textColor = .secondaryLabel; return l
    }

    private func makeResultRow(label: String, value: String) -> UIView {
        let lbl = UILabel(); lbl.text = label; lbl.font = .systemFont(ofSize: 14)
        let val = UILabel(); val.text = value; val.font = .boldSystemFont(ofSize: 14); val.textAlignment = .right
        let s = UIStackView(arrangedSubviews: [lbl, val])
        s.distribution = .equalSpacing; return s
    }

    // MARK: - Tour guide (first-run coach mark, see lib/tour_guides/property_tax_assessment_tour.dart)
    // Note: Flutter also spotlights a "Select Property" step and a
    // "Property Type" (residential/non-residential) step, and its final step
    // is a "Download Tax Comparison PDF" button; this native form has neither
    // a property picker nor a PDF export yet, so those steps are adapted to
    // the closest equivalent (the Calculate Tax button) or omitted.

    private func presentTourIfNeeded() {
        guard !didPresentTour, !UserDefaultsService.shared.hasTourBeenSeen(.propertyTaxAssessment) else { return }
        guard let roadWidthSectionView, let constructionTypeSectionView,
              let areaDetailsSectionView, let constructionDetailsSectionView else { return }
        didPresentTour = true

        let steps: [TourStep] = [
            TourStep(target: constructionTypeSectionView, icon: "building.2",
                     title: "Construction Type",
                     description: "Choose the construction type here. This also affects the area rate used in the calculation.",
                     edge: .bottom),
            TourStep(target: roadWidthSectionView, icon: "road.lanes",
                     title: "Road Width",
                     description: "Select the road width of the property so the correct rate can be used for the assessment.",
                     edge: .bottom),
            TourStep(target: areaDetailsSectionView, icon: "square.resize",
                     title: "Area Details",
                     description: "Enter the built-up and plot area here so the total area can be prepared for calculation.",
                     edge: .bottom),
            TourStep(target: constructionDetailsSectionView, icon: "calendar",
                     title: "Construction Details",
                     description: "Enter the construction year here to calculate structure age and continue to the comparison step.",
                     edge: .top),
            TourStep(target: calculateButton, icon: "function",
                     title: "Calculate Tax",
                     description: "Once all fields are filled, tap here to calculate and view the property tax comparison.",
                     edge: .top),
        ]

        TourCoachMarkView.present(steps: steps) {
            UserDefaultsService.shared.markTourSeen(.propertyTaxAssessment)
        }
    }
}
