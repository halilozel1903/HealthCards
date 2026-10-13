import Foundation

/// Everything the cards show for one day, loaded in one call with
/// ``HealthDataSource/snapshot(for:)``.
public struct HealthSnapshot: Sendable, Hashable {
    /// The moment the snapshot describes; "today" is the day containing it.
    public var date: Date
    /// Steps so far today.
    public var steps: Double
    /// Active energy so far today, in kilocalories.
    public var activeEnergy: Double
    /// Exercise so far today, in minutes.
    public var exerciseMinutes: Double
    /// Walking and running distance so far today, in meters.
    public var distance: Double
    /// Today's activity rings, if the source has them.
    public var rings: ActivityRings?
    /// Today's heart rate.
    public var heartRate: HeartRateSummary
    /// The night that ended this morning.
    public var lastNight: SleepNight?
    /// Up to seven nights, oldest first, ending with ``lastNight``.
    public var recentNights: [SleepNight]
    public var stepsTrend: WeeklyTrend
    public var energyTrend: WeeklyTrend
    public var exerciseTrend: WeeklyTrend
    /// Workouts of the last seven days, newest first.
    public var workouts: [Workout]

    public init(
        date: Date,
        steps: Double,
        activeEnergy: Double,
        exerciseMinutes: Double,
        distance: Double,
        rings: ActivityRings?,
        heartRate: HeartRateSummary,
        lastNight: SleepNight?,
        recentNights: [SleepNight],
        stepsTrend: WeeklyTrend,
        energyTrend: WeeklyTrend,
        exerciseTrend: WeeklyTrend,
        workouts: [Workout]
    ) {
        self.date = date
        self.steps = steps
        self.activeEnergy = activeEnergy
        self.exerciseMinutes = exerciseMinutes
        self.distance = distance
        self.rings = rings
        self.heartRate = heartRate
        self.lastNight = lastNight
        self.recentNights = recentNights
        self.stepsTrend = stepsTrend
        self.energyTrend = energyTrend
        self.exerciseTrend = exerciseTrend
        self.workouts = workouts
    }

    /// Builds a snapshot from the raw query results; both data sources go through here.
    init(
        date: Date,
        calendar: Calendar,
        stepPoints: [MetricPoint],
        energyPoints: [MetricPoint],
        exercisePoints: [MetricPoint],
        distancePoints: [MetricPoint],
        rings: ActivityRings?,
        heartRate: HeartRateSummary,
        recentNights: [SleepNight],
        workouts: [Workout]
    ) {
        let today = calendar.startOfDay(for: date)
        func todayValue(_ points: [MetricPoint]) -> Double {
            points.last { calendar.isDate($0.date, inSameDayAs: today) }?.value ?? 0
        }
        let lastNight = recentNights.last { night in
            guard let end = night.end else { return false }
            return calendar.isDate(end, inSameDayAs: today)
        }
        self.init(
            date: date,
            steps: todayValue(stepPoints),
            activeEnergy: todayValue(energyPoints),
            exerciseMinutes: todayValue(exercisePoints),
            distance: todayValue(distancePoints),
            rings: rings,
            heartRate: heartRate,
            lastNight: lastNight,
            recentNights: recentNights,
            stepsTrend: WeeklyTrend(metric: .steps, dailyPoints: stepPoints, endingOn: date, calendar: calendar),
            energyTrend: WeeklyTrend(metric: .activeEnergy, dailyPoints: energyPoints, endingOn: date, calendar: calendar),
            exerciseTrend: WeeklyTrend(metric: .exerciseTime, dailyPoints: exercisePoints, endingOn: date, calendar: calendar),
            workouts: workouts
        )
    }
}
