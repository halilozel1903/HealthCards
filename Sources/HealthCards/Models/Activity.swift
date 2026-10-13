import Foundation

/// A value and its goal, such as 412 of 500 kilocalories.
public struct RingValue: Sendable, Hashable {
    public var value: Double
    public var goal: Double

    public init(value: Double, goal: Double) {
        self.value = value
        self.goal = goal
    }

    /// `value / goal`; can be more than 1. Zero when there is no goal.
    public var progress: Double {
        guard goal > 0 else { return 0 }
        return Swift.max(0, value) / goal
    }

    /// The goal is reached.
    public var isClosed: Bool { goal > 0 && value >= goal }
}

/// Daily goals for the three activity rings.
public struct ActivityGoals: Sendable, Hashable {
    /// Active energy in kilocalories.
    public var move: Double
    /// Exercise in minutes.
    public var exercise: Double
    /// Hours with at least a minute of standing.
    public var stand: Double

    public init(move: Double, exercise: Double, stand: Double) {
        self.move = move
        self.exercise = exercise
        self.stand = stand
    }

    /// 500 kcal, 30 minutes and 12 hours.
    public static let standard = ActivityGoals(move: 500, exercise: 30, stand: 12)
}

/// A day's Move, Exercise and Stand rings.
public struct ActivityRings: Sendable, Hashable {
    /// The start of the day.
    public var date: Date
    /// Active energy in kilocalories.
    public var move: RingValue
    /// Exercise in minutes.
    public var exercise: RingValue
    /// Stand hours.
    public var stand: RingValue

    public init(date: Date, move: RingValue, exercise: RingValue, stand: RingValue) {
        self.date = date
        self.move = move
        self.exercise = exercise
        self.stand = stand
    }

    /// All three goals are reached.
    public var allClosed: Bool { move.isClosed && exercise.isClosed && stand.isClosed }
}
