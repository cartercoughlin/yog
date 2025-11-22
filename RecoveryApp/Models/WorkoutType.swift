//
//  WorkoutType.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation
import HealthKit

enum WorkoutType: String, Codable, CaseIterable {
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case strength = "Strength Training"
    case yoga = "Yoga"
    case mobility = "Mobility"
    case walking = "Walking"
    case rest = "Rest"
    case other = "Other"

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .strength: return "dumbbell.fill"
        case .yoga: return "figure.mind.and.body"
        case .mobility: return "figure.flexibility"
        case .walking: return "figure.walk"
        case .rest: return "bed.double.fill"
        case .other: return "figure.mixed.cardio"
        }
    }

    var color: String {
        switch self {
        case .running: return "blue"
        case .cycling: return "green"
        case .swimming: return "cyan"
        case .strength: return "orange"
        case .yoga: return "purple"
        case .mobility: return "pink"
        case .walking: return "mint"
        case .rest: return "gray"
        case .other: return "indigo"
        }
    }

    static func from(hkWorkoutType: HKWorkoutActivityType) -> WorkoutType {
        switch hkWorkoutType {
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .swimming:
            return .swimming
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .strength
        case .yoga:
            return .yoga
        case .flexibility:
            return .mobility
        case .walking:
            return .walking
        default:
            return .other
        }
    }
}

enum Intensity: String, Codable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"

    var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "red"
        }
    }
}
