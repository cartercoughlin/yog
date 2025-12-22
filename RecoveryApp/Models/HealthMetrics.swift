//
//  HealthMetrics.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation

struct HealthMetrics: Codable, Identifiable {
    let id: UUID
    let date: Date
    let hrv: Double?
    let restingHeartRate: Int?
    let sleepDuration: TimeInterval?
    let deepSleepDuration: TimeInterval?
    let remSleepDuration: TimeInterval?
    let coreSleepDuration: TimeInterval?
    let workouts: [WorkoutData]
    let activeEnergyBurned: Double?
    let steps: Int?

    init(
        id: UUID = UUID(),
        date: Date,
        hrv: Double? = nil,
        restingHeartRate: Int? = nil,
        sleepDuration: TimeInterval? = nil,
        deepSleepDuration: TimeInterval? = nil,
        remSleepDuration: TimeInterval? = nil,
        coreSleepDuration: TimeInterval? = nil,
        workouts: [WorkoutData] = [],
        activeEnergyBurned: Double? = nil,
        steps: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepDuration = sleepDuration
        self.deepSleepDuration = deepSleepDuration
        self.remSleepDuration = remSleepDuration
        self.coreSleepDuration = coreSleepDuration
        self.workouts = workouts
        self.activeEnergyBurned = activeEnergyBurned
        self.steps = steps
    }

    var totalSleepHours: Double? {
        guard let duration = sleepDuration else { return nil }
        return duration / 3600.0
    }

    var deepSleepPercentage: Double? {
        guard let deep = deepSleepDuration,
              let total = sleepDuration,
              total > 0 else { return nil }
        return (deep / total) * 100
    }

    var remSleepPercentage: Double? {
        guard let rem = remSleepDuration,
              let total = sleepDuration,
              total > 0 else { return nil }
        return (rem / total) * 100
    }

    var hasCompleteData: Bool {
        return hrv != nil &&
               restingHeartRate != nil &&
               sleepDuration != nil
    }
}
