import Foundation
import HealthCards
import SwiftUI

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
///
/// Simulators have no HealthKit data, so every scene uses the built-in sample data mode
/// (`SampleHealthDataSource`) with a fixed date, and the screens show their "Sample data" label as usual.
enum ScreenshotScene: String {
    /// iPhone: the Today tab with the rings, steps and heart rate.
    case today
    /// iPhone: the Week tab with the trends and workouts.
    case week
    /// iPhone: the Sleep tab with last night's stages and the last seven nights.
    case sleep
    /// Apple Watch: the rings and steps.
    case summary
    /// Apple Watch: the heart rate.
    case heart

    static var requested: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready` into the app
    /// container, once `isReady` is true and the frame had time to settle. Nothing animates in a screenshot scene,
    /// so the frame is final by then.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
        }
    }
}
