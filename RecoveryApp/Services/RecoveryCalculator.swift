//
//  RecoveryCalculator.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation

class RecoveryCalculator {

    func calculateRecoveryScore(
        currentMetrics: HealthMetrics,
        historicalMetrics: [HealthMetrics],
        injuryImpact: Double = 0
    ) -> RecoveryData {
        let hrvScore = calculateHRVScore(
            current: currentMetrics.hrv,
            historical: historicalMetrics
        )

        let rhrScore = calculateRestingHRScore(
            current: currentMetrics.restingHeartRate,
            historical: historicalMetrics
        )

        let sleepScore = calculateSleepScore(metrics: currentMetrics)

        let trainingLoadScore = calculateTrainingLoadScore(
            currentMetrics: currentMetrics,
            historicalMetrics: historicalMetrics
        )

        // Calculate base score with adjusted weights (screen time removed)
        let baseScore = Int(
            hrvScore * 0.20 +           // HRV is a strong recovery indicator
            rhrScore * 0.25 +           // Resting HR is critical
            sleepScore * 0.25 +         // Sleep quality is essential
            trainingLoadScore * 0.30    // Training load has significant impact
        )

        // Subtract injury impact from overall score
        let overallScore = max(0, baseScore - Int(injuryImpact))

        let category = RecoveryCategory.from(score: overallScore)

        return RecoveryData(
            date: currentMetrics.date,
            hrvScore: hrvScore,
            restingHRScore: rhrScore,
            sleepScore: sleepScore,
            trainingLoadScore: trainingLoadScore,
            overallScore: overallScore,
            category: category,
            metrics: currentMetrics
        )
    }

    private func calculateHRVScore(current: Double?, historical: [HealthMetrics]) -> Double {
        guard let currentHRV = current else { return 50.0 }

        // Use 30 days for better statistical distribution
        let last30Days = historical.suffix(30)
        let hrvValues = last30Days.compactMap { $0.hrv }

        guard hrvValues.count >= 7 else {
            // Not enough data, use deviation from baseline approach
            let baseline = hrvValues.isEmpty ? currentHRV : hrvValues.reduce(0.0, +) / Double(hrvValues.count)
            guard baseline > 0 else { return 50.0 }
            let deviation = ((currentHRV - baseline) / baseline) * 100
            return min(100, max(0, 50 + deviation * 2))
        }

        // Calculate percentile-based score
        let sortedValues = hrvValues.sorted()
        let percentile = calculatePercentile(value: currentHRV, in: sortedValues)

        // Higher HRV = better recovery
        // Very generous scoring curve - harder to score below 50
        let score: Double
        if percentile >= 75 {
            // Top 25% of your values = excellent (88-100)
            score = 88 + (percentile - 75) * 0.48
        } else if percentile >= 55 {
            // Above median (55-75th percentile) = very good (78-88)
            score = 78 + (percentile - 55) * 0.5
        } else if percentile >= 35 {
            // Around median (35-55th percentile) = good (68-78)
            score = 68 + (percentile - 35) * 0.5
        } else if percentile >= 20 {
            // Below median (20-35th percentile) = fair (58-68)
            score = 58 + (percentile - 20) * 0.67
        } else if percentile >= 10 {
            // Lower range (10-20th percentile) = moderate (48-58)
            score = 48 + (percentile - 10) * 1.0
        } else if percentile >= 5 {
            // Bottom 5-10% = low (40-48)
            score = 40 + (percentile - 5) * 1.6
        } else {
            // Bottom 5% = very low (35-40) - requires extreme outlier
            score = 35 + (percentile * 1.0)
        }

        return min(100, max(35, score))
    }

