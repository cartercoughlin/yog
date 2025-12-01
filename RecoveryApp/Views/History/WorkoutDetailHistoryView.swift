//
//  WorkoutDetailHistoryView.swift
//  RecoveryApp
//
//  Created on 2025-11-29
//

import SwiftUI
import HealthKit
import Combine

struct WorkoutDetailHistoryView: View {
    let workout: WorkoutData
    @StateObject private var viewModel: WorkoutDetailViewModel

    init(workout: WorkoutData) {
        self.workout = workout
        _viewModel = StateObject(wrappedValue: WorkoutDetailViewModel(workout: workout))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // External App Links
                externalLinksSection

                // Metrics Grid
                metricsSection

                // Additional Details
                detailsSection
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(workout.type.emoji)
                    .font(.system(size: 50))

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(workout.date.formatted(date: .long, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
        }
    }

    private var externalLinksSection: some View {
        VStack(spacing: 12) {
            // Garmin Connect button
            Button(action: {
                openGarminConnect()
            }) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("View Route & Details")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Open in Garmin Connect")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange)
                )
            }
            .padding(.horizontal)

            // Strava button
            Button(action: {
                openStrava()
            }) {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("View on Strava")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Open in Strava app")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.98, green: 0.29, blue: 0.16))
                )
            }
            .padding(.horizontal)
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metrics")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                if let distance = workout.distanceInMiles {
                    MetricCard(
                        title: "Distance",
                        value: String(format: "%.2f", distance),
                        unit: "mi",
                        icon: "location.fill",
                        color: .blue
                    )
                }

                MetricCard(
                    title: "Duration",
                    value: formatDuration(workout.duration),
                    unit: "",
                    icon: "clock.fill",
                    color: .orange
                )

                if let pace = workout.pacePerMile {
                    MetricCard(
                        title: "Avg Pace",
                        value: formatPace(pace),
                        unit: "/mi",
                        icon: "gauge.with.dots.needle.50percent",
                        color: .green
                    )
                }

                if let calories = workout.caloriesBurned {
                    MetricCard(
                        title: "Calories",
                        value: String(format: "%.0f", calories),
                        unit: "kcal",
                        icon: "flame.fill",
                        color: .red
                    )
                }

                if let avgHR = workout.averageHeartRate {
                    MetricCard(
                        title: "Avg HR",
                        value: "\(avgHR)",
                        unit: "bpm",
                        icon: "heart.fill",
                        color: .pink
                    )
                }

                if let maxHR = workout.maxHeartRate {
                    MetricCard(
                        title: "Max HR",
                        value: "\(maxHR)",
                        unit: "bpm",
                        icon: "waveform.path.ecg",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional Info")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                DetailRow(label: "Training Stress", value: String(format: "%.0f", workout.trainingStress))

                DetailRow(label: "Started", value: workout.date.formatted(date: .abbreviated, time: .shortened))

                if let endDate = viewModel.endDate {
                    DetailRow(label: "Ended", value: endDate.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatPace(_ pace: TimeInterval) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func openGarminConnect() {
        // Try to open Garmin Connect app first using the correct URL scheme
        if let url = URL(string: "com.garmin.connect.mobile://") {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    // If app not installed, open App Store
                    if let appStoreURL = URL(string: "https://apps.apple.com/us/app/garmin-connect/id583446403") {
                        UIApplication.shared.open(appStoreURL)
                    }
                }
            }
        }
    }

    private func openStrava() {
        // Try to open Strava app first
        if let url = URL(string: "strava://") {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    // If app not installed, open App Store
                    if let appStoreURL = URL(string: "https://apps.apple.com/us/app/strava/id426826309") {
                        UIApplication.shared.open(appStoreURL)
                    }
                }
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(height: 24)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

@MainActor
class WorkoutDetailViewModel: ObservableObject {
    @Published var endDate: Date?

    private let workout: WorkoutData

    init(workout: WorkoutData) {
        self.workout = workout
        // Set end date from workout if available
        if let hkWorkout = workout.workout {
            self.endDate = hkWorkout.endDate
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailHistoryView(workout: .sampleRunning)
    }
}

