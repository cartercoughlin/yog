//
//  ThemeManager.swift
//  RecoveryApp
//
//  Created on 2025-12-01
//

import SwiftUI
import Combine

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: RecoveryTheme
    @Published var animateTransitions: Bool = true

    private var cancellables = Set<AnyCancellable>()

    init(score: Int = 50) {
        self.currentTheme = RecoveryTheme(
            score: score,
            activityLevel: nil,
            timeOfDay: .init()
        )
    }

    func updateTheme(score: Int, workouts: [WorkoutData] = []) {
        // Only update if score change is significant (±5 points) to avoid excessive re-renders
        guard shouldUpdateTheme(newScore: score) else { return }

        let activityLevel = workouts.isEmpty ? nil : RecoveryTheme.ActivityLevel(from: workouts)
        let newTheme = RecoveryTheme(
            score: score,
            activityLevel: activityLevel,
            timeOfDay: .init()
        )

        if animateTransitions {
            withAnimation(.easeInOut(duration: 1.0)) {
                currentTheme = newTheme
            }
        } else {
            currentTheme = newTheme
        }
    }

    private func shouldUpdateTheme(newScore: Int) -> Bool {
        // Update if score crosses a major threshold (20-point boundaries)
        // or if the absolute difference is >= 5 points
        let oldThreshold = currentTheme.score / 20
        let newThreshold = newScore / 20

        return oldThreshold != newThreshold || abs(newScore - currentTheme.score) >= 5
    }
}
