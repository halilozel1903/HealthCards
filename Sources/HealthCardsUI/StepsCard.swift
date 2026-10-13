import Charts
import HealthCards
import SwiftUI

/// Today's steps against a goal, with a bar for each day of the week and the goal as a dashed line.
public struct StepsCard: View {
    let steps: Double
    let week: [MetricPoint]
    let goal: Double

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    /// - Parameters:
    ///   - steps: Steps so far today.
    ///   - week: Daily step counts, oldest first, such as ``WeeklyTrend/days``. Leave it empty for no chart.
    ///   - goal: The daily goal.
    public init(steps: Double, week: [MetricPoint] = [], goal: Double = 10_000) {
        self.steps = steps
        self.week = week
        self.goal = goal
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        HealthCard("Steps", systemImage: HealthMetric.steps.symbolName, tint: HealthPalette.steps, caption: "Today") {
            HealthValueText(format.steps(steps), unit: "steps")
            if goal > 0 {
                Text("\(format.percent(steps / goal)) of \(format.steps(goal))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !week.isEmpty {
                StepsWeekChart(week: week, goal: goal)
                    .frame(height: 120)
            }
        }
    }
}

struct StepsWeekChart: View {
    let week: [MetricPoint]
    let goal: Double
    var showsAxes: Bool = true

    var body: some View {
        let lastDate = week.last?.date
        Chart {
            ForEach(week) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Steps", point.value),
                    width: .ratio(0.6)
                )
                .foregroundStyle(point.date == lastDate ? HealthPalette.steps : HealthPalette.steps.opacity(0.45))
                .cornerRadius(3)
            }
            if goal > 0 {
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.secondary)
            }
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
        .chartXAxis(showsAxes ? .automatic : .hidden)
        .chartYAxis(showsAxes ? .automatic : .hidden)
    }
}
