import Foundation
import Testing
@testable import HealthCards

/// A Gregorian calendar in UTC with Monday as the first weekday, so the tests do not depend on the machine.
let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.firstWeekday = 2
    return calendar
}()

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@Suite("Aggregation")
struct AggregationTests {
    @Test("Day buckets cover every day the interval touches")
    func dayBuckets() {
        let interval = DateInterval(start: date(2026, 10, 5, 13), end: date(2026, 10, 8))
        let starts = HealthAggregation.bucketStarts(in: interval, bucket: .day, calendar: utc)
        #expect(starts == [date(2026, 10, 5), date(2026, 10, 6), date(2026, 10, 7)])
    }

    @Test("Week buckets start on the calendar's first weekday")
    func weekBuckets() {
        // Thursday 1 October to Wednesday 21 October 2026.
        let interval = DateInterval(start: date(2026, 10, 1), end: date(2026, 10, 22))
        let starts = HealthAggregation.bucketStarts(in: interval, bucket: .week, calendar: utc)
        #expect(starts == [date(2026, 9, 28), date(2026, 10, 5), date(2026, 10, 12), date(2026, 10, 19)])
    }

    @Test("Sums fill days without data with zero")
    func sumFillsGaps() {
        let interval = DateInterval(start: date(2026, 10, 5), end: date(2026, 10, 8))
        let points = [
            MetricPoint(date: date(2026, 10, 5, 9), value: 1_200),
            MetricPoint(date: date(2026, 10, 5, 18), value: 800),
            MetricPoint(date: date(2026, 10, 7, 12), value: 5_000),
        ]
        let days = HealthAggregation.normalize(points, aggregation: .sum, interval: interval, bucket: .day, calendar: utc)
        let values: [Double] = [2_000, 0, 5_000]
        #expect(days.map(\.value) == values)
        #expect(days.map(\.date) == [date(2026, 10, 5), date(2026, 10, 6), date(2026, 10, 7)])
    }

    @Test("Averages leave out days without data")
    func averageSkipsGaps() {
        let interval = DateInterval(start: date(2026, 10, 5), end: date(2026, 10, 8))
        let points = [
            MetricPoint(date: date(2026, 10, 5, 7), value: 56),
            MetricPoint(date: date(2026, 10, 5, 22), value: 60),
            MetricPoint(date: date(2026, 10, 7, 7), value: 54),
        ]
        let days = HealthAggregation.normalize(points, aggregation: .average, interval: interval, bucket: .day, calendar: utc)
        let values: [Double] = [58, 54]
        #expect(days.map(\.value) == values)
        #expect(days.map(\.date) == [date(2026, 10, 5), date(2026, 10, 7)])
    }

    @Test("Points outside the interval are ignored")
    func outsidePointsIgnored() {
        let interval = DateInterval(start: date(2026, 10, 5), end: date(2026, 10, 6))
        let points = [
            MetricPoint(date: date(2026, 10, 4, 12), value: 9_999),
            MetricPoint(date: date(2026, 10, 5, 12), value: 10),
            MetricPoint(date: date(2026, 10, 6, 12), value: 9_999),
        ]
        let days = HealthAggregation.normalize(points, aggregation: .sum, interval: interval, bucket: .day, calendar: utc)
        #expect(days.count == 1)
        #expect(days.first?.value == 10)
    }

    @Test("Weekly totals equal the sum of the days")
    func weeklyTotals() {
        // Monday 5 October to Sunday 18 October 2026: two full weeks.
        var daily: [MetricPoint] = []
        for offset in 0..<14 {
            let day = utc.date(byAdding: .day, value: offset, to: date(2026, 10, 5))!
            daily.append(MetricPoint(date: day, value: Double(1_000 * (offset + 1))))
        }
        let weeks = HealthAggregation.weekly(daily, aggregation: .sum, calendar: utc)
        let values: [Double] = [28_000, 77_000]
        #expect(weeks.map(\.value) == values)
        #expect(weeks.map(\.date) == [date(2026, 10, 5), date(2026, 10, 12)])
        #expect(HealthAggregation.total(weeks) == HealthAggregation.total(daily))

        let averages = HealthAggregation.weekly(daily, aggregation: .average, calendar: utc)
        let means: [Double] = [4_000, 11_000]
        #expect(averages.map(\.value) == means)
    }

    @Test("Mean and change")
    func meanAndChange() {
        #expect(HealthAggregation.mean([]) == nil)
        let points = [MetricPoint(date: date(2026, 10, 5), value: 3), MetricPoint(date: date(2026, 10, 6), value: 5)]
        #expect(HealthAggregation.mean(points) == 4)
        #expect(HealthAggregation.change(from: 8_000, to: 10_000) == 0.25)
        #expect(HealthAggregation.change(from: 0, to: 10_000) == nil)
    }

    @Test("Overlapping intervals count once")
    func unionDuration() {
        let intervals = [
            DateInterval(start: date(2026, 10, 5, 1), end: date(2026, 10, 5, 3)),
            DateInterval(start: date(2026, 10, 5, 2), end: date(2026, 10, 5, 4)),
            DateInterval(start: date(2026, 10, 5, 6), end: date(2026, 10, 5, 7)),
        ]
        #expect(HealthAggregation.unionDuration(of: intervals) == 4 * 3600)
        #expect(HealthAggregation.unionDuration(of: []) == 0)
    }

    @Test("The sleep window runs from 18:00 the evening before to noon")
    func sleepWindow() {
        let window = HealthAggregation.sleepWindow(endingOn: date(2026, 10, 9, 15), calendar: utc)
        #expect(window.start == date(2026, 10, 8, 18))
        #expect(window.end == date(2026, 10, 9, 12))
    }

