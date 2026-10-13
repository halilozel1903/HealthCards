import HealthCards
import SwiftUI

/// Recent workouts, one row each with the activity, day, duration, energy and distance.
public struct WorkoutsCard: View {
    let workouts: [Workout]
    let limit: Int

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    /// - Parameters:
    ///   - workouts: Newest first, such as ``HealthSnapshot/workouts``.
    ///   - limit: How many rows to show at most.
    public init(workouts: [Workout], limit: Int = 4) {
        self.workouts = workouts
        self.limit = limit
    }

    public var body: some View {
        let format = HealthFormatter(locale: locale, calendar: calendar)
        HealthCard("Workouts", systemImage: "figure.run", tint: HealthPalette.exercise, caption: "Last 7 days") {
            if workouts.isEmpty {
                NoHealthDataText("No workouts this week")
            } else {
                VStack(spacing: 10) {
                    ForEach(workouts.prefix(Swift.max(0, limit))) { workout in
                        WorkoutRow(workout: workout, format: format)
                    }
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let format: HealthFormatter

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.activity.symbolName)
                .font(.title3)
                .foregroundStyle(HealthPalette.exercise)
                .frame(width: 38, height: 38)
                .background(HealthPalette.track(HealthPalette.exercise), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activity.title)
                    .font(.subheadline.weight(.semibold))
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(format.weekday(workout.start))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var details: String {
        var parts = [format.duration(workout.duration)]
        if let energy = workout.activeEnergy {
            parts.append(format.energy(kilocalories: energy))
        }
        if let distance = workout.distance {
            parts.append(format.distance(meters: distance))
        }
        return parts.joined(separator: " · ")
    }
}
