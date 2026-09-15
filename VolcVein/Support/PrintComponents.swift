import SwiftUI

// The shared "molten riso poster" vocabulary: rock grounds, ash-paper panels,
// ink slabs and the jagged fissure plate. Every screen is built from these so
// the print language stays identical across the app.

// MARK: - Grounds

/// Full-bleed inked rock with the halftone dot field over it. Optionally backed
/// by a painterly raster background from the asset catalogue.
struct RockBackground: View {
    var image: String? = "bg_rock_wall"
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xA8400F), Color(hex: 0x7A2A0B),
                             Color(hex: 0x571C08), Color(hex: 0x3E1306)],
                    startPoint: .top, endPoint: .bottom
                )
                if let image, UIImage(named: image) != nil {
                    Image(image)
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(0.55)
                        .blendMode(.multiply)
                }
                HalftoneField(tint: VV.magmaHot.opacity(0.26))
                AshGrain()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

/// Hot daylight sky over inked ground — the Caldera and onboarding page 1.
struct SkyBackground: View {
    var horizon: CGFloat = 0.36
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color(hex: 0x8C3410), Color(hex: 0x5A1E0C), Color(hex: 0x3A1206)],
                    startPoint: .top, endPoint: .bottom
                )
                VStack(spacing: 0) {
                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: 0xFFF0C6), Color(hex: 0xFFD089),
                                     Color(hex: 0xFFA95A), Color(hex: 0xFF8438)],
                            startPoint: .top, endPoint: .bottom
                        )
                        if UIImage(named: "bg_ash_sky") != nil {
                            Image("bg_ash_sky")
                                .resizable()
                                .renderingMode(.original)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height * horizon)
                                .clipped()
                                .opacity(0.34)
                        }
                        HalftoneField(tint: Color(hex: 0xC43A0A).opacity(0.32))
                    }
                    .frame(height: geo.size.height * horizon)
                    .clipped()
                    Spacer(minLength: 0)
                }
                HalftoneField(tint: VV.magmaHot.opacity(0.16))
                AshGrain()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

/// The 5pt halftone dot pitch from the tokens, drawn as a repeating Canvas.
struct HalftoneField: View {
    var tint: Color
    var pitch: CGFloat = 5
    var body: some View {
        Canvas { ctx, size in
            let r: CGFloat = 1.05
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                             with: .color(tint))
                    x += pitch
                }
                y += pitch
            }
        }
        .allowsHitTesting(false)
    }
}

/// Press grain — what makes the screens read as print rather than vector.
struct AshGrain: View {
    var body: some View {
        Group {
            if UIImage(named: "tex_ash_grain") != nil {
                Image("tex_ash_grain")
                    .resizable(resizingMode: .tile)
                    .renderingMode(.original)
                    .opacity(0.16)
                    .blendMode(.multiply)
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Header sash

/// The skewed ink band every secondary screen wears.
struct HeaderSash<Trailing: View>: View {
    /// Chrome height plus the top safe area, so screens can reserve exactly the
    /// room the sash occupies.
    static func height(safeTop: CGFloat) -> CGFloat { 78 + safeTop }

    @Environment(\.safeTop) private var safeTop

    let title: String
    let accent: String
    let subtitle: String
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack(alignment: .topLeading) {
            SashShape()
                .fill(VV.ink)
                .shadow(color: VV.ink.opacity(0.5), radius: 12, y: 6)
            HStack(alignment: .center, spacing: VV.s3) {
                if let onBack {
                    Button(action: onBack) {
                        Image("btn_back_stone")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .frame(width: 44, height: 44)
                            .background(VV.rock)
                            .overlay(Rectangle().stroke(VV.ashMid, lineWidth: 3))
                    }
                    .buttonStyle(PressPlateStyle())
                    .accessibilityLabel("Back")
                    .ambientPulse(from: 1.0, to: 1.04, period: 3.4)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(VV.display(VV.tTitle))
                            .foregroundStyle(VV.ash)
                        Text(accent)
                            .font(VV.display(VV.tTitle))
                            .foregroundStyle(VV.sulfur)
                    }
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    Text(subtitle)
                        .microLabel(VV.ashDeep)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: VV.s2)
                trailing
            }
            .padding(.horizontal, 14)
            .padding(.top, 4 + safeTop)
        }
        .frame(height: Self.height(safeTop: safeTop))
    }
}

extension HeaderSash where Trailing == EmptyView {
    init(title: String, accent: String, subtitle: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, accent: accent, subtitle: subtitle,
                  onBack: onBack, trailing: { EmptyView() })
    }
}

/// Counter block that rides on the right of a sash.
struct SashCounter: View {
    let value: String
    let caption: String
    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(VV.display(28))
                .foregroundStyle(VV.sulfur)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption).microLabel(VV.ashDeep)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

extension View {
    /// Reserves the sash's height and clips to what is left, so scrolling
    /// content can never ride up under the status bar or peek through the
    /// sash's skewed lower edge.
    func belowSash() -> some View {
        modifier(BelowSash())
    }
}

private struct BelowSash: ViewModifier {
    @Environment(\.safeTop) private var safeTop

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: HeaderSash<EmptyView>.height(safeTop: safeTop))
            content.clipped()
        }
    }
}

