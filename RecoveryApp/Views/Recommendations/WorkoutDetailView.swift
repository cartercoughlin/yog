//
//  WorkoutDetailView.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct WorkoutDetailView: View {
    let recommendation: WorkoutRecommendation
    @Environment(\.dismiss) private var dismiss
    @State private var showingWorkoutSession = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text(recommendation.type.emoji)
                        .font(.system(size: 40))
                        .frame(width: 70, height: 70)
                        .background(
                            Circle()
                                .fill(Color(recommendation.type.color).opacity(0.1))
                        )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendation.title)
                            .font(.title)
                            .fontWeight(.bold)

                        HStack(spacing: 16) {
                            Label("\(recommendation.durationInMinutes) min", systemImage: "clock")
                                .font(.subheadline)

                            Label(recommendation.intensity.rawValue, systemImage: "flame")
                                .font(.subheadline)
                                .foregroundStyle(Color(recommendation.intensity.color))
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()

                VStack(alignment: .leading, spacing: 8) {
                    Label("About", systemImage: "info.circle")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(recommendation.description)
                        .font(.body)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Why This Workout?", systemImage: "lightbulb")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(recommendation.reason)
                        .font(.body)
                }
                .padding(.horizontal)

                if !recommendation.exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Exercises")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        ForEach(Array(recommendation.exercises.enumerated()), id: \.element.id) { index, exercise in
                            ExerciseCard(exercise: exercise, number: index + 1)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Start") {
                    showingWorkoutSession = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(recommendation.exercises.isEmpty)
            }
        }
        .navigationDestination(isPresented: $showingWorkoutSession) {
            WorkoutSessionView(recommendation: recommendation)
        }
    }
}

struct ExerciseCard: View {
    let exercise: Exercise
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("\(number)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.blue))

                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)

                    HStack(spacing: 16) {
                        Label("\(exercise.sets) sets", systemImage: "repeat")
                        Label(exercise.reps, systemImage: "number")
                        Label("\(exercise.restInSeconds)s rest", systemImage: "timer")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if let notes = exercise.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(recommendation: .sampleHighIntensity)
    }
}
