import Foundation

enum TimeRange: String, CaseIterable {
    case week = "7D"
    case twoWeeks = "14D"
    case month = "30D"
    case threeMonths = "90D"

    var days: Int {
        switch self {
        case .week: return 7
        case .twoWeeks: return 14
        case .month: return 30
        case .threeMonths: return 90
        }
    }

    var displayName: String {
        switch self {
        case .week: return "Week"
        case .twoWeeks: return "2 Weeks"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        }
    }
}
