import HealthCards
import HealthCardsUI
import SwiftUI

/// Today: the activity rings, steps with the week's bars, and the day's heart rate.
struct TodayScreen: View {
    var body: some View {
        DashboardScreen("Today") { snapshot in
            ActivityRingsCard(rings: snapshot.rings)
            StepsCard(steps: snapshot.steps, week: snapshot.stepsTrend.days)
            HeartRateCard(summary: snapshot.heartRate)
        }
    }
}

/// The week: steps, active energy and exercise against the week before, and the latest workouts.
struct WeekScreen: View {
    var body: some View {
        DashboardScreen("This Week") { snapshot in
            WeeklyTrendCard(trend: snapshot.stepsTrend)
            WeeklyTrendCard(trend: snapshot.energyTrend)
            WeeklyTrendCard(trend: snapshot.exerciseTrend)
            WorkoutsCard(workouts: snapshot.workouts)
        }
    }
}

/// Sleep: last night's stages and the last seven nights.
struct SleepScreen: View {
    var body: some View {
        DashboardScreen("Sleep") { snapshot in
            SleepCard(night: snapshot.lastNight)
            SleepHistoryCard(nights: snapshot.recentNights)
        }
    }
}
