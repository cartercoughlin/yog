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
    @Published var longRunWeekday: Int = 1  // Calendar weekday: 1 = Sunday ... 7 = Saturday
    @Published var qualityWeekday: Int = 4  // Wednesday keeps two easy days before a Sunday long run

    // Recovery-based adjustment infrastructure
    @Published var lastRecoveryScore: Double?
    @Published var adjustmentSuggestion: String?

    // Reusable plan-setup presets
    @Published var planTemplates: [PlanTemplate] = [] {
        didSet {
            saveTemplates()
        }
    }

    private let healthKitManager = HealthKitManager()
    private let userDefaultsKey = "savedTrainingPlans"
    private let planVersionKey = "trainingPlanVersion"
    private let currentPlanVersion = 4  // Version 4: Dynamic weeks, workout toggle, half marathon 10mi cap
    private let templatesKey = "savedPlanTemplates"
    private var isLoadingPlans = false
    private var isLoadingTemplates = false

    init() {
        migrateIfNeeded()
        loadPlans()
        loadTemplates()
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        let savedVersion = UserDefaults.standard.integer(forKey: planVersionKey)

        // Schema changes are handled by backward-compatible decoding in
        // TrainingPlan's Codable conformance (decodeIfPresent with defaults),
        // so bumping the version must never delete a tester's saved plans -
        // that would wipe TestFlight users' data on every app update.
        if savedVersion < currentPlanVersion {
            UserDefaults.standard.set(currentPlanVersion, forKey: planVersionKey)
            print("🔄 Training plan schema updated to version \(currentPlanVersion) - existing plans preserved")
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

        // Include both the current calendar week and race week. The previous
        // whole-week calculation stopped the plan the day before races that
        // fell on the same weekday as the plan creation date.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let raceDay = calendar.startOfDay(for: selectedRaceDate)
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let raceWeekStart = calendar.dateInterval(of: .weekOfYear, for: raceDay)?.start ?? raceDay
        let weeksBetween = calendar.dateComponents(
            [.weekOfYear],
            from: currentWeekStart,
            to: raceWeekStart
        ).weekOfYear ?? 0
        let maxWeeksForDistance = selectedDistance.recommendedWeeks
        let actualWeeks = max(4, min(weeksBetween + 1, maxWeeksForDistance))

        var weeks: [WeeklyPlan] = []
        let startDate = calendar.date(
            byAdding: .weekOfYear,
            value: -(actualWeeks - 1),
            to: raceWeekStart
        ) ?? currentWeekStart

        // Generate weeks following periodized phase structure
        for weekNumber in 0..<actualWeeks {
            let displayedWeekNumber = weekNumber + 1
            let phase = determinePhase(weekNumber: weekNumber, totalWeeks: actualWeeks)
            let weekStartDate = calendar.date(
                byAdding: .weekOfYear,
                value: weekNumber,
                to: startDate
            ) ?? Date()

            var mileage = calculateWeeklyMileage(
                weekNumber: weekNumber,
                totalWeeks: actualWeeks,
                phase: phase
            )

            if marathonPeakLongRunKind(
                weekNumber: displayedWeekNumber,
                totalWeeks: actualWeeks,
                raceDistance: selectedDistance
            ) != nil {
                mileage = max(mileage, 20)
            }

            let weekEndDate = calendar.date(byAdding: .day, value: 7, to: weekStartDate) ?? weekStartDate
            if raceDay >= weekStartDate && raceDay < weekEndDate {
                // Weekly mileage includes the race itself.
                mileage = max(mileage, selectedDistance.meters / 1609.34)
            }

            let workouts = generateWeeklyWorkouts(
                weekNumber: displayedWeekNumber,
                totalWeeks: actualWeeks,
                phase: phase,
                targetMileage: mileage,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: selectedDistance,
                weekStartDate: weekStartDate,
                daysPerWeek: daysPerWeek,
                includeWorkouts: includeWorkouts,
                longRunWeekday: longRunWeekday,
                qualityWeekday: qualityWeekday,
                raceDate: raceDay
            )

            let isStepback = isStepbackWeek(weekNumber: displayedWeekNumber, totalWeeks: actualWeeks) &&
                marathonPeakLongRunKind(
                    weekNumber: displayedWeekNumber,
                    totalWeeks: actualWeeks,
                    raceDistance: selectedDistance
                ) == nil

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
            longRunWeekday: longRunWeekday,
            qualityWeekday: qualityWeekday,
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
        let weeksPerPhase = max(1, totalWeeks / 4)
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
        // `weekNumber` is zero-based here; the shared helper takes the
        // one-based number displayed to the runner.
        let isStepbackWeek = isStepbackWeek(
            weekNumber: weekNumber + 1,
            totalWeeks: totalWeeks
        )

        // Build to peak mileage, then taper for 1-3 weeks based on plan length.
        let taperWeeks = taperWeekCount(totalWeeks: totalWeeks)
        let buildWeeks = max(1, totalWeeks - taperWeeks)

        var baseMileage: Double

        if weekNumber < buildWeeks {
            // Progressive build with smoother curve (reduces spikes)
            let progress = buildWeeks > 1
                ? Double(weekNumber) / Double(buildWeeks - 1)
                : 1
            let mileageRange = maxWeeklyMileage - minWeeklyMileage

            // Use a smoother progression curve
            // Instead of linear, use a cubic ease-in curve for more gradual build
            let smoothProgress = pow(progress, 1.5)
            baseMileage = minWeeklyMileage + (mileageRange * smoothProgress)
        } else {
            // Taper phase
            let weeksIntoTaper = weekNumber - buildWeeks
            let taperFactors: [Double]
            switch taperWeeks {
            case 1: taperFactors = [0.50]
            case 2: taperFactors = [0.70, 0.50]
            default: taperFactors = [0.80, 0.65, 0.50]
            }
            baseMileage = maxWeeklyMileage * taperFactors[min(weeksIntoTaper, taperFactors.count - 1)]
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

        let taperStart = totalWeeks - taperWeekCount(totalWeeks: totalWeeks) + 1

        // Higdon-style recovery every third week, stopping before the taper.
        return weekNumber % 3 == 0 && weekNumber < taperStart
    }

    private func taperWeekCount(totalWeeks: Int) -> Int {
        if totalWeeks >= 16 { return 3 }
        if totalWeeks >= 8 { return 2 }
        return 1
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
        includeWorkouts: Bool,
        longRunWeekday: Int,
        qualityWeekday: Int,
        raceDate: Date
    ) -> [DailyWorkout] {
        var workouts: [DailyWorkout] = []

        let calendar = Calendar.current
        let weekEndDate = calendar.date(byAdding: .day, value: 7, to: weekStartDate) ?? weekStartDate
        let isRaceWeek = raceDate >= weekStartDate && raceDate < weekEndDate

        if isRaceWeek {
            return [createWorkout(
                date: raceDate,
                type: .racePace,
                distance: raceDistance.meters / 1609.34,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                description: "\(raceDistance.rawValue) race day"
            )]
        }

        let peakLongRunKind = marathonPeakLongRunKind(
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            raceDistance: raceDistance
        )
        let buildLongRunKind = marathonBuildLongRunKind(
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            raceDistance: raceDistance
        )
        let isStepback = isStepbackWeek(weekNumber: weekNumber, totalWeeks: totalWeeks) && peakLongRunKind == nil
        let longRunDistance = calculateLongRunDistance(
            targetMileage: targetMileage,
            phase: phase,
            isStepback: isStepback,
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            raceDistance: raceDistance,
            goalRacePaceSecPerMile: goalRacePaceSecPerMile
        )

        // Only generate quality days: Long Run + Quality Workout
        // HealthKit workouts will be pulled in automatically to show actual training

        // Long Run - Always included as quality day, on the user's chosen weekday
        let longRunDescription = generateLongRunDescription(
            phase: phase,
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            distance: longRunDistance,
            targetMileage: targetMileage,
            raceDistance: raceDistance,
            isStepback: isStepback
        )
        workouts.append(createWorkout(
            date: addDays(to: weekStartDate, days: dayOffset(forWeekday: longRunWeekday, from: weekStartDate)),
            type: .long,
            distance: longRunDistance,
            goalRacePaceSecPerMile: goalRacePaceSecPerMile,
            raceDistance: raceDistance,
            description: longRunDescription
        ))

        // Quality workout, on the user's chosen weekday (only if includeWorkouts is enabled)
        // - Not if workouts are disabled
        // - Not in foundation phase
        // - Not during final taper (last 2 weeks or ~12.5% of plan)
        // - Not on stepback weeks
        guard includeWorkouts else {
            return workouts.sorted { $0.date < $1.date }
        }

        let taperWeeks = taperWeekCount(totalWeeks: totalWeeks)
        let foundationWeeks = max(1, totalWeeks / 4)  // First ~25% is foundation
        let isFinalPreRaceWeek = weekNumber == totalWeeks - 1
        let isFoundationPhase = weekNumber <= foundationWeeks

        if !isFinalPreRaceWeek && !isStepback && !isFoundationPhase &&
            peakLongRunKind == nil && buildLongRunKind == nil {
            let safeQualityWeekday = qualityWeekdayWithAdequateRecovery(
                requested: qualityWeekday,
                longRunWeekday: longRunWeekday
            )
            let qualityWorkout = generateQualityWorkout(
                phase: phase,
                weekNumber: weekNumber,
                weekStartDate: weekStartDate,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                targetMileage: targetMileage,
                isStepback: isStepback,
                qualityWeekday: safeQualityWeekday,
                isTaper: weekNumber > totalWeeks - taperWeeks
            )
            workouts.append(qualityWorkout)
        }

        return workouts.sorted { $0.date < $1.date }
    }

    // MARK: - Weekday Helpers

    /// Number of days to add to `startDate` to land on the given calendar
    /// weekday (1 = Sunday ... 7 = Saturday), assuming `startDate` falls
    /// within the same week.
    private func dayOffset(forWeekday weekday: Int, from startDate: Date) -> Int {
        let calendar = Calendar.current
        let startWeekday = calendar.component(.weekday, from: startDate)
        return (weekday - startWeekday + 7) % 7
    }

    /// VDOT recommends at least two easy days between quality sessions.
    /// If the requested pairing is too close, place the speed session three
    /// days after the long run while keeping it in the same calendar week.
    private func qualityWeekdayWithAdequateRecovery(requested: Int, longRunWeekday: Int) -> Int {
        let directGap = abs(requested - longRunWeekday)
        let circularGap = min(directGap, 7 - directGap)
        guard circularGap < 3 else { return requested }
        return ((longRunWeekday - 1 + 3) % 7) + 1
    }

    // MARK: - Day-Specific Quality Workouts

    private func generateQualityWorkout(
        phase: TrainingPhase,
        weekNumber: Int,
        weekStartDate: Date,
        goalRacePaceSecPerMile: Double,
        raceDistance: RaceDistance,
        targetMileage: Double,
        isStepback: Bool,
        qualityWeekday: Int,
        isTaper: Bool
    ) -> DailyWorkout {
        let workoutDate = addDays(to: weekStartDate, days: dayOffset(forWeekday: qualityWeekday, from: weekStartDate))

        // On stepback weeks, reduce intensity
        if isStepback {
            return createWorkout(
                date: workoutDate,
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
                date: workoutDate,
                type: .easy,
                distance: 6,
                durationMinutes: 55,
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                description: "Easy run"
            )

        case .earlyQuality:
            // Early quality: Repetition work (400m repeats)
            // Daniels caps repetition work at about 5% of weekly mileage.
            let repsByVolume = max(2, Int((targetMileage * 0.05) / (400.0 / 1609.34)))
            let reps = min(12, min(8 + (weekNumber / 2), repsByVolume))
            let workMiles = Double(reps) * 400.0 / 1609.34
            return createWorkout(
                date: workoutDate,
                type: .repetition,
                distance: ceil(workMiles + 3),
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                description: "1.5 mi E, \(reps) × 400m @ R pace with 400m easy jog, 1.5 mi E"
            )

        case .transitionQuality:
            // Transition: Interval work (1000m repeats)
            // Keep I-pace work at or below roughly 8% of weekly volume.
            let reps = max(2, min(6, Int((targetMileage * 0.08) / (1000.0 / 1609.34))))
            let workMiles = Double(reps) * 1000.0 / 1609.34
            return createWorkout(
                date: workoutDate,
                type: .interval,
                distance: ceil(workMiles + 3),
                goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                raceDistance: raceDistance,
                description: "1.5 mi E, \(reps) × 1000m @ I pace with equal-time jog, 1.5 mi E"
            )

        case .finalQuality:
            // Final quality: Race-specific work
            if raceDistance == .marathon {
                if longRunIncludesMarathonPace(
                    phase: phase,
                    weekNumber: weekNumber,
                    raceDistance: raceDistance,
                    isStepback: isStepback
                ) {
                    let maximumThresholdMiles = max(1, min(5, Int(targetMileage * 0.10)))
                    let thresholdMiles = isTaper ? max(1, maximumThresholdMiles / 2) : maximumThresholdMiles
                    return createWorkout(
                        date: workoutDate,
                        type: .threshold,
                        distance: Double(thresholdMiles + 3),
                        goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                        raceDistance: raceDistance,
                        description: "1.5 mi E, \(thresholdMiles) × 1 mile @ T pace with 1 min jog, 1.5 mi E"
                    )
                }

                let maximumMPaceMiles = max(2, min(8, Int(targetMileage * 0.20)))
                let mPaceMiles = isTaper ? max(2, maximumMPaceMiles / 2) : maximumMPaceMiles
                return createWorkout(
                    date: workoutDate,
                    type: .marathon,
                    distance: Double(mPaceMiles + 4),
                    goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                    raceDistance: raceDistance,
                    description: "2 miles E, \(mPaceMiles) miles @ M pace, 2 miles E"
                )
            } else {
                let maximumThresholdMiles = max(1, min(5, Int(targetMileage * 0.10)))
                let thresholdMiles = isTaper ? max(1, maximumThresholdMiles / 2) : maximumThresholdMiles
                return createWorkout(
                    date: workoutDate,
                    type: .threshold,
                    distance: Double(thresholdMiles + 3),
                    goalRacePaceSecPerMile: goalRacePaceSecPerMile,
                    raceDistance: raceDistance,
                    description: "1.5 mi E, \(thresholdMiles) × 1 mile @ T pace with 1 min jog, 1.5 mi E"
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
        raceDistance: RaceDistance,
        goalRacePaceSecPerMile: Double
    ) -> Double {
        if marathonPeakLongRunKind(
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            raceDistance: raceDistance
        ) != nil {
            return 20
        }

        if let buildLongRunKind = marathonBuildLongRunKind(
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            raceDistance: raceDistance
        ) {
            return buildLongRunKind.distance
        }

        // Long run should be 25-30% of weekly mileage
        let percentage: Double = phase == .foundation ? 0.25 : 0.30
        var distance = targetMileage * percentage

        // Cap based on race distance
        switch raceDistance {
        case .fiveK, .tenK:
            distance = min(12, distance)  // Cap at 12 miles for shorter races
        case .halfMarathon:
            // Keep the race-specific cap without overriding the weekly-volume cap.
            distance = min(10, distance)
        case .marathon:
            distance = min(21, distance)  // Cap at 21 miles for marathon

            // Do not force 20-mile runs when the configured weekly volume
            // cannot support them. The percentage cap above remains binding.
        }

        // Reduce long run on stepback weeks
        if isStepback {
            distance *= 0.80
        }

        // VDOT caps long runs at 150 minutes as well as 25-30% of weekly mileage.
        let estimatedEasyPace = goalRacePaceSecPerMile * 1.30
        let timeCappedDistance = (150.0 * 60.0) / estimatedEasyPace
        let weeklyVolumeCap = targetMileage * percentage
        return max(3, min(distance, weeklyVolumeCap, timeCappedDistance))
    }

    private func generateLongRunDescription(
        phase: TrainingPhase,
        weekNumber: Int,
        totalWeeks: Int,
        distance: Double,
        targetMileage: Double,
        raceDistance: RaceDistance,
        isStepback: Bool
    ) -> String {
        let miles = Int(distance.rounded())

        switch marathonPeakLongRunKind(
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            raceDistance: raceDistance
        ) {
        case .easy:
            return "20 miles easy, conversational effort"
        case .workout:
            return "20 miles: 14 easy + 5 miles @ M pace + 1 easy"
        case .progression:
            return "20 miles: 15 easy + 5 miles steady, faster than easy but slower than M pace"
        case nil:
            break
        }

        switch marathonBuildLongRunKind(
            weekNumber: weekNumber,
            totalWeeks: totalWeeks,
            raceDistance: raceDistance
        ) {
        case .sixteenProgression:
            return "16 miles: 3 easy + 10 miles progressing from M pace to HM pace + 3 easy"
        case .eighteenTwoByFive:
            return "18 miles: 3 easy + 2 × 5 miles @ M pace with 1 mile easy between + 4 easy"
        case nil:
            break
        }

        // Stepback weeks: just easy running
        if isStepback {
            return "\(miles) miles easy"
        }

        if longRunIncludesMarathonPace(
            phase: phase,
            weekNumber: weekNumber,
            raceDistance: raceDistance,
            isStepback: isStepback
        ), miles >= 8 {
            // Keep M-pace work below both 20% of weekly mileage and roughly
            // one-third of the long run. Alternate weeks receive a dedicated
            // M workout instead, preventing duplicate M sessions.
            let weeklyCap = max(1, Int(targetMileage * 0.20))
            let longRunCap = max(1, miles / 3)
            let mPaceMiles = min(weeklyCap, longRunCap)
            return "\(miles) miles: \(miles - mPaceMiles) easy + \(mPaceMiles) miles @ M pace"
        }

        return "\(miles) miles easy, conversational effort"
    }

    private func longRunIncludesMarathonPace(
        phase: TrainingPhase,
        weekNumber: Int,
        raceDistance: RaceDistance,
        isStepback: Bool
    ) -> Bool {
        raceDistance == .marathon &&
            phase == .finalQuality &&
            !isStepback &&
            weekNumber.isMultiple(of: 2)
    }

    private enum MarathonPeakLongRunKind {
        case easy
        case progression
        case workout
    }

    private enum MarathonBuildLongRunKind {
        case sixteenProgression
        case eighteenTwoByFive

        var distance: Double {
            switch self {
            case .sixteenProgression: return 16
            case .eighteenTwoByFive: return 18
            }
        }
    }

    /// Full marathon builds use the same race-specific long-run spine at
    /// every mileage setting. The two nearest non-stepback weeks before the
    /// first 20-miler become a 16-mile progression and an 18-mile MP workout.
    private func marathonBuildLongRunKind(
        weekNumber: Int,
        totalWeeks: Int,
        raceDistance: RaceDistance
    ) -> MarathonBuildLongRunKind? {
        guard raceDistance == .marathon, totalWeeks >= 14 else { return nil }

        let preRaceWeeks = totalWeeks - 1
        var firstTwentyWeek = preRaceWeeks >= 8 ? totalWeeks - 8 : 1
        firstTwentyWeek = min(firstTwentyWeek, preRaceWeeks - 1)

        let eligibleBuildWeeks = (1..<firstTwentyWeek)
            .reversed()
            .filter { !isStepbackWeek(weekNumber: $0, totalWeeks: totalWeeks) }

        guard eligibleBuildWeeks.count >= 2 else { return nil }
        if weekNumber == eligibleBuildWeeks[0] { return .eighteenTwoByFive }
        if weekNumber == eligibleBuildWeeks[1] { return .sixteenProgression }
        return nil
    }

    /// Marathon plans always include two distinct 20-mile peaks. When the
    /// plan is long enough they land about eight and four weeks before race
    /// week, matching the race-countback pattern documented in the README.
    private func marathonPeakLongRunKind(
        weekNumber: Int,
        totalWeeks: Int,
        raceDistance: RaceDistance
    ) -> MarathonPeakLongRunKind? {
        guard raceDistance == .marathon, totalWeeks >= 4 else { return nil }

        let preRaceWeeks = totalWeeks - 1
        var easyPeakWeek = preRaceWeeks >= 8 ? totalWeeks - 8 : 1
        var workoutPeakWeek = preRaceWeeks >= 4 ? totalWeeks - 4 : preRaceWeeks

        easyPeakWeek = min(easyPeakWeek, preRaceWeeks - 1)
        if workoutPeakWeek == easyPeakWeek {
            workoutPeakWeek = min(preRaceWeeks, easyPeakWeek + 1)
        }

        if weekNumber == easyPeakWeek { return .easy }
        if maxWeeklyMileage > 40 {
            var progressionPeakWeek = preRaceWeeks >= 6 ? totalWeeks - 6 : max(2, preRaceWeeks / 2)
            if progressionPeakWeek == easyPeakWeek {
                progressionPeakWeek = min(preRaceWeeks, easyPeakWeek + 1)
            }
            if progressionPeakWeek == workoutPeakWeek {
                progressionPeakWeek = max(1, workoutPeakWeek - 1)
            }
            if weekNumber == progressionPeakWeek { return .progression }
        }
        if weekNumber == workoutPeakWeek { return .workout }
        return nil
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

    /// Applies `transform` to the workout matching `workoutId` and persists the
    /// resulting plan into both `currentPlan` and `trainingPlans`.
    private func updateWorkout(workoutId: UUID, transform: (DailyWorkout) -> DailyWorkout) {
        guard let plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            guard let workoutIndex = week.workouts.firstIndex(where: { $0.id == workoutId }) else { continue }

            var updatedWorkouts = week.workouts
            updatedWorkouts[workoutIndex] = transform(updatedWorkouts[workoutIndex])
            updatedWorkouts.sort { $0.date < $1.date }

            updatedWeeks[weekIndex] = week.withWorkouts(updatedWorkouts)

            let updatedPlan = plan.withWeeks(updatedWeeks)
            currentPlan = updatedPlan
            if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                trainingPlans[planIndex] = updatedPlan
            }
            return
        }
    }

    func linkWorkoutToDay(workoutId: UUID, healthKitWorkout: WorkoutData) {
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

        updateWorkout(workoutId: workoutId) { workout in
            DailyWorkout(
                id: workout.id,
                date: workout.date,
                type: workout.type,
                distanceInMiles: workout.distanceInMiles,
                durationInMinutes: workout.durationInMinutes,
                paceMinPerMile: workout.paceMinPerMile,
                description: workout.description,
                isCompleted: true,
                linkedWorkout: linkedWorkout,
                customPaceOverride: workout.customPaceOverride
            )
        }
    }

    func unlinkWorkoutFromDay(workoutId: UUID) {
        updateWorkout(workoutId: workoutId) { workout in
            DailyWorkout(
                id: workout.id,
                date: workout.date,
                type: workout.type,
                distanceInMiles: workout.distanceInMiles,
                durationInMinutes: workout.durationInMinutes,
                paceMinPerMile: workout.paceMinPerMile,
                description: workout.description,
                isCompleted: false,
                linkedWorkout: nil,
                customPaceOverride: workout.customPaceOverride
            )
        }
    }

    func skipWorkout(workoutId: UUID) {
        updateWorkout(workoutId: workoutId) { workout in
            DailyWorkout(
                id: workout.id,
                date: workout.date,
                type: workout.type,
                distanceInMiles: workout.distanceInMiles,
                durationInMinutes: workout.durationInMinutes,
                paceMinPerMile: workout.paceMinPerMile,
                description: workout.description + " (Skipped)",
                isCompleted: true,
                linkedWorkout: nil,
                customPaceOverride: workout.customPaceOverride
            )
        }
    }

    func unskipWorkout(workoutId: UUID) {
        updateWorkout(workoutId: workoutId) { workout in
            let cleanedDescription = workout.description.replacingOccurrences(of: " (Skipped)", with: "")
            return DailyWorkout(
                id: workout.id,
                date: workout.date,
                type: workout.type,
                distanceInMiles: workout.distanceInMiles,
                durationInMinutes: workout.durationInMinutes,
                paceMinPerMile: workout.paceMinPerMile,
                description: cleanedDescription,
                isCompleted: false,
                linkedWorkout: nil,
                customPaceOverride: workout.customPaceOverride
            )
        }
    }

    func addManualWorkout(workoutId: UUID, distance: Double, duration: TimeInterval, date: Date) {
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

        updateWorkout(workoutId: workoutId) { workout in
            DailyWorkout(
                id: workout.id,
                date: workout.date,
                type: workout.type,
                distanceInMiles: workout.distanceInMiles,
                durationInMinutes: workout.durationInMinutes,
                paceMinPerMile: workout.paceMinPerMile,
                description: workout.description,
                isCompleted: true,
                linkedWorkout: linkedWorkout,
                customPaceOverride: workout.customPaceOverride
            )
        }
    }

    /// Lets the user override a workout's type, distance, duration,
    /// description, and pace after the plan has already been generated.
    func editWorkout(
        workoutId: UUID,
        type: TrainingWorkoutType,
        distanceInMiles: Double?,
        durationInMinutes: Int?,
        description: String,
        customPaceOverride: String?
    ) {
        updateWorkout(workoutId: workoutId) { workout in
            DailyWorkout(
                id: workout.id,
                date: workout.date,
                type: type,
                distanceInMiles: distanceInMiles,
                durationInMinutes: durationInMinutes,
                paceMinPerMile: workout.paceMinPerMile,
                description: description,
                isCompleted: workout.isCompleted,
                linkedWorkout: workout.linkedWorkout,
                customPaceOverride: customPaceOverride
            )
        }
    }

    func addCustomWorkout(toWeekNumber weekNumber: Int, workoutType: WorkoutType, description: String, date: Date, distanceInMiles: Double? = nil, durationInMinutes: Int? = nil) {
        guard let plan = currentPlan else { return }

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

        updatedWeeks[weekIndex] = week.withWorkouts(updatedWorkouts)

        let updatedPlan = plan.withWeeks(updatedWeeks)
        currentPlan = updatedPlan
        if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
            trainingPlans[planIndex] = updatedPlan
        }
    }

    func deleteWorkout(workoutId: UUID) {
        guard let plan = currentPlan else { return }

        var updatedWeeks = plan.weeks
        for (weekIndex, week) in updatedWeeks.enumerated() {
            guard let workoutIndex = week.workouts.firstIndex(where: { $0.id == workoutId }) else { continue }

            var updatedWorkouts = week.workouts
            updatedWorkouts.remove(at: workoutIndex)
            updatedWeeks[weekIndex] = week.withWorkouts(updatedWorkouts)

            let updatedPlan = plan.withWeeks(updatedWeeks)
            currentPlan = updatedPlan
            if let planIndex = trainingPlans.firstIndex(where: { $0.id == plan.id }) {
                trainingPlans[planIndex] = updatedPlan
            }
            return
        }
    }

    // MARK: - Workout Day Editing

    func moveWorkout(from workoutId: UUID, toDay newDate: Date) {
        updateWorkout(workoutId: workoutId) { workout in
            DailyWorkout(
                id: workout.id,
                date: newDate,
                type: workout.type,
                distanceInMiles: workout.distanceInMiles,
                durationInMinutes: workout.durationInMinutes,
                paceMinPerMile: workout.paceMinPerMile,
                description: workout.description,
                isCompleted: workout.isCompleted,
                linkedWorkout: workout.linkedWorkout,
                customPaceOverride: workout.customPaceOverride
            )
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
            currentPlan = plans.first(where: { $0.currentWeek != nil }) ?? plans.first
            isLoadingPlans = false
            print("📂 Training plans loaded from storage (\(plans.count) plans)")
        } catch {
            isLoadingPlans = false
            print("❌ Failed to load training plans: \(error)")
            // Clean up corrupted data
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }

    // MARK: - Plan Templates

    func saveCurrentSettingsAsTemplate(name: String) {
        let template = PlanTemplate(
            name: name,
            currentWeeklyMileage: currentWeeklyMileage,
            minWeeklyMileage: minWeeklyMileage,
            maxWeeklyMileage: maxWeeklyMileage,
            daysPerWeek: daysPerWeek,
            includeWorkouts: includeWorkouts,
            allowRecoveryAdjustments: allowRecoveryAdjustments,
            longRunWeekday: longRunWeekday,
            qualityWeekday: qualityWeekday
        )
        planTemplates.append(template)
    }

    func applyTemplate(_ template: PlanTemplate) {
        currentWeeklyMileage = template.currentWeeklyMileage
        minWeeklyMileage = template.minWeeklyMileage
        maxWeeklyMileage = template.maxWeeklyMileage
        daysPerWeek = template.daysPerWeek
        includeWorkouts = template.includeWorkouts
        allowRecoveryAdjustments = template.allowRecoveryAdjustments
        longRunWeekday = template.longRunWeekday
        qualityWeekday = template.qualityWeekday
    }

    func deleteTemplates(at offsets: IndexSet) {
        planTemplates.remove(atOffsets: offsets)
    }

    private func saveTemplates() {
        guard !isLoadingTemplates else { return }

        do {
            let data = try JSONEncoder().encode(planTemplates)
            UserDefaults.standard.set(data, forKey: templatesKey)
        } catch {
            print("❌ Failed to save plan templates: \(error)")
        }
    }

    private func loadTemplates() {
        guard let data = UserDefaults.standard.data(forKey: templatesKey) else { return }

        do {
            isLoadingTemplates = true
            planTemplates = try JSONDecoder().decode([PlanTemplate].self, from: data)
            isLoadingTemplates = false
        } catch {
            isLoadingTemplates = false
            print("❌ Failed to load plan templates: \(error)")
            UserDefaults.standard.removeObject(forKey: templatesKey)
        }
    }
}
