import SwiftUI
import UIKit

/// Palette and type scale transcribed from `design-tokens.css` — that file is the
/// source of truth, these constants mirror it one-for-one.
enum VV {

    // MARK: - Colour

    /// Dominant ink — molten orange. The app's voice.
    static let magma      = Color(hex: 0xFF5A1F)
    static let magmaHot   = Color(hex: 0xFF8A2B)
    static let magmaCore  = Color(hex: 0xFFD07A)
    static let magmaPale  = Color(hex: 0xFFE2A6)

    /// Accent ink — sulfur yellow. Primary actions, earned marks, open valves.
    static let sulfur     = Color(hex: 0xFFC21A)
    static let sulfurDeep = Color(hex: 0xD99200)

    /// Rock neutrals — warm browns, never near-black.
    static let ink        = Color(hex: 0x2B0F08)
    static let rockDeep   = Color(hex: 0x5A1E0C)
    static let rock       = Color(hex: 0x8C3410)
    static let rockLit    = Color(hex: 0xB8471A)
    static let rockFlare  = Color(hex: 0xC9531F)

    /// Paper stock — contrast containers only.
    static let ash        = Color(hex: 0xF2E7D8)
    static let ashMid     = Color(hex: 0xC9B7A4)
    static let ashDeep    = Color(hex: 0x9A8776)
    static let paperShade = Color(hex: 0xDCCBB6)
    static let paperText2 = Color(hex: 0x7A4A32)
    static let paperText3 = Color(hex: 0x6B4030)

    /// Functional state ink — cooled rock ONLY.
    static let obsidian    = Color(hex: 0x12383D)
    static let obsidianLit = Color(hex: 0x1E5A60)
    static let obsidianFacet = Color(hex: 0x79C0B8)
    static let uncastStone = Color(hex: 0x5A4A3E)

    /// Semantic.
    static let danger = Color(hex: 0xC22A12)
    static let scrim  = Color(hex: 0x2B0F08).opacity(0.72)

    // MARK: - Spacing (8px scale)

    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 16
    static let s4: CGFloat = 24
    static let s5: CGFloat = 32
    static let s6: CGFloat = 48
    static let s7: CGFloat = 64

    // MARK: - Radius (hard-edged print)

    static let rSm: CGFloat = 2
    static let rMd: CGFloat = 4
    static let rLg: CGFloat = 8

    // MARK: - Type
    //
    // Both families ship with iOS — nothing is downloaded, nothing drifts.
    // The design runs on two extremes: 800 condensed for everything structural,
    // 400 regular for the few places that need real reading.

    private static let displayFace = "AvenirNextCondensed-Heavy"
    private static let displayMid  = "AvenirNextCondensed-DemiBold"
    private static let bodyFace    = "AvenirNext-Regular"
    private static let bodyBold    = "AvenirNext-DemiBold"
    private static let bodyThin    = "AvenirNext-UltraLight"

    static func display(_ size: CGFloat) -> Font { .custom(displayFace, size: size) }
    static func displaySoft(_ size: CGFloat) -> Font { .custom(displayMid, size: size) }
    static func body(_ size: CGFloat) -> Font { .custom(bodyFace, size: size) }
    static func bodyStrong(_ size: CGFloat) -> Font { .custom(bodyBold, size: size) }
    static func thin(_ size: CGFloat) -> Font { .custom(bodyThin, size: size) }

    /// Scale — few steps, large jumps (11 → 15 → 22 → 30 → 42 → 66).
    static let tMicro: CGFloat   = 11
    static let tBody: CGFloat    = 15
    static let tNumeral: CGFloat = 22
    static let tTitle: CGFloat   = 30
    static let tDisplay: CGFloat = 42
    static let tHero: CGFloat    = 66

    static let trackWide: CGFloat = 2.2   // ~0.2em at 11pt
    static let trackTight: CGFloat = -0.6
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Text helpers

extension View {
    /// Uppercase micro label — always sits on a solid plate, never on bare art.
    func microLabel(_ color: Color = VV.ash) -> some View {
        self.font(VV.display(VV.tMicro))
            .tracking(VV.trackWide)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    /// The double shadow the design uses wherever ink meets rock.
    func carved() -> some View {
        self.shadow(color: VV.ink.opacity(0.6), radius: 4, x: 0, y: 2)
            .shadow(color: VV.ink.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}

/// The device's top inset. Screens whose background deliberately ignores the
/// safe area still have to keep their chrome out from under the status bar and
/// Dynamic Island.
///
/// Measured once by SwiftUI at the root (`HomeView`) and handed down through the
/// environment. It must never be read from `UIWindow` inside a `body`: doing so
/// forces a UIKit layout pass mid-update, and the view that triggered it stops
/// redrawing when its own `@State` changes — onboarding's "Go on" did nothing.
private struct SafeTopKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

/// The home-indicator inset, measured alongside `safeTop`, for screens whose
/// root ignores the bottom safe area but still pin controls to the bottom edge.
private struct SafeBottomKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var safeTop: CGFloat {
        get { self[SafeTopKey.self] }
        set { self[SafeTopKey.self] = newValue }
    }

    var safeBottom: CGFloat {
        get { self[SafeBottomKey.self] }
        set { self[SafeBottomKey.self] = newValue }
    }
}

extension Int {
    /// Cast scores read as "8,420" the way the design plates them.
    var castFormatted: String {
        Self.castFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    private static let castFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.groupingSize = 3
        return f
    }()
}
