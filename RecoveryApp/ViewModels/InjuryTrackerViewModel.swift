import Foundation
import SwiftUI

@MainActor
class InjuryTrackerViewModel: ObservableObject {
    @Published var injuries: [Injury] = []
    @Published var selectedInjury: Injury?

    init() {
        loadInjuries()
    }

    // MARK: - Injury Management

    func addInjury(_ injury: Injury) {
        var newInjury = injury

        // Generate exercise recommendations
        let suggestedExercises = ExerciseDatabase.exercisesFor(region: injury.region, limit: 6)
        newInjury.suggestedExercises = suggestedExercises

        injuries.append(newInjury)
        saveInjuries()
    }

    func updateInjury(_ injury: Injury) {
        if let index = injuries.firstIndex(where: { $0.id == injury.id }) {
            injuries[index] = injury
            saveInjuries()
        }
    }

    func deleteInjury(_ injury: Injury) {
        injuries.removeAll { $0.id == injury.id }
        saveInjuries()
    }

    func markInjuryResolved(_ injury: Injury) {
        if let index = injuries.firstIndex(where: { $0.id == injury.id }) {
            injuries[index].isActive = false
            injuries[index].dateResolved = Date()
            saveInjuries()
        }
    }

    func markInjuryActive(_ injury: Injury) {
        if let index = injuries.firstIndex(where: { $0.id == injury.id }) {
            injuries[index].isActive = true
            injuries[index].dateResolved = nil
            saveInjuries()
        }
    }

    // MARK: - Exercise Rating

    func rateExercise(
        for injuryId: UUID,
        exerciseId: UUID,
        rating: Int,
        notes: String? = nil
    ) {
        guard let index = injuries.firstIndex(where: { $0.id == injuryId }) else { return }

        let exerciseRating = ExerciseRating(
            exerciseId: exerciseId,
            rating: rating,
            notes: notes,
            lastPerformed: Date()
        )

        injuries[index].updateExerciseRating(exerciseRating)
        saveInjuries()
    }

    // MARK: - Generate More Exercises

    func generateMoreExercises(for injury: Injury) {
        guard let index = injuries.firstIndex(where: { $0.id == injury.id }) else { return }

        let currentExerciseIds = injury.suggestedExercises.map { $0.id }
        let additionalExercises = ExerciseDatabase.additionalExercisesFor(
            region: injury.region,
            excluding: currentExerciseIds,
            limit: 4
        )

        injuries[index].suggestedExercises.append(contentsOf: additionalExercises)
        saveInjuries()
    }

    // MARK: - Computed Properties

    var activeInjuries: [Injury] {
        injuries.filter { $0.isActive }.sorted { $0.dateReported > $1.dateReported }
    }

    var resolvedInjuries: [Injury] {
        injuries.filter { !$0.isActive }.sorted { ($0.dateResolved ?? Date()) > ($1.dateResolved ?? Date()) }
    }

    var injuryCount: Int {
        activeInjuries.count
    }

    func injuriesForRegion(_ region: BodyRegion) -> [Injury] {
        injuries.filter { $0.region == region }
    }

    var hasActiveInjuries: Bool {
        !activeInjuries.isEmpty
    }

    var totalRecoveryImpact: Double {
        activeInjuries.reduce(0) { $0 + $1.recoveryImpact }
    }

    // MARK: - Persistence

    private func saveInjuries() {
        if let encoded = try? JSONEncoder().encode(injuries) {
            UserDefaults.standard.set(encoded, forKey: "SavedInjuries")
        }
    }

    private func loadInjuries() {
        if let data = UserDefaults.standard.data(forKey: "SavedInjuries"),
           let decoded = try? JSONDecoder().decode([Injury].self, from: data) {
            injuries = decoded
        }
    }

    // MARK: - Analytics

    var totalInjuryDays: Int {
        activeInjuries.map { $0.durationDays }.reduce(0, +)
    }

    var mostCommonRegion: BodyRegion? {
        let regions = injuries.map { $0.region }
        let counts = Dictionary(grouping: regions, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var averageRecoveryTime: Double {
        let resolved = resolvedInjuries
        guard !resolved.isEmpty else { return 0 }
        let total = resolved.map { $0.durationDays }.reduce(0, +)
        return Double(total) / Double(resolved.count)
    }
}
