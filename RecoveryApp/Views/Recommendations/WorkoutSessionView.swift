//
//  WorkoutSessionView.swift
//  RecoveryApp
//
//  Created on 2025-11-29
//

import SwiftUI

struct WorkoutSessionView: View {
    @StateObject private var viewModel: WorkoutTimerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEndAlert = false

    init(recommendation: WorkoutRecommendation) {
        _viewModel = StateObject(wrappedValue: WorkoutTimerViewModel(recommendation: recommendation))
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if viewModel.phase == .ready {
                readyView
            } else if viewModel.phase == .completed {
                completedView
            } else {
                workoutView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("End") {
                    showingEndAlert = true
                }
                .foregroundStyle(.red)
            }
        }
        .alert("End Workout?", isPresented: $showingEndAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Workout", role: .destructive) {
                viewModel.endWorkout()
            }
        } message: {
            Text("Are you sure you want to end this workout?")
        }
    }

    private var readyView: some View {
        VStack(spacing: 32) {
            Text("Ready to Start?")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(viewModel.recommendation.title)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("\(viewModel.recommendation.exercises.count) exercises")
                .font(.headline)

            Button(action: {
                viewModel.startWorkout()
            }) {
                Text("Start Workout")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
        }
        .padding()
    }

    private var workoutView: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: viewModel.progress)
                .tint(.blue)
                .padding(.horizontal)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 24) {
                    // Exercise number and name
                    VStack(spacing: 8) {
                        Text("Exercise \(viewModel.currentExerciseIndex + 1) of \(viewModel.recommendation.exercises.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let exercise = viewModel.currentExercise {
                            Text(exercise.name)
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 24)

                    // Animation/Placeholder
                    if let exercise = viewModel.currentExercise {
                        exerciseAnimationView(exercise: exercise)
                    }

                    // Set counter
                    if viewModel.phase == .exercise {
                        VStack(spacing: 8) {
                            Text("Set \(viewModel.currentSet) of \(viewModel.totalSets)")
                                .font(.title3)
                                .fontWeight(.semibold)

                            if let exercise = viewModel.currentExercise {
                                Text(exercise.reps)
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .fontWeight(.bold)

                                if let notes = exercise.notes {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .padding(.horizontal)
                    }

                    // Rest timer
                    if viewModel.phase == .rest {
                        VStack(spacing: 16) {
                            Text("Rest")
                                .font(.title)
                                .fontWeight(.semibold)

                            Text(timeString(from: viewModel.timeRemaining))
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                                .monospacedDigit()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }

            // Control buttons
            if viewModel.phase == .exercise {
                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.completeCurrentSet()
                    }) {
                        Text("Complete Set")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        viewModel.skipExercise()
                    }) {
                        Text("Skip Exercise")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    private var completedView: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Workout Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Great job!")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
        }
        .padding()
    }

    @ViewBuilder
    private func exerciseAnimationView(exercise: Exercise) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemBackground))
                .frame(height: 300)

            VStack(spacing: 16) {
                // Placeholder for animation - you can replace this with actual GIFs or videos
                Image(systemName: getExerciseIcon(for: exercise.name))
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
            }
        }
        .padding(.horizontal)
    }

    private func getExerciseIcon(for exerciseName: String) -> String {
        let name = exerciseName.lowercased()

        if name.contains("squat") {
            return "figure.squat"
        } else if name.contains("push") || name.contains("press") {
            return "figure.strengthtraining.traditional"
        } else if name.contains("pull") {
            return "figure.pull.ups"
        } else if name.contains("run") || name.contains("walk") {
            return "figure.run"
        } else if name.contains("yoga") || name.contains("stretch") || name.contains("pose") {
            return "figure.yoga"
        } else if name.contains("deadlift") {
            return "figure.strengthtraining.functional"
        } else if name.contains("lunge") {
            return "figure.walk"
        } else if name.contains("plank") {
            return "figure.core.training"
        } else if name.contains("row") {
            return "figure.rower"
        } else {
            return "figure.mixed.cardio"
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        WorkoutSessionView(recommendation: .sampleHighIntensity)
    }
}
