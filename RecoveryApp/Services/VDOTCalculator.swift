import Foundation

/// VDOT Calculator for training pace recommendations
/// Calculates training paces for different workout types based on VDOT value
class VDOTCalculator {

    // MARK: - VDOT Calculation

    /// Calculate VDOT from race performance
    /// - Parameters:
    ///   - distanceInMeters: Race distance in meters
    ///   - timeInSeconds: Race time in seconds
    /// - Returns: VDOT value (approximate VO2max)
    static func calculateVDOT(distanceInMeters: Double, timeInSeconds: TimeInterval) -> Double {
        let velocityMetersPerMinute = distanceInMeters / (timeInSeconds / 60.0)

        // Oxygen cost calculation
        let percentMax: Double
        if timeInSeconds <= 150 {  // 2.5 minutes or less
            percentMax = 1.0
        } else if timeInSeconds <= 600 {  // 2.5 to 10 minutes
            percentMax = 1.0 - 0.0375 * ((timeInSeconds - 150) / 60.0)
        } else {  // Over 10 minutes
            percentMax = 0.8315 - 0.0039 * ((timeInSeconds - 600) / 60.0)
        }

        let vo2 = -4.60 + 0.182258 * velocityMetersPerMinute + 0.000104 * pow(velocityMetersPerMinute, 2)
        let vdot = vo2 / percentMax

        return max(30, min(85, vdot))  // Clamp between 30 and 85
    }

    // MARK: - Training Pace Calculation

    struct TrainingPaces {
        let easyMinPerMile: String       // Easy/Recovery
        let marathonMinPerMile: String   // Marathon pace
        let thresholdMinPerMile: String  // Tempo/Threshold
        let intervalMinPerMile: String   // VO2max intervals
        let repetitionMinPerMile: String // Speed work
    }

    /// Calculate all training paces based on VDOT
    static func calculateTrainingPaces(vdot: Double) -> TrainingPaces {
        // Each pace is calculated at specific % of VO2max

        // Easy pace: 59-74% VO2max (use average ~65%)
        let easyPaceSecPerMile = velocityToSecondsPerMile(velocityMetersPerMin: velocityAtPercentVO2(vdot: vdot, percent: 0.65))

        // Marathon pace: ~80-85% VO2max (use 82%)
        let marathonPaceSecPerMile = velocityToSecondsPerMile(velocityMetersPerMin: velocityAtPercentVO2(vdot: vdot, percent: 0.82))

        // Threshold pace: ~83-88% VO2max (use 86%)
        let thresholdPaceSecPerMile = velocityToSecondsPerMile(velocityMetersPerMin: velocityAtPercentVO2(vdot: vdot, percent: 0.86))

        // Interval pace: ~95-100% VO2max (use 98%)
        let intervalPaceSecPerMile = velocityToSecondsPerMile(velocityMetersPerMin: velocityAtPercentVO2(vdot: vdot, percent: 0.98))

        // Repetition pace: ~105-120% VO2max (use 110% - faster than VO2max)
        let repetitionPaceSecPerMile = velocityToSecondsPerMile(velocityMetersPerMin: velocityAtPercentVO2(vdot: vdot, percent: 1.10))

        return TrainingPaces(
            easyMinPerMile: formatPace(secondsPerMile: easyPaceSecPerMile),
            marathonMinPerMile: formatPace(secondsPerMile: marathonPaceSecPerMile),
            thresholdMinPerMile: formatPace(secondsPerMile: thresholdPaceSecPerMile),
            intervalMinPerMile: formatPace(secondsPerMile: intervalPaceSecPerMile),
            repetitionMinPerMile: formatPace(secondsPerMile: repetitionPaceSecPerMile)
        )
    }

