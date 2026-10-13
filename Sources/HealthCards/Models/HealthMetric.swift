import Foundation

/// A quantity HealthCards reads as statistics over days or weeks.
///
/// Values always use the same units, whatever the data source:
///
/// | Metric | Unit |
/// | --- | --- |
/// | ``steps`` | count |
/// | ``activeEnergy`` | kilocalories |
/// | ``exerciseTime`` | minutes |
/// | ``walkingRunningDistance`` | meters |
/// | ``heartRate``, ``restingHeartRate`` | beats per minute |
/// | ``heartRateVariability`` | milliseconds (SDNN) |
public enum HealthMetric: String, Sendable, Hashable, CaseIterable, Identifiable {
    case steps
    case activeEnergy
    case exerciseTime
    case walkingRunningDistance
    case heartRate
    case restingHeartRate
    case heartRateVariability

    public var id: String { rawValue }

    /// How samples in one day or week combine: steps add up, heart rates average.
    public var aggregation: MetricAggregation {
        switch self {
        case .steps, .activeEnergy, .exerciseTime, .walkingRunningDistance:
            .sum
        case .heartRate, .restingHeartRate, .heartRateVariability:
            .average
        }
    }

    /// A short English title, such as "Steps" or "Resting Heart Rate".
    public var title: String {
        switch self {
        case .steps: "Steps"
        case .activeEnergy: "Active Energy"
        case .exerciseTime: "Exercise"
        case .walkingRunningDistance: "Distance"
        case .heartRate: "Heart Rate"
        case .restingHeartRate: "Resting Heart Rate"
        case .heartRateVariability: "Heart Rate Variability"
        }
    }

    /// An SF Symbol for the metric.
    public var symbolName: String {
        switch self {
        case .steps: "figure.walk"
        case .activeEnergy: "flame.fill"
        case .exerciseTime: "figure.run"
        case .walkingRunningDistance: "map.fill"
        case .heartRate: "heart.fill"
        case .restingHeartRate: "bed.double.fill"
        case .heartRateVariability: "waveform.path.ecg"
        }
    }
}

/// How the values in one statistics bucket combine.
public enum MetricAggregation: String, Sendable, Hashable {
    /// Values add up, and a bucket without data counts as zero.
    case sum
    /// Values are averaged, and a bucket without data is left out.
    case average
}

/// The length of one statistics bucket.
public enum StatisticsBucket: String, Sendable, Hashable, CaseIterable {
    /// Calendar days, from midnight to midnight.
    case day
    /// Calendar weeks, starting on the calendar's first weekday.
    case week

    /// The calendar component one bucket spans.
    public var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        }
    }
}

/// One value of a metric for the bucket (day or week) starting at `date`.
public struct MetricPoint: Sendable, Hashable, Identifiable {
    /// The start of the day or week.
    public var date: Date
    /// The value, in the metric's unit (see ``HealthMetric``).
    public var value: Double

    public var id: Date { date }

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}
