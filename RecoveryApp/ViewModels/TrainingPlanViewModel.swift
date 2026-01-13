import Foundation
import SwiftUI
import Combine

@MainActor
class TrainingPlanViewModel: ObservableObject {
    @Published var trainingPlans: [TrainingPlan] = [] {
        didSet {
            savePlans()
        }
    }
    @Published var currentPlan: TrainingPlan? {
        didSet {
            savePlans()
        }
    }
    @Published var isCreatingPlan = false

    // Plan creation inputs
    @Published var planName = ""
    @Published var selectedDistance: RaceDistance = .marathon
    @Published var selectedRaceDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @Published var goalHours = 3
    @Published var goalMinutes = 30
    @Published var goalSeconds = 0
    @Published var currentWeeklyMileage: Double = 35
    @Published var minWeeklyMileage: Double = 40
    @Published var maxWeeklyMileage: Double = 55
    @Published var daysPerWeek: Int = 6
    @Published var allowRecoveryAdjustments = true
    @Published var includeWorkouts = true  // Toggle for quality workouts vs long runs only

    // Recovery-based adjustment infrastructure
    @Published var lastRecoveryScore: Double?
    @Published var adjustmentSuggestion: String?

    private let healthKitManager = HealthKitManager()
    private let userDefaultsKey = "savedTrainingPlans"
    private let planVersionKey = "trainingPlanVersion"
    private let currentPlanVersion = 4  // Version 4: Dynamic weeks, workout toggle, half marathon 10mi cap
    private var isLoadingPlans = false

    init() {
        migrateIfNeeded()
        loadPlans()
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        let savedVersion = UserDefaults.standard.integer(forKey: planVersionKey)

        // If old version or no version, clear existing plans for fresh start
        if savedVersion < currentPlanVersion {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            UserDefaults.standard.set(currentPlanVersion, forKey: planVersionKey)
            print("🔄 Migrated training plans to version \(currentPlanVersion) - cleared old plans")
        }
    }

    // MARK: - Mileage Calculation Helpers

    func updateDesiredMileageDefaults() {
        // Calculate recommended mileage increase based on race distance
        let mileageIncrease: (min: Double, max: Double)

        switch selectedDistance {
        case .fiveK:
            mileageIncrease = (5, 10)  // Modest increase for 5K
        case .tenK:
            mileageIncrease = (5, 10)  // Moderate increase for 10K
        case .halfMarathon:
            mileageIncrease = (10, 15)  // Significant increase for half marathon
        case .marathon:
            mileageIncrease = (15, 20)  // Large increase for marathon
        }

        // Set desired mileage as current + race-specific increase
        minWeeklyMileage = min(80, currentWeeklyMileage + mileageIncrease.min)
        maxWeeklyMileage = min(100, currentWeeklyMileage + mileageIncrease.max)

        // Ensure max is always greater than min
        if maxWeeklyMileage <= minWeeklyMileage {
            maxWeeklyMileage = minWeeklyMileage + 10
        }
    }

    // MARK: - Plan Generation

