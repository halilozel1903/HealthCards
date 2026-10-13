import Foundation
import HealthCards
import Observation

/// Loads a `HealthSnapshot` from HealthKit or from the sample data, and lets the user switch between them.
@MainActor
@Observable
final class DashboardModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var source: any HealthDataSource
    private(set) var snapshot: HealthSnapshot?
    private(set) var phase: Phase = .idle
    /// A fixed "now" for sample data in screenshots; `nil` uses the current time.
    private let fixedDate: Date?

    init(source: any HealthDataSource, fixedDate: Date? = nil) {
        self.source = source
        self.fixedDate = fixedDate
    }

    /// Screenshots always use sample data with a fixed date. Otherwise HealthKit, except in the simulator, which has
    /// no health data; the menu switches between the two.
    static func make(for scene: ScreenshotScene?) -> DashboardModel {
        if scene != nil {
            let date = SampleHealthDataSource.showcaseDate()
            return DashboardModel(source: SampleHealthDataSource(now: date), fixedDate: date)
        }
        #if targetEnvironment(simulator)
        return DashboardModel(source: SampleHealthDataSource())
        #else
        return DashboardModel(source: makeDefaultHealthDataSource())
        #endif
    }

    var isSampleData: Bool { source.isSampleData }

    /// Whether this device can read HealthKit at all.
    var canUseHealthKit: Bool {
        #if canImport(HealthKit) && (os(iOS) || os(watchOS))
        return HealthKitDataSource.isAvailable
        #else
        return false
        #endif
    }

    func load() async {
        phase = .loading
        let source = self.source
        let date = fixedDate ?? Date()
        do {
            if !source.isSampleData {
                try await source.requestAuthorization()
            }
            snapshot = try await source.snapshot(for: date)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Switches between HealthKit and the sample data, then reloads.
    func useSampleData(_ useSample: Bool) async {
        guard useSample != isSampleData else { return }
        if useSample || !canUseHealthKit {
            source = SampleHealthDataSource()
        } else {
            source = makeDefaultHealthDataSource()
        }
        snapshot = nil
        await load()
    }
}
