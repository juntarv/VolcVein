import SpriteKit

/// Pre-allocated couriers and sparks. Nothing here is ever created or destroyed
/// while the game is running — `update(_:)` only flips flags and moves nodes.
final class GoutPool {

    struct Gout {
        var active = false
        var moldIndex = 0
        var progress: Double = 0      // 0…1 along the mold's polyline
        var speed: Double = 1
        var burstDone = false
    }

    struct Spark {
        var active = false
        var vx: CGFloat = 0
        var vy: CGFloat = 0
        var life: Double = 0
        var maxLife: Double = 1
    }

    private(set) var gouts: [Gout]
    private(set) var sparks: [Spark]

    private let goutNodes: [SKSpriteNode]
    private let sparkNodes: [SKSpriteNode]

    /// Chamber→mold polylines the couriers ride, rebuilt only on resize.
    private var routes: [[CGPoint]] = []
    private var rng: SeededRandom

    init(goutCount: Int = 26, sparkCount: Int = 72, parent: SKNode, seed: UInt64) {
        rng = SeededRandom(seed: seed)
        gouts = [Gout](repeating: Gout(), count: goutCount)
        sparks = [Spark](repeating: Spark(), count: sparkCount)

        let goutTexture = SKTexture(imageNamed: "gout_blob")
        let sparkTexture = SKTexture(imageNamed: "ember_spark")

        var gNodes: [SKSpriteNode] = []
        gNodes.reserveCapacity(goutCount)
        for _ in 0..<goutCount {
            let n = SKSpriteNode(texture: goutTexture)
            n.size = CGSize(width: 22, height: 27)
            n.zPosition = ZLayer.effects
            n.isHidden = true
            let body = SKPhysicsBody(circleOfRadius: 9)
            body.isDynamic = true
            body.affectedByGravity = false
            body.allowsRotation = false
            body.categoryBitMask = PhysicsCategory.gout
            body.contactTestBitMask = PhysicsCategory.mold
            body.collisionBitMask = PhysicsCategory.none
            n.physicsBody = body
            parent.addChild(n)
            gNodes.append(n)
        }
        goutNodes = gNodes

        var sNodes: [SKSpriteNode] = []
        sNodes.reserveCapacity(sparkCount)
        for _ in 0..<sparkCount {
            let n = SKSpriteNode(texture: sparkTexture)
            n.size = CGSize(width: 13, height: 13)
            n.zPosition = ZLayer.effects + 2
            n.isHidden = true
            parent.addChild(n)
            sNodes.append(n)
        }
        sparkNodes = sNodes
    }

    func setRoutes(_ routes: [[CGPoint]], goutSize: CGFloat) {
        self.routes = routes
        for n in goutNodes {
            n.size = CGSize(width: goutSize * 0.82, height: goutSize)
        }
        for n in sparkNodes {
            n.size = CGSize(width: goutSize * 0.52, height: goutSize * 0.52)
        }
    }

    func reset() {
        for i in gouts.indices {
            gouts[i].active = false
            goutNodes[i].isHidden = true
        }
        for i in sparks.indices {
            sparks[i].active = false
            sparkNodes[i].isHidden = true
        }
    }

    /// Index of the mold a gout node belongs to, so contact callbacks can tell
    /// which courier landed.
    func moldIndex(forNode node: SKNode) -> Int? {
        guard let idx = goutNodes.firstIndex(where: { $0 === node }) else { return nil }
        return gouts[idx].active ? gouts[idx].moldIndex : nil
    }

    func goutSlot(forNode node: SKNode) -> Int? {
        goutNodes.firstIndex(where: { $0 === node })
    }

    @discardableResult
    func launch(towards moldIndex: Int, speed: Double) -> Bool {
        guard moldIndex < routes.count, routes[moldIndex].count > 1 else { return false }
        for i in gouts.indices where !gouts[i].active {
            gouts[i].active = true
            gouts[i].moldIndex = moldIndex
            gouts[i].progress = 0
            gouts[i].speed = speed
            gouts[i].burstDone = false
            goutNodes[i].isHidden = false
            goutNodes[i].position = routes[moldIndex][0]
            goutNodes[i].setScale(1)
            return true
        }
        return false
    }

    func burst(at point: CGPoint, count: Int, spread: CGFloat) {
        var spawned = 0
        for i in sparks.indices where !sparks[i].active {
            guard spawned < count else { return }
            let angle = CGFloat(rng.unit()) * .pi * 2
            let speed = spread * (0.45 + CGFloat(rng.unit()) * 0.85)
            sparks[i].active = true
            sparks[i].vx = cos(angle) * speed
            sparks[i].vy = sin(angle) * speed
            sparks[i].maxLife = 0.34 + rng.unit() * 0.3
            sparks[i].life = sparks[i].maxLife
            sparkNodes[i].isHidden = false
            sparkNodes[i].position = point
            sparkNodes[i].alpha = 1
            sparkNodes[i].setScale(1)
            spawned += 1
        }
    }

    func retire(slot: Int) {
        guard slot >= 0, slot < gouts.count else { return }
        gouts[slot].active = false
        goutNodes[slot].isHidden = true
    }

    func position(ofSlot slot: Int) -> CGPoint {
        goutNodes[slot].position
    }

    /// Advances couriers and sparks. Returns the slots that reached their mold.
    /// Writes into the caller's buffer so nothing is allocated.
    func update(dt: Double, arrivals: inout [Int]) {
        arrivals.removeAll(keepingCapacity: true)

        for i in gouts.indices where gouts[i].active {
            gouts[i].progress += gouts[i].speed * dt
            let route = routes[gouts[i].moldIndex]
            if gouts[i].progress >= 1 {
                goutNodes[i].position = route[route.count - 1]
                arrivals.append(i)
                continue
            }
            let t = gouts[i].progress * Double(route.count - 1)
            let idx = min(route.count - 2, max(0, Int(t)))
            let frac = CGFloat(t - Double(idx))
            let a = route[idx], b = route[idx + 1]
            goutNodes[i].position = CGPoint(x: a.x + (b.x - a.x) * frac,
                                            y: a.y + (b.y - a.y) * frac)
        }

        for i in sparks.indices where sparks[i].active {
            sparks[i].life -= dt
            if sparks[i].life <= 0 {
                sparks[i].active = false
                sparkNodes[i].isHidden = true
                continue
            }
            sparks[i].vy -= 260 * CGFloat(dt)
            let n = sparkNodes[i]
            n.position.x += sparks[i].vx * CGFloat(dt)
            n.position.y += sparks[i].vy * CGFloat(dt)
            let k = sparks[i].life / sparks[i].maxLife
            n.alpha = CGFloat(k)
            n.setScale(0.45 + CGFloat(k) * 0.7)
        }
    }
}