    private func calculateRestingHRScore(current: Int?, historical: [HealthMetrics]) -> Double {
        guard let currentRHR = current else { return 50.0 }

        let last30Days = historical.suffix(30)
        let rhrValues = last30Days.compactMap { $0.restingHeartRate }

        guard rhrValues.count >= 7 else {
            // Not enough data, use deviation from baseline approach
            let baseline = rhrValues.isEmpty ? Double(currentRHR) : Double(rhrValues.reduce(0, +)) / Double(rhrValues.count)
            let deviation = baseline - Double(currentRHR)
            return max(0, min(100, 50 + (deviation * 5)))
        }

        // Calculate percentile-based score (inverted: lower RHR = higher percentile)
        let sortedValues = rhrValues.sorted()
        let inversePercentile = 100 - calculatePercentile(value: currentRHR, in: sortedValues)

        // Lower RHR = better recovery
        // Very generous scoring curve - harder to score below 50
        let score: Double
        if inversePercentile >= 75 {
            // Top 25% (lowest RHR) = excellent (88-100)
            score = 88 + (inversePercentile - 75) * 0.48
        } else if inversePercentile >= 55 {
            // Above median (55-75th percentile) = very good (78-88)
            score = 78 + (inversePercentile - 55) * 0.5
        } else if inversePercentile >= 35 {
            // Around median (35-55th percentile) = good (68-78)
            score = 68 + (inversePercentile - 35) * 0.5
        } else if inversePercentile >= 20 {
            // Below median (20-35th percentile) = fair (58-68)
            score = 58 + (inversePercentile - 20) * 0.67
        } else if inversePercentile >= 10 {
            // Lower range (10-20th percentile) = moderate (48-58)
            score = 48 + (inversePercentile - 10) * 1.0
        } else if inversePercentile >= 5 {
            // Bottom 5-10% (high RHR) = low (40-48)
            score = 40 + (inversePercentile - 5) * 1.6
        } else {
            // Bottom 5% (very high RHR) = very low (35-40) - requires extreme outlier
            score = 35 + (inversePercentile * 1.0)
        }

        return max(35, min(100, score))
    }

    private func calculateSleepScore(metrics: HealthMetrics) -> Double {
        guard let totalSleep = metrics.sleepDuration else { return 50.0 }

        let sleepHours = totalSleep / 3600.0

        // Very generous sleep scoring - harder to score below 50
        let durationScore: Double
        if sleepHours >= 8.0 {
            // Excellent sleep duration (8+ hours) = 92-100
            durationScore = min(100, 92 + (sleepHours - 8.0) * 4)
        } else if sleepHours >= 7.0 {
            // Good sleep duration (7-8 hours) = 82-92
            durationScore = 82 + (sleepHours - 7.0) * 10
        } else if sleepHours >= 6.5 {
            // Adequate sleep (6.5-7 hours) = 72-82
            durationScore = 72 + (sleepHours - 6.5) * 20
        } else if sleepHours >= 6.0 {
            // Decent sleep (6-6.5 hours) = 64-72
            durationScore = 64 + (sleepHours - 6.0) * 16
        } else if sleepHours >= 5.5 {
            // Moderate sleep (5.5-6 hours) = 56-64
            durationScore = 56 + (sleepHours - 5.5) * 16
        } else if sleepHours >= 5.0 {
            // Below average sleep (5-5.5 hours) = 48-56
            durationScore = 48 + (sleepHours - 5.0) * 16
        } else if sleepHours >= 4.0 {
            // Poor sleep (4-5 hours) = 40-48
            durationScore = 40 + (sleepHours - 4.0) * 8
        } else {
            // Extremely poor sleep (<4 hours) = 35-40 - requires extreme sleep deprivation
            durationScore = max(35, 35 + (sleepHours * 1.25))
        }

        var qualityScore = durationScore

        if let deepPct = metrics.deepSleepPercentage,
           let remPct = metrics.remSleepPercentage {

            // Very generous quality scoring
            let deepScore: Double
            if deepPct >= 18.0 {
                deepScore = min(100, 90 + (deepPct - 18.0) * 2)
            } else if deepPct >= 13.0 {
                deepScore = 75 + (deepPct - 13.0) * 3
            } else if deepPct >= 10.0 {
                deepScore = 65 + (deepPct - 10.0) * 3.33
            } else {
                deepScore = max(50, deepPct * 6.5)
            }

            let remScore: Double
            if remPct >= 23.0 {
                remScore = min(100, 90 + (remPct - 23.0) * 2)
            } else if remPct >= 18.0 {
                remScore = 75 + (remPct - 18.0) * 3
            } else if remPct >= 15.0 {
                remScore = 65 + (remPct - 15.0) * 3.33
            } else {
                remScore = max(50, remPct * 4.33)
            }

            qualityScore = durationScore * 0.4 +
                          deepScore * 0.35 +
                          remScore * 0.25
        }

        return max(35, min(100, qualityScore))
    }

