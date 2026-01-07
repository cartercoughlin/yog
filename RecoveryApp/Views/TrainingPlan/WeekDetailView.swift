import SwiftUI

struct WeekDetailView: View {
    let week: WeeklyPlan
    let plan: TrainingPlan
    @ObservedObject var viewModel: TrainingPlanViewModel
    @State private var showAddWorkout = false

    // HealthKit workout state
    @State private var healthKitWorkouts: [WorkoutData] = []
    @State private var isLoadingWorkouts = false
    private let healthKitManager = HealthKitManager()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }

    private var dateRangeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Week Header
                weekHeader

                // Running Metrics Summary (from HealthKit)
                if !healthKitWorkouts.isEmpty || isLoadingWorkouts {
                    runningMetricsSummary
                }

                // Training Paces Reference
                trainingPacesCard

                // Planned Quality Workouts
                dailyWorkoutsSection

                // HealthKit Workouts Section
                healthKitWorkoutsSection
            }
            .padding()
        }
        .navigationTitle("Week \(week.weekNumber)")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadHealthKitWorkouts()
        }
    }

    // MARK: - HealthKit Data Loading

    private func loadHealthKitWorkouts() async {
        isLoadingWorkouts = true

        do {
            // Fetch workouts for the entire week's date range
            let metrics = try await healthKitManager.fetchMetricsForDateRange(
                startDate: week.startDate,
                endDate: week.endDate
            )

            // Extract all workouts from all days and flatten
            let allWorkouts = metrics.flatMap { $0.workouts }

            // Sort by date
            healthKitWorkouts = allWorkouts.sorted { $0.date < $1.date }
        } catch {
            print("Error loading HealthKit workouts: \(error)")
            healthKitWorkouts = []
        }

        isLoadingWorkouts = false
    }

    // MARK: - Running Metrics Computed Properties

    private var runningWorkouts: [WorkoutData] {
        healthKitWorkouts.filter { $0.type == .running }
    }

    private var totalRunningDistance: Double {
        runningWorkouts.compactMap { $0.distance }.reduce(0, +) / 1609.34 // Convert to miles
    }

    private var totalRunningDuration: TimeInterval {
        runningWorkouts.reduce(0) { $0 + $1.duration }
    }

    private var averageRunningPace: String {
        guard totalRunningDistance > 0 else { return "--:--" }
        let paceSecPerMile = totalRunningDuration / totalRunningDistance
        let paceMin = Int(paceSecPerMile / 60)
        let paceSec = Int(paceSecPerMile.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", paceMin, paceSec)
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

                    // Date range for the week
                    if let endDate = Calendar.current.date(byAdding: .day, value: 6, to: week.startDate) {
                        Text("\(week.startDate, formatter: dateRangeFormatter) - \(endDate, formatter: dateRangeFormatter)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(String(format: "%.0f", week.totalMileage))
                        .font(.system(size: 36, weight: .bold))

                    Text("recommended miles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                statBox(title: "Quality Days", value: "\(week.qualityWorkouts.count)")
                Divider().frame(height: 40)
                statBox(title: "Workouts", value: isLoadingWorkouts ? "..." : "\(healthKitWorkouts.count)")
                Divider().frame(height: 40)
                statBox(title: "Actual Miles", value: isLoadingWorkouts ? "..." : String(format: "%.1f", totalRunningDistance))
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Week \(week.weekNumber) Workouts")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(week.workouts) { workout in
                    WorkoutCard(workout: workout, plan: plan)
                        .environmentObject(viewModel)
                }
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

    // MARK: - Running Metrics Summary

    private var runningMetricsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Running Summary")
                    .font(.headline)

                Spacer()

                if isLoadingWorkouts {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if runningWorkouts.isEmpty && !isLoadingWorkouts {
                Text("No runs recorded this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !isLoadingWorkouts {
                HStack(spacing: 0) {
                    metricBox(
                        icon: "figure.run",
                        value: String(format: "%.1f", totalRunningDistance),
                        unit: "miles",
                        color: .blue
                    )

                    Divider().frame(height: 50)

                    metricBox(
                        icon: "clock",
                        value: formatDuration(totalRunningDuration),
                        unit: "time",
                        color: .green
                    )

                    Divider().frame(height: 50)

                    metricBox(
                        icon: "speedometer",
                        value: averageRunningPace,
                        unit: "/mile",
                        color: .orange
                    )

                    Divider().frame(height: 50)

                    metricBox(
                        icon: "number",
                        value: "\(runningWorkouts.count)",
                        unit: "runs",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
        )
    }

    private func metricBox(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    // MARK: - HealthKit Workouts Section

    private var workoutsByType: [(type: WorkoutType, workouts: [WorkoutData])] {
        let grouped = Dictionary(grouping: healthKitWorkouts) { $0.type }
        // Sort by workout type, with running first
        let typeOrder: [WorkoutType] = [.running, .cycling, .swimming, .strength, .yoga, .mobility, .walking, .other, .rest]
        return typeOrder.compactMap { type in
            if let workouts = grouped[type], !workouts.isEmpty {
                return (type: type, workouts: workouts.sorted { $0.date < $1.date })
            }
            return nil
        }
    }

    private var healthKitWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Activities")
                    .font(.headline)

                Spacer()

                if isLoadingWorkouts {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button {
                    showAddWorkout = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
            }

            if healthKitWorkouts.isEmpty && !isLoadingWorkouts {
                Text("No activities recorded this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(workoutsByType, id: \.type) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Type header
                        HStack(spacing: 8) {
                            Image(systemName: group.type.icon)
                                .font(.subheadline)
                                .foregroundStyle(colorForWorkoutType(group.type))

                            Text(group.type.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(colorForWorkoutType(group.type))

                            Text("(\(group.workouts.count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)

                        // Workouts for this type
                        ForEach(group.workouts) { workout in
                            HealthKitWorkoutCard(workout: workout)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddWorkout) {
            AddCustomWorkoutSheet(week: week, viewModel: viewModel)
        }
    }

    private func colorForWorkoutType(_ type: WorkoutType) -> Color {
        switch type {
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .strength: return .orange
        case .yoga: return .purple
        case .mobility: return .pink
        case .walking: return .mint
        case .rest: return .gray
        case .other: return .indigo
        }
    }
}

// MARK: - HealthKit Workout Card

struct HealthKitWorkoutCard: View {
    let workout: WorkoutData

    var body: some View {
        HStack(spacing: 12) {
            // Workout type icon
            Image(systemName: workout.type.icon)
                .font(.title2)
                .foregroundStyle(colorForWorkoutType(workout.type))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(colorForWorkoutType(workout.type).opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workout.type.rawValue)
                        .font(.headline)

                    Spacer()

                    Text(workout.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(formatDuration(workout.duration))
                            .font(.caption)
                    }

                    // Distance (if applicable)
                    if let distance = workout.distance, distance > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(String(format: "%.2f mi", distance / 1609.34))
                                .font(.caption)
                        }
                    }

                    // Calories (if applicable)
                    if let calories = workout.caloriesBurned, calories > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                            Text("\(Int(calories)) cal")
                                .font(.caption)
                        }
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(colorForWorkoutType(workout.type).opacity(0.3), lineWidth: 1)
        )
    }

    private func colorForWorkoutType(_ type: WorkoutType) -> Color {
        switch type {
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .strength: return .orange
        case .yoga: return .purple
        case .mobility: return .pink
        case .walking: return .mint
        case .rest: return .gray
        case .other: return .indigo
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct WorkoutCard: View {
    let workout: DailyWorkout
    let plan: TrainingPlan
    @State private var showLinkSheet = false
    @State private var showDatePicker = false
    @State private var showManualEntry = false
    @State private var showActionSheet = false
    @State private var showWorkoutDetail = false
    @State private var newDate: Date
    @EnvironmentObject private var viewModel: TrainingPlanViewModel

    init(workout: DailyWorkout, plan: TrainingPlan) {
        self.workout = workout
        self.plan = plan
        _newDate = State(initialValue: workout.date)
    }

    // Create WorkoutData from LinkedWorkout for detail view
    private var linkedWorkoutData: WorkoutData? {
        guard let linked = workout.linkedWorkout else { return nil }
        return WorkoutData(
            id: linked.id,
            date: linked.completedDate,
            type: .running,
            duration: linked.actualDuration,
            distance: linked.actualDistance * 1609.34, // Convert miles to meters
            trainingStress: 0
        )
    }

    private var isSkipped: Bool {
        workout.description.contains("(Skipped)")
    }

    private var isCustomWorkout: Bool {
        // Detect if this is a custom workout by checking the description
        let desc = workout.description.lowercased()
        return desc.contains("strength") || desc.contains("yoga") || desc.contains("mobility") ||
               desc.contains("cycling") || desc.contains("swimming") || desc.contains("walking")
    }

    private var displayTitle: String {
        // For custom workouts, extract the type from description
        if isCustomWorkout {
            // Remove " Workout" suffix and "(Skipped)" if present
            let cleanDesc = workout.description
                .replacingOccurrences(of: " Workout", with: "")
                .replacingOccurrences(of: " (Skipped)", with: "")
            return cleanDesc
        }
        return workout.type.rawValue
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

    private var dateNumberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    private var mainCardContent: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(isSkipped ? Color.gray : (workout.isCompleted ? Color.green : workoutColor))
                .frame(width: 10, height: 10)

            // Left side: workout info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayTitle)
                        .font(.headline)

                    if workout.isCompleted {
                        Image(systemName: isSkipped ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(isSkipped ? .gray : .green)
                    }
                }

                Text(workout.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Right side: distance, pace, and action
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    if let distance = workout.distanceInMiles {
                        Text(String(format: "%.0f mi", distance))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if let pace = calculatedPace {
                        Text("\(pace)/mi")
                            .font(.subheadline)
                            .foregroundStyle(workoutColor)
                    }
                }

                // Linked workout info or Log button
                if let linked = workout.linkedWorkout {
                    HStack(spacing: 8) {
                        if linked.actualDistance > 0 {
                            Text(linked.formattedDistance)
                            Text("\(linked.actualPace)/mi")
                        }
                        Text(linked.formattedDuration)
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                } else if workout.date <= Date() && !workout.isCompleted {
                    Button {
                        showActionSheet = true
                    } label: {
                        Text("Log")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSkipped ? Color.gray.opacity(0.05) : (workout.isCompleted ? Color.green.opacity(0.05) : Color(.systemBackground)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSkipped ? Color.gray.opacity(0.3) : (workout.isCompleted ? Color.green.opacity(0.3) :
                    (workout.type.isQuality ? workoutColor.opacity(0.3) : Color.clear)),
                    lineWidth: 1
                )
        )
    }

    var body: some View {
        mainCardContent
        .confirmationDialog("", isPresented: $showActionSheet) {
            Button("Link Workout") {
                showLinkSheet = true
            }
            Button("Enter Manually") {
                showManualEntry = true
            }
            Button("Skip Workout") {
                viewModel.skipWorkout(workoutId: workout.id)
            }
        } message: {
            Text("How would you like to log this workout?")
        }
        .sheet(isPresented: $showLinkSheet) {
            WorkoutLinkingSheet(workout: workout)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showManualEntry) {
            ManualMileageEntrySheet(workout: workout)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showWorkoutDetail) {
            if let workoutData = linkedWorkoutData {
                NavigationStack {
                    WorkoutDetailHistoryView(workout: workoutData)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showWorkoutDetail = false
                                }
                            }
                        }
                }
            }
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

            if isSkipped {
                Button {
                    viewModel.unskipWorkout(workoutId: workout.id)
                } label: {
                    Label("Unskip Workout", systemImage: "arrow.uturn.backward")
                }
            }

            if isCustomWorkout {
                Button(role: .destructive) {
                    viewModel.deleteWorkout(workoutId: workout.id)
                } label: {
                    Label("Delete Workout", systemImage: "trash")
                }
            }
        }
        .onTapGesture {
            // If there's a linked workout, show the detail view
            if workout.linkedWorkout != nil {
                showWorkoutDetail = true
            }
        }
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

struct ManualMileageEntrySheet: View {
    let workout: DailyWorkout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: TrainingPlanViewModel
    @State private var distance: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 30
    @State private var seconds: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    HStack {
                        Text("Distance (miles)")
                        Spacer()
                        TextField("0.0", text: $distance)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration")
                            .font(.subheadline)
                        HStack(spacing: 16) {
                            Picker("Hours", selection: $hours) {
                                ForEach(0..<10) { hour in
                                    Text("\(hour)h").tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)

                            Picker("Minutes", selection: $minutes) {
                                ForEach(0..<60) { minute in
                                    Text("\(minute)m").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)

                            Picker("Seconds", selection: $seconds) {
                                ForEach(0..<60) { second in
                                    Text("\(second)s").tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80)
                        }
                    }
                }

                Section {
                    if let dist = Double(distance), dist > 0, (hours > 0 || minutes > 0 || seconds > 0) {
                        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds)
                        let paceSecPerMile = totalSeconds / dist
                        let paceMin = Int(paceSecPerMile / 60)
                        let paceSec = Int(paceSecPerMile.truncatingRemainder(dividingBy: 60))

                        HStack {
                            Text("Pace")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%d:%02d /mi", paceMin, paceSec))
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveManualEntry()
                    }
                    .disabled(!isValidEntry)
                }
            }
        }
    }

    private var isValidEntry: Bool {
        guard let dist = Double(distance), dist > 0 else { return false }
        return hours > 0 || minutes > 0 || seconds > 0
    }

    private func saveManualEntry() {
        guard let dist = Double(distance) else { return }
        let totalSeconds = Double(hours * 3600 + minutes * 60 + seconds)

        viewModel.addManualWorkout(
            workoutId: workout.id,
            distance: dist,
            duration: totalSeconds,
            date: workout.date
        )

        dismiss()
    }
}

struct AddCustomWorkoutSheet: View {
    let week: WeeklyPlan
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: WorkoutType = .strength
    @State private var description: String = ""
    @State private var selectedDate: Date = Date()
    @State private var distance: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 45
    @State private var seconds: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach([WorkoutType.strength, .yoga, .mobility, .cycling, .swimming, .walking], id: \.self) { type in
                            Label {
                                Text(type.rawValue)
                            } icon: {
                                Image(systemName: type.icon)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Details") {
                    DatePicker("Date", selection: $selectedDate, in: week.startDate...week.endDate, displayedComponents: .date)

                    TextField("Description", text: $description)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Duration") {
                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            VStack {
                                Text("Hours")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("Hours", selection: $hours) {
                                    ForEach(0..<10) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                            }

                            VStack {
                                Text("Minutes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("Minutes", selection: $minutes) {
                                    ForEach(0..<60) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                            }

                            VStack {
                                Text("Seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("Seconds", selection: $seconds) {
                                    ForEach(0..<60) { second in
                                        Text("\(second)").tag(second)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80)
                            }
                        }
                    }
                }

                if selectedType == .running || selectedType == .cycling || selectedType == .walking {
                    Section("Distance (Optional)") {
                        HStack {
                            TextField("0.0", text: $distance)
                                .keyboardType(.decimalPad)
                            Text("miles")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addWorkout()
                    }
                    .disabled(!isValidEntry)
                }
            }
            .onAppear {
                // Set default date to first day of the week
                selectedDate = week.startDate
                // Set default description based on type
                updateDefaultDescription()
            }
            .onChange(of: selectedType) { _ in
                updateDefaultDescription()
            }
        }
    }

    private var isValidEntry: Bool {
        return hours > 0 || minutes > 0 || seconds > 0
    }

    private func updateDefaultDescription() {
        let typeText = selectedType.rawValue
        description = "\(typeText) Workout"
    }

    private func addWorkout() {
        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        let dist = Double(distance)

        viewModel.addCustomWorkout(
            toWeekNumber: week.weekNumber,
            workoutType: selectedType,
            description: description,
            date: selectedDate,
            distanceInMiles: dist,
            durationInMinutes: totalSeconds / 60
        )

        dismiss()
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
