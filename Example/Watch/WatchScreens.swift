import HealthCards
import HealthCardsUI
import SwiftUI

/// The rings and today's steps.
struct WatchSummaryView: View {
    var body: some View {
        WatchPage("Summary", tint: HealthPalette.move) { snapshot in
            CompactActivityRingsCard(rings: snapshot.rings)
            CompactStepsCard(steps: snapshot.steps, week: snapshot.stepsTrend.days)
        }
    }
}

/// The latest heart rate with the day's ranges, resting heart rate and HRV.
struct WatchHeartView: View {
    var body: some View {
        WatchPage("Heart", tint: HealthPalette.heart) { snapshot in
            CompactHeartRateCard(summary: snapshot.heartRate)
        }
    }
}

/// Last night's sleep.
struct WatchSleepView: View {
    var body: some View {
        WatchPage("Sleep", tint: HealthPalette.sleep) { snapshot in
            CompactSleepCard(night: snapshot.lastNight)
        }
    }
}
