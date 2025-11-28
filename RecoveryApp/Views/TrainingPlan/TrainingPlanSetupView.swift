import SwiftUI

struct TrainingPlanSetupView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Race Distance", selection: $viewModel.selectedDistance) {
                        ForEach(RaceDistance.allCases) { distance in
                            Text(distance.rawValue).tag(distance)
                        }
                    }

                    DatePicker(
                        "Race Date",
                        selection: $viewModel.selectedRaceDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                } header: {
                    Text("Race Details")
                } footer: {
                    Text("Select your target race distance and date")
                }

                Section {
                    HStack {
                        Text("Hours")
                        Spacer()
                        Picker("", selection: $viewModel.goalHours) {
                            ForEach(0..<10) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                    }

                    HStack {
                        Text("Minutes")
                        Spacer()
                        Picker("", selection: $viewModel.goalMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                    }

                    HStack {
                        Text("Seconds")
                        Spacer()
                        Picker("", selection: $viewModel.goalSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)
                    }
                } header: {
                    Text("Goal Time")
                } footer: {
                    estimatedPaceFooter
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Minimum: \(Int(viewModel.minWeeklyMileage)) miles/week")
                            .font(.subheadline)

                        Slider(
                            value: $viewModel.minWeeklyMileage,
                            in: 15...80,
                            step: 5
                        )

                        Text("Maximum: \(Int(viewModel.maxWeeklyMileage)) miles/week")
                            .font(.subheadline)

                        Slider(
                            value: $viewModel.maxWeeklyMileage,
                            in: 20...100,
                            step: 5
                        )
                    }
                } header: {
                    Text("Weekly Mileage Range")
                } footer: {
                    Text("Your plan will build from minimum to maximum mileage over the training period")
                }

                Section {
                    Toggle(
                        "Allow Recovery-Based Adjustments",
                        isOn: $viewModel.allowRecoveryAdjustments
                    )
                } header: {
                    Text("Adaptive Training")
                } footer: {
                    Text("When enabled, the app will suggest workout modifications based on your daily recovery score")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            title: "Training Duration",
                            value: "\(viewModel.selectedDistance.recommendedWeeks) weeks"
                        )

                        InfoRow(
                            title: "Philosophy",
                            value: "Jack Daniels' Running Formula"
                        )

                        InfoRow(
                            title: "Quality Days",
                            value: "3 per week"
                        )
                    }
                } header: {
                    Text("Plan Overview")
                }
            }
            .navigationTitle("Create Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        viewModel.generatePlan()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        viewModel.minWeeklyMileage < viewModel.maxWeeklyMileage
    }

    private var estimatedPaceFooter: some View {
        let totalSeconds = TimeInterval(
            viewModel.goalHours * 3600 +
            viewModel.goalMinutes * 60 +
            viewModel.goalSeconds
        )
        let miles = viewModel.selectedDistance.meters / 1609.34
        let paceMinPerMile = (totalSeconds / 60.0) / miles
        let minutes = Int(paceMinPerMile)
        let seconds = Int((paceMinPerMile - Double(minutes)) * 60)

        return Text("Estimated pace: \(minutes):\(String(format: "%02d", seconds))/mile")
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    TrainingPlanSetupView(viewModel: TrainingPlanViewModel())
}
