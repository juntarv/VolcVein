import Foundation

/// What a finished attempt was worth. Pure arithmetic, no side effects.
struct RunSummary {
    let ventNumber: Int
    let riftIndex: Int
    let outcome: VentOutcome
    let moldsFilled: Int
    let moldCount: Int
    let yield: Double
    let peakPressure: Double
    let veinsCrusted: Int
    let crustsBlown: Int
    let moldsCracked: Int
    let reopenCount: Int
    let tremorsSurvived: Int
    let gasPocketsRidden: Int
    let duration: Double
    let score: Int
    let stars: Int

    var succeeded: Bool { outcome == .cast }
}

enum ScoreRules {

    /// moldsFilled × 250 + yield × 600 + leftover-pressure bonus − cracked penalty,
    /// then a speed multiplier against the vent's par time.
    static func score(moldsFilled: Int,
                      yield: Double,
                      peakPressure: Double,
                      moldsCracked: Int,
                      duration: Double,
                      parTime: Double,
                      riftIndex: Int,
                      succeeded: Bool) -> Int {
        guard succeeded else {
            // A failed run still banks what it managed to cast.
            return max(0, moldsFilled * 120 + Int(yield * 200))
        }
        let base = Double(moldsFilled) * 250.0
        let yieldPart = max(0, yield) * 600.0
        let headroom = max(0, 1.0 - peakPressure) * 420.0
        let penalty = Double(moldsCracked) * 180.0
        let speed = duration <= 0 ? 1.0 : min(1.45, max(0.85, parTime / max(duration, 1)))
        let riftBonus = 1.0 + Double(riftIndex - 1) * 0.18
        let raw = (base + yieldPart + headroom - penalty) * speed * riftBonus
        return max(0, Int(raw.rounded()))
    }

    /// 1 — every mold cast. 2 — yield at or above 90%. 3 — nothing crusted shut.
    static func stars(succeeded: Bool, yield: Double, veinsCrusted: Int) -> Int {
        guard succeeded else { return 0 }
        var s = 1
        if yield >= 0.90 { s += 1 }
        if veinsCrusted == 0 { s += 1 }
        return s
    }

    static func summarise(run: VentRun, outcome: VentOutcome) -> RunSummary {
        let succeeded = outcome == .cast
        let yield = run.yieldFraction
        let stars = stars(succeeded: succeeded, yield: yield, veinsCrusted: run.veinsCrusted)
        let score = score(moldsFilled: run.moldsFilled,
                          yield: yield,
                          peakPressure: run.peakPressure,
                          moldsCracked: run.moldsCracked,
                          duration: run.elapsed,
                          parTime: run.layout.parTime,
                          riftIndex: run.layout.riftIndex,
                          succeeded: succeeded)
        return RunSummary(ventNumber: run.layout.ventNumber,
                          riftIndex: run.layout.riftIndex,
                          outcome: outcome,
                          moldsFilled: run.moldsFilled,
                          moldCount: run.layout.moldCount,
                          yield: yield,
                          peakPressure: run.peakPressure,
                          veinsCrusted: run.veinsCrusted,
                          crustsBlown: run.crustsBlown,
                          moldsCracked: run.moldsCracked,
                          reopenCount: run.reopenCount,
                          tremorsSurvived: run.tremorsSurvived,
                          gasPocketsRidden: run.gasPocketsRidden,
                          duration: run.elapsed,
                          score: score,
                          stars: stars)
    }
}
