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

    // Search criteria
    @Published var propertyId: String = ""
    @Published var ownerName: String = ""
    @Published var fatherName: String = ""
    @Published var mobileNumber: String = ""
    @Published var houseNo: String = ""
    @Published var chukNo: String = ""

    @Published var isLoading: Bool = false
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
        isLoading = true
        defer { isLoading = false }
        do {
            let r = try await api.fetchUlbData()
            ulbs = r.data
        } catch { errorMessage = message(error) }
    }

    func selectUlb(_ ulb: UlbData) {
        selectedUlb = ulb
        selectedZone = nil; selectedWard = nil; selectedMohalla = nil
        zones = []; wards = []; mohalles = []
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
        do { zones = try await api.fetchZoneData(ulbId: ulbId).data }
        catch { errorMessage = message(error) }
    }

    private func loadWards(ulbId: String, zoneId: String) async {
        do { wards = try await api.fetchWardData(ulbId: ulbId, zoneId: zoneId).data }
        catch { errorMessage = message(error) }
    }

    private func loadMohalles(ulbId: String, zoneId: String, wardId: String) async {
        do { mohalles = try await api.fetchMohallaData(ulbId: ulbId, zoneId: zoneId, wardId: wardId).data }
        catch { errorMessage = message(error) }
    }

    // MARK: - Search

    func search() {
        guard let ulbId = selectedUlb?.ulbId else {
            errorMessage = "Please select a ULB."; return
        }
        isLoading = true; errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let r = try await api.searchProperty(PropertySearchRequest(
                    ulbId: ulbId,
                    zoneId: selectedZone?.zoneId,
                    wardId: selectedWard?.wardId,
                    mohallaId: selectedMohalla?.mohallaId,
                    propertyId: nilIfEmpty(propertyId),
                    ownerName: nilIfEmpty(ownerName),
                    fatherName: nilIfEmpty(fatherName),
                    mobileNumber: nilIfEmpty(mobileNumber),
                    houseNo: nilIfEmpty(houseNo),
                    chukNo: nilIfEmpty(chukNo)
                ))
                if r.success {
                    searchResults = r.data
                    if !r.data.isEmpty {
                        coordinator?.showPropertySelection(results: r.data)
                    } else {
                        errorMessage = "No properties found."
                    }
                }
            } catch { errorMessage = message(error) }
        }
    }

    private func nilIfEmpty(_ s: String) -> String? { s.trimmingCharacters(in: .whitespaces).isEmpty ? nil : s }
    private func message(_ e: Error) -> String { (e as? NetworkError)?.errorDescription ?? e.localizedDescription }
}
