import SwiftUI

struct WeekDetailView: View {
    let week: WeeklyPlan
    let plan: TrainingPlan

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Week Header
                weekHeader

                // Training Paces Reference
                trainingPacesCard

                // Daily Workouts
                dailyWorkoutsSection
            }
            .padding()
        }
        .navigationTitle("Week \(week.weekNumber)")
        .navigationBarTitleDisplayMode(.large)
    }

    private var weekHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(week.phase.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(phaseColor)

                    Text(week.phase.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(String(format: "%.1f", week.totalMileage))
                        .font(.system(size: 36, weight: .bold))

                    Text("total miles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                statBox(title: "Quality Days", value: "\(week.qualityWorkouts.count)")
                Divider().frame(height: 40)
                statBox(title: "Easy Days", value: "\(week.workouts.filter { $0.type == .easy }.count)")
                Divider().frame(height: 40)
                statBox(title: "Rest Days", value: "\(week.workouts.filter { $0.type == .rest }.count)")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }

    private var trainingPacesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Paces (VDOT \(String(format: "%.1f", plan.vdot)))")
                    .font(.headline)

                Spacer()

                Button {
                    // Future: Show pace calculator or info
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                }
            }

            let paces = VDOTCalculator.calculateTrainingPaces(vdot: plan.vdot)

            VStack(spacing: 8) {
                paceRow(type: "Easy (E)", pace: paces.easyMinPerMile, color: .green)
                paceRow(type: "Marathon (M)", pace: paces.marathonMinPerMile, color: .blue)
                paceRow(type: "Threshold (T)", pace: paces.thresholdMinPerMile, color: .orange)
                paceRow(type: "Interval (I)", pace: paces.intervalMinPerMile, color: .red)
                paceRow(type: "Repetition (R)", pace: paces.repetitionMinPerMile, color: .purple)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func paceRow(type: String, pace: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(type)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(pace)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Text("/ mile")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dailyWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Workouts")
                .font(.headline)

            ForEach(week.workouts) { workout in
                WorkoutCard(workout: workout)
            }
        }
    }

    private var phaseColor: Color {
        switch week.phase {
        case .foundation: return .blue
        case .earlyQuality: return .green
        case .transitionQuality: return .orange
        case .finalQuality: return .red
        }
    }
}

struct WorkoutCard: View {
    let workout: DailyWorkout

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }

    private var dayOfWeekFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Day indicator
            VStack(spacing: 4) {
                Text(dayOfWeekFormatter.string(from: workout.date))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(workout.type.isQuality ? .white : .secondary)

                Circle()
                    .fill(workoutColor)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(workout.type.isQuality ? workoutColor.opacity(0.2) : Color.clear)
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(workout.type.rawValue)
                        .font(.headline)

                    if workout.type.isQuality {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }

                    Spacer()

                    if let distance = workout.distanceInMiles {
                        Text(String(format: "%.1f mi", distance))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }

                Text(workout.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let pace = workout.paceMinPerMile {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption)
                        Text("\(pace) / mile")
                            .font(.caption)
                    }
                    .foregroundStyle(workoutColor)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(workout.type.isQuality ? workoutColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var workoutColor: Color {
        switch workout.type {
        case .easy, .long: return .green
        case .marathon: return .blue
        case .threshold: return .orange
        case .interval: return .red
        case .repetition: return .purple
        case .rest: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        WeekDetailView(
            week: WeeklyPlan(
                weekNumber: 1,
                phase: .foundation,
                workouts: [
                    DailyWorkout(
                        date: Date(),
                        type: .long,
                        distanceInMiles: 10,
                        paceMinPerMile: "9:00",
                        description: "Long run at easy pace"
                    ),
                    DailyWorkout(
                        date: Date().addingTimeInterval(86400),
                        type: .easy,
                        distanceInMiles: 5,
                        paceMinPerMile: "9:30",
                        description: "Easy recovery run"
                    ),
                ],
                startDate: Date()
            ),
            plan: TrainingPlan(
                raceDistance: .marathon,
                raceDate: Date().addingTimeInterval(86400 * 120),
                goalTimeInSeconds: 3 * 3600 + 30 * 60,
                minWeeklyMileage: 40,
                maxWeeklyMileage: 55,
                weeks: [],
                vdot: 50
            )
        )
    }
}
