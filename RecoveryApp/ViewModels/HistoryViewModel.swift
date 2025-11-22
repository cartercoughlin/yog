//
//  HistoryViewModel.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation
import SwiftUI
import Combine

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var recoveryHistory: [RecoveryData] = []
    @Published var workoutHistory: [WorkoutData] = []
    @Published var isLoading = false
    @Published var selectedTimeRange: TimeRange = .week

    private let healthKitManager = HealthKitManager()
    private let recoveryCalculator = RecoveryCalculator()

    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case twoWeeks = "14D"
        case month = "30D"
        case threeMonths = "90D"

        var days: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            case .month: return 30
            case .threeMonths: return 90
            }
        }

        var displayName: String {
            switch self {
            case .week: return "Week"
            case .twoWeeks: return "2 Weeks"
            case .month: return "Month"
            case .threeMonths: return "3 Months"
            }
        }
    }

    func loadHistory() async {
        isLoading = true

        do {
            let days = selectedTimeRange.days
            let historicalMetrics = try await healthKitManager.fetchHistoricalMetrics(days: days)

            var recovery: [RecoveryData] = []
            var workouts: [WorkoutData] = []

            for metrics in historicalMetrics {
                let recoveryData = recoveryCalculator.calculateRecoveryScore(
                    currentMetrics: metrics,
                    historicalMetrics: historicalMetrics
                )
                recovery.append(recoveryData)
                workouts.append(contentsOf: metrics.workouts)
            }

            recoveryHistory = recovery.sorted { $0.date > $1.date }
            workoutHistory = workouts.sorted { $0.date > $1.date }

        } catch {
            print("Error loading history: \(error)")
        }

        isLoading = false
    }

    var averageRecoveryScore: Double {
        guard !recoveryHistory.isEmpty else { return 0 }
        let sum = recoveryHistory.reduce(0.0) { $0 + Double($1.overallScore) }
        return sum / Double(recoveryHistory.count)
    }

    var totalWorkouts: Int {
        workoutHistory.count
    }

    var totalDistance: Double {
        workoutHistory.compactMap { $0.distanceInKilometers }.reduce(0, +)
    }

    var totalDuration: TimeInterval {
        workoutHistory.map { $0.duration }.reduce(0, +)
    }
}
