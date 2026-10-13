import Charts
import HealthCards
import SwiftUI

// Smaller cards for Apple Watch (or widgets and tight spaces): fewer labels, smaller charts, no axes.

/// Steps and progress towards the goal, with a bar per day when a week is given.
public struct CompactStepsCard: View {
    let steps: Double
    let week: [MetricPoint]
    let goal: Double

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    public init(steps: Double, week: [MetricPoint] = [], goal: Double = 10_000) {
        self.steps = steps
        self.week = week
        self.goal = goal
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        CompactHealthCard("Steps", systemImage: HealthMetric.steps.symbolName, tint: HealthPalette.steps) {
            HealthValueText(format.steps(steps), size: 22)
            if goal > 0 {
                ProgressView(value: Swift.min(Swift.max(steps / goal, 0), 1))
                    .tint(HealthPalette.steps)
            }
            if !week.isEmpty {
                StepsWeekChart(week: week, goal: goal, showsAxes: false)
                    .frame(height: 36)
            }
        }
    }
}

/// The latest heart rate, the resting heart rate and small range bars for the day.
public struct CompactHeartRateCard: View {
    let summary: HeartRateSummary

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    public init(summary: HeartRateSummary) {
        self.summary = summary
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        CompactHealthCard("Heart Rate", systemImage: HealthMetric.heartRate.symbolName, tint: HealthPalette.heart) {
            if summary.isEmpty {
                NoHealthDataText("No data today")
            } else {
                HStack(alignment: .lastTextBaseline) {
                    if let latest = summary.latest {
                        HealthValueText(format.number(latest.beatsPerMinute), unit: "bpm", size: 22)
                    }
                    Spacer(minLength: 0)
                    if let latest = summary.latest {
                        Text(format.time(latest.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !summary.samples.isEmpty {
                    HeartRateRangeChart(
                        ranges: summary.ranges(hours: 2, calendar: calendar),
                        resting: summary.resting,
                        showsAxes: false
                    )
                    .frame(height: 50)
                }
                HStack {
                    if let resting = summary.resting {
                        CompactFigure(title: "Resting", value: format.heartRate(resting))
                    }
                    Spacer(minLength: 0)
                    if let variability = summary.variability {
                        CompactFigure(title: "HRV", value: format.variability(milliseconds: variability))
                    }
                }
            }
        }
    }
}

/// Time asleep and a small stage timeline.
public struct CompactSleepCard: View {
    let night: SleepNight?

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    public init(night: SleepNight?) {
        self.night = night
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        CompactHealthCard("Sleep", systemImage: "bed.double.fill", tint: HealthPalette.sleep) {
            if let night, !night.segments.isEmpty {
                HealthValueText(format.duration(night.asleepDuration), size: 22)
                SleepStageChart(night: night, showsAxes: false)
                    .frame(height: 54)
                HStack(spacing: 4) {
                    ForEach(night.stageDurations.filter { $0.stage != .awake }) { item in
                        CompactFigure(title: item.stage.title, value: format.duration(item.duration), color: item.stage.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                NoHealthDataText("No sleep data")
            }
        }
    }
}

/// The rings with their three values beside them.
public struct CompactActivityRingsCard: View {
    let rings: ActivityRings?

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    public init(rings: ActivityRings?) {
        self.rings = rings
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        CompactHealthCard("Activity", systemImage: "flame.fill", tint: HealthPalette.move) {
            if let rings {
                HStack(spacing: 10) {
                    ActivityRingsView(rings: rings, lineWidthRatio: 0.13)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        RingLegendRow(
                            title: "Move",
                            value: format.energy(kilocalories: rings.move.value),
                            color: HealthPalette.move,
                            compact: true
                        )
                        RingLegendRow(
                            title: "Exercise",
                            value: format.minutes(rings.exercise.value),
                            color: HealthPalette.exercise,
                            compact: true
                        )
                        RingLegendRow(
                            title: "Stand",
                            value: format.hours(rings.stand.value),
                            color: HealthPalette.stand,
                            compact: true
                        )
                    }
                    Spacer(minLength: 0)
                }
            } else {
                NoHealthDataText("No activity data")
            }
        }
    }
}

struct CompactFigure: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}
