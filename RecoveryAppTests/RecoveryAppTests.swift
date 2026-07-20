//
//  RecoveryAppTests.swift
//  YogTests
//
//  Created by Carter Coughlin on 11/22/25.
//

import Foundation
import Testing
@testable import Yog

@Suite(.serialized)
struct TrainingPlanGenerationTests {
    private let planKeys = ["savedTrainingPlans", "trainingPlanVersion", "savedPlanTemplates"]

    @MainActor
    @Test func marathonPlanHonorsDocumentedTrainingInvariants() throws {
        for key in planKeys { UserDefaults.standard.removeObject(forKey: key) }
        defer { for key in planKeys { UserDefaults.standard.removeObject(forKey: key) } }

        let calendar = Calendar.current
        let currentWeekStart = try #require(calendar.dateInterval(of: .weekOfYear, for: Date())?.start)
        let raceDate = try #require(calendar.date(byAdding: .weekOfYear, value: 17, to: currentWeekStart))

        let viewModel = TrainingPlanViewModel()
        viewModel.selectedDistance = .marathon
        viewModel.selectedRaceDate = raceDate
        viewModel.goalHours = 3
        viewModel.goalMinutes = 30
        viewModel.currentWeeklyMileage = 40
        viewModel.minWeeklyMileage = 40
        viewModel.maxWeeklyMileage = 55
        viewModel.longRunWeekday = 1
        viewModel.qualityWeekday = 3 // Too close; generator should safely move it.
        viewModel.includeWorkouts = true
        viewModel.generatePlan()

        let plan = try #require(viewModel.currentPlan)
        #expect(plan.weeks.count == 18)

        let raceWeek = try #require(plan.weeks.last)
        let race = try #require(raceWeek.workouts.first)
        #expect(race.type == .racePace)
        #expect(calendar.isDate(race.date, inSameDayAs: raceDate))

        for week in plan.weeks.dropLast() {
            #expect(week.workouts.count <= 2)

            let longRun = try #require(week.workouts.first { $0.type == .long })
            let longDistance = try #require(longRun.distanceInMiles)
            let isRaceSpecificLongRun = longRun.description.contains("M pace to HM pace") ||
                longRun.description.contains("2 × 5 miles @ M pace")
            if longDistance < 20 && !isRaceSpecificLongRun {
                #expect(longDistance <= week.recommendedMileage * 0.30 + 0.001)
                #expect(longDistance <= (150.0 * 60.0) / (8.0 * 60.0 * 1.30) + 0.001)
            }

            if week.isStepbackWeek {
                #expect(week.workouts.count == 1)
            }

            if week.workouts.count == 2 {
                let quality = try #require(week.workouts.first { $0.type != .long })
                let longDay = calendar.component(.weekday, from: longRun.date)
                let qualityDay = calendar.component(.weekday, from: quality.date)
                let directGap = abs(longDay - qualityDay)
                #expect(min(directGap, 7 - directGap) >= 3)
            }
        }

        let earlyTypes = Set(plan.weeks
            .filter { $0.phase == .earlyQuality }
            .flatMap(\.workouts)
            .map(\.type))
        #expect(earlyTypes.contains(.repetition))

        let transitionTypes = Set(plan.weeks
            .filter { $0.phase == .transitionQuality }
            .flatMap(\.workouts)
            .map(\.type))
        #expect(transitionTypes.contains(.interval))

        let finalWeeks = plan.weeks.filter { $0.phase == .finalQuality }.dropLast()
        #expect(finalWeeks.flatMap(\.workouts).contains { $0.type == .marathon })
        #expect(finalWeeks.flatMap(\.workouts).contains { $0.type == .threshold })
        #expect(finalWeeks.flatMap(\.workouts).contains {
            $0.type == .long && $0.description.contains("@ M pace")
        })

        let twentyMilers = plan.weeks
            .flatMap(\.workouts)
            .filter { $0.type == .long && $0.distanceInMiles == 20 }
        #expect(twentyMilers.count == 3)
        #expect(twentyMilers.contains { $0.description.contains("conversational") })
        #expect(twentyMilers.contains { $0.description.contains("steady") })
        #expect(twentyMilers.contains { $0.description.contains("@ M pace") })

        let longRuns = plan.weeks.flatMap(\.workouts).filter { $0.type == .long }
        #expect(longRuns.contains {
            $0.distanceInMiles == 16 && $0.description.contains("M pace to HM pace")
        })
        #expect(longRuns.contains {
            $0.distanceInMiles == 18 && $0.description.contains("2 × 5 miles @ M pace")
        })
        #expect(plan.weeks.flatMap(\.workouts).contains {
            $0.type == .threshold && $0.description.contains("× 1 mile @ T pace")
        })
    }

    @Test func recoveryGuidanceTargetsTheExactScheduledWorkout() throws {
        let workout = DailyWorkout(
            date: Date(),
            type: .interval,
            distanceInMiles: 8,
            description: "4 x 1000m @ I pace"
        )
        let week = WeeklyPlan(
            weekNumber: 7,
            phase: .transitionQuality,
            workouts: [workout],
            startDate: Date(),
            recommendedMileage: 40
        )

        let recommendation = TrainingAdjustmentEngine.analyzeRecoveryForAdjustments(
            recoveryScore: 62,
            currentWeek: week,
            historicalScores: [76, 74, 72, 68, 65, 62]
        )
        let adjustment = try #require(recommendation.suggestedWorkoutChanges.first)

        #expect(adjustment.workoutID == workout.id)
        #expect(adjustment.suggestedType == .threshold)
        #expect(adjustment.suggestedDistance(for: workout) == 6.4)
        #expect(adjustment.title == "Swap speed for threshold")

        let restRecommendation = TrainingAdjustmentEngine.analyzeRecoveryForAdjustments(
            recoveryScore: 32,
            currentWeek: week
        )
        #expect(restRecommendation.suggestedWorkoutChanges.first?.suggestedType == .rest)
    }

    @MainActor
    @Test func marathonLongRunSpineDoesNotDependOnMileageRange() throws {
        for key in planKeys { UserDefaults.standard.removeObject(forKey: key) }
        defer { for key in planKeys { UserDefaults.standard.removeObject(forKey: key) } }

        let calendar = Calendar.current
        let currentWeekStart = try #require(calendar.dateInterval(of: .weekOfYear, for: Date())?.start)
        let viewModel = TrainingPlanViewModel()
        viewModel.selectedDistance = .marathon
        viewModel.selectedRaceDate = try #require(
            calendar.date(byAdding: .weekOfYear, value: 17, to: currentWeekStart)
        )
        viewModel.minWeeklyMileage = 30
        viewModel.maxWeeklyMileage = 40
        viewModel.generatePlan()

        let plan = try #require(viewModel.currentPlan)
        let longRuns = plan.weeks.flatMap(\.workouts).filter { $0.type == .long }
        #expect(longRuns.contains { $0.distanceInMiles == 16 })
        #expect(longRuns.contains { $0.distanceInMiles == 18 })
        #expect(longRuns.filter { $0.distanceInMiles == 20 }.count == 2)
        #expect(longRuns.contains { $0.description.contains("10 miles progressing from M pace to HM pace") })
        #expect(longRuns.contains { $0.description.contains("2 × 5 miles @ M pace") })
    }

    @Test func planStartingTodayIsTheCurrentPlan() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lateToday = try #require(calendar.date(byAdding: .hour, value: 23, to: today))
        let week = WeeklyPlan(
            weekNumber: 1,
            phase: .foundation,
            workouts: [],
            startDate: lateToday,
            recommendedMileage: 30
        )
        let plan = TrainingPlan(
            name: "Starts Today",
            raceDistance: .marathon,
            raceDate: try #require(calendar.date(byAdding: .month, value: 4, to: today)),
            goalTimeInSeconds: 14_400,
            minWeeklyMileage: 30,
            maxWeeklyMileage: 45,
            weeks: [week],
            vdot: 45
        )

        #expect(plan.currentWeek?.id == week.id)
    }
}
