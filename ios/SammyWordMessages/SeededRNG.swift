import Foundation

/// Small, fast, seedable PRNG (mulberry32) — the Swift port of the web app's
/// `mulberry32`, used for the deterministic Map of the Day and for replaying a
/// Flag Match challenge's exact questions. Same seed → same sequence.
struct SeededRNG {
    private var state: UInt32

    init(seed: UInt32) { state = seed }

    /// Next value in `[0, 1)`.
    mutating func next() -> Double {
        state = state &+ 0x6D2B79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t = t ^ (t &+ ((t ^ (t >> 7)) &* (t | 61)))
        return Double(t ^ (t >> 14)) / 4294967296.0
    }

    /// Integer in `0..<n`.
    mutating func int(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return min(Int(next() * Double(n)), n - 1)
    }
}

/// FNV-1a 32-bit hash — turns a string (e.g. a day key) into a PRNG seed.
/// Mirrors the web app's `hashStr`.
func hashStr(_ s: String) -> UInt32 {
    var h: UInt32 = 2166136261
    for b in s.utf8 {
        h ^= UInt32(b)
        h = h &* 16777619
    }
    return h
}
