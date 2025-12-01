//
//  WorkoutTimerViewModel.swift
//  RecoveryApp
//
//  Created on 2025-11-29
//

import Foundation
import Combine

enum WorkoutPhase {
    case ready
    case exercise
    case rest
    case completed
}

class WorkoutTimerViewModel: ObservableObject {
    @Published var currentExerciseIndex = 0
    @Published var currentSet = 1
    @Published var timeRemaining: TimeInterval = 0
    @Published var phase: WorkoutPhase = .ready
    @Published var isRunning = false

    let recommendation: WorkoutRecommendation
    private var timer: Timer?

    init(recommendation: WorkoutRecommendation) {
        self.recommendation = recommendation
    }

    var currentExercise: Exercise? {
        guard currentExerciseIndex < recommendation.exercises.count else { return nil }
        return recommendation.exercises[currentExerciseIndex]
    }

    var totalSets: Int {
        currentExercise?.sets ?? 0
    }

    var progress: Double {
        let totalExercises = recommendation.exercises.count
        let completedExercises = currentExerciseIndex
        let exerciseProgress = Double(completedExercises) / Double(totalExercises)

        if let exercise = currentExercise {
            let setProgress = Double(currentSet - 1) / Double(exercise.sets)
            let currentExerciseProgress = setProgress / Double(totalExercises)
            return exerciseProgress + currentExerciseProgress
        }

        return exerciseProgress
    }

    func startWorkout() {
        phase = .exercise
        currentExerciseIndex = 0
        currentSet = 1
        startExerciseTimer()
    }

    func startExerciseTimer() {
        guard let exercise = currentExercise else {
            completeWorkout()
            return
        }

        // For timed exercises, use a default of 60 seconds
        // For rep-based exercises, we'll just show the exercise without countdown
        timeRemaining = 60
        phase = .exercise
        isRunning = true
        startTimer()
    }

    func completeCurrentSet() {
        stopTimer()

        guard let exercise = currentExercise else { return }

        if currentSet < exercise.sets {
            // Start rest period
            timeRemaining = exercise.restPeriod
            phase = .rest
            currentSet += 1
            startTimer()
        } else {
            // Move to next exercise
            moveToNextExercise()
        }
    }

    func skipExercise() {
        stopTimer()
        moveToNextExercise()
    }

    private func moveToNextExercise() {
        currentExerciseIndex += 1
        currentSet = 1

        if currentExerciseIndex < recommendation.exercises.count {
            startExerciseTimer()
        } else {
            completeWorkout()
        }
    }

    private func completeWorkout() {
        stopTimer()
        phase = .completed
        isRunning = false
    }

    private func startTimer() {
        timer?.invalidate()
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                if self.phase == .rest {
                    self.startExerciseTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func pauseWorkout() {
        isRunning = false
        timer?.invalidate()
    }

    func resumeWorkout() {
        isRunning = true
        startTimer()
    }

    func endWorkout() {
        stopTimer()
        phase = .completed
    }

    deinit {
        timer?.invalidate()
    }
}
