import SwiftUI

struct InjuryTrackerView: View {
    @StateObject private var viewModel = InjuryViewModel()
    @State private var showingAddInjury = false
    @State private var selectedLocation: BodyLocation? = nil
    @State private var showingInjuryDetail: InjuryData? = nil
    @State private var selectedFilter: InjuryFilter = .active

    enum InjuryFilter: String, CaseIterable {
        case active = "Active"
        case all = "All"
        case healed = "Healed"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    injurySummaryCard

                    // Body Mannequin
                    mannequinSection

                    // Injury List
                    injuryListSection
                }
                .padding()
            }
            .navigationTitle("Injury Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddInjury = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddInjury) {
                InjuryInputSheet(viewModel: viewModel)
            }
            .sheet(item: $showingInjuryDetail) { injury in
                InjuryDetailView(injury: injury, viewModel: viewModel)
            }
        }
    }

    // MARK: - Summary Card
    private var injurySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cross.case.fill")
                    .font(.title2)
                    .foregroundColor(.red)

                VStack(alignment: .leading) {
                    Text("Injury Status")
                        .font(.headline)
                    Text(viewModel.injurySummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.totalRecoveryImpact > 0 {
                    VStack(alignment: .trailing) {
                        Text("-\(Int(viewModel.totalRecoveryImpact))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Recovery Impact")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !viewModel.activeInjuries.isEmpty {
                Divider()

                HStack(spacing: 20) {
                    StatItem(
                        title: "Active",
                        value: "\(viewModel.activeInjuries.filter { $0.status == .active }.count)",
                        color: .red
                    )

                    StatItem(
                        title: "Recovering",
                        value: "\(viewModel.activeInjuries.filter { $0.status == .recovering }.count)",
                        color: .orange
                    )

                    StatItem(
                        title: "Avg Days",
                        value: "\(averageDaysSinceReported)",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Mannequin Section
    private var mannequinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pain Map")
                .font(.headline)

            if viewModel.activeInjuries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 60))
                        .foregroundColor(.green.opacity(0.6))

                    Text("No active injuries")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Tap + to log an injury")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
            } else {
                BodyMannequinView(viewModel: viewModel, selectedLocation: $selectedLocation)
                    .frame(height: 400)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)

                if let location = selectedLocation,
                   let injuries = viewModel.injuries(at: location).first {
                    selectedLocationDetail(injury: injuries)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Injury List Section
    private var injuryListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Injury Log")
                    .font(.headline)

                Spacer()

                Picker("Filter", selection: $selectedFilter) {
                    ForEach(InjuryFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if filteredInjuries.isEmpty {
                Text("No injuries to display")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(filteredInjuries) { injury in
                    InjuryRow(injury: injury)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingInjuryDetail = injury
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Selected Location Detail
    private func selectedLocationDetail(injury: InjuryData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: injury.painType.icon)
                    .foregroundColor(severityColor(injury.severity))

                Text(injury.location.displayName)
                    .font(.headline)

                Spacer()

                Text(injury.severity.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(severityColor(injury.severity).opacity(0.2))
                    .cornerRadius(8)
            }

            if !injury.notes.isEmpty {
                Text(injury.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: { showingInjuryDetail = injury }) {
                Text("View Details")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.top, 8)
    }

    // MARK: - Helpers
    private var filteredInjuries: [InjuryData] {
        switch selectedFilter {
        case .active:
            return viewModel.activeInjuries.sorted { $0.dateReported > $1.dateReported }
        case .healed:
            return viewModel.healedInjuries.sorted { $0.dateReported > $1.dateReported }
        case .all:
            return viewModel.injuries.sorted { $0.dateReported > $1.dateReported }
        }
    }

    private var averageDaysSinceReported: Int {
        let active = viewModel.activeInjuries
        guard !active.isEmpty else { return 0 }
        let total = active.reduce(0) { $0 + $1.daysSinceReported }
        return total / active.count
    }

    private func severityColor(_ severity: PainSeverity) -> Color {
        switch severity.color {
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .gray
        }
    }
}

// MARK: - Injury Row
struct InjuryRow: View {
    let injury: InjuryData

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(injury.location.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(injury.painType.displayName, systemImage: injury.painType.icon)
                        .font(.caption)

                    Text("•")
                        .font(.caption)

                    Text(injury.severity.displayName)
                        .font(.caption)

                    if injury.daysSinceReported > 0 {
                        Text("•")
                            .font(.caption)

                        Text("\(injury.daysSinceReported)d ago")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch injury.status {
        case .active: return .red
        case .recovering: return .orange
        case .healed: return .green
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        var body: some View {
            InjuryTrackerView()
        }
    }

    return PreviewWrapper()
}
