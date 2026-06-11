import Foundation

@MainActor
final class SearchPropertyViewModel: ObservableObject {

    @Published var ulbs: [UlbData] = []
    @Published var zones: [ZoneData] = []
    @Published var wards: [WardData] = []
    @Published var mohalles: [MohallaData] = []
    @Published var searchResults: [PropertyData] = []

    @Published var selectedUlb: UlbData?
    @Published var selectedZone: ZoneData?
    @Published var selectedWard: WardData?
    @Published var selectedMohalla: MohallaData?

    // Search fields
    @Published var propertyId: String = ""
    @Published var ownerName: String = ""
    @Published var fatherName: String = ""
    @Published var mobileNumber: String = ""
    @Published var houseNo: String = ""

    // Search mode: matches Flutter's _searchMode strings
    @Published var searchMode: String = "By Owner"

    @Published var isLoading: Bool = false
    @Published var isLoadingUlbs: Bool = false
    @Published var isLoadingZones: Bool = false
    @Published var isLoadingWards: Bool = false
    @Published var isLoadingMohalles: Bool = false
    @Published var errorMessage: String?

    private let api = APIService.shared
    weak var coordinator: PropertyCoordinator?

    init(coordinator: PropertyCoordinator) {
        self.coordinator = coordinator
    }

    func onViewAppear() {
        Task { await loadUlbs() }
    }

    // MARK: - Cascade loading

    func loadUlbs() async {
        isLoadingUlbs = true
        errorMessage = nil
        defer { isLoadingUlbs = false }
        do {
            let r = try await api.fetchUlbData()
            ulbs = r.data
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription ?? "Unable to load ULB data right now. Please try again."
        }
    }

    func selectUlb(_ ulb: UlbData) {
        selectedUlb = ulb
        selectedZone = nil; selectedWard = nil; selectedMohalla = nil
        zones = []; wards = []; mohalles = []
        AppState.shared.selectedUlbId = ulb.ulbId
        Task { await loadZones(ulbId: ulb.ulbId) }
    }

    func selectZone(_ zone: ZoneData) {
        selectedZone = zone
        selectedWard = nil; selectedMohalla = nil
        wards = []; mohalles = []
        guard let ulbId = selectedUlb?.ulbId else { return }
        Task { await loadWards(ulbId: ulbId, zoneId: zone.zoneId) }
    }

    func selectWard(_ ward: WardData) {
        selectedWard = ward
        selectedMohalla = nil; mohalles = []
        guard let ulbId = selectedUlb?.ulbId, let zoneId = selectedZone?.zoneId else { return }
        Task { await loadMohalles(ulbId: ulbId, zoneId: zoneId, wardId: ward.wardId) }
    }

    private func loadZones(ulbId: String) async {
        isLoadingZones = true
        defer { isLoadingZones = false }
        do { zones = try await api.fetchZoneData(ulbId: ulbId).data }
        catch { errorMessage = "Failed to load zones" }
    }

    private func loadWards(ulbId: String, zoneId: String) async {
        isLoadingWards = true
        defer { isLoadingWards = false }
        do { wards = try await api.fetchWardData(ulbId: ulbId, zoneId: zoneId).data }
        catch { errorMessage = "Failed to load wards" }
    }

    private func loadMohalles(ulbId: String, zoneId: String, wardId: String) async {
        isLoadingMohalles = true
        defer { isLoadingMohalles = false }
        do { mohalles = try await api.fetchMohallaData(ulbId: ulbId, zoneId: zoneId, wardId: wardId).data }
        catch { errorMessage = "Failed to load mohallas" }
    }

    // MARK: - Search

    func search() {
        guard let ulb = selectedUlb else {
            errorMessage = "Please select ULB first"; return
        }
        isLoading = true; errorMessage = nil

        let searchType: String
        switch searchMode {
        case "By Owner":       searchType = "OWNER"
        case "By Property ID": searchType = "PID"
        case "By House No":    searchType = "HOUSE"
        case "By Location":    searchType = "LOCATION"
        case "By Mobile No":   searchType = "MOBILE"
        default:               searchType = "OWNER"
        }

        Task {
            defer { isLoading = false }
            do {
                let r = try await api.searchProperty(PropertySearchRequest(
                    ulbId: ulb.ulbId,
                    searchType: searchType,
                    zoneId: selectedZone?.zoneId,
                    wardId: selectedWard?.wardId,
                    mohallaId: selectedMohalla?.mohallaId,
                    propertyId: nilIfEmpty(propertyId),
                    ownerName: nilIfEmpty(ownerName),
                    fatherName: nilIfEmpty(fatherName),
                    mobileNumber: nilIfEmpty(mobileNumber),
                    houseNo: nilIfEmpty(houseNo),
                    chukNo: nil
                ))
                if r.success {
                    if r.data.isEmpty {
                        errorMessage = "No properties found."
                    } else {
                        AppState.shared.selectedUlbId = ulb.ulbId
                        if let arv = r.data.first?.totalArv {
                            AppState.shared.selectedPropertyTotalArv = arv
                        }
                        coordinator?.showPropertySelection(results: r.data)
                    }
                } else {
                    errorMessage = "Search failed. Please try again."
                }
            } catch {
                errorMessage = (error as? NetworkError)?.errorDescription ?? "Unable to search properties right now. Please try again."
            }
        }
    }

    private func nilIfEmpty(_ s: String) -> String? { s.trimmingCharacters(in: .whitespaces).isEmpty ? nil : s }
}
