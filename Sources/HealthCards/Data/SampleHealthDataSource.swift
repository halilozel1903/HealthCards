import Foundation

/// Plausible health data without HealthKit, for SwiftUI previews, demos, tests and the simulator (which has no
/// health data).
///
/// The data is deterministic: each day is generated from the seed and the calendar date alone, so the same day
/// always has the same steps, heart rate, sleep and workouts, whichever range or order it is asked for in. Today is
/// filled in up to ``now``, and nothing exists after it.
///
/// Show your users when they are looking at sample data; ``HealthDataSource/isSampleData`` is `true` for this
/// source.
public struct SampleHealthDataSource: HealthDataSource {
    public let seed: UInt64
    public let calendar: Calendar
    public let goals: ActivityGoals
    private let fixedNow: Date?

    /// - Parameters:
    ///   - seed: Another seed gives other, equally plausible data.
    ///   - now: The moment data ends. `nil` uses the current time at every query; pass a date for repeatable
    ///     screenshots and tests.
    public init(
        seed: UInt64 = 1903,
        calendar: Calendar = .current,
        now: Date? = nil,
        goals: ActivityGoals = .standard
    ) {
        self.seed = seed
        self.calendar = calendar
        self.fixedNow = now
        self.goals = goals
    }

    /// Friday 9 October 2026 at 18:30 in `calendar`: a fixed "now" for previews and screenshots.
    public static func showcaseDate(calendar: Calendar = .current) -> Date {
        let components = DateComponents(year: 2026, month: 10, day: 9, hour: 18, minute: 30)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 1_791_570_600)
    }

    /// A source for SwiftUI previews, with ``showcaseDate(calendar:)`` as its fixed "now".
    public static var preview: SampleHealthDataSource {
        SampleHealthDataSource(now: showcaseDate())
    }

    public var kind: HealthDataKind { .sample }

    /// The moment the generated data ends.
    public var now: Date { fixedNow ?? Date() }

    // MARK: HealthDataSource

    public func requestAuthorization() async throws {}

    public func authorizationStatus() async throws -> HealthAuthorizationStatus { .requested }

    public func statistics(
        _ metric: HealthMetric,
        in interval: DateInterval,
        bucket: StatisticsBucket
    ) async throws -> [MetricPoint] {
        points(metric, in: interval, bucket: bucket)
    }

    public func heartRate(on date: Date) async throws -> HeartRateSummary {
        heartRateSummary(on: date)
    }

    public func sleep(forNightEndingOn date: Date) async throws -> SleepNight? {
        night(endingOn: date)
    }

    public func activityRings(on date: Date) async throws -> ActivityRings? {
        rings(on: date)
    }

    public func workouts(in interval: DateInterval) async throws -> [Workout] {
        workoutList(in: interval)
    }

    // MARK: Synchronous access

    /// The same as ``statistics(_:in:bucket:)``, synchronously.
    public func points(_ metric: HealthMetric, in interval: DateInterval, bucket: StatisticsBucket) -> [MetricPoint] {
        var daily: [MetricPoint] = []
        for start in HealthAggregation.bucketStarts(in: interval, bucket: .day, calendar: calendar) {
            if let value = dailyValue(metric, on: start) {
                daily.append(MetricPoint(date: start, value: value))
            }
        }
        return HealthAggregation.normalize(
            daily,
            aggregation: metric.aggregation,
            interval: interval,
            bucket: bucket,
            calendar: calendar
        )
    }

    /// The same as ``heartRate(on:)``, synchronously: a measurement every five minutes up to ``now``.
    public func heartRateSummary(on date: Date) -> HeartRateSummary {
        guard let generated = day(date) else { return .empty }
        var random = generator(for: generated.start, salt: 0x4EA2_7BEA)
        let current = now
        let intensity = generated.workout.map { Self.profile(for: $0.activity).intensity } ?? 0
        var samples: [HeartRateSample] = []
        for index in 0..<288 {
            let noise = random.uniform(-1...1)
            let burst = random.unit()
            let time = generated.start.addingTimeInterval(Double(index) * 300)
            guard time <= current else { break }
            let hour = Double(index) / 12
            let bpm: Double
            if let workout = generated.workout, workout.start <= time, time < workout.end {
                bpm = 108 + 48 * intensity + noise * 7
            } else if hour < 6.5 || hour >= 23 {
                bpm = generated.restingHeartRate - 3 + noise * 3 + burst * 3
            } else {
                let daylight = sin((hour - 6.5) / 16.5 * Double.pi)
                bpm = generated.restingHeartRate + 11 + 9 * daylight + noise * 5 + burst * burst * 24
            }
            samples.append(HeartRateSample(date: time, beatsPerMinute: bpm.rounded()))
        }
        return HeartRateSummary(samples: samples, resting: generated.restingHeartRate, variability: generated.variability)
    }

    /// The same as ``sleep(forNightEndingOn:)``, synchronously: four or five sleep cycles with more deep sleep
    /// early in the night and more REM towards morning.
    public func night(endingOn date: Date) -> SleepNight? {
        let wakeDay = calendar.startOfDay(for: date)
        var random = generator(for: wakeDay, salt: 0x51EE_9000)
        let bedtime = wakeDay.addingTimeInterval(random.uniform(-80 ... -5).rounded() * 60)
        let latency = random.uniform(6...16)
        let cycleCount = random.integer(4...5)

        var segments: [SleepSegment] = []
        var cursor = bedtime
        func add(_ stage: SleepStage, minutes: Double) {
            let length = minutes.rounded()
            guard length >= 1 else { return }
            let end = cursor.addingTimeInterval(length * 60)
            segments.append(SleepSegment(stage: stage, start: cursor, end: end))
            cursor = end
        }

        add(.awake, minutes: latency)
        for cycle in 0..<6 {
            // Every cycle draws the same numbers, used or not, so the night depends only on the seed and date.
            let length = random.uniform(86...104)
            let split = random.uniform(0.4...0.6)
            let wakes = random.chance(0.4)
            let wakeMinutes = random.uniform(2...7)
            guard cycle < cycleCount else { continue }
            let deepShare = Swift.max(0.03, 0.30 - 0.065 * Double(cycle))
            let remShare = Swift.min(0.36, 0.12 + 0.06 * Double(cycle))
            let core = length * (1 - deepShare - remShare)
            add(.core, minutes: core * split)
            add(.deep, minutes: length * deepShare)
            add(.core, minutes: core * (1 - split))
            add(.rem, minutes: length * remShare)
            if wakes && cycle < cycleCount - 1 {
                add(.awake, minutes: wakeMinutes)
            }
        }
        add(.core, minutes: random.uniform(10...40))
        add(.awake, minutes: random.uniform(2...6))

        guard cursor <= now else { return nil }
        segments.append(SleepSegment(
            stage: .inBed,
            start: bedtime.addingTimeInterval(-8 * 60),
            end: cursor.addingTimeInterval(4 * 60)
        ))
        return SleepNight(segments: segments)
    }

    /// The same as ``activityRings(on:)``, synchronously.
    public func rings(on date: Date) -> ActivityRings? {
        guard let generated = day(date) else { return nil }
        return ActivityRings(
            date: generated.start,
            move: RingValue(value: generated.activeEnergy, goal: goals.move),
            exercise: RingValue(value: generated.exerciseMinutes, goal: goals.exercise),
            stand: RingValue(value: generated.standHours, goal: goals.stand)
        )
    }

    /// The same as ``workouts(in:)``, synchronously.
    public func workoutList(in interval: DateInterval) -> [Workout] {
        HealthAggregation.bucketStarts(in: interval, bucket: .day, calendar: calendar)
            .compactMap { day($0)?.workout }
            .filter { $0.start >= interval.start && $0.start < interval.end }
            .sorted { $0.start > $1.start }
    }

    /// A snapshot built synchronously, for SwiftUI previews. ``HealthDataSource/snapshot(for:)`` returns the same.
    public func makeSnapshot(for date: Date? = nil) -> HealthSnapshot {
        let moment = date ?? now
        let today = calendar.startOfDay(for: moment)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let fortnightStart = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let fortnight = DateInterval(start: fortnightStart, end: tomorrow)
        var nights: [SleepNight] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            let wakeDay = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            if let generated = night(endingOn: wakeDay) {
                nights.append(generated)
            }
        }
        return HealthSnapshot(
            date: moment,
            calendar: calendar,
            stepPoints: points(.steps, in: fortnight, bucket: .day),
            energyPoints: points(.activeEnergy, in: fortnight, bucket: .day),
            exercisePoints: points(.exerciseTime, in: fortnight, bucket: .day),
            distancePoints: points(.walkingRunningDistance, in: DateInterval(start: today, end: tomorrow), bucket: .day),
            rings: rings(on: moment),
            heartRate: heartRateSummary(on: moment),
            recentNights: nights,
            workouts: workoutList(in: DateInterval(start: weekStart, end: tomorrow))
        )
    }

    // MARK: Generation

    /// One generated day, filled in up to `now`.
    struct Day {
        var start: Date
        var steps: Double
        var activeEnergy: Double
        var exerciseMinutes: Double
        var distance: Double
        var standHours: Double
        var restingHeartRate: Double
        var variability: Double
        /// The day's workout, once it has finished.
        var workout: Workout?
    }

    struct ActivityProfile {
        var stepsPerMinute: Double
        var energyPerMinute: Double
        var metersPerMinute: Double
        /// 0 (resting) to 1 (hard), for the heart rate during the workout.
        var intensity: Double
    }

    static let workoutActivities: [WorkoutActivity] = [
        .running, .walking, .cycling, .strengthTraining, .yoga, .hiking, .highIntensityIntervalTraining,
    ]

    static func profile(for activity: WorkoutActivity) -> ActivityProfile {
        switch activity {
        case .running:
            ActivityProfile(stepsPerMinute: 165, energyPerMinute: 11.5, metersPerMinute: 165, intensity: 0.85)
        case .walking:
            ActivityProfile(stepsPerMinute: 115, energyPerMinute: 5.2, metersPerMinute: 85, intensity: 0.25)
        case .hiking:
            ActivityProfile(stepsPerMinute: 105, energyPerMinute: 7.8, metersPerMinute: 70, intensity: 0.45)
        case .cycling:
            ActivityProfile(stepsPerMinute: 0, energyPerMinute: 9, metersPerMinute: 330, intensity: 0.7)
        case .highIntensityIntervalTraining:
            ActivityProfile(stepsPerMinute: 40, energyPerMinute: 12, metersPerMinute: 0, intensity: 1)
        case .yoga:
            ActivityProfile(stepsPerMinute: 0, energyPerMinute: 3.6, metersPerMinute: 0, intensity: 0.1)
        default:
            ActivityProfile(stepsPerMinute: 0, energyPerMinute: 7, metersPerMinute: 0, intensity: 0.55)
        }
    }

    /// A generator for one calendar day and purpose. Keyed on the year, month and day, so the time zone and the
    /// query range do not change the data.
    func generator(for date: Date, salt: UInt64) -> SeededGenerator {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let key = (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
        var mixer = SeededGenerator(seed: seed ^ (UInt64(Swift.max(0, key)) &* 0x9E37_79B9_7F4A_7C15) ^ salt)
        return SeededGenerator(seed: mixer.next())
    }

    /// How much of the day's activity has happened by `now`: none before 07:00, all of it by 22:00.
    func progress(ofDayStarting start: Date) -> Double {
        let hours = now.timeIntervalSince(start) / 3600
        if hours >= 24 {
            return 1
        }
        return Swift.min(1, Swift.max(0, (hours - 7) / 15))
    }

    func day(_ date: Date) -> Day? {
        let start = calendar.startOfDay(for: date)
        let current = now
        guard start <= current else { return nil }
        var random = generator(for: start, salt: 0xAC71_7171)
        let weekday = calendar.component(.weekday, from: start)
        let isWeekend = weekday == 1 || weekday == 7

        // Every number is drawn on every day, used or not, so each value depends only on the seed and the date.
        let baseSteps = random.uniform(5_400...9_600)
        let weekendSteps = random.uniform(800...2_800)
        let lightExercise = random.uniform(6...20)
        let baseEnergy = random.uniform(60...110)
        let standHours = Double(random.integer(9...13))
        let resting = random.uniform(54...61).rounded()
        let variability = random.uniform(36...64).rounded()
        let hasWorkout = random.chance(isWeekend ? 0.75 : 0.55)
        let activity = Self.workoutActivities[random.integer(0...(Self.workoutActivities.count - 1))]
        let workoutMinutes = random.uniform(24...56).rounded()
        let morning = random.chance(0.45)
        let startMinute = random.uniform(0...60).rounded() + (morning ? 390 : 1_050)
        let workoutID = random.uuid()

        let profile = Self.profile(for: activity)
        let workoutStart = start.addingTimeInterval(startMinute * 60)
        let workoutEnd = workoutStart.addingTimeInterval(workoutMinutes * 60)
        var workout: Workout?
        if hasWorkout && workoutEnd <= current {
            workout = Workout(
                id: workoutID,
                activity: activity,
                start: workoutStart,
                end: workoutEnd,
                activeEnergy: (workoutMinutes * profile.energyPerMinute).rounded(),
                distance: profile.metersPerMinute > 0 ? (workoutMinutes * profile.metersPerMinute).rounded() : nil
            )
        }

        let share = progress(ofDayStarting: start)
        let walkingSteps = (baseSteps + (isWeekend ? weekendSteps : 0)) * share
        let workoutSteps = workout == nil ? 0 : workoutMinutes * profile.stepsPerMinute
        let energy = walkingSteps * 0.034 + (lightExercise * 4.5 + baseEnergy) * share + (workout?.activeEnergy ?? 0)
        let exercise = (lightExercise * share).rounded() + (workout == nil ? 0 : workoutMinutes)
        return Day(
            start: start,
            steps: (walkingSteps + workoutSteps).rounded(),
            activeEnergy: energy.rounded(),
            exerciseMinutes: exercise,
            distance: (walkingSteps * 0.74 + (workout?.distance ?? 0)).rounded(),
            standHours: (standHours * share).rounded(.down),
            restingHeartRate: resting,
            variability: variability,
            workout: workout
        )
    }

    func dailyValue(_ metric: HealthMetric, on date: Date) -> Double? {
        guard let generated = day(date) else { return nil }
        switch metric {
        case .steps: return generated.steps
        case .activeEnergy: return generated.activeEnergy
        case .exerciseTime: return generated.exerciseMinutes
        case .walkingRunningDistance: return generated.distance
        case .heartRate: return heartRateSummary(on: date).average
        case .restingHeartRate: return generated.restingHeartRate
        case .heartRateVariability: return generated.variability
        }
    }
}
