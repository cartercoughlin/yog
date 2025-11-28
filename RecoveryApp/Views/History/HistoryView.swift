//
//  HistoryView.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI
import Charts

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView("Loading history...")
                            .padding(.top, 100)
                    } else if viewModel.recoveryHistory.isEmpty {
                        EmptyHistoryView()
                    } else {
                        timeRangePicker

                        statisticsCards

                        recoveryScoreChart

                        workoutsList
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("History")
            .task {
                await viewModel.loadHistory()
            }
        }
    }

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedTimeRange) {
            ForEach(HistoryViewModel.TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: viewModel.selectedTimeRange) { _, _ in
            Task {
                await viewModel.loadHistory()
            }
        }
    }

    private var statisticsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Avg Score",
                value: String(format: "%.0f", viewModel.averageRecoveryScore),
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )

            StatCard(
                title: "Workouts",
                value: "\(viewModel.totalWorkouts)",
                icon: "figure.run",
                color: .orange
            )

            StatCard(
                title: "Distance",
                value: String(format: "%.1f mi", viewModel.totalDistance / 1.60934),
                icon: "location.fill",
                color: .green
            )

            StatCard(
                title: "Duration",
                value: formatDuration(viewModel.totalDuration),
                icon: "clock.fill",
                color: .purple
            )
        }
        .padding(.horizontal)
    }

    private var recoveryScoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Score Trend")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(viewModel.recoveryHistory) { recovery in
                    LineMark(
                        x: .value("Date", recovery.date),
                        y: .value("Score", recovery.overallScore)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", recovery.date),
                        y: .value("Score", recovery.overallScore)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("Target", 70))
                    .foregroundStyle(.green.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            }
            .frame(height: 200)
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
        }
    }

    private var workoutsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.workoutHistory.prefix(10)) { workout in
                WorkoutHistoryRow(workout: workout)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(height: 28)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct WorkoutHistoryRow: View {
    let workout: WorkoutData

    var body: some View {
        HStack(spacing: 12) {
            Text(workout.type.emoji)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let distance = workout.distanceInMiles {
                        Label(String(format: "%.1f mi", distance), systemImage: "location.fill")
                            .font(.caption)
                    }

                    Label(formatDuration(workout.duration), systemImage: "clock.fill")
                        .font(.caption)

                    if let avgHR = workout.averageHeartRate {
                        Label("\(avgHR) bpm", systemImage: "heart.fill")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatRelativeTime(workout.date))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let timeInterval = Date().timeIntervalSince(date)
        let hours = timeInterval / 3600

        if hours >= 24 {
            let days = Int(hours / 24)
            return "\(days)d ago"
        } else {
            return date.formatted(.relative(presentation: .named))
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No History Yet")
                .font(.headline)

            Text("Your activity history will appear here as you use the app")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 100)
    }
}

#Preview {
    HistoryView()
}
