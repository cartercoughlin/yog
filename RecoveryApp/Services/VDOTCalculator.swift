import Foundation

/// VDOT Calculator based on Jack Daniels' Running Formula
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

        // Oxygen cost calculation (simplified Jack Daniels formula)
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
        // Simplified pace calculations based on VDOT tables
        // These are approximations of Jack Daniels' tables

        let marathonPaceSecPerMile = vdotToMarathonPace(vdot: vdot)
        let thresholdPaceSecPerMile = marathonPaceSecPerMile * 0.90  // ~10% faster than marathon
        let intervalPaceSecPerMile = marathonPaceSecPerMile * 0.82   // ~18% faster than marathon
        let repetitionPaceSecPerMile = marathonPaceSecPerMile * 0.75 // ~25% faster than marathon
        let easyPaceSecPerMile = marathonPaceSecPerMile * 1.25        // ~25% slower than marathon

        return TrainingPaces(
            easyMinPerMile: formatPace(secondsPerMile: easyPaceSecPerMile),
            marathonMinPerMile: formatPace(secondsPerMile: marathonPaceSecPerMile),
            thresholdMinPerMile: formatPace(secondsPerMile: thresholdPaceSecPerMile),
            intervalMinPerMile: formatPace(secondsPerMile: intervalPaceSecPerMile),
            repetitionMinPerMile: formatPace(secondsPerMile: repetitionPaceSecPerMile)
        )
    }

    /// Get pace for specific workout type
    static func paceForWorkoutType(_ type: WorkoutType, vdot: Double) -> String {
        let paces = calculateTrainingPaces(vdot: vdot)

        switch type {
        case .easy, .long:
            return paces.easyMinPerMile
        case .marathon:
            return paces.marathonMinPerMile
        case .threshold:
            return paces.thresholdMinPerMile
        case .interval:
            return paces.intervalMinPerMile
        case .repetition:
            return paces.repetitionMinPerMile
        case .rest:
            return "–"
        }
    }

    // MARK: - Helper Methods

    private static func vdotToMarathonPace(vdot: Double) -> Double {
        // Simplified conversion from VDOT to marathon pace (seconds per mile)
        // Based on approximation of Jack Daniels' tables
        let baseSeconds = 1800.0  // 30:00 per mile baseline
        let improvement = (vdot - 30.0) * 20.0  // ~20 seconds improvement per VDOT point
        return max(300, baseSeconds - improvement)  // Min 5:00/mile
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
