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

// MARK: - Training Workout Type
enum TrainingWorkoutType: String, CaseIterable {
    case easy = "Easy"
    case long = "Long Run"
    case marathon = "Marathon Pace"
    case threshold = "Threshold"
    case interval = "Interval"
    case repetition = "Repetition"
    case hill = "Hill Repeats"
    case racePace = "Race Pace"
    case rest = "Rest"

    var abbreviation: String {
        switch self {
        case .easy: return "E"
        case .long: return "L"
        case .marathon: return "M"
        case .threshold: return "T"
        case .interval: return "I"
        case .repetition: return "R"
        case .hill: return "H"
        case .racePace: return "RP"
        case .rest: return "Rest"
        }
    }

    var description: String {
        switch self {
        case .easy:
            return "Comfortable pace for recovery and base building"
        case .long:
            return "Extended run for endurance, often with pace work"
        case .marathon:
            return "Goal marathon race pace"
        case .threshold:
            return "Comfortably hard, lactate threshold pace"
        case .interval:
            return "VO2max pace with equal rest periods"
        case .repetition:
            return "Fast pace for speed and neuromuscular development"
        case .hill:
            return "Uphill repeats for strength and power"
        case .racePace:
            return "Goal race pace sustained effort"
        case .rest:
            return "Recovery day, no running"
        }
    }

