import Foundation

enum EdgeState {
    case open
    /// Shut by the player and still warm — reopening is free.
    case shut
    /// Cooled through. Only a press-and-hold blowout gets it back.
    case crusted
}

enum MoldState {
    case filling
    case cast
    case cracked
    /// Starved for too long — the magma in it set solid.
    case setSolid

    var accepts: Bool { self == .filling }
    var isFinished: Bool { self != .filling }
}

enum VentOutcome {
    case cast
    case blowout
    case choked
}

enum ValveAction {
    case shut
    case reopened
    case blownOpen
    case refused
    case none
}

/// One frame of simulation, reported back so the scene can play the right
/// effects without duplicating any rules.
struct TickReport {
    var moldsJustCast: [Int] = []
    var moldsJustCracked: [Int] = []
    var moldsJustSet: [Int] = []
    var edgesJustCrusted: [Int] = []
    var tremorEdge: Int?
    var gasBurstEdge: Int?
    var outcome: VentOutcome?
}

/// The live state of one attempt at a vent. Plain Swift — no SpriteKit, no
/// Core Data — so the rules can be reasoned about and tested on their own.
final class VentRun {

    let layout: VentLayout

    private(set) var edgeState: [EdgeState]
    private(set) var edgeOpen: [Bool]
    private(set) var crustTimer: [Double]

    private(set) var moldFill: [Double]
    private(set) var moldState: [MoldState]
    private(set) var moldRate: [Double]
    private var overRateTimer: [Double]
    private var underRateTimer: [Double]

    private(set) var pressure: Double = 0.28
    private(set) var peakPressure: Double = 0.28
    private(set) var elapsed: Double = 0

    private(set) var absorbedTotal: Double = 0
    private(set) var wastedTotal: Double = 0

    private(set) var veinsCrusted: Int = 0
    private(set) var crustsBlown: Int = 0
    private(set) var moldsCracked: Int = 0
    private(set) var reopenCount: Int = 0
    private(set) var tremorsSurvived: Int = 0
    private(set) var gasPocketsRidden: Int = 0

    private(set) var finished = false
    private(set) var outcome: VentOutcome?

    /// 0…1 while the rim is sealed off — the HUD uses it to warn before the
    /// run is actually lost.
    var chokeWarning: Double { min(1, chokeTimer / Self.chokeGrace) }

    private var solver = FlowSolver()
    private var rng: SeededRandom
    private var tremorCountdown: Double
    private var gasFired: [Bool]
    private var gasBurstRemaining: Double = 0
    /// How long every unfinished mold has been sealed behind crust. A crust can
    /// always be blown open, so being cut off is a warning, not an instant loss.
    private var chokeTimer: Double = 0
    static let chokeGrace: Double = 3.0

    /// Per-mold "has ever received magma" — starvation only counts after the
    /// first delivery, so nothing can die in the opening seconds.
    private var moldTouched: [Bool]
    /// Chamber→mold node chains, resolved once so the per-frame reachability
    /// check never allocates.
    private let moldChains: [[Int]]

    init(layout: VentLayout, seed: UInt64) {
        self.layout = layout
        edgeState = [EdgeState](repeating: .open, count: layout.edgeCount)
        edgeOpen = [Bool](repeating: true, count: layout.edgeCount)
        crustTimer = [Double](repeating: 0, count: layout.edgeCount)
        moldFill = [Double](repeating: 0, count: layout.moldCount)
        moldState = [MoldState](repeating: .filling, count: layout.moldCount)
        moldRate = [Double](repeating: 0, count: layout.moldCount)
        overRateTimer = [Double](repeating: 0, count: layout.moldCount)
        underRateTimer = [Double](repeating: 0, count: layout.moldCount)
        moldTouched = [Bool](repeating: false, count: layout.moldCount)
        gasFired = [Bool](repeating: false, count: layout.edgeCount)
        moldChains = (0..<layout.moldCount).map { layout.pathToMold($0) }
        rng = SeededRandom(seed: seed)
        tremorCountdown = layout.tremorInterval > 0 ? layout.tremorInterval : .infinity
        solver.prepare(for: layout)
    }

    // MARK: - Derived readouts

    var moldsFilled: Int {
        var n = 0
        for s in moldState where s == .cast { n += 1 }
        return n
    }
    var moldsLost: Int {
        var n = 0
        for s in moldState where s == .cracked || s == .setSolid { n += 1 }
        return n
    }
    var allMoldsCast: Bool { moldState.allSatisfy { $0 == .cast } }

