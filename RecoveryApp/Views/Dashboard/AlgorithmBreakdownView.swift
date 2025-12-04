//
//  AlgorithmBreakdownView.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import SwiftUI

struct AlgorithmBreakdownView: View {
    let recovery: RecoveryData
    let historicalMetrics: [HealthMetrics]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall Score Summary
                    overallScoreCard

                    // Formula Explanation
                    formulaCard

                    // HRV Component
                    ComponentBreakdownCard(
                        title: "Heart Rate Variability (HRV)",
                        weight: 20,
                        score: recovery.hrvScore,
                        icon: "waveform.path.ecg",
                        color: .purple,
                        currentValue: recovery.metrics.hrv.map { String(format: "%.0f ms", $0) } ?? "N/A",
                        baseline: calculateHRVBaseline(),
                        explanation: "HRV measures the variation in time between heartbeats. Higher HRV indicates better recovery and readiness to train. Scored using percentile ranking within your last 30 days.",
                        calculation: getHRVCalculation()
                    )

                    // Resting HR Component
                    ComponentBreakdownCard(
                        title: "Resting Heart Rate",
                        weight: 25,
                        score: recovery.restingHRScore,
                        icon: "heart.fill",
                        color: .red,
                        currentValue: recovery.metrics.restingHeartRate.map { "\($0) bpm" } ?? "N/A",
                        baseline: calculateRHRBaseline(),
                        explanation: "Lower resting heart rate indicates better cardiovascular fitness and recovery. Scored using percentile ranking within your last 30 days (inverted: lower RHR = higher score).",
                        calculation: getRHRCalculation()
                    )

                    // Sleep Component
                    ComponentBreakdownCard(
                        title: "Sleep Quality",
                        weight: 25,
                        score: recovery.sleepScore,
                        icon: "bed.double.fill",
                        color: .blue,
                        currentValue: recovery.metrics.totalSleepHours.map { String(format: "%.1f hrs", $0) } ?? "N/A",
                        baseline: "7-9 hrs optimal",
                        explanation: "Sleep duration and quality (REM/Deep sleep) are crucial for recovery. 8+ hours scores 90-100.",
                        calculation: getSleepCalculation()
                    )

                    // Training Load Component
                    ComponentBreakdownCard(
                        title: "Training Load",
                        weight: 30,
                        score: recovery.trainingLoadScore,
                        icon: "figure.run",
                        color: .orange,
                        currentValue: String(format: "%.0f", calculateAcuteLoad()),
                        baseline: String(format: "Chronic: %.0f", calculateChronicLoad()),
                        explanation: "INVERSE relationship: Lower recent training = better recovery. Low ratio (<0.6) = high recovery score (85-100).",
                        calculation: getTrainingLoadCalculation()
                    )

