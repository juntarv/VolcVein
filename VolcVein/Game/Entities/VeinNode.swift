import SpriteKit

/// One branch of the network: ink casing, magma core and a pale highlight,
/// exactly as the design draws them. The three shapes are built once; changing
/// state only swaps colours and a precomputed path.
final class VeinNode: SKNode {

    let edgeIndex: Int
    private let casing = SKShapeNode()
    private let core = SKShapeNode()
    private let highlight = SKShapeNode()

    private var solidPath: CGPath?
    private var crustedPath: CGPath?

    init(edgeIndex: Int) {
        self.edgeIndex = edgeIndex
        super.init()
        zPosition = ZLayer.entities

        casing.strokeColor = UIColor(VV.ink)
        casing.lineCap = .round
        casing.fillColor = .clear
        casing.zPosition = 0

        core.lineCap = .round
        core.fillColor = .clear
        core.zPosition = 1

        highlight.strokeColor = UIColor(VV.magmaPale)
        highlight.lineCap = .round
        highlight.fillColor = .clear
        highlight.zPosition = 2

        addChild(casing)
        addChild(core)
        addChild(highlight)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Rebuilt only when the scene resizes, never per frame.
    func setGeometry(path: CGPath, width: CGFloat) {
        solidPath = path
        crustedPath = path.copy(dashingWithPhase: 0, lengths: [width * 1.2, width * 0.85])

        casing.path = path
        casing.lineWidth = width * 1.72
        core.lineWidth = width
        highlight.path = path
        highlight.lineWidth = max(2, width * 0.30)
        apply(.open)
    }

    func apply(_ state: EdgeState) {
        switch state {
        case .open:
            core.path = solidPath
            core.strokeColor = UIColor(VV.magma)
            core.alpha = 1
            highlight.isHidden = false
        case .shut:
            core.path = solidPath
            core.strokeColor = UIColor(VV.rock)
            core.alpha = 1
            highlight.isHidden = true
        case .crusted:
            core.path = crustedPath
            core.strokeColor = UIColor(VV.obsidian)
            core.alpha = 1
            highlight.isHidden = true
        }
    }
}