    var yieldFraction: Double {
        let total = absorbedTotal + wastedTotal
        return total > 0.0001 ? absorbedTotal / total : 1.0
    }

    func fillFraction(_ moldIndex: Int) -> Double {
        guard moldIndex < moldFill.count else { return 0 }
        return min(1, moldFill[moldIndex] / layout.molds[moldIndex].target)
    }

    /// The only valve the trunk has no valve on is the chamber feed — the
    /// player can never shut the mountain off entirely.
    func isValveEdge(_ edge: Int) -> Bool {
        !layout.chambers.contains(layout.edges[edge].from)
    }

    // MARK: - Player intents

    @discardableResult
    func toggleValve(edge: Int) -> ValveAction {
        guard !finished, edge >= 0, edge < edgeState.count, isValveEdge(edge) else { return .none }
        switch edgeState[edge] {
        case .open:
            edgeState[edge] = .shut
            edgeOpen[edge] = false
            crustTimer[edge] = 0
            return .shut
        case .shut:
            edgeState[edge] = .open
            edgeOpen[edge] = true
            crustTimer[edge] = 0
            reopenCount += 1
            return .reopened
        case .crusted:
            return .refused
        }
    }

    /// Press-and-hold on a crusted valve: the crust goes, and so does a bite of
    /// chamber pressure.
    @discardableResult
    func blowCrust(edge: Int) -> ValveAction {
        guard !finished, edge >= 0, edge < edgeState.count,
              edgeState[edge] == .crusted else { return .none }
        edgeState[edge] = .open
        edgeOpen[edge] = true
        crustTimer[edge] = 0
        crustsBlown += 1
        veinsCrusted = max(0, veinsCrusted - 1)
        pressure = max(0.04, pressure - layout.blowoutCost)
        return .blownOpen
    }

    // MARK: - Simulation

