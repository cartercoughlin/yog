//
//  HealthKitManager.swift
//  RecoveryApp
//
//  Created on 2025-11-22
//

import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRate),
        HKCategoryType(.sleepAnalysis),
        HKObjectType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.respiratoryRate)
    ]

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        print("🔐 Requesting HealthKit authorization...")
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        await MainActor.run {
            self.isAuthorized = true
        }
        print("✅ HealthKit authorization granted")
    }

    func fetchHealthMetrics(for date: Date) async throws -> HealthMetrics {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        async let hrv = fetchHRV(for: date)
        async let restingHR = fetchRestingHeartRate(for: date)
        async let sleepData = fetchSleepData(for: date)
        async let workouts = fetchWorkouts(startDate: startOfDay, endDate: endOfDay)
        async let activeEnergy = fetchActiveEnergy(startDate: startOfDay, endDate: endOfDay)
        async let steps = fetchSteps(startDate: startOfDay, endDate: endOfDay)

        let (hrvValue, restingHRValue, sleep, workoutData, energy, stepCount) = try await (
            hrv, restingHR, sleepData, workouts, activeEnergy, steps
        )

        return HealthMetrics(
            date: date,
            hrv: hrvValue,
            restingHeartRate: restingHRValue,
            sleepDuration: sleep.totalDuration,
            deepSleepDuration: sleep.deepDuration,
            remSleepDuration: sleep.remDuration,
            coreSleepDuration: sleep.coreDuration,
            workouts: workoutData,
            activeEnergyBurned: energy,
            steps: stepCount
        )
    }

    func fetchHistoricalMetrics(days: Int) async throws -> [HealthMetrics] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate)!

        var metrics: [HealthMetrics] = []
        var currentDate = startDate

        while currentDate <= endDate {
            do {
                let dayMetrics = try await fetchHealthMetrics(for: currentDate)
                metrics.append(dayMetrics)
            } catch {
                print("Error fetching metrics for \(currentDate): \(error)")
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return metrics
    }

    private func fetchHRV(for date: Date) async throws -> Double? {
        let hrvType = HKQuantityType(.heartRateVariabilitySDNN)
        let predicate = predicateForDay(date)

        print("📊 Fetching HRV for \(date)...")
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, results, error in
                if let error = error {
                    print("❌ HRV fetch error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        print("   Found \(samples.count) HRV samples")
        if let firstSample = samples.first {
            // HRV in HealthKit is stored as seconds, we need milliseconds for display
            let hrvInSeconds = firstSample.quantity.doubleValue(for: HKUnit.second())
            let hrvInMilliseconds = hrvInSeconds * 1000.0
            print("   ✅ HRV: \(hrvInSeconds) s = \(hrvInMilliseconds) ms")
            return hrvInMilliseconds
        }

        // If no HRV data, try to estimate from heart rate variability during sleep
        print("   ⚠️ No HRV data available, attempting to estimate from HR data...")
        if let estimatedHRV = try? await estimateHRVFromHeartRate(for: date) {
            print("   ✅ Estimated HRV: \(estimatedHRV) ms (from HR data)")
            return estimatedHRV
        }

        print("   ⚠️ Could not estimate HRV")
        return nil
    }

    private func estimateHRVFromHeartRate(for date: Date) async throws -> Double? {
        let hrType = HKQuantityType(.heartRate)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Look for HR data during typical sleep hours (10pm to 8am)
        let sleepStart = calendar.date(byAdding: .hour, value: -2, to: startOfDay)!
        let sleepEnd = calendar.date(byAdding: .hour, value: 8, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(
            withStart: sleepStart,
            end: sleepEnd,
            options: .strictStartDate
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        guard samples.count >= 10 else { return nil }

        // Calculate RMSSD (Root Mean Square of Successive Differences)
        let heartRates = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }

        // Convert HR to RR intervals (60000ms / HR)
        let rrIntervals = heartRates.map { 60000.0 / $0 }

        // Calculate successive differences
        var sumSquaredDiffs = 0.0
        for i in 0..<(rrIntervals.count - 1) {
            let diff = rrIntervals[i + 1] - rrIntervals[i]
            sumSquaredDiffs += diff * diff
        }

        let rmssd = sqrt(sumSquaredDiffs / Double(rrIntervals.count - 1))

        // RMSSD and SDNN are correlated but not identical
        // Rough conversion: SDNN ≈ RMSSD * 1.5 (this is an approximation)
        let estimatedSDNN = rmssd * 1.5

        return estimatedSDNN
    }

    private func fetchRestingHeartRate(for date: Date) async throws -> Int? {
        let rhrType = HKQuantityType(.restingHeartRate)
        let predicate = predicateForDay(date)

        print("❤️  Fetching Resting HR for \(date)...")
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, results, error in
                if let error = error {
                    print("❌ RHR fetch error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        print("   Found \(samples.count) RHR samples")
        guard let sample = samples.first else {
            print("   ⚠️ No Resting HR data available")
            return nil
        }
        let rhrValue = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        print("   ✅ Resting HR: \(rhrValue) bpm")
        return rhrValue
    }

    private func fetchSleepData(for date: Date) async throws -> (totalDuration: TimeInterval?, deepDuration: TimeInterval?, remDuration: TimeInterval?, coreDuration: TimeInterval?) {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let previousNight = calendar.date(byAdding: .hour, value: -8, to: startOfDay)!

        print("😴 Fetching Sleep data for \(date)...")
        print("   Time range: \(previousNight) to \(calendar.date(byAdding: .hour, value: 12, to: startOfDay)!)")

        let predicate = HKQuery.predicateForSamples(
            withStart: previousNight,
            end: calendar.date(byAdding: .hour, value: 12, to: startOfDay),
            options: .strictStartDate
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error = error {
                    print("❌ Sleep fetch error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }

        print("   Found \(samples.count) sleep samples")
        var totalDuration: TimeInterval = 0
        var deepDuration: TimeInterval = 0
        var remDuration: TimeInterval = 0
        var coreDuration: TimeInterval = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)

            if #available(iOS 16.0, *) {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    deepDuration += duration
                    totalDuration += duration
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    remDuration += duration
                    totalDuration += duration
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    coreDuration += duration
                    totalDuration += duration
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    totalDuration += duration
                default:
                    break
                }
            } else {
                if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                    totalDuration += duration
                }
            }
        }

        if totalDuration > 0 {
            print("   ✅ Sleep: \(totalDuration/3600) hrs (Deep: \(deepDuration/3600)h, REM: \(remDuration/3600)h, Core: \(coreDuration/3600)h)")
        } else {
            print("   ⚠️ No Sleep data available")
        }

        return (
            totalDuration > 0 ? totalDuration : nil,
            deepDuration > 0 ? deepDuration : nil,
            remDuration > 0 ? remDuration : nil,
            coreDuration > 0 ? coreDuration : nil
        )
    }

    private func fetchWorkouts(startDate: Date, endDate: Date) async throws -> [WorkoutData] {
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        print("🏃 Fetching Workouts from \(startDate) to \(endDate)...")
        let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error = error {
                    print("❌ Workout fetch error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }

        print("   Found \(workouts.count) workouts")
        var workoutData: [WorkoutData] = []
        for workout in workouts {
            let workoutType = WorkoutType.from(hkWorkoutType: workout.workoutActivityType)
            print("   - \(workoutType.rawValue): \(workout.duration/60) min")
            let avgHR = try? await fetchAverageHeartRate(for: workout)
            let maxHR = try? await fetchMaxHeartRate(for: workout)

            let data = WorkoutData(
                date: workout.startDate,
                type: WorkoutType.from(hkWorkoutType: workout.workoutActivityType),
                duration: workout.duration,
                distance: workout.totalDistance?.doubleValue(for: .meter()),
                averageHeartRate: avgHR,
                maxHeartRate: maxHR,
                caloriesBurned: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                trainingStress: 0
            )
            workoutData.append(data)
        }

        return workoutData
    }

    private func fetchAverageHeartRate(for workout: HKWorkout) async throws -> Int? {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
        return Int(total / Double(samples.count))
    }

    private func fetchMaxHeartRate(for workout: HKWorkout) async throws -> Int? {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        let maxHR = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }.max()
        return maxHR.map { Int($0) }
    }

    private func fetchActiveEnergy(startDate: Date, endDate: Date) async throws -> Double? {
        let energyType = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let sum = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSteps(startDate: Date, endDate: Date) async throws -> Int? {
        let stepsType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let sum = statistics?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: sum.map { Int($0) })
            }
            healthStore.execute(query)
        }
    }

    private func predicateForDay(_ date: Date) -> NSPredicate {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
    }
}

enum HealthKitError: Error {
    case notAvailable
    case authorizationFailed
    case dataNotAvailable
}
