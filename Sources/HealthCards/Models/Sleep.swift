import Foundation

/// A sleep stage, matching HealthKit's sleep analysis values.
public enum SleepStage: String, Sendable, Hashable, CaseIterable, Identifiable {
    case inBed
    case awake
    case rem
    case core
    case deep
    /// Asleep, without stage information (older devices and third-party apps).
    case unspecified

    public var id: String { rawValue }

    /// Maps an `HKCategoryValueSleepAnalysis` raw value; `nil` for values this version does not know.
    public init?(healthKitValue: Int) {
        switch healthKitValue {
        case 0: self = .inBed
        case 1: self = .unspecified
        case 2: self = .awake
        case 3: self = .core
        case 4: self = .deep
        case 5: self = .rem
        default: return nil
        }
    }

    /// The `HKCategoryValueSleepAnalysis` raw value.
    public var healthKitValue: Int {
        switch self {
        case .inBed: 0
        case .unspecified: 1
        case .awake: 2
        case .core: 3
        case .deep: 4
        case .rem: 5
        }
    }

    /// Whether the stage counts as sleep.
    public var isAsleep: Bool {
        switch self {
        case .rem, .core, .deep, .unspecified: true
        case .inBed, .awake: false
        }
    }

    public var title: String {
        switch self {
        case .inBed: "In Bed"
        case .awake: "Awake"
        case .rem: "REM"
        case .core: "Core"
        case .deep: "Deep"
        case .unspecified: "Asleep"
        }
    }

    /// The order of the rows in a stage chart, top to bottom, as in the Health app.
    public static let chartOrder: [SleepStage] = [.awake, .rem, .core, .deep, .unspecified]
}

/// A span of time spent in one sleep stage.
public struct SleepSegment: Sendable, Hashable, Identifiable {
    public var stage: SleepStage
    public var start: Date
    public var end: Date

    /// `end` is clamped so it is never before `start`.
    public init(stage: SleepStage, start: Date, end: Date) {
        self.stage = stage
        self.start = start
        self.end = Swift.max(start, end)
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public var interval: DateInterval { DateInterval(start: start, end: end) }

    public var id: String { "\(stage.rawValue)-\(start.timeIntervalSinceReferenceDate)" }
}

/// The total time of one stage in a night.
public struct SleepStageDuration: Sendable, Hashable, Identifiable {
    public var stage: SleepStage
    public var duration: TimeInterval

    public var id: SleepStage { stage }

    public init(stage: SleepStage, duration: TimeInterval) {
        self.stage = stage
        self.duration = duration
    }
}

/// One night of sleep.
///
/// The initializer cleans up what several sources record for the same night: "in bed" spans become ``inBed``,
/// overlapping segments of the same stage are merged, and when any segment has stage information, segments
/// without it are dropped so a night is not counted twice. Durations are computed from the union of the spans,
/// so overlaps never add up to more time than passed.
public struct SleepNight: Sendable, Hashable, Identifiable {
    /// The stage segments (never ``SleepStage/inBed``), ordered by start.
    public let segments: [SleepSegment]
    /// From the first "in bed" sample to the last one, if any were recorded.
    public let inBed: DateInterval?

    public init(segments: [SleepSegment]) {
        let bed = segments.filter { $0.stage == .inBed && $0.duration > 0 }
        var stages = segments.filter { $0.stage != .inBed && $0.duration > 0 }
        if stages.contains(where: { $0.stage == .rem || $0.stage == .core || $0.stage == .deep }) {
            stages.removeAll { $0.stage == .unspecified }
        }
        self.segments = Self.merged(stages)
        if let first = bed.map(\.start).min(), let last = bed.map(\.end).max() {
            inBed = DateInterval(start: first, end: last)
        } else {
            inBed = nil
        }
    }

    /// Merges overlapping or touching segments of the same stage.
    static func merged(_ segments: [SleepSegment]) -> [SleepSegment] {
        var result: [SleepSegment] = []
        for stage in SleepStage.allCases {
            let sorted = segments.filter { $0.stage == stage }.sorted { $0.start < $1.start }
            var current: SleepSegment?
            for segment in sorted {
                if var open = current, segment.start <= open.end {
                    open.end = Swift.max(open.end, segment.end)
                    current = open
                } else {
                    if let open = current {
                        result.append(open)
                    }
                    current = segment
                }
            }
            if let open = current {
                result.append(open)
            }
        }
        return result.sorted { $0.start < $1.start || ($0.start == $1.start && $0.end < $1.end) }
    }

    public var id: Date { start ?? inBed?.start ?? .distantPast }

    public var isEmpty: Bool { segments.isEmpty && inBed == nil }

    /// The start of the first stage segment.
    public var start: Date? { segments.map(\.start).min() }

    /// The end of the last stage segment: the wake-up time.
    public var end: Date? { segments.map(\.end).max() }

    /// Whether the night has REM, core or deep segments rather than plain "asleep".
    public var hasStages: Bool { segments.contains { $0.stage == .rem || $0.stage == .core || $0.stage == .deep } }

    /// Time asleep in any stage, in seconds.
    public var asleepDuration: TimeInterval {
        HealthAggregation.unionDuration(of: segments.filter(\.stage.isAsleep).map(\.interval))
    }

    /// Time in bed in seconds: the recorded "in bed" span, or else from the first to the last segment.
    public var timeInBed: TimeInterval {
        if let inBed {
            return inBed.duration
        }
        guard let start, let end else { return 0 }
        return end.timeIntervalSince(start)
    }

    /// Time spent in one stage, in seconds.
    public func duration(of stage: SleepStage) -> TimeInterval {
        if stage == .inBed {
            return timeInBed
        }
        return HealthAggregation.unionDuration(of: segments.filter { $0.stage == stage }.map(\.interval))
    }

    /// The stages present in the night, in ``SleepStage/chartOrder``.
    public var stages: [SleepStage] {
        SleepStage.chartOrder.filter { stage in segments.contains { $0.stage == stage } }
    }

    /// The time in each present stage, in ``SleepStage/chartOrder``.
    public var stageDurations: [SleepStageDuration] {
        stages.map { SleepStageDuration(stage: $0, duration: duration(of: $0)) }
    }
}
