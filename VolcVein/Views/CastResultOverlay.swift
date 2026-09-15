import SwiftUI

/// One layout, two verdicts. A cast reveals the obsidian piece; a blowout or a
/// choke says so plainly and still banks what the run managed.
struct CastResultOverlay: View {
    @ObservedObject var vm: GameViewModel
    let summary: RunSummary
    let onMap: () -> Void
    let onLeave: () -> Void

    @State private var starsShown = 0

    private var succeeded: Bool { summary.succeeded }

    private var verdict: String {
        switch summary.outcome {
        case .cast: return "Cast"
        case .blowout: return "Blowout"
        case .choked: return "Choked"
        }
    }

    private var verdictRail: Color { succeeded ? VV.magma : VV.danger }

    private var streak: Int { vm.commitOutcome?.streakAfter ?? 0 }

    /// Which optional strips the column carries this time — the fitting pass
    /// has to know before it picks a density.
    private var parts: ResultParts {
        let plate: ResultParts.Nameplate
        if !succeeded {
            plate = .absent
        } else if vm.awardedCast != nil {
            plate = .cast
        } else if vm.commitOutcome?.newMarks.first != nil {
            plate = .mark
        } else {
            plate = .absent
        }
        return ResultParts(succeeded: succeeded,
                           nameplate: plate,
                           rankUp: vm.commitOutcome?.newRank != nil,
                           vigil: streak > 0)
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
            AmbientEmbers(count: 18, tint: succeeded ? VV.sulfur : VV.danger,
                          speed: 0.9, seed: 99)
                .ignoresSafeArea()

            GeometryReader { geo in
                // An SE-height screen gets a lower dock so the column keeps room
                // for the reveal; the fissure plate still out-sizes everything.
                docked(compactDock: geo.size.height < 700)
            }
        }
        .onAppear {
            rollStars()
        }
    }

    private func docked(compactDock: Bool) -> some View {
        DockedScroll(dockSpacing: compactDock ? 8 : 10, contentAlignment: .center) { viewport in
            column(ResultMetrics.fitting(viewport, parts: parts))
        } dock: {
            actions(compact: compactDock)
        }
    }

    // MARK: - Column

    private func column(_ m: ResultMetrics) -> some View {
        VStack(spacing: m.spacing) {
            // Above the hero so the burst turns behind the slab, as drawn.
            verdictSlab(m).vvEntrance(0).zIndex(1)
            VStack(spacing: m.starGap) {
                hero(m).vvEntrance(1)
                stars(m).vvEntrance(2)
            }
            if parts.nameplate != .absent { nameplate(m) }
            ledger(m).vvEntrance(3)
            if let rank = vm.commitOutcome?.newRank {
                rankUp(rank, m).vvEntrance(4)
            }
            if streak > 0 {
                vigilStrip(m).vvEntrance(5)
            }
        }
        .padding(.top, m.topInset)
    }

    private func verdictSlab(_ m: ResultMetrics) -> some View {
        VStack(spacing: m.tabGap) {
            Text(verdict)
                .font(VV.display(m.verdictSize))
                .textCase(.uppercase)
                .foregroundStyle(VV.ash)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .capBox(m.verdictSize)
                .padding(.horizontal, VV.s4 - 2)
                .padding(.top, m.verdictPad)
                .padding(.bottom, m.verdictPad + 2)
                .background(VV.ink)
                .overlay(alignment: .leading) { Rectangle().fill(verdictRail).frame(width: 6) }
                .compositingGroup()
                .rotationEffect(.degrees(-2))
                .shadow(color: VV.ink.opacity(0.45), radius: 0, x: 7, y: 7)

            Text(vm.isDaily
                 ? "Daily fissure · \(RiftCatalog.name(summary.riftIndex)) shape"
                 : "Vent \(String(format: "%02d", summary.ventNumber)) · Rift \(RiftCatalog.numeral(summary.riftIndex)) · \(RiftCatalog.name(summary.riftIndex))")
                .microLabel(VV.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(VV.sulfur)
                .rotationEffect(.degrees(1.5))
                .shadow(color: VV.sulfurDeep, radius: 0, y: 3)
        }
    }

    @ViewBuilder
    private func hero(_ m: ResultMetrics) -> some View {
        if succeeded {
            ZStack {
                // The burst keeps turning behind the piece, spilling past its
                // frame toward the tab and the stars the way the mockup does.
                Image("burst_cast")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: m.burst, height: m.burst)
                    .opacity(0.85)
                    .ambientSpin(period: 34)
                Image(vm.awardedCast?.asset ?? "cast_crownfracture_hero")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: m.hero)
                    .shadow(color: VV.ink.opacity(0.6), radius: 16, y: 10)
                    .ambientPulse(from: 0.98, to: 1.03, period: 2.8)
            }
            .frame(height: m.hero)
        } else {
            Image("crust_plate")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: m.hero)
                .padding(.vertical, m.crustPad)
                .ambientPulse(from: 0.97, to: 1.02, period: 3.4)
        }
    }

    private func stars(_ m: ResultMetrics) -> some View {
        HStack(spacing: (m.starSize * 0.32).rounded()) {
            ForEach(0..<3, id: \.self) { i in
                Image(i < starsShown ? "cast_star_on" : "cast_star_off")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: m.starSize, height: m.starSize)
                    .scaleEffect(i < starsShown ? 1 : 0.86)
                    .animation(Motion.spring(0.3, 0.55), value: starsShown)
            }
        }
    }

    @ViewBuilder
    private func nameplate(_ m: ResultMetrics) -> some View {
        if let cast = vm.awardedCast {
            VStack(spacing: 3) {
                Text(cast.name)
                    .font(VV.display(m.nameSize))
                    .textCase(.uppercase)
                    .foregroundStyle(VV.ash)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .capBox(m.nameSize)
                Text("New obsidian cast · \(cast.order) of 12").microLabel(VV.magmaCore)
            }
            .padding(.horizontal, 14)
            .padding(.top, m.namePad)
            .padding(.bottom, m.namePad + 2)
            .frame(maxWidth: .infinity)
            .background(VV.ink)
            .overlay(alignment: .bottom) { Rectangle().fill(VV.sulfur).frame(height: 4) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.4), radius: 0, y: 5)
        } else if let marks = vm.commitOutcome?.newMarks, let first = marks.first {
            InkPlate(underline: VV.sulfur) {
                Text("Mark struck · \(first)").microLabel(VV.sulfur)
            }
        }
    }

    private func rankUp(_ rank: RankSpec, _ m: ResultMetrics) -> some View {
        HStack(spacing: 11) {
            Image("mark_full_yield")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: m.rankIcon, height: m.rankIcon)
            VStack(alignment: .leading, spacing: 1) {
                Text("New title").microLabel(VV.magmaCore)
                Text(rank.title)
                    .font(VV.display(m.rankTitle))
                    .textCase(.uppercase)
                    .foregroundStyle(VV.ash)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .capBox(m.rankTitle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, m.rankPad)
        .frame(maxWidth: .infinity)
        .background(VV.ink)
        .overlay(alignment: .leading) { Rectangle().fill(VV.sulfur).frame(width: 5) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.42), radius: 0, y: 4)
    }

    private func vigilStrip(_ m: ResultMetrics) -> some View {
        HStack(spacing: 10) {
            Image("cast_star_on")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: m.vigilIcon, height: m.vigilIcon)
            Text(streak == 1 ? "Vigil started" : "\(streak) day vigil")
                .microLabel(VV.sulfur)
            Spacer(minLength: 0)
            Text(vm.isDaily ? "Daily kept" : "Descent counted").microLabel(VV.ashDeep)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, m.vigilPad)
        .frame(maxWidth: .infinity)
        .background(Color(hex: 0x1C0904).opacity(0.9))
        .overlay(alignment: .leading) { Rectangle().fill(VV.sulfur).frame(width: 4) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 0, y: 3)
    }

    private func ledger(_ m: ResultMetrics) -> some View {
        PaperPanel(rail: VV.magma, padding: m.ledgerPad) {
            VStack(spacing: 0) {
                row("Molds filled", "\(summary.moldsFilled) / \(summary.moldCount)", hot: false, m)
                row("Yield — magma not spilled", "\(Int((summary.yield * 100).rounded()))%", hot: true, m)
                row("Veins crusted shut", "\(summary.veinsCrusted)", hot: false, m)
                row("Peak pressure", "\(Int((summary.peakPressure * 100).rounded()))%", hot: false, m)
                row("Cast score", summary.score.castFormatted, hot: true, m, last: true)
            }
        }
    }

    private func row(_ caption: String, _ value: String, hot: Bool,
                     _ m: ResultMetrics, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(caption).microLabel(VV.paperText2)
                Spacer(minLength: 8)
                Text(value)
                    .font(VV.display(m.ledgerValue))
                    .foregroundStyle(hot ? VV.magma : VV.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.vertical, m.ledgerRowPad)
            if !last {
                Rectangle()
                    .fill(VV.ashMid)
                    .frame(height: 1)
                    .mask(HStack(spacing: 4) { ForEach(0..<40, id: \.self) { _ in Rectangle().frame(width: 4) } })
            }
        }
    }

    // MARK: - Dock

    /// Pinned under the column so every way on is reachable without scrolling.
    /// The fissure keeps a full-width tier of its own; everything calmer shares
    /// one row beneath it, the way home included.
    @ViewBuilder
    private func actions(compact: Bool) -> some View {
        let primary: CGFloat = compact ? 66 : 74
        let secondary: CGFloat = compact ? 48 : 54

        if vm.isDaily {
            FissurePlate(title: succeeded ? "Cast it again" : "Try again",
                         height: primary, titleSize: 32) {
                vm.restart()
            }
            .vvEntrance(6)
            HStack(spacing: 10) {
                StonePlate(title: "The ledger", systemIcon: "list.bullet", height: secondary) {
                    onMap()
                }
                calderaPlate(height: secondary)
            }
            .vvEntrance(7)
        } else if succeeded && !vm.isFinalVent {
            FissurePlate(title: "Next vent", height: primary, titleSize: 32) {
                vm.advanceToNextVent()
            }
            .vvEntrance(6)
            HStack(spacing: 10) {
                StonePlate(title: "Recast", systemIcon: "arrow.counterclockwise", height: secondary) {
                    vm.restart()
                }
                StonePlate(title: "Rift map", systemIcon: "map", height: secondary) {
                    onMap()
                }
                calderaTile(height: secondary)
            }
            .vvEntrance(7)
        } else {
            FissurePlate(title: "Recast", height: primary, titleSize: 32) {
                vm.restart()
            }
            .vvEntrance(6)
            HStack(spacing: 10) {
                StonePlate(title: "Rift map", systemIcon: "map", height: secondary) {
                    onMap()
                }
                calderaPlate(height: secondary)
            }
            .vvEntrance(7)
        }
    }

    private func calderaPlate(height: CGFloat) -> some View {
        StonePlate(title: "Caldera", systemIcon: "house", underline: VV.magma, height: height) {
            onLeave()
        }
    }

    /// The way home folded to a narrow basalt tile, so it can share the row with
    /// Recast and Rift map instead of costing the dock a third tier. Same slab,
    /// lit edge, magma underline and glyph as the full Caldera plate.
    private func calderaTile(height: CGFloat) -> some View {
        Button(action: onLeave) {
            VStack(spacing: 3) {
                Image(systemName: "house")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(VV.magma)
                Text("Caldera")
                    .font(VV.display(VV.tMicro))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(VV.ash)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 62, height: height)
            .background(
                VV.ink
                    .overlay(alignment: .top) {
                        Rectangle().fill(VV.ash.opacity(0.07)).frame(height: 1)
                    }
            )
            .overlay(alignment: .bottom) { Rectangle().fill(VV.magma).frame(height: 3) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
        }
        .buttonStyle(PressPlateStyle())
        .accessibilityLabel("Caldera")
    }

    private func rollStars() {
        starsShown = 0
        guard summary.stars > 0 else { return }
        for i in 1...summary.stars {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26 * Double(i)) {
                starsShown = i
                Haptics.knock()
            }
        }
    }
}

