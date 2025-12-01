import SwiftUI

struct InjuryDetailView: View {
    let injury: Injury
    @ObservedObject var viewModel: InjuryTrackerViewModel

    @State private var showExerciseDetail: RehabExercise?
    @State private var editedNotes: String
    @State private var isEditing = false

    init(injury: Injury, viewModel: InjuryTrackerViewModel) {
        self.injury = injury
        self.viewModel = viewModel
        _editedNotes = State(initialValue: injury.notes)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Injury Header
                injuryHeader

                // Notes Section
                notesSection

                // Rehab Exercises
                exercisesSection

                // Generate More Button
                if injury.suggestedExercises.count < 15 {
                    generateMoreButton
                }

                // Action Buttons
                actionButtons
            }
            .padding()
        }
        .navigationTitle(injury.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $showExerciseDetail) { exercise in
            ExerciseDetailSheet(
                exercise: exercise,
                injury: injury,
                viewModel: viewModel
            )
        }
    }

    private var injuryHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: injury.severity.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(injury.severity.color)

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(injury.region.rawValue)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(injury.severity.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(injury.severity.color)
                }
            }

            Divider()

            HStack {
                statBox(title: "Days Active", value: "\(injury.durationDays)")
                Divider().frame(height: 40)
                statBox(title: "Exercises", value: "\(injury.suggestedExercises.count)")
                Divider().frame(height: 40)
                statBox(title: "Avg Rating", value: injury.averageExerciseRating > 0 ? String(format: "%.1f ★", injury.averageExerciseRating) : "–")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func statBox(title: String, value: String) -> some View {
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)

                Spacer()

                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        var updatedInjury = injury
                        updatedInjury.notes = editedNotes
                        viewModel.updateInjury(updatedInjury)
                    }
                    isEditing.toggle()
                }
                .font(.subheadline)
            }

            if isEditing {
                TextEditor(text: $editedNotes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Text(injury.notes.isEmpty ? "No notes added" : injury.notes)
                    .font(.subheadline)
                    .foregroundStyle(injury.notes.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rehab Exercises")
                .font(.headline)

            Text("Tap an exercise to view details and rate its effectiveness")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(injury.suggestedExercises) { exercise in
                Button {
                    showExerciseDetail = exercise
                } label: {
                    ExerciseCard(
                        exercise: exercise,
                        rating: injury.ratingForExercise(exercise.id)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var generateMoreButton: some View {
        Button {
            viewModel.generateMoreExercises(for: injury)
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Generate More Exercises")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
            .foregroundStyle(.blue)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if injury.isActive {
                Button {
                    viewModel.markInjuryResolved(injury)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Resolved")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
            } else {
                Button {
                    viewModel.markInjuryActive(injury)
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Mark as Active Again")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
            }

            Button(role: .destructive) {
                viewModel.deleteInjury(injury)
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Injury")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .cornerRadius(12)
            }
        }
    }
}

struct ExerciseCard: View {
    let exercise: RehabExercise
    let rating: ExerciseRating?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: exercise.type.icon)
                    .font(.title3)
                    .foregroundStyle(exercise.type.color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)

                    Text(exercise.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let rating = rating, rating.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<rating.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }

            Text(exercise.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label(exercise.duration, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
    }
}

struct ExerciseDetailSheet: View {
    let exercise: RehabExercise
    let injury: Injury
    @ObservedObject var viewModel: InjuryTrackerViewModel

    @Environment(\.dismiss) var dismiss
    @State private var selectedRating: Int
    @State private var notes: String

    init(exercise: RehabExercise, injury: Injury, viewModel: InjuryTrackerViewModel) {
        self.exercise = exercise
        self.injury = injury
        self.viewModel = viewModel

        let existingRating = injury.ratingForExercise(exercise.id)
        _selectedRating = State(initialValue: existingRating?.rating ?? 0)
        _notes = State(initialValue: existingRating?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Exercise Header
                    HStack {
                        Image(systemName: exercise.type.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(exercise.type.color)

                        VStack(alignment: .leading) {
                            Text(exercise.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(exercise.type.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(exercise.description)
                            .font(.subheadline)
                    }

                    // Duration
                    HStack {
                        Image(systemName: "clock")
                        Text(exercise.duration)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.headline)

                        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                    .frame(width: 20, alignment: .leading)

                                Text(instruction)
                                    .font(.subheadline)
                            }
                        }
                    }

                    Divider()

                    // Rating Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rate Effectiveness")
                            .font(.headline)

                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    selectedRating = star
                                } label: {
                                    Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                        .font(.title2)
                                        .foregroundStyle(star <= selectedRating ? .yellow : .gray)
                                }
                            }
                        }

                        Text("Notes (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $notes)
                            .frame(height: 80)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    Button {
                        if selectedRating > 0 {
                            viewModel.rateExercise(
                                for: injury.id,
                                exerciseId: exercise.id,
                                rating: selectedRating,
                                notes: notes.isEmpty ? nil : notes
                            )
                        }
                        dismiss()
                    } label: {
                        Text("Save Rating")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedRating > 0 ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .disabled(selectedRating == 0)
                }
                .padding()
            }
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        InjuryDetailView(
            injury: Injury(
                region: .leftKnee,
                severity: .moderate,
                name: "Runner's Knee",
                notes: "Started after long run",
                suggestedExercises: ExerciseDatabase.exercisesFor(region: .leftKnee)
            ),
            viewModel: InjuryTrackerViewModel()
        )
    }
}
