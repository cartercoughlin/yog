//
//  RecommendationEngine.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation

class RecommendationEngine {

    func generateRecommendation(
        recoveryScore: Int,
        recentWorkouts: [WorkoutData],
        injuryWarnings: [String] = []
    ) -> WorkoutRecommendation {

        let last7Days = recentWorkouts.filter { workout in
            Calendar.current.dateComponents([.day], from: workout.date, to: Date()).day ?? 99 <= 7
        }

        let strengthDays = last7Days.filter { $0.type == .strength }.count
        let runningDays = last7Days.filter { $0.type == .running }.count
        let mobilityDays = last7Days.filter { $0.type == .mobility || $0.type == .yoga }.count

        var recommendation: WorkoutRecommendation

        if recoveryScore >= 85 {
            recommendation = highRecoveryRecommendation(strengthDays: strengthDays, runningDays: runningDays)
        } else if recoveryScore >= 70 {
            recommendation = goodRecoveryRecommendation(strengthDays: strengthDays, mobilityDays: mobilityDays)
        } else if recoveryScore >= 50 {
            recommendation = moderateRecoveryRecommendation(strengthDays: strengthDays)
        } else if recoveryScore >= 30 {
            recommendation = lowRecoveryRecommendation()
        } else {
            recommendation = veryLowRecoveryRecommendation()
        }

        // Add injury warnings if present
        if !injuryWarnings.isEmpty {
            let warningText = "\n\n⚠️ Injury Warnings:\n" + injuryWarnings.map { "• \($0)" }.joined(separator: "\n")
            recommendation = WorkoutRecommendation(
                type: recommendation.type,
                title: recommendation.title,
                description: recommendation.description + warningText,
                duration: recommendation.duration,
                intensity: recommendation.intensity,
                exercises: recommendation.exercises,
                reason: recommendation.reason
            )
        }

        return recommendation
    }

    private func highRecoveryRecommendation(strengthDays: Int, runningDays: Int) -> WorkoutRecommendation {
        if strengthDays < 2 {
            return WorkoutRecommendation(
                type: .strength,
                title: "Full Body Strength",
                description: "High-intensity full body workout with compound movements",
                duration: 3600,
                intensity: .high,
                exercises: [
                    Exercise(name: "Barbell Back Squats", sets: 4, reps: "8-10", restPeriod: 90,
                            notes: "Focus on depth and maintaining neutral spine"),
                    Exercise(name: "Barbell Bench Press", sets: 4, reps: "8-10", restPeriod: 90,
                            notes: "Control the descent, explosive press"),
                    Exercise(name: "Conventional Deadlifts", sets: 3, reps: "6-8", restPeriod: 120,
                            notes: "Keep back neutral, engage core"),
                    Exercise(name: "Weighted Pull-ups", sets: 3, reps: "8-12", restPeriod: 90,
                            notes: "Full range of motion"),
                    Exercise(name: "Overhead Press", sets: 3, reps: "8-10", restPeriod: 75,
                            notes: "Maintain core stability"),
                    Exercise(name: "Barbell Rows", sets: 3, reps: "10-12", restPeriod: 60,
                            notes: "Pull to lower chest")
                ],
                reason: "Your recovery score is excellent. You're ready for high-intensity compound movements."
            )
        } else if runningDays < 4 {
            return WorkoutRecommendation(
                type: .running,
                title: "Tempo Run",
                description: "Moderate to high intensity tempo run to build aerobic capacity",
                duration: 3600,
                intensity: .high,
                exercises: [
                    Exercise(name: "Warm-up", sets: 1, reps: "10 min easy", restPeriod: 0,
                            notes: "Build up to tempo pace gradually"),
                    Exercise(name: "Tempo Intervals", sets: 4, reps: "8 min at tempo", restPeriod: 120,
                            notes: "Comfortably hard pace, roughly 80-85% max HR"),
                    Exercise(name: "Cool-down", sets: 1, reps: "10 min easy", restPeriod: 0,
                            notes: "Bring heart rate down gradually")
                ],
                reason: "High recovery allows for quality running. Perfect day for tempo work."
            )
        } else {
            return WorkoutRecommendation(
                type: .strength,
                title: "Upper Body Push/Pull",
                description: "Focused upper body strength session",
                duration: 2700,
                intensity: .high,
                exercises: [
                    Exercise(name: "Incline Dumbbell Press", sets: 4, reps: "10-12", restPeriod: 75),
                    Exercise(name: "Weighted Chin-ups", sets: 4, reps: "8-10", restPeriod: 75),
                    Exercise(name: "Dips", sets: 3, reps: "10-15", restPeriod: 60),
                    Exercise(name: "Cable Rows", sets: 3, reps: "12-15", restPeriod: 60),
                    Exercise(name: "Lateral Raises", sets: 3, reps: "12-15", restPeriod: 45),
                    Exercise(name: "Face Pulls", sets: 3, reps: "15-20", restPeriod: 45)
                ],
                reason: "Great recovery and you've been active this week. Focus on upper body today."
            )
        }
    }

