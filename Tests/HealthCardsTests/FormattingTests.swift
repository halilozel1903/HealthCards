import Foundation
import Testing
@testable import HealthCards

@Suite("Formatting")
struct FormattingTests {
    let us = HealthFormatter(locale: Locale(identifier: "en_US"), calendar: utc)
    let germany = HealthFormatter(locale: Locale(identifier: "de_DE"), calendar: utc)

    @Test("Step counts use the locale's grouping")
    func steps() {
        #expect(us.steps(8_432) == "8,432")
        #expect(us.steps(8_431.6) == "8,432")
        #expect(germany.steps(8_432) == "8.432")
        #expect(us.steps(0) == "0")
    }

    @Test("Energy is in kilocalories")
    func energy() {
        let text = us.energy(kilocalories: 412.4)
        #expect(text.contains("412"))
        #expect(text.contains("kcal"))
    }

    @Test("Distance follows the locale's road unit")
    func distance() {
        let american = us.distance(meters: 5_000)
        let german = germany.distance(meters: 5_000)
        #expect(american.contains("mi"))
        #expect(american.contains("3.1"))
        #expect(german.contains("km"))
        #expect(german.contains("5"))
    }

    @Test("Heart rate, variability and minutes")
    func heartAndTime() {
        #expect(us.heartRate(61.6) == "62 bpm")
        #expect(us.variability(milliseconds: 47.8).contains("48"))
        #expect(us.variability(milliseconds: 47.8).contains("ms"))
        #expect(us.minutes(32).contains("32"))
        #expect(us.minutes(32).contains("min"))
    }

    @Test("Durations show hours and minutes")
    func duration() {
        let text = us.duration(7 * 3600 + 21 * 60 + 20)
        #expect(text.contains("7"))
        #expect(text.contains("21"))
        #expect(!text.contains("20"))
        #expect(us.duration(45 * 60).contains("45"))
    }

    @Test("Changes carry a sign")
    func change() {
        #expect(us.change(0.123) == "+12%")
        #expect(us.change(-0.05) == "\u{2212}5%")
        #expect(us.change(0.001) == "0%")
        #expect(us.percent(0.62) == "62%")
    }

    @Test("Weekdays and days follow the locale")
    func dates() {
        let friday = date(2026, 10, 9, 18, 30)
        #expect(us.weekday(friday) == "Fri")
        #expect(germany.weekday(friday).hasPrefix("Fr"))
        #expect(us.day(friday).contains("Friday"))
        #expect(us.day(friday).contains("Oct"))
        #expect(us.time(friday).contains("6:30"))
        #expect(germany.time(friday).contains("18:30"))
    }

    @Test("Each metric formats in its unit")
    func metricValues() {
        #expect(us.value(8_432, for: .steps) == "8,432")
        #expect(us.value(58, for: .restingHeartRate) == "58 bpm")
        #expect(us.value(500, for: .activeEnergy).contains("kcal"))
        #expect(us.value(30, for: .exerciseTime).contains("min"))
    }
}
