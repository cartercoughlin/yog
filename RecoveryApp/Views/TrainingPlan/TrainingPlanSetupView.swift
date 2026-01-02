import SwiftUI

struct TrainingPlanSetupView: View {
    @ObservedObject var viewModel: TrainingPlanViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false

    private var isEditing: Bool {
        viewModel.currentPlan != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Plan Name (optional)", text: $viewModel.planName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Plan Information")
                } footer: {
                    Text("Give your training plan a custom name, or leave blank for auto-generated name")
                }

                Section {
                    Picker("Race Distance", selection: $viewModel.selectedDistance) {
                        ForEach(RaceDistance.allCases) { distance in
                            Text(distance.rawValue).tag(distance)
                        }
                    }
                    .onChange(of: viewModel.selectedDistance) { _, _ in
                        viewModel.updateDesiredMileageDefaults()
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
                        Text("Minimum: \(Int(viewModel.currentMinWeeklyMileage)) miles/week")
                            .font(.subheadline)

                        Slider(
                            value: $viewModel.currentMinWeeklyMileage,
                            in: 10...80,
                            step: 5
                        )
                        .onChange(of: viewModel.currentMinWeeklyMileage) { _, _ in
                            viewModel.updateDesiredMileageDefaults()
                        }

                        Text("Maximum: \(Int(viewModel.currentMaxWeeklyMileage)) miles/week")
                            .font(.subheadline)

                        Slider(
                            value: $viewModel.currentMaxWeeklyMileage,
                            in: 15...85,
                            step: 5
                        )
                        .onChange(of: viewModel.currentMaxWeeklyMileage) { _, _ in
                            viewModel.updateDesiredMileageDefaults()
                        }
                    }
                } header: {
                    Text("Current Weekly Mileage Range")
                } footer: {
                    Text("What is your current typical weekly mileage range?")
                }

                Section {
                    Picker("Days Per Week", selection: $viewModel.daysPerWeek) {
                        ForEach(3...7, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Running Frequency")
                } footer: {
                    Text("How many days per week do you want to run?")
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
                    Text("Target Weekly Mileage Range")
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
                            value: "VDOT-Based Training"
                        )

                        InfoRow(
                            title: "Quality Days",
                            value: "3 per week"
                        )
                    }
                } header: {
                    Text("Plan Overview")
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Training Plan")
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("This will permanently delete your current training plan and all linked workouts")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Training Plan" : "Create Training Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Update" : "Generate") {
                        viewModel.generatePlan()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Delete Training Plan?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.resetPlan()
                    dismiss()
                }
            } message: {
                Text("This will permanently delete your training plan and all linked workouts. This action cannot be undone.")
            }
            .onAppear {
                loadExistingPlanData()
            }
        }
    }

    private func loadExistingPlanData() {
        guard let plan = viewModel.currentPlan else {
            // Clear name field when creating new plan
            viewModel.planName = ""
            return
        }

        // Populate form with existing plan data
        viewModel.planName = plan.name
        viewModel.selectedDistance = plan.raceDistance
        viewModel.selectedRaceDate = plan.raceDate
        viewModel.minWeeklyMileage = plan.minWeeklyMileage
        viewModel.maxWeeklyMileage = plan.maxWeeklyMileage
        viewModel.daysPerWeek = plan.daysPerWeek
        viewModel.allowRecoveryAdjustments = plan.allowRecoveryAdjustments

        // Convert goal time back to hours/minutes/seconds
        let totalSeconds = Int(plan.goalTimeInSeconds)
        viewModel.goalHours = totalSeconds / 3600
        viewModel.goalMinutes = (totalSeconds % 3600) / 60
        viewModel.goalSeconds = totalSeconds % 60
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