    @Test("A weekly trend splits two weeks and compares their averages")
    func weeklyTrend() {
        var daily: [MetricPoint] = []
        for offset in 0..<14 {
            let day = utc.date(byAdding: .day, value: offset, to: date(2026, 9, 26))!
            daily.append(MetricPoint(date: day, value: offset < 7 ? 8_000 : 10_000))
        }
        let trend = WeeklyTrend(metric: .steps, dailyPoints: daily, endingOn: date(2026, 10, 9, 18), calendar: utc)
        #expect(trend.days.count == 7)
        #expect(trend.previousDays.count == 7)
        #expect(trend.days.first?.date == date(2026, 10, 3))
        #expect(trend.days.last?.date == date(2026, 10, 9))
        #expect(trend.total == 70_000)
        #expect(trend.average == 10_000)
        #expect(trend.previousAverage == 8_000)
        #expect(trend.change == 0.25)
    }
}

@Suite("Models")
struct ModelTests {
    @Test("Sleep stages map HealthKit's raw values both ways")
    func sleepStageValues() {
        for stage in SleepStage.allCases {
            #expect(SleepStage(healthKitValue: stage.healthKitValue) == stage)
        }
        #expect(SleepStage(healthKitValue: 3) == .core)
        #expect(SleepStage(healthKitValue: 99) == nil)
    }

    @Test("A night merges overlaps, drops unstaged sleep and keeps in-bed time apart")
    func sleepNightCleanup() {
        let night = SleepNight(segments: [
            SleepSegment(stage: .inBed, start: date(2026, 10, 8, 22, 50), end: date(2026, 10, 9, 7)),
            SleepSegment(stage: .core, start: date(2026, 10, 8, 23), end: date(2026, 10, 9, 1)),
            // The same core sleep, recorded twice with an overlap.
            SleepSegment(stage: .core, start: date(2026, 10, 9, 0, 30), end: date(2026, 10, 9, 2)),
            SleepSegment(stage: .deep, start: date(2026, 10, 9, 2), end: date(2026, 10, 9, 3)),
            SleepSegment(stage: .awake, start: date(2026, 10, 9, 3), end: date(2026, 10, 9, 3, 10)),
            SleepSegment(stage: .rem, start: date(2026, 10, 9, 3, 10), end: date(2026, 10, 9, 4, 40)),
            // Plain "asleep" from another source over the same time.
            SleepSegment(stage: .unspecified, start: date(2026, 10, 8, 23), end: date(2026, 10, 9, 6)),
        ])
        #expect(night.hasStages)
        #expect(!night.segments.contains { $0.stage == .unspecified })
        #expect(night.segments.filter { $0.stage == .core }.count == 1)
        #expect(night.duration(of: .core) == 3 * 3600)
        #expect(night.duration(of: .deep) == 3600)
        #expect(night.duration(of: .rem) == 90 * 60)
        #expect(night.duration(of: .awake) == 10 * 60)
        #expect(night.asleepDuration == (3 * 3600 + 3600 + 90 * 60))
        #expect(night.timeInBed == (8 * 3600 + 10 * 60))
        #expect(night.start == date(2026, 10, 8, 23))
        #expect(night.end == date(2026, 10, 9, 4, 40))
        #expect(night.stages == [.awake, .rem, .core, .deep])
    }

    @Test("A night with only unstaged sleep keeps it")
    func unstagedNight() {
        let night = SleepNight(segments: [
            SleepSegment(stage: .unspecified, start: date(2026, 10, 8, 23), end: date(2026, 10, 9, 6, 30)),
        ])
        #expect(!night.hasStages)
        #expect(night.asleepDuration == 7.5 * 3600)
        #expect(night.timeInBed == 7.5 * 3600)
        #expect(night.stageDurations.map(\.stage) == [.unspecified])
    }

    @Test("Heart rate summary statistics and hourly ranges")
    func heartRateSummary() {
        let summary = HeartRateSummary(
            samples: [
                HeartRateSample(date: date(2026, 10, 9, 9, 40), beatsPerMinute: 90),
                HeartRateSample(date: date(2026, 10, 9, 8, 5), beatsPerMinute: 60),
                HeartRateSample(date: date(2026, 10, 9, 8, 50), beatsPerMinute: 80),
                HeartRateSample(date: date(2026, 10, 9, 9, 10), beatsPerMinute: 70),
            ],
            resting: 55,
            variability: 48
        )
        #expect(summary.latest?.beatsPerMinute == 90)
        #expect(summary.minimum == 60)
        #expect(summary.maximum == 90)
        #expect(summary.average == 75)

        let hourly = summary.ranges(hours: 1, calendar: utc)
        #expect(hourly.map(\.start) == [date(2026, 10, 9, 8), date(2026, 10, 9, 9)])
        let lows: [Double] = [60, 70]
        let highs: [Double] = [80, 90]
        #expect(hourly.map(\.minimum) == lows)
        #expect(hourly.map(\.maximum) == highs)

        let twoHourly = summary.ranges(hours: 2, calendar: utc)
        #expect(twoHourly.count == 1)
        #expect(twoHourly.first?.start == date(2026, 10, 9, 8))
        #expect(HeartRateSummary.empty.average == nil)
        #expect(HeartRateSummary.empty.isEmpty)
    }

    @Test("Ring progress")
    func ringProgress() {
        #expect(RingValue(value: 250, goal: 500).progress == 0.5)
        #expect(RingValue(value: 750, goal: 500).progress == 1.5)
        #expect(RingValue(value: 750, goal: 500).isClosed)
        #expect(RingValue(value: 10, goal: 0).progress == 0)
        #expect(!RingValue(value: 10, goal: 0).isClosed)
    }
}
