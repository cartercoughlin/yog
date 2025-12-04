import SwiftUI

enum MetricType: String, CaseIterable {
    case hrv = "HRV"
    case restingHeartRate = "Resting HR"
    case sleep = "Sleep"
    case steps = "Steps"
    case screenTime = "Screen Time"

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
        case .screenTime:
            return "iphone"
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
        case .screenTime:
            return .orange
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
        case .screenTime:
            return "hrs"
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
        case .screenTime:
            return "Hours"
        }
    }
}
