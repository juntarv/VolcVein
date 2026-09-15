import SpriteKit

/// The single SKScene. It renders whatever `VentRun` says is true and reports
/// touches back — every rule lives in the Logic layer, and Core Data is never
/// touched from here.
final class GameScene: SKScene, SKPhysicsContactDelegate {

    weak var bridge: GameViewModel?

    private(set) var run: VentRun?
    private var layout: VentLayout?

    // Scene graph, built once.
    private let world = SKNode()
    private let backdrop = SKSpriteNode(texture: SKTexture(imageNamed: "bg_chamber_glow"))
    private var veins: [VeinNode] = []
    private var valves: [ValveNode] = []
    private var molds: [MoldNode] = []
    private var chamberShapes: [SKShapeNode] = []
    private var goutPool: GoutPool?

    private var anchors: [CGPoint] = []
    private var routes: [[CGPoint]] = []
    private var arrivalBuffer: [Int] = []

    // Interaction.
    private var heldValve: ValveNode?
    private var holdSeconds: Double = 0
    private static let holdToBlow: Double = 0.6

    // Presentation.
    private var lastUpdate: TimeInterval = 0
    private var shakeRemaining: Double = 0
    private var shakeAmplitude: CGFloat = 0
    private var shakePhase: Double = 0
    var motionEnabled: Bool = true

    // Courier emission.
    private var lastEmitFill: [Double] = []
    private static let goutQuantum: Double = 0.34

    // Deterministic demo script.
    private var demoCursor = 0
    private var demoScript: [(time: Double, edge: Int)] = []

