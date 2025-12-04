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
        historicalMetrics: [HealthMetrics]
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

        let screenTimeScore = calculateScreenTimeScore(
            current: currentMetrics.screenTimeHours,
            historical: historicalMetrics
        )

        // Adjusted weights to include screen time
        let overallScore = Int(
            hrvScore * 0.18 +           // HRV is a strong recovery indicator
            rhrScore * 0.22 +           // Resting HR is critical
            sleepScore * 0.22 +         // Sleep quality is essential
            trainingLoadScore * 0.28 +  // Training load has significant impact
            screenTimeScore * 0.10      // Screen time affects mental recovery
        )

        let category = RecoveryCategory.from(score: overallScore)

        return RecoveryData(
            date: currentMetrics.date,
            hrvScore: hrvScore,
            restingHRScore: rhrScore,
            sleepScore: sleepScore,
            trainingLoadScore: trainingLoadScore,
            screenTimeScore: screenTimeScore,
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
        // More generous scoring curve - being at/near median should score 70+
        let score: Double
        if percentile >= 80 {
            // Top 20% of your values = excellent (85-100)
            score = 85 + (percentile - 80) * 0.75
        } else if percentile >= 60 {
            // Above median (60-80th percentile) = good (75-85)
            score = 75 + (percentile - 60) * 0.5
        } else if percentile >= 40 {
            // Near median (40-60th percentile) = fair (65-75)
            score = 65 + (percentile - 40) * 0.5
        } else if percentile >= 20 {
            // Below median (20-40th percentile) = moderate (50-65)
            score = 50 + (percentile - 20) * 0.75
        } else {
            // Bottom 20% = low (0-50)
            score = percentile * 2.5
        }

        return min(100, max(0, score))
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
        // More generous scoring curve - being at/near median should score 70+
        let score: Double
        if inversePercentile >= 80 {
            // Top 20% (lowest RHR) = excellent (85-100)
            score = 85 + (inversePercentile - 80) * 0.75
        } else if inversePercentile >= 60 {
            // Above median (60-80th percentile) = good (75-85)
            score = 75 + (inversePercentile - 60) * 0.5
        } else if inversePercentile >= 40 {
            // Near median (40-60th percentile) = fair (65-75)
            score = 65 + (inversePercentile - 40) * 0.5
        } else if inversePercentile >= 20 {
            // Below median (20-40th percentile) = moderate (50-65)
            score = 50 + (inversePercentile - 20) * 0.75
        } else {
            // Bottom 20% (highest RHR) = low (0-50)
            score = inversePercentile * 2.5
        }

        return max(0, min(100, score))
    }

    private func calculateSleepScore(metrics: HealthMetrics) -> Double {
        guard let totalSleep = metrics.sleepDuration else { return 50.0 }

        let sleepHours = totalSleep / 3600.0

        // More generous sleep scoring - recognize excellent sleep
        let durationScore: Double
        if sleepHours >= 8.0 {
            // Excellent sleep duration (8+ hours) = 90-100
            durationScore = min(100, 90 + (sleepHours - 8.0) * 5)
        } else if sleepHours >= 7.0 {
            // Good sleep duration (7-8 hours) = 75-90
            durationScore = 75 + (sleepHours - 7.0) * 15
        } else if sleepHours >= 6.0 {
            // Adequate sleep (6-7 hours) = 55-75
            durationScore = 55 + (sleepHours - 6.0) * 20
        } else if sleepHours >= 5.0 {
            // Poor sleep (5-6 hours) = 35-55
            durationScore = 35 + (sleepHours - 5.0) * 20
        } else {
            // Very poor sleep (<5 hours) = 0-35
            durationScore = sleepHours * 7
        }

        var qualityScore = durationScore

        if let deepPct = metrics.deepSleepPercentage,
           let remPct = metrics.remSleepPercentage {

            // More generous quality scoring
            let deepScore: Double
            if deepPct >= 18.0 {
                deepScore = min(100, 85 + (deepPct - 18.0) * 3)
            } else if deepPct >= 13.0 {
                deepScore = 60 + (deepPct - 13.0) * 5
            } else {
                deepScore = deepPct * 4.6
            }

            let remScore: Double
            if remPct >= 20.0 {
                remScore = min(100, 85 + (remPct - 20.0) * 3)
            } else if remPct >= 15.0 {
                remScore = 60 + (remPct - 15.0) * 5
            } else {
                remScore = remPct * 4
            }

            qualityScore = durationScore * 0.4 +
                          deepScore * 0.35 +
                          remScore * 0.25
        }

        return max(0, min(100, qualityScore))
    }

    private func calculateScreenTimeScore(current: Double?, historical: [HealthMetrics]) -> Double {
        guard let currentScreenTime = current else { return 50.0 }

        let last30Days = historical.suffix(30)
        let screenTimeValues = last30Days.compactMap { $0.screenTimeHours }

        guard screenTimeValues.count >= 7 else {
            // Not enough data, use baseline approach
            // Lower screen time = better score (inverse relationship)
            // Optimal: <2 hours = 90-100, 2-3 hours = 75-90, 3-4 hours = 60-75, >4 hours = <60
            if currentScreenTime < 2.0 {
                return min(100, 90 + (2.0 - currentScreenTime) * 5)
            } else if currentScreenTime < 3.0 {
                return 75 + (3.0 - currentScreenTime) * 15
            } else if currentScreenTime < 4.0 {
                return 60 + (4.0 - currentScreenTime) * 15
            } else if currentScreenTime < 6.0 {
                return 40 + (6.0 - currentScreenTime) * 10
            } else {
                return max(0, 40 - (currentScreenTime - 6.0) * 5)
            }
        }

        // Calculate percentile-based score (inverted: lower screen time = higher percentile)
        let sortedValues = screenTimeValues.sorted()
        let inversePercentile = 100 - calculatePercentile(value: currentScreenTime, in: sortedValues)

        // Lower screen time = better recovery (similar to resting HR)
        let score: Double
        if inversePercentile >= 80 {
            // Top 20% (lowest screen time) = excellent (85-100)
            score = 85 + (inversePercentile - 80) * 0.75
        } else if inversePercentile >= 60 {
            // Above median (60-80th percentile) = good (75-85)
            score = 75 + (inversePercentile - 60) * 0.5
        } else if inversePercentile >= 40 {
            // Near median (40-60th percentile) = fair (65-75)
            score = 65 + (inversePercentile - 40) * 0.5
        } else if inversePercentile >= 20 {
            // Below median (20-40th percentile) = moderate (50-65)
            score = 50 + (inversePercentile - 20) * 0.75
        } else {
            // Bottom 20% (highest screen time) = low (0-50)
            score = inversePercentile * 2.5
        }

        return max(0, min(100, score))
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

        // RECOVERY SCORE: Lower training load = better recovery (inverse relationship)
        let score: Double
        if ratio < 0.3 {
            // Very low recent training = excellent recovery (95-100)
            score = min(100, 95 + (0.3 - ratio) * 16.7)
        } else if ratio < 0.6 {
            // Low training = very good recovery (85-95)
            score = 85 + (0.6 - ratio) * 33.3
        } else if ratio <= 1.0 {
            // Moderate balanced training = good recovery (70-85)
            score = 70 + (1.0 - ratio) * 37.5
        } else if ratio <= 1.3 {
            // Slightly elevated training = moderate recovery (55-70)
            score = 55 + (1.3 - ratio) * 50
        } else if ratio <= 1.6 {
            // High training = low recovery (40-55)
            score = 40 + (1.6 - ratio) * 50
        } else if ratio <= 2.0 {
            // Very high training = very low recovery (25-40)
            score = 25 + (2.0 - ratio) * 37.5
        } else {
            // Extreme overreaching = minimal recovery (0-25)
            score = max(0, 25 - (ratio - 2.0) * 10)
        }

        return score
    }

    private func calculateTotalTrainingStress(metrics: [HealthMetrics]) -> Double {
        var totalStress = 0.0

        for metric in metrics {
            for workout in metric.workouts {
                let stress = calculateWorkoutStress(workout)
                totalStress += stress
            }
        }

        return totalStress
    }

    private func calculateWorkoutStress(_ workout: WorkoutData) -> Double {
        guard let avgHR = workout.averageHeartRate else {
            return workout.durationInMinutes * 0.5
        }

        let restingHR = 60.0
        let maxHR = 190.0
        let hrReserve = maxHR - restingHR
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
