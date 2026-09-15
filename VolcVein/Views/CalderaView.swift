import CoreData
import SwiftUI

/// The home screen is the mountain itself: the logo slab breaks the upper-left
/// sky, the ERUPT fissure is cut across the throat, navigation is world objects
/// at different heights, and the lifetime numbers are carved into the magma
/// chamber at the foot. No button row, no floating chips.
struct CalderaView: View {
    @Environment(\.managedObjectContext) private var ctx

    let onPlay: () -> Void
    let onDaily: () -> Void
    let onMap: () -> Void
    let onVault: () -> Void
    let onMarks: () -> Void
    let onLedger: () -> Void
    let onSettings: () -> Void

    @State private var stats = CalderaStats()
    @State private var liveVent = 1
    @State private var loaded = false

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let compact = h < 760

            ZStack(alignment: .bottom) {
                SkyBackground(horizon: 0.34)

                Image("mountain_cross_section")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: h * 0.82, alignment: .top)
                    .clipped()
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(false)

                // The ambient element: the plume never stops moving.
                Image("ash_plume")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.62)
                    .opacity(0.85)
                    .ambientDrift(x: 10, y: -6, period: 9)
                    .ambientPulse(from: 0.98, to: 1.05, period: 7)
                    .position(x: geo.size.width * 0.5, y: h * 0.14)
                    .allowsHitTesting(false)

                AmbientEmbers(count: 12, tint: VV.sulfur, speed: 0.55, seed: 77)
                    .allowsHitTesting(false)

                content(size: geo.size, compact: compact)
            }
            .frame(width: geo.size.width, height: h)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            refresh()
        }
    }

    private func content(size: CGSize, compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Image("logo_volcvein")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: min(size.width * 0.60, 236))
                    .rotationEffect(.degrees(-4.5))
                    .shadow(color: VV.ink.opacity(0.45), radius: 18, x: 7, y: 12)
                Spacer(minLength: 0)
                WorldNavButton(asset: "icon_stone_tablet",
                               caption: "Marks \(stats.marksEarned)/\(stats.marksTotal)",
                               size: compact ? 62 : 74,
                               action: onMarks)
                    .padding(.top, 6)
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .padding(.top, compact ? 2 : 8)
            .vvEntrance(0)

            Spacer(minLength: compact ? 2 : 8)

            // The vigil banner — the one thing that changes every day.
            dailyBanner(compact: compact)
                .padding(.horizontal, size.width * 0.07)
                .vvEntrance(1)

            Spacer(minLength: compact ? 2 : 8)

            HStack(alignment: .center) {
                WorldNavButton(asset: "icon_obsidian_plinth",
                               caption: "Casts \(stats.castsUnlocked)/\(stats.castsTotal)",
                               size: compact ? 68 : 84,
                               action: onVault)
                Spacer(minLength: 0)
                rankPlate
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .vvEntrance(2)

            Spacer(minLength: compact ? 2 : 10)

            FissurePlate(title: stats.isComplete ? "Recast" : "Erupt",
                         caption: eruptCaption,
                         height: compact ? 82 : 96,
                         titleSize: compact ? 36 : 42,
                         rotation: -3,
                         action: {
                             Haptics.knock()
                             onPlay()
                         })
                .ambientGlow(VV.sulfur, radius: 22, period: 2.6)
                .padding(.horizontal, size.width * 0.10)
                .vvEntrance(3)

            Spacer(minLength: compact ? 2 : 8)

            HStack(alignment: .bottom, spacing: 10) {
                chamberWall
                Spacer(minLength: 0)
                VStack(spacing: 7) {
                    WorldNavButton(asset: "icon_valve_wheel",
                                   caption: "Settings",
                                   size: compact ? 48 : 58,
                                   action: onSettings)
                    Button(action: onMap) {
                        InkPlate(underline: VV.sulfur) {
                            Text("Rift map").microLabel()
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(PressPlateStyle())
                }
            }
            .padding(.horizontal, VV.s3)
            .padding(.bottom, compact ? 26 : 40)
            .vvEntrance(4)
        }
    }

    private var eruptCaption: String? {
        guard loaded else { return nil }
        if stats.isFirstRun { return "Your first vent" }
        if stats.isComplete { return "Every vent cast · chase the stars" }
        return "Rift \(RiftCatalog.numeral(VentCatalog.riftIndex(forVent: liveVent))) · Vent \(String(format: "%02d", liveVent))"
    }

    // MARK: - The vigil banner

    private func dailyBanner(compact: Bool) -> some View {
        Button {
            Haptics.knock()
            onDaily()
        } label: {
            HStack(spacing: 11) {
                Image(stats.dailyDoneToday ? "cast_star_on" : "valve_open")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 30, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(stats.dailyDoneToday ? "Vigil kept today" : "Daily fissure")
                        .font(VV.display(compact ? 19 : 21))
                        .textCase(.uppercase)
                        .foregroundStyle(stats.dailyDoneToday ? VV.magmaCore : VV.ash)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(stats.currentStreak > 0
                         ? "\(stats.currentStreak) day streak · \(RiftCatalog.name(VentCatalog.dailyArchetype(VentCatalog.dayKey())))"
                         : "A new vent every day · start a streak")
                        .microLabel(VV.ashDeep)
                }

                Spacer(minLength: 0)

                Text(stats.currentStreak > 0 ? "\(stats.currentStreak)" : "—")
                    .font(VV.display(compact ? 26 : 30))
                    .foregroundStyle(VV.sulfur)
                    .contentTransition(.numericText())
                    .lineLimit(1)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0x1C0904).opacity(0.93))
            .overlay(alignment: .leading) {
                Rectangle().fill(stats.dailyDoneToday ? VV.sulfur : VV.magma).frame(width: 5)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
            .shadow(color: .black.opacity(0.4), radius: 14, y: 9)
        }
        .buttonStyle(PressPlateStyle(scale: 0.97))
    }

    // MARK: - Rank

    private var rankPlate: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(stats.rank.title)
                .font(VV.display(17))
                .textCase(.uppercase)
                .foregroundStyle(VV.ash)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(stats.totalStars)★ of \(stats.starsTotal)").microLabel(VV.magmaCore)
            RuleBar(fraction: Double(stats.totalStars) / Double(max(stats.starsTotal, 1)),
                    fill: VV.sulfur, height: 5)
                .frame(width: 104)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(VV.ink.opacity(0.92))
        .overlay(alignment: .trailing) { Rectangle().fill(VV.sulfur).frame(width: 4) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
        .frame(maxWidth: 156)
    }

    // MARK: - Chamber wall

    private var chamberWall: some View {
        Button(action: {
            onLedger()
        }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(stats.isFirstRun ? "The mountain" : "Best cast").microLabel(VV.ashDeep)
                    Spacer(minLength: 4)
                    Text("Ledger ›").microLabel(VV.sulfur)
                }
                Text(stats.isFirstRun ? "Unworked" : stats.bestCast.castFormatted)
                    .font(VV.display(stats.isFirstRun ? 26 : 36))
                    .foregroundStyle(VV.sulfur)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Rectangle().fill(VV.ash.opacity(0.22)).frame(height: 1)

                HStack(alignment: .top, spacing: 14) {
                    statColumn("\(stats.riftsCleared)/\(stats.riftsTotal)", "Rifts")
                    statColumn("\(stats.ventsCleared)/\(stats.ventsTotal)", "Vents")
                    statColumn("\(Int((stats.averageYield * 100).rounded()))%", "Yield")
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(Color(hex: 0x1C0904).opacity(0.93))
            .overlay(alignment: .leading) { Rectangle().fill(VV.magma).frame(width: 5) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
            .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
            .frame(maxWidth: 214)
        }
        .buttonStyle(PressPlateStyle(scale: 0.97))
    }

    private func statColumn(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(VV.display(19))
                .foregroundStyle(VV.ash)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(caption).microLabel(VV.ashDeep)
        }
    }

    private func refresh() {
        // Loaded straight after appear, so let it land without cross-fading the
        // starting values through the ones that just loaded.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            stats = ProgressStore.stats(in: ctx)
            liveVent = ProgressStore.liveVent(in: ctx)
            loaded = true
        }
    }
}
