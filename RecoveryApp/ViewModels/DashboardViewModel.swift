//
//  DashboardViewModel.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation
import SwiftUI
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var todayRecovery: RecoveryData?
    @Published var recommendation: WorkoutRecommendation?
    @Published var weeklyTrend: (average: Double, trend: Trend)?
    @Published var historicalMetrics: [HealthMetrics] = []
    @Published var isLoading = false
    @Published var error: String?

    private let healthKitManager = HealthKitManager()
    private let recoveryCalculator = RecoveryCalculator()
    private let recommendationEngine = RecommendationEngine()

    var mostRecentWorkout: WorkoutData? {
        historicalMetrics
            .flatMap { $0.workouts }
            .sorted { $0.date > $1.date }
            .first
    }

    // Cache management
    private var lastLoadTime: Date?
    private var cacheExpirationInterval: TimeInterval = 300 // 5 minutes

    func loadData(injuryViewModel: InjuryTrackerViewModel) async {
        // Check if we have cached data that's still fresh
        if let lastLoad = lastLoadTime,
           todayRecovery != nil,
           Date().timeIntervalSince(lastLoad) < cacheExpirationInterval {
            print("📦 Using cached data (loaded \(Int(Date().timeIntervalSince(lastLoad)))s ago)")
            return
        }

        isLoading = true
        error = nil

        do {
            try await healthKitManager.requestAuthorization()

            // Fetch 90 days of historical data for better baselines
            print("📅 Fetching 90 days of historical data for baseline calculation...")
            var historicalMetrics = try await healthKitManager.fetchHistoricalMetrics(days: 90)
            print("✅ Loaded \(historicalMetrics.count) days of historic data")
            
            // Check if we have any meaningful data
            let hasAnyData = historicalMetrics.contains { metrics in
                metrics.hrv != nil || metrics.restingHeartRate != nil || 
                metrics.sleepDuration != nil || !metrics.workouts.isEmpty
            }
            
            guard hasAnyData else {
                throw HealthKitError.dataNotAvailable
            }

            let todayMetrics = try await healthKitManager.fetchHealthMetrics(for: Date())

            // Add today's metrics to historical data if not already present
            let today = Calendar.current.startOfDay(for: Date())
            if !historicalMetrics.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                historicalMetrics.append(todayMetrics)
                print("✅ Added today's metrics to historical data")
            } else {
                // Replace today's metrics with fresh data
                historicalMetrics.removeAll { Calendar.current.isDate($0.date, inSameDayAs: today) }
                historicalMetrics.append(todayMetrics)
                print("✅ Updated today's metrics in historical data")
            }

            // Get injury impact
            let injuryImpact = injuryViewModel.totalRecoveryImpact

            let recovery = recoveryCalculator.calculateRecoveryScore(
                currentMetrics: todayMetrics,
                historicalMetrics: historicalMetrics,
                injuryImpact: injuryImpact
            )

            let allWorkouts = historicalMetrics.flatMap { $0.workouts }
            let workoutRec = recommendationEngine.generateRecommendation(
                recoveryScore: recovery.overallScore,
                recentWorkouts: allWorkouts
            )

            let historicalRecovery = historicalMetrics.map { metrics in
                recoveryCalculator.calculateRecoveryScore(
                    currentMetrics: metrics,
                    historicalMetrics: historicalMetrics
                )
            }

            let trend = recoveryCalculator.calculateWeeklyBaseline(historicalData: historicalRecovery)

            todayRecovery = recovery
            recommendation = workoutRec
            weeklyTrend = trend
            self.historicalMetrics = historicalMetrics

            // Update cache timestamp
            lastLoadTime = Date()
            print("✅ Data cached at \(Date())")

        } catch {
            if let healthKitError = error as? HealthKitError {
                switch healthKitError {
                case .dataNotAvailable:
                    self.error = nil // Will show EmptyStateView instead
                case .notAvailable:
                    self.error = "HealthKit is not available on this device"
                case .authorizationFailed:
                    self.error = "HealthKit access denied. Please enable in Settings > Privacy & Security > Health"
                }
            } else {
                self.error = "Failed to load health data: \(error.localizedDescription)"
            }
            print("Error loading data: \(error)")
        }

        isLoading = false
    }

    func refreshData(injuryViewModel: InjuryTrackerViewModel) async {
        // Force refresh by clearing cache
        lastLoadTime = nil
        await loadData(injuryViewModel: injuryViewModel)
    }

    func clearCache() {
        lastLoadTime = nil
        todayRecovery = nil
        recommendation = nil
        weeklyTrend = nil
        historicalMetrics = []
    }
}
