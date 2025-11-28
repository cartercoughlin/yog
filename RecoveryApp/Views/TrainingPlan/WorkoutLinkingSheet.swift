import SwiftUI

struct WorkoutLinkingSheet: View {
    let workout: DailyWorkout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: TrainingPlanViewModel
    @State private var availableWorkouts: [WorkoutData] = []
    @State private var isLoading = false
    @State private var isLinking = false
    @State private var linkingWorkoutId: UUID?

    private let healthKitManager = HealthKitManager()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading workouts...")
                } else if availableWorkouts.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .navigationTitle("Link Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadWorkouts()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: workout.date > Date() ? "calendar.badge.clock" : "figure.run")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text(workout.date > Date() ? "Future Workout" : "No Workouts Found")
                .font(.headline)

            if workout.date > Date() {
                Text("This workout is scheduled for \(workout.date.formatted(date: .abbreviated, time: .omitted)). Complete the run and sync your Garmin to link it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("No running workouts found around \(workout.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    Task {
                        await loadWorkouts()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
        }
        .padding()
    }

    private var workoutList: some View {
        List(availableWorkouts) { workoutData in
            Button {
                linkWorkout(workoutData)
            } label: {
                WorkoutLinkRow(
                    workout: workoutData,
                    isLinking: isLinking && linkingWorkoutId == workoutData.id
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLinking)
        }
        .overlay {
            if isLinking {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
            }
        }
    }

    private func loadWorkouts() async {
        isLoading = true

        do {
            // Don't fetch data for future dates
            let now = Date()
            if workout.date > now {
                print("⏭️ Workout date is in the future, no data to fetch yet")
                availableWorkouts = []
                isLoading = false
                return
            }

            // Fetch workouts from ±3 days around the scheduled date
            let calendar = Calendar.current
            var startDate = calendar.date(byAdding: .day, value: -3, to: workout.date) ?? workout.date
            let endDate = min(
                calendar.date(byAdding: .day, value: 3, to: workout.date) ?? workout.date,
                now  // Don't fetch future dates
            )

            // Ensure start date is not in the future
            if startDate > now {
                startDate = now
            }

            // Skip if the entire range is in the future
            if startDate > endDate {
                print("⏭️ Date range is in the future")
                availableWorkouts = []
                isLoading = false
                return
            }

            print("📅 Fetching workouts from \(startDate) to \(endDate)")

            // Fetch health metrics for this date range
            let metrics = try await healthKitManager.fetchMetricsForDateRange(startDate: startDate, endDate: endDate)

            // Extract running workouts only
            let runningWorkouts = metrics.flatMap { $0.workouts }
                .filter { $0.type == .running }
                .sorted { abs($0.date.timeIntervalSince(workout.date)) < abs($1.date.timeIntervalSince(workout.date)) }

            availableWorkouts = runningWorkouts
            print("✅ Found \(runningWorkouts.count) running workouts")
        } catch {
            print("❌ Error loading workouts: \(error)")
        }

        isLoading = false
    }

    private func linkWorkout(_ workoutData: WorkoutData) {
        isLinking = true
        linkingWorkoutId = workoutData.id

        // Add a small delay for visual feedback
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            viewModel.linkWorkoutToDay(workoutId: workout.id, healthKitWorkout: workoutData)

            // Small additional delay before dismissing
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            isLinking = false
            dismiss()
        }
    }
}

struct WorkoutLinkRow: View {
    let workout: WorkoutData
    let isLinking: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.caption)
                        Text(String(format: "%.2f mi", workout.distance! / 1609.34))
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formatDuration(workout.duration))
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                        Text(formatPace(distance: workout.distance!, duration: workout.duration))
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isLinking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .opacity(isLinking ? 0.6 : 1.0)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
        }
    }

    private func formatPace(distance: Double, duration: TimeInterval) -> String {
        let miles = distance / 1609.34
        let paceSecPerMile = duration / miles
        let paceMin = Int(paceSecPerMile / 60)
        let paceSec = Int(paceSecPerMile.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d /mi", paceMin, paceSec)
    }
}

#Preview {
    NavigationStack {
        WorkoutLinkingSheet(
            workout: DailyWorkout(
                date: Date(),
                type: .easy,
                distanceInMiles: 6,
                paceMinPerMile: "9:00",
                description: "Easy run"
            )
        )
        .environmentObject(TrainingPlanViewModel())
    }
}
