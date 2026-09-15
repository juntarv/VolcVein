import Foundation

// The authored content of the game: 60 vent layouts across 6 rifts, plus the
// date-seeded Daily Fissure.
// Unit space is x 0…1 left→right, y 0…1 bottom→top (chamber low, rim high).
// Nodes are always ordered parents-before-children so the solver can sweep
// the arrays in one pass without building a tree at runtime.

enum VeinNodeKind {
    case chamber
    case junction
    case mold
}

struct VeinPoint {
    let x: Double
    let y: Double
    let kind: VeinNodeKind
}

struct VeinEdge {
    let from: Int
    let to: Int
    /// A marked segment that releases a pressure burst the first time magma
    /// runs through it (Rift II onward).
    let gasPocket: Bool
}

struct MoldSpec {
    let nodeIndex: Int
    /// Units of magma required to cast.
    let target: Double
    /// Below this rate for the vent's `setSeconds` and the mold sets solid.
    let minRate: Double
    /// Above this rate for `VentTuning.crackSeconds` and the mold cracks.
    let maxRate: Double
}

enum VentTuning {
    static let crackSeconds: Double = 1.15
    /// How fast absorbed magma bleeds chamber pressure.
    static let reliefK: Double = 0.085
    /// Overflow into a finished mold still vents some pressure, but earns nothing.
    static let overflowRelief: Double = 0.30
    /// Gas pocket burst.
    static let gasMultiplier: Double = 2.0
    static let gasSeconds: Double = 1.5
}

struct VentLayout {
    let ventNumber: Int
    let riftIndex: Int
    let nodes: [VeinPoint]
    let edges: [VeinEdge]
    let molds: [MoldSpec]
    /// Root nodes and the share of total inflow each one carries.
    let chambers: [Int]
    let chamberShare: [Double]
    let baseFlow: Double
    let pressureBase: Double
    let pressureAccel: Double
    let crustSeconds: Double
    /// How long a mold may sit under its minimum rate before it sets solid.
    let setSeconds: Double
    let blowoutCost: Double
    /// 0 means this vent throws no tremors.
    let tremorInterval: Double
    let parTime: Double

    /// Out-edge indices per node, precomputed once at build time.
    let outEdges: [[Int]]
    /// Mold index per node, or -1.
    let moldOfNode: [Int]

    var moldCount: Int { molds.count }
    var edgeCount: Int { edges.count }
    var nodeCount: Int { nodes.count }

    init(ventNumber: Int, riftIndex: Int, nodes: [VeinPoint], edges: [VeinEdge],
         molds: [MoldSpec], chambers: [Int], chamberShare: [Double],
         baseFlow: Double, pressureBase: Double, pressureAccel: Double,
         crustSeconds: Double, setSeconds: Double, blowoutCost: Double,
         tremorInterval: Double, parTime: Double) {
        self.ventNumber = ventNumber
        self.riftIndex = riftIndex
        self.nodes = nodes
        self.edges = edges
        self.molds = molds
        self.chambers = chambers
        self.chamberShare = chamberShare
        self.baseFlow = baseFlow
        self.pressureBase = pressureBase
        self.pressureAccel = pressureAccel
        self.crustSeconds = crustSeconds
        self.setSeconds = setSeconds
        self.blowoutCost = blowoutCost
        self.tremorInterval = tremorInterval
        self.parTime = parTime

        var outs = [[Int]](repeating: [], count: nodes.count)
        for (i, e) in edges.enumerated() { outs[e.from].append(i) }
        self.outEdges = outs

        var mon = [Int](repeating: -1, count: nodes.count)
        for (i, m) in molds.enumerated() { mon[m.nodeIndex] = i }
        self.moldOfNode = mon

        assertValid()
    }

