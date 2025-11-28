import SwiftUI

enum MetricType: String, CaseIterable {
    case hrv = "HRV"
    case restingHeartRate = "Resting HR"
    case sleep = "Sleep"
    case steps = "Steps"

    var icon: String {
        switch self {
        case .hrv:
            return "waveform.path.ecg"
        case .restingHeartRate:
            return "heart.fill"
        case .sleep:
            return "bed.double.fill"
        case .steps:
            return "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .hrv:
            return .purple
        case .restingHeartRate:
            return .red
        case .sleep:
            return .blue
        case .steps:
            return .green
        }
    }

    var unit: String {
        switch self {
        case .hrv:
            return "ms"
        case .restingHeartRate:
            return "bpm"
        case .sleep:
            return "hrs"
        case .steps:
            return "steps"
        }
    }

    var chartYAxisLabel: String {
        switch self {
        case .hrv:
            return "HRV (ms)"
        case .restingHeartRate:
            return "Heart Rate (bpm)"
        case .sleep:
            return "Hours"
        case .steps:
            return "Step Count"
        }
    }
}
