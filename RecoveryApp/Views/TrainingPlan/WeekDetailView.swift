import SwiftUI

struct WeekDetailView: View {
    let week: WeeklyPlan
    let plan: TrainingPlan
    @ObservedObject var viewModel: TrainingPlanViewModel

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
                    Text(String(format: "%.0f", week.totalMileage))
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
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
        let raceMiles = plan.raceDistance.meters / 1609.34
        let goalRacePaceSecPerMile = plan.goalTimeInSeconds / raceMiles
        let paces = VDOTCalculator.calculateTrainingPacesFromGoal(goalRacePaceSecPerMile: goalRacePaceSecPerMile, raceDistance: plan.raceDistance)
        let racePaceLabel = racePaceLabelFor(distance: plan.raceDistance)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Paces")
                    .font(.headline)

                Spacer()

                Button {
                    // Future: Show pace calculator or info
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                }
            }

            VStack(spacing: 8) {
                paceRow(type: "Easy (E)", pace: paces.easyMinPerMile, color: .green)
                paceRow(type: racePaceLabel, pace: paces.racePaceMinPerMile, color: .blue)
                paceRow(type: "Threshold (T)", pace: paces.thresholdMinPerMile, color: .orange)
                paceRow(type: "Interval (I)", pace: paces.intervalMinPerMile, color: .red)
                paceRow(type: "Repetition (R)", pace: paces.repetitionMinPerMile, color: .purple)
            }
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
    }

    private func racePaceLabelFor(distance: RaceDistance) -> String {
        switch distance {
        case .fiveK:
            return "5K Race Pace (RP)"
        case .tenK:
            return "10K Race Pace (RP)"
        case .halfMarathon:
            return "Half Marathon (HM)"
        case .marathon:
            return "Marathon (M)"
        }
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
                WorkoutCard(workout: workout, plan: plan)
                    .environmentObject(viewModel)
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
    let plan: TrainingPlan
    @State private var showLinkSheet = false
    @State private var showDatePicker = false
    @State private var newDate: Date
    @State private var isExpanded = false
    @EnvironmentObject private var viewModel: TrainingPlanViewModel

    init(workout: DailyWorkout, plan: TrainingPlan) {
        self.workout = workout
        self.plan = plan
        _newDate = State(initialValue: workout.date)
    }

    // Calculate pace dynamically based on current pace calculation logic
    private var calculatedPace: String? {
        guard workout.type != .rest else { return nil }

        let raceMiles = plan.raceDistance.meters / 1609.34
        let goalRacePaceSecPerMile = plan.goalTimeInSeconds / raceMiles
        return VDOTCalculator.paceForWorkoutType(workout.type, goalRacePaceSecPerMile: goalRacePaceSecPerMile, raceDistance: plan.raceDistance)
    }

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
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Day indicator
                    VStack(spacing: 4) {
                        Text(dayOfWeekFormatter.string(from: workout.date))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(workout.type.isQuality ? .white : .secondary)

                        Circle()
                            .fill(workout.isCompleted ? Color.green : workoutColor)
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
                                .foregroundColor(.primary)

                            if workout.type.isQuality {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }

                            if workout.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }

                            Spacer()

                            if let distance = workout.distanceInMiles {
                                Text(String(format: "%.0f mi", distance))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !isExpanded {
                            Text(workout.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.vertical, 8)

                    Text(workout.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let pace = calculatedPace {
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.caption)
                            Text("\(pace) / mile")
                                .font(.caption)
                        }
                        .foregroundStyle(workoutColor)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Linked workout display
            if let linked = workout.linkedWorkout {
                Divider()
                    .padding(.vertical, 8)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed Workout")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Distance")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(linked.formattedDistance)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            Divider().frame(height: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pace")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(linked.actualPace) / mi")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            Divider().frame(height: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Duration")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(linked.formattedDuration)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            } else if !workout.isCompleted {
                // Link workout button (only for past/present workouts)
                if workout.date <= Date() {
                    Button {
                        showLinkSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "link")
                                .font(.caption)
                            Text("Link Workout")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                        .padding(.vertical, 8)
                    }
                } else {
                    // Future workout indicator
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Scheduled for \(workout.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(workout.isCompleted ? Color.green.opacity(0.05) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    workout.isCompleted ? Color.green.opacity(0.3) :
                    (workout.type.isQuality ? workoutColor.opacity(0.3) : Color.clear),
                    lineWidth: 1
                )
        )
        .sheet(isPresented: $showLinkSheet) {
            WorkoutLinkingSheet(workout: workout)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Change Workout Day")
                        .font(.headline)
                        .padding(.top)

                    DatePicker(
                        "Select New Date",
                        selection: $newDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    HStack(spacing: 16) {
                        Button("Cancel") {
                            showDatePicker = false
                            newDate = workout.date
                        }
                        .buttonStyle(.bordered)

                        Button("Move Workout") {
                            viewModel.moveWorkout(from: workout.id, toDay: newDate)
                            showDatePicker = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                .presentationDetents([.medium])
            }
        }
        .onLongPressGesture {
            // Long press shows context menu options via sheet
        }
        .contextMenu {
            Button {
                showDatePicker = true
            } label: {
                Label("Change Day", systemImage: "calendar")
            }

            if workout.linkedWorkout != nil {
                Button(role: .destructive) {
                    viewModel.unlinkWorkoutFromDay(workoutId: workout.id)
                } label: {
                    Label("Unlink Workout", systemImage: "link.badge.minus")
                }
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }
        )
    }

    private var workoutColor: Color {
        switch workout.type {
        case .easy, .long: return .green
        case .marathon, .racePace: return .blue
        case .threshold: return .orange
        case .interval: return .red
        case .repetition: return .purple
        case .hill: return .brown
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
                name: "Sample Marathon Plan",
                raceDistance: .marathon,
                raceDate: Date().addingTimeInterval(86400 * 120),
                goalTimeInSeconds: 3 * 3600 + 30 * 60,
                minWeeklyMileage: 40,
                maxWeeklyMileage: 55,
                weeks: [],
                vdot: 50
            ),
            viewModel: TrainingPlanViewModel()
        )
    }
}