    private func goodRecoveryRecommendation(strengthDays: Int, mobilityDays: Int) -> WorkoutRecommendation {
        if strengthDays == 0 {
            return WorkoutRecommendation(
                type: .strength,
                title: "Lower Body Strength",
                description: "Moderate intensity lower body workout",
                duration: 2700,
                intensity: .moderate,
                exercises: [
                    Exercise(name: "Goblet Squats", sets: 3, reps: "12-15", restPeriod: 60,
                            notes: "Focus on form and depth"),
                    Exercise(name: "Romanian Deadlifts", sets: 3, reps: "10-12", restPeriod: 75,
                            notes: "Feel the hamstring stretch"),
                    Exercise(name: "Walking Lunges", sets: 3, reps: "10 each leg", restPeriod: 60),
                    Exercise(name: "Bulgarian Split Squats", sets: 3, reps: "10 each leg", restPeriod: 60),
                    Exercise(name: "Calf Raises", sets: 3, reps: "15-20", restPeriod: 45),
                    Exercise(name: "Planks", sets: 3, reps: "60 sec", restPeriod: 45,
                            notes: "Maintain neutral spine")
                ],
                reason: "Good recovery allows for strength work. Lower body focus today."
            )
        } else {
            return WorkoutRecommendation(
                type: .mobility,
                title: "Yoga Flow",
                description: "Active recovery with yoga to maintain mobility",
                duration: 2700,
                intensity: .low,
                exercises: [
                    Exercise(name: "Sun Salutations", sets: 1, reps: "5 rounds", restPeriod: 0,
                            notes: "Flow with breath"),
                    Exercise(name: "Warrior Sequence", sets: 1, reps: "3 min each side", restPeriod: 0),
                    Exercise(name: "Pigeon Pose", sets: 2, reps: "2 min each side", restPeriod: 30,
                            notes: "Deep hip stretch"),
                    Exercise(name: "Seated Forward Fold", sets: 1, reps: "3 min", restPeriod: 0),
                    Exercise(name: "Spinal Twists", sets: 2, reps: "1 min each side", restPeriod: 0),
                    Exercise(name: "Savasana", sets: 1, reps: "5 min", restPeriod: 0,
                            notes: "Complete relaxation")
                ],
                reason: "Good recovery but you've been training hard. Active recovery recommended."
            )
        }
    }

    private func moderateRecoveryRecommendation(strengthDays: Int) -> WorkoutRecommendation {
        return WorkoutRecommendation(
            type: .mobility,
            title: "Dynamic Stretching & Light Movement",
            description: "Active recovery focusing on mobility and blood flow",
            duration: 1800,
            intensity: .low,
            exercises: [
                Exercise(name: "Leg Swings", sets: 2, reps: "15 each direction", restPeriod: 0,
                        notes: "Front/back and side-to-side"),
                Exercise(name: "Cat-Cow Stretch", sets: 1, reps: "15 reps", restPeriod: 0,
                        notes: "Slow and controlled"),
                Exercise(name: "World's Greatest Stretch", sets: 2, reps: "5 each side", restPeriod: 30),
                Exercise(name: "Foam Rolling", sets: 1, reps: "10 min", restPeriod: 0,
                        notes: "Focus on tight areas")
            ],
            reason: "Moderate recovery suggests active recovery. Focus on mobility and light movement."
        )
    }

    private func lowRecoveryRecommendation() -> WorkoutRecommendation {
        return WorkoutRecommendation(
            type: .yoga,
            title: "Gentle Yoga & Stretching",
            description: "Restorative practice to aid recovery",
            duration: 1500,
            intensity: .low,
            exercises: [
                Exercise(name: "Child's Pose", sets: 1, reps: "3 min", restPeriod: 0,
                        notes: "Deep breathing, complete relaxation"),
                Exercise(name: "Supine Twist", sets: 2, reps: "2 min each side", restPeriod: 0,
                        notes: "Gentle spinal rotation"),
                Exercise(name: "Legs Up the Wall", sets: 1, reps: "5 min", restPeriod: 0,
                        notes: "Promotes circulation and relaxation"),
                Exercise(name: "Reclined Pigeon", sets: 2, reps: "2 min each side", restPeriod: 0,
                        notes: "Gentle hip opening"),
                Exercise(name: "Savasana", sets: 1, reps: "5 min", restPeriod: 0,
                        notes: "Complete rest and recovery")
            ],
            reason: "Low recovery score. Prioritize gentle movement and restoration."
        )
    }

    private func veryLowRecoveryRecommendation() -> WorkoutRecommendation {
        return WorkoutRecommendation(
            type: .rest,
            title: "Complete Rest Day",
            description: "Your body needs recovery. Take a complete rest day.",
            duration: 0,
            intensity: .low,
            exercises: [
                Exercise(name: "Sleep", sets: 1, reps: "8-9 hours", restPeriod: 0,
                        notes: "Prioritize quality sleep tonight"),
                Exercise(name: "Hydration", sets: 1, reps: "Throughout day", restPeriod: 0,
                        notes: "Drink plenty of water"),
                Exercise(name: "Light Walking (optional)", sets: 1, reps: "10-15 min", restPeriod: 0,
                        notes: "Only if you feel up to it, very easy pace"),
                Exercise(name: "Nutrition", sets: 1, reps: "Balanced meals", restPeriod: 0,
                        notes: "Focus on protein and micronutrients")
            ],
            reason: "Very low recovery score indicates your body needs rest. Avoid training today."
        )
    }
}