    var isQuality: Bool {
        switch self {
        case .threshold, .interval, .repetition, .long, .hill, .racePace:
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
    let type: TrainingWorkoutType
    let distanceInMiles: Double?
    let durationInMinutes: Int?  // Optional time-based alternative
    let paceMinPerMile: String?  // Format: "8:30"
    let description: String
    let isCompleted: Bool
    let linkedWorkout: LinkedWorkout?  // Link to actual HealthKit workout

    init(
        id: UUID = UUID(),
        date: Date,
        type: TrainingWorkoutType,
        distanceInMiles: Double? = nil,
        durationInMinutes: Int? = nil,
        paceMinPerMile: String? = nil,
        description: String,
        isCompleted: Bool = false,
        linkedWorkout: LinkedWorkout? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.distanceInMiles = distanceInMiles
        self.durationInMinutes = durationInMinutes
        self.paceMinPerMile = paceMinPerMile
        self.description = description
        self.isCompleted = isCompleted
        self.linkedWorkout = linkedWorkout
    }

    var formattedDistance: String {
        if let distance = distanceInMiles {
            return String(format: "%.0f mi", distance)
        } else if let duration = durationInMinutes {
            return "\(duration) min"
        }
        return "–"
    }
}

// MARK: - Linked Workout
struct LinkedWorkout: Codable, Identifiable {
    let id: UUID
    let workoutId: String  // HealthKit workout UUID
    let actualDistance: Double  // Miles
    let actualDuration: TimeInterval  // Seconds
    let actualPace: String  // Min/mile
    let completedDate: Date

    var formattedDistance: String {
        String(format: "%.2f mi", actualDistance)
    }

    var formattedDuration: String {
        let hours = Int(actualDuration) / 3600
        let minutes = (Int(actualDuration) % 3600) / 60
        let seconds = Int(actualDuration) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
}

// MARK: - Weekly Plan
struct WeeklyPlan: Identifiable, Codable {
    let id: UUID
    let weekNumber: Int
    let phase: TrainingPhase
    let workouts: [DailyWorkout]
    let startDate: Date
    let isStepbackWeek: Bool  // Every 3rd week for recovery
    let recommendedMileage: Double  // Target weekly mileage

    init(
        id: UUID = UUID(),
        weekNumber: Int,
        phase: TrainingPhase,
        workouts: [DailyWorkout],
        startDate: Date,
        isStepbackWeek: Bool = false,
        recommendedMileage: Double = 0
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.phase = phase
        self.workouts = workouts
        self.startDate = startDate
        self.isStepbackWeek = isStepbackWeek
        self.recommendedMileage = recommendedMileage
    }

    var totalMileage: Double {
        recommendedMileage
    }

    var actualMileage: Double {
        workouts.compactMap { $0.linkedWorkout?.actualDistance }.reduce(0, +)
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
    }

    var qualityWorkouts: [DailyWorkout] {
        workouts.filter { $0.type.isQuality }
    }

    var runningWorkouts: [DailyWorkout] {
        workouts.filter { $0.type != .rest }
    }

    var completionPercentage: Double {
        guard !workouts.isEmpty else { return 0 }
        let completed = workouts.filter { $0.isCompleted }.count
        return Double(completed) / Double(workouts.count) * 100
    }
}

// MARK: - Training Plan
struct TrainingPlan: Identifiable {
    let id: UUID
    let name: String
    let raceDistance: RaceDistance
    let raceDate: Date
    let goalTimeInSeconds: TimeInterval  // Goal finish time
    let minWeeklyMileage: Double
    let maxWeeklyMileage: Double
    let daysPerWeek: Int
    let weeks: [WeeklyPlan]
    let vdot: Double  // VDOT value for pace calculations
    let allowRecoveryAdjustments: Bool
    let includeWorkouts: Bool  // Whether to include quality workouts or just long runs
    let createdDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        raceDistance: RaceDistance,
        raceDate: Date,
        goalTimeInSeconds: TimeInterval,
        minWeeklyMileage: Double,
        maxWeeklyMileage: Double,
        daysPerWeek: Int = 6,
        weeks: [WeeklyPlan],
        vdot: Double,
        allowRecoveryAdjustments: Bool = true,
        includeWorkouts: Bool = true,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.raceDistance = raceDistance
        self.raceDate = raceDate
        self.goalTimeInSeconds = goalTimeInSeconds
        self.minWeeklyMileage = minWeeklyMileage
        self.maxWeeklyMileage = maxWeeklyMileage
        self.daysPerWeek = daysPerWeek
        self.weeks = weeks
        self.vdot = vdot
        self.allowRecoveryAdjustments = allowRecoveryAdjustments
        self.includeWorkouts = includeWorkouts
        self.createdDate = createdDate
    }
}

// MARK: - Codable Conformance
extension TrainingPlan: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, raceDistance, raceDate, goalTimeInSeconds
        case minWeeklyMileage, maxWeeklyMileage, daysPerWeek
        case weeks, vdot, allowRecoveryAdjustments, includeWorkouts, createdDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        raceDistance = try container.decode(RaceDistance.self, forKey: .raceDistance)
        raceDate = try container.decode(Date.self, forKey: .raceDate)
        goalTimeInSeconds = try container.decode(TimeInterval.self, forKey: .goalTimeInSeconds)
        minWeeklyMileage = try container.decode(Double.self, forKey: .minWeeklyMileage)
        maxWeeklyMileage = try container.decode(Double.self, forKey: .maxWeeklyMileage)

        // Provide default values for backward compatibility with old saved plans
        daysPerWeek = try container.decodeIfPresent(Int.self, forKey: .daysPerWeek) ?? 6
        includeWorkouts = try container.decodeIfPresent(Bool.self, forKey: .includeWorkouts) ?? true

        weeks = try container.decode([WeeklyPlan].self, forKey: .weeks)
        vdot = try container.decode(Double.self, forKey: .vdot)
        allowRecoveryAdjustments = try container.decode(Bool.self, forKey: .allowRecoveryAdjustments)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(raceDistance, forKey: .raceDistance)
        try container.encode(raceDate, forKey: .raceDate)
        try container.encode(goalTimeInSeconds, forKey: .goalTimeInSeconds)
        try container.encode(minWeeklyMileage, forKey: .minWeeklyMileage)
        try container.encode(maxWeeklyMileage, forKey: .maxWeeklyMileage)
        try container.encode(daysPerWeek, forKey: .daysPerWeek)
        try container.encode(weeks, forKey: .weeks)
        try container.encode(vdot, forKey: .vdot)
        try container.encode(allowRecoveryAdjustments, forKey: .allowRecoveryAdjustments)
        try container.encode(includeWorkouts, forKey: .includeWorkouts)
        try container.encode(createdDate, forKey: .createdDate)
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

// MARK: - Training Workout Type Codable Extension
extension TrainingWorkoutType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TrainingWorkoutType(rawValue: rawValue) ?? .easy
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
