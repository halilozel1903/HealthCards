import Foundation

/// One heart rate measurement.
public struct HeartRateSample: Sendable, Hashable, Identifiable {
    public var date: Date
    public var beatsPerMinute: Double

    public var id: Date { date }

    public init(date: Date, beatsPerMinute: Double) {
        self.date = date
        self.beatsPerMinute = beatsPerMinute
    }
}

/// The lowest and highest heart rate within a span of hours, as drawn in the Health app's range chart.
public struct HeartRateRange: Sendable, Hashable, Identifiable {
    /// The start of the span.
    public var start: Date
    public var minimum: Double
    public var maximum: Double

    public var id: Date { start }

    public init(start: Date, minimum: Double, maximum: Double) {
        self.start = start
        self.minimum = minimum
        self.maximum = maximum
    }
}

/// A day of heart rate data: the measurements, the resting heart rate and, when available, the heart rate
/// variability.
public struct HeartRateSummary: Sendable, Hashable {
    /// Measurements, oldest first.
    public var samples: [HeartRateSample]
    /// Resting heart rate in beats per minute.
    public var resting: Double?
    /// Heart rate variability (SDNN) in milliseconds; `nil` when it was not read or not recorded.
    public var variability: Double?

    public init(samples: [HeartRateSample] = [], resting: Double? = nil, variability: Double? = nil) {
        self.samples = samples.sorted { $0.date < $1.date }
        self.resting = resting
        self.variability = variability
    }

    /// No measurements and no resting heart rate.
    public static let empty = HeartRateSummary()

    public var isEmpty: Bool { samples.isEmpty && resting == nil }

    /// The most recent measurement.
    public var latest: HeartRateSample? { samples.last }

    public var minimum: Double? { samples.map(\.beatsPerMinute).min() }

    public var maximum: Double? { samples.map(\.beatsPerMinute).max() }

    /// The mean of all measurements.
    public var average: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0) { $0 + $1.beatsPerMinute } / Double(samples.count)
    }

    /// The minimum and maximum of every span of `hours` hours that has measurements, oldest first. Spans start at
    /// midnight, so `hours: 2` gives 00:00, 02:00, 04:00 and so on.
    public func ranges(hours: Int = 1, calendar: Calendar = .current) -> [HeartRateRange] {
        let width = Swift.max(1, hours)
        var groups: [Date: (low: Double, high: Double)] = [:]
        for sample in samples {
            let start = Self.spanStart(for: sample.date, hours: width, calendar: calendar)
            let bpm = sample.beatsPerMinute
            if let existing = groups[start] {
                groups[start] = (Swift.min(existing.low, bpm), Swift.max(existing.high, bpm))
            } else {
                groups[start] = (bpm, bpm)
            }
        }
        return groups
            .map { HeartRateRange(start: $0.key, minimum: $0.value.low, maximum: $0.value.high) }
            .sorted { $0.start < $1.start }
    }

    static func spanStart(for date: Date, hours: Int, calendar: Calendar) -> Date {
        let hourStart = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        let offset = calendar.component(.hour, from: hourStart) % hours
        return calendar.date(byAdding: .hour, value: -offset, to: hourStart) ?? hourStart
    }
}
