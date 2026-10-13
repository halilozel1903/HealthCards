import Foundation
import Testing
@testable import HealthCards

@Suite("Sample data")
struct SampleDataTests {
    /// Friday 9 October 2026, 18:30 UTC.
    let now = date(2026, 10, 9, 18, 30)

    func source(seed: UInt64 = 1903) -> SampleHealthDataSource {
        SampleHealthDataSource(seed: seed, calendar: utc, now: now)
    }

    var fortnight: DateInterval {
        DateInterval(start: date(2026, 9, 26), end: date(2026, 10, 10))
    }

    @Test("The same seed gives the same data")
    func deterministic() async throws {
        let first = source()
        let second = source()
        for metric in HealthMetric.allCases {
            let a = try await first.statistics(metric, in: fortnight, bucket: .day)
            let b = try await second.statistics(metric, in: fortnight, bucket: .day)
            #expect(a == b, "\(metric) differs")
        }
        #expect(first.night(endingOn: now) == second.night(endingOn: now))
        #expect(first.heartRateSummary(on: now) == second.heartRateSummary(on: now))
        #expect(first.workoutList(in: fortnight) == second.workoutList(in: fortnight))
        #expect(first.makeSnapshot() == second.makeSnapshot())
    }

    @Test("Another seed gives other data")
    func seedMatters() {
        let a = source(seed: 1).points(.steps, in: fortnight, bucket: .day)
        let b = source(seed: 2).points(.steps, in: fortnight, bucket: .day)
        #expect(a != b)
    }

    @Test("A day has the same values whatever range it is asked for in")
    func rangeIndependent() {
        let sample = source()
        let wide = sample.points(.steps, in: fortnight, bucket: .day)
        let single = sample.points(.steps, in: DateInterval(start: date(2026, 10, 1), end: date(2026, 10, 2)), bucket: .day)
        let match = wide.first { $0.date == date(2026, 10, 1) }
        #expect(single.count == 1)
        #expect(match == single.first)
    }

    @Test("Past days do not change as time goes on")
    func pastIsStable() {
        let earlier = SampleHealthDataSource(seed: 7, calendar: utc, now: date(2026, 10, 9, 8))
        let later = SampleHealthDataSource(seed: 7, calendar: utc, now: date(2026, 10, 12, 20))
        let week = DateInterval(start: date(2026, 10, 2), end: date(2026, 10, 9))
        #expect(earlier.points(.activeEnergy, in: week, bucket: .day) == later.points(.activeEnergy, in: week, bucket: .day))
        #expect(earlier.night(endingOn: date(2026, 10, 5)) == later.night(endingOn: date(2026, 10, 5)))
    }

    @Test("Values are plausible")
    func plausible() {
        let sample = source()
        let fullDays = DateInterval(start: date(2026, 9, 26), end: date(2026, 10, 9))
        for point in sample.points(.steps, in: fullDays, bucket: .day) {
            #expect((4_000...25_000).contains(point.value), "steps \(point.value)")
        }
        for point in sample.points(.activeEnergy, in: fullDays, bucket: .day) {
            #expect((150...1_400).contains(point.value), "energy \(point.value)")
        }
        for point in sample.points(.restingHeartRate, in: fullDays, bucket: .day) {
            #expect((50...65).contains(point.value), "resting \(point.value)")
        }
        for point in sample.points(.heartRateVariability, in: fullDays, bucket: .day) {
            #expect((30...70).contains(point.value), "variability \(point.value)")
        }
        let heart = sample.heartRateSummary(on: date(2026, 10, 8))
        #expect(heart.samples.count == 288)
        #expect((40...190).contains(heart.minimum ?? 0))
        #expect((40...190).contains(heart.maximum ?? 0))
    }