    private var built = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(VV.rockDeep)
        scaleMode = .resizeFill
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        if world.parent == nil {
            backdrop.zPosition = ZLayer.background
            backdrop.alpha = 0.85
            addChild(backdrop)
            world.zPosition = ZLayer.entities
            addChild(world)
        }
        if let layout { build(for: layout) }
        layoutScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard built else { return }
        layoutScene()
    }

    // MARK: - Loading a vent

    /// Reconfigures the existing scene for another vent. The scene object itself
    /// is created once and never rebuilt.
    func load(vent ventNumber: Int) {
        load(layout: VentCatalog.layout(for: ventNumber))
    }

    /// The Daily Fissure hands in a layout directly rather than a vent number.
    func load(layout newLayout: VentLayout) {
        layout = newLayout
        let seed: UInt64 = LaunchFlags.deterministic
            ? LaunchFlags.demoSeed
            : UInt64.random(in: 1...UInt64.max)
        run = VentRun(layout: newLayout, seed: seed)
        lastEmitFill = [Double](repeating: 0, count: newLayout.moldCount)
        demoCursor = 0
        demoScript = Self.script(for: newLayout)
        lastUpdate = 0
        shakeRemaining = 0
        heldValve = nil
        holdSeconds = 0

        if isPaused { isPaused = false }
        guard view != nil else { return }
        build(for: newLayout)
        layoutScene()
        goutPool?.reset()
    }

    // MARK: - Build

    private func build(for layout: VentLayout) {
        world.removeAllChildren()
        veins.removeAll(); valves.removeAll(); molds.removeAll(); chamberShapes.removeAll()

        for _ in layout.chambers {
            let pool = SKShapeNode()
            pool.zPosition = ZLayer.entities - 2
            pool.lineWidth = 0
            world.addChild(pool)
            chamberShapes.append(pool)
        }

        for e in layout.edges.indices {
            let vein = VeinNode(edgeIndex: e)
            world.addChild(vein)
            veins.append(vein)
        }

        for e in layout.edges.indices {
            guard !layout.chambers.contains(layout.edges[e].from) else { continue }
            let valve = ValveNode(edgeIndex: e, size: 42)
            world.addChild(valve)
            valves.append(valve)
        }

        for m in layout.molds.indices {
            let mold = MoldNode(moldIndex: m, width: 70)
            world.addChild(mold)
            molds.append(mold)
        }

        goutPool = GoutPool(parent: world, seed: LaunchFlags.demoSeed &+ UInt64(max(1, layout.ventNumber)))
        built = true
    }

    // MARK: - Layout

    /// Everything is positioned as a fraction of `scene.size`, with insets that
    /// keep the playfield clear of the HUD card, the pressure column, the hint
    /// strip and the home indicator on the smallest phone.
    private func layoutScene() {
        guard let layout, built, size.width > 1, size.height > 1 else { return }

        backdrop.position = CGPoint(x: size.width / 2, y: size.height / 2)
        let bgScale = max(size.width / max(backdrop.texture?.size().width ?? 1, 1),
                          size.height / max(backdrop.texture?.size().height ?? 1, 1))
        backdrop.setScale(bgScale)

        let topInset = max(150, size.height * 0.205)
        let bottomInset = max(92, size.height * 0.125)
        let leftInset = max(68, size.width * 0.175)
        let rightInset = max(16, size.width * 0.045)

        let w = max(40, size.width - leftInset - rightInset)
        let h = max(40, size.height - topInset - bottomInset)

        anchors = layout.nodes.map {
            CGPoint(x: leftInset + CGFloat($0.x) * w, y: bottomInset + CGFloat($0.y) * h)
        }

        let unit = min(w, h)
        let veinWidth = max(8, unit * 0.055)
        let valveSize = max(38, unit * 0.125)
        let moldWidth = min(w / CGFloat(max(layout.moldCount, 1)) * 0.88, unit * 0.30)

        // Chamber pools.
        for (i, root) in layout.chambers.enumerated() where i < chamberShapes.count {
            let c = anchors[root]
            let rx = min(w * 0.46, unit * 0.42) * (layout.chambers.count > 1 ? 0.66 : 1.0)
            let ry = rx * 0.34
            let rect = CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)
            chamberShapes[i].path = CGPath(ellipseIn: rect, transform: nil)
            chamberShapes[i].fillColor = UIColor(VV.magmaHot)
            chamberShapes[i].strokeColor = UIColor(VV.rock)
            chamberShapes[i].lineWidth = max(4, veinWidth * 0.5)
        }

        // Veins.
        for (i, vein) in veins.enumerated() {
            let e = layout.edges[i]
            vein.setGeometry(path: Self.curve(from: anchors[e.from], to: anchors[e.to]),
                             width: veinWidth)
        }

        // Valves at 55% along their branch.
        for valve in valves {
            let e = layout.edges[valve.edgeIndex]
            valve.position = Self.pointOnCurve(from: anchors[e.from], to: anchors[e.to], t: 0.55)
            valve.resize(valveSize)
        }

        // Molds.
        for (i, mold) in molds.enumerated() {
            mold.position = anchors[layout.molds[i].nodeIndex]
            mold.resize(width: moldWidth)
            mold.attachPhysics(radius: moldWidth * 0.42)
        }

        // Courier routes.
        routes = (0..<layout.moldCount).map { m in
            Self.polyline(chain: layout.pathToMold(m), anchors: anchors)
        }
        goutPool?.setRoutes(routes, goutSize: max(18, unit * 0.075))

        syncVisuals(force: true)
    }

    private static func curve(from a: CGPoint, to b: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: a)
        path.addQuadCurve(to: b, control: controlPoint(a, b))
        return path
    }

    private static func controlPoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(1, sqrt(dx * dx + dy * dy))
        // Bow each branch outward a little so the network reads as rock, not wire.
        let bow = len * 0.10
        return CGPoint(x: mid.x + (-dy / len) * bow, y: mid.y + (dx / len) * bow)
    }

    private static func pointOnCurve(from a: CGPoint, to b: CGPoint, t: CGFloat) -> CGPoint {
        let c = controlPoint(a, b)
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                       y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }

    private static func polyline(chain: [Int], anchors: [CGPoint]) -> [CGPoint] {
        guard chain.count > 1 else { return anchors.isEmpty ? [.zero] : [anchors[0]] }
        var pts: [CGPoint] = []
        pts.reserveCapacity((chain.count - 1) * 8 + 1)
        for i in 0..<(chain.count - 1) {
            let a = anchors[chain[i]], b = anchors[chain[i + 1]]
            let steps = 8
            for s in 0..<steps {
                pts.append(pointOnCurve(from: a, to: b, t: CGFloat(s) / CGFloat(steps)))
            }
        }
        pts.append(anchors[chain[chain.count - 1]])
        return pts
    }

    // MARK: - Frame

    override func update(_ currentTime: TimeInterval) {
        guard let run, built else { return }
        if lastUpdate == 0 { lastUpdate = currentTime }
        let dt = min(max(currentTime - lastUpdate, 0), 1.0 / 20.0)
        lastUpdate = currentTime
        guard dt > 0 else { return }

        if LaunchFlags.deterministic { advanceDemoScript(run: run) }
        advanceHold(dt: dt, run: run)

        let report = run.tick(dt: dt)
        emitCouriers(run: run)
        advanceEffects(dt: dt, run: run)
        syncVisuals(force: false)
        handle(report: report, run: run)

        bridge?.sync(from: run)
    }

    private func advanceHold(dt: Double, run: VentRun) {
        guard let valve = heldValve else { return }
        holdSeconds += dt
        valve.setHoldProgress(min(1, holdSeconds / Self.holdToBlow))
        if holdSeconds >= Self.holdToBlow {
            if run.blowCrust(edge: valve.edgeIndex) == .blownOpen {
                valve.flash()
                valve.nudge()
                shake(amplitude: 7, duration: 0.26)
                burst(at: valve.position, count: 14, spread: 190)
                Haptics.blow()
            }
            valve.setHoldProgress(0)
            heldValve = nil
            holdSeconds = 0
        }
    }

    /// One courier per fixed quantum of magma a mold takes in, so the visuals
    /// follow the simulation rather than inventing their own rate.
    private func emitCouriers(run: VentRun) {
        guard let pool = goutPool else { return }
        for m in run.moldFill.indices {
            let delta = run.moldFill[m] - lastEmitFill[m]
            guard delta >= Self.goutQuantum else { continue }
            lastEmitFill[m] = run.moldFill[m]
            pool.launch(towards: m, speed: 1.25)
        }
    }

    private func advanceEffects(dt: Double, run: VentRun) {
        guard let pool = goutPool else { return }
        pool.update(dt: dt, arrivals: &arrivalBuffer)
        for slot in arrivalBuffer {
            let moldIndex = pool.gouts[slot].moldIndex
            if !pool.gouts[slot].burstDone, moldIndex < molds.count {
                burst(at: molds[moldIndex].position, count: 6, spread: 120)
            }
            pool.retire(slot: slot)
        }

        if shakeRemaining > 0 {
            shakeRemaining -= dt
            shakePhase += dt * 52
            let decay = CGFloat(max(0, shakeRemaining / 0.3))
            world.position = CGPoint(x: CGFloat(sin(shakePhase)) * shakeAmplitude * decay,
                                     y: CGFloat(cos(shakePhase * 1.37)) * shakeAmplitude * decay * 0.6)
            if shakeRemaining <= 0 { world.position = .zero }
        }

        // The chamber breathes with pressure — a readable tell before a blowout.
        let heat = CGFloat(0.55 + run.pressure * 0.45)
        for shape in chamberShapes {
            shape.fillColor = UIColor(VV.magmaHot).withAlphaComponent(min(1, heat))
        }
    }

    private func syncVisuals(force: Bool) {
        guard let run else { return }
        for vein in veins { vein.apply(run.edgeState[vein.edgeIndex]) }
        for valve in valves { valve.apply(run.edgeState[valve.edgeIndex]) }
        for (i, mold) in molds.enumerated() where i < run.moldState.count {
            mold.apply(state: run.moldState[i], fill: run.fillFraction(i))
        }
        if force { world.position = .zero }
    }

    private func handle(report: TickReport, run: VentRun) {
        for m in report.moldsJustCast {
            molds[safe: m]?.flash(.white)
            burst(at: molds[safe: m]?.position ?? .zero, count: 18, spread: 230)
            shake(amplitude: 4, duration: 0.18)
            Haptics.success()
        }
        for m in report.moldsJustCracked {
            molds[safe: m]?.flash(UIColor(VV.danger))
            shake(amplitude: 8, duration: 0.3)
            Haptics.warn()
        }
        for m in report.moldsJustSet {
            molds[safe: m]?.flash(UIColor(VV.obsidianLit))
            Haptics.warn()
        }
        for e in report.edgesJustCrusted {
            if let valve = valves.first(where: { $0.edgeIndex == e }) {
                valve.flash()
                burst(at: valve.position, count: 5, spread: 90)
            }
        }
        if report.tremorEdge != nil {
            shake(amplitude: 10, duration: 0.4)
            Haptics.blow()
        }
        if let e = report.gasBurstEdge, let valve = valves.first(where: { $0.edgeIndex == e }) {
            burst(at: valve.position, count: 12, spread: 200)
            shake(amplitude: 5, duration: 0.22)
            Haptics.knock()
        }
        if let outcome = report.outcome {
            heldValve?.setHoldProgress(0)
            heldValve = nil
            if outcome == .cast {
                Haptics.success()
                shake(amplitude: 5, duration: 0.3)
            } else {
                Haptics.warn()
                shake(amplitude: 13, duration: 0.5)
            }
            bridge?.runDidFinish(run: run, outcome: outcome)
        }
    }

    private func burst(at point: CGPoint, count: Int, spread: CGFloat) {
        guard motionEnabled else { return }
        goutPool?.burst(at: point, count: count, spread: spread)
    }

    private func shake(amplitude: CGFloat, duration: Double) {
        guard motionEnabled else { return }
        shakeAmplitude = amplitude
        shakeRemaining = max(shakeRemaining, duration)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let run, !run.finished, !isPaused, !LaunchFlags.deterministic,
              let touch = touches.first else { return }
        let p = touch.location(in: world)
        guard let valve = nearestValve(to: p) else { return }

        if run.edgeState[valve.edgeIndex] == .crusted {
            heldValve = valve
            holdSeconds = 0
            valve.setHoldProgress(0.02)
            Haptics.tap()
        } else {
            let action = run.toggleValve(edge: valve.edgeIndex)
            if action == .shut || action == .reopened {
                valve.nudge()
                valve.flash()
                burst(at: valve.position, count: 4, spread: 80)
                Haptics.knock()
                syncVisuals(force: false)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        heldValve?.setHoldProgress(0)
        heldValve = nil
        holdSeconds = 0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    /// Generous 56pt target regardless of how small the valve is drawn.
    private func nearestValve(to point: CGPoint) -> ValveNode? {
        var best: ValveNode?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for valve in valves {
            let dx = valve.position.x - point.x
            let dy = valve.position.y - point.y
            let d = dx * dx + dy * dy
            if d < bestDistance { bestDistance = d; best = valve }
        }
        return bestDistance <= 56 * 56 ? best : nil
    }

    // MARK: - Contact

    func didBegin(_ contact: SKPhysicsContact) {
        guard motionEnabled, let pool = goutPool else { return }
        let bodies = [contact.bodyA, contact.bodyB]
        guard let goutBody = bodies.first(where: { $0.categoryBitMask == PhysicsCategory.gout }),
              let moldBody = bodies.first(where: { $0.categoryBitMask == PhysicsCategory.mold }),
              let goutNode = goutBody.node, let moldNode = moldBody.node as? MoldNode,
              let slot = pool.goutSlot(forNode: goutNode), pool.gouts[slot].active,
              !pool.gouts[slot].burstDone else { return }
        pool.burst(at: moldNode.position, count: 6, spread: 130)
        pool.retire(slot: slot)
    }

    // MARK: - Demo script

    /// A fixed sequence of valve taps so `-demoMode` and `-screenshotTour`
    /// render identical, legible frames every launch.
    private static func script(for layout: VentLayout) -> [(time: Double, edge: Int)] {
        var valveEdges: [Int] = []
        for e in layout.edges.indices where !layout.chambers.contains(layout.edges[e].from) {
            valveEdges.append(e)
        }
        guard !valveEdges.isEmpty else { return [] }
        var script: [(Double, Int)] = []
        var t = 1.1
        for cycle in 0..<6 {
            for (i, edge) in valveEdges.enumerated() {
                script.append((t, edge))
                t += 1.4 + Double((cycle + i) % 3) * 0.35
            }
        }
        return script
    }

    private func advanceDemoScript(run: VentRun) {
        while demoCursor < demoScript.count, run.elapsed >= demoScript[demoCursor].time {
            let edge = demoScript[demoCursor].edge
            demoCursor += 1
            if run.edgeState[edge] == .crusted {
                run.blowCrust(edge: edge)
            } else {
                run.toggleValve(edge: edge)
            }
            if let valve = valves.first(where: { $0.edgeIndex == edge }) {
                valve.nudge()
                burst(at: valve.position, count: 5, spread: 100)
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}
