import Foundation
import Combine

struct MetricDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

class MetricDetailViewModel: ObservableObject {
    @Published var selectedTimeRange: TimeRange = .month
    @Published var dataPoints: [MetricDataPoint] = []
    @Published var currentValue: Double?
    @Published var average: Double?
    @Published var minimum: Double?
    @Published var maximum: Double?
    @Published var trend: String = "–"

    private let metricType: MetricType
    private let historicalMetrics: [HealthMetrics]

    init(metricType: MetricType, historicalMetrics: [HealthMetrics]) {
        self.metricType = metricType
        self.historicalMetrics = historicalMetrics
        updateData()
    }

    func setTimeRange(_ range: TimeRange) {
        selectedTimeRange = range
        updateData()
    }

    private func updateData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // A 7-day range means today plus the previous six complete calendar
        // days. Comparing against an exact time could discard the oldest day.
        let cutoffDate = calendar.date(
            byAdding: .day,
            value: -(selectedTimeRange.days - 1),
            to: today
        ) ?? today

        let filteredMetrics = historicalMetrics
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date < $1.date }

        dataPoints = filteredMetrics.compactMap { metric -> MetricDataPoint? in
            guard let value = extractValue(from: metric) else { return nil }
            return MetricDataPoint(date: metric.date, value: value)
        }

        calculateStatistics()
    }

    private func extractValue(from metric: HealthMetrics) -> Double? {
        switch metricType {
        case .hrv:
            return metric.hrv
        case .restingHeartRate:
            return metric.restingHeartRate.map { Double($0) }
        case .sleep:
            guard let sleepDuration = metric.sleepDuration else { return nil }
            return sleepDuration / 3600.0  // Convert seconds to hours
        case .steps:
            return metric.steps.map { Double($0) }
        }
    }

    private func calculateStatistics() {
        let values = dataPoints.map { $0.value }

        guard !values.isEmpty else {
            currentValue = nil
            average = nil
            minimum = nil
            maximum = nil
            trend = "–"
            return
        }

        // Get the most recent value from ALL historical metrics (not just filtered)
        let sortedMetrics = historicalMetrics.sorted { $0.date > $1.date }
        currentValue = sortedMetrics.compactMap { extractValue(from: $0) }.first

        average = values.reduce(0, +) / Double(values.count)
        minimum = values.min()
        maximum = values.max()

        // Calculate trend (comparing current value to average of selected time range)
        if let current = currentValue, let avg = average {
            let percentDiff = ((current - avg) / avg) * 100

            if abs(percentDiff) < 2 {
                trend = "Stable"
            } else if percentDiff > 0 {
                // For HRV, Sleep, and Steps, higher is better
                // For Resting HR, lower is better
                switch metricType {
                case .hrv, .sleep, .steps:
                    trend = "↑ Improving"
                case .restingHeartRate:
                    trend = "↑ Above Avg."
                }
            } else {
                switch metricType {
                case .hrv, .sleep, .steps:
                    trend = "↓ Below Avg."
                case .restingHeartRate:
                    trend = "↓ Improving"
                }
            }
        }
    }

    func formattedValue(_ value: Double?) -> String {
        guard let value = value else { return "–" }

        switch metricType {
        case .hrv:
            return String(format: "%.0f", value)
        case .restingHeartRate:
            return String(format: "%.0f", value)
        case .sleep:
            return String(format: "%.1f", value)
        case .steps:
            return String(format: "%.0f", value)
        }
    }
}