    func generatePlan() {
        isCreatingPlan = true

        let goalTime = TimeInterval(goalHours * 3600 + goalMinutes * 60 + goalSeconds)
        let vdot = VDOTCalculator.calculateVDOT(
            distanceInMeters: selectedDistance.meters,
            timeInSeconds: goalTime
        )

        // Calculate goal race pace (seconds per mile)
        let raceMiles = selectedDistance.meters / 1609.34
        let goalRacePaceSecPerMile = goalTime / raceMiles

        // Calculate actual weeks until race date, capped at recommended weeks for the distance
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let raceDay = calendar.startOfDay(for: selectedRaceDate)
        let weeksUntilRace = calendar.dateComponents([.weekOfYear], from: today, to: raceDay).weekOfYear ?? 16
        let maxWeeksForDistance = selectedDistance.recommendedWeeks
        let actualWeeks = max(4, min(weeksUntilRace, maxWeeksForDistance))  // Min 4 weeks, max based on distance

        var weeks: [WeeklyPlan] = []
        let startDate = calendar.date(
            byAdding: .weekOfYear,
            value: -actualWeeks,
            to: selectedRaceDate
        ) ?? Date()

        // Generate weeks following periodized phase structure
        for weekNumber in 0..<actualWeeks {
            let phase = determinePhase(weekNumber: weekNumber, totalWeeks: actualWeeks)
            let weekStartDate = calendar.date(
                byAdding: .weekOfYear,
                value: weekNumber,
                to: startDate
            ) ?? Date()

            let mileage = calculateWeeklyMileage(
                weekNumber: weekNumber,
                totalWeeks: actualWeeks,
                phase: phase
            )

            let workouts = generateWeeklyWorkouts(
                weekNumber: weekNumber + 1,
                totalWeeks: actualWeeks,
                phase: phase,
                targetMileage: mileage,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: selectedDistance,
                weekStartDate: weekStartDate,
                daysPerWeek: daysPerWeek,
                includeWorkouts: includeWorkouts
            )

            let isStepback = isStepbackWeek(weekNumber: weekNumber + 1, totalWeeks: actualWeeks)

            weeks.append(WeeklyPlan(
                weekNumber: weekNumber + 1,
                phase: phase,
                workouts: workouts,
                startDate: weekStartDate,
                isStepbackWeek: isStepback,
                recommendedMileage: mileage
            ))
        }

        // Use custom name or generate default name
        let finalName = planName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "\(selectedDistance.rawValue) - \(selectedRaceDate.formatted(date: .abbreviated, time: .omitted))"
            : planName.trimmingCharacters(in: .whitespaces)

        // If editing existing plan, preserve its ID and createdDate
        let planId = currentPlan?.id ?? UUID()
        let planCreatedDate = currentPlan?.createdDate ?? Date()

        let newPlan = TrainingPlan(
            id: planId,
            name: finalName,
            raceDistance: selectedDistance,
            raceDate: selectedRaceDate,
            goalTimeInSeconds: goalTime,
            minWeeklyMileage: minWeeklyMileage,
            maxWeeklyMileage: maxWeeklyMileage,
            daysPerWeek: daysPerWeek,
            weeks: weeks,
            vdot: vdot,
            allowRecoveryAdjustments: allowRecoveryAdjustments,
            includeWorkouts: includeWorkouts,
            createdDate: planCreatedDate
        )

        // If editing existing plan, replace it
        if let currentPlan = currentPlan,
           let index = trainingPlans.firstIndex(where: { $0.id == currentPlan.id }) {
            trainingPlans[index] = newPlan
            self.currentPlan = newPlan
        } else {
            // Add new plan
            trainingPlans.append(newPlan)
            currentPlan = newPlan
        }

        isCreatingPlan = false
    }

    // MARK: - Phase Determination

    private func determinePhase(weekNumber: Int, totalWeeks: Int) -> TrainingPhase {
        let weeksPerPhase = totalWeeks / 4
        let phaseIndex = min(3, weekNumber / weeksPerPhase)

        switch phaseIndex {
        case 0: return .foundation
        case 1: return .earlyQuality
        case 2: return .transitionQuality
        default: return .finalQuality
        }
    }

    // MARK: - Mileage Calculation

    private func calculateWeeklyMileage(
        weekNumber: Int,
        totalWeeks: Int,
        phase: TrainingPhase
    ) -> Double {
        // Determine if this is a stepback week (every 4th week, with smoother reduction)
        let isStepbackWeek = (weekNumber % 4 == 0) && weekNumber < (totalWeeks - 2)

        // Build up from min to max over first 75% of plan, then taper
        let buildWeeks = Int(Double(totalWeeks) * 0.75)
        let taperWeeks = totalWeeks - buildWeeks

        var baseMileage: Double

        if weekNumber < buildWeeks {
            // Progressive build with smoother curve (reduces spikes)
            let progress = Double(weekNumber) / Double(buildWeeks)
            let mileageRange = maxWeeklyMileage - minWeeklyMileage

            // Use a smoother progression curve
            // Instead of linear, use a cubic ease-in curve for more gradual build
            let smoothProgress = pow(progress, 1.5)
            baseMileage = minWeeklyMileage + (mileageRange * smoothProgress)
        } else {
            // Taper phase
            let weeksIntoTaper = weekNumber - buildWeeks
            let taperProgress = Double(weeksIntoTaper) / Double(taperWeeks)
            baseMileage = maxWeeklyMileage * (1.0 - (taperProgress * 0.4))  // 40% reduction
        }

        // Apply stepback reduction: gentler 15% reduction on stepback weeks
        // This creates recovery without huge drops
        if isStepbackWeek {
            return baseMileage * 0.85
        }

        return baseMileage
    }