struct SashShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 14))
        p.closeSubpath()
        return p
    }
}

// MARK: - Panels

/// Ash-paper stock dropped on the rock with a hard ink offset — the contrast
/// container every readable paragraph lives in.
struct PaperPanel<Content: View>: View {
    var rail: Color = VV.sulfur
    var padding: CGFloat = VV.s3
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VV.ash)
            .overlay(alignment: .leading) { Rectangle().fill(rail).frame(width: 6) }
            .compositingGroup()
            .shadow(color: VV.ink.opacity(0.5), radius: 0, x: 0, y: 5)
            .shadow(color: VV.ink.opacity(0.36), radius: 16, x: 0, y: 12)
    }
}

/// Dark rock plate — used where paper would wash out the scene.
struct InkPanel<Content: View>: View {
    var rail: Color = VV.magma
    var padding: CGFloat = VV.s3
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: 0x1C0904).opacity(0.92))
            .overlay(alignment: .leading) { Rectangle().fill(rail).frame(width: 5) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.42), radius: 0, x: 0, y: 4)
            .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 10)
    }
}

/// Small ink caption plate — captions under world objects, node labels.
struct InkPlate<Content: View>: View {
    var underline: Color = VV.magma
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(VV.ink)
            .overlay(alignment: .bottom) { Rectangle().fill(underline).frame(height: 2) }
            .compositingGroup()
            .shadow(color: VV.ink.opacity(0.5), radius: 0, y: 3)
    }
}

// MARK: - The fissure plate (primary action)

/// A jagged sulfur fissure torn through basalt. When Ideogram supplied a plate
/// image it is used directly; otherwise the same silhouette is drawn as a path.
struct FissureShape: Shape {
    // The exact polygon from the approved design mockups.
    private static let pts: [CGPoint] = [
        .init(x: 0.00, y: 0.24), .init(x: 0.07, y: 0.06), .init(x: 0.27, y: 0.14),
        .init(x: 0.45, y: 0.02), .init(x: 0.64, y: 0.11), .init(x: 0.83, y: 0.03),
        .init(x: 0.96, y: 0.13), .init(x: 1.00, y: 0.40), .init(x: 0.94, y: 0.74),
        .init(x: 0.99, y: 0.96), .init(x: 0.76, y: 0.88), .init(x: 0.57, y: 0.99),
        .init(x: 0.36, y: 0.90), .init(x: 0.17, y: 0.98), .init(x: 0.04, y: 0.80),
        .init(x: 0.01, y: 0.54),
    ]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for (i, pt) in Self.pts.enumerated() {
            let q = CGPoint(x: rect.minX + pt.x * rect.width, y: rect.minY + pt.y * rect.height)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }
}

struct FissurePlate: View {
    let title: String
    var caption: String?
    var height: CGFloat = 82
    var titleSize: CGFloat = 36
    var rotation: Double = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // The plate is drawn, not stamped: the harvested design art has
                // its own label baked in, which would double up under ours.
                FissureShape()
                    .fill(VV.sulfurDeep)
                    .offset(y: 5)
                FissureShape()
                    .fill(LinearGradient(colors: [VV.sulfur, VV.sulfur, VV.sulfurDeep],
                                         startPoint: .top, endPoint: .bottom))
                FissureShape()
                    .stroke(VV.ink.opacity(0.35), lineWidth: 2)

                VStack(spacing: 1) {
                    Text(title)
                        .font(VV.display(titleSize))
                        .textCase(.uppercase)
                        .foregroundStyle(VV.ink)
                        .shadow(color: .white.opacity(0.32), radius: 0, y: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    if let caption {
                        Text(caption).microLabel(Color(hex: 0x6B2A05))
                    }
                }
                .padding(.horizontal, 30)
            }
            .frame(height: height)
            .rotationEffect(.degrees(rotation))
            .compositingGroup()
            .shadow(color: VV.ink.opacity(0.55), radius: 16, y: 9)
        }
        .buttonStyle(PressPlateStyle())
    }
}

