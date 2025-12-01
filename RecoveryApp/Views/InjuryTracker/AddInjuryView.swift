import SwiftUI

struct AddInjuryView: View {
    @ObservedObject var viewModel: InjuryTrackerViewModel
    @Environment(\.dismiss) var dismiss

    let preselectedRegion: BodyRegion?

    @State private var name: String = ""
    @State private var selectedRegion: BodyRegion
    @State private var selectedSeverity: InjurySeverity = .moderate
    @State private var notes: String = ""
    @State private var dateReported: Date = Date()

    init(viewModel: InjuryTrackerViewModel, preselectedRegion: BodyRegion? = nil) {
        self.viewModel = viewModel
        self.preselectedRegion = preselectedRegion
        _selectedRegion = State(initialValue: preselectedRegion ?? .leftKnee)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Injury Name", text: $name)
                        .autocorrectionDisabled()

                    DatePicker(
                        "Date Noticed",
                        selection: $dateReported,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                } header: {
                    Text("Basic Info")
                }

                Section {
                    Picker("Body Region", selection: $selectedRegion) {
                        ForEach(BodyRegion.allCases, id: \.self) { region in
                            Text(region.rawValue).tag(region)
                        }
                    }

                    Picker("Severity", selection: $selectedSeverity) {
                        ForEach(InjurySeverity.allCases, id: \.self) { severity in
                            HStack {
                                Image(systemName: severity.icon)
                                Text(severity.rawValue)
                            }
                            .tag(severity)
                        }
                    }
                } header: {
                    Text("Injury Details")
                } footer: {
                    severityDescription
                }

                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } header: {
                    Text("Notes (Optional)")
                } footer: {
                    Text("Add any relevant details about how the injury occurred or symptoms")
                }

                Section {
                    Text("Based on the selected region, the app will automatically suggest appropriate rehab exercises including stretches, foam rolling, and strengthening exercises.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Injury")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addInjury()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var severityDescription: some View {
        let description: String
        switch selectedSeverity {
        case .minor:
            description = "Minor discomfort, can continue training with modifications"
        case .moderate:
            description = "Noticeable pain that may require rest and rehab"
        case .severe:
            description = "Significant pain, should seek medical attention"
        }

        return Text(description)
            .font(.caption)
    }

    private func addInjury() {
        let injury = Injury(
            region: selectedRegion,
            severity: selectedSeverity,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dateReported: dateReported,
            notes: notes
        )

        viewModel.addInjury(injury)
        dismiss()
    }
}

#Preview {
    AddInjuryView(viewModel: InjuryTrackerViewModel())
}
