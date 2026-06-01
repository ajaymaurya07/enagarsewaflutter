import Foundation

@MainActor
final class TaxAssessmentViewModel: ObservableObject {

    @Published var selectedConstructionType: PropertyTaxCalculator.ConstructionType = .rcc
    @Published var selectedRoadWidth: PropertyTaxCalculator.RoadWidth = .medium
    @Published var builtUpArea: String = ""
    @Published var plotArea: String = ""
    @Published var constructionYear: String = ""
    @Published var result: PropertyTaxCalculator.TaxResult?
    @Published var errorMessage: String?

    let property: PropertyEntity
    private let calculator = PropertyTaxCalculator.shared

    init(property: PropertyEntity) {
        self.property = property
    }

    func calculate() {
        guard let built = Double(builtUpArea), built > 0 else {
            errorMessage = "Please enter a valid built-up area."; return
        }
        guard let plot = Double(plotArea), plot > 0 else {
            errorMessage = "Please enter a valid plot area."; return
        }
        guard let year = Int(constructionYear), year > 1800, year <= Calendar.current.component(.year, from: Date()) else {
            errorMessage = "Please enter a valid construction year."; return
        }

        errorMessage = nil
        let input = PropertyTaxCalculator.AssessmentInput(
            wardNo: property.ward,
            constructionType: selectedConstructionType,
            roadWidth: selectedRoadWidth,
            builtUpArea: built,
            plotArea: plot,
            constructionYear: year,
            isRCC: selectedConstructionType == .rcc
        )
        result = calculator.calculate(input: input)
    }

    func reset() {
        builtUpArea = ""; plotArea = ""; constructionYear = ""; result = nil
    }
}