    private func isStepbackWeek(weekNumber: Int, totalWeeks: Int) -> Bool {
        // For short plans (< 8 weeks), no stepback weeks
        guard totalWeeks >= 8 else { return false }

        // Stepback every 3-4 weeks depending on plan length
        let stepbackInterval = totalWeeks >= 12 ? 4 : 3

        // Foundation phase is ~25% of plan
        let foundationWeeks = max(1, totalWeeks / 4)

        // Taper is last ~12.5% of plan (at least 1 week)
        let taperStart = totalWeeks - max(1, totalWeeks / 8)

        // Stepback weeks occur after foundation, before taper, at regular intervals
        return (weekNumber % stepbackInterval == 0) && weekNumber > foundationWeeks && weekNumber < taperStart
    }

    // MARK: - Workout Generation

    private func generateWeeklyWorkouts(
        weekNumber: Int,
        totalWeeks: Int,
        phase: TrainingPhase,
        targetMileage: Double,
        goalRacePaceSecPerMile: Double,
        raceDistance: RaceDistance,
        weekStartDate: Date,
        daysPerWeek: Int,
        includeWorkouts: Bool
    ) -> [DailyWorkout] {
        var workouts: [DailyWorkout] = []

        let isStepback = isStepbackWeek(weekNumber: weekNumber, totalWeeks: totalWeeks)
        let longRunDistance = calculateLongRunDistance(
            targetMileage: targetMileage,
            phase: phase,
            isStepback: isStepback,
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            raceDistance: raceDistance
        )

        // Only generate quality days: Long Run + Quality Workout
        // HealthKit workouts will be pulled in automatically to show actual training

        // Sunday (day 0): Long Run - Always included as quality day
        let longRunDescription = generateLongRunDescription(
            phase: phase,
            weekNumber: weekNumber,
            distance: longRunDistance,
            raceDistance: raceDistance,
            isStepback: isStepback
        )
        workouts.append(createWorkout(
            date: addDays(to: weekStartDate, days: 0),
            type: .long,
            distance: longRunDistance,
            goalRacePaceSecPerMile: goalRacePaceSecPerMile,
            raceDistance: raceDistance,
            description: longRunDescription
        ))

        // Tuesday (day 2): Quality workout (only if includeWorkouts is enabled)
        // - Not if workouts are disabled
        // - Not in foundation phase
        // - Not during final taper (last 2 weeks or ~12.5% of plan)
        // - Not on stepback weeks
        guard includeWorkouts else {
            return workouts.sorted { $0.date < $1.date }
        }

        let taperWeeks = max(1, totalWeeks / 8)  // Last ~12.5% of plan is taper
        let foundationWeeks = max(1, totalWeeks / 4)  // First ~25% is foundation
        let isTaperWeek = weekNumber > (totalWeeks - taperWeeks)
        let isFoundationPhase = weekNumber <= foundationWeeks

        if !isTaperWeek && !isStepback && !isFoundationPhase {
            let tuesdayWorkout = generateTuesdayQuality(
                phase: phase,
                weekNumber: weekNumber,
                weekStartDate: weekStartDate,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                isStepback: isStepback
            )
            workouts.append(tuesdayWorkout)
        }

        return workouts.sorted { $0.date < $1.date }
    }

    // MARK: - Day-Specific Quality Workouts

    private func generateTuesdayQuality(
        phase: TrainingPhase,
        weekNumber: Int,
        weekStartDate: Date,
        goalRacePaceSecPerMile: Double,
        raceDistance: RaceDistance,
        isStepback: Bool
    ) -> DailyWorkout {
        // On stepback weeks, reduce intensity
        if isStepback {
            return createWorkout(
                date: addDays(to: weekStartDate, days: 2),
                type: .easy,
                distance: 5,
                durationMinutes: 50,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                description: "Easy run"
            )
        }

        switch phase {
        case .foundation:
            // Foundation phase: easy run only, no quality workouts
            return createWorkout(
                date: addDays(to: weekStartDate, days: 2),
                type: .easy,
                distance: 6,
                durationMinutes: 55,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                description: "Easy run"
            )

        case .earlyQuality:
            // Early quality: Repetition work (400m repeats)
            let reps = min(12, 8 + (weekNumber / 2))
            return createWorkout(
                date: addDays(to: weekStartDate, days: 2),
                type: .repetition,
                distance: 7,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                description: "\(reps) × 400m @ R pace, 90 sec rest"
            )

        case .transitionQuality:
            // Transition: Interval work (800m-1000m)
            return createWorkout(
                date: addDays(to: weekStartDate, days: 2),
                type: .interval,
                distance: 8,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                description: "6 × 1000m @ I pace, equal jog rest"
            )

        case .finalQuality:
            // Final quality: Race-specific work
            if raceDistance == .marathon {
                return createWorkout(
                    date: addDays(to: weekStartDate, days: 2),
                    type: .marathon,
                    distance: 10,
                    goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                    raceDistance: raceDistance,
                    description: "2 miles E, 6 miles @ M pace, 2 miles E"
                )
            } else {
                return createWorkout(
                    date: addDays(to: weekStartDate, days: 2),
                    type: .interval,
                    distance: 8,
                    goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                    raceDistance: raceDistance,
                    description: "5 × 1 mile @ I pace, 2 min rest"
                )
            }
        }
    }

