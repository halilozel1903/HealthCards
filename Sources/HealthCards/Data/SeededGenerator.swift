import Foundation

/// SplitMix64: a small, fast generator whose output depends only on its seed. The sample data uses its own
/// helpers instead of `Double.random(in:using:)`, whose algorithm the standard library may change, so the same
/// seed gives the same data on every OS version.
struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in `0..<1`.
    mutating func unit() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992 // 2^53
    }

    /// A value in `range`.
    mutating func uniform(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    /// An integer in `range`.
    mutating func integer(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    /// `true` with probability `probability`.
    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    /// A UUID made of generator output, so sample workouts keep their identity between loads.
    mutating func uuid() -> UUID {
        let high = next()
        let low = next()
        func byte(_ value: UInt64, _ index: UInt64) -> UInt8 {
            UInt8(truncatingIfNeeded: value >> (index * 8))
        }
        // Version 4 and RFC 4122 variant bits, so the UUID looks like any random one.
        let version: UInt8 = (byte(high, 6) & 0x0F) | 0x40
        let variant: UInt8 = (byte(low, 0) & 0x3F) | 0x80
        return UUID(uuid: (
            byte(high, 0), byte(high, 1), byte(high, 2), byte(high, 3),
            byte(high, 4), byte(high, 5), version, byte(high, 7),
            variant, byte(low, 1), byte(low, 2), byte(low, 3),
            byte(low, 4), byte(low, 5), byte(low, 6), byte(low, 7)
        ))
    }
}
