import Foundation

/// The heart of the game, and deliberately free of SpriteKit.
///
/// Given the vein graph and which edges are currently open, it works out how
/// much magma every edge and every mold receives. The player never pushes
/// magma anywhere — they only close branches, and the redistribution this type
/// performs is what turns that into a decision.
///
/// All scratch storage is allocated once in `prepare(for:)` so `solve` can run
/// every frame without touching the heap.
struct FlowSolver {

    /// Magma that reached a junction with nowhere open to go. It does not drain
    /// at all, so it is what drives the chamber toward a blowout.
    private(set) var blocked: Double = 0
    /// Magma that went out a dead-end relief vent: it leaves the mountain, so it
    /// bleeds pressure, but it casts nothing.
    private(set) var vented: Double = 0

    private(set) var edgeFlow: [Double] = []
    private(set) var moldRate: [Double] = []

    private var nodeRate: [Double] = []
    private var reachable: [Bool] = []

    mutating func prepare(for layout: VentLayout) {
        edgeFlow = [Double](repeating: 0, count: layout.edgeCount)
        moldRate = [Double](repeating: 0, count: layout.moldCount)
        nodeRate = [Double](repeating: 0, count: layout.nodeCount)
        reachable = [Bool](repeating: false, count: layout.nodeCount)
    }

    /// - Parameters:
    ///   - edgeOpen: per-edge open state (a shut or crusted edge is closed).
    ///   - inflow: total magma rate leaving the chambers this tick.
    mutating func solve(layout: VentLayout, edgeOpen: [Bool], inflow: Double) {
        blocked = 0; vented = 0
        for i in edgeFlow.indices { edgeFlow[i] = 0 }
        for i in moldRate.indices { moldRate[i] = 0 }
        for i in nodeRate.indices { nodeRate[i] = 0 }

        // A node is reachable if magma can physically leave it: molds are always
        // termini, junctions need at least one open edge to a reachable child.
        // Nodes are authored parents-before-children, so one reverse sweep does it.
        var i = layout.nodeCount - 1
        while i >= 0 {
            if layout.nodes[i].kind == .mold || layout.outEdges[i].isEmpty {
                // Molds are termini; so is a relief vent that leads nowhere.
                reachable[i] = true
            } else {
                var ok = false
                for e in layout.outEdges[i] where edgeOpen[e] && reachable[layout.edges[e].to] {
                    ok = true
                    break
                }
                reachable[i] = ok
            }
            i -= 1
        }

        for (k, root) in layout.chambers.enumerated() {
            let share = k < layout.chamberShare.count ? layout.chamberShare[k] : 1.0
            nodeRate[root] += inflow * share
        }

        // Forward sweep: split each node's rate evenly across its open, reachable
        // branches. Anything with nowhere to go backs up into the chamber.
        for n in 0..<layout.nodeCount {
            let rate = nodeRate[n]
            guard rate > 0 else { continue }

            let moldIndex = layout.moldOfNode[n]
            if moldIndex >= 0 {
                moldRate[moldIndex] = rate
                continue
            }

            guard !layout.outEdges[n].isEmpty else {
                vented += rate
                continue
            }

            var open = 0
            for e in layout.outEdges[n] where edgeOpen[e] && reachable[layout.edges[e].to] {
                open += 1
            }
            guard open > 0 else {
                blocked += rate
                continue
            }
            let share = rate / Double(open)
            for e in layout.outEdges[n] where edgeOpen[e] && reachable[layout.edges[e].to] {
                edgeFlow[e] = share
                nodeRate[layout.edges[e].to] += share
            }
        }
    }

    /// True when no open path exists from any chamber at all.
    func isFullyChoked(layout: VentLayout) -> Bool {
        for root in layout.chambers where reachable[root] { return false }
        return true
    }

    func isReachable(_ node: Int) -> Bool {
        node >= 0 && node < reachable.count ? reachable[node] : false
    }
}
