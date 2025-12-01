import SwiftUI

struct InjuryTrackerView: View {
    @StateObject private var viewModel = InjuryTrackerViewModel()
    @State private var showAddInjury = false
    @State private var selectedRegion: BodyRegion?
    @State private var showBodyDiagram = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    summaryCard

                    // Body Diagram Button
                    Button {
                        showBodyDiagram = true
                    } label: {
                        HStack {
                            Image(systemName: "figure.stand")
                                .font(.title2)
                            Text("View Body Diagram")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)

                    // Active Injuries
                    if !viewModel.activeInjuries.isEmpty {
                        activeInjuriesSection
                    }

                    // Resolved Injuries
                    if !viewModel.resolvedInjuries.isEmpty {
                        resolvedInjuriesSection
                    }

                    if viewModel.injuries.isEmpty {
                        emptyState
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Injury Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddInjury = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddInjury) {
                AddInjuryView(viewModel: viewModel, preselectedRegion: selectedRegion)
            }
            .sheet(isPresented: $showBodyDiagram) {
                NavigationStack {
                    BodyDiagramView(injuries: viewModel.injuries) { region in
                        selectedRegion = region
                        showBodyDiagram = false
                        showAddInjury = true
                    }
                    .navigationTitle("Body Diagram")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showBodyDiagram = false
                            }
                        }
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Injuries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.activeInjuries.count)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Resolved")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.resolvedInjuries.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let mostCommon = viewModel.mostCommonRegion {
                Divider()

                HStack {
                    Text("Most Common:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(mostCommon.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal)
    }

    private var activeInjuriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Injuries")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.activeInjuries) { injury in
                NavigationLink {
                    InjuryDetailView(injury: injury, viewModel: viewModel)
                } label: {
                    InjuryRow(injury: injury)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var resolvedInjuriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resolved Injuries")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.resolvedInjuries) { injury in
                NavigationLink {
                    InjuryDetailView(injury: injury, viewModel: viewModel)
                } label: {
                    InjuryRow(injury: injury)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.stand")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("No Injuries Tracked")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Tap + to add an injury or use the body diagram to select a region")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showBodyDiagram = true
            } label: {
                Label("View Body Diagram", systemImage: "figure.stand")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }
}

struct InjuryRow: View {
    let injury: Injury

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: injury.severity.icon)
                .font(.title3)
                .foregroundStyle(injury.severity.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(injury.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(injury.region.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !injury.isActive {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("Resolved")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(injury.durationDays) days")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if injury.suggestedExercises.count > 0 {
                    Text("\(injury.suggestedExercises.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .padding(.horizontal)
    }
}

#Preview {
    InjuryTrackerView()
}
