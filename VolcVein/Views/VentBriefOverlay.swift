import CoreData
import SwiftUI

/// The briefing sheet you get before dropping into a vent: what the network
/// looks like, what the mountain will throw at you, and what you have already
/// pulled out of it.
struct VentBriefOverlay: View {
    @Environment(\.managedObjectContext) private var ctx

    let ventNumber: Int
    let onEnter: () -> Void
    let onClose: () -> Void

    /// The column's laid-out height without the diagram in it. The diagram is
    /// sized from this so it takes exactly the room left above the dock.
    @State private var restHeight: CGFloat = 0

    /// The diagram's drawn height before the column has been measured.
    private static let diagramNatural: CGFloat = 182
    /// The most a sparse brief on a tall screen lets the diagram grow to.
    private static let diagramMax: CGFloat = 200
    /// The dock's soft edge below the column, plus slack, so a fitted column
    /// never tips over into scrolling on a rounding error.
    private static let dockFade: CGFloat = 16

    private var layout: VentLayout { VentCatalog.layout(for: ventNumber) }
    private var rift: RiftSpec { RiftCatalog.spec(layout.riftIndex) }
    private var progress: VentProgressEntity? { ProgressStore.vent(ventNumber, in: ctx) }
    private var award: CastSpec? { CastCatalog.spec(awardedBy: ventNumber) }

    private var valveCount: Int {
        layout.edges.indices.filter { !layout.chambers.contains(layout.edges[$0].from) }.count
    }
    private var gasCount: Int { layout.edges.filter(\.gasPocket).count }
    private var reliefCount: Int {
        layout.nodes.indices.filter {
            layout.nodes[$0].kind == .junction && layout.outEdges[$0].isEmpty
        }.count
    }

    var body: some View {
        ZStack {
            VV.scrim.ignoresSafeArea()
                .onTapGesture { onClose() }
            AmbientEmbers(count: 12, tint: VV.magmaHot, speed: 0.6, seed: 303)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { geo in
                // An SE-class screen gets slimmer plates so the brief itself
                // keeps enough height to read.
                let short = geo.size.height < 700
                // The map underneath ignores the bottom safe area, so the dock
                // has to clear the home indicator on its own.
                DockedScroll(horizontalPadding: VV.s3 + 2,
                             dockSpacing: short ? 8 : 10,
                             clearsHomeIndicator: true) { viewport in
                    column(viewport: viewport)
                } dock: {
                    FissurePlate(title: "Descend",
                                 height: short ? 64 : 76,
                                 titleSize: short ? 30 : 34) {
                        Haptics.knock()
                        onEnter()
                    }
                    .vvEntrance(5)
                    StonePlate(title: "Back to the map", systemIcon: "chevron.left",
                               height: short ? 46 : 52) {
                        onClose()
                    }
                    .vvEntrance(5)
                }
            }
        }
    }

    // MARK: - Column

    /// Everything above the dock. The chrome tightens on an SE-class viewport,
    /// and the vein diagram gives up height before the column resorts to
    /// scrolling.
    private func column(viewport: CGFloat) -> some View {
        let tight = viewport < 560
        let diagramHeight = fittedDiagramHeight(viewport: viewport, tight: tight)
        return VStack(spacing: tight ? 9 : 11) {
            header(tight: tight).vvEntrance(0)
            diagram(height: diagramHeight, tight: tight).vvEntrance(1)
            facts(tight: tight).vvEntrance(2)
            Group {
                if let progress, progress.cleared {
                    bestCard(progress, tight: tight)
                } else {
                    unplayedCard(tight: tight)
                }
            }
            .vvEntrance(3)
            if let award { awardCard(award, tight: tight).vvEntrance(4) }
        }
        .padding(.top, tight ? 6 : 10)
        .background {
            GeometryReader { g in
                Color.clear.preference(key: BriefRestHeightKey.self,
                                       value: (g.size.height - diagramHeight).rounded())
            }
        }
        .onPreferenceChange(BriefRestHeightKey.self) { rest in
            // Whole points only, so a sub-pixel wobble can never feed back.
            if abs(rest - restHeight) >= 1 { restHeight = rest }
        }
    }

    /// The room the column leaves over, held between a floor where the network
    /// still reads as a network and a ceiling where it stops gaining anything.
    private func fittedDiagramHeight(viewport: CGFloat, tight: Bool) -> CGFloat {
        guard restHeight > 0 else { return Self.diagramNatural }
        let legible: CGFloat = tight ? 108 : 128
        let room = (viewport - restHeight - Self.dockFade).rounded(.down)
        return min(Self.diagramMax, max(legible, room))
    }

    // MARK: - Pieces

