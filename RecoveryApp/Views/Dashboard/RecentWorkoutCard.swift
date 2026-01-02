//
//  RecentWorkoutCard.swift
//  RecoveryApp
//
//  Created on 2026-01-02
//

import SwiftUI

struct RecentWorkoutCard: View {
    let workout: WorkoutData

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    private var workoutColor: Color {
        switch workout.type {
        case .running: return .blue
        case .cycling: return .green
        case .swimming: return .cyan
        case .walking: return .orange
        case .strength: return .red
        case .yoga: return .purple
        case .mobility: return .pink
        case .rest: return .gray
        case .other: return .indigo
        }
    }

    private var workoutIcon: String {
        switch workout.type {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .walking: return "figure.walk"
        case .strength: return "figure.strengthtraining.traditional"
        case .yoga: return "figure.yoga"
        case .mobility: return "figure.flexibility"
        case .rest: return "bed.double.fill"
        case .other: return "figure.mixed.cardio"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: workoutIcon)
                    .font(.title2)
                    .foregroundStyle(workoutColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Most Recent Workout")
                        .font(.headline)
                    Text(dateFormatter.string(from: workout.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    WorkoutDetailHistoryView(workout: workout)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 20) {
                if let distance = workout.distance {
                    WorkoutStat(
                        icon: "location.fill",
                        value: String(format: "%.2f", distance / 1609.34),
                        unit: "mi",
                        color: workoutColor
                    )
                }

                WorkoutStat(
                    icon: "clock.fill",
                    value: formatDuration(workout.duration),
                    unit: "",
                    color: workoutColor
                )

                if let distance = workout.distance {
                    let paceSecPerMile = workout.duration / (distance / 1609.34)
                    let paceMin = Int(paceSecPerMile / 60)
                    let paceSec = Int(paceSecPerMile.truncatingRemainder(dividingBy: 60))

                    WorkoutStat(
                        icon: "speedometer",
                        value: String(format: "%d:%02d", paceMin, paceSec),
                        unit: "/mi",
                        color: workoutColor
                    )
                }
            }
        }
        .padding()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
        )
        .padding(.horizontal)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

struct WorkoutStat: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        RecentWorkoutCard(workout: .sampleRunning)
    }
}
