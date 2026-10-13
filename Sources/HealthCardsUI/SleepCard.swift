import Charts
import HealthCards
import SwiftUI

/// A night of sleep: the time asleep, a bar per stage segment on a timeline (Awake, REM, Core, Deep from top to
/// bottom), and the total of each stage.
public struct SleepCard: View {
    let night: SleepNight?

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    /// - Parameter night: The night to show, such as ``HealthSnapshot/lastNight``; `nil` shows "No sleep data".
    public init(night: SleepNight?) {
        self.night = night
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        HealthCard(
            "Sleep",
            systemImage: "bed.double.fill",
            tint: HealthPalette.sleep,
            caption: night.flatMap { Self.timeRange(of: $0, format: format) }
        ) {
            if let night, !night.segments.isEmpty {
                HStack(alignment: .lastTextBaseline) {
                    HealthValueText(format.duration(night.asleepDuration))
                    Text("asleep")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if night.timeInBed > 0 {
                        HeartRateFigure(title: "In bed", value: format.duration(night.timeInBed))
                    }
                }
                SleepStageChart(night: night)
                    .frame(height: 150)
                SleepStageLegend(durations: night.stageDurations, format: format)
            } else {
                NoHealthDataText("No sleep data for last night")
            }
        }
    }

    static func timeRange(of night: SleepNight, format: HealthFormatter) -> String? {
        guard let start = night.start, let end = night.end else { return nil }
        return "\(format.time(start)) – \(format.time(end))"
    }
}

/// Every segment of the night as a bar on its stage's row.
struct SleepStageChart: View {
    let night: SleepNight
    var showsAxes: Bool = true

    var body: some View {
        let stages = night.stages
        Chart(night.segments) { segment in
            BarMark(
                xStart: .value("Start", segment.start),
                xEnd: .value("End", segment.end),
                y: .value("Stage", segment.stage.title),
                height: .ratio(0.8)
            )
            .foregroundStyle(segment.stage.color)
            .cornerRadius(2)
        }
        .chartYScale(domain: stages.map(\.title))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartXAxis(showsAxes ? .automatic : .hidden)
        .chartYAxis(showsAxes ? .automatic : .hidden)
    }
}

/// The time in each stage, as colored dots with durations.
struct SleepStageLegend: View {
    let durations: [SleepStageDuration]
    let format: HealthFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(durations) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.stage.color)
                            .frame(width: 7, height: 7)
                        Text(item.stage.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(format.duration(item.duration))
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Several nights side by side: one stacked bar per night with the hours in each stage.
public struct SleepHistoryCard: View {
    let nights: [SleepNight]

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    /// - Parameter nights: Nights, oldest first, such as ``HealthSnapshot/recentNights``.
    public init(nights: [SleepNight]) {
        self.nights = nights
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        let average = nights.isEmpty ? 0 : nights.reduce(0) { $0 + $1.asleepDuration } / Double(nights.count)
        HealthCard("Last \(nights.count) Nights", systemImage: "moon.zzz.fill", tint: HealthPalette.sleep) {
            if nights.isEmpty {
                NoHealthDataText("No sleep data")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Average asleep")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HealthValueText(format.duration(average), size: 24)
                }
                SleepHistoryChart(nights: nights)
                    .frame(height: 140)
            }
        }
    }
}

struct SleepHistoryChart: View {
    let nights: [SleepNight]

    private struct Bar: Identifiable {
        let night: Date
        let stage: SleepStage
        let hours: Double
        var id: String { "\(night.timeIntervalSinceReferenceDate)-\(stage.rawValue)" }
    }

    private var bars: [Bar] {
        nights.flatMap { night -> [Bar] in
            guard let end = night.end else { return [] }
            return night.stageDurations
                .filter { $0.stage.isAsleep }
                .map { Bar(night: end, stage: $0.stage, hours: $0.duration / 3600) }
        }
    }

    var body: some View {
        let bars = self.bars
        let present = Set(bars.map(\.stage))
        let stages: [SleepStage] = SleepStage.chartOrder.reversed().filter { present.contains($0) }
        Chart(bars) { bar in
            BarMark(
                x: .value("Night", bar.night, unit: .day),
                y: .value("Hours", bar.hours),
                width: .ratio(0.6)
            )
            .foregroundStyle(by: .value("Stage", bar.stage.title))
        }
        .chartForegroundStyleScale(domain: stages.map(\.title), range: stages.map(\.color))
        .chartLegend(position: .bottom, spacing: 8)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .stride(by: 2)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}
