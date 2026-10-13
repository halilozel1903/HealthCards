import HealthCards
import SwiftUI

/// The frame every card shares: a tinted title with a symbol, an optional trailing caption, and the content on a
/// rounded background. Use it to build cards of your own that match.
public struct HealthCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let caption: String?
    let content: Content

    public init(
        _ title: String,
        systemImage: String,
        tint: Color,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.caption = caption
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 8)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthPalette.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// The smaller frame of the compact (Apple Watch) cards.
public struct CompactHealthCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let content: Content

    public init(_ title: String, systemImage: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HealthPalette.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A large value with its unit, such as "8,432 steps".
public struct HealthValueText: View {
    let value: String
    let unit: String?
    let size: CGFloat

    public init(_ value: String, unit: String? = nil, size: CGFloat = 30) {
        self.value = value
        self.unit = unit
        self.size = size
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let unit {
                Text(unit)
                    .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// A short line shown in a card that has no data.
public struct NoHealthDataText: View {
    let message: String

    public init(_ message: String = "No data") {
        self.message = message
    }

    public var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

/// A small "Sample data" label. Show it whenever the cards display ``SampleHealthDataSource`` data, so nobody
/// mistakes it for their own.
public struct SampleDataBadge: View {
    public init() {}

    public var body: some View {
        Label("Sample data", systemImage: "testtube.2")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.yellow.opacity(0.18), in: Capsule())
            .accessibilityLabel("Showing sample data, not your health data")
    }
}