    private func calculateTrainingLoadScore(
        currentMetrics: HealthMetrics,
        historicalMetrics: [HealthMetrics]
    ) -> Double {
        let last7Days = Array(historicalMetrics.suffix(7)) + [currentMetrics]
        let last28Days = Array(historicalMetrics.suffix(28)) + [currentMetrics]

        let acuteLoad = calculateTotalTrainingStress(metrics: last7Days)
        let chronicLoad = calculateTotalTrainingStress(metrics: last28Days) / 4.0

        guard chronicLoad > 0 else { return 100.0 }

        let ratio = acuteLoad / chronicLoad

        // RECOVERY SCORE: Training load stays high during normal training
        // Only drops significantly for actual overtraining
        let baseScore: Double
        if ratio < 0.4 {
            // Very low training = excellent recovery but detraining risk (92-100)
            baseScore = min(100, 92 + (0.4 - ratio) * 20)
        } else if ratio <= 0.7 {
            // Light training = excellent recovery (88-92)
            baseScore = 88 + (0.7 - ratio) * 13.3
        } else if ratio <= 1.3 {
            // NORMAL TRAINING ZONE = very good recovery (82-88)
            // Ratio 0.8-1.3 is healthy, balanced training
            baseScore = 82 + (1.3 - ratio) * 10
        } else if ratio <= 1.6 {
            // Slightly elevated = good recovery (70-82)
            baseScore = 70 + (1.6 - ratio) * 40
        } else if ratio <= 2.0 {
            // High load = moderate recovery (55-70)
            // This is where overreaching begins
            baseScore = 55 + (2.0 - ratio) * 37.5
        } else if ratio <= 2.5 {
            // Very high = low recovery (40-55)
            // Clear overtraining signal
            baseScore = 40 + (2.5 - ratio) * 30
        } else {
            // Extreme overtraining (>2.5x) = very low (35-40)
            baseScore = max(35, 40 - (ratio - 2.5) * 10)
        }

        // HR-based fatigue adjustment: check if HR is elevated during recent workouts
        let hrFatigueAdjustment = calculateHRFatigueAdjustment(
            currentMetrics: currentMetrics,
            historicalMetrics: historicalMetrics
        )

        let adjustedScore = baseScore + hrFatigueAdjustment
        return max(35, min(100, adjustedScore))
    }

    private func calculateHRFatigueAdjustment(
        currentMetrics: HealthMetrics,
        historicalMetrics: [HealthMetrics]
    ) -> Double {
        // Look at recent RUNNING workouts to detect if HR is abnormally elevated
        // Only compare running to running for accurate fatigue detection

        let last14Days = Array(historicalMetrics.suffix(14)) + [currentMetrics]
        let allWorkouts = last14Days.flatMap { $0.workouts }

        // Filter for running workouts only
        let runningWorkouts = allWorkouts.filter { $0.type == .running }

        // Need at least 5 running workouts for comparison
        guard runningWorkouts.count >= 5 else { return 0 }

        // Get average HR for the 3 most recent runs vs previous runs
        let sortedByDate = runningWorkouts.sorted { $0.date > $1.date }
        let recent3 = Array(sortedByDate.prefix(3)).compactMap { $0.averageHeartRate }
        let older = Array(sortedByDate.dropFirst(3).prefix(7)).compactMap { $0.averageHeartRate }

        guard recent3.count >= 2, older.count >= 3 else { return 0 }

        let recentAvgHR = Double(recent3.reduce(0, +)) / Double(recent3.count)
        let baselineAvgHR = Double(older.reduce(0, +)) / Double(older.count)

        // If recent running HR is elevated by 3+ bpm, that's a fatigue signal
        let hrDrift = recentAvgHR - baselineAvgHR

        if hrDrift >= 8.0 {
            // Significant HR elevation = -10 points (clear running fatigue)
            return -10
        } else if hrDrift >= 5.0 {
            // Moderate HR elevation = -5 points
            return -5
        } else if hrDrift >= 3.0 {
            // Slight HR elevation = -2 points
            return -2
        } else if hrDrift <= -3.0 {
            // HR improving (becoming more efficient) = +3 bonus
            return 3
        }

        return 0
    }

