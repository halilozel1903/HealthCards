import Foundation

/// The arithmetic behind statistics collections, trends and sleep totals. Both data sources use it, so HealthKit
/// and sample data produce buckets the same way.
public enum HealthAggregation {
    /// The start of the day or week containing `date`.
    public static func bucketStart(for date: Date, bucket: StatisticsBucket, calendar: Calendar) -> Date {
        switch bucket {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        }
    }

    /// The start of every day or week that overlaps `interval`, oldest first. The first one can start before
    /// `interval.start` when the interval begins mid-day or mid-week.
    public static func bucketStarts(in interval: DateInterval, bucket: StatisticsBucket, calendar: Calendar) -> [Date] {
        var start = bucketStart(for: interval.start, bucket: bucket, calendar: calendar)
        guard interval.duration > 0 else { return [start] }
        var starts: [Date] = []
        while start < interval.end {
            starts.append(start)
            guard
                let next = calendar.date(byAdding: bucket.component, value: 1, to: start),
                next > start
            else { break }
            start = next
        }
        return starts
    }

    /// Groups `points` into the buckets of `interval` and combines each group.
    ///
    /// With ``MetricAggregation/sum`` every bucket of the interval is returned and a bucket without points is zero.
    /// With ``MetricAggregation/average`` a bucket is the mean of its points and buckets without points are left
    /// out. Points outside the interval's buckets are ignored.
    public static func normalize(
        _ points: [MetricPoint],
        aggregation: MetricAggregation,
        interval: DateInterval,
        bucket: StatisticsBucket,
        calendar: Calendar
    ) -> [MetricPoint] {
        var groups: [Date: [Double]] = [:]
        for point in points {
            groups[bucketStart(for: point.date, bucket: bucket, calendar: calendar), default: []].append(point.value)
        }
        return bucketStarts(in: interval, bucket: bucket, calendar: calendar).compactMap { start in
            let values = groups[start] ?? []
            switch aggregation {
            case .sum:
                return MetricPoint(date: start, value: values.reduce(0, +))
            case .average:
                guard !values.isEmpty else { return nil }
                return MetricPoint(date: start, value: values.reduce(0, +) / Double(values.count))
            }
        }
    }

    /// Re-buckets daily points into calendar weeks: weekly totals for a sum, the mean of the days for an average.
    public static func weekly(
        _ dailyPoints: [MetricPoint],
        aggregation: MetricAggregation,
        calendar: Calendar
    ) -> [MetricPoint] {
        guard
            let first = dailyPoints.map(\.date).min(),
            let last = dailyPoints.map(\.date).max()
        else { return [] }
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) ?? last
        return normalize(
            dailyPoints,
            aggregation: aggregation,
            interval: DateInterval(start: first, end: Swift.max(first, end)),
            bucket: .week,
            calendar: calendar
        )
    }

    /// The sum of the values.
    public static func total(_ points: [MetricPoint]) -> Double {
        points.reduce(0) { $0 + $1.value }
    }

    /// The mean of the values, or `nil` for no points.
    public static func mean(_ points: [MetricPoint]) -> Double? {
        guard !points.isEmpty else { return nil }
        return total(points) / Double(points.count)
    }

    /// The relative change from `old` to `new` (0.25 is 25% more), or `nil` when `old` is not positive.
    public static func change(from old: Double, to new: Double) -> Double? {
        guard old > 0 else { return nil }
        return (new - old) / old
    }

    /// The length of the union of the intervals, in seconds: overlapping time counts once.
    public static func unionDuration(of intervals: [DateInterval]) -> TimeInterval {
        var total: TimeInterval = 0
        var open: (start: Date, end: Date)?
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let current = open, interval.start <= current.end {
                open = (start: current.start, end: Swift.max(current.end, interval.end))
            } else {
                if let current = open {
                    total += current.end.timeIntervalSince(current.start)
                }
                open = (start: interval.start, end: interval.end)
            }
        }
        if let current = open {
            total += current.end.timeIntervalSince(current.start)
        }
        return total
    }

    /// The window searched for the night that ends on the day containing `date`: from 18:00 the evening before
    /// to 12:00 noon.
    public static func sleepWindow(endingOn date: Date, calendar: Calendar) -> DateInterval {
        let day = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .hour, value: -6, to: day) ?? day.addingTimeInterval(-6 * 3600)
        let end = calendar.date(byAdding: .hour, value: 12, to: day) ?? day.addingTimeInterval(12 * 3600)
        return DateInterval(start: start, end: Swift.max(start, end))
    }
}

extension Calendar {
    /// The day containing `date`, from midnight to midnight.
    func dayInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .day, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 86_400)
    }
}
