import Foundation

// MARK: - Body Location
enum BodyLocation: String, Codable, CaseIterable, Identifiable {
    case head
    case neck
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHand
    case rightHand
    case chest
    case upperBack
    case lowerBack
    case abdomen
    case leftHip
    case rightHip
    case leftQuad
    case rightQuad
    case leftKnee
    case rightKnee
    case leftShin
    case rightShin
    case leftCalf
    case rightCalf
    case leftAnkle
    case rightAnkle
    case leftFoot
    case rightFoot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .head: return "Head"
        case .neck: return "Neck"
        case .leftShoulder: return "Left Shoulder"
        case .rightShoulder: return "Right Shoulder"
        case .leftElbow: return "Left Elbow"
        case .rightElbow: return "Right Elbow"
        case .leftWrist: return "Left Wrist"
        case .rightWrist: return "Right Wrist"
        case .leftHand: return "Left Hand"
        case .rightHand: return "Right Hand"
        case .chest: return "Chest"
        case .upperBack: return "Upper Back"
        case .lowerBack: return "Lower Back"
        case .abdomen: return "Abdomen"
        case .leftHip: return "Left Hip"
        case .rightHip: return "Right Hip"
        case .leftQuad: return "Left Quad"
        case .rightQuad: return "Right Quad"
        case .leftKnee: return "Left Knee"
        case .rightKnee: return "Right Knee"
        case .leftShin: return "Left Shin"
        case .rightShin: return "Right Shin"
        case .leftCalf: return "Left Calf"
        case .rightCalf: return "Right Calf"
        case .leftAnkle: return "Left Ankle"
        case .rightAnkle: return "Right Ankle"
        case .leftFoot: return "Left Foot"
        case .rightFoot: return "Right Foot"
        }
    }

    // Position for mannequin visualization (normalized coordinates 0-1)
    var mannequinPosition: (x: Double, y: Double) {
        switch self {
        case .head: return (0.5, 0.08)
        case .neck: return (0.5, 0.15)
        case .leftShoulder: return (0.35, 0.20)
        case .rightShoulder: return (0.65, 0.20)
        case .leftElbow: return (0.25, 0.32)
        case .rightElbow: return (0.75, 0.32)
        case .leftWrist: return (0.20, 0.42)
        case .rightWrist: return (0.80, 0.42)
        case .leftHand: return (0.18, 0.48)
        case .rightHand: return (0.82, 0.48)
        case .chest: return (0.5, 0.28)
        case .upperBack: return (0.5, 0.30)
        case .lowerBack: return (0.5, 0.45)
        case .abdomen: return (0.5, 0.38)
        case .leftHip: return (0.42, 0.48)
        case .rightHip: return (0.58, 0.48)
        case .leftQuad: return (0.42, 0.58)
        case .rightQuad: return (0.58, 0.58)
        case .leftKnee: return (0.42, 0.68)
        case .rightKnee: return (0.58, 0.68)
        case .leftShin: return (0.42, 0.78)
        case .rightShin: return (0.58, 0.78)
        case .leftCalf: return (0.40, 0.80)
        case .rightCalf: return (0.60, 0.80)
        case .leftAnkle: return (0.42, 0.88)
        case .rightAnkle: return (0.58, 0.88)
        case .leftFoot: return (0.42, 0.94)
        case .rightFoot: return (0.58, 0.94)
        }
    }
}

// MARK: - Pain Type
enum PainType: String, Codable, CaseIterable, Identifiable {
    case sharp
    case dull
    case aching
    case burning
    case throbbing
    case stabbing
    case tingling
    case numb
    case stiff

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .sharp: return "bolt.fill"
        case .dull: return "circle.fill"
        case .aching: return "waveform.path"
        case .burning: return "flame.fill"
        case .throbbing: return "heart.fill"
        case .stabbing: return "exclamationmark.triangle.fill"
        case .tingling: return "sparkles"
        case .numb: return "moon.zzz.fill"
        case .stiff: return "lock.fill"
        }
    }
}

// MARK: - Pain Severity
enum PainSeverity: Int, Codable, CaseIterable, Identifiable {
    case mild = 1
    case moderate = 2
    case severe = 3
    case debilitating = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .mild: return "Mild (1-3)"
        case .moderate: return "Moderate (4-6)"
        case .severe: return "Severe (7-9)"
        case .debilitating: return "Debilitating (10)"
        }
    }

    var color: String {
        switch self {
        case .mild: return "yellow"
        case .moderate: return "orange"
        case .severe: return "red"
        case .debilitating: return "purple"
        }
    }

    var numericValue: Int {
        switch self {
        case .mild: return 2
        case .moderate: return 5
        case .severe: return 8
        case .debilitating: return 10
        }
    }
}

// MARK: - Injury Status
enum InjuryStatus: String, Codable, CaseIterable {
    case active
    case recovering
    case healed

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .active: return "exclamationmark.circle.fill"
        case .recovering: return "arrow.clockwise.circle.fill"
        case .healed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Injury Data
struct InjuryData: Identifiable, Codable, Equatable {
    let id: UUID
    var location: BodyLocation
    var painType: PainType
    var severity: PainSeverity
    var status: InjuryStatus
    var dateReported: Date
    var dateHealed: Date?
    var notes: String
    var affectedWorkoutTypes: [String] // Activities that aggravate the injury

    init(
        id: UUID = UUID(),
        location: BodyLocation,
        painType: PainType,
        severity: PainSeverity,
        status: InjuryStatus = .active,
        dateReported: Date = Date(),
        dateHealed: Date? = nil,
        notes: String = "",
        affectedWorkoutTypes: [String] = []
    ) {
        self.id = id
        self.location = location
        self.painType = painType
        self.severity = severity
        self.status = status
        self.dateReported = dateReported
        self.dateHealed = dateHealed
        self.notes = notes
        self.affectedWorkoutTypes = affectedWorkoutTypes
    }

    var daysSinceReported: Int {
        Calendar.current.dateComponents([.day], from: dateReported, to: Date()).day ?? 0
    }

    var isActive: Bool {
        status == .active || status == .recovering
    }

    // Recovery impact: how much this injury should reduce recovery score (0-30 points)
    var recoveryImpact: Double {
        guard isActive else { return 0 }

        let baseImpact: Double
        switch severity {
        case .mild: baseImpact = 5
        case .moderate: baseImpact = 10
        case .severe: baseImpact = 20
        case .debilitating: baseImpact = 30
        }

        // Reduce impact as injury gets older (recovering injuries have less impact)
        let recoveryMultiplier: Double = status == .recovering ? 0.5 : 1.0

        return baseImpact * recoveryMultiplier
    }
}
