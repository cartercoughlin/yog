import Foundation
import Combine

class InjuryViewModel: ObservableObject {
    @Published var injuries: [InjuryData] = []
    @Published var isLoading = false

    private let userDefaultsKey = "savedInjuries"

    init() {
        loadInjuries()
    }

    // MARK: - Computed Properties

    var activeInjuries: [InjuryData] {
        injuries.filter { $0.status == .active || $0.status == .recovering }
    }

    var healedInjuries: [InjuryData] {
        injuries.filter { $0.status == .healed }
    }

    var totalRecoveryImpact: Double {
        activeInjuries.reduce(0) { $0 + $1.recoveryImpact }
    }

    // Get injuries by body location
    func injuries(at location: BodyLocation) -> [InjuryData] {
        injuries.filter { $0.location == location && $0.isActive }
    }

    // Get all active body locations with injuries
    var affectedBodyLocations: [BodyLocation] {
        Array(Set(activeInjuries.map { $0.location }))
    }

    // Get the most severe injury at a location
    func mostSevereInjury(at location: BodyLocation) -> InjuryData? {
        injuries(at: location).max { $0.severity.rawValue < $1.severity.rawValue }
    }

    // MARK: - CRUD Operations

    func addInjury(_ injury: InjuryData) {
        injuries.append(injury)
        saveInjuries()
    }

    func updateInjury(_ injury: InjuryData) {
        if let index = injuries.firstIndex(where: { $0.id == injury.id }) {
            injuries[index] = injury
            saveInjuries()
        }
    }

    func deleteInjury(_ injury: InjuryData) {
        injuries.removeAll { $0.id == injury.id }
        saveInjuries()
    }

    func markAsHealed(_ injury: InjuryData) {
        if let index = injuries.firstIndex(where: { $0.id == injury.id }) {
            injuries[index].status = .healed
            injuries[index].dateHealed = Date()
            saveInjuries()
        }
    }

    func markAsRecovering(_ injury: InjuryData) {
        if let index = injuries.firstIndex(where: { $0.id == injury.id }) {
            injuries[index].status = .recovering
            saveInjuries()
        }
    }

    func markAsActive(_ injury: InjuryData) {
        if let index = injuries.firstIndex(where: { $0.id == injury.id }) {
            injuries[index].status = .active
            saveInjuries()
        }
    }

    // Update severity
    func updateSeverity(for injury: InjuryData, to severity: PainSeverity) {
        if let index = injuries.firstIndex(where: { $0.id == injury.id }) {
            injuries[index].severity = severity
            saveInjuries()
        }
    }

    // MARK: - Analysis

    // Check if a specific workout type should be avoided
    func shouldAvoidWorkout(type: String) -> Bool {
        activeInjuries.contains { injury in
            injury.affectedWorkoutTypes.contains(type) && injury.severity.rawValue >= PainSeverity.moderate.rawValue
        }
    }

    // Get workout recommendations based on injuries
    func getInjuryWarnings(for workoutType: String) -> [String] {
        var warnings: [String] = []

        for injury in activeInjuries {
            if injury.affectedWorkoutTypes.contains(workoutType) {
                let warning = "\(injury.location.displayName) - \(injury.severity.displayName) \(injury.painType.displayName.lowercased()) pain"
                warnings.append(warning)
            }
        }

        return warnings
    }

    // Get general injury summary
    var injurySummary: String {
        let count = activeInjuries.count
        if count == 0 {
            return "No active injuries"
        } else if count == 1 {
            let injury = activeInjuries[0]
            return "\(injury.severity.displayName) \(injury.location.displayName.lowercased()) injury"
        } else {
            return "\(count) active injuries"
        }
    }

    // MARK: - Persistence

    private func saveInjuries() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(injuries)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Error saving injuries: \(error)")
        }
    }

    private func loadInjuries() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            injuries = []
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            injuries = try decoder.decode([InjuryData].self, from: data)
        } catch {
            print("Error loading injuries: \(error)")
            injuries = []
        }
    }

    // MARK: - Sample Data (for testing)

    func loadSampleData() {
        injuries = [
            InjuryData(
                location: .leftKnee,
                painType: .aching,
                severity: .moderate,
                status: .active,
                dateReported: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
                notes: "Pain after long runs, especially downhill",
                affectedWorkoutTypes: ["Running", "Cycling"]
            ),
            InjuryData(
                location: .rightAnkle,
                painType: .sharp,
                severity: .mild,
                status: .recovering,
                dateReported: Calendar.current.date(byAdding: .day, value: -14, to: Date())!,
                notes: "Rolled ankle during trail run",
                affectedWorkoutTypes: ["Running"]
            ),
            InjuryData(
                location: .lowerBack,
                painType: .stiff,
                severity: .mild,
                status: .active,
                dateReported: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
                notes: "Tight after sitting at desk",
                affectedWorkoutTypes: ["Strength Training"]
            )
        ]
        saveInjuries()
    }
}
