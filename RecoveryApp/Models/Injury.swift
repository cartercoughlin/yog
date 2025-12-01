import Foundation
import SwiftUI

// MARK: - Body Region
enum BodyRegion: String, CaseIterable, Codable {
    // Lower Body
    case leftFoot = "Left Foot"
    case rightFoot = "Right Foot"
    case leftAnkle = "Left Ankle"
    case rightAnkle = "Right Ankle"
    case leftCalf = "Left Calf"
    case rightCalf = "Right Calf"
    case leftShin = "Left Shin"
    case rightShin = "Right Shin"
    case leftKnee = "Left Knee"
    case rightKnee = "Right Knee"
    case leftQuad = "Left Quad"
    case rightQuad = "Right Quad"
    case leftHamstring = "Left Hamstring"
    case rightHamstring = "Right Hamstring"
    case leftGlute = "Left Glute"
    case rightGlute = "Right Glute"
    case leftHip = "Left Hip"
    case rightHip = "Right Hip"

    // Core & Back
    case lowerBack = "Lower Back"
    case upperBack = "Upper Back"
    case core = "Core/Abs"

    // Upper Body
    case leftShoulder = "Left Shoulder"
    case rightShoulder = "Right Shoulder"
    case neck = "Neck"

    var category: BodyCategory {
        switch self {
        case .leftFoot, .rightFoot, .leftAnkle, .rightAnkle:
            return .foot
        case .leftCalf, .rightCalf, .leftShin, .rightShin:
            return .lowerLeg
        case .leftKnee, .rightKnee:
            return .knee
        case .leftQuad, .rightQuad, .leftHamstring, .rightHamstring:
            return .thigh
        case .leftGlute, .rightGlute, .leftHip, .rightHip:
            return .hipGlute
        case .lowerBack, .upperBack, .core:
            return .backCore
        case .leftShoulder, .rightShoulder, .neck:
            return .upperBody
        }
    }
}

enum BodyCategory {
    case foot, lowerLeg, knee, thigh, hipGlute, backCore, upperBody
}

// MARK: - Injury Severity
enum InjurySeverity: String, CaseIterable, Codable {
    case minor = "Minor"
    case moderate = "Moderate"
    case severe = "Severe"

    var color: Color {
        switch self {
        case .minor: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        }
    }

    var icon: String {
        switch self {
        case .minor: return "exclamationmark.circle"
        case .moderate: return "exclamationmark.triangle"
        case .severe: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Exercise Type
enum ExerciseType: String, CaseIterable, Codable {
    case stretch = "Stretch"
    case foamRolling = "Foam Rolling"
    case strengthening = "Strengthening"
    case resistanceBand = "Resistance Band"
    case mobilityDrill = "Mobility Drill"

    var icon: String {
        switch self {
        case .stretch: return "figure.flexibility"
        case .foamRolling: return "cylinder"
        case .strengthening: return "dumbbell"
        case .resistanceBand: return "figure.strengthtraining.traditional"
        case .mobilityDrill: return "figure.cooldown"
        }
    }

    var color: Color {
        switch self {
        case .stretch: return .blue
        case .foamRolling: return .purple
        case .strengthening: return .red
        case .resistanceBand: return .orange
        case .mobilityDrill: return .green
        }
    }
}

// MARK: - Rehab Exercise
struct RehabExercise: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let type: ExerciseType
    let description: String
    let duration: String  // e.g., "2 min", "3 sets of 10"
    let targetRegions: [BodyRegion]
    let instructions: [String]
    let videoURL: String?  // Future: link to exercise videos

    init(
        id: UUID = UUID(),
        name: String,
        type: ExerciseType,
        description: String,
        duration: String,
        targetRegions: [BodyRegion],
        instructions: [String],
        videoURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.duration = duration
        self.targetRegions = targetRegions
        self.instructions = instructions
        self.videoURL = videoURL
    }
}

// MARK: - Exercise Rating
struct ExerciseRating: Codable, Hashable {
    let exerciseId: UUID
    var rating: Int  // 1-5 stars
    var notes: String?
    var lastPerformed: Date

    init(exerciseId: UUID, rating: Int = 0, notes: String? = nil, lastPerformed: Date = Date()) {
        self.exerciseId = exerciseId
        self.rating = rating
        self.notes = notes
        self.lastPerformed = lastPerformed
    }
}

// MARK: - Injury
struct Injury: Identifiable, Codable {
    let id: UUID
    let region: BodyRegion
    let severity: InjurySeverity
    let name: String
    let dateReported: Date
    var dateResolved: Date?
    var notes: String
    var suggestedExercises: [RehabExercise]
    var exerciseRatings: [ExerciseRating]
    var isActive: Bool

    init(
        id: UUID = UUID(),
        region: BodyRegion,
        severity: InjurySeverity,
        name: String,
        dateReported: Date = Date(),
        dateResolved: Date? = nil,
        notes: String = "",
        suggestedExercises: [RehabExercise] = [],
        exerciseRatings: [ExerciseRating] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.region = region
        self.severity = severity
        self.name = name
        self.dateReported = dateReported
        self.dateResolved = dateResolved
        self.notes = notes
        self.suggestedExercises = suggestedExercises
        self.exerciseRatings = exerciseRatings
        self.isActive = isActive
    }

    var durationDays: Int {
        let endDate = dateResolved ?? Date()
        return Calendar.current.dateComponents([.day], from: dateReported, to: endDate).day ?? 0
    }

    func ratingForExercise(_ exerciseId: UUID) -> ExerciseRating? {
        exerciseRatings.first { $0.exerciseId == exerciseId }
    }

    mutating func updateExerciseRating(_ rating: ExerciseRating) {
        if let index = exerciseRatings.firstIndex(where: { $0.exerciseId == rating.exerciseId }) {
            exerciseRatings[index] = rating
        } else {
            exerciseRatings.append(rating)
        }
    }

    var averageExerciseRating: Double {
        let validRatings = exerciseRatings.filter { $0.rating > 0 }
        guard !validRatings.isEmpty else { return 0 }
        return Double(validRatings.map { $0.rating }.reduce(0, +)) / Double(validRatings.count)
    }

    var effectiveExercises: [RehabExercise] {
        suggestedExercises.filter { exercise in
            if let rating = ratingForExercise(exercise.id), rating.rating >= 4 {
                return true
            }
            return false
        }
    }
}