// MARK: - Fitting

/// Which optional strips the result column carries this time.
private struct ResultParts {
    enum Nameplate { case cast, mark, absent }

    let succeeded: Bool
    let nameplate: Nameplate
    let rankUp: Bool
    let vigil: Bool
}

/// One density step of the result column, and the arithmetic that picks it.
/// The overlay is told the height the dock leaves it and takes the loosest step
/// whose text, strips and spacing still leave the hero a worthy size; the hero
/// then absorbs whatever is left, up to its full reveal scale. On a 402×874
/// phone the whole verdict fits unscrolled even with a new title and a vigil;
/// on an SE only the rarest stack of strips scrolls, and only by a few lines.
private struct ResultMetrics {
    /// Avenir Next Condensed's line box, and the trimmed box `capBox` sets
    /// titles on, per point of size.
    static let lineBox: CGFloat = 1.366
    static let capBox: CGFloat = 0.95
    /// The dock scroll's fade padding under the column, plus slack for pixel
    /// rounding of the text boxes.
    private static let reserved: CGFloat = 14 + 6
    private static let pieceCeiling: CGFloat = 172
    private static let crustCeiling: CGFloat = 96

    let topInset: CGFloat
    let spacing: CGFloat
    let verdictSize: CGFloat
    let verdictPad: CGFloat
    let tabGap: CGFloat
    /// Smallest hero this step accepts before a tighter step is tried.
    let pieceFloor: CGFloat
    let crustFloor: CGFloat
    let starGap: CGFloat
    let starSize: CGFloat
    let crustPad: CGFloat
    let nameSize: CGFloat
    let namePad: CGFloat
    let ledgerValue: CGFloat
    let ledgerRowPad: CGFloat
    let ledgerPad: CGFloat
    let rankIcon: CGFloat
    let rankTitle: CGFloat
    let rankPad: CGFloat
    let vigilIcon: CGFloat
    let vigilPad: CGFloat
    /// The piece — or, on a failed run, the crust plate. Resolved last.
    var hero: CGFloat = 0

