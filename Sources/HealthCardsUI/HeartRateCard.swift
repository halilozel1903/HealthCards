import Charts
import HealthCards
import SwiftUI

/// The day's heart rate as hourly ranges, with the latest reading, the resting heart rate as a dashed line and,
/// when available, the heart rate variability.
public struct HeartRateCard: View {
    let summary: HeartRateSummary
    let hoursPerBar: Int

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    /// - Parameters:
    ///   - summary: The day's heart rate, such as ``HealthSnapshot/heartRate``.
    ///   - hoursPerBar: How many hours each range bar covers.
    public init(summary: HeartRateSummary, hoursPerBar: Int = 1) {
        self.summary = summary
        self.hoursPerBar = hoursPerBar
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        HealthCard(
            "Heart Rate",
            systemImage: HealthMetric.heartRate.symbolName,
            tint: HealthPalette.heart,
            caption: summary.latest.map { format.time($0.date) }
        ) {
            if summary.isEmpty {
                NoHealthDataText("No heart rate data today")
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 18) {
                    if let latest = summary.latest {
                        HealthValueText(format.number(latest.beatsPerMinute), unit: "bpm")
                    }
                    Spacer(minLength: 0)
                    if let resting = summary.resting {
                        HeartRateFigure(title: "Resting", value: format.heartRate(resting))
                    }
                    if let variability = summary.variability {
                        HeartRateFigure(title: "HRV", value: format.variability(milliseconds: variability))
                    }
                }
                if !summary.samples.isEmpty {
                    HeartRateRangeChart(
                        ranges: summary.ranges(hours: hoursPerBar, calendar: calendar),
                        resting: summary.resting
                    )
                    .frame(height: 130)
                    if let low = summary.minimum, let high = summary.maximum {
                        Text("Range \(format.number(low))–\(format.number(high)) bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct HeartRateFigure: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}

/// One capsule per span from the lowest to the highest heart rate.
struct HeartRateRangeChart: View {
    let ranges: [HeartRateRange]
    let resting: Double?
    var showsAxes: Bool = true

    var body: some View {
        Chart {
            ForEach(ranges) { range in
                BarMark(
                    x: .value("Time", range.start, unit: .hour),
                    yStart: .value("Lowest", range.minimum),
                    yEnd: .value("Highest", Swift.max(range.maximum, range.minimum + 2)),
                    width: .ratio(0.55)
                )
                .foregroundStyle(HealthPalette.heart)
                .cornerRadius(3)
            }
            if let resting {
                RuleMark(y: .value("Resting", resting))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(HealthPalette.heart.opacity(0.6))
            }
        }
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis(showsAxes ? .automatic : .hidden)
        .chartYAxis(showsAxes ? .automatic : .hidden)
    }

    /// Rounded to tens around the data, so the bars never touch the edges.
    private var domain: ClosedRange<Double> {
        let lows = ranges.map(\.minimum) + (resting.map { [$0] } ?? [])
        let highs = ranges.map(\.maximum) + (resting.map { [$0] } ?? [])
        let low = ((lows.min() ?? 50) - 5) / 10
        let high = ((highs.max() ?? 120) + 5) / 10
        return (low.rounded(.down) * 10)...(Swift.max(high.rounded(.up), low.rounded(.down) + 1) * 10)
    }
}
