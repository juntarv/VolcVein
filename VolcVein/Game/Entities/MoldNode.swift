import SpriteKit

/// A rim mold: the stone form the magma has to land in. Base art swaps between
/// open, cast and lost stone; the magma is drawn as a pool inside the tapered
/// cavity the art carves, so it never spills outside the form it is filling.
final class MoldNode: SKNode {

    let moldIndex: Int

    private let base: SKSpriteNode
    private let fill: SKShapeNode
    private let surface: SKShapeNode
    private let badge: SKSpriteNode
    private let badgeLabel: SKLabelNode

    /// `mold_empty` is authored on a 264×252 sheet while the other three states
    /// are 264×234 — the same drawing with 18px more transparent skirt under it.
    /// Cropping it back to the shared box keeps the mold from jumping a size the
    /// moment it is cast, and keeps the cavity measurements below true for every
    /// state.
    private static let empty = SKTexture(
        rect: CGRect(x: 0, y: 18.0 / 252.0, width: 1, height: 234.0 / 252.0),
        in: SKTexture(imageNamed: "mold_empty"))
    private static let full = SKTexture(imageNamed: "mold_full")
    private static let dead = SKTexture(imageNamed: "mold_set")
    private static let badgeOpen = SKTexture(imageNamed: "node_live")
    private static let badgeDone = SKTexture(imageNamed: "node_cleared")
    private static let badgeDead = SKTexture(imageNamed: "node_locked")

    // The cavity, measured off the art's 264×234 box: a trapezoid that narrows
    // from 208px across at the rim (y=25) to 144px at the floor (y=178). The
    // magma is drawn to this, not to a rectangle, or it spills out of the stone
    // at both sides and below.
    private static let cavityTop: CGFloat = 25.0 / 234.0       // from the top edge
    private static let cavityBottom: CGFloat = 178.0 / 234.0
    private static let cavityTopHalf: CGFloat = 104.0 / 264.0
    private static let cavityBottomHalf: CGFloat = 72.0 / 264.0
    /// A hair of stone left visible around the magma, so it reads as poured in
    /// rather than painted over.
    private static let cavityInset: CGFloat = 0.94

    private var cavityFloor: CGFloat = 0
    private var cavityRoof: CGFloat = 1
    private var floorHalf: CGFloat = 0
    private var roofHalf: CGFloat = 0
    private var meniscus: CGFloat = 1

    private var lastArt: MoldArt?
    private var lastFillStep: Int = -1

    /// Which stone is showing. `mold_part` is not in the rotation: it bakes a
    /// fill level into the art, which would show through under the live pool.
    private enum MoldArt: Equatable {
        case open, cast, lost
        static func of(_ s: MoldState) -> MoldArt {
            switch s {
            case .filling: return .open
            case .cast: return .cast
            case .cracked, .setSolid: return .lost
            }
        }
    }

