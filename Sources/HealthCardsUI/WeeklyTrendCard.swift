import Charts
import HealthCards
import SwiftUI

/// A metric over the last seven days: the daily average, the change against the week before, and a line with the
/// average as a dashed rule.
public struct WeeklyTrendCard: View {
    let trend: WeeklyTrend

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    /// - Parameter trend: Such as ``HealthSnapshot/stepsTrend`` or the result of
    ///   ``HealthDataSource/weeklyTrend(_:endingOn:)``.
    public init(trend: WeeklyTrend) {
        self.trend = trend
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        let metric = trend.metric
        HealthCard(metric.title, systemImage: metric.symbolName, tint: metric.color, caption: "Last 7 days") {
            if trend.days.isEmpty {
                NoHealthDataText("No data this week")
            } else {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HealthValueText(format.value(trend.average, for: metric), size: 24)
                    }
                    Spacer(minLength: 8)
                    if let change = trend.change {
                        TrendChangeLabel(change: change, text: format.change(change))
                    }
                }
                WeeklyTrendChart(trend: trend)
                    .frame(height: 120)
            }
        }
    }
}

/// "+12% vs last week" with an arrow.
struct TrendChangeLabel: View {
    let change: Double
    let text: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Label(text, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text("vs last week")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var symbol: String {
        if change >= 0.005 {
            return "arrow.up.right"
        } else if change <= -0.005 {
            return "arrow.down.right"
        }
        return "arrow.right"
    }
}

struct WeeklyTrendChart: View {
    let trend: WeeklyTrend

    var body: some View {
        let color = trend.metric.color
        Chart {
            ForEach(trend.days) { point in
                AreaMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value(trend.metric.title, point.value)
                )
                .foregroundStyle(
                    LinearGradient(colors: [color.opacity(0.35), color.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value(trend.metric.title, point.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value(trend.metric.title, point.value)
                )
                .foregroundStyle(color)
                .symbolSize(24)
            }
            RuleMark(y: .value("Average", trend.average))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(Color.secondary)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
    }
}
