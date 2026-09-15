import SpriteKit

/// A rim mold: the stone form the magma has to land in. Base art swaps between
/// the four authored states; the fill bar scales inside it.
final class MoldNode: SKNode {

    let moldIndex: Int

    private let base: SKSpriteNode
    private let fill: SKSpriteNode
    private let badge: SKSpriteNode
    private let badgeLabel: SKLabelNode

    private static let empty = SKTexture(imageNamed: "mold_empty")
    private static let part = SKTexture(imageNamed: "mold_part")
    private static let full = SKTexture(imageNamed: "mold_full")
    private static let dead = SKTexture(imageNamed: "mold_set")
    private static let badgeOpen = SKTexture(imageNamed: "node_live")
    private static let badgeDone = SKTexture(imageNamed: "node_cleared")
    private static let badgeDead = SKTexture(imageNamed: "node_locked")

    private var innerHeight: CGFloat = 1
    private var lastState: MoldState = .filling
    private var lastFillStep: Int = -1

    init(moldIndex: Int, width: CGFloat) {
        self.moldIndex = moldIndex
        base = SKSpriteNode(texture: Self.empty)
        fill = SKSpriteNode(color: UIColor(VV.magma), size: CGSize(width: 1, height: 1))
        badge = SKSpriteNode(texture: Self.badgeOpen)
        badgeLabel = SKLabelNode(fontNamed: "AvenirNextCondensed-Heavy")
        super.init()

        zPosition = ZLayer.entities + 4

        fill.anchorPoint = CGPoint(x: 0.5, y: 0)
        fill.zPosition = 1

        badge.zPosition = 3
        badgeLabel.zPosition = 4
        badgeLabel.fontColor = UIColor(VV.ink)
        badgeLabel.verticalAlignmentMode = .center
        badgeLabel.horizontalAlignmentMode = .center
        badgeLabel.text = "\(moldIndex + 1)"

        addChild(base)
        addChild(fill)
        addChild(badge)
        addChild(badgeLabel)
        resize(width: width)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func resize(width: CGFloat) {
        let h = width * 0.77
        base.size = CGSize(width: width, height: h)
        innerHeight = h * 0.72
        fill.size = CGSize(width: width * 0.72, height: 1)
        fill.position = CGPoint(x: 0, y: -h * 0.40)

        let badgeSize = width * 0.42
        badge.size = CGSize(width: badgeSize * 0.92, height: badgeSize)
        badge.position = CGPoint(x: 0, y: h * 0.62)
        badgeLabel.position = CGPoint(x: 0, y: h * 0.62)
        badgeLabel.fontSize = badgeSize * 0.46
        lastFillStep = -1
    }

    /// Called every frame — cheap, and only touches the scene graph when a
    /// visible step actually changed.
    func apply(state: MoldState, fill fraction: Double) {
        let step = Int((max(0, min(1, fraction)) * 40).rounded())
        if step != lastFillStep {
            lastFillStep = step
            fill.size.height = max(0.5, CGFloat(fraction) * innerHeight)
        }
        if state != lastState {
            lastState = state
            switch state {
            case .filling:
                base.texture = Self.part
                badge.texture = Self.badgeOpen
                badgeLabel.fontColor = UIColor(VV.ink)
            case .cast:
                base.texture = Self.full
                badge.texture = Self.badgeDone
                badgeLabel.fontColor = UIColor(VV.ink)
            case .cracked, .setSolid:
                base.texture = Self.dead
                badge.texture = Self.badgeDead
                badgeLabel.fontColor = UIColor(VV.ashMid)
            }
        }
        fill.isHidden = state != .filling || fraction <= 0.02
    }

    func flash(_ color: UIColor) {
        base.run(.sequence([
            .colorize(with: color, colorBlendFactor: 0.9, duration: 0.06),
            .colorize(withColorBlendFactor: 0, duration: 0.28),
        ]))
        run(.sequence([.scale(to: 1.14, duration: 0.08), .scale(to: 1.0, duration: 0.16)]))
    }

    func attachPhysics(radius: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.mold
        body.contactTestBitMask = PhysicsCategory.gout
        body.collisionBitMask = PhysicsCategory.none
        physicsBody = body
    }
}
