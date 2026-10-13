import Foundation

/// Locale-aware text for health values, built on `Measurement` and Foundation's format styles.
///
/// ```swift
/// let format = HealthFormatter(locale: Locale(identifier: "de_DE"))
/// format.steps(8432)                  // "8.432"
/// format.distance(meters: 5000)       // "5 km" (miles in the US)
/// HealthFormatter(locale: Locale(identifier: "en_US")).duration(26_460)   // "7h 21m"
/// ```
public struct HealthFormatter: Sendable {
    public var locale: Locale
    public var calendar: Calendar

    /// The calendar's time zone is used for times and weekdays.
    public init(locale: Locale = .autoupdatingCurrent, calendar: Calendar = .autoupdatingCurrent) {
        self.locale = locale
        self.calendar = calendar
    }

    // MARK: Numbers

    /// A plain number with grouping, such as "8,432".
    public func number(_ value: Double, fractionDigits: Int = 0) -> String {
        let digits = Swift.max(0, fractionDigits)
        return value.formatted(FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(digits)))
    }

    /// A step count, such as "8,432".
    public func steps(_ count: Double) -> String {
        number(count.rounded())
    }

    /// A share as a percentage, such as "62%".
    public func percent(_ fraction: Double) -> String {
        fraction.formatted(FloatingPointFormatStyle<Double>.Percent(locale: locale).precision(.fractionLength(0)))
    }

    /// A change with its sign, such as "+12%", "−5%" or "0%".
    public func change(_ fraction: Double) -> String {
        let text = percent(Swift.abs(fraction))
        if fraction >= 0.005 {
            return "+" + text
        } else if fraction <= -0.005 {
            return "\u{2212}" + text
        }
        return percent(0)
    }

    // MARK: Measurements

    /// Active energy, such as "412 kcal".
    public func energy(kilocalories: Double) -> String {
        let style = Measurement<UnitEnergy>.FormatStyle(
            width: .abbreviated,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: wholeNumbers
        )
        return Measurement(value: kilocalories.rounded(), unit: UnitEnergy.kilocalories).formatted(style)
    }

    /// Minutes, such as "32 min".
    public func minutes(_ minutes: Double) -> String {
        let style = Measurement<UnitDuration>.FormatStyle(
            width: .abbreviated,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: wholeNumbers
        )
        return Measurement(value: minutes.rounded(), unit: UnitDuration.minutes).formatted(style)
    }

    /// Hours, such as "9 hr" for stand hours.
    public func hours(_ hours: Double) -> String {
        let style = Measurement<UnitDuration>.FormatStyle(
            width: .abbreviated,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: wholeNumbers
        )
        return Measurement(value: hours.rounded(), unit: UnitDuration.hours).formatted(style)
    }

    /// A walking or running distance in the locale's road unit: "3.1 mi" in the US, "5 km" in Germany.
    public func distance(meters: Double) -> String {
        let style = Measurement<UnitLength>.FormatStyle(
            width: .abbreviated,
            locale: locale,
            usage: .road,
            numberFormatStyle: FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(0...1))
        )
        return Measurement(value: meters, unit: UnitLength.meters).formatted(style)
    }

    /// A heart rate, such as "62 bpm".
    public func heartRate(_ beatsPerMinute: Double) -> String {
        number(beatsPerMinute) + " bpm"
    }

    /// Heart rate variability, such as "48 ms".
    public func variability(milliseconds: Double) -> String {
        let style = Measurement<UnitDuration>.FormatStyle(
            width: .abbreviated,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: wholeNumbers
        )
        return Measurement(value: milliseconds.rounded(), unit: UnitDuration.milliseconds).formatted(style)
    }

    /// A length of time in hours and minutes, such as "7h 21m". Seconds are rounded to the minute.
    public func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = self.calendar
        calendar.locale = locale
        formatter.calendar = calendar
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        let rounded = (Swift.max(0, seconds) / 60).rounded() * 60
        return formatter.string(from: rounded) ?? minutes(rounded / 60)
    }

    /// The value of a metric in its unit, such as "8,432", "412 kcal" or "58 bpm".
    public func value(_ value: Double, for metric: HealthMetric) -> String {
        switch metric {
        case .steps: steps(value)
        case .activeEnergy: energy(kilocalories: value)
        case .exerciseTime: minutes(value)
        case .walkingRunningDistance: distance(meters: value)
        case .heartRate, .restingHeartRate: heartRate(value)
        case .heartRateVariability: variability(milliseconds: value)
        }
    }

    // MARK: Dates

    /// An abbreviated weekday, such as "Fri".
    public func weekday(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.abbreviated))
    }

    /// A short time, such as "6:48 AM".
    public func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(
            date: .omitted,
            time: .shortened,
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        ))
    }

    /// A day for a header, such as "Friday, Oct 9".
    public func day(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.wide).month(.abbreviated).day())
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }

    private var wholeNumbers: FloatingPointFormatStyle<Double> {
        FloatingPointFormatStyle<Double>(locale: locale).precision(.fractionLength(0))
    }
}
