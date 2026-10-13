import HealthCards
import SwiftUI

/// The colors of the cards, close to the ones the Health and Fitness apps use.
public enum HealthPalette {
    public static let move = Color(red: 0.98, green: 0.07, blue: 0.31)
    public static let exercise = Color(red: 0.62, green: 0.96, blue: 0.0)
    public static let stand = Color(red: 0.0, green: 0.86, blue: 0.94)
    public static let steps = Color(red: 1.0, green: 0.42, blue: 0.16)
    public static let energy = Color(red: 1.0, green: 0.27, blue: 0.23)
    public static let heart = Color(red: 1.0, green: 0.22, blue: 0.37)
    public static let sleep = Color(red: 0.36, green: 0.42, blue: 0.98)
    public static let distance = Color(red: 0.2, green: 0.67, blue: 1.0)
    public static let variability = Color(red: 0.4, green: 0.8, blue: 1.0)

    /// The background of a card.
    public static var cardBackground: Color {
        #if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(watchOS)
        return Color.white.opacity(0.11)
        #else
        return Color.primary.opacity(0.06)
        #endif
    }

    /// The faint track behind a ring or a bar.
    public static func track(_ color: Color) -> Color {
        color.opacity(0.22)
    }
}

extension HealthMetric {
    /// The metric's color in the cards.
    public var color: Color {
        switch self {
        case .steps: HealthPalette.steps
        case .activeEnergy: HealthPalette.move
        case .exerciseTime: HealthPalette.exercise
        case .walkingRunningDistance: HealthPalette.distance
        case .heartRate, .restingHeartRate: HealthPalette.heart
        case .heartRateVariability: HealthPalette.variability
        }
    }
}

extension SleepStage {
    /// The stage's color in the sleep charts.
    public var color: Color {
        switch self {
        case .awake: Color(red: 1.0, green: 0.47, blue: 0.35)
        case .rem: Color(red: 0.36, green: 0.8, blue: 1.0)
        case .core: Color(red: 0.2, green: 0.5, blue: 1.0)
        case .deep: Color(red: 0.36, green: 0.25, blue: 0.86)
        case .unspecified: Color(red: 0.27, green: 0.62, blue: 1.0)
        case .inBed: Color.gray
        }
    }
}
