//
//  WorkoutData.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation
import HealthKit

struct WorkoutData: Codable, Identifiable {
    let id: UUID
    let date: Date
    let type: WorkoutType
    let duration: TimeInterval
    let distance: Double?
    let averageHeartRate: Int?
    let maxHeartRate: Int?
    let caloriesBurned: Double?
    let trainingStress: Double

    // Not codable - for runtime use only
    var workout: HKWorkout?

    enum CodingKeys: String, CodingKey {
        case id, date, type, duration, distance
        case averageHeartRate, maxHeartRate, caloriesBurned, trainingStress
    }

    init(
        id: UUID = UUID(),
        date: Date,
        type: WorkoutType,
        duration: TimeInterval,
        distance: Double? = nil,
        averageHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        caloriesBurned: Double? = nil,
        trainingStress: Double = 0,
        workout: HKWorkout? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.duration = duration
        self.distance = distance
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.caloriesBurned = caloriesBurned
        self.trainingStress = trainingStress
        self.workout = workout
    }

    var durationInMinutes: Double {
        return duration / 60.0
    }

    var distanceInKilometers: Double? {
        guard let distance = distance else { return nil }
        return distance / 1000.0
    }

    var distanceInMiles: Double? {
        guard let distance = distance else { return nil }
        return distance / 1609.34
    }

    var pacePerKm: TimeInterval? {
        guard let distance = distance, distance > 0 else { return nil }
        let km = distance / 1000.0
        return duration / km
    }

    var pacePerMile: TimeInterval? {
        guard let distance = distance, distance > 0 else { return nil }
        let miles = distance / 1609.34
        return duration / miles
    }

    func calculateTrainingStress(restingHR: Int = 60, maxHR: Int = 190) -> Double {
        guard let avgHR = averageHeartRate else {
            return durationInMinutes * 0.5
        }

        let hrReserve = Double(maxHR - restingHR)
        let intensity = Double(avgHR - restingHR) / hrReserve

        return durationInMinutes * intensity * intensity * 100
    }
}

extension WorkoutData {
    static var sampleRunning: WorkoutData {
        WorkoutData(
            date: Date(),
            type: .running,
            duration: 3600,
            distance: 10000,
            averageHeartRate: 150,
            maxHeartRate: 175,
            caloriesBurned: 650,
            trainingStress: 85
        )
    }

    static var sampleStrength: WorkoutData {
        WorkoutData(
            date: Date(),
            type: .strength,
            duration: 2700,
            averageHeartRate: 120,
            maxHeartRate: 155,
            caloriesBurned: 320,
            trainingStress: 45
        )
    }

    static var sampleYoga: WorkoutData {
        WorkoutData(
            date: Date(),
            type: .yoga,
            duration: 1800,
            averageHeartRate: 95,
            caloriesBurned: 150,
            trainingStress: 20
        )
    }
}