    /// Catches an authoring slip at the source instead of deep inside an array
    /// subscript: every endpoint in range, and parents always before children so
    /// the solver's single forward sweep is correct.
    private func assertValid() {
        #if DEBUG
        for (i, e) in edges.enumerated() {
            assert(e.from >= 0 && e.from < nodes.count,
                   "vent \(ventNumber) edge \(i) leaves node \(e.from), out of range")
            assert(e.to >= 0 && e.to < nodes.count,
                   "vent \(ventNumber) edge \(i) reaches node \(e.to), out of range")
            assert(e.from < e.to,
                   "vent \(ventNumber) edge \(i) runs \(e.from)->\(e.to); nodes must be ordered parents first")
        }
        for (i, m) in molds.enumerated() {
            assert(m.nodeIndex >= 0 && m.nodeIndex < nodes.count,
                   "vent \(ventNumber) mold \(i) sits on node \(m.nodeIndex), out of range")
            assert(nodes[m.nodeIndex].kind == .mold,
                   "vent \(ventNumber) mold \(i) sits on a node that is not a mold")
        }
        for c in chambers {
            assert(c >= 0 && c < nodes.count, "vent \(ventNumber) chamber \(c) out of range")
        }
        assert(chambers.count == chamberShare.count,
               "vent \(ventNumber) has \(chambers.count) chambers but \(chamberShare.count) shares")
        #endif
    }

    /// The chain of node indices from a chamber down to a mold — used to draw
    /// the courier path a gout travels.
    func pathToMold(_ moldIndex: Int) -> [Int] {
        var parent = [Int](repeating: -1, count: nodes.count)
        for e in edges { parent[e.to] = e.from }
        var chain: [Int] = []
        var cursor = molds[moldIndex].nodeIndex
        while cursor >= 0 {
            chain.append(cursor)
            cursor = parent[cursor]
        }
        return chain.reversed()
    }
}

enum VentCatalog {

    static let ventCount = 60
    static let riftCount = 6
    static let ventsPerRift = 10

    /// Built on demand — a run only ever needs the one vent it is playing.
    static func layout(for ventNumber: Int) -> VentLayout {
        build(vent: min(max(ventNumber, 1), ventCount))
    }

    static func riftIndex(forVent vent: Int) -> Int {
        min(riftCount, max(1, (vent - 1) / ventsPerRift + 1))
    }

    static func firstVent(ofRift rift: Int) -> Int { (rift - 1) * ventsPerRift + 1 }
    static func lastVent(ofRift rift: Int) -> Int { rift * ventsPerRift }

    // MARK: - The Daily Fissure

    /// A different vent every calendar day, identical for every run that day.
    /// The archetype and the difficulty band both come from the date, so the
    /// daily is its own thing rather than a re-skin of wherever you happen to be.
    static func dailyLayout(dayKey: String) -> VentLayout {
        let seed = dailySeed(dayKey)
        var rng = SeededRandom(seed: seed)
        let archetype = dailyArchetype(dayKey)
        // Pulls from the middle of each rift so the daily is always a real test
        // without depending on how far the player has climbed.
        let sourceVent = firstVent(ofRift: archetype) + 4 + rng.int(below: 4)
        return build(vent: sourceVent)
    }

    static func dailyArchetype(_ dayKey: String) -> Int {
        var rng = SeededRandom(seed: dailySeed(dayKey))
        return 1 + rng.int(below: riftCount)
    }

    private static func dailySeed(_ dayKey: String) -> UInt64 {
        var h: UInt64 = 0xCBF29CE484222325
        for byte in dayKey.utf8 {
            h = (h ^ UInt64(byte)) &* 0x100000001B3
        }
        return h
    }