    private func calculateTotalTrainingStress(metrics: [HealthMetrics]) -> Double {
        var totalStress = 0.0

        for metric in metrics {
            for workout in metric.workouts {
                let stress = calculateWorkoutStress(workout, userRestingHR: metric.restingHeartRate)
                totalStress += stress
            }
        }

        return totalStress
    }

    private func calculateWorkoutStress(_ workout: WorkoutData, userRestingHR: Int?) -> Double {
        guard let avgHR = workout.averageHeartRate else {
            return workout.durationInMinutes * 0.5
        }

        // Use actual resting HR if available, otherwise estimate
        let restingHR = userRestingHR.map(Double.init) ?? 60.0

        // Calculate age-adjusted max HR using Tanaka formula: 208 - (0.7 × age)
        // For safety, use conservative estimate if age unknown
        let estimatedMaxHR = 190.0 // Conservative default
        let maxHR = workout.maxHeartRate.map(Double.init) ?? estimatedMaxHR

        let hrReserve = maxHR - restingHR
        guard hrReserve > 0 else { return workout.durationInMinutes * 0.5 }

        let intensity = (Double(avgHR) - restingHR) / hrReserve

        let stress = workout.durationInMinutes * intensity * intensity * 100

        switch workout.type {
        case .running, .cycling:
            return stress
        case .swimming:
            return stress * 1.1
        case .strength:
            return stress * 0.8
        case .yoga, .mobility:
            return stress * 0.3
        case .walking:
            return stress * 0.4
        case .rest:
            return 0
        case .other:
            return stress * 0.7
        }
    }

    func calculateWeeklyBaseline(historicalData: [RecoveryData]) -> (average: Double, trend: Trend) {
        guard historicalData.count >= 7 else {
            return (average: 50, trend: .stable)
        }

        let last7Days = Array(historicalData.suffix(7))
        let scores = last7Days.map { Double($0.overallScore) }
        let average = scores.reduce(0, +) / Double(scores.count)

        let previous7Days = Array(historicalData.dropLast(7).suffix(7))
        guard !previous7Days.isEmpty else {
            return (average: average, trend: .stable)
        }

        let previousScores = previous7Days.map { Double($0.overallScore) }
        let previousAverage = previousScores.reduce(0, +) / Double(previousScores.count)

        let change = average - previousAverage

        let trend: Trend
        if change > 5 {
            trend = .improving
        } else if change < -5 {
            trend = .declining
        } else {
            trend = .stable
        }

        return (average: average, trend: trend)
    }

    // MARK: - Helper Functions

    private func calculatePercentile<T: Comparable>(value: T, in sortedValues: [T]) -> Double {
        guard !sortedValues.isEmpty else { return 50.0 }

        let count = sortedValues.count
        var valuesBelow = 0

        for sortedValue in sortedValues {
            if sortedValue < value {
                valuesBelow += 1
            } else if sortedValue == value {
                valuesBelow += 1
                break
            } else {
                break
            }
        }

        return (Double(valuesBelow) / Double(count)) * 100.0
    }
}

enum Trend {
    case improving
    case stable
    case declining

    var description: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }
}
