import Foundation
import SwiftUI

@MainActor
class TrainingPlanViewModel: ObservableObject {
    @Published var currentPlan: TrainingPlan?
    @Published var isCreatingPlan = false

    // Plan creation inputs
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

    // MARK: - Plan Generation

    func generatePlan() {
        isCreatingPlan = true

        let goalTime = TimeInterval(goalHours * 3600 + goalMinutes * 60 + goalSeconds)
        let vdot = VDOTCalculator.calculateVDOT(
            distanceInMeters: selectedDistance.meters,
            timeInSeconds: goalTime
        )

        let totalWeeks = selectedDistance.recommendedWeeks
        let weeksUntilRace = Calendar.current.dateComponents(
            [.weekOfYear],
            from: Date(),
            to: selectedRaceDate
        ).weekOfYear ?? totalWeeks

        let actualWeeks = min(totalWeeks, max(8, weeksUntilRace))

        var weeks: [WeeklyPlan] = []
        let startDate = Calendar.current.date(
            byAdding: .weekOfYear,
            value: -actualWeeks,
            to: selectedRaceDate
        ) ?? Date()

        // Generate weeks following Jack Daniels' phase structure
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
                vdot: vdot,
                raceDistance: selectedDistance,
                weekStartDate: weekStartDate
            )

