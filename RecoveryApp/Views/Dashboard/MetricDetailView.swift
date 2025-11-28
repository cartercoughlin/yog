import SwiftUI
import Charts

struct MetricDetailView: View {
    let metricType: MetricType
    @StateObject private var viewModel: MetricDetailViewModel

    init(metricType: MetricType, historicalMetrics: [HealthMetrics]) {
        self.metricType = metricType
        _viewModel = StateObject(wrappedValue: MetricDetailViewModel(metricType: metricType, historicalMetrics: historicalMetrics))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Card
                headerCard

                // Time Range Selector
                timeRangeSelector

                // Chart
                chartCard

                // Summary Statistics
                statisticsCard

                Spacer()
            }
            .padding()
        }
        .navigationTitle(metricType.rawValue)
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: metricType.icon)
                .font(.system(size: 50))
                .foregroundColor(metricType.color)

            if let current = viewModel.currentValue {
                Text(viewModel.formattedValue(current))
                    .font(.system(size: 48, weight: .bold))
                Text(metricType.unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No Data")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            Text("Current Value")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    viewModel.setTimeRange(range)
                }) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(viewModel.selectedTimeRange == range ? .semibold : .regular)
                        .foregroundColor(viewModel.selectedTimeRange == range ? .white : metricType.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedTimeRange == range ? metricType.color : Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)

            if viewModel.dataPoints.isEmpty {
                Text("No data available for selected time range")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 60)
            } else {
                Chart {
                    ForEach(viewModel.dataPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(metricType.chartYAxisLabel, point.value)
                        )
                        .foregroundStyle(metricType.color.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value(metricType.chartYAxisLabel, point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [metricType.color.opacity(0.3), metricType.color.opacity(0.05)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }

                    // Average line
                    if let average = viewModel.average {
                        RuleMark(
                            y: .value("Average", average)
                        )
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: strideCount)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatisticItem(
                    title: "Average",
                    value: viewModel.formattedValue(viewModel.average),
                    unit: metricType.unit,
                    color: .blue
                )

                StatisticItem(
                    title: "Trend",
                    value: viewModel.trend,
                    unit: "",
                    color: trendColor
                )

                StatisticItem(
                    title: "Minimum",
                    value: viewModel.formattedValue(viewModel.minimum),
                    unit: metricType.unit,
                    color: .orange
                )

                StatisticItem(
                    title: "Maximum",
                    value: viewModel.formattedValue(viewModel.maximum),
                    unit: metricType.unit,
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private var trendColor: Color {
        if viewModel.trend.contains("Improving") {
            return .green
        } else if viewModel.trend == "Stable" {
            return .blue
        } else {
            return .orange
        }
    }

    private var strideCount: Int {
        switch viewModel.selectedTimeRange {
        case .week:
            return 1
        case .twoWeeks:
            return 2
        case .month:
            return 5
        case .threeMonths:
            return 15
        }
    }
}

struct StatisticItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
