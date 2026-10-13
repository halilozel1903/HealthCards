#if canImport(HealthKit) && (os(iOS) || os(watchOS))
import Foundation
import HealthKit

/// Reads steps, active energy, exercise time, distance, heart rate, resting heart rate, heart rate variability,
/// sleep stages, activity rings and workouts from HealthKit. It never writes.
///
/// The app needs the HealthKit capability (the `com.apple.developer.healthkit` entitlement) and an
/// `NSHealthShareUsageDescription` in its Info.plist. Call ``requestAuthorization()`` before the first query.
///
/// `HKHealthStore` is documented as thread-safe and every other stored property is immutable, which is why the
/// class can be `Sendable`.
public final class HealthKitDataSource: HealthDataSource, @unchecked Sendable {
    public let calendar: Calendar
    /// Whether heart rate variability is requested and read. Leave it off when your app does not show HRV, so the
    /// permission sheet asks for one type less.
    public let readsHeartRateVariability: Bool
    private let store: HKHealthStore

    public init(
        store: HKHealthStore = HKHealthStore(),
        calendar: Calendar = .current,
        readsHeartRateVariability: Bool = true
    ) {
        self.store = store
        self.calendar = calendar
        self.readsHeartRateVariability = readsHeartRateVariability
    }

    /// Whether HealthKit is available on this device.
    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    public var kind: HealthDataKind { .healthKit }

    /// The types this source reads.
    public var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType(),
        ]
        if readsHeartRateVariability {
            types.insert(HKQuantityType(.heartRateVariabilitySDNN))
        }
        return types
    }

    // MARK: Authorization

    public func requestAuthorization() async throws {
        guard Self.isAvailable else { throw HealthDataError.healthDataUnavailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    public func authorizationStatus() async throws -> HealthAuthorizationStatus {
        guard Self.isAvailable else { throw HealthDataError.healthDataUnavailable }
        let status = try await store.statusForAuthorizationRequest(toShare: [], read: readTypes)
        switch status {
        case .shouldRequest:
            return .shouldRequest
        case .unnecessary:
            return .requested
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    // MARK: Statistics

    public func statistics(
        _ metric: HealthMetric,
        in interval: DateInterval,
        bucket: StatisticsBucket
    ) async throws -> [MetricPoint] {
        let unit = metric.healthKitUnit
        let isSum = metric.aggregation == .sum
        let anchor = HealthAggregation.bucketStart(for: interval.start, bucket: bucket, calendar: calendar)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(metric.quantityIdentifier), predicate: predicate),
            options: isSum ? .cumulativeSum : .discreteAverage,
            anchorDate: anchor,
            intervalComponents: bucket == .day ? DateComponents(day: 1) : DateComponents(day: 7)
        )
        let collection = try await descriptor.result(for: store)
        var points: [MetricPoint] = []
        for statistics in collection.statistics() {
            let quantity = isSum ? statistics.sumQuantity() : statistics.averageQuantity()
            if let quantity {
                points.append(MetricPoint(date: statistics.startDate, value: quantity.doubleValue(for: unit)))
            }
        }
        return HealthAggregation.normalize(
            points,
            aggregation: metric.aggregation,
            interval: interval,
            bucket: bucket,
            calendar: calendar
        )
    }

    // MARK: Heart rate

    public func heartRate(on date: Date) async throws -> HeartRateSummary {
        let day = calendar.dayInterval(containing: date)
        let bpm = HKUnit.count().unitDivided(by: HKUnit.minute())
        let samples = try await quantitySamples(.heartRate, in: day, newestFirst: false, limit: nil)
        let resting = try await quantitySamples(.restingHeartRate, in: day, newestFirst: true, limit: 1).first
        var variability: Double?
        if readsHeartRateVariability {
            let milliseconds = HKUnit.secondUnit(with: .milli)
            let values = try await quantitySamples(.heartRateVariabilitySDNN, in: day, newestFirst: false, limit: nil)
                .map { $0.quantity.doubleValue(for: milliseconds) }
            if !values.isEmpty {
                variability = values.reduce(0, +) / Double(values.count)
            }
        }
        return HeartRateSummary(
            samples: samples.map { HeartRateSample(date: $0.startDate, beatsPerMinute: $0.quantity.doubleValue(for: bpm)) },
            resting: resting?.quantity.doubleValue(for: bpm),
            variability: variability
        )
    }

    private func quantitySamples(
        _ identifier: HKQuantityTypeIdentifier,
        in interval: DateInterval,
        newestFirst: Bool,
        limit: Int?
    ) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: newestFirst ? .reverse : .forward)],
            limit: limit
        )
        return try await descriptor.result(for: store)
    }

    // MARK: Sleep

    public func sleep(forNightEndingOn date: Date) async throws -> SleepNight? {
        let window = HealthAggregation.sleepWindow(endingOn: date, calendar: calendar)
        // No options: every sample that overlaps the window, clipped to it below.
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: nil
        )
        let samples = try await descriptor.result(for: store)
        var segments: [SleepSegment] = []
        for sample in samples {
            guard let stage = SleepStage(healthKitValue: sample.value) else { continue }
            segments.append(SleepSegment(
                stage: stage,
                start: Swift.max(sample.startDate, window.start),
                end: Swift.min(sample.endDate, window.end)
            ))
        }
        let night = SleepNight(segments: segments)
        return night.isEmpty ? nil : night
    }

    // MARK: Activity rings

    public func activityRings(on date: Date) async throws -> ActivityRings? {
        var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.calendar = calendar
        let predicate = HKQuery.predicateForActivitySummary(with: components)
        let day = calendar.startOfDay(for: date)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ActivityRings?, any Error>) in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, error in
                if let error {
                    if let healthKitError = error as? HKError, healthKitError.code == .errorNoData {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: summaries?.first.map { ActivityRings(summary: $0, date: day) })
            }
            store.execute(query)
        }
    }

    // MARK: Workouts

    public func workouts(in interval: DateInterval) async throws -> [Workout] {
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: nil
        )
        let workouts = try await descriptor.result(for: store)
        return workouts.map { Workout(healthKit: $0) }
    }
}

