import Foundation
import UIKit

// MARK: - Training Plan Export
// Renders a TrainingPlan into a CSV or PDF document that the user can
// share/save from a share sheet.
enum TrainingPlanExporter {

    // MARK: CSV

    static func csvData(for plan: TrainingPlan) -> Data {
        var rows: [[String]] = [[
            "Week", "Phase", "Date", "Day", "Workout Type", "Description",
            "Planned Distance (mi)", "Planned Duration (min)", "Pace (/mi)",
            "Completed", "Actual Distance (mi)", "Actual Duration", "Actual Pace (/mi)"
        ]]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        for week in plan.weeks {
            for workout in week.workouts.sorted(by: { $0.date < $1.date }) {
                rows.append([
                    "\(week.weekNumber)",
                    week.phase.rawValue,
                    dateFormatter.string(from: workout.date),
                    dayFormatter.string(from: workout.date),
                    workout.type.rawValue,
                    workout.description,
                    workout.distanceInMiles.map { String(format: "%.1f", $0) } ?? "",
                    workout.durationInMinutes.map { "\($0)" } ?? "",
                    workout.customPaceOverride ?? workout.paceMinPerMile ?? "",
                    workout.isCompleted ? "Yes" : "No",
                    workout.linkedWorkout.map { String(format: "%.2f", $0.actualDistance) } ?? "",
                    workout.linkedWorkout.map { formatClockDuration($0.actualDuration) } ?? "",
                    workout.linkedWorkout?.actualPace ?? ""
                ])
            }
        }

        let csvString = rows.map { row in row.map(escapeCSVField).joined(separator: ",") }.joined(separator: "\r\n")
        return Data(csvString.utf8)
    }

    private static func escapeCSVField(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func formatClockDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: PDF

    static func pdfData(for plan: TrainingPlan) -> Data {
        let pageWidth: CGFloat = 612   // US Letter, 8.5in @ 72dpi
        let pageHeight: CGFloat = 792  // 11in @ 72dpi
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let titleFont = UIFont.boldSystemFont(ofSize: 20)
        let subtitleFont = UIFont.systemFont(ofSize: 11)
        let weekHeaderFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 10)
        let noteFont = UIFont.systemFont(ofSize: 9)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"

        return renderer.pdfData { context in
            var y: CGFloat = margin

            func startNewPage() {
                context.beginPage()
                y = margin
            }

            func draw(_ text: String, font: UIFont, color: UIColor = .black, indent: CGFloat = 0, spacingAfter: CGFloat = 4) {
                let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
                let maxWidth = contentWidth - indent
                let boundingRect = attributed.boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                )
                let neededHeight = boundingRect.height + spacingAfter
                if y + neededHeight > pageHeight - margin {
                    startNewPage()
                }
                attributed.draw(
                    with: CGRect(x: margin + indent, y: y, width: maxWidth, height: boundingRect.height),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                )
                y += neededHeight
            }

            startNewPage()

            draw(plan.name, font: titleFont, spacingAfter: 6)
            draw(
                "\(plan.raceDistance.rawValue) · Goal \(VDOTCalculator.formatTime(seconds: plan.goalTimeInSeconds)) (\(plan.goalPaceMinPerMile)/mi) · Race day \(dateFormatter.string(from: plan.raceDate))",
                font: subtitleFont,
                color: .darkGray,
                spacingAfter: 14
            )

            for week in plan.weeks {
                let weekTitle = "Week \(week.weekNumber) — \(week.phase.rawValue)"
                    + (week.isStepbackWeek ? " (Recovery)" : "")
                    + " · \(Int(week.totalMileage)) mi"
                draw(weekTitle, font: weekHeaderFont, spacingAfter: 6)

                let sortedWorkouts = week.workouts.sorted { $0.date < $1.date }
                if sortedWorkouts.isEmpty {
                    draw("No scheduled workouts", font: noteFont, color: .gray, indent: 12, spacingAfter: 10)
                    continue
                }

                for workout in sortedWorkouts {
                    var headline = "\(dateFormatter.string(from: workout.date)) — \(workout.type.rawValue)"
                    if let distance = workout.distanceInMiles {
                        headline += String(format: " · %.0f mi", distance)
                    }
                    let pace = workout.customPaceOverride ?? workout.paceMinPerMile
                    if let pace, workout.type != .rest {
                        headline += " · \(pace)/mi"
                    }
                    if workout.isCompleted {
                        headline += workout.description.contains("(Skipped)") ? " · Skipped" : " · Completed"
                    }
                    draw(headline, font: bodyFont, indent: 12, spacingAfter: 2)
                    draw(workout.description, font: noteFont, color: .darkGray, indent: 24, spacingAfter: 4)

                    if let linked = workout.linkedWorkout {
                        draw(
                            "Actual: \(linked.formattedDistance) in \(linked.formattedDuration) (\(linked.actualPace)/mi)",
                            font: noteFont,
                            color: .systemGreen,
                            indent: 24,
                            spacingAfter: 4
                        )
                    }
                }

                y += 8
            }
        }
    }

    // MARK: File Writing

    /// Writes export data to a temporary file so it can be handed to a share sheet.
    static func writeToTemporaryFile(data: Data, planName: String, fileExtension: String) -> URL? {
        let sanitizedName = planName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let filename = (sanitizedName.isEmpty ? "TrainingPlan" : sanitizedName) + "." + fileExtension

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("❌ Failed to write export file: \(error)")
            return nil
        }
    }
}
