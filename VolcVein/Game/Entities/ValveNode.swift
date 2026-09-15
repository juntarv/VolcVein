import SpriteKit

/// The only thing the player touches. Art comes straight from the approved
/// design: `valve_open`, `valve_shut`, `valve_crusted`.
final class ValveNode: SKNode {

    let edgeIndex: Int

    private let sprite: SKSpriteNode
    /// Fills up while a crusted valve is being held down.
    private let holdRing: SKShapeNode
    private static let openTexture = SKTexture(imageNamed: "valve_open")
    private static let shutTexture = SKTexture(imageNamed: "valve_shut")
    private static let crustedTexture = SKTexture(imageNamed: "valve_crusted")

    private(set) var state: EdgeState = .open

    init(edgeIndex: Int, size: CGFloat) {
        self.edgeIndex = edgeIndex
        sprite = SKSpriteNode(texture: Self.openTexture)
        sprite.size = CGSize(width: size * 0.9, height: size)
        holdRing = SKShapeNode(circleOfRadius: size * 0.86)
        super.init()

        zPosition = ZLayer.entities + 6

        holdRing.fillColor = UIColor(VV.sulfur).withAlphaComponent(0.42)
        holdRing.strokeColor = UIColor(VV.sulfur)
        holdRing.lineWidth = 3
        holdRing.zPosition = -1
        holdRing.setScale(0.001)
        holdRing.isHidden = true

        addChild(holdRing)
        addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func resize(_ size: CGFloat) {
        sprite.size = CGSize(width: size * 0.9, height: size)
    }

    func apply(_ newState: EdgeState) {
        guard newState != state else { return }
        state = newState
        switch newState {
        case .open: sprite.texture = Self.openTexture
        case .shut: sprite.texture = Self.shutTexture
        case .crusted: sprite.texture = Self.crustedTexture
        }
    }

    /// 0…1 — driven from `update(_:)`, so it scales a prebuilt node rather than
    /// rebuilding an arc path every frame.
    func setHoldProgress(_ progress: Double) {
        if progress <= 0 {
            holdRing.isHidden = true
            holdRing.setScale(0.001)
        } else {
            holdRing.isHidden = false
            holdRing.setScale(max(0.001, CGFloat(progress)))
        }
    }

    /// A short white pulse — the hit-flash the juice checklist calls for.
    func flash() {
        sprite.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 0.85, duration: 0.05),
            .colorize(withColorBlendFactor: 0, duration: 0.22),
        ]))
    }

    func nudge() {
        sprite.run(.sequence([
            .scale(to: 1.22, duration: 0.07),
            .scale(to: 1.0, duration: 0.14),
        ]))
    }
}