    @Test("Nights have realistic stages")
    func nights() throws {
        let sample = source()
        for day in 1...9 {
            let night = try #require(sample.night(endingOn: date(2026, 10, day)))
            let hours = night.asleepDuration / 3600
            #expect((5.5...9.5).contains(hours), "asleep \(hours) h")
            #expect(night.hasStages)
            #expect(night.duration(of: .deep) > 0)
            #expect(night.duration(of: .rem) > 0)
            #expect(night.timeInBed >= night.asleepDuration)
            let start = try #require(night.start)
            let end = try #require(night.end)
            let bedtimeHour = utc.component(.hour, from: start)
            let wakeHour = utc.component(.hour, from: end)
            #expect(bedtimeHour >= 22 || bedtimeHour == 0, "bedtime hour \(bedtimeHour)")
            #expect((4...10).contains(wakeHour), "wake hour \(wakeHour)")
        }
    }

    @Test("Nothing exists after now")
    func endsAtNow() async throws {
        let sample = source()
        #expect(sample.night(endingOn: date(2026, 10, 10)) == nil)
        #expect(sample.rings(on: date(2026, 10, 10)) == nil)
        #expect(sample.heartRateSummary(on: date(2026, 10, 10)).isEmpty)
        let today = sample.heartRateSummary(on: now)
        #expect(today.samples.allSatisfy { $0.date <= now })
        // Every five minutes from midnight to 18:30, inclusive.
        let expectedSamples: Int = 18 * 12 + 6 + 1
        #expect(today.samples.count == expectedSamples)
        let workouts = try await sample.workouts(in: DateInterval(start: date(2026, 10, 9), end: date(2026, 10, 11)))
        #expect(workouts.allSatisfy { $0.end <= now })
    }

    @Test("Today is only partly done")
    func todayIsPartial() {
        let morning = SampleHealthDataSource(seed: 5, calendar: utc, now: date(2026, 10, 9, 6))
        let evening = SampleHealthDataSource(seed: 5, calendar: utc, now: date(2026, 10, 9, 23))
        let day = DateInterval(start: date(2026, 10, 9), end: date(2026, 10, 10))
        let early = morning.points(.steps, in: day, bucket: .day).first?.value ?? -1
        let late = evening.points(.steps, in: day, bucket: .day).first?.value ?? -1
        #expect(early == 0)
        #expect(late > 4_000)
    }

    @Test("Weekly buckets add up the days")
    func weeklyStatistics() {
        let sample = source()
        let interval = DateInterval(start: date(2026, 9, 28), end: date(2026, 10, 5))
        let days = sample.points(.steps, in: interval, bucket: .day)
        let weeks = sample.points(.steps, in: interval, bucket: .week)
        #expect(days.count == 7)
        #expect(weeks.count == 1)
        #expect(weeks.first?.value == HealthAggregation.total(days))
    }

    @Test("The snapshot matches the individual queries")
    func snapshot() async throws {
        let sample = source()
        let snapshot = try await sample.snapshot(for: now)
        #expect(snapshot == sample.makeSnapshot(for: now))
        #expect(snapshot.stepsTrend.days.count == 7)
        #expect(snapshot.stepsTrend.previousDays.count == 7)
        #expect(snapshot.steps == snapshot.stepsTrend.days.last?.value)
        #expect(snapshot.rings?.move.value == snapshot.activeEnergy)
        #expect(snapshot.lastNight != nil)
        #expect(snapshot.lastNight == snapshot.recentNights.last)
        #expect(snapshot.recentNights.count == 7)
        #expect(snapshot.workouts.allSatisfy { $0.start >= date(2026, 10, 3) })
        #expect(sample.isSampleData)
    }

    @Test("Sample workouts keep their identity")
    func workoutIdentity() {
        let a = source().workoutList(in: fortnight)
        let b = source().workoutList(in: fortnight)
        #expect(!a.isEmpty)
        #expect(a.map(\.id) == b.map(\.id))
        #expect(Set(a.map(\.id)).count == a.count)
    }
}
