import Foundation

/// The last seven days of a metric next to the seven days before them.
public struct WeeklyTrend: Sendable, Hashable {
    public var metric: HealthMetric
    /// The current week's daily values, oldest first; the last one is the day the trend ends on.
    public var days: [MetricPoint]
    /// The previous week's daily values, oldest first.
    public var previousDays: [MetricPoint]

    public init(metric: HealthMetric, days: [MetricPoint], previousDays: [MetricPoint] = []) {
        self.metric = metric
        self.days = days.sorted { $0.date < $1.date }
        self.previousDays = previousDays.sorted { $0.date < $1.date }
    }

    /// Splits daily points into the `length` days ending on `date` (inclusive) and the `length` days before them.
    /// Points outside both weeks are ignored.
    public init(
        metric: HealthMetric,
        dailyPoints: [MetricPoint],
        endingOn date: Date,
        length: Int = 7,
        calendar: Calendar = .current
    ) {
        let span = Swift.max(1, length)
        let lastDay = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        let currentStart = calendar.date(byAdding: .day, value: -(span - 1), to: lastDay) ?? lastDay
        let previousStart = calendar.date(byAdding: .day, value: -span, to: currentStart) ?? currentStart
        self.init(
            metric: metric,
            days: dailyPoints.filter { $0.date >= currentStart && $0.date < end },
            previousDays: dailyPoints.filter { $0.date >= previousStart && $0.date < currentStart }
        )
    }

    /// The sum of the current week.
    public var total: Double { HealthAggregation.total(days) }

    /// The mean per day of the current week (days without data are not in ``days`` and do not count).
    public var average: Double { HealthAggregation.mean(days) ?? 0 }

    /// The mean per day of the previous week.
    public var previousAverage: Double { HealthAggregation.mean(previousDays) ?? 0 }

    /// The change of ``average`` against ``previousAverage`` as a fraction (0.12 is 12% more), or `nil` without a
    /// previous week to compare with.
    public var change: Double? {
        HealthAggregation.change(from: previousAverage, to: average)
    }

    /// The day with the highest value.
    public var best: MetricPoint? { days.max { $0.value < $1.value } }

    /// The most recent day.
    public var latest: MetricPoint? { days.last }
}
