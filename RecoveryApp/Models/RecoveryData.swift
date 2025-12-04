//
//  RecoveryData.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation
import SwiftUI

struct RecoveryData: Codable, Identifiable {
    let id: UUID
    let date: Date
    let hrvScore: Double
    let restingHRScore: Double
    let sleepScore: Double
    let trainingLoadScore: Double
    let screenTimeScore: Double
    let overallScore: Int
    let category: RecoveryCategory
    let metrics: HealthMetrics

    init(
        id: UUID = UUID(),
        date: Date,
        hrvScore: Double,
        restingHRScore: Double,
        sleepScore: Double,
        trainingLoadScore: Double,
        screenTimeScore: Double,
        overallScore: Int,
        category: RecoveryCategory,
        metrics: HealthMetrics
    ) {
        self.id = id
        self.date = date
        self.hrvScore = hrvScore
        self.restingHRScore = restingHRScore
        self.sleepScore = sleepScore
        self.trainingLoadScore = trainingLoadScore
        self.screenTimeScore = screenTimeScore
        self.overallScore = overallScore
        self.category = category
        self.metrics = metrics
    }

    var scoreBreakdown: [(String, Double, String)] {
        [
            ("HRV", hrvScore, "heart.fill"),
            ("Resting HR", restingHRScore, "waveform.path.ecg"),
            ("Sleep", sleepScore, "bed.double.fill"),
            ("Training Load", trainingLoadScore, "figure.run"),
            ("Screen Time", screenTimeScore, "iphone")
        ]
    }
}

enum RecoveryCategory: String, Codable, CaseIterable {
    case peak = "Peak Performance"
    case good = "Good"
    case moderate = "Moderate"
    case low = "Low"
    case veryLow = "Very Low"

    var color: Color {
        switch self {
        case .peak: return .green
        case .good: return Color(red: 0.6, green: 0.8, blue: 0.4)
        case .moderate: return .yellow
        case .low: return .orange
        case .veryLow: return .red
        }
    }

    var icon: String {
        switch self {
        case .peak: return "bolt.fill"
        case .good: return "checkmark.circle.fill"
        case .moderate: return "minus.circle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .veryLow: return "xmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .peak:
            return "You're fully recovered and ready for high-intensity training"
        case .good:
            return "Good recovery status. You can handle moderate to high training loads"
        case .moderate:
            return "Moderate recovery. Consider lighter training or active recovery"
        case .low:
            return "Low recovery. Focus on mobility and light activity"
        case .veryLow:
            return "Very low recovery. Prioritize rest and recovery today"
        }
    }

    static func from(score: Int) -> RecoveryCategory {
        switch score {
        case 90...100:
            return .peak
        case 70..<90:
            return .good
        case 50..<70:
            return .moderate
        case 30..<50:
            return .low
        default:
            return .veryLow
        }
    }
}

extension RecoveryData {
    static var sample: RecoveryData {
        RecoveryData(
            date: Date(),
            hrvScore: 85,
            restingHRScore: 75,
            sleepScore: 80,
            trainingLoadScore: 90,
            screenTimeScore: 70,
            overallScore: 80,
            category: .good,
            metrics: HealthMetrics(
                date: Date(),
                hrv: 65,
                restingHeartRate: 52,
                sleepDuration: 28800,
                deepSleepDuration: 5400,
                remSleepDuration: 6480,
                coreSleepDuration: 14400,
                workouts: [.sampleRunning],
                activeEnergyBurned: 650,
                steps: 12500,
                screenTimeHours: 3.5
            )
        )
    }
}
