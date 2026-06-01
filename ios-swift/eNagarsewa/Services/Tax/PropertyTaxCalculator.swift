import Foundation

/// Replicates Flutter's property_tax_calculator.dart logic.
/// Reads rate_master.json bundled with the app.
final class PropertyTaxCalculator {

    static let shared = PropertyTaxCalculator()
    private var rateMaster: [RateMasterEntry] = []
    private init() { loadRateMaster() }

    // MARK: - Public

    struct TaxResult {
        let annualRentalValue: Double
        let monthlyRentalValue: Double
        let totalTax: Double
        let breakdown: TaxBreakdown
    }

    struct TaxBreakdown {
        let generalTax: Double
        let waterTax: Double
        let sewerageTax: Double
        let lightTax: Double
        let conservancyTax: Double
    }

    struct AssessmentInput {
        let wardNo: String
        let constructionType: ConstructionType
        let roadWidth: RoadWidth
        let builtUpArea: Double      // sq ft
        let plotArea: Double         // sq ft
        let constructionYear: Int
        let isRCC: Bool
    }

    enum ConstructionType: String {
        case rcc   = "RCC"
        case other = "Other"
        case kacha = "Kacha"
    }

    enum RoadWidth: String {
        case wide   = ">24m"
        case medium = "12-24m"
        case narrow = "<12m"
    }

    func calculate(input: AssessmentInput) -> TaxResult {
        let ratePerSqFt = rateFor(input: input)
        let mrv = input.builtUpArea * ratePerSqFt           // Monthly Rental Value
        let arv = mrv * 12                                   // Annual Rental Value
        let depreciatedArv = applyDepreciation(arv: arv, year: input.constructionYear)

        let breakdown = computeBreakdown(arv: depreciatedArv)
        let totalTax = breakdown.generalTax + breakdown.waterTax + breakdown.sewerageTax
            + breakdown.lightTax + breakdown.conservancyTax

        return TaxResult(
            annualRentalValue:  depreciatedArv,
            monthlyRentalValue: mrv,
            totalTax:           totalTax,
            breakdown:          breakdown
        )
    }

    // MARK: - Rate lookup

    private func rateFor(input: AssessmentInput) -> Double {
        guard let entry = rateMaster.first(where: { $0.wardNo == input.wardNo }) else {
            return defaultRate(construction: input.constructionType, road: input.roadWidth)
        }
        switch (input.constructionType, input.roadWidth) {
        case (.rcc,   .wide):   return entry.rccWide
        case (.rcc,   .medium): return entry.rccMedium
        case (.rcc,   .narrow): return entry.rccNarrow
        case (.other, .wide):   return entry.otherWide
        case (.other, .medium): return entry.otherMedium
        case (.other, .narrow): return entry.otherNarrow
        case (.kacha, .wide):   return entry.kachaWide
        case (.kacha, .medium): return entry.kachaMedium
        case (.kacha, .narrow): return entry.kachaNarrow
        }
    }

    private func defaultRate(construction: ConstructionType, road: RoadWidth) -> Double {
        switch (construction, road) {
        case (.rcc, .wide):    return 2.5
        case (.rcc, .medium):  return 2.0
        case (.rcc, .narrow):  return 1.5
        case (.other, .wide):  return 2.0
        case (.other, .medium):return 1.5
        case (.other, .narrow):return 1.0
        case (.kacha, .wide):  return 1.0
        case (.kacha, .medium):return 0.8
        case (.kacha, .narrow):return 0.6
        }
    }

    // MARK: - Depreciation/Appreciation

    private func applyDepreciation(arv: Double, year: Int) -> Double {
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = currentYear - year
        let factor: Double
        switch age {
        case ..<0:   factor = 1.10   // future (appreciation)
        case 0...5:  factor = 1.00
        case 6...10: factor = 0.95
        case 11...20:factor = 0.90
        case 21...30:factor = 0.85
        case 31...40:factor = 0.80
        case 41...50:factor = 0.75
        default:     factor = 0.70
        }
        return arv * factor
    }

    // MARK: - Tax breakdown (approximate municipal ratios)

    private func computeBreakdown(arv: Double) -> TaxBreakdown {
        TaxBreakdown(
            generalTax:      arv * 0.10,
            waterTax:        arv * 0.04,
            sewerageTax:     arv * 0.02,
            lightTax:        arv * 0.02,
            conservancyTax:  arv * 0.02
        )
    }

    // MARK: - rate_master.json loader

    private func loadRateMaster() {
        guard let url = Bundle.main.url(forResource: "rate_master", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([RateMasterEntry].self, from: data) else {
            return
        }
        rateMaster = entries
    }
}

// MARK: - JSON model

private struct RateMasterEntry: Decodable {
    let wardNo: String
    let wardName: String
    let rccWide: Double
    let rccMedium: Double
    let rccNarrow: Double
    let otherWide: Double
    let otherMedium: Double
    let otherNarrow: Double
    let kachaWide: Double
    let kachaMedium: Double
    let kachaNarrow: Double

    enum CodingKeys: String, CodingKey {
        case wardNo      = "WardNo"
        case wardName    = "WardName"
        case rccWide     = "RCC_Wide"
        case rccMedium   = "RCC_Medium"
        case rccNarrow   = "RCC_Narrow"
        case otherWide   = "Other_Wide"
        case otherMedium = "Other_Medium"
        case otherNarrow = "Other_Narrow"
        case kachaWide   = "Kacha_Wide"
        case kachaMedium = "Kacha_Medium"
        case kachaNarrow = "Kacha_Narrow"
    }
}
