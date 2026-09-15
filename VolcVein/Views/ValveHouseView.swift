import CoreData
import SwiftUI

/// Settings, kept to what an offline game actually needs: two switches, a recap
/// of the rules, and a reset that confirms first.
struct ValveHouseView: View {
    @Environment(\.managedObjectContext) private var ctx

    let onBack: () -> Void
    let onReset: () -> Void

    @FetchRequest(
        entity: PreferenceEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PreferenceEntity.createdAt, ascending: true)]
    ) private var preferences: FetchedResults<PreferenceEntity>

    @State private var confirmingReset = false

    private var prefs: PreferenceEntity? { preferences.first }

    /// Below this much room under the sash (an SE) the reset plate trims down.
    private static let shortArea: CGFloat = 600
    /// Content viewports under these heights give up padding and gaps first,
    /// then icon and type size — the switches lead the column either way, so
    /// they always sit whole above the fold.
    private static let tightViewport: CGFloat = 680
    private static let compactViewport: CGFloat = 540

    var body: some View {
        ZStack(alignment: .top) {
            RockBackground()
            AmbientEmbers(count: 10, tint: VV.magmaCore, speed: 0.45, seed: 606)
                .ignoresSafeArea()

            // The reset plate rides a dock above the home indicator with the
            // colophon under it, where the design pins the footer. Only the
            // rules recap and the standing card ever give way to a scroll.
            GeometryReader { area in
                DockedScroll(dockSpacing: VV.s2, clearsHomeIndicator: true) { viewport in
                    column(viewport)
                } dock: {
                    resetPlate(compact: area.size.height < Self.shortArea)
                        .vvEntrance(4)
                    footer
                }
            }
            .belowSash()

            HeaderSash(title: "The", accent: "Valve House",
                       subtitle: "Settings · plays offline",
                       onBack: onBack) {
                // The valve wheel turns for as long as the screen is up.
                Image("icon_settings")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .ambientSpin(period: 26)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .alert("Reset progress?", isPresented: $confirmingReset) {
            Button("Cancel", role: .cancel) { confirmingReset = false }
            Button("Reset", role: .destructive) {
                Seeder.resetProgress(in: ctx)
                Haptics.warn()
                onReset()
            }
        } message: {
            Text("This wipes every vent, cast, mark, ledger entry and your vigil streak, and starts you back at the first rift.")
        }
    }

    // MARK: - Column

    /// Everything above the dock, in the design's order: the two switches, the
    /// rules recap, then where the player stands.
    private func column(_ viewport: CGFloat) -> some View {
        let tight = viewport < Self.tightViewport
        let compact = viewport < Self.compactViewport
        return VStack(spacing: tight ? 10 : 12) {
            switchPlaque(
                asset: "icon_haptics",
                title: "Haptics",
                detail: "A knock at every valve, gout and blowout.",
                isOn: prefs?.hapticsOn ?? true,
                tight: tight,
                compact: compact
            ) { newValue in
                prefs?.hapticsOn = newValue
                Haptics.enabled = newValue
                ctx.saveChanges()
                if newValue { Haptics.knock() }
            }
            .vvEntrance(0)

            switchPlaque(
                asset: "icon_animations",
                title: "Motion",
                detail: "Screen shake, ember bursts and roll-up counters.",
                isOn: prefs?.animationsOn ?? true,
                tight: tight,
                compact: compact
            ) { newValue in
                prefs?.animationsOn = newValue
                Motion.enabled = newValue
                ctx.saveChanges()
            }
            .vvEntrance(1)

            howItWorks(tight: tight, compact: compact).vvEntrance(2)
            standingCard(tight: tight).vvEntrance(3)
        }
        // A strip of rock between the sash's skewed edge and the first plaque.
        .padding(.top, tight ? VV.s2 : 12)
    }

    // MARK: - Pieces

    private func switchPlaque(asset: String, title: String, detail: String,
                              isOn: Bool, tight: Bool, compact: Bool,
                              onChange: @escaping (Bool) -> Void) -> some View {
        PaperPanel(rail: VV.sulfur, padding: tight ? 12 : VV.s3) {
            HStack(spacing: compact ? 11 : 13) {
                Image(asset)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: compact ? 40 : 46, height: compact ? 40 : 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VV.display(22))
                        .textCase(.uppercase)
                        .foregroundStyle(VV.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(detail)
                        .font(VV.body(12))
                        .foregroundStyle(VV.paperText2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)
                ValveSwitch(isOn: isOn, onChange: onChange)
            }
            // Tight panels trim the vertical padding, not the gap off the rail.
            .padding(.leading, tight ? 4 : 0)
        }
    }

    /// Where the player actually stands — the numbers Settings is the natural
    /// home for, rather than a second copy of the Caldera.
    private func standingCard(tight: Bool) -> some View {
        let stats = ProgressStore.stats(in: ctx)
        let gap: CGFloat = tight ? 8 : 11
        return PaperPanel(rail: VV.magma, padding: tight ? 12 : VV.s3) {
            VStack(alignment: .leading, spacing: gap) {
                HStack {
                    Text("Where you stand").microLabel(VV.paperText2)
                    Spacer(minLength: 8)
                    Text(stats.rank.title)
                        .font(VV.display(17))
                        .textCase(.uppercase)
                        .foregroundStyle(VV.magma)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                HStack(spacing: 10) {
                    StatCell(value: "\(stats.ventsCleared)/\(stats.ventsTotal)", caption: "Vents cast", tint: VV.magma)
                    StatCell(value: "\(stats.totalStars)", caption: "Cast stars")
                    StatCell(value: "\(stats.currentStreak)", caption: "Day vigil")
                }
                Rectangle().fill(VV.ashMid).frame(height: 1)
                HStack(spacing: 10) {
                    StatCell(value: "\(stats.castsUnlocked)/\(stats.castsTotal)", caption: "Casts")
                    StatCell(value: "\(stats.marksEarned)/\(stats.marksTotal)", caption: "Marks")
                    StatCell(value: "\(stats.totalRuns)", caption: "Descents")
                }
            }
            .padding(.leading, tight ? 4 : 0)
        }
    }

    private func howItWorks(tight: Bool, compact: Bool) -> some View {
        InkPanel(rail: VV.magma, padding: tight ? 13 : 15) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    Image("icon_info")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: compact ? 24 : 26, height: compact ? 24 : 26)
                    Text("How a vent works")
                        .font(VV.display(compact ? 20 : 21))
                        .textCase(.uppercase)
                        .foregroundStyle(VV.ash)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                step(asset: "valve_open",
                     text: "**Tap a valve** to shut that branch. You never aim the magma — you only decide where it cannot go.",
                     tight: tight, compact: compact)
                step(asset: "valve_crusted",
                     text: "**Shut veins cool.** Leave one closed too long and it crusts over — hold it to blow the crust out, at the cost of pressure.",
                     tight: tight, compact: compact)
                step(asset: "mold_part",
                     text: "**Fill every rim mold** before the chamber redlines. Overfill one and it cracks; starve one and it sets.",
                     tight: tight, compact: compact)
            }
        }
    }

    private func step(asset: String, text: String, tight: Bool, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 10 : 11) {
            Image(asset)
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: compact ? 28 : 32, height: compact ? 28 : 32)
            Text(.init(text))
                .font(VV.body(compact ? 12 : 12.5))
                .foregroundStyle(VV.ashMid)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, tight ? 9 : 11)
    }

    // MARK: - Dock

    private func resetPlate(compact: Bool) -> some View {
        HStack(spacing: compact ? 11 : 13) {
            Image("icon_reset_hammer")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reset progress")
                    .font(VV.display(22))
                    .textCase(.uppercase)
                    .foregroundStyle(VV.ash)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Wipes vents, casts and marks. Asks first.")
                    .font(VV.body(12))
                    .foregroundStyle(VV.ashDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Button {
                confirmingReset = true
            } label: {
                Text("Reset")
                    .font(VV.display(15))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(VV.ash)
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(VV.danger)
                    .shadow(color: Color(hex: 0x7E1A0A), radius: 0, y: 3)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(PressPlateStyle())
        }
        .padding(.horizontal, compact ? 14 : VV.s3)
        .padding(.vertical, compact ? 10 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VV.ink)
        .overlay(alignment: .leading) { Rectangle().fill(VV.danger).frame(width: 6) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
    }

    /// The micro colophon under the reset plate, at the foot of the screen.
    private var footer: some View {
        Text("VolcVein · \(VentCatalog.ventCount) vents · \(CastCatalog.all.count) casts · \(MarkCatalog.all.count) marks · v1.0")
            .microLabel(VV.ashDeep)
            .frame(maxWidth: .infinity)
    }
}

/// A chunky two-state ink switch — the design's own control, not a stock Toggle.
struct ValveSwitch: View {
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button {
            onChange(!isOn)
        } label: {
            HStack(spacing: 0) {
                half(label: "Off", active: !isOn)
                half(label: "On", active: isOn)
            }
            .frame(width: 74, height: 44)
            .background(VV.ink)
            .overlay(Rectangle().stroke(VV.ink, lineWidth: 3))
            .animation(Motion.spring(0.3, 0.72), value: isOn)
        }
        .buttonStyle(PressPlateStyle())
        .accessibilityLabel(isOn ? "On" : "Off")
    }

    private func half(label: String, active: Bool) -> some View {
        Text(label)
            .font(VV.display(11))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(active ? VV.ink : VV.ash)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(active ? (label == "On" ? VV.sulfur : VV.ashDeep) : Color.clear)
    }
}
