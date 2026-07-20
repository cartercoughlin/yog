//
//  DashboardView.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var injuryViewModel: InjuryTrackerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingPlanViewModel: TrainingPlanViewModel
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showAlgorithmBreakdown = false
    @State private var showSettings = false
    let onCreatePlan: () -> Void

    init(onCreatePlan: @escaping () -> Void = {}) {
        self.onCreatePlan = onCreatePlan
    }

    private var activePlan: TrainingPlan? {
        if let currentPlan = trainingPlanViewModel.currentPlan,
           currentPlan.currentWeek != nil {
            return currentPlan
        }

        return trainingPlanViewModel.trainingPlans.first { $0.currentWeek != nil }
    }

    private var todaysWorkout: DailyWorkout? {
        guard let currentPlan = activePlan else { return nil }
        let today = Date()

        for week in currentPlan.weeks {
            for workout in week.workouts {
                if Calendar.current.isDate(workout.date, inSameDayAs: today) {
                    return workout
                }
            }
        }
        return nil
    }

    private var currentWeek: WeeklyPlan? {
        guard let currentPlan = activePlan else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return currentPlan.weeks.first { week in
            let weekStart = calendar.startOfDay(for: week.startDate)
            let dayAfterWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? week.endDate
            return today >= weekStart && today < dayAfterWeek
        }
    }

    private var nextWorkout: DailyWorkout? {
        activePlan?.weeks
            .flatMap(\.workouts)
            .filter { $0.date >= Calendar.current.startOfDay(for: Date()) && !$0.isCompleted }
            .sorted { $0.date < $1.date }
            .first
    }

    private var currentWeekActualMiles: Double {
        guard let week = currentWeek else { return 0 }
        let weekMetrics: [HealthMetrics] = viewModel.historicalMetrics.filter {
            $0.date >= week.startDate && $0.date <= week.endDate
        }
        let workouts: [WorkoutData] = weekMetrics.flatMap { $0.workouts }
        let distances: [Double] = workouts
            .filter { $0.type == .running }
            .compactMap { $0.distance }
        return distances.reduce(0, +) / 1609.34
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background color
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        VStack(spacing: 12) {
                            trainingSection(recovery: viewModel.todayRecovery)
                        }
                        .padding(.top, 16)

                        if let recentWorkout = viewModel.mostRecentWorkout {
                            RecentWorkoutCard(workout: recentWorkout)
                        }

                        if !injuryViewModel.activeInjuries.isEmpty {
                            NavigationLink {
                                InjuryTrackerView()
                                    .environmentObject(injuryViewModel)
                            } label: {
                                InjuryWarningCard(injuryViewModel: injuryViewModel)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if viewModel.isLoading {
                            ProgressView("Updating health guidance...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if let error = viewModel.error {
                            HealthDataErrorView(message: error) {
                                Task {
                                    await viewModel.refreshData(injuryViewModel: injuryViewModel)
                                }
                            }
                        } else if let recovery = viewModel.todayRecovery {
                            if activePlan == nil {
                                ReadinessSummaryCard(
                                    recovery: recovery,
                                    weeklyAverage: viewModel.weeklyTrend?.average,
                                    historicalMetrics: viewModel.historicalMetrics,
                                    showDetails: { showAlgorithmBreakdown = true }
                                )
                                .onAppear {
                                    themeManager.updateTheme(score: recovery.overallScore)
                                }
                            }
                        } else {
                            HealthDataEmptyStateView()
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 32)

                        Text("jog with a why")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        WeatherWidget()

                        Button {
                            Task {
                                await viewModel.refreshData(injuryViewModel: injuryViewModel)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            .task {
                await viewModel.loadData(injuryViewModel: injuryViewModel)
            }
            .sheet(isPresented: $showAlgorithmBreakdown) {
                if let recovery = viewModel.todayRecovery {
                    AlgorithmBreakdownView(
                        recovery: recovery,
                        historicalMetrics: viewModel.historicalMetrics
                    )
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    @ViewBuilder
    private func trainingSection(recovery: RecoveryData?) -> some View {
        if let plan = activePlan, let week = currentWeek {
            NavigationLink {
                WeekDetailView(week: week, plan: plan, viewModel: trainingPlanViewModel)
                    .environmentObject(themeManager)
            } label: {
                TrainingWeekSummaryCard(
                    plan: plan,
                    week: week,
                    actualMiles: currentWeekActualMiles,
                    nextWorkout: nextWorkout
                )
            }
            .buttonStyle(.plain)

            if let recovery {
                ReadinessSummaryCard(
                    recovery: recovery,
                    weeklyAverage: viewModel.weeklyTrend?.average,
                    historicalMetrics: viewModel.historicalMetrics,
                    showDetails: { showAlgorithmBreakdown = true }
                )
                .onAppear {
                    themeManager.updateTheme(score: recovery.overallScore)
                }
            }

            if let workout = todaysWorkout {
                NavigationLink {
                    WeekDetailView(week: week, plan: plan, viewModel: trainingPlanViewModel)
                        .environmentObject(themeManager)
                } label: {
                    TodaysWorkoutCard(
                        workout: workout,
                        currentWeek: week,
                        recoveryScore: recovery.map { Double($0.overallScore) },
                        historicalScores: viewModel.recentRecoveryScores,
                        allowAdjustments: plan.allowRecoveryAdjustments
                    )
                    .environmentObject(themeManager)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button(action: onCreatePlan) {
                NoActivePlanCard()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the training plan builder")
        }
    }
}

struct TrainingWeekSummaryCard: View {
    let plan: TrainingPlan
    let week: WeeklyPlan
    let actualMiles: Double
    let nextWorkout: DailyWorkout?

    private var progress: Double {
        guard week.recommendedMileage > 0 else { return 0 }
        return min(1, actualMiles / week.recommendedMileage)
    }

    private var daysToRace: Int {
        max(0, Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: plan.raceDate)
        ).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Week \(week.weekNumber) · \(week.phase.rawValue)")
                        .font(.headline)
                    Text("\(daysToRace) days to \(plan.raceDistance.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(String(format: "%.1f / %.0f mi", actualMiles, week.recommendedMileage))
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.semibold)
            }

            ProgressView(value: progress)
                .tint(.primary)

            if let nextWorkout {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Next: \(nextWorkout.type.rawValue)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(nextWorkout.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let distance = nextWorkout.distanceInMiles {
                        Text(String(format: "%.0f mi", distance))
                            .font(.subheadline.monospacedDigit())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
}

struct ReadinessSummaryCard: View {
    let recovery: RecoveryData
    let weeklyAverage: Double?
    let historicalMetrics: [HealthMetrics]
    let showDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Training readiness")
                    .font(.headline)
                Spacer()
                Text("\(recovery.overallScore)")
                    .font(.title2.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(recovery.category.color)
                if let weeklyAverage {
                    Text("7d \(Int(weeklyAverage))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Button(action: showDetails) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("View readiness details")
            }

            Text(recovery.category.trainingGuidance)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 0) {
                metricLink(
                    type: .hrv,
                    label: "HRV",
                    value: recovery.metrics.hrv.map { "\(Int($0)) ms" } ?? "—"
                )
                metricLink(
                    type: .restingHeartRate,
                    label: "Rest HR",
                    value: recovery.metrics.restingHeartRate.map { "\($0) bpm" } ?? "—"
                )
                metricLink(
                    type: .sleep,
                    label: "Sleep",
                    value: recovery.metrics.totalSleepHours.map { String(format: "%.1f hr", $0) } ?? "—"
                )
            }

        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }

    private func metricLink(type: MetricType, label: String, value: String) -> some View {
        NavigationLink {
            MetricDetailView(
                metricType: type,
                historicalMetrics: historicalMetrics
            )
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 3) {
                    Text(label)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct NoActivePlanCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("No active training plan")
                    .font(.headline)
                Text("Create or select a plan in the Training tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
}

struct WeeklyTrendCard: View {
    let average: Double
    let trend: Trend
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("7-Day Average")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(average))")
                        .font(.title)
                        .fontWeight(.bold)

                    HStack(spacing: 4) {
                        Image(systemName: trend.icon)
                            .font(.caption)
                        Text(trend.description)
                            .font(.caption)
                    }
                    .foregroundStyle(trend == .improving ? .green : trend == .declining ? .red : .secondary)
                }
            }

            Spacer()
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
}

struct RecommendationPreviewCard: View {
    let recommendation: WorkoutRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Recommendation")
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(recommendation.type.emoji)
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(recommendation.durationInMinutes) min · \(recommendation.intensity.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(recommendation.reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Error Loading Data")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(.top, 100)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No Data Available")
                .font(.headline)

            Text("Grant HealthKit permissions to see your recovery score")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 100)
    }
}

struct TodaysWorkoutCard: View {
    let workout: DailyWorkout
    let currentWeek: WeeklyPlan
    let recoveryScore: Double?
    let historicalScores: [Double]
    let allowAdjustments: Bool
    @EnvironmentObject var themeManager: ThemeManager

    private var adjustmentRecommendation: TrainingAdjustmentEngine.AdjustmentRecommendation? {
        guard allowAdjustments, let recoveryScore else { return nil }
        return TrainingAdjustmentEngine.analyzeRecoveryForAdjustments(
            recoveryScore: recoveryScore,
            currentWeek: currentWeek,
            historicalScores: historicalScores
        )
    }

    private var workoutAdjustmentForToday: TrainingAdjustmentEngine.WorkoutAdjustment? {
        guard let recommendation = adjustmentRecommendation else { return nil }
        return recommendation.suggestedWorkoutChanges.first { adjustment in
            adjustment.workoutID == workout.id
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Text("Today · \(workout.type.rawValue)")
                        .font(.headline)

                    if workout.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }

                Spacer()

                if let distance = workout.distanceInMiles {
                    VStack(alignment: .trailing) {
                        Text(String(format: "%.0f mi", distance))
                            .font(.title3)
                            .fontWeight(.bold)
                        if let pace = workout.paceMinPerMile {
                            Text("\(pace)/mi")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if workout.type == .rest {
                    Text("Rest")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
            }

            Text(workout.description)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Show specific workout adjustment if available
            if let adjustment = workoutAdjustmentForToday {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(adjustment.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)

                    Text(adjustedPrescription(adjustment))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(adjustment.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }

    private func adjustedPrescription(_ adjustment: TrainingAdjustmentEngine.WorkoutAdjustment) -> String {
        if adjustment.suggestedType == .rest {
            return "Rest instead of \(workout.type.rawValue.lowercased())"
        }
        if let distance = adjustment.suggestedDistance(for: workout) {
            return "\(adjustment.suggestedType.rawValue) · \(Int(distance.rounded())) mi"
        }
        return adjustment.suggestedType.rawValue
    }
}

struct InjuryWarningCard: View {
    @ObservedObject var injuryViewModel: InjuryTrackerViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bandage.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Injuries")
                        .font(.headline)
                    Text("\(injuryViewModel.injuryCount) active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if injuryViewModel.totalRecoveryImpact > 0 {
                    VStack(alignment: .trailing) {
                        Text("-\(Int(injuryViewModel.totalRecoveryImpact))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                        Text("score impact")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(injuryViewModel.activeInjuries.prefix(3))) { injury in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(injury.severity.color)
                            .frame(width: 8, height: 8)

                        Text(injury.region.rawValue)
                            .font(.subheadline)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(injury.severity.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(injury.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }

                if injuryViewModel.activeInjuries.count > 3 {
                    Text("+\(injuryViewModel.activeInjuries.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                }
            }
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }
}

#Preview {
    DashboardView()
        .environmentObject(InjuryTrackerViewModel())
        .environmentObject(ThemeManager())
        .environmentObject(TrainingPlanViewModel())
}
