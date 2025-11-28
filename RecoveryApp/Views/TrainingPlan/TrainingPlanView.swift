import SwiftUI
import Charts

struct TrainingPlanView: View {
    @StateObject private var viewModel = TrainingPlanViewModel()
    @State private var showSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if let plan = viewModel.currentPlan {
                    planContent(plan: plan)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Training Plan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if viewModel.currentPlan != nil {
                            viewModel.resetPlan()
                        }
                        showSetup = true
                    } label: {
                        Image(systemName: viewModel.currentPlan == nil ? "plus" : "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showSetup) {
                TrainingPlanSetupView(viewModel: viewModel)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No Training Plan")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create a customized training plan based on Jack Daniels' Running Formula")
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
                // Plan Header
                planHeader(plan: plan)

                // Recovery Adjustment Alert (if applicable)
                if let suggestion = viewModel.adjustmentSuggestion {
                    recoveryAlert(message: suggestion)
                }

                // Weekly Mileage Chart
                weeklyMileageChart(plan: plan)

                // Week List
                weekList(plan: plan)
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
                statItem(title: "VDOT", value: String(format: "%.1f", plan.vdot))
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
            Text("Weekly Mileage")
                .font(.headline)

            Chart {
                ForEach(plan.weeks) { week in
                    BarMark(
                        x: .value("Week", "W\(week.weekNumber)"),
                        y: .value("Miles", week.totalMileage)
                    )
                    .foregroundStyle(colorForPhase(week.phase).gradient)
                    .annotation(position: .top) {
                        if week.weekNumber % 2 == 1 || plan.weeks.count < 15 {
                            Text("\(Int(week.totalMileage))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 200)
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
                                .font(.caption2)
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

    private func weekList(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Weeks")
                .font(.headline)

            ForEach(plan.weeks) { week in
                NavigationLink {
                    WeekDetailView(week: week, plan: plan)
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
                Text("Week \(week.weekNumber)")
                    .font(.headline)

                Text(week.phase.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f mi", week.totalMileage))
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
                .fill(Color(.systemBackground))
        )
    }
}

#Preview {
    TrainingPlanView()
}
