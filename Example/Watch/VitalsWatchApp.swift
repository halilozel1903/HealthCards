import HealthCards
import HealthCardsUI
import SwiftUI

@main
struct VitalsWatchApp: App {
    @State private var model: DashboardModel

    init() {
        _model = State(initialValue: DashboardModel.make(for: ScreenshotScene.requested))
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(scene: ScreenshotScene.requested)
                .environment(model)
        }
    }
}

/// Vertically paged screens: summary, heart rate and sleep. A screenshot launch shows one screen on its own.
struct WatchRootView: View {
    let scene: ScreenshotScene?

    @Environment(DashboardModel.self) private var model

    var body: some View {
        Group {
            switch scene {
            case .summary:
                WatchSummaryView()
            case .heart:
                WatchHeartView()
            default:
                TabView {
                    WatchSummaryView()
                    WatchHeartView()
                    WatchSleepView()
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .task {
            if model.snapshot == nil {
                await model.load()
            }
        }
        .signalsScreenshotReady(scene, when: model.phase == .loaded)
    }
}

/// One watch page: a navigation title next to the system clock (so content never sits under the clock), the
/// "Sample data" label in sample data mode, and the cards in a scroll view.
struct WatchPage<Content: View>: View {
    let title: String
    let tint: Color
    let content: (HealthSnapshot) -> Content

    @Environment(DashboardModel.self) private var model

    init(_ title: String, tint: Color, @ViewBuilder content: @escaping (HealthSnapshot) -> Content) {
        self.title = title
        self.tint = tint
        self.content = content
    }

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = model.snapshot {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if model.isSampleData {
                                SampleDataBadge()
                            }
                            content(snapshot)
                        }
                        .padding(.top, 4)
                    }
                } else {
                    WatchLoadingView()
                }
            }
            .navigationTitle(title)
            .containerBackground(tint.opacity(0.32).gradient, for: .navigation)
        }
    }
}

/// A spinner while loading, or the error with buttons to retry or show sample data.
struct WatchLoadingView: View {
    @Environment(DashboardModel.self) private var model

    var body: some View {
        if case let .failed(message) = model.phase {
            ScrollView {
                VStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .font(.title2)
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await model.load() }
                    }
                    Button("Sample Data") {
                        Task { await model.useSampleData(true) }
                    }
                }
            }
        } else {
            ProgressView()
        }
    }
}
