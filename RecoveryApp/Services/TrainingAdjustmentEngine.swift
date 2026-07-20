import Foundation

/// Engine for suggesting training plan adjustments based on recovery scores
/// This provides the infrastructure for adaptive training based on physiological readiness
class TrainingAdjustmentEngine {

    // MARK: - Adjustment Recommendations

    struct AdjustmentRecommendation {
        let shouldAdjust: Bool
        let severity: AdjustmentSeverity
        let message: String
        let suggestedWorkoutChanges: [WorkoutAdjustment]
    }

    enum AdjustmentSeverity {
        case none
        case minor
        case moderate
        case significant

        var color: String {
            switch self {
            case .none: return "green"
            case .minor: return "yellow"
            case .moderate: return "orange"
            case .significant: return "red"
            }
        }
    }

    enum Trend {
        case improving
        case stable
        case declining
    }

    struct WorkoutAdjustment {
        let workoutID: UUID
        let originalType: TrainingWorkoutType
        let suggestedType: TrainingWorkoutType
        let title: String
        let reason: String
        let distanceModification: Double?  // Percentage (e.g., 0.8 for 80%)

        func suggestedDistance(for workout: DailyWorkout) -> Double? {
            guard let distance = workout.distanceInMiles else { return nil }
            return distanceModification.map { distance * $0 } ?? distance
        }
    }

    // MARK: - Recovery Score Analysis

    /// Analyzes recovery score and provides training adjustment recommendations
    /// - Parameters:
    ///   - recoveryScore: Current recovery score (0-100)
    ///   - currentWeek: The week to analyze for adjustments
    ///   - historicalScores: Optional array of recent recovery scores for trend analysis
    /// - Returns: Adjustment recommendation
    static func analyzeRecoveryForAdjustments(
        recoveryScore: Double,
        currentWeek: WeeklyPlan,
        historicalScores: [Double] = []
    ) -> AdjustmentRecommendation {

        // Calculate trend if we have historical data
        let trend = calculateTrend(scores: historicalScores)

        // Determine severity based on score and trend
        let severity = determineSeverity(score: recoveryScore, trend: trend)

        // Generate specific workout adjustments
        let adjustments = generateWorkoutAdjustments(
            severity: severity,
            currentWeek: currentWeek,
            recoveryScore: recoveryScore
        )

        // Create recommendation message
        let message = createRecommendationMessage(
            severity: severity,
            score: recoveryScore,
            trend: trend
        )

        return AdjustmentRecommendation(
            shouldAdjust: !adjustments.isEmpty,
            severity: severity,
            message: message,
            suggestedWorkoutChanges: adjustments
        )
    }

    // MARK: - Helper Methods

    private static func calculateTrend(scores: [Double]) -> Trend {
        guard scores.count >= 3 else { return .stable }

        let recentAverage = scores.suffix(3).reduce(0, +) / 3.0
        let previousWindow = scores.dropLast(3).suffix(3)
        guard previousWindow.count == 3 else { return .stable }
        let previousAverage = previousWindow.reduce(0, +) / 3.0

        let difference = recentAverage - previousAverage

        if difference > 5 {
            return .improving
        } else if difference < -5 {
            return .declining
        } else {
            return .stable
        }
    }

    private static func determineSeverity(score: Double, trend: Trend) -> AdjustmentSeverity {
        // Very low recovery scores
        if score < 40 {
            return .significant
        }

        // Low recovery scores
        if score < 55 {
            return .moderate
        }

        // Readiness below 70 should produce a concrete, conservative option.
        if score < 70 {
            return .minor
        }

        if score < 80 && trend == .declining {
            return .minor
        }

        // Good recovery
        return .none
    }

