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
        async let activeEnergy = fetchActiveEnergy(startDate: startOfDay, endDate: endOfDay)
        async let steps = fetchSteps(startDate: startOfDay, endDate: endOfDay)
        async let dateOfBirth = fetchDateOfBirth()

        let (hrvValue, restingHRValue, sleep, energy, stepCount, dob) = try await (
            hrv, restingHR, sleepData, activeEnergy, steps, dateOfBirth
        )

        // Fetch workouts with context about resting HR and age for accurate training stress
        let workoutData = try await fetchWorkouts(
            startDate: startOfDay,
            endDate: endOfDay,
            restingHR: restingHRValue,
            dateOfBirth: dob
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

    func fetchMetricsForDateRange(startDate: Date, endDate: Date) async throws -> [HealthMetrics] {
        let calendar = Calendar.current
        var metrics: [HealthMetrics] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let finalDate = calendar.startOfDay(for: endDate)

        while currentDate <= finalDate {
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
        do {
            if let estimatedHRV = try await estimateHRVFromHeartRate(for: date) {
                print("   ✅ Estimated HRV (RMSSD): \(estimatedHRV) ms (from HR data)")
                return estimatedHRV
            }
        } catch {
            print("   ❌ Error estimating HRV: \(error)")
        }

        print("   ⚠️ Could not estimate HRV")
        return nil
    }

    private func estimateHRVFromHeartRate(for date: Date) async throws -> Double? {
        let hrType = HKQuantityType(.heartRate)
        let sleepType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Get actual sleep periods from sleep analysis
        let sleepStart = calendar.date(byAdding: .hour, value: -2, to: startOfDay)!
        let sleepEnd = calendar.date(byAdding: .hour, value: 8, to: startOfDay)!

        let sleepPredicate = HKQuery.predicateForSamples(
            withStart: sleepStart,
            end: sleepEnd,
            options: .strictStartDate
        )

        // Fetch sleep analysis data
        print("   🛌 Fetching sleep analysis data...")
        let sleepSamples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: sleepPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }
        print("   📊 Found \(sleepSamples.count) sleep samples")

        // Extract actual sleep periods (asleep, not just in bed)
        let sleepPeriods = sleepSamples.compactMap { sample -> (start: Date, end: Date)? in
            // Include asleep, core, deep, and REM sleep
            if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
               sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                return (sample.startDate, sample.endDate)
            }
            return nil
        }

        // If no sleep data, fall back to typical sleep hours but mark as less reliable
        let hrPredicate: NSPredicate
        if sleepPeriods.isEmpty {
            print("   ⚠️ No sleep analysis data, using typical sleep hours")
            hrPredicate = HKQuery.predicateForSamples(
                withStart: sleepStart,
                end: sleepEnd,
                options: .strictStartDate
            )
        } else {
            print("   ✅ Found \(sleepPeriods.count) sleep periods")
            hrPredicate = HKQuery.predicateForSamples(
                withStart: sleepStart,
                end: sleepEnd,
                options: .strictStartDate
            )
        }

        // Fetch heart rate samples
        print("   💓 Fetching heart rate samples...")
        let hrSamples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: hrPredicate,
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
        print("   📊 Found \(hrSamples.count) HR samples")

        // Filter HR samples to only those during actual sleep periods
        let filteredSamples: [HKQuantitySample]
        if !sleepPeriods.isEmpty {
            filteredSamples = hrSamples.filter { sample in
                sleepPeriods.contains { period in
                    sample.startDate >= period.start && sample.startDate <= period.end
                }
            }
            print("   📊 Filtered to \(filteredSamples.count) HR samples during sleep")
        } else {
            filteredSamples = hrSamples
        }

        guard !filteredSamples.isEmpty else {
            print("   ⚠️ No HR samples found during sleep periods")
            return nil
        }

        // Convert to HR values and clean outliers
        let heartRates = filteredSamples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }

        // Calculate mean and standard deviation for outlier detection
        let mean = heartRates.reduce(0.0, +) / Double(heartRates.count)
        let variance = heartRates.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(heartRates.count)
        let stdDev = sqrt(variance)

        // Filter out outliers and physiologically impossible values
        let cleanedData = zip(filteredSamples, heartRates).compactMap { (sample, hr) -> (date: Date, hr: Double)? in
            // Remove outliers: >3 SD from mean, or outside physiological range (30-130 bpm during sleep)
            if hr < 30 || hr > 130 || abs(hr - mean) > 3 * stdDev {
                return nil
            }
            return (sample.startDate, hr)
        }

        print("   📊 Cleaned data: \(cleanedData.count) samples (removed \(heartRates.count - cleanedData.count) outliers)")

        guard cleanedData.count >= 20 else {
            print("   ⚠️ Insufficient clean HR data (need 20+, got \(cleanedData.count))")
            return nil
        }

        // Convert HR to RR intervals (60000ms / HR)
        let rrData = cleanedData.map { (date: $0.date, rr: 60000.0 / $0.hr) }

        // Find continuous segments (max gap: 60 seconds)
        struct Segment {
            var rrPairs: [(Double, Double)] // (rr1, rr2) pairs
            var duration: TimeInterval
        }

        var segments: [Segment] = []
        var currentSegment: [(date: Date, rr: Double)] = [rrData[0]]
        var gapStats: [Double] = []

        for i in 1..<rrData.count {
            let timeDiff = rrData[i].date.timeIntervalSince(currentSegment.last!.date)
            gapStats.append(timeDiff)

            if timeDiff <= 600.0 { // Max 10 minute gap (relaxed further)
                currentSegment.append(rrData[i])
            } else {
                // Process current segment if it's long enough
                if currentSegment.count >= 5 { // Relaxed from 10
                    let pairs = zip(currentSegment.dropLast(), currentSegment.dropFirst()).map { ($0.rr, $1.rr) }
                    let duration = currentSegment.last!.date.timeIntervalSince(currentSegment.first!.date)
                    segments.append(Segment(rrPairs: Array(pairs), duration: duration))
                }
                currentSegment = [rrData[i]]
            }
        }

        // Don't forget the last segment
        if currentSegment.count >= 5 { // Relaxed from 10
            let pairs = zip(currentSegment.dropLast(), currentSegment.dropFirst()).map { ($0.rr, $1.rr) }
            let duration = currentSegment.last!.date.timeIntervalSince(currentSegment.first!.date)
            segments.append(Segment(rrPairs: Array(pairs), duration: duration))
        }

        // Log gap statistics
        let sortedGaps = gapStats.sorted()
        let medianGap = sortedGaps[sortedGaps.count / 2]
        let maxGap = sortedGaps.last ?? 0
        print("   📊 Gap stats: median=\(Int(medianGap))s, max=\(Int(maxGap))s")
        print("   📊 Found \(segments.count) continuous segments")

        guard !segments.isEmpty else {
            print("   ⚠️ No continuous segments found")
            return nil
        }

        // Calculate total time covered
        let totalDuration = segments.reduce(0.0) { $0 + $1.duration }
        print("   📊 Total time coverage: \(Int(totalDuration/60)) minutes")

        guard totalDuration >= 600 else { // At least 10 minutes of data (relaxed from 30)
            print("   ⚠️ Insufficient time coverage (need 10+ min, got \(Int(totalDuration/60)) min)")
            return nil
        }

        // Calculate RMSSD for each segment
        let segmentRMSSDs = segments.map { segment -> Double in
            let sumSquaredDiffs = segment.rrPairs.map { pow($1 - $0, 2) }.reduce(0.0, +)
            return sqrt(sumSquaredDiffs / Double(segment.rrPairs.count))
        }

        // Use median RMSSD across segments (more robust than mean)
        let sortedRMSSDs = segmentRMSSDs.sorted()
        let medianRMSSD: Double
        if sortedRMSSDs.count % 2 == 0 {
            medianRMSSD = (sortedRMSSDs[sortedRMSSDs.count / 2 - 1] + sortedRMSSDs[sortedRMSSDs.count / 2]) / 2.0
        } else {
            medianRMSSD = sortedRMSSDs[sortedRMSSDs.count / 2]
        }

        print("   ✅ Calculated RMSSD: \(medianRMSSD) ms from \(segments.count) segments over \(Int(totalDuration/60)) min")

        // Return RMSSD as the primary metric (more robust than SDNN for short periods)
        // Note: This is an approximation from HR data, not direct HRV measurement
        return medianRMSSD
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

    private func fetchWorkouts(startDate: Date, endDate: Date, restingHR: Int? = nil, dateOfBirth: Date? = nil) async throws -> [WorkoutData] {
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

            // Calculate training stress using heart rate if available
            let durationMinutes = workout.duration / 60.0
            let trainingStress: Double
            if let avgHR = avgHR {
                // Use actual resting HR from HealthKit, or fallback to 60
                let actualRestingHR = Double(restingHR ?? 60)

                // Calculate max HR based on age if available, otherwise use standard formula
                let estimatedMaxHR: Double
                if let dob = dateOfBirth {
                    let age = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
                    // Use more accurate Tanaka formula: 208 - (0.7 × age)
                    estimatedMaxHR = 208.0 - (0.7 * Double(age))
                } else {
                    // Fallback to standard assumption
                    estimatedMaxHR = 190.0
                }

                // Also consider the max HR from this specific workout
                let workoutMaxHR = maxHR != nil ? Double(maxHR!) : estimatedMaxHR
                let effectiveMaxHR = min(workoutMaxHR, estimatedMaxHR + 10) // Cap at formula + 10 for safety

                // Heart rate reserve formula: intensity = (avgHR - restingHR) / (maxHR - restingHR)
                let hrReserve = effectiveMaxHR - actualRestingHR
                let intensity = max(0, min(1, (Double(avgHR) - actualRestingHR) / hrReserve)) // Clamp 0-1
                trainingStress = durationMinutes * intensity * intensity * 100
            } else {
                // Fallback: use duration with moderate intensity assumption
                trainingStress = durationMinutes * 0.5
            }

            let data = WorkoutData(
                date: workout.startDate,
                type: WorkoutType.from(hkWorkoutType: workout.workoutActivityType),
                duration: workout.duration,
                distance: workout.totalDistance?.doubleValue(for: .meter()),
                averageHeartRate: avgHR,
                maxHeartRate: maxHR,
                caloriesBurned: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                trainingStress: trainingStress,
                workout: workout
            )

            workoutData.append(data)
        }

        return workoutData
    }

    private func fetchDateOfBirth() async throws -> Date? {
        do {
            let dateOfBirthComponents = try healthStore.dateOfBirthComponents()
            return Calendar.current.date(from: dateOfBirthComponents)
        } catch {
            print("   ⚠️ Could not fetch date of birth: \(error)")
            return nil
        }
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