    private func calculateLongRunDistance(
        targetMileage: Double,
        phase: TrainingPhase,
        isStepback: Bool,
        weekNumber: Int,
        totalWeeks: Int,
        raceDistance: RaceDistance
    ) -> Double {
        // Long run should be 25-30% of weekly mileage
        let percentage: Double = phase == .foundation ? 0.25 : 0.30
        var distance = targetMileage * percentage

        // Cap based on race distance
        switch raceDistance {
        case .fiveK, .tenK:
            distance = min(12, distance)  // Cap at 12 miles for shorter races
        case .halfMarathon:
            // For half marathon, cap at 10 miles if max weekly mileage > 10
            // Ensure at least 2 long runs reach 10 miles in the final quality phase
            distance = min(10, distance)

            // Peak weeks for half marathon (last 3-4 weeks before taper, scaled to plan length)
            let taperStart = totalWeeks - max(1, totalWeeks / 8)
            let peakWeek1 = max(1, taperStart - 2)
            let peakWeek2 = max(1, taperStart - 4)

            if maxWeeklyMileage > 10 && (weekNumber == peakWeek1 || weekNumber == peakWeek2) {
                distance = 10  // Ensure 10-mile long runs for these peak weeks
            }
        case .marathon:
            distance = min(21, distance)  // Cap at 21 miles for marathon

            // For marathon training, ensure we hit 3 long runs of 20-21 miles
            // Scale peak weeks based on total plan length
            let taperStart = totalWeeks - max(2, totalWeeks / 8)
            let peakWeek1 = max(1, taperStart - 2)
            let peakWeek2 = max(1, taperStart - 4)
            let peakWeek3 = max(1, taperStart - 6)

            if weekNumber == peakWeek1 || weekNumber == peakWeek2 || weekNumber == peakWeek3 {
                distance = max(distance, 20)  // Ensure at least 20 miles
            }
        }

        // Reduce long run on stepback weeks
        if isStepback {
            distance *= 0.80
        }

        // Minimum distance based on race type
        let minDistance: Double = raceDistance == .marathon ? 8 : 6
        return max(minDistance, distance)
    }

    private func generateLongRunDescription(
        phase: TrainingPhase,
        weekNumber: Int,
        distance: Double,
        raceDistance: RaceDistance,
        isStepback: Bool
    ) -> String {
        let miles = Int(distance)

        // Stepback weeks: just easy running
        if isStepback {
            return "\(miles) miles easy"
        }

        switch phase {
        case .foundation:
            // Foundation: all easy
            return "\(miles) miles easy"

        case .earlyQuality:
            // Early quality: introduce light pace work in later weeks
            if weekNumber >= 6 && miles >= 12 {
                return "\(miles) miles: last 2 miles @ M pace"
            }
            return "\(miles) miles easy"

        case .transitionQuality:
            // Transition: structured M pace segments (Bandit/Higdon style)
            if raceDistance == .marathon && miles >= 14 {
                let segment1 = min(4, Int(Double(miles) * 0.30))
                let segment2 = min(3, Int(Double(miles) * 0.20))
                return "\(miles) miles: \(miles - segment1 - segment2 - 2) easy + \(segment1) @ M + 1 easy + \(segment2) @ M + 1 easy"
            } else if miles >= 12 {
                return "\(miles) miles: last 3 miles @ M pace"
            }
            return "\(miles) miles easy"

        case .finalQuality:
            // Final quality: longer M pace segments
            if raceDistance == .marathon && miles >= 14 {
                let segment1 = min(6, Int(Double(miles) * 0.40))
                let segment2 = min(4, Int(Double(miles) * 0.25))
                return "\(miles) miles: \(miles - segment1 - segment2 - 2) easy + \(segment1) @ M + 1 easy + \(segment2) @ M + 1 easy"
            } else if miles >= 10 {
                let mpaceMiles = Int(Double(miles) * 0.40)
                return "\(miles) miles: \(miles - mpaceMiles) easy + \(mpaceMiles) @ M pace"
            }
            return "\(miles) miles easy"
        }
    }