    private static func generateWorkoutAdjustments(
        severity: AdjustmentSeverity,
        currentWeek: WeeklyPlan,
        recoveryScore: Double
    ) -> [WorkoutAdjustment] {
        var adjustments: [WorkoutAdjustment] = []

        let qualityWorkouts = currentWeek.workouts.filter { $0.type.isQuality }

        switch severity {
        case .none:
            // No adjustments needed
            break

        case .minor:
            for workout in qualityWorkouts {
                let suggestedType: TrainingWorkoutType
                let title: String
                let reason: String
                let distanceModification: Double

                switch workout.type {
                case .interval, .repetition:
                    suggestedType = .threshold
                    title = "Swap speed for threshold"
                    reason = "Keep an aerobic quality stimulus without the full VO2 or repetition load."
                    distanceModification = 0.80
                case .threshold, .marathon, .racePace:
                    suggestedType = workout.type
                    title = "Shorten the pace work"
                    reason = "Keep the planned pace, but stop while the effort is still controlled."
                    distanceModification = 0.75
                case .long:
                    suggestedType = .long
                    title = "Shorten the long run"
                    reason = "Run conversationally and remove any fast finish or pace segment."
                    distanceModification = 0.85
                default:
                    continue
                }

                adjustments.append(WorkoutAdjustment(
                    workoutID: workout.id,
                    originalType: workout.type,
                    suggestedType: suggestedType,
                    title: title,
                    reason: reason,
                    distanceModification: distanceModification
                ))
            }

        case .moderate:
            // Convert quality workouts to easier alternatives
            for workout in qualityWorkouts {
                let suggestedType: TrainingWorkoutType
                let reason: String

                switch workout.type {
                case .interval, .repetition:
                    suggestedType = .easy
                    reason = "Low recovery - replace intensity with easy running"
                case .threshold, .marathon, .racePace:
                    suggestedType = .easy
                    reason = "Low recovery - convert pace work to easy running"
                case .long:
                    suggestedType = .easy
                    reason = "Low recovery - reduce long run distance"
                default:
                    continue
                }

                adjustments.append(WorkoutAdjustment(
                    workoutID: workout.id,
                    originalType: workout.type,
                    suggestedType: suggestedType,
                    title: workout.type == .long ? "Run shorter and easy" : "Replace with easy running",
                    reason: reason,
                    distanceModification: 0.7
                ))
            }

        case .significant:
            // Recommend rest or very easy running only
            for workout in currentWeek.workouts where workout.type != .rest {
                if workout.type.isQuality {
                    adjustments.append(WorkoutAdjustment(
                        workoutID: workout.id,
                        originalType: workout.type,
                        suggestedType: .rest,
                        title: "Take a rest day",
                        reason: "Very low recovery - prioritize rest",
                        distanceModification: nil
                    ))
                } else if workout.type == .easy {
                    adjustments.append(WorkoutAdjustment(
                        workoutID: workout.id,
                        originalType: workout.type,
                        suggestedType: .easy,
                        title: "Cut the easy run in half",
                        reason: "Very low recovery - reduce volume significantly",
                        distanceModification: 0.5
                    ))
                }
            }
        }

        return adjustments
    }

    private static func createRecommendationMessage(
        severity: AdjustmentSeverity,
        score: Double,
        trend: Trend
    ) -> String {
        let trendText: String
        switch trend {
        case .improving: trendText = "improving"
        case .declining: trendText = "declining"
        case .stable: trendText = "stable"
        }

        switch severity {
        case .none:
            return "Readiness \(Int(score)), trend \(trendText): keep today's session as planned."

        case .minor:
            return "Readiness \(Int(score)), trend \(trendText): use the lower-load option if the warm-up feels harder than normal."

        case .moderate:
            return "Readiness \(Int(score)), trend \(trendText): replace today's quality work with easy running."

        case .significant:
            return "Readiness \(Int(score)): skip today's quality load and reassess tomorrow."
        }
    }

    // MARK: - Integration Points for Future Implementation

    /// Placeholder for automated adjustment application
    /// Future implementation: automatically modify training plan based on recovery
    static func applyAutomaticAdjustments(
        plan: TrainingPlan,
        recommendation: AdjustmentRecommendation
    ) -> TrainingPlan {
        // TODO: Implement automatic plan modification
        // This would create a new TrainingPlan with adjusted workouts
        // For now, return the original plan
        return plan
    }

    /// Placeholder for tracking adjustment history
    /// Future implementation: track which adjustments were made and their effectiveness
    static func recordAdjustment(
        date: Date,
        originalWorkout: DailyWorkout,
        adjustedWorkout: DailyWorkout,
        recoveryScore: Double
    ) {
        // TODO: Implement adjustment tracking
        // This would store adjustments for later analysis
        print("Recorded adjustment: \(originalWorkout.type) -> \(adjustedWorkout.type) (Recovery: \(recoveryScore))")
    }

    /// Placeholder for machine learning-based personalization
    /// Future implementation: learn from user's response to different recovery scores
    static func personalizeThresholds(userId: String) -> (low: Double, moderate: Double, high: Double) {
        // TODO: Implement personalized thresholds based on user history
        // For now, return default thresholds
        return (low: 55, moderate: 70, high: 80)
    }
}
