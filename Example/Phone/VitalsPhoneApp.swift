import HealthCards
import HealthCardsUI
import SwiftUI

@main
struct VitalsPhoneApp: App {
    @State private var model: DashboardModel

    init() {
        _model = State(initialValue: DashboardModel.make(for: ScreenshotScene.requested))
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView(scene: ScreenshotScene.requested)
                .environment(model)
                .preferredColorScheme(.dark)
        }
    }
}

/// Three tabs: today, the week and sleep. A screenshot scene opens its tab.
struct PhoneRootView: View {
    enum Tab: Hashable {
        case today
        case week
        case sleep
    }

    let scene: ScreenshotScene?

    @Environment(DashboardModel.self) private var model
    @State private var tab: Tab

    init(scene: ScreenshotScene?) {
        self.scene = scene
        let initial: Tab
        switch scene {
        case .week: initial = .week
        case .sleep: initial = .sleep
        default: initial = .today
        }
        _tab = State(initialValue: initial)
    }

    var body: some View {
        TabView(selection: $tab) {
            TodayScreen()
                .tabItem { Label("Today", systemImage: "heart.text.square") }
                .tag(Tab.today)
            WeekScreen()
                .tabItem { Label("Week", systemImage: "chart.xyaxis.line") }
                .tag(Tab.week)
            SleepScreen()
                .tabItem { Label("Sleep", systemImage: "bed.double") }
                .tag(Tab.sleep)
        }
        .tint(HealthPalette.heart)
        .task {
            if model.snapshot == nil {
                await model.load()
            }
        }
        .signalsScreenshotReady(scene, when: model.phase == .loaded)
    }
}

/// The frame of every tab: a navigation bar with an inline title and a visible background, the day with the
/// "Sample data" label when sample data is shown, and the cards in a scroll view.
struct DashboardScreen<Content: View>: View {
    let title: String
    let content: (HealthSnapshot) -> Content

    @Environment(DashboardModel.self) private var model

    init(_ title: String, @ViewBuilder content: @escaping (HealthSnapshot) -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = model.snapshot {
                    ScrollView {
                        VStack(spacing: 14) {
                            DayHeader(date: snapshot.date, isSampleData: model.isSampleData)
                            content(snapshot)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else {
                    PhoneLoadingView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DataSourceMenu()
                }
            }
        }
    }
}

/// "Friday, Oct 9" and, in sample data mode, the "Sample data" label.
struct DayHeader: View {
    let date: Date
    let isSampleData: Bool

    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        HStack {
            Text(HealthFormatter(locale: locale, calendar: calendar).day(date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if isSampleData {
                SampleDataBadge()
            }
        }
    }
}

/// Switches between the Health app's data and the built-in sample data.
struct DataSourceMenu: View {
    @Environment(DashboardModel.self) private var model

    var body: some View {
        Menu {
            Button {
                Task { await model.useSampleData(false) }
            } label: {
                Label("Health Data", systemImage: model.isSampleData ? "heart" : "checkmark")
            }
            .disabled(!model.canUseHealthKit)
            Button {
                Task { await model.useSampleData(true) }
            } label: {
                Label("Sample Data", systemImage: model.isSampleData ? "checkmark" : "testtube.2")
            }
            Divider()
            Button {
                Task { await model.load() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
        } label: {
            Label("Data Source", systemImage: "ellipsis")
        }
    }
}

/// A spinner while loading, or the error with a retry button.
struct PhoneLoadingView: View {
    @Environment(DashboardModel.self) private var model

    var body: some View {
        if case let .failed(message) = model.phase {
            ContentUnavailableView {
                Label("No Health Data", systemImage: "heart.slash")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await model.load() }
                }
                .buttonStyle(.borderedProminent)
                Button("Use Sample Data") {
                    Task { await model.useSampleData(true) }
                }
            }
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }
}