    init(moldIndex: Int, width: CGFloat) {
        self.moldIndex = moldIndex
        base = SKSpriteNode(texture: Self.empty)
        fill = SKShapeNode()
        surface = SKShapeNode()
        badge = SKSpriteNode(texture: Self.badgeOpen)
        badgeLabel = SKLabelNode(fontNamed: "AvenirNextCondensed-Heavy")
        super.init()

        zPosition = ZLayer.entities + 4

        fill.fillColor = UIColor(VV.magma)
        fill.strokeColor = .clear
        fill.lineWidth = 0
        fill.zPosition = 1

        // The bright meniscus the authored `mold_part` art draws, kept because it
        // is what makes the level readable at a glance.
        surface.fillColor = UIColor(VV.sulfur)
        surface.strokeColor = .clear
        surface.lineWidth = 0
        surface.zPosition = 2

        badge.zPosition = 3
        badgeLabel.zPosition = 4
        badgeLabel.fontColor = UIColor(VV.ink)
        badgeLabel.verticalAlignmentMode = .center
        badgeLabel.horizontalAlignmentMode = .center
        badgeLabel.text = "\(moldIndex + 1)"

        addChild(base)
        addChild(fill)
        addChild(surface)
        addChild(badge)
        addChild(badgeLabel)
        resize(width: width)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func resize(width: CGFloat) {
        let h = width * 0.77
        base.size = CGSize(width: width, height: h)

        cavityRoof = h * (0.5 - Self.cavityTop)
        cavityFloor = h * (0.5 - Self.cavityBottom)
        roofHalf = width * Self.cavityTopHalf * Self.cavityInset
        floorHalf = width * Self.cavityBottomHalf * Self.cavityInset
        meniscus = max(1, h * 0.055)

        let badgeSize = width * 0.42
        badge.size = CGSize(width: badgeSize * 0.92, height: badgeSize)
        badge.position = CGPoint(x: 0, y: h * 0.62)
        badgeLabel.position = CGPoint(x: 0, y: h * 0.62)
        badgeLabel.fontSize = badgeSize * 0.46
        lastFillStep = -1
        lastArt = nil
    }

    /// Called every frame — cheap, and only touches the scene graph when a
    /// visible step actually changed.
    func apply(state: MoldState, fill fraction: Double) {
        let clamped = max(0, min(1, fraction))
        let step = Int((clamped * 40).rounded())
        if step != lastFillStep {
            lastFillStep = step
            let pool = Self.pool(fraction: CGFloat(clamped),
                                 floor: cavityFloor, roof: cavityRoof,
                                 floorHalf: floorHalf, roofHalf: roofHalf,
                                 meniscus: meniscus)
            fill.path = pool.magma
            surface.path = pool.surface
        }
        let art = MoldArt.of(state)
        if art != lastArt {
            lastArt = art
            switch art {
            case .open:
                base.texture = Self.empty
                badge.texture = Self.badgeOpen
                badgeLabel.fontColor = UIColor(VV.ink)
            case .cast:
                base.texture = Self.full
                badge.texture = Self.badgeDone
                badgeLabel.fontColor = UIColor(VV.ink)
            case .lost:
                base.texture = Self.dead
                badge.texture = Self.badgeDead
                badgeLabel.fontColor = UIColor(VV.ashMid)
            }
        }
        fill.isHidden = state != .filling || clamped <= 0.02
        surface.isHidden = fill.isHidden
    }

    /// The magma sitting in the cavity: a trapezoid whose sides follow the
    /// stone's taper, so the pool is always inside the mold it is filling.
    private static func pool(fraction: CGFloat, floor: CGFloat, roof: CGFloat,
                             floorHalf: CGFloat, roofHalf: CGFloat,
                             meniscus: CGFloat) -> (magma: CGPath, surface: CGPath) {
        let depth = roof - floor
        let top = floor + max(0.5, fraction * depth)
        func half(at y: CGFloat) -> CGFloat {
            let t = depth > 0 ? min(1, max(0, (y - floor) / depth)) : 0
            return floorHalf + (roofHalf - floorHalf) * t
        }
        let topHalf = half(at: top)
        let magma = CGMutablePath()
        magma.move(to: CGPoint(x: -floorHalf, y: floor))
        magma.addLine(to: CGPoint(x: floorHalf, y: floor))
        magma.addLine(to: CGPoint(x: topHalf, y: top))
        magma.addLine(to: CGPoint(x: -topHalf, y: top))
        magma.closeSubpath()

        let lip = max(floor, top - meniscus)
        let lipHalf = half(at: lip)
        let band = CGMutablePath()
        band.move(to: CGPoint(x: -lipHalf, y: lip))
        band.addLine(to: CGPoint(x: lipHalf, y: lip))
        band.addLine(to: CGPoint(x: topHalf, y: top))
        band.addLine(to: CGPoint(x: -topHalf, y: top))
        band.closeSubpath()
        return (magma, band)
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
