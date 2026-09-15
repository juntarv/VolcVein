import CoreData
import SwiftUI

/// One rift, end to end: what it does to you, how far through it you are, every
/// vent in it and every piece it casts. Reached by tapping a rift band on the map.
struct RiftDossierView: View {
    @Environment(\.managedObjectContext) private var ctx

    let riftIndex: Int
    let onBack: () -> Void
    let onEnter: (Int) -> Void

    @FetchRequest private var vents: FetchedResults<VentProgressEntity>
    @FetchRequest private var casts: FetchedResults<CastEntity>
    @State private var detailKey: String?

    init(riftIndex: Int, onBack: @escaping () -> Void, onEnter: @escaping (Int) -> Void) {
        self.riftIndex = riftIndex
        self.onBack = onBack
        self.onEnter = onEnter
        _vents = FetchRequest(
            entity: VentProgressEntity.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \VentProgressEntity.ventNumber, ascending: true)],
            predicate: NSPredicate(format: "riftIndex == %d", riftIndex)
        )
        _casts = FetchRequest(
            entity: CastEntity.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \CastEntity.orderIndex, ascending: true)],
            predicate: NSPredicate(format: "awardVent >= %d AND awardVent <= %d",
                                   VentCatalog.firstVent(ofRift: riftIndex),
                                   VentCatalog.lastVent(ofRift: riftIndex))
        )
    }

    private var spec: RiftSpec { RiftCatalog.spec(riftIndex) }
    private var cleared: Int { vents.filter { $0.cleared }.count }
    private var stars: Int { vents.reduce(0) { $0 + Int($1.starsEarned) } }
    private var starsPossible: Int { VentCatalog.ventsPerRift * 3 }
    private var unlocked: Bool { vents.contains { $0.unlocked } }
    private var castsGot: Int { casts.filter { $0.unlocked }.count }
    private var bestScore: Int { vents.map { Int($0.bestScore) }.max() ?? 0 }
    private var meanYield: Double {
        let done = vents.filter { $0.cleared }
        return done.isEmpty ? 0 : done.reduce(0) { $0 + $1.bestYield } / Double(done.count)
    }
    /// The vent that best shows this rift's shape — the middle of the run.
    private var signatureVent: Int { VentCatalog.firstVent(ofRift: riftIndex) + 5 }
    private var nextVent: Int? {
        vents.first { $0.unlocked && !$0.cleared }.map { Int($0.ventNumber) }
            ?? vents.first { $0.unlocked }.map { Int($0.ventNumber) }
    }

    /// Below this much room under the sash (an SE) the descend plate trims down.
    private static let shortArea: CGFloat = 600
    /// Content viewports under these heights give up diagram height and gaps first.
    private static let compactViewport: CGFloat = 600
    private static let tightViewport: CGFloat = 500

    var body: some View {
        ZStack(alignment: .top) {
            RockBackground()
            AmbientEmbers(count: 14, tint: VV.magmaHot, speed: 0.8, seed: UInt64(riftIndex) &* 31)
                .ignoresSafeArea()

            // The descend plate is the screen's one call to action, so it rides a
            // dock above the home indicator; the cards scroll over it only when
            // they outgrow what is left.
            GeometryReader { area in
                DockedScroll(clearsHomeIndicator: true) { viewport in
                    column(viewport)
                } dock: {
                    if unlocked, let nextVent {
                        actions(nextVent, compact: area.size.height < Self.shortArea)
                            .vvEntrance(5)
                    }
                }
            }
            .belowSash()

            HeaderSash(title: "Rift \(spec.numeral)", accent: spec.name,
                       subtitle: spec.subtitle,
                       onBack: onBack) {
                SashCounter(value: "\(cleared)/\(VentCatalog.ventsPerRift)", caption: "Cast")
            }

            if let detailKey {
                CastDetailOverlay(
                    castKey: detailKey,
                    onClose: { self.detailKey = nil },
                    onPlayVent: onEnter
                )
                .transition(.opacity)
            }
        }
        .animation(Motion.ease(0.2), value: detailKey)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Column

    /// Everything above the dock. The sealed plate keeps its own way back — it is
    /// short enough to sit whole on an SE.
    private func column(_ viewport: CGFloat) -> some View {
        let compact = viewport < Self.compactViewport
        let tight = viewport < Self.tightViewport
        return VStack(spacing: compact ? VV.s2 + 4 : VV.s3) {
            if unlocked {
                crest(diagramHeight: tight ? 140 : (compact ? 160 : 186)).vvEntrance(0)
                masteryCard.vvEntrance(1)
                wrinkleCard.vvEntrance(2)
                ventStrip.vvEntrance(3)
                castStrip.vvEntrance(4)
            } else {
                sealedState.vvEntrance(0)
            }

            // Room for the last card's drop before the column fades into the dock.
            Color.clear.frame(height: VV.s2)
        }
    }

    // MARK: - Pieces

    private func crest(diagramHeight: CGFloat) -> some View {
        InkPanel(rail: VV.sulfur, padding: 12) {
            VStack(alignment: .leading, spacing: VV.s2) {
                HStack {
                    Text("The shape of it").microLabel(VV.ashDeep)
                    Spacer(minLength: VV.s1)
                    Text("Vent \(signatureVent)").microLabel(VV.magmaCore)
                }
                VeinDiagram(layout: VentCatalog.layout(for: signatureVent), height: diagramHeight)
            }
        }
    }

    private var masteryCard: some View {
        PaperPanel(rail: VV.magma, padding: VV.s3) {
            VStack(alignment: .leading, spacing: VV.s2 + 3) {
                HStack {
                    Text("Mastery").microLabel(VV.paperText2)
                    Spacer(minLength: VV.s1)
                    Text("\(Int((Double(stars) / Double(starsPossible) * 100).rounded()))%")
                        .font(VV.display(21))
                        .foregroundStyle(VV.magma)
                        .contentTransition(.numericText())
                }
                ShimmerRule(fraction: Double(stars) / Double(starsPossible),
                            fill: VV.magma, track: VV.paperShade, height: 10)
                HStack(spacing: VV.s2 + 2) {
                    StatCell(value: "\(cleared)/\(VentCatalog.ventsPerRift)", caption: "Vents cast", tint: VV.magma)
                    StatCell(value: "\(stars)/\(starsPossible)", caption: "Cast stars")
                    StatCell(value: "\(castsGot)/\(casts.count)", caption: "Pieces")
                }
                Rectangle().fill(VV.ashMid).frame(height: 1)
                HStack(spacing: VV.s2 + 2) {
                    StatCell(value: bestScore > 0 ? bestScore.castFormatted : "—", caption: "Best score")
                    StatCell(value: meanYield > 0 ? "\(Int((meanYield * 100).rounded()))%" : "—",
                             caption: "Mean yield")
                    StatCell(value: "\(vents.reduce(0) { $0 + Int($1.attempts) })", caption: "Descents")
                }
            }
        }
    }

    private var wrinkleCard: some View {
        InkPanel(rail: VV.magma, padding: VV.s3) {
            VStack(alignment: .leading, spacing: VV.s2) {
                Text("What this rift does").microLabel(VV.ashDeep)
                Text(RiftCatalog.wrinkle(riftIndex))
                    .font(VV.body(13.5))
                    .foregroundStyle(VV.ashMid)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var ventStrip: some View {
        PaperPanel(rail: VV.sulfur, padding: VV.s3) {
            VStack(alignment: .leading, spacing: VV.s2 + 2) {
                Text("Every vent").microLabel(VV.paperText2)
                let columns = Array(repeating: GridItem(.flexible(), spacing: VV.s2), count: 5)
                LazyVGrid(columns: columns, spacing: VV.s2 + 2) {
                    ForEach(vents, id: \.objectID) { vent in
                        ventChip(vent)
                    }
                }
            }
        }
    }

    private func ventChip(_ vent: VentProgressEntity) -> some View {
        let n = Int(vent.ventNumber)
        let isOpen = vent.unlocked
        return Button {
            guard isOpen else {
                Haptics.warn()
                return
            }
            Haptics.knock()
            onEnter(n)
        } label: {
            VStack(spacing: 3) {
                Image(vent.cleared ? "node_cleared" : (isOpen ? "node_live" : "node_locked"))
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 46, height: 50)
                    .overlay {
                        Text("\(n)")
                            .font(VV.display(17))
                            .foregroundStyle(isOpen ? VV.ink : VV.ashMid)
                            .offset(y: -1)
                            .shadow(color: (isOpen ? VV.magmaPale : VV.obsidian).opacity(0.85),
                                    radius: 2)
                    }
                if vent.cleared {
                    StarRow(earned: Int(vent.starsEarned), size: 9, spacing: 1.5)
                } else {
                    Color.clear.frame(height: 9)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressPlateStyle(scale: 0.9))
        .disabled(!isOpen)
    }

    private var castStrip: some View {
        PaperPanel(rail: VV.obsidianLit, padding: VV.s3) {
            VStack(alignment: .leading, spacing: VV.s2 + 2) {
                HStack {
                    Text("What it casts").microLabel(VV.paperText2)
                    Spacer(minLength: VV.s1)
                    Text("\(castsGot)/\(casts.count)")
                        .microLabel(castsGot == casts.count ? VV.sulfurDeep : VV.paperText2)
                }
                HStack(alignment: .bottom, spacing: VV.s2) {
                    ForEach(casts, id: \.objectID) { cast in
                        castChip(cast)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func castChip(_ cast: CastEntity) -> some View {
        let got = cast.unlocked
        return Button {
            detailKey = cast.castKey
        } label: {
            VStack(spacing: 3) {
                Image(got ? (cast.assetName ?? "cast_emberdrop") : "cast_locked_lump")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: 46)
                    .saturation(got ? 1 : 0.2)
                Text(got ? "★\(cast.earnedStars)" : "\(cast.awardVent)")
                    .microLabel(got ? VV.paperText2 : VV.ashDeep)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressPlateStyle(scale: 0.92))
    }

    private func actions(_ vent: Int, compact: Bool) -> some View {
        FissurePlate(title: cleared == VentCatalog.ventsPerRift ? "Raise a star" : "Descend",
                     caption: "Vent \(String(format: "%02d", vent))",
                     height: compact ? 66 : 76, titleSize: compact ? 28 : 32) {
            Haptics.knock()
            onEnter(vent)
        }
    }

    private var sealedState: some View {
        EdgeStatePlate(
            art: "cast_locked_lump",
            title: "This rift is still sealed",
            message: "Clear seven vents in Rift \(RiftCatalog.numeral(max(1, riftIndex - 1))) and the rock above it opens up. Everything in here is waiting.",
            accent: VV.obsidianLit,
            actionTitle: "Back to the map",
            action: onBack
        )
        .padding(.top, VV.s4)
    }
}
