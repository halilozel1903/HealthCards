import Foundation

/// The kind of a workout. HealthKit's many activity types map onto these; the rest become ``other``.
public enum WorkoutActivity: String, Sendable, Hashable, CaseIterable, Identifiable {
    case running
    case walking
    case cycling
    case swimming
    case hiking
    case yoga
    case strengthTraining
    case highIntensityIntervalTraining
    case elliptical
    case rowing
    case dance
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .running: "Running"
        case .walking: "Walking"
        case .cycling: "Cycling"
        case .swimming: "Swimming"
        case .hiking: "Hiking"
        case .yoga: "Yoga"
        case .strengthTraining: "Strength Training"
        case .highIntensityIntervalTraining: "HIIT"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .dance: "Dance"
        case .other: "Workout"
        }
    }

    /// An SF Symbol for the activity.
    public var symbolName: String {
        switch self {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .hiking: "figure.hiking"
        case .yoga: "figure.yoga"
        case .strengthTraining: "figure.strengthtraining.functional"
        case .highIntensityIntervalTraining: "figure.highintensity.intervaltraining"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .dance: "figure.dance"
        case .other: "figure.mixed.cardio"
        }
    }
}

/// A recorded workout.
public struct Workout: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var activity: WorkoutActivity
    public var start: Date
    public var end: Date
    /// Active energy in kilocalories, if recorded.
    public var activeEnergy: Double?
    /// Distance in meters, if the activity has one.
    public var distance: Double?

    public init(
        id: UUID = UUID(),
        activity: WorkoutActivity,
        start: Date,
        end: Date,
        activeEnergy: Double? = nil,
        distance: Double? = nil
    ) {
        self.id = id
        self.activity = activity
        self.start = start
        self.end = Swift.max(start, end)
        self.activeEnergy = activeEnergy
        self.distance = distance
    }

    /// The length in seconds.
    public var duration: TimeInterval { end.timeIntervalSince(start) }
}
