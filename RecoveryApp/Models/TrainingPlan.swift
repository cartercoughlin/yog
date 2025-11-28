import Foundation

// MARK: - Race Distance
enum RaceDistance: String, CaseIterable, Identifiable {
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "Half Marathon"
    case marathon = "Marathon"

    var id: String { rawValue }

    var meters: Double {
        switch self {
        case .fiveK: return 5000
        case .tenK: return 10000
        case .halfMarathon: return 21097.5
        case .marathon: return 42195
        }
    }

    var recommendedWeeks: Int {
        switch self {
        case .fiveK, .tenK: return 12
        case .halfMarathon: return 16
        case .marathon: return 24
        }
    }
}

// MARK: - Training Phase
enum TrainingPhase: String, CaseIterable {
    case foundation = "Foundation"
    case earlyQuality = "Early Quality"
    case transitionQuality = "Transition Quality"
    case finalQuality = "Final Quality"

    var description: String {
        switch self {
        case .foundation:
            return "Building base fitness and injury prevention"
        case .earlyQuality:
            return "Long runs and repetition work"
        case .transitionQuality:
            return "Interval and threshold training"
        case .finalQuality:
            return "Race-specific preparation"
        }
    }

    var color: String {
        switch self {
        case .foundation: return "blue"
        case .earlyQuality: return "green"
        case .transitionQuality: return "orange"
        case .finalQuality: return "red"
        }
    }
}

// MARK: - Workout Type
enum WorkoutType: String, CaseIterable {
    case easy = "Easy"
    case long = "Long Run"
    case marathon = "Marathon Pace"
    case threshold = "Threshold"
    case interval = "Interval"
    case repetition = "Repetition"
    case rest = "Rest"

    var abbreviation: String {
        switch self {
        case .easy: return "E"
        case .long: return "L"
        case .marathon: return "M"
        case .threshold: return "T"
        case .interval: return "I"
        case .repetition: return "R"
        case .rest: return "Rest"
        }
    }

    var description: String {
        switch self {
        case .easy:
            return "Comfortable pace for recovery and base building"
        case .long:
            return "Extended easy run for endurance"
        case .marathon:
            return "Goal marathon race pace"
        case .threshold:
            return "Comfortably hard, lactate threshold pace"
        case .interval:
            return "VO2max pace with equal rest periods"
        case .repetition:
            return "Fast pace for speed and neuromuscular development"
        case .rest:
            return "Recovery day, no running"
        }
    }

    var isQuality: Bool {
        switch self {
        case .threshold, .interval, .repetition, .long:
            return true
        default:
            return false
        }
    }
}

// MARK: - Daily Workout
struct DailyWorkout: Identifiable, Codable {
    let id: UUID
    let date: Date
    let type: WorkoutType
    let distanceInMiles: Double?
    let paceMinPerMile: String?  // Format: "8:30"
    let description: String
    let isCompleted: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        type: WorkoutType,
        distanceInMiles: Double? = nil,
        paceMinPerMile: String? = nil,
        description: String,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.distanceInMiles = distanceInMiles
        self.paceMinPerMile = paceMinPerMile
        self.description = description
        self.isCompleted = isCompleted
    }

    var formattedDistance: String {
        guard let distance = distanceInMiles else { return "–" }
        return String(format: "%.1f mi", distance)
    }
}

// MARK: - Weekly Plan
struct WeeklyPlan: Identifiable, Codable {
    let id: UUID
    let weekNumber: Int
    let phase: TrainingPhase
    let workouts: [DailyWorkout]
    let startDate: Date

    init(
        id: UUID = UUID(),
        weekNumber: Int,
        phase: TrainingPhase,
        workouts: [DailyWorkout],
        startDate: Date
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.phase = phase
        self.workouts = workouts
        self.startDate = startDate
    }

    var totalMileage: Double {
        workouts.compactMap { $0.distanceInMiles }.reduce(0, +)
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
    }

    var qualityWorkouts: [DailyWorkout] {
        workouts.filter { $0.type.isQuality }
    }

    var completionPercentage: Double {
        guard !workouts.isEmpty else { return 0 }
        let completed = workouts.filter { $0.isCompleted }.count
        return Double(completed) / Double(workouts.count) * 100
    }
}

// MARK: - Training Plan
struct TrainingPlan: Identifiable, Codable {
    let id: UUID
    let raceDistance: RaceDistance
    let raceDate: Date
    let goalTimeInSeconds: TimeInterval  // Goal finish time
    let minWeeklyMileage: Double
    let maxWeeklyMileage: Double
    let weeks: [WeeklyPlan]
    let vdot: Double  // Jack Daniels VDOT value
    let allowRecoveryAdjustments: Bool
    let createdDate: Date

    init(
        id: UUID = UUID(),
        raceDistance: RaceDistance,
        raceDate: Date,
        goalTimeInSeconds: TimeInterval,
        minWeeklyMileage: Double,
        maxWeeklyMileage: Double,
        weeks: [WeeklyPlan],
        vdot: Double,
        allowRecoveryAdjustments: Bool = true,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.raceDistance = raceDistance
        self.raceDate = raceDate
        self.goalTimeInSeconds = goalTimeInSeconds
        self.minWeeklyMileage = minWeeklyMileage
        self.maxWeeklyMileage = maxWeeklyMileage
        self.weeks = weeks
        self.vdot = vdot
        self.allowRecoveryAdjustments = allowRecoveryAdjustments
        self.createdDate = createdDate
    }

    var totalWeeks: Int {
        weeks.count
    }

    var weeksUntilRace: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let race = calendar.startOfDay(for: raceDate)
        let components = calendar.dateComponents([.weekOfYear], from: today, to: race)
        return max(0, components.weekOfYear ?? 0)
    }

    var currentWeek: WeeklyPlan? {
        let today = Date()
        return weeks.first { week in
            today >= week.startDate && today <= week.endDate
        }
    }

    var completedWeeks: [WeeklyPlan] {
        let today = Date()
        return weeks.filter { $0.endDate < today }
    }

    var averageWeeklyMileage: Double {
        guard !weeks.isEmpty else { return 0 }
        return weeks.map { $0.totalMileage }.reduce(0, +) / Double(weeks.count)
    }

    var goalPaceMinPerMile: String {
        let totalMinutes = goalTimeInSeconds / 60
        let miles = raceDistance.meters / 1609.34
        let paceMinPerMile = totalMinutes / miles
        let minutes = Int(paceMinPerMile)
        let seconds = Int((paceMinPerMile - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Workout Type Codable Extension
extension WorkoutType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = WorkoutType(rawValue: rawValue) ?? .easy
    }
}

// MARK: - Training Phase Codable Extension
extension TrainingPhase: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TrainingPhase(rawValue: rawValue) ?? .foundation
    }
}

// MARK: - Race Distance Codable Extension
extension RaceDistance: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = RaceDistance(rawValue: rawValue) ?? .marathon
    }
}