            weeks.append(WeeklyPlan(
                weekNumber: weekNumber + 1,
                phase: phase,
                workouts: workouts,
                startDate: weekStartDate
            ))
        }

        currentPlan = TrainingPlan(
            raceDistance: selectedDistance,
            raceDate: selectedRaceDate,
            goalTimeInSeconds: goalTime,
            minWeeklyMileage: minWeeklyMileage,
            maxWeeklyMileage: maxWeeklyMileage,
            weeks: weeks,
            vdot: vdot,
            allowRecoveryAdjustments: allowRecoveryAdjustments
        )

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
        // Build up from min to max over first 75% of plan, then taper
        let buildWeeks = Int(Double(totalWeeks) * 0.75)
        let taperWeeks = totalWeeks - buildWeeks

        if weekNumber < buildWeeks {
            // Progressive build
            let progress = Double(weekNumber) / Double(buildWeeks)
            let mileageRange = maxWeeklyMileage - minWeeklyMileage
            return minWeeklyMileage + (mileageRange * progress)
        } else {
            // Taper phase
            let weeksIntoTaper = weekNumber - buildWeeks
            let taperProgress = Double(weeksIntoTaper) / Double(taperWeeks)
            return maxWeeklyMileage * (1.0 - (taperProgress * 0.4))  // 40% reduction
        }
    }

    // MARK: - Workout Generation

    private func generateWeeklyWorkouts(
        weekNumber: Int,
        phase: TrainingPhase,
        targetMileage: Double,
        vdot: Double,
        raceDistance: RaceDistance,
        weekStartDate: Date
    ) -> [DailyWorkout] {
        var workouts: [DailyWorkout] = []

        // Jack Daniels: 3 quality days per week + easy running
        let longRunDistance = calculateLongRunDistance(targetMileage: targetMileage, phase: phase)

        // Sunday: Long Run (always present except taper week)
        let isLastWeek = (targetMileage < maxWeeklyMileage * 0.7)
        if !isLastWeek {
            workouts.append(createWorkout(
                date: addDays(to: weekStartDate, days: 0),
                type: .long,
                distance: longRunDistance,
                vdot: vdot,
                description: "Long run at easy pace"
            ))
        } else {
            workouts.append(createWorkout(
                date: addDays(to: weekStartDate, days: 0),
                type: .easy,
                distance: 4,
                vdot: vdot,
                description: "Easy recovery run"
            ))
        }

        // Monday: Rest or Easy
        workouts.append(createWorkout(
            date: addDays(to: weekStartDate, days: 1),
            type: .rest,
            distance: nil,
            vdot: vdot,
            description: "Rest day"
        ))

        // Generate quality workouts based on phase
        let qualityWorkouts = generatePhaseSpecificQuality(
            phase: phase,
            weekStartDate: weekStartDate,
            vdot: vdot,
            raceDistance: raceDistance
        )
        workouts.append(contentsOf: qualityWorkouts)

        // Fill remaining days with easy runs
        let currentMileage = workouts.compactMap { $0.distanceInMiles }.reduce(0, +)
        let remainingMileage = max(0, targetMileage - currentMileage)
        let easyDays = 7 - workouts.count
        let easyMileagePerDay = easyDays > 0 ? remainingMileage / Double(easyDays) : 0

        var usedDays = Set(workouts.map { Calendar.current.component(.weekday, from: $0.date) })
        for day in 1..<7 {
            let weekday = (day + 1) % 7 + 1  // Convert to Calendar weekday (1 = Sunday)
            if !usedDays.contains(weekday) {
                workouts.append(createWorkout(
                    date: addDays(to: weekStartDate, days: day),
                    type: .easy,
                    distance: max(3, min(8, easyMileagePerDay)),
                    vdot: vdot,
                    description: "Easy run"
                ))
            }
        }

        return workouts.sorted { $0.date < $1.date }
    }

    private func generatePhaseSpecificQuality(
        phase: TrainingPhase,
        weekStartDate: Date,
        vdot: Double,
        raceDistance: RaceDistance
    ) -> [DailyWorkout] {
        var workouts: [DailyWorkout] = []

        switch phase {
        case .foundation:
            // Foundation: Light strides, no heavy quality
            workouts.append(createWorkout(
                date: addDays(to: weekStartDate, days: 3),  // Wednesday
                type: .easy,
                distance: 6,
                vdot: vdot,
                description: "Easy run + 4-6 strides"
            ))

        case .earlyQuality:
            // Early Quality: Long run + 2 Repetition workouts
            workouts.append(createWorkout(
                date: addDays(to: weekStartDate, days: 2),  // Tuesday
                type: .repetition,
                distance: 6,
                vdot: vdot,
                description: "6 x 400m @ R pace, equal rest"
            ))
            workouts.append(createWorkout(
                date: addDays(to: weekStartDate, days: 5),  // Friday
                type: .repetition,
                distance: 5,
                vdot: vdot,
                description: "8 x 200m @ R pace, 200m jog recovery"
            ))

        case .transitionQuality:
            // Transition: Threshold + Interval work
            workouts.append(createWorkout(
                date: addDays(to: weekStartDate, days: 2),  // Tuesday
                type: .interval,
                distance: 7,
                vdot: vdot,
                description: "5 x 1000m @ I pace, equal rest"
            ))
            workouts.append(createWorkout(
                date: addDays(to: weekStartDate, days: 4),  // Thursday
                type: .threshold,
                distance: 8,
                vdot: vdot,
                description: "20 min @ T pace"
            ))

        case .finalQuality:
            // Final Quality: Race-specific workouts
            if raceDistance == .marathon {
                workouts.append(createWorkout(
                    date: addDays(to: weekStartDate, days: 2),  // Tuesday
                    type: .threshold,
                    distance: 9,
                    vdot: vdot,
                    description: "2 x 15 min @ T pace, 2 min rest"
                ))
                workouts.append(createWorkout(
                    date: addDays(to: weekStartDate, days: 4),  // Thursday
                    type: .marathon,
                    distance: 10,
                    vdot: vdot,
                    description: "8 miles @ M pace"
                ))
            } else {
                workouts.append(createWorkout(
                    date: addDays(to: weekStartDate, days: 2),  // Tuesday
                    type: .interval,
                    distance: 7,
                    vdot: vdot,
                    description: "6 x 800m @ I pace, 2 min rest"
                ))
                workouts.append(createWorkout(
                    date: addDays(to: weekStartDate, days: 4),  // Thursday
                    type: .threshold,
                    distance: 7,
                    vdot: vdot,
                    description: "25 min @ T pace"
                ))
            }
        }

        return workouts
    }

    private func calculateLongRunDistance(targetMileage: Double, phase: TrainingPhase) -> Double {
        // Long run should be 25-30% of weekly mileage
        let percentage: Double = phase == .foundation ? 0.25 : 0.30
        return min(20, targetMileage * percentage)  // Cap at 20 miles
    }

    private func createWorkout(
        date: Date,
        type: WorkoutType,
        distance: Double?,
        vdot: Double,
        description: String
    ) -> DailyWorkout {
        let pace = type == .rest ? nil : VDOTCalculator.paceForWorkoutType(type, vdot: vdot)

        return DailyWorkout(
            date: date,
            type: type,
            distanceInMiles: distance,
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
}