extension HealthMetric {
    /// The HealthKit quantity type behind the metric.
    public var quantityIdentifier: HKQuantityTypeIdentifier {
        switch self {
        case .steps: .stepCount
        case .activeEnergy: .activeEnergyBurned
        case .exerciseTime: .appleExerciseTime
        case .walkingRunningDistance: .distanceWalkingRunning
        case .heartRate: .heartRate
        case .restingHeartRate: .restingHeartRate
        case .heartRateVariability: .heartRateVariabilitySDNN
        }
    }

    /// The unit HealthCards reports the metric in.
    public var healthKitUnit: HKUnit {
        switch self {
        case .steps: HKUnit.count()
        case .activeEnergy: HKUnit.kilocalorie()
        case .exerciseTime: HKUnit.minute()
        case .walkingRunningDistance: HKUnit.meter()
        case .heartRate, .restingHeartRate: HKUnit.count().unitDivided(by: HKUnit.minute())
        case .heartRateVariability: HKUnit.secondUnit(with: .milli)
        }
    }
}

extension ActivityRings {
    init(summary: HKActivitySummary, date: Date) {
        let kilocalories = HKUnit.kilocalorie()
        let minutes = HKUnit.minute()
        let count = HKUnit.count()
        self.init(
            date: date,
            move: RingValue(
                value: summary.activeEnergyBurned.doubleValue(for: kilocalories),
                goal: summary.activeEnergyBurnedGoal.doubleValue(for: kilocalories)
            ),
            exercise: RingValue(
                value: summary.appleExerciseTime.doubleValue(for: minutes),
                goal: summary.exerciseTimeGoal?.doubleValue(for: minutes) ?? ActivityGoals.standard.exercise
            ),
            stand: RingValue(
                value: summary.appleStandHours.doubleValue(for: count),
                goal: summary.standHoursGoal?.doubleValue(for: count) ?? ActivityGoals.standard.stand
            )
        )
    }
}

extension Workout {
    init(healthKit workout: HKWorkout) {
        let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: HKUnit.kilocalorie())
        var distance: Double?
        let distanceTypes: [HKQuantityTypeIdentifier] = [.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
        for identifier in distanceTypes {
            if let meters = workout.statistics(for: HKQuantityType(identifier))?.sumQuantity()?.doubleValue(for: HKUnit.meter()) {
                distance = meters
                break
            }
        }
        self.init(
            id: workout.uuid,
            activity: WorkoutActivity(healthKit: workout.workoutActivityType),
            start: workout.startDate,
            end: workout.endDate,
            activeEnergy: energy,
            distance: distance
        )
    }
}

extension WorkoutActivity {
    /// Maps a HealthKit activity type; types without a case of their own become ``other``.
    public init(healthKit type: HKWorkoutActivityType) {
        switch type {
        case .running: self = .running
        case .walking: self = .walking
        case .cycling: self = .cycling
        case .swimming: self = .swimming
        case .hiking: self = .hiking
        case .yoga: self = .yoga
        case .functionalStrengthTraining, .traditionalStrengthTraining: self = .strengthTraining
        case .highIntensityIntervalTraining: self = .highIntensityIntervalTraining
        case .elliptical: self = .elliptical
        case .rowing: self = .rowing
        case .cardioDance, .socialDance: self = .dance
        default: self = .other
        }
    }
}
#endif
