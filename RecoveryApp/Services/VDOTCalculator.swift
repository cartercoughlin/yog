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
        let racePaceMinPerMile: String   // Race pace (5K/10K/HM/Marathon)
        let thresholdMinPerMile: String  // Tempo/Threshold
        let intervalMinPerMile: String   // VO2max intervals
        let repetitionMinPerMile: String // Speed work
        let raceDistance: RaceDistance?  // Store race distance for display purposes

        // Convenience computed property for backward compatibility
        var marathonMinPerMile: String { racePaceMinPerMile }
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
            racePaceMinPerMile: formatPace(secondsPerMile: marathonPaceSecPerMile),
            thresholdMinPerMile: formatPace(secondsPerMile: thresholdPaceSecPerMile),
            intervalMinPerMile: formatPace(secondsPerMile: intervalPaceSecPerMile),
            repetitionMinPerMile: formatPace(secondsPerMile: repetitionPaceSecPerMile),
            raceDistance: nil
        )
    }

    /// Calculate training paces based on goal race pace and distance
    /// This uses the actual goal pace rather than VDOT-derived pace
    static func calculateTrainingPacesFromGoal(goalRacePaceSecPerMile: Double, raceDistance: RaceDistance) -> TrainingPaces {
        // Use goal race pace as the baseline
        let racePaceSecPerMile = goalRacePaceSecPerMile

        // Calculate marathon-equivalent pace for relative calculations
        // For shorter distances, we need to adjust since race pace is faster
        let marathonEquivalentPace: Double
        switch raceDistance {
        case .fiveK:
            // 5K pace is ~15-20% faster than marathon pace
            marathonEquivalentPace = racePaceSecPerMile * 1.18
        case .tenK:
            // 10K pace is ~10-12% faster than marathon pace
            marathonEquivalentPace = racePaceSecPerMile * 1.11
        case .halfMarathon:
            // Half marathon pace is ~3-5% faster than marathon pace
            marathonEquivalentPace = racePaceSecPerMile * 1.04
        case .marathon:
            marathonEquivalentPace = racePaceSecPerMile
        }

        // Calculate easy pace - based on marathon-equivalent pace for consistency
        // Easy pace should be the same regardless of race distance, as it's based on
        // aerobic capacity and heart rate zones, not race-specific pace
        // We use marathon-equivalent pace as the baseline since it represents
        // sustainable aerobic effort
        let easyPaceSecPerMile = marathonEquivalentPace * 1.30  // 30% slower than marathon pace

        // Threshold, Interval, and Repetition paces depend on race distance
        let thresholdPaceSecPerMile: Double
        let intervalPaceSecPerMile: Double
        let repetitionPaceSecPerMile: Double

        switch raceDistance {
        case .fiveK:
            // For 5K: race pace is between Threshold and Interval
            // So Threshold is slightly slower than race, Interval is race pace, Rep is faster
            thresholdPaceSecPerMile = racePaceSecPerMile * 1.03  // ~3% slower than 5K pace
            intervalPaceSecPerMile = racePaceSecPerMile  // 5K pace IS interval pace
            repetitionPaceSecPerMile = racePaceSecPerMile * 0.95  // ~5% faster than 5K pace

        case .tenK:
            // For 10K: race pace is between Threshold and Interval
            // Threshold is slightly slower, Interval is slightly faster
            thresholdPaceSecPerMile = racePaceSecPerMile * 1.04  // ~4% slower than 10K pace
            intervalPaceSecPerMile = racePaceSecPerMile * 0.98  // ~2% faster than 10K pace
            repetitionPaceSecPerMile = racePaceSecPerMile * 0.92  // ~8% faster than 10K pace

        case .halfMarathon:
            // For Half Marathon: race pace is very close to Threshold
            thresholdPaceSecPerMile = racePaceSecPerMile * 1.02  // ~2% slower than HM pace
            intervalPaceSecPerMile = racePaceSecPerMile * 0.95  // ~5% faster than HM pace
            repetitionPaceSecPerMile = racePaceSecPerMile * 0.88  // ~12% faster than HM pace

        case .marathon:
            // For Marathon: use standard marathon-based calculations
            thresholdPaceSecPerMile = marathonEquivalentPace * 0.94  // ~6% faster than M pace
            intervalPaceSecPerMile = marathonEquivalentPace * 0.87  // ~13% faster than M pace
            repetitionPaceSecPerMile = marathonEquivalentPace * 0.80  // ~20% faster than M pace
        }

        return TrainingPaces(
            easyMinPerMile: formatPace(secondsPerMile: easyPaceSecPerMile),
            racePaceMinPerMile: formatPace(secondsPerMile: racePaceSecPerMile),
            thresholdMinPerMile: formatPace(secondsPerMile: thresholdPaceSecPerMile),
            intervalMinPerMile: formatPace(secondsPerMile: intervalPaceSecPerMile),
            repetitionMinPerMile: formatPace(secondsPerMile: repetitionPaceSecPerMile),
            raceDistance: raceDistance
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

    /// Get pace for specific workout type based on goal race pace and distance
    static func paceForWorkoutType(_ type: TrainingWorkoutType, goalRacePaceSecPerMile: Double, raceDistance: RaceDistance) -> String {
        let paces = calculateTrainingPacesFromGoal(goalRacePaceSecPerMile: goalRacePaceSecPerMile, raceDistance: raceDistance)

        switch type {
        case .easy, .long:
            return paces.easyMinPerMile
        case .marathon, .racePace:
            return paces.racePaceMinPerMile
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

    // MARK: - Interval Rep Time Calculations

    /// Common interval distances in meters
    enum IntervalDistance: String, CaseIterable {
        case fourHundred = "400m"
        case sixHundred = "600m"
        case eightHundred = "800m"
        case oneK = "1k"
        case oneKm = "1km"
        case twelvehundred = "1200m"
        case oneMile = "mile"

        var meters: Double {
            switch self {
            case .fourHundred: return 400
            case .sixHundred: return 600
            case .eightHundred: return 800
            case .oneK, .oneKm: return 1000
            case .twelvehundred: return 1200
            case .oneMile: return 1609.34
            }
        }

        var displayName: String {
            switch self {
            case .fourHundred: return "400m"
            case .sixHundred: return "600m"
            case .eightHundred: return "800m"
            case .oneK, .oneKm: return "1k"
            case .twelvehundred: return "1200m"
            case .oneMile: return "mile"
            }
        }
    }

    /// Calculate rep time for a specific distance given pace per mile
    /// - Parameters:
    ///   - paceMinPerMile: Pace string in format "X:XX" (min:sec per mile)
    ///   - distanceMeters: Distance of the rep in meters
    /// - Returns: Formatted time string for the rep (e.g., "3:45" for a 1k)
    static func repTimeForDistance(paceMinPerMile: String, distanceMeters: Double) -> String {
        guard let paceSeconds = parseTime(paceMinPerMile) else { return "--:--" }

        let metersPerMile = 1609.34
        let paceSecondsPerMeter = paceSeconds / metersPerMile
        let repTimeSeconds = paceSecondsPerMeter * distanceMeters

        return formatTime(seconds: repTimeSeconds)
    }

    /// Detect interval distance from workout description
    /// - Parameter description: Workout description (e.g., "6x1k at I pace", "8x400m repeats")
    /// - Returns: The detected interval distance, or nil if not found
    static func detectIntervalDistance(from description: String) -> IntervalDistance? {
        let lowercased = description.lowercased()

        // Check for each interval distance pattern
        // Order matters - check longer patterns first to avoid partial matches
        if lowercased.contains("1200m") || lowercased.contains("1200") {
            return .twelvehundred
        }
        if lowercased.contains("1km") {
            return .oneKm
        }
        if lowercased.contains("1k") {
            return .oneK
        }
        if lowercased.contains("800m") || lowercased.contains("800") {
            return .eightHundred
        }
        if lowercased.contains("600m") || lowercased.contains("600") {
            return .sixHundred
        }
        if lowercased.contains("400m") || lowercased.contains("400") {
            return .fourHundred
        }
        if lowercased.contains("mile") && (lowercased.contains("repeat") || lowercased.contains("x")) {
            return .oneMile
        }

        return nil
    }

    /// Get formatted rep time display for an interval workout
    /// - Parameters:
    ///   - workoutType: The training workout type
    ///   - description: Workout description to detect interval distance
    ///   - goalRacePaceSecPerMile: Goal race pace in seconds per mile
    ///   - raceDistance: Target race distance
    /// - Returns: A tuple with (repTime, distanceLabel) or nil if not an interval workout
    static func intervalRepTimeDisplay(
        workoutType: TrainingWorkoutType,
        description: String,
        goalRacePaceSecPerMile: Double,
        raceDistance: RaceDistance
    ) -> (repTime: String, distanceLabel: String)? {
        // Only show rep times for interval and repetition workouts
        guard workoutType == .interval || workoutType == .repetition else { return nil }

        // Detect the interval distance from description
        guard let intervalDistance = detectIntervalDistance(from: description) else { return nil }

        // Get the pace for this workout type
        let pace = paceForWorkoutType(workoutType, goalRacePaceSecPerMile: goalRacePaceSecPerMile, raceDistance: raceDistance)

        // Calculate rep time
        let repTime = repTimeForDistance(paceMinPerMile: pace, distanceMeters: intervalDistance.meters)

        return (repTime: repTime, distanceLabel: intervalDistance.displayName)
    }
}