/// Calmer basalt plate for secondary actions: a full-width ink slab with a
/// coloured underline and a hard drop, as in the pause and result mockups.
/// Drawn rather than stamped — the harvested `btn_secondary` art is a hollow
/// ring with a fixed 3:1 aspect, so it could never hold a long label.
struct StonePlate: View {
    let title: String
    var systemIcon: String?
    var underline: Color = VV.ashDeep
    var height: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 17, weight: .heavy))
                        // Magma-underlined "leave" plates carry a magma glyph, as drawn.
                        .foregroundStyle(underline == VV.magma ? VV.magma : VV.sulfur)
                }
                Text(title)
                    .font(VV.display(21))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(VV.ash)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                VV.ink
                    .overlay(alignment: .top) {
                        // A faint lit edge so the slab reads as stone, not a flat fill.
                        Rectangle().fill(VV.ash.opacity(0.07)).frame(height: 1)
                    }
            )
            .overlay(alignment: .bottom) { Rectangle().fill(underline).frame(height: 3) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
        }
        .buttonStyle(PressPlateStyle())
    }
}

// MARK: - Action dock

/// The scaffold for every screen or overlay whose action plates follow a column
/// of content. The plates are pinned to the bottom edge, above the home
/// indicator, so no button ever has to be scrolled to — on an SE as much as on
/// a Pro Max. The content gets whatever height is left: it only scrolls when it
/// genuinely overflows, and it is told that height (`viewport`) so a screen can
/// compact its hero art before resorting to scrolling at all.
struct DockedScroll<Content: View, Dock: View>: View {
    var horizontalPadding: CGFloat = VV.s3
    var dockSpacing: CGFloat = 10
    /// Where content shorter than the viewport settles — `.center` for a lone slab.
    var contentAlignment: Alignment = .top
    /// Set by screens whose root ignores the bottom safe area, so the dock still
    /// clears the home indicator.
    var clearsHomeIndicator = false
    @ViewBuilder var content: (_ viewport: CGFloat) -> Content
    @ViewBuilder var dock: Dock

    @Environment(\.safeBottom) private var safeBottom

    /// Height of the soft edge where scrolling content ducks under the dock.
    private let fade: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    content(geo.size.height)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, fade)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height, alignment: contentAlignment)
                }
                .modifier(BouncesOnlyWhenOverflowing())
                .mask(
                    VStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: fade)
                    }
                )
            }

            VStack(spacing: dockSpacing) { dock }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, VV.s1)
                .padding(.bottom, VV.s2 + (clearsHomeIndicator ? safeBottom : 0))
        }
    }
}

private struct BouncesOnlyWhenOverflowing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

// MARK: - Press feedback

/// Every interactive element drops its offset shadow and scales on press.
struct PressPlateStyle: ButtonStyle {
    var scale: CGFloat = 0.955
    /// Every tappable thing in the app uses this style, so the touch-down knock
    /// lives here rather than being re-added at each call site.
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(Motion.spring(0.22, 0.6), value: configuration.isPressed)
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { pressed in
                if pressed && haptic { Haptics.tap() }
            }
    }
}

/// World-object navigation on the Caldera — art plus an ink caption.
struct WorldNavButton: View {
    let asset: String
    let caption: String
    var size: CGFloat = 96
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(asset)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: size)
                    .shadow(color: VV.ink.opacity(0.55), radius: 10, y: 6)
                InkPlate { Text(caption).microLabel() }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressPlateStyle(scale: 0.93))
    }
}

// MARK: - Gauges

/// Horizontal fill track on paper stock, with the sulfur safe-band bracket.
struct PressureTrack: View {
    let value: Double          // 0…1
    var safeLow: Double = 0.40
    var safeHigh: Double = 0.75
    var onPaper: Bool = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(onPaper ? VV.paperShade : Color(hex: 0x3E2118))
                Rectangle()
                    .fill(value > 0.9 ? VV.danger : VV.magma)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
                Rectangle()
                    .stroke(VV.sulfurDeep, lineWidth: 2.5)
                    .background(VV.sulfur.opacity(0.18))
                    .frame(width: (safeHigh - safeLow) * geo.size.width)
                    .offset(x: safeLow * geo.size.width)
            }
            .overlay(Rectangle().stroke(onPaper ? VV.ink : VV.ashDeep.opacity(0.5), lineWidth: 2))
        }
        .frame(height: 14)
    }
}

/// A single rim-mold gauge — fills from the bottom like the real thing.
struct MoldGauge: View {
    let index: Int
    let fill: Double           // 0…1
    let state: MoldVisualState

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(state == .dead ? VV.obsidian : VV.paperShade)
            if state != .dead {
                Rectangle()
                    .fill(LinearGradient(colors: [VV.magma, VV.sulfur],
                                         startPoint: .bottom, endPoint: .top))
                    .frame(height: max(0, min(1, fill)) * 44)
            }
            if state == .cracked {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(VV.danger)
            }
            VStack {
                HStack {
                    Text("\(index)")
                        .font(VV.display(13))
                        .foregroundStyle(state == .dead ? VV.ashMid : VV.ink)
                        .padding(.leading, 5).padding(.top, 3)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(height: 44)
        .overlay(Rectangle().stroke(state == .dead ? VV.obsidian : VV.ink, lineWidth: 3))
    }
}

enum MoldVisualState { case filling, full, cracked, dead }

// MARK: - Edge states

/// The shared empty / first-run / finished plate. Every list in the app has one
/// so a fresh install never shows a blank screen.
struct EdgeStatePlate: View {
    let art: String
    let title: String
    let message: String
    var accent: Color = VV.sulfur
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(art)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: 84)
                .opacity(0.9)
                .shadow(color: VV.ink.opacity(0.5), radius: 10, y: 6)
                .ambientPulse(from: 0.95, to: 1.05, period: 3.1)

