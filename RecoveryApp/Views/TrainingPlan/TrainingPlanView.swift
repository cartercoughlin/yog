import SwiftUI
import Charts

struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showSetup = false
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
                } else {
                    // Always show list when there are plans
                    planListView
                }
            }
            .navigationTitle("Training Plans")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Clear currentPlan to ensure we're in "create new" mode
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
                // Restore currentPlan to first plan if it was cleared
                if viewModel.currentPlan == nil && !viewModel.trainingPlans.isEmpty {
                    viewModel.currentPlan = viewModel.trainingPlans.first
                }
            }
        }
    }

    private func refreshData() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
    }

    private var planListView: some View {
        List {
            ForEach(viewModel.trainingPlans) { plan in
                NavigationLink {
                    SinglePlanView(plan: plan, viewModel: viewModel)
                } label: {
                    PlanListRow(plan: plan)
                }
            }
            .onDelete { indexSet in
                viewModel.deletePlans(at: indexSet)
            }
        }
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

    private func planContent(plan: TrainingPlan) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sync reminder banner
                if showSyncBanner {
                    syncReminderBanner()
                        .onTapGesture {
                            selectedWeekNumber = nil
                        }
                }

                // Plan Header
                planHeader(plan: plan)
                    .onTapGesture {
                        selectedWeekNumber = nil
                    }

                // Recovery Adjustment Alert (if applicable)
                if let suggestion = viewModel.adjustmentSuggestion {
                    recoveryAlert(message: suggestion)
                        .onTapGesture {
                            selectedWeekNumber = nil
                        }
                }

                // Weekly Mileage Chart
                weeklyMileageChart(plan: plan)

                // Selected Week Detail (if a bar is tapped)
                if let weekNumberStr = selectedWeekNumber,
                   let weekNumber = Int(weekNumberStr),
                   let selectedWeek = plan.weeks.first(where: { $0.weekNumber == weekNumber }) {
                    selectedWeekDetail(week: selectedWeek, plan: plan)
                }

                // Week List
                weekList(plan: plan)
                    .onTapGesture {
                        selectedWeekNumber = nil
                    }
            }
            .padding()
        }
    }

    private func planHeader(plan: TrainingPlan) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.raceDistance.rawValue)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(plan.raceDate, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(plan.weeksUntilRace)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.blue)

                    Text("weeks to go")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                statItem(title: "Goal Time", value: VDOTCalculator.formatTime(seconds: plan.goalTimeInSeconds))
                Divider().frame(height: 40)
                statItem(title: "Goal Pace", value: plan.goalPaceMinPerMile + "/mi")
                Divider().frame(height: 40)
                statItem(title: "VDOT", value: String(format: "%.0f", plan.vdot))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }

    private func syncReminderBanner() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Link Your Workouts")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Open Garmin Connect to sync, then link completed runs to your plan")
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
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
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
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func weeklyMileageChart(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Mileage")
                    .font(.headline)

                Spacer()

                // Legend for planned vs actual
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text("Planned")
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
                }
            }

            Chart {
                // Planned mileage (bars)
                ForEach(plan.weeks) { week in
                    BarMark(
                        x: .value("Week", "\(week.weekNumber)"),
                        y: .value("Miles", week.totalMileage)
                    )
                    .foregroundStyle(
                        selectedWeekNumber == "\(week.weekNumber)"
                            ? colorForPhase(week.phase)
                            : colorForPhase(week.phase).opacity(0.6)
                    )
                    .annotation(position: .top) {
                        if week.weekNumber % 2 == 1 || plan.weeks.count < 15 {
                            Text("\(Int(week.totalMileage))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Actual mileage (line)
                ForEach(plan.weeks.filter { $0.actualMileage > 0 }) { week in
                    LineMark(
                        x: .value("Week", "\(week.weekNumber)"),
                        y: .value("Actual Miles", week.actualMileage)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Week", "\(week.weekNumber)"),
                        y: .value("Actual Miles", week.actualMileage)
                    )
                    .foregroundStyle(Color.green)
                    .symbol(.circle)
                    .symbolSize(80)
                }
            }
            .frame(height: 200)
            .chartXSelection(value: $selectedWeekNumber)
            .chartGesture { chartProxy in
                SpatialTapGesture()
                    .onEnded { value in
                        let plotFrame = chartProxy.plotFrame
                        if let weekStr: String = chartProxy.value(atX: value.location.x) {
                            if selectedWeekNumber == weekStr {
                                selectedWeekNumber = nil
                            } else {
                                selectedWeekNumber = weekStr
                            }
                        }
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let miles = value.as(Double.self) {
                            Text("\(Int(miles)) mi")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 9))
                        }
                    }
                }
            }

            // Phase Legend
            HStack(spacing: 16) {
                ForEach(TrainingPhase.allCases, id: \.self) { phase in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForPhase(phase))
                            .frame(width: 8, height: 8)
                        Text(phase.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func selectedWeekDetail(week: WeeklyPlan, plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Week \(week.weekNumber)")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(week.phase.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(colorForPhase(week.phase))
                }

                Spacer()

                NavigationLink {
                    WeekDetailView(week: week, plan: plan, viewModel: viewModel)
                } label: {
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }

            Divider()

            // Week Stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Mileage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f mi", week.totalMileage))
                        .font(.headline)
                }

                Divider().frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(week.qualityWorkouts.count)")
                        .font(.headline)
                }

                Divider().frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Run Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(week.runningWorkouts.count)")
                        .font(.headline)
                }
            }

            Divider()

            // Daily Workouts Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("This Week's Workouts")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(week.workouts) { workout in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(workout.type.isQuality ? colorForPhase(week.phase) : Color.gray)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.type.rawValue)
                                .font(.subheadline)
                                .fontWeight(workout.type.isQuality ? .semibold : .regular)

                            if let distance = workout.distanceInMiles {
                                Text("\(String(format: "%.0f", distance)) mi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if let pace = calculatePaceForWorkout(workout, plan: plan) {
                            Text(pace + "/mi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                selectedWeekNumber = nil
            } label: {
                HStack {
                    Spacer()
                    Text("Close")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForPhase(week.phase), lineWidth: 2)
        )
    }

    private func weekList(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Weeks")
                .font(.headline)

            ForEach(plan.weeks) { week in
                NavigationLink {
                    WeekDetailView(week: week, plan: plan, viewModel: viewModel)
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

    // Helper function to calculate pace dynamically based on current logic
    private func calculatePaceForWorkout(_ workout: DailyWorkout, plan: TrainingPlan) -> String? {
        guard workout.type != .rest else { return nil }

        let raceMiles = plan.raceDistance.meters / 1609.34
        let goalRacePaceSecPerMile = plan.goalTimeInSeconds / raceMiles
        return VDOTCalculator.paceForWorkoutType(workout.type, goalRacePaceSecPerMile: goalRacePaceSecPerMile, raceDistance: plan.raceDistance)
    }
}

struct WeekRow: View {
    let week: WeeklyPlan

    var body: some View {
        HStack(spacing: 12) {
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

                Text("\(week.qualityWorkouts.count) quality workouts")
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
                .fill(week.isStepbackWeek ? Color.cyan.opacity(0.1) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(week.isStepbackWeek ? Color.cyan.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct PlanListRow: View {
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Spacer()

                Text(plan.raceDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label {
                    Text(plan.raceDistance.rawValue)
                        .font(.caption)
                } icon: {
                    Image(systemName: "flag.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                Label {
                    Text("\(plan.weeksUntilRace) weeks")
                        .font(.caption)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                Label {
                    Text(VDOTCalculator.formatTime(seconds: plan.goalTimeInSeconds))
                        .font(.caption)
                } icon: {
                    Image(systemName: "timer")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// Wrapper view for displaying a single plan from the list
struct SinglePlanView: View {
    let plan: TrainingPlan
    @ObservedObject var viewModel: TrainingPlanViewModel
    @State private var showSetup = false
    @State private var selectedWeekNumber: String?
    @State private var isRefreshing = false
    @State private var showSyncBanner = true

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
    }

    private func planContentView(plan: TrainingPlan) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sync reminder banner
                if showSyncBanner {
                    syncReminderBanner()
                        .onTapGesture {
                            selectedWeekNumber = nil
                        }
                }

                // Plan Header
                planHeader(plan: plan)
                    .onTapGesture {
                        selectedWeekNumber = nil
                    }

                // Recovery Adjustment Alert (if applicable)
                if let suggestion = viewModel.adjustmentSuggestion {
                    recoveryAlert(message: suggestion)
                        .onTapGesture {
                            selectedWeekNumber = nil
                        }
                }

                // Weekly Mileage Chart
                weeklyMileageChart(plan: plan)

                // Selected Week Detail (if a bar is tapped)
                if let weekNumberStr = selectedWeekNumber,
                   let weekNumber = Int(weekNumberStr),
                   let selectedWeek = plan.weeks.first(where: { $0.weekNumber == weekNumber }) {
                    selectedWeekDetail(week: selectedWeek, plan: plan)
                }

                // Week List
                weekList(plan: plan)
                    .onTapGesture {
                        selectedWeekNumber = nil
                    }
            }
            .padding()
        }
        .refreshable {
            await refreshData()
        }
    }

    private func refreshData() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isRefreshing = false
    }

    private func planHeader(plan: TrainingPlan) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.raceDistance.rawValue)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(plan.raceDate, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(plan.weeksUntilRace)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.blue)

                    Text("weeks to go")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                statItem(title: "Goal Time", value: VDOTCalculator.formatTime(seconds: plan.goalTimeInSeconds))
                Divider().frame(height: 40)
                statItem(title: "Goal Pace", value: plan.goalPaceMinPerMile + "/mi")
                Divider().frame(height: 40)
                statItem(title: "VDOT", value: String(format: "%.0f", plan.vdot))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }

    private func syncReminderBanner() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Link Your Workouts")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Open Garmin Connect to sync, then link completed runs to your plan")
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
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
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
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func weeklyMileageChart(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Mileage")
                    .font(.headline)

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text("Planned")
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
                }
            }

            Chart {
                ForEach(plan.weeks) { week in
                    BarMark(
                        x: .value("Week", "\(week.weekNumber)"),
                        y: .value("Miles", week.totalMileage)
                    )
                    .foregroundStyle(
                        selectedWeekNumber == "\(week.weekNumber)"
                            ? colorForPhase(week.phase)
                            : colorForPhase(week.phase).opacity(0.6)
                    )
                    .annotation(position: .top) {
                        if week.weekNumber % 2 == 1 || plan.weeks.count < 15 {
                            Text("\(Int(week.totalMileage))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(plan.weeks.filter { $0.actualMileage > 0 }) { week in
                    LineMark(
                        x: .value("Week", "\(week.weekNumber)"),
                        y: .value("Actual Miles", week.actualMileage)
                    )
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Week", "\(week.weekNumber)"),
                        y: .value("Actual Miles", week.actualMileage)
                    )
                    .foregroundStyle(Color.green)
                    .symbol(.circle)
                    .symbolSize(80)
                }
            }
            .frame(height: 200)
            .chartXSelection(value: $selectedWeekNumber)
            .chartGesture { chartProxy in
                SpatialTapGesture()
                    .onEnded { value in
                        if let weekStr: String = chartProxy.value(atX: value.location.x) {
                            if selectedWeekNumber == weekStr {
                                selectedWeekNumber = nil
                            } else {
                                selectedWeekNumber = weekStr
                            }
                        }
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let miles = value.as(Double.self) {
                            Text("\(Int(miles)) mi")
                                .font(.caption)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 9))
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                ForEach(TrainingPhase.allCases, id: \.self) { phase in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForPhase(phase))
                            .frame(width: 8, height: 8)
                        Text(phase.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func selectedWeekDetail(week: WeeklyPlan, plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Week \(week.weekNumber)")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(week.phase.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(colorForPhase(week.phase))
                }

                Spacer()

                NavigationLink {
                    WeekDetailView(week: week, plan: plan, viewModel: viewModel)
                } label: {
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Mileage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f mi", week.totalMileage))
                        .font(.headline)
                }

                Divider().frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(week.qualityWorkouts.count)")
                        .font(.headline)
                }

                Divider().frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Run Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(week.runningWorkouts.count)")
                        .font(.headline)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("This Week's Workouts")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(week.workouts) { workout in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(workout.type.isQuality ? colorForPhase(week.phase) : Color.gray)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.type.rawValue)
                                .font(.subheadline)
                                .fontWeight(workout.type.isQuality ? .semibold : .regular)

                            if let distance = workout.distanceInMiles {
                                Text("\(String(format: "%.0f", distance)) mi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if let pace = calculatePaceForWorkout(workout, plan: plan) {
                            Text(pace + "/mi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                selectedWeekNumber = nil
            } label: {
                HStack {
                    Spacer()
                    Text("Close")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForPhase(week.phase), lineWidth: 2)
        )
    }

    private func weekList(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Weeks")
                .font(.headline)

            ForEach(plan.weeks) { week in
                NavigationLink {
                    WeekDetailView(week: week, plan: plan, viewModel: viewModel)
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

    // Helper function to calculate pace dynamically based on current logic
    private func calculatePaceForWorkout(_ workout: DailyWorkout, plan: TrainingPlan) -> String? {
        guard workout.type != .rest else { return nil }

        let raceMiles = plan.raceDistance.meters / 1609.34
        let goalRacePaceSecPerMile = plan.goalTimeInSeconds / raceMiles
        return VDOTCalculator.paceForWorkoutType(workout.type, goalRacePaceSecPerMile: goalRacePaceSecPerMile, raceDistance: plan.raceDistance)
    }
}

#Preview {
    TrainingPlanView()
}