    var burst: CGFloat { hero * 250 / 172 }

    private static let steps: [ResultMetrics] = [
        // The mockup's own sizes — Pro Max and roomier.
        ResultMetrics(topInset: 12, spacing: 12, verdictSize: 50, verdictPad: 8, tabGap: 11,
                      pieceFloor: 150, crustFloor: 90, starGap: 10, starSize: 44, crustPad: 14,
                      nameSize: 27, namePad: 9, ledgerValue: 21, ledgerRowPad: 4, ledgerPad: 12,
                      rankIcon: 40, rankTitle: 23, rankPad: 11, vigilIcon: 24, vigilPad: 10),
        ResultMetrics(topInset: 8, spacing: 10, verdictSize: 46, verdictPad: 7, tabGap: 10,
                      pieceFloor: 130, crustFloor: 80, starGap: 8, starSize: 42, crustPad: 10,
                      nameSize: 26, namePad: 8, ledgerValue: 21, ledgerRowPad: 2.5, ledgerPad: 11,
                      rankIcon: 36, rankTitle: 22, rankPad: 9, vigilIcon: 22, vigilPad: 8),
        ResultMetrics(topInset: 6, spacing: 8, verdictSize: 42, verdictPad: 6, tabGap: 9,
                      pieceFloor: 108, crustFloor: 68, starGap: 6, starSize: 38, crustPad: 8,
                      nameSize: 24, namePad: 7, ledgerValue: 20, ledgerRowPad: 1.5, ledgerPad: 10,
                      rankIcon: 32, rankTitle: 21, rankPad: 7, vigilIcon: 20, vigilPad: 7),
        // SE-height: the slab still clears its own tilt at the top edge.
        ResultMetrics(topInset: 5, spacing: 6, verdictSize: 38, verdictPad: 5, tabGap: 8,
                      pieceFloor: 84, crustFloor: 56, starGap: 5, starSize: 34, crustPad: 6,
                      nameSize: 22, namePad: 6, ledgerValue: 19, ledgerRowPad: 0.5, ledgerPad: 9,
                      rankIcon: 28, rankTitle: 20, rankPad: 5, vigilIcon: 20, vigilPad: 5),
    ]

