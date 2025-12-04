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
        let originalType: TrainingWorkoutType
        let suggestedType: TrainingWorkoutType
        let reason: String
        let distanceModification: Double?  // Percentage (e.g., 0.8 for 80%)
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
        let previousAverage = scores.prefix(3).reduce(0, +) / 3.0

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

        // Moderate recovery with declining trend
        if score < 70 && trend == .declining {
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
            // Reduce intensity of hardest workout
            if let hardestWorkout = qualityWorkouts.first(where: { $0.type == .interval || $0.type == .repetition }) {
                adjustments.append(WorkoutAdjustment(
                    originalType: hardestWorkout.type,
                    suggestedType: .threshold,
                    reason: "Moderate recovery - convert speed work to tempo",
                    distanceModification: nil
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
                case .threshold:
                    suggestedType = .easy
                    reason = "Low recovery - convert tempo to easy pace"
                case .long:
                    suggestedType = .easy
                    reason = "Low recovery - reduce long run distance"
                default:
                    continue
                }

                adjustments.append(WorkoutAdjustment(
                    originalType: workout.type,
                    suggestedType: suggestedType,
                    reason: reason,
                    distanceModification: workout.type == .long ? 0.7 : nil
                ))
            }

        case .significant:
            // Recommend rest or very easy running only
            for workout in currentWeek.workouts where workout.type != .rest {
                if workout.type.isQuality {
                    adjustments.append(WorkoutAdjustment(
                        originalType: workout.type,
                        suggestedType: .rest,
                        reason: "Very low recovery - prioritize rest",
                        distanceModification: nil
                    ))
                } else if workout.type == .easy {
                    adjustments.append(WorkoutAdjustment(
                        originalType: workout.type,
                        suggestedType: .easy,
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
            return "Recovery score is \(Int(score)) and \(trendText). You're ready for your planned workouts!"

        case .minor:
            return "Recovery score is \(Int(score)) and \(trendText). Consider reducing intensity slightly on quality workouts."

        case .moderate:
            return "Recovery score is \(Int(score)) and \(trendText). Strongly recommend converting quality workouts to easy running this week."

        case .significant:
            return "Recovery score is critically low at \(Int(score)). Prioritize rest and recovery over training this week to prevent injury and burnout."
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