    private func createWorkout(
        date: Date,
        type: TrainingWorkoutType,
        distance: Double?,
        durationMinutes: Int? = nil,
        goalRacePaceSecPerMile: Double,
        raceDistance: RaceDistance,
        description: String
    ) -> DailyWorkout {
        let pace = type == .rest ? nil : VDOTCalculator.paceForWorkoutType(type, goalRacePaceSecPerMile: goalRacePaceSecPerMile, raceDistance: raceDistance)

        return DailyWorkout(
            date: date,
            type: type,
            distanceInMiles: distance,
            durationInMinutes: durationMinutes,
            paceMinPerMile: pace,
            description: description
        )
    }

    private func addDays(to date: Date, days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    // MARK: - Recovery-Based Adjustments Infrastructure

    func evaluateRecoveryAdjustment(currentRecoveryScore: Double) {
        guard let plan = currentPlan, plan.allowRecoveryAdjustments else { return }
        guard let currentWeek = plan.currentWeek else { return }

        lastRecoveryScore = currentRecoveryScore

        // Suggest adjustments based on recovery score
        if currentRecoveryScore < 50 {
            adjustmentSuggestion = "Low recovery score detected. Consider converting quality workouts to easy runs this week."
        } else if currentRecoveryScore < 65 {
            adjustmentSuggestion = "Moderate recovery. Maintain planned workouts but monitor fatigue closely."
        } else if currentRecoveryScore >= 80 {
            adjustmentSuggestion = "Excellent recovery! You're ready for this week's quality workouts."
        } else {
            adjustmentSuggestion = nil
        }
    }

    func resetPlan() {
        currentPlan = nil
        adjustmentSuggestion = nil
        lastRecoveryScore = nil
    }

    func deletePlan(_ plan: TrainingPlan) {
        trainingPlans.removeAll { $0.id == plan.id }
        if currentPlan?.id == plan.id {
            currentPlan = trainingPlans.first
        }
    }

    func deletePlans(at offsets: IndexSet) {
        // Store IDs of plans to delete
        let plansToDelete = offsets.map { trainingPlans[$0] }
        let idsToDelete = Set(plansToDelete.map { $0.id })

        // Check if current plan is being deleted
        let deletingCurrentPlan = currentPlan.map { idsToDelete.contains($0.id) } ?? false

        // Remove plans from array
        trainingPlans.remove(atOffsets: offsets)

        // Update current plan if it was deleted
        if deletingCurrentPlan {
            currentPlan = trainingPlans.first
        }
    }

    func selectPlan(_ plan: TrainingPlan) {
        currentPlan = plan
    }

    // MARK: - Workout Linking

    func linkWorkoutToDay(workoutId: UUID, healthKitWorkout: WorkoutData) {
        guard var plan = currentPlan else { return }

        // Find the workout day
        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            for (workoutIndex, workout) in week.workouts.enumerated() {
                if workout.id == workoutId {
                    // Calculate actual pace (only for distance-based workouts)
                    let distanceMiles: Double
                    let paceString: String

                    if let distance = healthKitWorkout.distance, distance > 0 {
                        distanceMiles = distance / 1609.34
                        let paceSecPerMile = healthKitWorkout.duration / distanceMiles
                        let paceMin = Int(paceSecPerMile / 60)
                        let paceSec = Int(paceSecPerMile.truncatingRemainder(dividingBy: 60))
                        paceString = String(format: "%d:%02d", paceMin, paceSec)
                    } else {
                        // Strength training or other non-distance workouts
                        distanceMiles = 0
                        paceString = "N/A"
                    }

                    let linkedWorkout = LinkedWorkout(
                        id: UUID(),
                        workoutId: healthKitWorkout.id.uuidString,
                        actualDistance: distanceMiles,
                        actualDuration: healthKitWorkout.duration,
                        actualPace: paceString,
                        completedDate: healthKitWorkout.date
                    )

                    // Create updated workout
                    let updatedWorkout = DailyWorkout(
                        id: workout.id,
                        date: workout.date,
                        type: workout.type,
                        distanceInMiles: workout.distanceInMiles,
                        durationInMinutes: workout.durationInMinutes,
                        paceMinPerMile: workout.paceMinPerMile,
                        description: workout.description,
                        isCompleted: true,
                        linkedWorkout: linkedWorkout
                    )

                    // Update the workout in the week
                    var updatedWorkouts = week.workouts
                    updatedWorkouts[workoutIndex] = updatedWorkout

                    // Update the week
                    updatedWeeks[weekIndex] = WeeklyPlan(
                        id: week.id,
                        weekNumber: week.weekNumber,
                        phase: week.phase,
                        workouts: updatedWorkouts,
                        startDate: week.startDate,
                        isStepbackWeek: week.isStepbackWeek,
                        recommendedMileage: week.recommendedMileage
                    )

                    // Update the plan
                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        daysPerWeek: plan.daysPerWeek,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
                        includeWorkouts: plan.includeWorkouts,
                        createdDate: plan.createdDate
                    )

                    // Update in both currentPlan and trainingPlans array
                    currentPlan = updatedPlan
                    if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                        trainingPlans[planIndex] = updatedPlan
                    }
                    return
                }
            }
        }
    }

    func unlinkWorkoutFromDay(workoutId: UUID) {
        guard var plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            for (workoutIndex, workout) in week.workouts.enumerated() {
                if workout.id == workoutId {
                    // Create updated workout without link
                    let updatedWorkout = DailyWorkout(
                        id: workout.id,
                        date: workout.date,
                        type: workout.type,
                        distanceInMiles: workout.distanceInMiles,
                        durationInMinutes: workout.durationInMinutes,
                        paceMinPerMile: workout.paceMinPerMile,
                        description: workout.description,
                        isCompleted: false,
                        linkedWorkout: nil
                    )

                    var updatedWorkouts = week.workouts
                    updatedWorkouts[workoutIndex] = updatedWorkout

                    updatedWeeks[weekIndex] = WeeklyPlan(
                        id: week.id,
                        weekNumber: week.weekNumber,
                        phase: week.phase,
                        workouts: updatedWorkouts,
                        startDate: week.startDate,
                        isStepbackWeek: week.isStepbackWeek,
                        recommendedMileage: week.recommendedMileage
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        daysPerWeek: plan.daysPerWeek,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
                        includeWorkouts: plan.includeWorkouts,
                        createdDate: plan.createdDate
                    )

                    // Update in both currentPlan and trainingPlans array
                    currentPlan = updatedPlan
                    if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                        trainingPlans[planIndex] = updatedPlan
                    }
                    return
                }
            }
        }
    }

    func skipWorkout(workoutId: UUID) {
        guard var plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            for (workoutIndex, workout) in week.workouts.enumerated() {
                if workout.id == workoutId {
                    // Mark workout as completed but with no linked workout data
                    let updatedWorkout = DailyWorkout(
                        id: workout.id,
                        date: workout.date,
                        type: workout.type,
                        distanceInMiles: workout.distanceInMiles,
                        durationInMinutes: workout.durationInMinutes,
                        paceMinPerMile: workout.paceMinPerMile,
                        description: workout.description + " (Skipped)",
                        isCompleted: true,
                        linkedWorkout: nil
                    )

                    var updatedWorkouts = week.workouts
                    updatedWorkouts[workoutIndex] = updatedWorkout

                    updatedWeeks[weekIndex] = WeeklyPlan(
                        id: week.id,
                        weekNumber: week.weekNumber,
                        phase: week.phase,
                        workouts: updatedWorkouts,
                        startDate: week.startDate,
                        isStepbackWeek: week.isStepbackWeek,
                        recommendedMileage: week.recommendedMileage
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        daysPerWeek: plan.daysPerWeek,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
                        includeWorkouts: plan.includeWorkouts,
                        createdDate: plan.createdDate
                    )

                    currentPlan = updatedPlan
                    if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                        trainingPlans[planIndex] = updatedPlan
                    }
                    return
                }
            }
        }
    }

    func unskipWorkout(workoutId: UUID) {
        guard var plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            for (workoutIndex, workout) in week.workouts.enumerated() {
                if workout.id == workoutId {
                    // Remove "(Skipped)" from description and mark as incomplete
                    let cleanedDescription = workout.description.replacingOccurrences(of: " (Skipped)", with: "")

                    let updatedWorkout = DailyWorkout(
                        id: workout.id,
                        date: workout.date,
                        type: workout.type,
                        distanceInMiles: workout.distanceInMiles,
                        durationInMinutes: workout.durationInMinutes,
                        paceMinPerMile: workout.paceMinPerMile,
                        description: cleanedDescription,
                        isCompleted: false,
                        linkedWorkout: nil
                    )

                    var updatedWorkouts = week.workouts
                    updatedWorkouts[workoutIndex] = updatedWorkout

                    updatedWeeks[weekIndex] = WeeklyPlan(
                        id: week.id,
                        weekNumber: week.weekNumber,
                        phase: week.phase,
                        workouts: updatedWorkouts,
                        startDate: week.startDate,
                        isStepbackWeek: week.isStepbackWeek,
                        recommendedMileage: week.recommendedMileage
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        daysPerWeek: plan.daysPerWeek,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
                        includeWorkouts: plan.includeWorkouts,
                        createdDate: plan.createdDate
                    )

                    currentPlan = updatedPlan
                    if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                        trainingPlans[planIndex] = updatedPlan
                    }
                    return
                }
            }
        }
    }

    func addManualWorkout(workoutId: UUID, distance: Double, duration: TimeInterval, date: Date) {
        guard var plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            for (workoutIndex, workout) in week.workouts.enumerated() {
                if workout.id == workoutId {
                    // Calculate pace (only for distance-based workouts)
                    let paceString: String
                    if distance > 0 {
                        let paceSecPerMile = duration / distance
                        let paceMin = Int(paceSecPerMile / 60)
                        let paceSec = Int(paceSecPerMile.truncatingRemainder(dividingBy: 60))
                        paceString = String(format: "%d:%02d", paceMin, paceSec)
                    } else {
                        // Strength training or other non-distance workouts
                        paceString = "N/A"
                    }

                    let linkedWorkout = LinkedWorkout(
                        id: UUID(),
                        workoutId: "manual-\(UUID().uuidString)",
                        actualDistance: distance,
                        actualDuration: duration,
                        actualPace: paceString,
                        completedDate: date
                    )

                    let updatedWorkout = DailyWorkout(
                        id: workout.id,
                        date: workout.date,
                        type: workout.type,
                        distanceInMiles: workout.distanceInMiles,
                        durationInMinutes: workout.durationInMinutes,
                        paceMinPerMile: workout.paceMinPerMile,
                        description: workout.description,
                        isCompleted: true,
                        linkedWorkout: linkedWorkout
                    )

                    var updatedWorkouts = week.workouts
                    updatedWorkouts[workoutIndex] = updatedWorkout

                    updatedWeeks[weekIndex] = WeeklyPlan(
                        id: week.id,
                        weekNumber: week.weekNumber,
                        phase: week.phase,
                        workouts: updatedWorkouts,
                        startDate: week.startDate,
                        isStepbackWeek: week.isStepbackWeek,
                        recommendedMileage: week.recommendedMileage
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        daysPerWeek: plan.daysPerWeek,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
                        includeWorkouts: plan.includeWorkouts,
                        createdDate: plan.createdDate
                    )

                    currentPlan = updatedPlan
                    if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                        trainingPlans[planIndex] = updatedPlan
                    }
                    return
                }
            }
        }
    }

    func addCustomWorkout(toWeekNumber weekNumber: Int, workoutType: WorkoutType, description: String, date: Date, distanceInMiles: Double? = nil, durationInMinutes: Int? = nil) {
        guard var plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        guard let weekIndex = updatedWeeks.firstIndex(where: { $0.weekNumber == weekNumber }) else { return }

        let week = updatedWeeks[weekIndex]

        // Create a new workout based on the type
        let trainingType: TrainingWorkoutType
        switch workoutType {
        case .strength:
            trainingType = .easy  // Use easy as placeholder for strength
        case .yoga, .mobility:
            trainingType = .easy  // Use easy as placeholder for yoga/mobility
        default:
            trainingType = .easy
        }

        let newWorkout = DailyWorkout(
            date: date,
            type: trainingType,
            distanceInMiles: distanceInMiles,
            durationInMinutes: durationInMinutes,
            paceMinPerMile: nil,
            description: description
        )

        var updatedWorkouts = week.workouts
        updatedWorkouts.append(newWorkout)
        updatedWorkouts.sort { $0.date < $1.date }

        updatedWeeks[weekIndex] = WeeklyPlan(
            id: week.id,
            weekNumber: week.weekNumber,
            phase: week.phase,
            workouts: updatedWorkouts,
            startDate: week.startDate,
            isStepbackWeek: week.isStepbackWeek,
            recommendedMileage: week.recommendedMileage
        )

        let updatedPlan = TrainingPlan(
            id: plan.id,
            name: plan.name,
            raceDistance: plan.raceDistance,
            raceDate: plan.raceDate,
            goalTimeInSeconds: plan.goalTimeInSeconds,
            minWeeklyMileage: plan.minWeeklyMileage,
            maxWeeklyMileage: plan.maxWeeklyMileage,
            daysPerWeek: plan.daysPerWeek,
            weeks: updatedWeeks,
            vdot: plan.vdot,
            allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
            includeWorkouts: plan.includeWorkouts,
            createdDate: plan.createdDate
        )

        currentPlan = updatedPlan
        if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
            trainingPlans[planIndex] = updatedPlan
        }
    }

    func deleteWorkout(workoutId: UUID) {
        guard var plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            if let workoutIndex = week.workouts.firstIndex(where: { $0.id == workoutId }) {
                var updatedWorkouts = week.workouts
                updatedWorkouts.remove(at: workoutIndex)

                updatedWeeks[weekIndex] = WeeklyPlan(
                    id: week.id,
                    weekNumber: week.weekNumber,
                    phase: week.phase,
                    workouts: updatedWorkouts,
                    startDate: week.startDate,
                    isStepbackWeek: week.isStepbackWeek,
                    recommendedMileage: week.recommendedMileage
                )

                let updatedPlan = TrainingPlan(
                    id: plan.id,
                    name: plan.name,
                    raceDistance: plan.raceDistance,
                    raceDate: plan.raceDate,
                    goalTimeInSeconds: plan.goalTimeInSeconds,
                    minWeeklyMileage: plan.minWeeklyMileage,
                    maxWeeklyMileage: plan.maxWeeklyMileage,
                    daysPerWeek: plan.daysPerWeek,
                    weeks: updatedWeeks,
                    vdot: plan.vdot,
                    allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
                    includeWorkouts: plan.includeWorkouts,
                    createdDate: plan.createdDate
                )

                currentPlan = updatedPlan
                if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                    trainingPlans[planIndex] = updatedPlan
                }
                return
            }
        }
    }

    // MARK: - Workout Day Editing

    func moveWorkout(from workoutId: UUID, toDay newDate: Date) {
        guard var plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            for (workoutIndex, workout) in week.workouts.enumerated() {
                if workout.id == workoutId {
                    // Create updated workout with new date
                    let updatedWorkout = DailyWorkout(
                        id: workout.id,
                        date: newDate,
                        type: workout.type,
                        distanceInMiles: workout.distanceInMiles,
                        durationInMinutes: workout.durationInMinutes,
                        paceMinPerMile: workout.paceMinPerMile,
                        description: workout.description,
                        isCompleted: workout.isCompleted,
                        linkedWorkout: workout.linkedWorkout
                    )

                    var updatedWorkouts = week.workouts
                    updatedWorkouts[workoutIndex] = updatedWorkout

                    updatedWeeks[weekIndex] = WeeklyPlan(
                        id: week.id,
                        weekNumber: week.weekNumber,
                        phase: week.phase,
                        workouts: updatedWorkouts.sorted { $0.date < $1.date },
                        startDate: week.startDate,
                        isStepbackWeek: week.isStepbackWeek,
                        recommendedMileage: week.recommendedMileage
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        daysPerWeek: plan.daysPerWeek,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
                        includeWorkouts: plan.includeWorkouts,
                        createdDate: plan.createdDate
                    )

                    // Update in both currentPlan and trainingPlans array
                    currentPlan = updatedPlan
                    if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                        trainingPlans[planIndex] = updatedPlan
                    }
                    return
                }
            }
        }
    }

    // MARK: - Persistence

    private func savePlans() {
        // Don't save while loading to avoid re-saving the same data
        guard !isLoadingPlans else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trainingPlans)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("💾 Training plans saved to storage (\(trainingPlans.count) plans)")
        } catch {
            print("❌ Failed to save training plans: \(error)")
        }
    }

    private func loadPlans() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            print("📭 No saved training plans found")
            return
        }

        do {
            isLoadingPlans = true
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let plans = try decoder.decode([TrainingPlan].self, from: data)
            trainingPlans = plans
            currentPlan = plans.first  // Set most recent plan as current
            isLoadingPlans = false
            print("📂 Training plans loaded from storage (\(plans.count) plans)")
        } catch {
            isLoadingPlans = false
            print("❌ Failed to load training plans: \(error)")
            // Clean up corrupted data
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }
}