    private func header(tight: Bool) -> some View {
        // No gap under the slab: its tilt tucks the rift tag against one
        // corner like a second sticker, and the header stays short.
        VStack(spacing: 0) {
            Text("Vent \(String(format: "%02d", ventNumber))")
                .font(VV.display(tight ? 40 : 46))
                .textCase(.uppercase)
                .foregroundStyle(VV.ash)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, VV.s4 - 2)
                .padding(.vertical, tight ? 6 : 8)
                .background(VV.ink)
                .overlay(alignment: .leading) { Rectangle().fill(VV.magma).frame(width: 6) }
                .compositingGroup()
                .rotationEffect(.degrees(-2))
                .shadow(color: VV.ink.opacity(0.45), radius: 0, x: 7, y: 7)

            Text("Rift \(rift.numeral) · \(rift.name)")
                .font(VV.display(VV.tMicro))
                .tracking(VV.trackWide)
                .textCase(.uppercase)
                .foregroundStyle(VV.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(VV.sulfur)
                .rotationEffect(.degrees(1.5))
                .compositingGroup()
                .shadow(color: VV.sulfurDeep, radius: 0, y: 3)
        }
    }

    private func diagram(height: CGFloat, tight: Bool) -> some View {
        InkPanel(rail: VV.sulfur, padding: tight ? 10 : 12) {
            VStack(alignment: .leading, spacing: tight ? 6 : VV.s2) {
                Text("The network").microLabel(VV.ashDeep)
                VeinDiagram(layout: layout, height: height)
            }
        }
    }

    private func facts(tight: Bool) -> some View {
        PaperPanel(rail: VV.magma, padding: tight ? 11 : 12) {
            VStack(alignment: .leading, spacing: tight ? 8 : 10) {
                HStack(spacing: 10) {
                    StatCell(value: "\(layout.moldCount)", caption: "Rim molds", tint: VV.magma)
                    StatCell(value: "\(valveCount)", caption: "Valves")
                    StatCell(value: String(format: "%.1fs", layout.crustSeconds), caption: "Crust in")
                }
                Rectangle().fill(VV.ashMid).frame(height: 1)
                HStack(spacing: 10) {
                    StatCell(value: gasCount > 0 ? "\(gasCount)" : "—", caption: "Gas pockets")
                    StatCell(value: layout.tremorInterval > 0
                             ? String(format: "%.0fs", layout.tremorInterval) : "—",
                             caption: "Tremors")
                    StatCell(value: reliefCount > 0 ? "\(reliefCount)" : "—", caption: "Relief vents")
                }
                Text(riftWarning)
                    .font(VV.body(12.5))
                    .foregroundStyle(VV.paperText3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var riftWarning: String { RiftCatalog.wrinkle(layout.riftIndex) }

    private func bestCard(_ p: VentProgressEntity, tight: Bool) -> some View {
        PaperPanel(rail: VV.sulfur, padding: tight ? 11 : 12) {
            VStack(alignment: .leading, spacing: tight ? 7 : 9) {
                HStack {
                    Text("Your best").microLabel(VV.paperText2)
                    Spacer(minLength: 8)
                    StarRow(earned: Int(p.starsEarned), size: 20)
                }
                HStack(spacing: 10) {
                    StatCell(value: Int(p.bestScore).castFormatted, caption: "Score", tint: VV.magma)
                    StatCell(value: "\(Int((p.bestYield * 100).rounded()))%", caption: "Yield")
                    StatCell(value: "\(p.attempts)", caption: "Descents")
                }
                if p.starsEarned < 3 {
                    Text(starHint(for: p))
                        .font(VV.body(12.5))
                        .foregroundStyle(VV.paperText3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func starHint(for p: VentProgressEntity) -> String {
        if p.starsEarned <= 1 { return "Second star: finish at 90% yield or better. Third: cast it without letting a single vein crust shut." }
        return "Third star: cast it without letting a single vein crust shut."
    }

    private func unplayedCard(tight: Bool) -> some View {
        PaperPanel(rail: VV.obsidianLit, padding: tight ? 11 : 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Not yet cast").microLabel(VV.paperText2)
                Text("No descent recorded here. Fill every rim mold before the chamber redlines and the rift will sign it.")
                    .font(VV.body(13))
                    .foregroundStyle(VV.paperText3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func awardCard(_ spec: CastSpec, tight: Bool) -> some View {
        let unlocked = ProgressStore.casts(in: ctx)
            .first { $0.castKey == spec.key }?.unlocked ?? false
        return InkPanel(rail: unlocked ? VV.sulfur : VV.obsidianLit, padding: tight ? 10 : 12) {
            HStack(spacing: tight ? 11 : 13) {
                Image(unlocked ? spec.asset : "cast_locked_lump")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: tight ? 38 : 44, height: tight ? 38 : 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(unlocked ? "Already cast" : "Casts on a clear").microLabel(VV.ashDeep)
                    Text(spec.name)
                        .font(VV.display(tight ? 19 : 21))
                        .textCase(.uppercase)
                        .foregroundStyle(VV.ash)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// The brief column's height without its diagram, reported up from layout.
private struct BriefRestHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
