import SwiftUI
import Charts

struct TrainingPlanView: View {
    @EnvironmentObject var viewModel: TrainingPlanViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var showSetup: Bool
    @State private var selectedWeekNumber: String?
    @State private var isRefreshing = false
    @State private var showSyncBanner = true

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.trainingPlans.isEmpty {
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                        emptyState
                    }
                    .transition(.opacity)
                } else {
                    planListView
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.trainingPlans.isEmpty)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.currentPlan = nil
                        showSetup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSetup) {
                TrainingPlanSetupView(viewModel: viewModel)
            }
            .onDisappear {
                if viewModel.currentPlan == nil && !viewModel.trainingPlans.isEmpty {
                    viewModel.currentPlan = viewModel.trainingPlans.first
                }
            }
        }
    }

    private var planListView: some View {
        List {
            ForEach(viewModel.trainingPlans) { plan in
                NavigationLink {
                    SinglePlanView(plan: plan, viewModel: viewModel)
                } label: {
                    PlanListRowCard(plan: plan)
                }
            }
            .onDelete { indexSet in
                withAnimation {
                    viewModel.deletePlans(at: indexSet)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: viewModel.trainingPlans.map(\.id))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No Training Plans")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create a customized training plan with VDOT-based pacing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showSetup = true
            } label: {
                Label("Create Plan", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }

    private func colorForPhase(_ phase: TrainingPhase) -> Color {
        switch phase {
        case .foundation: return .blue
        case .earlyQuality: return .green
        case .transitionQuality: return .orange
        case .finalQuality: return .red
        }
    }
}

struct PlanListRowCard: View {
    let plan: TrainingPlan
    
    private var raceColor: Color {
        switch plan.raceDistance {
        case .fiveK: return .green
        case .tenK: return .blue
        case .halfMarathon: return .orange
        case .marathon: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(raceColor)
                        .frame(width: 8, height: 8)

                    Text(plan.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.caption2)
                    .foregroundStyle(raceColor)
                Text(plan.raceDistance.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(raceColor)

                Spacer()

                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(plan.raceDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.caption2)
                    .foregroundStyle(.purple)
                Text("Goal: \(VDOTCalculator.formatTime(seconds: plan.goalTimeInSeconds))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)

                Spacer()

                Image(systemName: "figure.run")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("\(plan.weeksUntilRace) weeks to go")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
    }
}

struct SinglePlanView: View {
    let plan: TrainingPlan
    @ObservedObject var viewModel: TrainingPlanViewModel
    @State private var showSetup = false
    @State private var selectedWeekNumber: String?
    @State private var showWeekDetail = false
    @State private var showSyncBanner = false
    @State private var exportedFile: ExportedFile?
    @State private var exportError: String?

    // HealthKit actual mileage per week
    @State private var weeklyActualMileage: [Int: Double] = [:]
    @State private var isLoadingMileage = false
    private let healthKitManager = HealthKitManager()

    var body: some View {
        Group {
            if let currentPlan = viewModel.currentPlan, currentPlan.id == plan.id {
                planContentView(plan: currentPlan)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel.selectPlan(plan)
                    }
            }
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(plan.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(plan.raceDistance.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        exportPlan(as: .csv)
                    } label: {
                        Label("Export as CSV", systemImage: "tablecells")
                    }

                    Button {
                        exportPlan(as: .pdf)
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSetup = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showSetup) {
            TrainingPlanSetupView(viewModel: viewModel)
        }
        .sheet(item: $exportedFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError ?? "Something went wrong while preparing the export.")
        }
        .sheet(isPresented: $showWeekDetail) {
            if let weekNumberStr = selectedWeekNumber,
               let weekNumber = Int(weekNumberStr),
               let currentPlan = viewModel.currentPlan,
               let selectedWeek = currentPlan.weeks.first(where: { $0.weekNumber == weekNumber }) {
                NavigationStack {
                    WeekDetailView(week: selectedWeek, plan: currentPlan, viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showWeekDetail = false
                                    selectedWeekNumber = nil
                                }
                            }
                        }
                }
            }
        }
        .onChange(of: selectedWeekNumber) { oldValue, newValue in
            if newValue != nil {
                showWeekDetail = true
            }
        }
        .task {
            await loadWeeklyActualMileage()
        }
    }

    // MARK: - HealthKit Data Loading

    private func loadWeeklyActualMileage() async {
        guard let currentPlan = viewModel.currentPlan else { return }
        isLoadingMileage = true

        var mileageByWeek: [Int: Double] = [:]

        for week in currentPlan.weeks {
            do {
                let metrics = try await healthKitManager.fetchMetricsForDateRange(
                    startDate: week.startDate,
                    endDate: week.endDate
                )

                // Extract all running workouts and sum their distance
                let allWorkouts = metrics.flatMap { $0.workouts }
                let runningWorkouts = allWorkouts.filter { $0.type == .running }
                let distances: [Double] = runningWorkouts.compactMap { $0.distance }
                let totalMeters = distances.reduce(0, +)
                let runningMiles = totalMeters / 1609.34  // Convert to miles

                if runningMiles > 0 {
                    mileageByWeek[week.weekNumber] = runningMiles
                }
            } catch {
                print("Error loading week \(week.weekNumber) mileage: \(error)")
            }
        }

        weeklyActualMileage = mileageByWeek
        isLoadingMileage = false
    }

    private func planContentView(plan: TrainingPlan) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if showSyncBanner {
                    syncReminderBanner()
                }

                planHeader(plan: plan)

                // Current week with next workout - tappable
                if let currentWeek = plan.currentWeek {
                    currentWeekCard(week: currentWeek, plan: plan)
                }

                if let suggestion = viewModel.adjustmentSuggestion {
                    recoveryAlert(message: suggestion)
                }

                weeklyMileageChart(plan: plan)

                weekList(plan: plan)
            }
            .padding(.horizontal)
        }
    }

    private func currentWeekCard(week: WeeklyPlan, plan: TrainingPlan) -> some View {
        Button {
            selectedWeekNumber = "\(week.weekNumber)"
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Week \(week.weekNumber) - \(week.phase.rawValue)")
                            .font(.headline)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Show next upcoming workout
                if let nextWorkout = nextUpcomingWorkout(in: week) {
                    Divider()

                    HStack(spacing: 12) {
                        Circle()
                            .fill(colorForWorkoutType(nextWorkout.type))
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next: \(nextWorkout.type.rawValue)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(nextWorkout.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let distance = nextWorkout.distanceInMiles {
                            Text(String(format: "%.0f mi", distance))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func nextUpcomingWorkout(in week: WeeklyPlan) -> DailyWorkout? {
        let today = Calendar.current.startOfDay(for: Date())
        // Find the next workout that hasn't been completed and is today or later
        return week.workouts
            .filter { !$0.isCompleted && Calendar.current.startOfDay(for: $0.date) >= today }
            .sorted { $0.date < $1.date }
            .first
    }

    private func colorForWorkoutType(_ type: TrainingWorkoutType) -> Color {
        switch type {
        case .easy, .long: return .green
        case .marathon, .racePace: return .blue
        case .threshold: return .orange
        case .interval: return .red
        case .repetition: return .purple
        case .hill: return .brown
        case .rest: return .gray
        }
    }

    private func planHeader(plan: TrainingPlan) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.raceDistance.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(plan.raceDate, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Text("Goal: \(VDOTCalculator.formatTime(seconds: plan.goalTimeInSeconds))")
                            .font(.caption)
                            .foregroundStyle(.blue)

                        Text(plan.goalPaceMinPerMile + " /mi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(plan.weeksUntilRace)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.blue)

                    Text("weeks left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
    }

    private func syncReminderBanner() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Track Your Workouts")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Tap any workout card to link HealthKit data or enter manual mileage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation {
                    showSyncBanner = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }

    private func recoveryAlert(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }

    private func weeklyMileageChart(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Mileage")
                        .font(.headline)
                    Text("Tap any bar to view week details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text("Recommended")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Actual")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if isLoadingMileage {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
            }

            // Precompute arrays to reduce type-checking complexity
            let weeks: [WeeklyPlan] = plan.weeks
            let weeksWithActuals: [WeeklyPlan] = weeks.filter { weeklyActualMileage[$0.weekNumber] != nil }

            Chart {
                // Recommended mileage bars
                ForEach(weeks) { week in
                    BarMark(
                        x: .value("Week", String(week.weekNumber)),
                        y: .value("Miles", week.totalMileage)
                    )
                    .foregroundStyle(colorForPhase(week.phase))
                    .opacity(selectedWeekNumber == String(week.weekNumber) ? 1.0 : 0.7)
                }

                // Actual mileage line + points (from HealthKit)
                ForEach(weeksWithActuals) { week in
                    if let actualMileage = weeklyActualMileage[week.weekNumber] {
                        LineMark(
                            x: .value("Week", String(week.weekNumber)),
                            y: .value("Actual Miles", actualMileage)
                        )
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        PointMark(
                            x: .value("Week", String(week.weekNumber)),
                            y: .value("Actual Miles", actualMileage)
                        )
                        .foregroundStyle(Color.green)
                        .symbol(.circle)
                        .symbolSize(80)
                    }
                }
            }
            .frame(height: 200)
            .chartXSelection(value: $selectedWeekNumber)
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
    }

    private func weekList(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Weeks")
                .font(.headline)

            ForEach(plan.weeks) { week in
                Button {
                    selectedWeekNumber = "\(week.weekNumber)"
                } label: {
                    WeekRow(week: week)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func colorForPhase(_ phase: TrainingPhase) -> Color {
        switch phase {
        case .foundation: return .blue
        case .earlyQuality: return .green
        case .transitionQuality: return .orange
        case .finalQuality: return .red
        }
    }

    // MARK: - Export

    private enum ExportFormat {
        case csv
        case pdf
    }

    private func exportPlan(as format: ExportFormat) {
        guard let currentPlan = viewModel.currentPlan, currentPlan.id == plan.id else { return }

        let data: Data
        let fileExtension: String
        switch format {
        case .csv:
            data = TrainingPlanExporter.csvData(for: currentPlan)
            fileExtension = "csv"
        case .pdf:
            data = TrainingPlanExporter.pdfData(for: currentPlan)
            fileExtension = "pdf"
        }

        guard let url = TrainingPlanExporter.writeToTemporaryFile(
            data: data,
            planName: currentPlan.name,
            fileExtension: fileExtension
        ) else {
            exportError = "Couldn't create the export file. Please try again."
            return
        }

        exportedFile = ExportedFile(url: url)
    }
}

struct WeekRow: View {
    let week: WeeklyPlan

    private var isCompleted: Bool {
        week.endDate < Date()
    }

    private var borderColor: Color {
        if isCompleted {
            return Color.green.opacity(0.4)
        } else if week.isStepbackWeek {
            return Color.cyan.opacity(0.3)
        } else {
            return Color.secondary.opacity(0.2)
        }
    }

    private var backgroundColor: Color {
        if isCompleted {
            return Color.green.opacity(0.05)
        } else {
            return Color.clear
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Completion indicator
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Week \(week.weekNumber)")
                        .font(.headline)

                    if week.isStepbackWeek {
                        Text("RECOVERY")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.cyan)
                            )
                    }
                }

                Text(week.phase.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f mi", week.totalMileage))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(week.qualityWorkouts.count) quality workout\(week.qualityWorkouts.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1.5)
        )
    }
}

#Preview {
    TrainingPlanView(showSetup: .constant(false))
        .environmentObject(ThemeManager())
        .environmentObject(TrainingPlanViewModel())
}
