import SwiftUI

struct InjuryInputSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: InjuryViewModel

    @State private var selectedLocation: BodyLocation = .leftKnee
    @State private var selectedPainType: PainType = .aching
    @State private var selectedSeverity: PainSeverity = .moderate
    @State private var notes: String = ""
    @State private var affectedWorkouts: Set<String> = []
    @State private var dateReported: Date = Date()

    let workoutTypes = ["Running", "Cycling", "Swimming", "Strength Training", "Yoga", "Walking"]

    var editingInjury: InjuryData?

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    Picker("Body Part", selection: $selectedLocation) {
                        ForEach(BodyLocation.allCases) { location in
                            Text(location.displayName)
                                .tag(location)
                        }
                    }
                }

                Section("Pain Details") {
                    Picker("Pain Type", selection: $selectedPainType) {
                        ForEach(PainType.allCases) { painType in
                            Label(painType.displayName, systemImage: painType.icon)
                                .tag(painType)
                        }
                    }

                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(PainSeverity.allCases) { severity in
                            Text(severity.displayName)
                                .tag(severity)
                        }
                    }

                    DatePicker("Date Noticed", selection: $dateReported, displayedComponents: .date)
                }

                Section("Affected Activities") {
                    ForEach(workoutTypes, id: \.self) { workout in
                        Toggle(workout, isOn: Binding(
                            get: { affectedWorkouts.contains(workout) },
                            set: { isOn in
                                if isOn {
                                    affectedWorkouts.insert(workout)
                                } else {
                                    affectedWorkouts.remove(workout)
                                }
                            }
                        ))
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section {
                    // Severity visualization
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Severity Level: \(selectedSeverity.numericValue)/10")
                            .font(.headline)

                        HStack(spacing: 4) {
                            ForEach(1...10, id: \.self) { level in
                                Rectangle()
                                    .fill(level <= selectedSeverity.numericValue ? severityColor : Color.gray.opacity(0.2))
                                    .frame(height: 20)
                            }
                        }
                        .cornerRadius(4)

                        Text(severityDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(editingInjury == nil ? "Log Injury" : "Edit Injury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(editingInjury == nil ? "Save" : "Update") {
                        saveInjury()
                    }
                }
            }
            .onAppear {
                loadEditingData()
            }
        }
    }

    private var severityColor: Color {
        switch selectedSeverity.color {
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .gray
        }
    }

    private var severityDescription: String {
        switch selectedSeverity {
        case .mild: return "Minor discomfort, doesn't significantly impact activities"
        case .moderate: return "Noticeable pain, may need to modify activities"
        case .severe: return "Significant pain, should avoid aggravating activities"
        case .debilitating: return "Intense pain, seek medical attention"
        }
    }

    private func loadEditingData() {
        guard let injury = editingInjury else { return }

        selectedLocation = injury.location
        selectedPainType = injury.painType
        selectedSeverity = injury.severity
        notes = injury.notes
        affectedWorkouts = Set(injury.affectedWorkoutTypes)
        dateReported = injury.dateReported
    }

    private func saveInjury() {
        if let existing = editingInjury {
            // Update existing injury
            var updated = existing
            updated.location = selectedLocation
            updated.painType = selectedPainType
            updated.severity = selectedSeverity
            updated.notes = notes
            updated.affectedWorkoutTypes = Array(affectedWorkouts)
            updated.dateReported = dateReported

            viewModel.updateInjury(updated)
        } else {
            // Create new injury
            let newInjury = InjuryData(
                location: selectedLocation,
                painType: selectedPainType,
                severity: selectedSeverity,
                status: .active,
                dateReported: dateReported,
                notes: notes,
                affectedWorkoutTypes: Array(affectedWorkouts)
            )

            viewModel.addInjury(newInjury)
        }

        dismiss()
    }
}

// MARK: - Preview
#Preview {
    InjuryInputSheet(viewModel: InjuryViewModel())
}
