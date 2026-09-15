import Foundation

/// The single source of truth for every collision bitmask in VolcVein.
/// No other file defines or modifies a category.
enum PhysicsCategory {
    static let none:    UInt32 = 0
    static let gout:    UInt32 = 1 << 0
    static let mold:    UInt32 = 1 << 1
    static let chamber: UInt32 = 1 << 2
    static let all:     UInt32 = .max
}

/// Fixed rendering layers — never improvised.
enum ZLayer {
    static let background: CGFloat = -100
    static let entities: CGFloat = 0
    static let effects: CGFloat = 50
    static let hud: CGFloat = 100
}
