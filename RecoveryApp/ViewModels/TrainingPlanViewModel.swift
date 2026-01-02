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
    @Published var minWeeklyMileage: Double = 40
    @Published var maxWeeklyMileage: Double = 55
    @Published var allowRecoveryAdjustments = true

    // Recovery-based adjustment infrastructure
    @Published var lastRecoveryScore: Double?
    @Published var adjustmentSuggestion: String?

    private let healthKitManager = HealthKitManager()
    private let userDefaultsKey = "savedTrainingPlans"
    private var isLoadingPlans = false

    init() {
        loadPlans()
    }

    // MARK: - Plan Generation

    func generatePlan() {
        isCreatingPlan = true

        let goalTime = TimeInterval(goalHours * 3600 + goalMinutes * 60 + goalSeconds)
        let vdot = VDOTCalculator.calculateVDOT(
            distanceInMeters: selectedDistance.meters,
            timeInSeconds: goalTime
        )

        // Calculate goal marathon pace (seconds per mile)
        let marathonMiles = selectedDistance.meters / 1609.34
        let goalMarathonPaceSecPerMile = goalTime / marathonMiles

        // Always create a 16-week plan regardless of race date
        let actualWeeks = 16

        var weeks: [WeeklyPlan] = []
        let startDate = Calendar.current.date(
            byAdding: .weekOfYear,
            value: -actualWeeks,
            to: selectedRaceDate
        ) ?? Date()

        // Generate weeks following periodized phase structure
        for weekNumber in 0..<actualWeeks {
            let phase = determinePhase(weekNumber: weekNumber, totalWeeks: actualWeeks)
            let weekStartDate = Calendar.current.date(
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
                phase: phase,
                targetMileage: mileage,
                goalMarathonPaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: selectedDistance,
                weekStartDate: weekStartDate
            )

            let isStepback = isStepbackWeek(weekNumber: weekNumber + 1, totalWeeks: actualWeeks)

            weeks.append(WeeklyPlan(
                weekNumber: weekNumber + 1,
                phase: phase,
                workouts: workouts,
                startDate: weekStartDate,
                isStepbackWeek: isStepback
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
            weeks: weeks,
            vdot: vdot,
            allowRecoveryAdjustments: allowRecoveryAdjustments,
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
        // Every 4th week is a stepback, except during final taper (last 2 weeks)
        return (weekNumber % 4 == 0) && weekNumber < (totalWeeks - 2)
    }

    // MARK: - Workout Generation

    private func generateWeeklyWorkouts(
        weekNumber: Int,
        phase: TrainingPhase,
        targetMileage: Double,
        goalMarathonPaceSecPerMile: Double,
        raceDistance: RaceDistance,
        weekStartDate: Date
    ) -> [DailyWorkout] {
        var workouts: [DailyWorkout] = []

        let isStepback = isStepbackWeek(weekNumber: weekNumber, totalWeeks: 16)
        let longRunDistance = calculateLongRunDistance(
            targetMileage: targetMileage,
            phase: phase,
            isStepback: isStepback,
            weekNumber: weekNumber,
            raceDistance: raceDistance
        )

        // Consistent weekly structure inspired by Bandit Running and Hal Higdon
        // Sunday (day 0): Long Run
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
            goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
            raceDistance: raceDistance,
            description: longRunDescription
        ))

        // Monday (day 1): Easy run with strides/accelerations
        let mondayDistance = isStepback ? 4.0 : min(6.0, targetMileage * 0.12)
        workouts.append(createWorkout(
            date: addDays(to: weekStartDate, days: 1),
            type: .easy,
            distance: mondayDistance,
            durationMinutes: Int(mondayDistance * 9.5),  // ~9.5 min/mile average
            goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
            raceDistance: raceDistance,
            description: phase == .foundation ? "Easy run" : "Easy run + 6 × 100m strides"
        ))

        // Tuesday (day 2): Quality workout (only ONE per week, eliminated during final 2-week taper)
        let isTaperWeek = weekNumber >= 15  // Weeks 15 and 16 are taper weeks
        if !isTaperWeek && !isStepback {
            let tuesdayWorkout = generateTuesdayQuality(
                phase: phase,
                weekNumber: weekNumber,
                weekStartDate: weekStartDate,
                goalMarathonPaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                isStepback: isStepback
            )
            workouts.append(tuesdayWorkout)
        } else {
            // Taper or stepback week: easy run instead of quality
            workouts.append(createWorkout(
                date: addDays(to: weekStartDate, days: 2),
                type: .easy,
                distance: 5,
                durationMinutes: 50,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "Easy run"
            ))
        }

        // Wednesday (day 3): Easy recovery run
        let wednesdayDistance = isStepback ? 4.0 : min(6.0, targetMileage * 0.10)
        workouts.append(createWorkout(
            date: addDays(to: weekStartDate, days: 3),
            type: .easy,
            distance: wednesdayDistance,
            durationMinutes: Int(wednesdayDistance * 9.5),
            goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
            raceDistance: raceDistance,
            description: "Easy recovery run"
        ))

        // Thursday (day 4): Always easy (removed second quality workout)
        let thursdayDistance = isStepback ? 4.0 : min(6.0, targetMileage * 0.12)
        workouts.append(createWorkout(
            date: addDays(to: weekStartDate, days: 4),
            type: .easy,
            distance: thursdayDistance,
            durationMinutes: Int(thursdayDistance * 9.5),
            goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
            raceDistance: raceDistance,
            description: "Easy run"
        ))

        // Friday (day 5): Rest day
        workouts.append(createWorkout(
            date: addDays(to: weekStartDate, days: 5),
            type: .rest,
            distance: nil,
            goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
            raceDistance: raceDistance,
            description: "Rest day"
        ))

        // Saturday (day 6): Easy or race pace run
        let saturdayDistance = calculateSaturdayDistance(
            targetMileage: targetMileage,
            currentMileage: workouts.compactMap { $0.distanceInMiles }.reduce(0, +),
            isStepback: isStepback
        )
        let saturdayWorkout = generateSaturdayWorkout(
            phase: phase,
            weekNumber: weekNumber,
            distance: saturdayDistance,
            weekStartDate: weekStartDate,
            goalMarathonPaceSecPerMile: goalMarathonPaceSecPerMile,
            raceDistance: raceDistance
        )
        workouts.append(saturdayWorkout)

        return workouts.sorted { $0.date < $1.date }
    }

    private func calculateSaturdayDistance(targetMileage: Double, currentMileage: Double, isStepback: Bool) -> Double {
        let remaining = max(0, targetMileage - currentMileage)
        return max(4, min(8, remaining))
    }

    // MARK: - Day-Specific Quality Workouts

    private func generateTuesdayQuality(
        phase: TrainingPhase,
        weekNumber: Int,
        weekStartDate: Date,
        goalMarathonPaceSecPerMile: Double,
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
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "Easy run"
            )
        }

        switch phase {
        case .foundation:
            // Foundation phase: tempo runs or fartlek
            return createWorkout(
                date: addDays(to: weekStartDate, days: 2),
                type: .threshold,
                distance: 6,
                durationMinutes: 50,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "20 min @ T pace (tempo)"
            )

        case .earlyQuality:
            // Early quality: Repetition work (400m repeats)
            let reps = min(12, 8 + (weekNumber / 2))
            return createWorkout(
                date: addDays(to: weekStartDate, days: 2),
                type: .repetition,
                distance: 7,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "\(reps) × 400m @ R pace, 90 sec rest"
            )

        case .transitionQuality:
            // Transition: Interval work (800m-1000m)
            return createWorkout(
                date: addDays(to: weekStartDate, days: 2),
                type: .interval,
                distance: 8,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
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
                    goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                    description: "2 miles E, 6 miles @ M pace, 2 miles E"
                )
            } else {
                return createWorkout(
                    date: addDays(to: weekStartDate, days: 2),
                    type: .interval,
                    distance: 8,
                    goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                    description: "5 × 1 mile @ I pace, 2 min rest"
                )
            }
        }
    }

    private func generateThursdayQuality(
        phase: TrainingPhase,
        weekNumber: Int,
        weekStartDate: Date,
        goalMarathonPaceSecPerMile: Double,
        raceDistance: RaceDistance,
        isStepback: Bool
    ) -> DailyWorkout {
        // On stepback weeks, easy run instead of quality
        if isStepback {
            return createWorkout(
                date: addDays(to: weekStartDate, days: 4),
                type: .easy,
                distance: 5,
                durationMinutes: 50,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "Easy run"
            )
        }

        // Every 3rd week that's not a stepback: hill repeats
        // Otherwise: tempo/threshold work
        if weekNumber % 3 == 1 {
            let hillCount = min(10, 6 + (weekNumber / 3))
            return createWorkout(
                date: addDays(to: weekStartDate, days: 4),
                type: .hill,
                distance: 7,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "\(hillCount) × 300m hills, jog down recovery"
            )
        }

        switch phase {
        case .foundation:
            return createWorkout(
                date: addDays(to: weekStartDate, days: 4),
                type: .easy,
                distance: 6,
                durationMinutes: 55,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "Easy run + 6 × 100m strides"
            )

        case .earlyQuality:
            return createWorkout(
                date: addDays(to: weekStartDate, days: 4),
                type: .threshold,
                distance: 7,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "2 × 2 miles @ T pace, 1 min rest (cruise intervals)"
            )

        case .transitionQuality:
            return createWorkout(
                date: addDays(to: weekStartDate, days: 4),
                type: .threshold,
                distance: 8,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "3 × 1.5 miles @ T pace, 1 min rest"
            )

        case .finalQuality:
            return createWorkout(
                date: addDays(to: weekStartDate, days: 4),
                type: .threshold,
                distance: 8,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "30 min continuous @ T pace"
            )
        }
    }

    private func generateSaturdayWorkout(
        phase: TrainingPhase,
        weekNumber: Int,
        distance: Double,
        weekStartDate: Date,
        goalMarathonPaceSecPerMile: Double,
        raceDistance: RaceDistance
    ) -> DailyWorkout {
        // Saturday workouts transition from easy to race pace as training progresses
        if phase == .finalQuality && raceDistance == .marathon && weekNumber >= 12 {
            return createWorkout(
                date: addDays(to: weekStartDate, days: 6),
                type: .racePace,
                distance: distance,
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "\(Int(distance)) miles @ goal marathon pace"
            )
        } else {
            return createWorkout(
                date: addDays(to: weekStartDate, days: 6),
                type: .easy,
                distance: distance,
                durationMinutes: Int(distance * 9.5),
                goalRacePaceSecPerMile: goalMarathonPaceSecPerMile,
                raceDistance: raceDistance,
                description: "Easy run"
            )
        }
    }

    private func calculateLongRunDistance(
        targetMileage: Double,
        phase: TrainingPhase,
        isStepback: Bool,
        weekNumber: Int,
        raceDistance: RaceDistance
    ) -> Double {
        // Long run should be 25-30% of weekly mileage
        let percentage: Double = phase == .foundation ? 0.25 : 0.30
        var distance = min(21, targetMileage * percentage)  // Cap at 21 miles

        // For marathon training, ensure we hit 3 long runs of 20-21 miles
        // These should be in weeks 10, 12, and 14 (before final taper)
        if raceDistance == .marathon {
            if weekNumber == 10 || weekNumber == 12 || weekNumber == 14 {
                distance = max(distance, 20)  // Ensure at least 20 miles
            }
        }

        // Reduce long run on stepback weeks
        if isStepback {
            distance *= 0.80
        }

        return max(8, distance)  // Minimum 8 miles
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
                    // Calculate actual pace
                    let distanceMiles = healthKitWorkout.distance! / 1609.34
                    let paceSecPerMile = healthKitWorkout.duration / distanceMiles
                    let paceMin = Int(paceSecPerMile / 60)
                    let paceSec = Int(paceSecPerMile.truncatingRemainder(dividingBy: 60))
                    let paceString = String(format: "%d:%02d", paceMin, paceSec)

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
                        isStepbackWeek: week.isStepbackWeek
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
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
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
                        isStepbackWeek: week.isStepbackWeek
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
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
                        isStepbackWeek: week.isStepbackWeek
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
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
                        isStepbackWeek: week.isStepbackWeek
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
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
                    // Calculate pace
                    let paceSecPerMile = duration / distance
                    let paceMin = Int(paceSecPerMile / 60)
                    let paceSec = Int(paceSecPerMile.truncatingRemainder(dividingBy: 60))
                    let paceString = String(format: "%d:%02d", paceMin, paceSec)

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
                        isStepbackWeek: week.isStepbackWeek
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
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
            isStepbackWeek: week.isStepbackWeek
        )

        let updatedPlan = TrainingPlan(
            id: plan.id,
            name: plan.name,
            raceDistance: plan.raceDistance,
            raceDate: plan.raceDate,
            goalTimeInSeconds: plan.goalTimeInSeconds,
            minWeeklyMileage: plan.minWeeklyMileage,
            maxWeeklyMileage: plan.maxWeeklyMileage,
            weeks: updatedWeeks,
            vdot: plan.vdot,
            allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
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
                    isStepbackWeek: week.isStepbackWeek
                )

                let updatedPlan = TrainingPlan(
                    id: plan.id,
                    name: plan.name,
                    raceDistance: plan.raceDistance,
                    raceDate: plan.raceDate,
                    goalTimeInSeconds: plan.goalTimeInSeconds,
                    minWeeklyMileage: plan.minWeeklyMileage,
                    maxWeeklyMileage: plan.maxWeeklyMileage,
                    weeks: updatedWeeks,
                    vdot: plan.vdot,
                    allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
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
                        isStepbackWeek: week.isStepbackWeek
                    )

                    let updatedPlan = TrainingPlan(
                        id: plan.id,
                        name: plan.name,
                        raceDistance: plan.raceDistance,
                        raceDate: plan.raceDate,
                        goalTimeInSeconds: plan.goalTimeInSeconds,
                        minWeeklyMileage: plan.minWeeklyMileage,
                        maxWeeklyMileage: plan.maxWeeklyMileage,
                        weeks: updatedWeeks,
                        vdot: plan.vdot,
                        allowRecoveryAdjustments: plan.allowRecoveryAdjustments,
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
