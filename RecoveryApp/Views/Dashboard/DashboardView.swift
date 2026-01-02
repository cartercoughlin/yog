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
    @State private var showAlgorithmBreakdown = false
    @State private var showSettings = false

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
                            RecoveryScoreCard(recovery: recovery)
                                .environmentObject(themeManager)
                                .padding(.top, 20)
                                .onAppear {
                                    themeManager.updateTheme(score: recovery.overallScore)
                                }
                                .onChange(of: recovery.overallScore) { _, newScore in
                                    themeManager.updateTheme(score: newScore)
                                }

                            Button {
                                showAlgorithmBreakdown = true
                            } label: {
                                Label("How is this calculated?", systemImage: "info.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(themeManager.currentTheme.primaryTextColor)
                            }
                            .padding(.horizontal)

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

                            if let trend = viewModel.weeklyTrend {
                                WeeklyTrendCard(
                                    average: trend.average,
                                    trend: trend.trend
                                )
                                .environmentObject(themeManager)
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
            .navigationTitle("Recovery")
            .toolbar {
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