                    // Raw Data
                    rawDataCard
                }
                .padding()
            }
            .navigationTitle("Algorithm Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var overallScoreCard: some View {
        VStack(spacing: 12) {
            Text("Overall Recovery Score")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(recovery.overallScore)")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(recovery.category.color)

            Text(recovery.category.rawValue)
                .font(.title3)
                .fontWeight(.semibold)

            Divider()
                .padding(.vertical, 8)

            Text("Weighted Components")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ScoreSegment(value: recovery.hrvScore * 0.20, color: .purple)
                ScoreSegment(value: recovery.restingHRScore * 0.25, color: .red)
                ScoreSegment(value: recovery.sleepScore * 0.25, color: .blue)
                ScoreSegment(value: recovery.trainingLoadScore * 0.30, color: .orange)
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Formula", systemImage: "function")
                .font(.headline)

            Text("Recovery Score = ")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                FormulaRow(component: "HRV Score", weight: "20%", value: recovery.hrvScore, color: .purple)
                FormulaRow(component: "Resting HR Score", weight: "25%", value: recovery.restingHRScore, color: .red)
                FormulaRow(component: "Sleep Score", weight: "25%", value: recovery.sleepScore, color: .blue)
                FormulaRow(component: "Training Load Score", weight: "30%", value: recovery.trainingLoadScore, color: .orange)
            }
            .padding(.leading, 8)

            Divider()

            HStack {
                Text("Total:")
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "%.1f × 0.20 + %.1f × 0.25 + %.1f × 0.25 + %.1f × 0.30",
                            recovery.hrvScore, recovery.restingHRScore, recovery.sleepScore, recovery.trainingLoadScore))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Text("= \(recovery.overallScore)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(recovery.category.color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var rawDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Raw Data", systemImage: "list.bullet.rectangle")
                .font(.headline)

            if let hrv = recovery.metrics.hrv {
                DataRow(label: "HRV", value: String(format: "%.0f ms", hrv))
            }

            if let rhr = recovery.metrics.restingHeartRate {
                DataRow(label: "Resting HR", value: "\(rhr) bpm")
            }

            if let sleepHours = recovery.metrics.totalSleepHours {
                DataRow(label: "Total Sleep", value: String(format: "%.1f hours", sleepHours))
            }

            if let deepPct = recovery.metrics.deepSleepPercentage {
                DataRow(label: "Deep Sleep", value: String(format: "%.1f%%", deepPct))
            }

            if let remPct = recovery.metrics.remSleepPercentage {
                DataRow(label: "REM Sleep", value: String(format: "%.1f%%", remPct))
            }

            if let steps = recovery.metrics.steps {
                DataRow(label: "Steps", value: "\(steps)")
            }

            DataRow(label: "Workouts Today", value: "\(recovery.metrics.workouts.count)")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Calculation Helpers

    private func calculateHRVBaseline() -> String {
        let last30Days = historicalMetrics.suffix(30)
        let hrvValues = last30Days.compactMap { $0.hrv }
        guard !hrvValues.isEmpty else { return "N/A" }
        let avg = hrvValues.reduce(0.0, +) / Double(hrvValues.count)
        return String(format: "%.0f ms (30-day avg)", avg)
    }

    private func calculateRHRBaseline() -> String {
        let last30Days = historicalMetrics.suffix(30)
        let rhrValues = last30Days.compactMap { $0.restingHeartRate }
        guard !rhrValues.isEmpty else { return "N/A" }
        let avg = Double(rhrValues.reduce(0, +)) / Double(rhrValues.count)
        return String(format: "%.0f bpm (30-day avg)", avg)
    }

    private func calculateAcuteLoad() -> Double {
        let last7Days = historicalMetrics.suffix(7)
        return last7Days.flatMap { $0.workouts }.reduce(0.0) { sum, workout in
            sum + calculateWorkoutStress(workout)
        }
    }

    private func calculateChronicLoad() -> Double {
        let last28Days = historicalMetrics.suffix(28)
        let total = last28Days.flatMap { $0.workouts }.reduce(0.0) { sum, workout in
            sum + calculateWorkoutStress(workout)
        }
        return total / 4.0
    }

    private func calculateWorkoutStress(_ workout: WorkoutData) -> Double {
        guard let avgHR = workout.averageHeartRate else {
            return workout.durationInMinutes * 0.5
        }

        let restingHR = 60.0
        let maxHR = 190.0
        let hrReserve = maxHR - restingHR
        let intensity = (Double(avgHR) - restingHR) / hrReserve

        return workout.durationInMinutes * intensity * intensity * 100
    }

    private func getHRVCalculation() -> String {
        guard let currentHRV = recovery.metrics.hrv else { return "No HRV data available" }

        let last30Days = historicalMetrics.suffix(30)
        let hrvValues = last30Days.compactMap { $0.hrv }

        guard hrvValues.count >= 7 else {
            let baseline = hrvValues.isEmpty ? currentHRV : hrvValues.reduce(0.0, +) / Double(hrvValues.count)
            return """
            Current: \(String(format: "%.0f", currentHRV)) ms
            Baseline: \(String(format: "%.0f", baseline)) ms

            Insufficient data for percentile scoring.
            Using deviation formula:
            Score = 50 + (deviation × 2)
            Score = \(String(format: "%.1f", recovery.hrvScore))
            """
        }

        let sortedValues = hrvValues.sorted()
        let percentile = calculatePercentile(value: currentHRV, in: sortedValues)
        let baseline = hrvValues.reduce(0.0, +) / Double(hrvValues.count)

        return """
        Current: \(String(format: "%.0f", currentHRV)) ms
        30-day avg: \(String(format: "%.0f", baseline)) ms

        Percentile-based scoring:
        Your percentile: \(String(format: "%.0f", percentile))th

        Score ranges:
        • Top 20% (80-100th) → 85-100
        • Above median (60-80th) → 75-85
        • Near median (40-60th) → 65-75
        • Below median (20-40th) → 50-65
        • Bottom 20% (0-20th) → 0-50

        Final Score = \(String(format: "%.1f", recovery.hrvScore))
        """
    }

    private func calculatePercentile(value: Double, in sortedValues: [Double]) -> Double {
        guard !sortedValues.isEmpty else { return 50.0 }

        let count = sortedValues.count
        var valuesBelow = 0

        for sortedValue in sortedValues {
            if sortedValue < value {
                valuesBelow += 1
            } else if sortedValue == value {
                valuesBelow += 1
                break
            } else {
                break
            }
        }

        return (Double(valuesBelow) / Double(count)) * 100.0
    }

    private func getRHRCalculation() -> String {
        guard let currentRHR = recovery.metrics.restingHeartRate else { return "No RHR data available" }

        let last30Days = historicalMetrics.suffix(30)
        let rhrValues = last30Days.compactMap { $0.restingHeartRate }

        guard rhrValues.count >= 7 else {
            let baseline = rhrValues.isEmpty ? Double(currentRHR) : Double(rhrValues.reduce(0, +)) / Double(rhrValues.count)
            return """
            Current: \(currentRHR) bpm
            Baseline: \(String(format: "%.0f", baseline)) bpm

            Insufficient data for percentile scoring.
            Using deviation formula:
            Score = 50 + (deviation × 5)
            Score = \(String(format: "%.1f", recovery.restingHRScore))

            (Lower RHR = Better recovery)
            """
        }

        let sortedValues = rhrValues.sorted()
        let percentile = calculatePercentileInt(value: currentRHR, in: sortedValues)
        let inversePercentile = 100 - percentile
        let baseline = Double(rhrValues.reduce(0, +)) / Double(rhrValues.count)

        return """
        Current: \(currentRHR) bpm
        30-day avg: \(String(format: "%.0f", baseline)) bpm

        Percentile-based scoring (INVERTED):
        Your RHR percentile: \(String(format: "%.0f", percentile))th
        Inverse percentile: \(String(format: "%.0f", inversePercentile))th

        Lower RHR = Better recovery
        • Top 20% (lowest RHR, 80-100 inv.) → 85-100
        • Above median (60-80 inv.) → 75-85
        • Near median (40-60 inv.) → 65-75
        • Below median (20-40 inv.) → 50-65
        • Bottom 20% (highest RHR, 0-20 inv.) → 0-50

        Final Score = \(String(format: "%.1f", recovery.restingHRScore))
        """
    }

    private func calculatePercentileInt(value: Int, in sortedValues: [Int]) -> Double {
        guard !sortedValues.isEmpty else { return 50.0 }

        let count = sortedValues.count
        var valuesBelow = 0

        for sortedValue in sortedValues {
            if sortedValue < value {
                valuesBelow += 1
            } else if sortedValue == value {
                valuesBelow += 1
                break
            } else {
                break
            }
        }

        return (Double(valuesBelow) / Double(count)) * 100.0
    }

    private func getSleepCalculation() -> String {
        guard let sleepHours = recovery.metrics.totalSleepHours else { return "No sleep data available" }

        let durationScore: Double
        if sleepHours >= 8.0 {
            durationScore = min(100, 90 + (sleepHours - 8.0) * 5)
        } else if sleepHours >= 7.0 {
            durationScore = 75 + (sleepHours - 7.0) * 15
        } else if sleepHours >= 6.0 {
            durationScore = 55 + (sleepHours - 6.0) * 20
        } else {
            durationScore = sleepHours * 7
        }

        var calc = """
        Total Sleep: \(String(format: "%.1f", sleepHours)) hours

        Duration Score Ranges:
        • 8+ hours → 90-100 (excellent)
        • 7-8 hours → 75-90 (good)
        • 6-7 hours → 55-75 (adequate)
        • <6 hours → progressively lower

        Duration Score: \(String(format: "%.1f", durationScore))
        """

        if let deepPct = recovery.metrics.deepSleepPercentage,
           let remPct = recovery.metrics.remSleepPercentage {
            let deepScore: Double
            if deepPct >= 18.0 {
                deepScore = min(100, 85 + (deepPct - 18.0) * 3)
            } else if deepPct >= 13.0 {
                deepScore = 60 + (deepPct - 13.0) * 5
            } else {
                deepScore = deepPct * 4.6
            }

            let remScore: Double
            if remPct >= 20.0 {
                remScore = min(100, 85 + (remPct - 20.0) * 3)
            } else if remPct >= 15.0 {
                remScore = 60 + (remPct - 15.0) * 5
            } else {
                remScore = remPct * 4
            }

            calc += """


            Deep Sleep: \(String(format: "%.1f%%", deepPct))
            (18%+ = excellent, 13-18% = good)
            Deep Score: \(String(format: "%.1f", deepScore))

            REM Sleep: \(String(format: "%.1f%%", remPct))
            (20%+ = excellent, 15-20% = good)
            REM Score: \(String(format: "%.1f", remScore))

            Final = (Duration × 0.4) + (Deep × 0.35) + (REM × 0.25)
            Final = \(String(format: "%.1f", recovery.sleepScore))
            """
        } else {
            calc += "\n\nNo sleep stage data available.\nFinal Score = \(String(format: "%.1f", recovery.sleepScore))"
        }

        return calc
    }

    private func getTrainingLoadCalculation() -> String {
        let acute = calculateAcuteLoad()
        let chronic = calculateChronicLoad()

        guard chronic > 0 else { return "No training load data" }

        let ratio = acute / chronic

        return """
        Acute Load (7 days): \(String(format: "%.0f", acute))
        Chronic Load (28 days avg): \(String(format: "%.0f", chronic))

        Ratio = Acute / Chronic
        Ratio = \(String(format: "%.0f", acute)) / \(String(format: "%.0f", chronic))
        Ratio = \(String(format: "%.2f", ratio))

        RECOVERY SCORING (INVERSE):
        Lower training = Better recovery

        Score Ranges:
        • Ratio < 0.3 → 95-100 (excellent recovery)
        • Ratio 0.3-0.6 → 85-95 (very good recovery)
        • Ratio 0.6-1.0 → 70-85 (good recovery)
        • Ratio 1.0-1.3 → 55-70 (moderate recovery)
        • Ratio 1.3-1.6 → 40-55 (low recovery)
        • Ratio 1.6-2.0 → 25-40 (very low recovery)
        • Ratio > 2.0 → 0-25 (minimal recovery)

        Final Score = \(String(format: "%.1f", recovery.trainingLoadScore))
        """
    }
}

struct ComponentBreakdownCard: View {
    let title: String
    let weight: Int
    let score: Double
    let icon: String
    let color: Color
    let currentValue: String
    let baseline: String
    let explanation: String
    let calculation: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("\(weight)% weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.1f", score))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(color)

                        Text(String(format: "→ %.1f pts", score * Double(weight) / 100.0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currentValue)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Baseline:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(baseline)
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)

                Divider()

                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Calculation:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text(calculation)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ScoreSegment: View {
    let value: Double
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: CGFloat(value) * 3)
    }
}

struct FormulaRow: View {
    let component: String
    let weight: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(component)
                .font(.caption)

            Spacer()

            Text(String(format: "%.1f × %@", value, weight))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(String(format: "= %.1f", value * Double(weight.dropLast().trimmingCharacters(in: .whitespaces))! / 100))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}

struct DataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

#Preview {
    AlgorithmBreakdownView(
        recovery: .sample,
        historicalMetrics: []
    )
}