    func tick(dt rawDT: Double) -> TickReport {
        var report = TickReport()
        guard !finished else { return report }
        let dt = min(rawDT, 1.0 / 20.0)   // never let a stall teleport the sim
        elapsed += dt

        // 1 — cooling. Shut branches crust through after the vent's timer.
        for e in edgeState.indices where edgeState[e] == .shut {
            crustTimer[e] += dt
            if crustTimer[e] >= layout.crustSeconds {
                edgeState[e] = .crusted
                edgeOpen[e] = false
                veinsCrusted += 1
                report.edgesJustCrusted.append(e)
            }
        }

        // 2 — tremors crust a random open branch out from under the player.
        if layout.tremorInterval > 0 {
            tremorCountdown -= dt
            if tremorCountdown <= 0 {
                tremorCountdown = layout.tremorInterval
                if let victim = randomOpenValveEdge() {
                    edgeState[victim] = .crusted
                    edgeOpen[victim] = false
                    veinsCrusted += 1
                    tremorsSurvived += 1
                    report.tremorEdge = victim
                    report.edgesJustCrusted.append(victim)
                }
            }
        }

        // 3 — distribute. Pressure pushes harder, so a backed-up chamber surges
        // the moment you give it somewhere to go.
        var inflow = layout.baseFlow * (0.55 + 0.85 * pressure)
        if gasBurstRemaining > 0 {
            gasBurstRemaining -= dt
            inflow *= VentTuning.gasMultiplier
        }
        solver.solve(layout: layout, edgeOpen: edgeOpen, inflow: inflow)

        // 4 — gas pockets fire once, the first time magma runs through them.
        for e in layout.edges.indices where layout.edges[e].gasPocket && !gasFired[e] {
            if solver.edgeFlow[e] > 0.02 {
                gasFired[e] = true
                gasBurstRemaining = VentTuning.gasSeconds
                gasPocketsRidden += 1
                report.gasBurstEdge = e
            }
        }

        // 5 — molds take what they can and judge the rate they are getting.
        var absorbedNow: Double = 0
        var wastedNow = (solver.blocked + solver.vented) * dt
        for m in moldState.indices {
            let rate = solver.moldRate[m]
            moldRate[m] = rate
            let delivered = rate * dt
            guard delivered > 0 else {
                if moldState[m] == .filling && moldTouched[m] {
                    underRateTimer[m] += dt
                    if underRateTimer[m] >= layout.setSeconds {
                        moldState[m] = .setSolid
                        report.moldsJustSet.append(m)
                    }
                }
                overRateTimer[m] = 0
                continue
            }

            guard moldState[m] == .filling else {
                wastedNow += delivered   // a finished mold just overflows
                continue
            }

            moldTouched[m] = true
            let spec = layout.molds[m]
            let room = max(0, spec.target - moldFill[m])
            let taken = min(delivered, room)
            moldFill[m] += taken
            absorbedNow += taken
            wastedNow += delivered - taken

            if rate > spec.maxRate {
                overRateTimer[m] += dt
                if overRateTimer[m] >= VentTuning.crackSeconds {
                    moldState[m] = .cracked
                    moldsCracked += 1
                    report.moldsJustCracked.append(m)
                }
            } else {
                overRateTimer[m] = max(0, overRateTimer[m] - dt * 1.6)
            }

            if rate < spec.minRate {
                underRateTimer[m] += dt
                if underRateTimer[m] >= layout.setSeconds {
                    moldState[m] = .setSolid
                    report.moldsJustSet.append(m)
                }
            } else {
                underRateTimer[m] = max(0, underRateTimer[m] - dt * 2.0)
            }

            if moldState[m] == .filling && moldFill[m] >= spec.target - 0.0001 {
                moldState[m] = .cast
                report.moldsJustCast.append(m)
            }
        }

        absorbedTotal += absorbedNow
        wastedTotal += wastedNow

        // 6 — pressure. Generation is constant; only magma that actually leaves
        // the mountain bleeds it off.
        let generation = layout.pressureBase + layout.pressureAccel * elapsed
        let reliefFlow = absorbedNow / max(dt, 0.0001)
        let ventedFlow = max(0, (wastedNow - solver.blocked * dt)) / max(dt, 0.0001)
        let relief = (reliefFlow + ventedFlow * VentTuning.overflowRelief) * VentTuning.reliefK
        pressure += (generation - relief) * dt
        pressure = min(1.05, max(0, pressure))
        peakPressure = max(peakPressure, pressure)

        // 7 — resolve.
        if allMoldsCast {
            finish(.cast, &report)
        } else if pressure >= 1.0 {
            finish(.blowout, &report)
        } else if moldsLost >= 3 {
            finish(.choked, &report)
        } else if !moldState.contains(where: { $0 == .filling }) {
            // Every mold is finished but not every mold was cast — nothing left
            // to play for, so the run ends instead of drifting to a blowout.
            finish(.choked, &report)
        } else if noUnfinishedMoldIsReachable() {
            // Give the player the grace to press-and-hold a crust open before
            // calling the run: sealing a mold off is recoverable, right up until
            // it is not.
            chokeTimer += dt
            if chokeTimer >= Self.chokeGrace { finish(.choked, &report) }
        } else {
            chokeTimer = 0
        }

        return report
    }

    private func finish(_ result: VentOutcome, _ report: inout TickReport) {
        finished = true
        outcome = result
        report.outcome = result
    }

    /// Every mold that still needs magma has been sealed off behind crust.
    private func noUnfinishedMoldIsReachable() -> Bool {
        var anyPending = false
        for m in moldState.indices where moldState[m] == .filling {
            anyPending = true
            if pathIsOpen(toMold: m) { return false }
        }
        return anyPending
    }

    private func pathIsOpen(toMold m: Int) -> Bool {
        let chain = moldChains[m]
        guard chain.count > 1 else { return true }
        for i in 0..<(chain.count - 1) {
            let a = chain[i], b = chain[i + 1]
            var found = false
            for e in layout.outEdges[a] where layout.edges[e].to == b {
                // A shut-but-warm branch can still be reopened, so it is not a
                // dead end — only crust truly seals a mold off.
                if edgeState[e] != .crusted { found = true }
            }
            if !found { return false }
        }
        return true
    }

    private func randomOpenValveEdge() -> Int? {
        var candidates = 0
        for e in edgeState.indices where edgeState[e] == .open && isValveEdge(e) { candidates += 1 }
        guard candidates > 0 else { return nil }
        var pick = rng.int(below: candidates)
        for e in edgeState.indices where edgeState[e] == .open && isValveEdge(e) {
            if pick == 0 { return e }
            pick -= 1
        }
        return nil
    }
}
