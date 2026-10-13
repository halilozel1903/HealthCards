import HealthCards
import SwiftUI

/// Three concentric rings for Move, Exercise and Stand. A ring past its goal keeps going round, a bit darker.
public struct ActivityRingsView: View {
    let rings: ActivityRings
    let lineWidthRatio: CGFloat

    /// - Parameter lineWidthRatio: The width of each ring as a share of the view's size.
    public init(rings: ActivityRings, lineWidthRatio: CGFloat = 0.12) {
        self.rings = rings
        self.lineWidthRatio = lineWidthRatio
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = Swift.min(proxy.size.width, proxy.size.height)
            let lineWidth = size * lineWidthRatio
            let step = lineWidth + size * 0.015
            ZStack {
                ProgressRing(progress: rings.move.progress, color: HealthPalette.move, lineWidth: lineWidth)
                ProgressRing(progress: rings.exercise.progress, color: HealthPalette.exercise, lineWidth: lineWidth)
                    .padding(step)
                ProgressRing(progress: rings.stand.progress, color: HealthPalette.stand, lineWidth: lineWidth)
                    .padding(step * 2)
            }
            .padding(lineWidth / 2)
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity rings")
    }
}

/// One ring: a faint track and the progress on top, starting at twelve o'clock.
struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        let firstLap = Swift.min(Swift.max(progress, 0), 1)
        let secondLap = Swift.min(Swift.max(progress - 1, 0), 1)
        ZStack {
            Circle()
                .stroke(HealthPalette.track(color), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: firstLap)
                .stroke(color, style: style)
            if secondLap > 0 {
                Circle()
                    .trim(from: 0, to: secondLap)
                    .stroke(color.opacity(0.75), style: style)
                    .shadow(color: .black.opacity(0.35), radius: lineWidth / 4)
            }
        }
        .rotationEffect(.degrees(-90))
    }
}

/// Today's activity rings with the value and goal of each.
public struct ActivityRingsCard: View {
    let rings: ActivityRings?

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    /// - Parameter rings: The day's rings, such as ``HealthSnapshot/rings``; `nil` shows "No activity data".
    public init(rings: ActivityRings?) {
        self.rings = rings
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        HealthCard("Activity", systemImage: "flame.fill", tint: HealthPalette.move, caption: "Today") {
            if let rings {
                HStack(spacing: 18) {
                    ActivityRingsView(rings: rings)
                        .frame(width: 112, height: 112)
                    VStack(alignment: .leading, spacing: 8) {
                        RingLegendRow(
                            title: "Move",
                            value: "\(format.number(rings.move.value))/\(format.energy(kilocalories: rings.move.goal))",
                            color: HealthPalette.move
                        )
                        RingLegendRow(
                            title: "Exercise",
                            value: "\(format.number(rings.exercise.value))/\(format.minutes(rings.exercise.goal))",
                            color: HealthPalette.exercise
                        )
                        RingLegendRow(
                            title: "Stand",
                            value: "\(format.number(rings.stand.value))/\(format.hours(rings.stand.goal))",
                            color: HealthPalette.stand
                        )
                    }
                    Spacer(minLength: 0)
                }
            } else {
                NoHealthDataText("No activity data today")
            }
        }
    }
}

struct RingLegendRow: View {
    let title: String
    let value: String
    let color: Color
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(compact ? Font.caption2.weight(.semibold) : Font.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(compact ? .footnote : .title3, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