    /// Calculate training paces based on goal marathon pace
    /// This uses the actual goal pace rather than VDOT-derived pace
    static func calculateTrainingPacesFromGoal(goalMarathonPaceSecPerMile: Double) -> TrainingPaces {
        // Use goal marathon pace as the baseline
        let marathonPaceSecPerMile = goalMarathonPaceSecPerMile

        // Calculate other paces relative to marathon pace
        // Easy: 15-25% slower than marathon (use 20%)
        let easyPaceSecPerMile = marathonPaceSecPerMile * 1.20

        // Threshold: 5-8% faster than marathon (use 6%)
        let thresholdPaceSecPerMile = marathonPaceSecPerMile * 0.94

        // Interval: 12-15% faster than marathon (use 13%)
        let intervalPaceSecPerMile = marathonPaceSecPerMile * 0.87

        // Repetition: 18-22% faster than marathon (use 20%)
        let repetitionPaceSecPerMile = marathonPaceSecPerMile * 0.80

        return TrainingPaces(
            easyMinPerMile: formatPace(secondsPerMile: easyPaceSecPerMile),
            marathonMinPerMile: formatPace(secondsPerMile: marathonPaceSecPerMile),
            thresholdMinPerMile: formatPace(secondsPerMile: thresholdPaceSecPerMile),
            intervalMinPerMile: formatPace(secondsPerMile: intervalPaceSecPerMile),
            repetitionMinPerMile: formatPace(secondsPerMile: repetitionPaceSecPerMile)
        )
    }

    /// Get pace for specific workout type
    static func paceForWorkoutType(_ type: TrainingWorkoutType, vdot: Double) -> String {
        let paces = calculateTrainingPaces(vdot: vdot)

        switch type {
        case .easy, .long:
            return paces.easyMinPerMile
        case .marathon, .racePace:
            return paces.marathonMinPerMile
        case .threshold:
            return paces.thresholdMinPerMile
        case .interval:
            return paces.intervalMinPerMile
        case .repetition:
            return paces.repetitionMinPerMile
        case .hill:
            // Hill repeats: run by effort, roughly R pace equivalent
            return paces.repetitionMinPerMile
        case .rest:
            return "–"
        }
    }

    /// Get pace for specific workout type based on goal marathon pace
    static func paceForWorkoutType(_ type: TrainingWorkoutType, goalMarathonPaceSecPerMile: Double) -> String {
        let paces = calculateTrainingPacesFromGoal(goalMarathonPaceSecPerMile: goalMarathonPaceSecPerMile)

        switch type {
        case .easy, .long:
            return paces.easyMinPerMile
        case .marathon, .racePace:
            return paces.marathonMinPerMile
        case .threshold:
            return paces.thresholdMinPerMile
        case .interval:
            return paces.intervalMinPerMile
        case .repetition:
            return paces.repetitionMinPerMile
        case .hill:
            // Hill repeats: run by effort, roughly R pace equivalent
            return paces.repetitionMinPerMile
        case .rest:
            return "–"
        }
    }

    // MARK: - Helper Methods

    /// Calculate velocity (meters/min) at a given percentage of VO2max
    /// Based on inverse of VO2 calculation
    private static func velocityAtPercentVO2(vdot: Double, percent: Double) -> Double {
        let targetVO2 = vdot * percent

        // Solve for velocity using quadratic formula from:
        // VO2 = -4.60 + 0.182258v + 0.000104v²
        // Rearranged: 0.000104v² + 0.182258v + (-4.60 - VO2) = 0

        let a = 0.000104
        let b = 0.182258
        let c = -4.60 - targetVO2

        let discriminant = b * b - 4 * a * c
        let velocity = (-b + sqrt(discriminant)) / (2 * a)

        return max(0, velocity)
    }

    /// Convert velocity (meters/min) to pace (seconds/mile)
    private static func velocityToSecondsPerMile(velocityMetersPerMin: Double) -> Double {
        let metersPerMile = 1609.34
        let minutesPerMile = metersPerMile / velocityMetersPerMin
        return minutesPerMile * 60.0  // Convert to seconds
    }

    private static func formatPace(secondsPerMile: Double) -> String {
        let minutes = Int(secondsPerMile / 60)
        let seconds = Int(secondsPerMile.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format time in seconds to HH:MM:SS or MM:SS
    static func formatTime(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    /// Parse time string (HH:MM:SS or MM:SS) to seconds
    static func parseTime(_ timeString: String) -> TimeInterval? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }

        switch components.count {
        case 2:  // MM:SS
            return TimeInterval(components[0] * 60 + components[1])
        case 3:  // HH:MM:SS
            return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        default:
            return nil
        }
    }
}
