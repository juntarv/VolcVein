import CoreData
import SwiftUI

/// A single obsidian piece at full size, with its story and the run that pulled
/// it out of the mountain.
struct CastDetailOverlay: View {
    @Environment(\.managedObjectContext) private var ctx

    let castKey: String
    let onClose: () -> Void
    let onPlayVent: (Int) -> Void

    private var spec: CastSpec? { CastCatalog.spec(key: castKey) }
    private var entity: CastEntity? {
        ProgressStore.casts(in: ctx).first { $0.castKey == castKey }
    }
    private var ventProgress: VentProgressEntity? {
        guard let spec else { return nil }
        return ProgressStore.vent(spec.awardVent, in: ctx)
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("bg_cast_result")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            VV.scrim.ignoresSafeArea()
            AmbientEmbers(count: 14, tint: VV.obsidianFacet, speed: 0.55, seed: 404)
                .ignoresSafeArea()

            // Both hosts (vault and dossier) ignore the bottom safe area, so the
            // dock clears the home indicator itself. The top inset is already
            // respected by the container — no second `safeTop` inside.
            GeometryReader { geo in
                let roomyDock = geo.size.height >= 700
                DockedScroll(horizontalPadding: VV.s3 + 2,
                             dockSpacing: roomyDock ? 10 : 8,
                             contentAlignment: .center,
                             clearsHomeIndicator: true) { viewport in
                    column(viewport: viewport)
                } dock: {
                    actions(roomy: roomyDock)
                }
            }
        }
    }

    // MARK: - Fit

    /// Spacing and hero scale for the height the column actually gets. The piece
    /// only shrinks as far as the screen demands: a Pro Max shows it at full
    /// stage, a 390pt phone settles without scrolling, an SE keeps the ledger in
    /// view with at most a nudge.
    private struct Fit {
        var top: CGFloat
        var gap: CGFloat
        var hero: CGFloat
        var nameSize: CGFloat
        var namePad: CGFloat
        var storyPad: CGFloat
        var panelPad: CGFloat
        var rowGap: CGFloat

        /// A sealed piece carries the short requirement card instead of the
        /// provenance ledger, which hands its height back to the hero.
        static func forViewport(_ viewport: CGFloat, unlocked: Bool) -> Fit {
            let relief: CGFloat = unlocked ? 0 : 110
            if viewport >= 700 {
                return Fit(top: 20, gap: 14, hero: 210, nameSize: 32, namePad: 11,
                           storyPad: 14, panelPad: 13, rowGap: 11)
            }
            if viewport >= 540 {
                // Everything below the hero needs ~448pt with a three-line story.
                return Fit(top: 18, gap: 12, hero: min(196, max(140, viewport - 448 + relief)),
                           nameSize: 28, namePad: 9, storyPad: 12, panelPad: 12, rowGap: 9)
            }
            return Fit(top: 12, gap: 10, hero: min(150, max(104, viewport - 400 + relief)),
                       nameSize: 26, namePad: 8, storyPad: 11, panelPad: 11, rowGap: 8)
        }
    }

    // MARK: - Column

    @ViewBuilder
    private func column(viewport: CGFloat) -> some View {
        if let spec, let entity {
            let fit = Fit.forViewport(viewport, unlocked: entity.unlocked)
            VStack(spacing: fit.gap) {
                hero(spec: spec, unlocked: entity.unlocked, fit: fit).vvEntrance(0)
                nameplate(spec: spec, unlocked: entity.unlocked, fit: fit).vvEntrance(1)
                story(spec: spec, unlocked: entity.unlocked, fit: fit).vvEntrance(2)
                Group {
                    if entity.unlocked {
                        provenance(spec: spec, entity: entity, fit: fit)
                    } else {
                        lockedCard(spec: spec, fit: fit)
                    }
                }
                .vvEntrance(3)
            }
            // Clears the burst's spikes so the scroll edge never shaves them.
            .padding(.top, fit.top)
        }
    }

    private func hero(spec: CastSpec, unlocked: Bool, fit: Fit) -> some View {
        // Proportions of the full 210pt stage: a 176pt piece, a 250pt burst.
        let piece = (fit.hero * 0.84).rounded()
        let burst = (fit.hero * 1.19).rounded()
        return ZStack {
            // A slab of real volcanic glass for the piece to sit against.
            Image("tex_obsidian_facet")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fill)
                .frame(width: piece, height: piece)
                .clipped()
                .opacity(unlocked ? 0.75 : 0.3)
                .overlay(Rectangle().stroke(VV.ink, lineWidth: 4))
                .rotationEffect(.degrees(-3))
                .shadow(color: VV.ink.opacity(0.55), radius: 14, y: 9)

            Image("burst_cast")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: burst, height: burst)
                .opacity(unlocked ? 0.85 : 0.18)
                .ambientSpin(period: 40)
            Image(unlocked ? spec.asset : "cast_locked_lump")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: piece)
                .saturation(unlocked ? 1 : 0.2)
                .shadow(color: VV.ink.opacity(0.6), radius: 16, y: 10)
                .ambientPulse(from: unlocked ? 0.98 : 1, to: unlocked ? 1.03 : 1, period: 3.0)
        }
        .frame(height: fit.hero)
    }

    private func nameplate(spec: CastSpec, unlocked: Bool, fit: Fit) -> some View {
        VStack(spacing: 3) {
            Text(unlocked ? spec.name : "Uncast stone")
                .font(VV.display(fit.nameSize))
                .textCase(.uppercase)
                .foregroundStyle(VV.ash)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
            Text("Cast \(spec.order) of \(CastCatalog.all.count)").microLabel(VV.magmaCore)
        }
        .padding(.horizontal, VV.s3)
        .padding(.vertical, fit.namePad)
        .frame(maxWidth: .infinity)
        .background(VV.ink)
        .overlay(alignment: .bottom) {
            Rectangle().fill(unlocked ? VV.sulfur : VV.obsidianLit).frame(height: 4)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 0, y: 5)
    }

    private func story(spec: CastSpec, unlocked: Bool, fit: Fit) -> some View {
        PaperPanel(rail: unlocked ? VV.sulfur : VV.obsidianLit, padding: fit.storyPad) {
            VStack(alignment: .leading, spacing: 6) {
                Text(unlocked ? "The piece" : "What waits").microLabel(VV.paperText2)
                Text(unlocked
                     ? spec.story
                     : "Nothing has been pulled from this mold yet. Clear \(CastCatalog.requirement(for: spec)) and the rift will hand it over.")
                    .font(VV.body(14))
                    .foregroundStyle(VV.paperText3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func provenance(spec: CastSpec, entity: CastEntity, fit: Fit) -> some View {
        PaperPanel(rail: VV.magma, padding: fit.panelPad) {
            VStack(alignment: .leading, spacing: fit.rowGap) {
                HStack {
                    Text("Provenance").microLabel(VV.paperText2)
                    Spacer(minLength: 8)
                    StarRow(earned: Int(entity.earnedStars), size: 20)
                }
                HStack(spacing: 10) {
                    StatCell(value: "\(spec.awardVent)", caption: "Vent", tint: VV.magma)
                    StatCell(value: RiftCatalog.numeral(VentCatalog.riftIndex(forVent: spec.awardVent)),
                             caption: "Rift")
                    StatCell(value: "\(Int((entity.earnedYield * 100).rounded()))%", caption: "Yield")
                }
                if let p = ventProgress, p.attempts > 0 {
                    Rectangle().fill(VV.ashMid).frame(height: 1)
                    HStack(spacing: 10) {
                        StatCell(value: Int(p.bestScore).castFormatted, caption: "Best score")
                        StatCell(value: "\(p.attempts)", caption: "Descents")
                    }
                }
                if let earnedAt = entity.earnedAt {
                    Text("Pulled \(earnedAt.formatted(date: .abbreviated, time: .shortened))")
                        .microLabel(Color(hex: 0x9A6A52))
                }
            }
        }
    }

    private func lockedCard(spec: CastSpec, fit: Fit) -> some View {
        InkPanel(rail: VV.obsidianLit, padding: fit.panelPad) {
            HStack(spacing: 13) {
                Image("crust_plate")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 54, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sealed").microLabel(VV.ashDeep)
                    Text(CastCatalog.requirement(for: spec))
                        .font(VV.display(21))
                        .textCase(.uppercase)
                        .foregroundStyle(VV.ash)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Dock

    /// The plates pinned under the column: the sulfur fissure when the vent is
    /// open, and always a way back — even for a key the catalog no longer knows.
    @ViewBuilder
    private func actions(roomy: Bool) -> some View {
        if let spec, let entity, ventProgress?.unlocked ?? false {
            FissurePlate(title: entity.unlocked ? "Cast it again" : "Go and cast it",
                         height: roomy ? 74 : 62, titleSize: roomy ? 30 : 26) {
                Haptics.knock()
                onPlayVent(spec.awardVent)
            }
            .vvEntrance(4)
        }
        StonePlate(title: "Back to the vault", systemIcon: "chevron.left", height: roomy ? 52 : 46) {
            onClose()
        }
        .vvEntrance(4)
    }
}
