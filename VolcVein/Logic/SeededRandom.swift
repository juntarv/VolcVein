import Foundation

/// Deterministic PRNG so `-demoMode` and `-screenshotTour` produce identical
/// frames on every launch. SplitMix64.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform double in 0..<1.
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    mutating func int(below n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(unit() * Double(n)) % n
    }
}
