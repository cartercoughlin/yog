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
            let historicalMetrics = try await healthKitManager.fetchHistoricalMetrics(days: 90)
            print("✅ Loaded \(historicalMetrics.count) days of historic data")

            let todayMetrics = try await healthKitManager.fetchHealthMetrics(for: Date())

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
            self.error = "Failed to load health data: \(error.localizedDescription)"
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