    static func fitting(_ viewport: CGFloat, parts: ResultParts) -> ResultMetrics {
        let budget = viewport - reserved
        let ceiling = parts.succeeded ? pieceCeiling : crustCeiling
        for step in steps {
            let heroFloor = parts.succeeded ? step.pieceFloor : step.crustFloor
            // `step.hero` is still zero, so this is the room left for the hero.
            let room = budget - step.height(parts)
            if room >= heroFloor {
                var fitted = step
                fitted.hero = min(ceiling, room)
                return fitted
            }
        }
        var tightest = steps[steps.count - 1]
        tightest.hero = parts.succeeded ? tightest.pieceFloor : tightest.crustFloor
        return tightest
    }

    /// Estimated column height, mirroring the views above item for item.
    func height(_ parts: ResultParts) -> CGFloat {
        let micro = VV.tMicro * Self.lineBox
        var items: [CGFloat] = []

        // Verdict slab on its cap box, then the micro tab (5pt padding each way).
        items.append(verdictSize * Self.capBox + verdictPad * 2 + 2 + tabGap + micro + 10)

        // Hero and the star row beneath it.
        let heroBlock = parts.succeeded ? hero : hero + crustPad * 2
        items.append(heroBlock + starGap + starSize)

        switch parts.nameplate {
        case .cast: items.append(nameSize * Self.capBox + 3 + micro + namePad * 2 + 2)
        case .mark: items.append(micro + 8)
        case .absent: break
        }

        // Five first-baseline rows and four dashed rules.
        let rowLine = max(ledgerValue, VV.tMicro) * Self.lineBox
        items.append((rowLine + ledgerRowPad * 2) * 5 + 4 + ledgerPad * 2)

        if parts.rankUp {
            items.append(max(rankIcon, micro + 1 + rankTitle * Self.capBox) + rankPad * 2)
        }
        if parts.vigil {
            items.append(max(vigilIcon, micro) + vigilPad * 2)
        }

        return topInset + items.reduce(0, +) + spacing * CGFloat(max(0, items.count - 1))
    }
}

private extension View {
    /// Sets a one-line display title on its capitals rather than the face's full
    /// line box: Avenir Next Condensed carries a third of an em of empty descender
    /// room, which left the ink slabs loose next to the mockup's tight leading.
    /// Height is pinned to ideal first so `minimumScaleFactor` only ever reacts
    /// to width, and the glyphs are nudged back onto the trimmed box's centre.
    func capBox(_ size: CGFloat) -> some View {
        fixedSize(horizontal: false, vertical: true)
            .frame(height: size * ResultMetrics.capBox)
            .offset(y: size * 0.037)
    }
}
