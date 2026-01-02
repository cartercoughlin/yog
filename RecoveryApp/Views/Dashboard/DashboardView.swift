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
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var trainingPlanViewModel = TrainingPlanViewModel()
    @State private var showAlgorithmBreakdown = false
    @State private var showSettings = false

    private var todaysWorkout: DailyWorkout? {
        guard let currentPlan = trainingPlanViewModel.currentPlan else { return nil }
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
        guard let currentPlan = trainingPlanViewModel.currentPlan else { return nil }
        let today = Date()

        return currentPlan.weeks.first { week in
            today >= week.startDate && today <= week.endDate
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background color
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            ProgressView("Loading your recovery data...")
                                .foregroundStyle(.white)
                                .padding(.top, 100)
                        } else if let error = viewModel.error {
                            HealthDataErrorView(message: error) {
                                Task {
                                    await viewModel.refreshData(injuryViewModel: injuryViewModel)
                                }
                            }
                        } else if let recovery = viewModel.todayRecovery {
                            NavigationLink(destination: HistoryView().environmentObject(themeManager)) {
                                RecoveryScoreCard(recovery: recovery)
                                    .environmentObject(themeManager)
                                    .onAppear {
                                        themeManager.updateTheme(score: recovery.overallScore)
                                    }
                                    .onChange(of: recovery.overallScore) { _, newScore in
                                        themeManager.updateTheme(score: newScore)
                                    }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 20)

                            // 7-day average - moved closer to score
                            if let trend = viewModel.weeklyTrend {
                                HStack {
                                    Spacer()
                                    WeeklyTrendCard(
                                        average: trend.average,
                                        trend: trend.trend
                                    )
                                    .environmentObject(themeManager)
                                    .frame(maxWidth: 280)
                                    Spacer()
                                }
                                .padding(.top, -8)
                            }

                            Button {
                                showAlgorithmBreakdown = true
                            } label: {
                                Label("How is this calculated?", systemImage: "info.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)

                            // Today's Workout Card (if there's a training plan)
                            if let workout = todaysWorkout,
                               let week = currentWeek,
                               let plan = trainingPlanViewModel.currentPlan {
                                NavigationLink(destination:
                                    WeekDetailView(
                                        week: week,
                                        plan: plan,
                                        viewModel: trainingPlanViewModel
                                    )
                                    .environmentObject(themeManager)
                                ) {
                                    TodaysWorkoutCard(
                                        workout: workout,
                                        currentWeek: week,
                                        recoveryScore: Double(recovery.overallScore),
                                        allowAdjustments: plan.allowRecoveryAdjustments
                                    )
                                    .environmentObject(themeManager)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.top, -8)
                            }

                            // Most Recent Workout Card
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

                        MetricsDetailCard(
                            metrics: recovery.metrics,
                            historicalMetrics: viewModel.historicalMetrics
                        )
                        } else {
                            HealthDataEmptyStateView()
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
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

struct MetricsDetailCard: View {
    let metrics: HealthMetrics
    let historicalMetrics: [HealthMetrics]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Metrics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let hrv = metrics.hrv {
                    NavigationLink {
                        MetricDetailView(
                            metricType: .hrv,
                            historicalMetrics: historicalMetrics
                        )
                    } label: {
                        MetricItem(
                            icon: "waveform.path.ecg",
                            label: "HRV",
                            value: String(format: "%.0f ms", hrv),
                            color: .purple
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if let rhr = metrics.restingHeartRate {
                    NavigationLink {
                        MetricDetailView(
                            metricType: .restingHeartRate,
                            historicalMetrics: historicalMetrics
                        )
                    } label: {
                        MetricItem(
                            icon: "heart.fill",
                            label: "Resting HR",
                            value: "\(rhr) bpm",
                            color: .red
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if let sleepHours = metrics.totalSleepHours {
                    NavigationLink {
                        MetricDetailView(
                            metricType: .sleep,
                            historicalMetrics: historicalMetrics
                        )
                    } label: {
                        MetricItem(
                            icon: "bed.double.fill",
                            label: "Sleep",
                            value: String(format: "%.1f hrs", sleepHours),
                            color: .blue
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if let steps = metrics.steps {
                    NavigationLink {
                        MetricDetailView(
                            metricType: .steps,
                            historicalMetrics: historicalMetrics
                        )
                    } label: {
                        MetricItem(
                            icon: "figure.walk",
                            label: "Steps",
                            value: "\(steps)",
                            color: .green
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
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

struct MetricItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(height: 24)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(8)
        }
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
    let recoveryScore: Double
    let allowAdjustments: Bool
    @EnvironmentObject var themeManager: ThemeManager

    private var adjustmentRecommendation: TrainingAdjustmentEngine.AdjustmentRecommendation? {
        guard allowAdjustments else { return nil }
        return TrainingAdjustmentEngine.analyzeRecoveryForAdjustments(
            recoveryScore: recoveryScore,
            currentWeek: currentWeek,
            historicalScores: []
        )
    }

    private var recoveryBlurb: String? {
        // If we have adjustment recommendations, use those
        if let recommendation = adjustmentRecommendation, recommendation.shouldAdjust {
            return recommendation.message
        }

        // Otherwise, use simple recovery-based guidance
        if recoveryScore < 50 {
            return "⚠️ Your recovery is low. Remember, all runs are effort-based - listen to your body and scale back intensity if needed."
        } else if recoveryScore < 65 {
            return "💛 Your recovery is moderate. Focus on perceived effort rather than pace today."
        } else if recoveryScore >= 80 {
            return "💚 Your recovery is excellent! You're ready for today's workout."
        }
        return nil
    }

    private var workoutAdjustmentForToday: TrainingAdjustmentEngine.WorkoutAdjustment? {
        guard let recommendation = adjustmentRecommendation else { return nil }
        return recommendation.suggestedWorkoutChanges.first { adjustment in
            adjustment.originalType == workout.type
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundStyle(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Today's Workout")
                            .font(.headline)

                        if workout.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        }
                    }
                    Text(workout.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            Divider()

            Text(workout.description)
                .font(.subheadline)
                .foregroundStyle(.primary)

            // Show specific workout adjustment if available
            if let adjustment = workoutAdjustmentForToday {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Suggested Adjustment")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }

                    Text("Consider: \(adjustment.suggestedType.rawValue) instead")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(adjustment.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            if let blurb = recoveryBlurb {
                Divider()

                Text(blurb)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
        .padding(.horizontal)
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
}