            Text(title)
                .font(VV.display(26))
                .textCase(.uppercase)
                .foregroundStyle(VV.ash)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(VV.body(13))
                .foregroundStyle(VV.ashMid)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                StonePlate(title: actionTitle, systemIcon: "chevron.right", underline: accent, height: 52, action: action)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x1C0904).opacity(0.9))
        .overlay(alignment: .leading) { Rectangle().fill(accent).frame(width: 5) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.42), radius: 0, y: 4)
        .shadow(color: .black.opacity(0.4), radius: 16, y: 10)
    }
}

/// A labelled figure on paper stock — the unit the detail screens are built from.
struct StatCell: View {
    let value: String
    let caption: String
    var tint: Color = VV.ink
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(VV.display(22))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(caption).microLabel(VV.paperText2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A row of three cast stars at a given size.
struct StarRow: View {
    let earned: Int
    var size: CGFloat = 22
    var spacing: CGFloat = 4
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { i in
                Image(i < earned ? "cast_star_on" : "cast_star_off")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
    }
}

/// The thin progress rule used under rank, rift and mark headings.
struct RuleBar: View {
    let fraction: Double
    var fill: Color = VV.magma
    var track: Color = Color(hex: 0x3E2118)
    var height: CGFloat = 9
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(track)
            GeometryReader { geo in
                Rectangle()
                    .fill(fill)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Vein diagram

/// A live miniature of a vent's vein graph, with magma visibly running up it.
/// Shared by the vent brief and the rift dossier so the two read identically.
struct VeinDiagram: View {
    let layout: VentLayout
    var height: CGFloat = 182
    var showLegend: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: VV.s2) {
            Group {
                if Motion.enabled {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        Canvas { ctx, size in
                            let period = 2.4
                            let t = timeline.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: period) / period
                            draw(&ctx, size, phase: t)
                        }
                    }
                } else {
                    Canvas { ctx, size in
                        var c = ctx
                        draw(&c, size, phase: 0.55)
                    }
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0x3A1206))

            if showLegend {
                HStack(spacing: VV.s3) {
                    legend(VV.magmaHot, "Chamber")
                    legend(VV.sulfur, "Mold")
                    legend(VV.obsidianLit, "Relief vent")
                }
            }
        }
    }

    private func legend(_ colour: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(colour)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(VV.ink, lineWidth: 2))
            Text(label).microLabel(VV.ashDeep)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, phase: Double) {
        let inset: CGFloat = 16
        let h = size.height - inset * 2
        // Hold the field to a sane aspect and centre it, or a wide canvas
        // squashes the climb into a sideways smear.
        let w = min(size.width - inset * 2, h * 1.5)
        let originX = (size.width - w) / 2
        func point(_ i: Int) -> CGPoint {
            let n = layout.nodes[i]
            // Unit space is y-up; the canvas is y-down.
            return CGPoint(x: originX + CGFloat(n.x) * w,
                           y: inset + (1 - CGFloat(n.y)) * h)
        }

        for edge in layout.edges {
            let a = point(edge.from), b = point(edge.to)
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            ctx.stroke(path, with: .color(VV.ink), style: .init(lineWidth: 7, lineCap: .round))
            ctx.stroke(path,
                       with: .color(edge.gasPocket ? VV.sulfur : VV.magma),
                       style: .init(lineWidth: 3.4, lineCap: .round))

            // The gout running the branch — this is the diagram's living part.
            let t = CGFloat(phase)
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            let r: CGFloat = 3.2
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                     with: .color(VV.magmaPale))
        }

        for i in layout.nodes.indices {
            let p = point(i)
            let kind = layout.nodes[i].kind
            let r: CGFloat = kind == .chamber ? 7 : (kind == .mold ? 6 : 4)
            let colour: Color = kind == .chamber
                ? VV.magmaHot
                : (kind == .mold ? VV.sulfur
                   : (layout.outEdges[i].isEmpty ? VV.obsidianLit : VV.ashMid))
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(VV.ink))
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: 1.6, dy: 1.6)), with: .color(colour))
        }
    }
}
