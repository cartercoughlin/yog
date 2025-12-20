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
                    planListView
                }
            }
            .navigationTitle("Training Plans")
            .toolbar {
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
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.trainingPlans) { plan in
                    NavigationLink {
                        SinglePlanView(plan: plan, viewModel: viewModel)
                    } label: {
                        PlanListRowCard(plan: plan)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
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
                        .lineLimit(1)
                }

                Spacer()

                Text(plan.raceDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label {
                    Text(plan.raceDistance.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "flag.fill")
                        .font(.caption2)
                }
                .foregroundStyle(raceColor)

                Label {
                    Text("\(plan.weeksUntilRace) weeks")
                        .font(.caption)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption2)
                }
                .foregroundStyle(.blue)

                Label {
                    Text(VDOTCalculator.formatTime(seconds: plan.goalTimeInSeconds))
                        .font(.caption)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "timer")
                        .font(.caption2)
                }
                .foregroundStyle(.purple)
            }
            
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    }

    private func planContentView(plan: TrainingPlan) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if showSyncBanner {
                    syncReminderBanner()
                }

                planHeader(plan: plan)

                if let suggestion = viewModel.adjustmentSuggestion {
                    recoveryAlert(message: suggestion)
                }

                weeklyMileageChart(plan: plan)

                weekList(plan: plan)
            }
            .padding(.horizontal)
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
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
                    .foregroundStyle(colorForPhase(week.phase))
                    .opacity(selectedWeekNumber == "\(week.weekNumber)" ? 1.0 : 0.7)
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
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(week.isStepbackWeek ? Color.cyan.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
    }
}

#Preview {
    TrainingPlanView()
}