    /// Today, in the player's own calendar — the key every daily record hangs off.
    static func dayKey(for date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Authored topologies

    /// Rift I — one junction, the core loop. Two molds fed 50/50, and the split
    /// sits just under `minRate` so the player has to concentrate the flow.
    private static func emberfoot(vent: Int, withSpillVent: Bool) -> ([VeinPoint], [VeinEdge], [MoldSpec]) {
        var nodes: [VeinPoint] = [
            VeinPoint(x: 0.50, y: 0.05, kind: .chamber),   // 0
            VeinPoint(x: 0.50, y: 0.36, kind: .junction),  // 1
            VeinPoint(x: 0.22, y: 0.82, kind: .mold),      // 2
            VeinPoint(x: 0.78, y: 0.82, kind: .mold),      // 3
        ]
        var edges: [VeinEdge] = [
            VeinEdge(from: 0, to: 1, gasPocket: false),
            VeinEdge(from: 1, to: 2, gasPocket: false),
            VeinEdge(from: 1, to: 3, gasPocket: false),
        ]
        if withSpillVent {
            nodes.append(VeinPoint(x: 0.50, y: 0.68, kind: .junction))  // 4 — dead end
            edges.append(VeinEdge(from: 1, to: 4, gasPocket: false))
        }
        let molds = [
            MoldSpec(nodeIndex: 2, target: 2.6 + Double((vent - 1) % 10) * 0.13, minRate: 0.07, maxRate: 1.25),
            MoldSpec(nodeIndex: 3, target: 2.6 + Double((vent - 1) % 10) * 0.13, minRate: 0.07, maxRate: 1.25),
        ]
        return (nodes, edges, molds)
    }

    /// Rift II — two tiers of junctions, three or four molds, gas pockets.
    private static func cinderSteps(vent: Int, molds moldCount: Int) -> ([VeinPoint], [VeinEdge], [MoldSpec]) {
        var nodes: [VeinPoint] = [
            VeinPoint(x: 0.50, y: 0.04, kind: .chamber),   // 0
            VeinPoint(x: 0.50, y: 0.30, kind: .junction),  // 1
            VeinPoint(x: 0.26, y: 0.54, kind: .junction),  // 2
            VeinPoint(x: 0.74, y: 0.54, kind: .junction),  // 3
            VeinPoint(x: 0.13, y: 0.86, kind: .mold),      // 4
            VeinPoint(x: 0.40, y: 0.86, kind: .mold),      // 5
            VeinPoint(x: 0.62, y: 0.86, kind: .mold),      // 6
        ]
        var edges: [VeinEdge] = [
            VeinEdge(from: 0, to: 1, gasPocket: false),
            VeinEdge(from: 1, to: 2, gasPocket: vent >= 12),
            VeinEdge(from: 1, to: 3, gasPocket: false),
            VeinEdge(from: 2, to: 4, gasPocket: false),
            VeinEdge(from: 2, to: 5, gasPocket: false),
            VeinEdge(from: 3, to: 6, gasPocket: vent >= 16),
        ]
        var molds = [
            MoldSpec(nodeIndex: 4, target: 2.4, minRate: 0.07, maxRate: 0.98),
            MoldSpec(nodeIndex: 5, target: 2.4, minRate: 0.07, maxRate: 0.98),
            MoldSpec(nodeIndex: 6, target: 2.8, minRate: 0.07, maxRate: 0.98),
        ]
        if vent >= 13 {
            nodes.append(VeinPoint(x: 0.06, y: 0.62, kind: .junction))  // relief vent, dead end
            edges.append(VeinEdge(from: 2, to: nodes.count - 1, gasPocket: false))
        }
        if moldCount >= 4 {
            nodes.append(VeinPoint(x: 0.88, y: 0.86, kind: .mold))     // mold
            edges.append(VeinEdge(from: 3, to: nodes.count - 1, gasPocket: false))
            molds.append(MoldSpec(nodeIndex: nodes.count - 1, target: 2.8, minRate: 0.07, maxRate: 0.98))
        }
        return (nodes, edges, molds)
    }

    /// Rift III — a deeper, lopsided tree with a spill vent and tremors.
    private static func ashfallReach(vent: Int) -> ([VeinPoint], [VeinEdge], [MoldSpec]) {
        let nodes: [VeinPoint] = [
            VeinPoint(x: 0.50, y: 0.04, kind: .chamber),   // 0
            VeinPoint(x: 0.48, y: 0.26, kind: .junction),  // 1
            VeinPoint(x: 0.24, y: 0.46, kind: .junction),  // 2
            VeinPoint(x: 0.74, y: 0.44, kind: .junction),  // 3
            VeinPoint(x: 0.44, y: 0.64, kind: .junction),  // 4
            VeinPoint(x: 0.11, y: 0.88, kind: .mold),      // 5
            VeinPoint(x: 0.34, y: 0.88, kind: .mold),      // 6
            VeinPoint(x: 0.58, y: 0.88, kind: .mold),      // 7
            VeinPoint(x: 0.87, y: 0.86, kind: .mold),      // 8
            VeinPoint(x: 0.92, y: 0.58, kind: .junction),  // 9 — dead-end relief vent
        ]
        let edges: [VeinEdge] = [
            VeinEdge(from: 0, to: 1, gasPocket: false),
            VeinEdge(from: 1, to: 2, gasPocket: true),
            VeinEdge(from: 1, to: 3, gasPocket: false),
            VeinEdge(from: 2, to: 5, gasPocket: false),
            VeinEdge(from: 2, to: 4, gasPocket: false),
            VeinEdge(from: 4, to: 6, gasPocket: false),
            VeinEdge(from: 4, to: 7, gasPocket: vent >= 25),
            VeinEdge(from: 3, to: 8, gasPocket: false),
            VeinEdge(from: 3, to: 9, gasPocket: false),
        ]
        let molds = [
            MoldSpec(nodeIndex: 5, target: 2.5, minRate: 0.07, maxRate: 1.18),
            MoldSpec(nodeIndex: 6, target: 2.5, minRate: 0.07, maxRate: 1.18),
            MoldSpec(nodeIndex: 7, target: 2.7, minRate: 0.07, maxRate: 1.18),
            MoldSpec(nodeIndex: 8, target: 2.9, minRate: 0.07, maxRate: 1.18),
        ]
        return (nodes, edges, molds)
    }

    /// Rift IV — twin chambers feeding two trunks at different rates, tight bands.
    private static func throatOfTheMountain(vent: Int, molds moldCount: Int) -> ([VeinPoint], [VeinEdge], [MoldSpec]) {
        var nodes: [VeinPoint] = [
            VeinPoint(x: 0.28, y: 0.04, kind: .chamber),   // 0 — main chamber
            VeinPoint(x: 0.76, y: 0.06, kind: .chamber),   // 1 — lesser chamber
            VeinPoint(x: 0.26, y: 0.30, kind: .junction),  // 2
            VeinPoint(x: 0.74, y: 0.32, kind: .junction),  // 3
            VeinPoint(x: 0.40, y: 0.56, kind: .junction),  // 4
            VeinPoint(x: 0.10, y: 0.60, kind: .junction),  // 5 — relief vent, dead end
            VeinPoint(x: 0.12, y: 0.88, kind: .mold),      // 6
            VeinPoint(x: 0.36, y: 0.88, kind: .mold),      // 7
            VeinPoint(x: 0.60, y: 0.88, kind: .mold),      // 8
            VeinPoint(x: 0.86, y: 0.88, kind: .mold),      // 9
            VeinPoint(x: 0.95, y: 0.56, kind: .junction),  // 10 — relief vent, dead end
        ]
        var edges: [VeinEdge] = [
            VeinEdge(from: 0, to: 2, gasPocket: false),
            VeinEdge(from: 1, to: 3, gasPocket: false),
            VeinEdge(from: 2, to: 5, gasPocket: false),
            VeinEdge(from: 2, to: 4, gasPocket: true),
            VeinEdge(from: 4, to: 6, gasPocket: false),
            VeinEdge(from: 4, to: 7, gasPocket: false),
            VeinEdge(from: 3, to: 8, gasPocket: vent >= 35),
            VeinEdge(from: 3, to: 9, gasPocket: false),
            VeinEdge(from: 3, to: 10, gasPocket: false),
        ]
        var molds = [
            MoldSpec(nodeIndex: 6, target: 2.6, minRate: 0.07, maxRate: 0.96),
            MoldSpec(nodeIndex: 7, target: 2.6, minRate: 0.07, maxRate: 0.96),
            MoldSpec(nodeIndex: 8, target: 2.8, minRate: 0.07, maxRate: 0.96),
            MoldSpec(nodeIndex: 9, target: 2.8, minRate: 0.07, maxRate: 0.96),
        ]
        if moldCount >= 5 {
            nodes.append(VeinPoint(x: 0.52, y: 0.70, kind: .mold))     // extra mold
            edges.append(VeinEdge(from: 4, to: nodes.count - 1, gasPocket: false))
            molds.append(MoldSpec(nodeIndex: nodes.count - 1, target: 2.2,
                                  minRate: 0.07, maxRate: 0.96))
        }
        return (nodes, edges, molds)
    }

    /// Rift V — a long cascade of brittle molds: five rim molds hanging off two
    /// tiers of junctions, so flow has to be steered a long way before it lands.
    private static func glassGallery(vent: Int) -> ([VeinPoint], [VeinEdge], [MoldSpec]) {
        let nodes: [VeinPoint] = [
            VeinPoint(x: 0.50, y: 0.03, kind: .chamber),   // 0
            VeinPoint(x: 0.50, y: 0.24, kind: .junction),  // 1
            VeinPoint(x: 0.28, y: 0.44, kind: .junction),  // 2
            VeinPoint(x: 0.74, y: 0.42, kind: .junction),  // 3
            VeinPoint(x: 0.20, y: 0.64, kind: .junction),  // 4
            VeinPoint(x: 0.62, y: 0.62, kind: .junction),  // 5
            VeinPoint(x: 0.45, y: 0.54, kind: .junction),  // 6 — relief vent, dead end
            VeinPoint(x: 0.07, y: 0.88, kind: .mold),      // 7
            VeinPoint(x: 0.30, y: 0.88, kind: .mold),      // 8
            VeinPoint(x: 0.92, y: 0.84, kind: .mold),      // 9
            VeinPoint(x: 0.52, y: 0.88, kind: .mold),      // 10
            VeinPoint(x: 0.74, y: 0.88, kind: .mold),      // 11
        ]
        let edges: [VeinEdge] = [
            VeinEdge(from: 0, to: 1, gasPocket: false),
            VeinEdge(from: 1, to: 2, gasPocket: vent >= 44),
            VeinEdge(from: 1, to: 3, gasPocket: false),
            VeinEdge(from: 2, to: 4, gasPocket: false),
            VeinEdge(from: 2, to: 6, gasPocket: false),
            VeinEdge(from: 3, to: 5, gasPocket: false),
            VeinEdge(from: 3, to: 9, gasPocket: vent >= 47),
            VeinEdge(from: 4, to: 7, gasPocket: false),
            VeinEdge(from: 4, to: 8, gasPocket: false),
            VeinEdge(from: 5, to: 10, gasPocket: false),
            VeinEdge(from: 5, to: 11, gasPocket: false),
        ]
        let molds = [
            MoldSpec(nodeIndex: 7, target: 2.4, minRate: 0.07, maxRate: 1.15),
            MoldSpec(nodeIndex: 8, target: 2.4, minRate: 0.07, maxRate: 1.15),
            MoldSpec(nodeIndex: 9, target: 2.7, minRate: 0.07, maxRate: 1.15),
            MoldSpec(nodeIndex: 10, target: 2.5, minRate: 0.07, maxRate: 1.15),
            MoldSpec(nodeIndex: 11, target: 2.5, minRate: 0.07, maxRate: 1.15),
        ]
        return (nodes, edges, molds)
    }

    /// Rift VI — three chambers at three different rates feeding one rim. Every
    /// wrinkle the mountain has, at once.
    private static func lastVent(vent: Int, molds moldCount: Int) -> ([VeinPoint], [VeinEdge], [MoldSpec]) {
        var nodes: [VeinPoint] = [
            VeinPoint(x: 0.15, y: 0.04, kind: .chamber),   // 0
            VeinPoint(x: 0.50, y: 0.02, kind: .chamber),   // 1
            VeinPoint(x: 0.85, y: 0.04, kind: .chamber),   // 2
            VeinPoint(x: 0.16, y: 0.28, kind: .junction),  // 3
            VeinPoint(x: 0.50, y: 0.26, kind: .junction),  // 4
            VeinPoint(x: 0.84, y: 0.28, kind: .junction),  // 5
            VeinPoint(x: 0.28, y: 0.54, kind: .junction),  // 6
            VeinPoint(x: 0.68, y: 0.54, kind: .junction),  // 7
            VeinPoint(x: 0.50, y: 0.46, kind: .junction),  // 8 — relief vent, dead end
            VeinPoint(x: 0.06, y: 0.88, kind: .mold),      // 9
            VeinPoint(x: 0.26, y: 0.88, kind: .mold),      // 10
            VeinPoint(x: 0.46, y: 0.88, kind: .mold),      // 11
            VeinPoint(x: 0.66, y: 0.88, kind: .mold),      // 12
            VeinPoint(x: 0.88, y: 0.88, kind: .mold),      // 13
            VeinPoint(x: 0.97, y: 0.58, kind: .junction),  // 14 — relief vent, dead end
        ]
        var edges: [VeinEdge] = [
            VeinEdge(from: 0, to: 3, gasPocket: false),
            VeinEdge(from: 1, to: 4, gasPocket: false),
            VeinEdge(from: 2, to: 5, gasPocket: false),
            VeinEdge(from: 3, to: 6, gasPocket: vent >= 54),
            VeinEdge(from: 4, to: 8, gasPocket: false),
            VeinEdge(from: 4, to: 11, gasPocket: false),
            VeinEdge(from: 5, to: 7, gasPocket: false),
            VeinEdge(from: 5, to: 14, gasPocket: false),
            VeinEdge(from: 6, to: 9, gasPocket: false),
            VeinEdge(from: 6, to: 10, gasPocket: false),
            VeinEdge(from: 7, to: 12, gasPocket: vent >= 57),
            VeinEdge(from: 7, to: 13, gasPocket: false),
        ]
        var molds = [
            MoldSpec(nodeIndex: 9, target: 2.5, minRate: 0.07, maxRate: 1.05),
            MoldSpec(nodeIndex: 10, target: 2.5, minRate: 0.07, maxRate: 1.05),
            MoldSpec(nodeIndex: 11, target: 2.7, minRate: 0.07, maxRate: 1.05),
            MoldSpec(nodeIndex: 12, target: 2.5, minRate: 0.07, maxRate: 1.05),
            MoldSpec(nodeIndex: 13, target: 2.7, minRate: 0.07, maxRate: 1.05),
        ]
        if moldCount >= 6 {
            nodes.append(VeinPoint(x: 0.40, y: 0.70, kind: .mold))     // sixth mold
            edges.append(VeinEdge(from: 6, to: nodes.count - 1, gasPocket: false))
            molds.append(MoldSpec(nodeIndex: nodes.count - 1, target: 2.2,
                                  minRate: 0.07, maxRate: 1.05))
        }
        return (nodes, edges, molds)
    }

    // MARK: - Per-vent tuning

    private static func build(vent: Int) -> VentLayout {
        let rift = riftIndex(forVent: vent)
        let step = Double((vent - 1) % ventsPerRift)   // 0…9 inside the rift
        let ramp = step / Double(ventsPerRift - 1)     // 0…1 across the rift

        let nodes: [VeinPoint]
        let edges: [VeinEdge]
        let molds: [MoldSpec]
        let chambers: [Int]
        let shares: [Double]

        switch rift {
        case 1:
            (nodes, edges, molds) = emberfoot(vent: vent, withSpillVent: vent >= 4)
            chambers = [0]; shares = [1.0]
        case 2:
            (nodes, edges, molds) = cinderSteps(vent: vent, molds: vent >= 15 ? 4 : 3)
            chambers = [0]; shares = [1.0]
        case 3:
            (nodes, edges, molds) = ashfallReach(vent: vent)
            chambers = [0]; shares = [1.0]
        case 4:
            (nodes, edges, molds) = throatOfTheMountain(vent: vent, molds: vent >= 36 ? 5 : 4)
            chambers = [0, 1]; shares = [0.62, 0.38]
        case 5:
            (nodes, edges, molds) = glassGallery(vent: vent)
            chambers = [0]; shares = [1.0]
        default:
            (nodes, edges, molds) = lastVent(vent: vent, molds: vent >= 56 ? 6 : 5)
            chambers = [0, 1, 2]; shares = [0.36, 0.34, 0.30]
        }

        // Crust timers tighten across each rift, then again between rifts.
        let crustStart: [Double] = [9.0, 6.8, 5.2, 4.0, 3.6, 3.2]
        let crustEnd: [Double]   = [7.0, 5.4, 4.2, 3.2, 3.0, 2.6]
        let crust = crustStart[rift - 1] + (crustEnd[rift - 1] - crustStart[rift - 1]) * ramp

        // Tuned per rift rather than by formula: the deeper rifts already lose a
        // chunk of their flow to relief vents, so they need a gentler generation
        // curve than a linear ramp would give them.
        let riftD = Double(rift - 1)
        let baseByRift: [Double]  = [0.058, 0.072, 0.084, 0.082, 0.086, 0.084]
        let accelByRift: [Double] = [0.00150, 0.00210, 0.00260, 0.00245, 0.00250, 0.00240]
        return VentLayout(
            ventNumber: vent,
            riftIndex: rift,
            nodes: nodes,
            edges: edges,
            molds: molds,
            chambers: chambers,
            chamberShare: shares,
            baseFlow: 0.62 + riftD * 0.085 + step * 0.012,
            pressureBase: baseByRift[rift - 1] + ramp * 0.015,
            pressureAccel: accelByRift[rift - 1] + ramp * 0.0008,
            crustSeconds: crust,
            setSeconds: 12.0 - Double(rift),
            blowoutCost: 0.17 + riftD * 0.012,
            tremorInterval: rift >= 3 ? max(10.5, 17.0 - ramp * 6.0 - riftD * 0.8) : 0,
            parTime: 52 + Double(molds.count) * 9
        )
    }
}
