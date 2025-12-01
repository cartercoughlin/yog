import SwiftUI

struct InjuryDetailView: View {
    @Environment(\.dismiss) var dismiss
    let injury: InjuryData
    @ObservedObject var viewModel: InjuryViewModel

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    headerCard

                    // Pain Details
                    painDetailsCard

                    // Timeline
                    timelineCard

                    // Affected Activities
                    if !injury.affectedWorkoutTypes.isEmpty {
                        affectedActivitiesCard
                    }

                    // Notes
                    if !injury.notes.isEmpty {
                        notesCard
                    }

                    // Actions
                    actionsCard
                }
                .padding()
            }
            .navigationTitle("Injury Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingEditSheet = true }) {
                            Label("Edit", systemImage: "pencil")
                        }

                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                InjuryInputSheet(viewModel: viewModel, editingInjury: injury)
            }
            .alert("Delete Injury", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteInjury(injury)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this injury record?")
            }
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: injury.painType.icon)
                    .font(.title)
                    .foregroundColor(severityColor)

                VStack(alignment: .leading) {
                    Text(injury.location.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        StatusBadge(status: injury.status)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(injury.severity.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery Impact")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("-\(Int(injury.recoveryImpact)) points")
                        .font(.headline)
                        .foregroundColor(.red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Days Active")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(injury.daysSinceReported)")
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Pain Details Card
    private var painDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pain Details")
                .font(.headline)

            HStack {
                InjuryDetailItem(
                    icon: injury.painType.icon,
                    title: "Type",
                    value: injury.painType.displayName
                )

                Spacer()

                InjuryDetailItem(
                    icon: "chart.bar.fill",
                    title: "Severity",
                    value: "\(injury.severity.numericValue)/10"
                )
            }

            // Severity Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { level in
                        Rectangle()
                            .fill(level <= injury.severity.numericValue ? severityColor : Color.gray.opacity(0.2))
                            .frame(height: 8)
                    }
                }
                .cornerRadius(4)

                Text(severityDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Timeline Card
    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                InjuryTimelineRow(
                    icon: "calendar",
                    title: "Reported",
                    date: injury.dateReported,
                    color: .blue
                )

                if let healedDate = injury.dateHealed {
                    InjuryTimelineRow(
                        icon: "checkmark.circle.fill",
                        title: "Healed",
                        date: healedDate,
                        color: .green
                    )

                    let duration = Calendar.current.dateComponents([.day], from: injury.dateReported, to: healedDate).day ?? 0
                    Text("Recovery time: \(duration) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 32)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Affected Activities Card
    private var affectedActivitiesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Affected Activities")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(injury.affectedWorkoutTypes, id: \.self) { activity in
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundColor(.orange)

                        Text(activity)
                            .font(.subheadline)

                        Spacer()

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)

            Text(injury.notes)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Actions Card
    private var actionsCard: some View {
        VStack(spacing: 12) {
            if injury.status == .active {
                Button(action: {
                    viewModel.markAsRecovering(injury)
                }) {
                    Label("Mark as Recovering", systemImage: "arrow.clockwise.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(10)
                }
            }

            if injury.status == .active || injury.status == .recovering {
                Button(action: {
                    viewModel.markAsHealed(injury)
                }) {
                    Label("Mark as Healed", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                }
            }

            if injury.status == .healed {
                Button(action: {
                    viewModel.markAsActive(injury)
                }) {
                    Label("Mark as Active Again", systemImage: "exclamationmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helpers
    private var severityColor: Color {
        switch injury.severity.color {
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .gray
        }
    }

    private var severityDescription: String {
        switch injury.severity {
        case .mild: return "Minor discomfort"
        case .moderate: return "Noticeable pain"
        case .severe: return "Significant pain"
        case .debilitating: return "Intense pain"
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: InjuryStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)

            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundColor(statusColor)
        .cornerRadius(6)
    }

    private var statusColor: Color {
        switch status {
        case .active: return .red
        case .recovering: return .orange
        case .healed: return .green
        }
    }
}

// MARK: - Injury Detail Item
struct InjuryDetailItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Injury Timeline Row
struct InjuryTimelineRow: View {
    let icon: String
    let title: String
    let date: Date
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleInjury = InjuryData(
        location: .leftKnee,
        painType: .aching,
        severity: .moderate,
        status: .active,
        dateReported: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
        notes: "Pain after long runs, especially downhill. Started after 20 mile run last week.",
        affectedWorkoutTypes: ["Running", "Cycling"]
    )

    return InjuryDetailView(injury: sampleInjury, viewModel: InjuryViewModel())
}
