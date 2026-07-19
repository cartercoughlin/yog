import Foundation

// MARK: - Plan Template
// A reusable snapshot of plan-setup preferences (mileage, frequency, workout
// structure) that a user can save and re-apply when creating future plans.
struct PlanTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let currentWeeklyMileage: Double
    let minWeeklyMileage: Double
    let maxWeeklyMileage: Double
    let daysPerWeek: Int
    let includeWorkouts: Bool
    let allowRecoveryAdjustments: Bool
    let longRunWeekday: Int
    let qualityWeekday: Int
    let createdDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        currentWeeklyMileage: Double,
        minWeeklyMileage: Double,
        maxWeeklyMileage: Double,
        daysPerWeek: Int,
        includeWorkouts: Bool,
        allowRecoveryAdjustments: Bool,
        longRunWeekday: Int,
        qualityWeekday: Int,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.currentWeeklyMileage = currentWeeklyMileage
        self.minWeeklyMileage = minWeeklyMileage
        self.maxWeeklyMileage = maxWeeklyMileage
        self.daysPerWeek = daysPerWeek
        self.includeWorkouts = includeWorkouts
        self.allowRecoveryAdjustments = allowRecoveryAdjustments
        self.longRunWeekday = longRunWeekday
        self.qualityWeekday = qualityWeekday
        self.createdDate = createdDate
    }
}
