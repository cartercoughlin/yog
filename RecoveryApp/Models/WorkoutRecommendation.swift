//
//  WorkoutRecommendation.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation

struct WorkoutRecommendation: Identifiable, Codable {
    let id: UUID
    let type: WorkoutType
    let title: String
    let description: String
    let duration: TimeInterval
    let intensity: Intensity
    let exercises: [Exercise]
    let reason: String

    init(
        id: UUID = UUID(),
        type: WorkoutType,
        title: String,
        description: String,
        duration: TimeInterval,
        intensity: Intensity,
        exercises: [Exercise] = [],
        reason: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.duration = duration
        self.intensity = intensity
        self.exercises = exercises
        self.reason = reason
    }

    var durationInMinutes: Int {
        return Int(duration / 60)
    }
}

struct Exercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let sets: Int
    let reps: String
    let restPeriod: TimeInterval
    let notes: String?
    let videoURL: String?

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        reps: String,
        restPeriod: TimeInterval = 60,
        notes: String? = nil,
        videoURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restPeriod = restPeriod
        self.notes = notes
        self.videoURL = videoURL
    }

    var restInSeconds: Int {
        return Int(restPeriod)
    }
}

extension WorkoutRecommendation {
    static var sampleHighIntensity: WorkoutRecommendation {
        WorkoutRecommendation(
            type: .strength,
            title: "Full Body Strength",
            description: "High-intensity full body workout focusing on compound movements",
            duration: 3600,
            intensity: .high,
            exercises: [
                Exercise(name: "Barbell Squats", sets: 4, reps: "8-10", restPeriod: 90, notes: "Focus on depth and form"),
                Exercise(name: "Bench Press", sets: 4, reps: "8-10", restPeriod: 90),
                Exercise(name: "Deadlifts", sets: 3, reps: "6-8", restPeriod: 120, notes: "Keep back neutral"),
                Exercise(name: "Pull-ups", sets: 3, reps: "8-12", restPeriod: 60),
                Exercise(name: "Overhead Press", sets: 3, reps: "8-10", restPeriod: 75),
                Exercise(name: "Barbell Rows", sets: 3, reps: "10-12", restPeriod: 60)
            ],
            reason: "High recovery score indicates you're ready for intense training"
        )
    }

    static var sampleMobility: WorkoutRecommendation {
        WorkoutRecommendation(
            type: .mobility,
            title: "Active Recovery - Yoga Flow",
            description: "Gentle yoga flow focusing on flexibility and recovery",
            duration: 1800,
            intensity: .low,
            exercises: [
                Exercise(name: "Cat-Cow Stretch", sets: 1, reps: "10 breaths", restPeriod: 0),
                Exercise(name: "Downward Dog", sets: 1, reps: "5 breaths", restPeriod: 0),
                Exercise(name: "Pigeon Pose", sets: 2, reps: "1 min each side", restPeriod: 30),
                Exercise(name: "Child's Pose", sets: 1, reps: "2 min", restPeriod: 0),
                Exercise(name: "Seated Forward Fold", sets: 1, reps: "2 min", restPeriod: 0),
                Exercise(name: "Supine Twist", sets: 2, reps: "1 min each side", restPeriod: 0)
            ],
            reason: "Low recovery score - focus on mobility and active recovery"
        )
    }

    static var sampleModerate: WorkoutRecommendation {
        WorkoutRecommendation(
            type: .strength,
            title: "Upper Body Strength",
            description: "Moderate intensity upper body workout",
            duration: 2700,
            intensity: .moderate,
            exercises: [
                Exercise(name: "Push-ups", sets: 3, reps: "12-15", restPeriod: 60),
                Exercise(name: "Dumbbell Rows", sets: 3, reps: "10-12 each arm", restPeriod: 60),
                Exercise(name: "Dumbbell Shoulder Press", sets: 3, reps: "10-12", restPeriod: 60),
                Exercise(name: "Bicep Curls", sets: 3, reps: "12-15", restPeriod: 45),
                Exercise(name: "Tricep Dips", sets: 3, reps: "10-12", restPeriod: 45),
                Exercise(name: "Face Pulls", sets: 3, reps: "15-20", restPeriod: 45)
            ],
            reason: "Moderate recovery - suitable for focused upper body work"
        )
    }
}
