import CoreData
import SwiftUI

/// Every descent the mountain remembers: lifetime totals, the vigil, and the
/// run-by-run history.
struct LedgerView: View {
    @Environment(\.managedObjectContext) private var ctx

    let onBack: () -> Void
    let onPlay: () -> Void
    let onVigil: () -> Void

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case cast = "Cast"
        case lost = "Lost"
        var id: String { rawValue }
    }

    @FetchRequest(
        entity: RunRecordEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \RunRecordEntity.createdAt, ascending: false)]
    ) private var runs: FetchedResults<RunRecordEntity>

    @State private var filter: Filter = .all
    @State private var totals = LedgerTotals()
    @State private var stats = CalderaStats()

    /// Below this much room under the sash (an SE leaves about 550pt) the three
    /// summary cards tighten, so the vigil card and the whole filter row land
    /// on screen without a scroll.
    private static let compactViewport: CGFloat = 600

    /// The scroll view's own space — the filter header measures itself against
    /// it to know when it has pinned under the sash.
    private static let scrollSpace = "ledger.scroll"

    private var shown: [RunRecordEntity] {
        let list = Array(runs.prefix(120))
        switch filter {
        case .all:  return list
        case .cast: return list.filter { $0.succeeded }
        case .lost: return list.filter { !$0.succeeded }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RockBackground()
            AmbientEmbers(count: 12, tint: VV.magmaHot, speed: 0.5, seed: 3072)
                .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    column(compact: geo.size.height < Self.compactViewport)
                        .padding(.horizontal, VV.s3)
                }
                .coordinateSpace(name: Self.scrollSpace)
            }
            .belowSash()

            HeaderSash(title: "The", accent: "Ledger",
                       subtitle: "Every descent, cast or not",
                       onBack: onBack) {
                SashCounter(value: "\(runs.count)", caption: "Descents")
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            totals = ProgressStore.ledgerTotals(in: ctx)
            stats = ProgressStore.stats(in: ctx)
        }
    }

    // MARK: - Column

    /// Lazy so the filter row can pin under the sash: once the history is
    /// scrolled into, the filters stay in reach instead of scrolling away.
    private func column(compact: Bool) -> some View {
        LazyVStack(spacing: compact ? VV.s2 + 2 : VV.s2 + 4, pinnedViews: [.sectionHeaders]) {
            if runs.isEmpty {
                EdgeStatePlate(
                    art: "crust_plate",
                    title: "The ledger is cold",
                    message: "Nothing has been written here yet. Finish a descent — cast or not — and the mountain starts keeping count.",
                    accent: VV.sulfur,
                    actionTitle: "Take a vent",
                    action: {
                        Haptics.knock()
                        onPlay()
                    }
                )
                .padding(.top, compact ? VV.s3 : 30)
            } else {
                vigilCard(compact: compact).vvEntrance(0)
                totalsCard(compact: compact).vvEntrance(1)
                rankCard(compact: compact).vvEntrance(2)
                Section {
                    if shown.isEmpty {
                        EdgeStatePlate(
                            art: "cast_locked_lump",
                            title: filter == .cast ? "No casts yet" : "Nothing lost yet",
                            message: filter == .cast
                                ? "Every descent so far ended short. Fill every rim mold and the first one lands here."
                                : "Not a single blowout or choke on record. That will not last forever.",
                            accent: VV.obsidianLit
                        )
                    } else {
                        ForEach(Array(shown.enumerated()), id: \.element.objectID) { i, r in
                            row(r).vvEntrance(min(4 + i, 10))
                        }
                    }
                } header: {
                    filterHeader.vvEntrance(3)
                }
            }

            Color.clear.frame(height: 40)
        }
    }

    // MARK: - Cards

    /// Full padding on tall screens; a shallower top and bottom on short ones.
    /// The sides never change, so card text keeps its left edge on every device.
    private func cardInsets(_ compact: Bool) -> EdgeInsets {
        let vertical: CGFloat = compact ? 10 : VV.s3
        return EdgeInsets(top: vertical, leading: VV.s3, bottom: vertical, trailing: VV.s3)
    }

    private func vigilCard(compact: Bool) -> some View {
        Button(action: onVigil) { vigilCardLabel(compact: compact) }
            .buttonStyle(PressPlateStyle(scale: 0.98))
    }

    private func vigilCardLabel(compact: Bool) -> some View {
        InkPanel(rail: VV.sulfur, padding: 0) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(stats.currentStreak)")
                        .font(VV.display(compact ? 34 : 44))
                        .foregroundStyle(VV.sulfur)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .ambientGlow(VV.sulfur, radius: 14, period: 2.3)
                    Text("Day vigil").microLabel(VV.ashDeep)
                }
                Rectangle().fill(VV.ash.opacity(0.2)).frame(width: 1, height: compact ? 36 : 46)
                VStack(alignment: .leading, spacing: VV.s1 + 2) {
                    HStack(spacing: VV.s1) {
                        Text("Longest run \(stats.bestStreak) days · \(stats.totalRuns) descents")
                            .font(VV.body(12))
                            .foregroundStyle(VV.ashMid)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Text("Vigil ›").microLabel(VV.sulfur)
                    }
                    ShimmerRule(fraction: stats.bestStreak > 0
                                ? Double(stats.currentStreak) / Double(max(stats.bestStreak, 1)) : 0,
                                fill: VV.sulfur)
                }
            }
            .padding(cardInsets(compact))
        }
    }

    private func totalsCard(compact: Bool) -> some View {
        PaperPanel(rail: VV.magma, padding: 0) {
            VStack(alignment: .leading, spacing: compact ? 7 : 11) {
                Text("Lifetime").microLabel(VV.paperText2)
                HStack(spacing: 10) {
                    StatCell(value: "\(totals.casts)", caption: "Cast", tint: VV.magma)
                    StatCell(value: "\(totals.blowouts)", caption: "Blowouts")
                    StatCell(value: "\(totals.chokes)", caption: "Choked")
                }
                Rectangle().fill(VV.ashMid).frame(height: 1)
                HStack(spacing: 10) {
                    StatCell(value: "\(Int((totals.successRate * 100).rounded()))%", caption: "Cast rate")
                    StatCell(value: "\(Int((totals.averageYield * 100).rounded()))%", caption: "Mean yield")
                    StatCell(value: totals.bestScore.castFormatted, caption: "Best score", tint: VV.magma)
                }
                Rectangle().fill(VV.ashMid).frame(height: 1)
                HStack(spacing: 10) {
                    StatCell(value: "\(totals.moldsFilled)", caption: "Molds filled")
                    StatCell(value: "\(totals.crustsBlown)", caption: "Crusts blown")
                    StatCell(value: timeString(totals.timeUnderTheRim), caption: "Under the rim")
                }
            }
            .padding(cardInsets(compact))
        }
    }

    private func rankCard(compact: Bool) -> some View {
        InkPanel(rail: VV.magma, padding: 0) {
            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stats.rank.title)
                        .font(VV.display(compact ? 22 : 26))
                        .textCase(.uppercase)
                        .foregroundStyle(VV.ash)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 8)
                    Text("\(stats.totalStars)★")
                        .font(VV.display(compact ? 19 : 22))
                        .foregroundStyle(VV.sulfur)
                }
                if let (next, owed) = stats.nextRank {
                    ShimmerRule(fraction: rankFraction, fill: VV.magma)
                    Text("\(owed) more cast stars to \(next.title)")
                        .font(VV.body(12))
                        .foregroundStyle(VV.ashMid)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ShimmerRule(fraction: 1, fill: VV.sulfur)
                    Text("The highest title the mountain gives out.")
                        .font(VV.body(12))
                        .foregroundStyle(VV.magmaCore)
                }
            }
            .padding(cardInsets(compact))
        }
    }

    private var rankFraction: Double {
        guard let (next, _) = stats.nextRank else { return 1 }
        let floorStars = stats.rank.starsRequired
        let span = max(1, next.starsRequired - floorStars)
        return Double(stats.totalStars - floorStars) / Double(span)
    }

    // MARK: - Filters

    /// The filter row as the history's section header. It rides in the flow
    /// above the list, then pins under the sash; only once pinned does it take
    /// an ink backing, so rows passing beneath never show between the chips.
    private var filterHeader: some View {
        filterRow
            .padding(.vertical, VV.s1)
            .background(alignment: .topLeading) {
                GeometryReader { geo in
                    // 0 while the row sits in the flow, 1 once it is flush with
                    // the top of the scroll view — fades in over the last 12pt.
                    let rise = geo.frame(in: .named(Self.scrollSpace)).minY
                    let pinned = 1 - min(max(rise, 0), 12) / 12
                    Color(hex: 0x1C0904).opacity(0.96)
                        .overlay(alignment: .bottom) { Rectangle().fill(VV.magma).frame(height: 2) }
                        .frame(width: geo.size.width + VV.s3 * 2, height: geo.size.height)
                        .offset(x: -VV.s3)
                        .shadow(color: VV.ink.opacity(0.45), radius: 10, y: 6)
                        .opacity(pinned)
                }
                .allowsHitTesting(false)
            }
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { f in
                Button {
                    withAnimation(Motion.spring()) { filter = f }
                } label: {
                    Text(f.rawValue)
                        .microLabel(filter == f ? VV.ink : VV.ash)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .background(filter == f ? VV.sulfur : VV.ink)
                        .frame(minHeight: 44)
                }
                .buttonStyle(PressPlateStyle())
                .accessibilityAddTraits(filter == f ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - History

    private func row(_ r: RunRecordEntity) -> some View {
        let isDaily = r.ventNumber == 0
        let label = isDaily ? "Daily Fissure"
                            : "Vent \(String(format: "%02d", Int(r.ventNumber)))"
        return HStack(spacing: 12) {
            Image(r.succeeded ? "node_cleared" : "node_locked")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 40, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(VV.display(19))
                        .textCase(.uppercase)
                        .foregroundStyle(VV.ash)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if isDaily {
                        Text("Vigil").microLabel(VV.sulfur)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(VV.ink)
                    }
                }
                Text("\(r.succeeded ? "Cast" : (r.peakPressure >= 0.99 ? "Blowout" : "Choked")) · \(r.moldsFilled) molds · \(Int((r.yield * 100).rounded()))% yield")
                    .font(VV.body(11.5))
                    .foregroundStyle(VV.ashDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let when = r.createdAt {
                    Text(when.formatted(date: .abbreviated, time: .shortened))
                        .microLabel(Color(hex: 0x7A5A48))
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Int(r.score).castFormatted)
                    .font(VV.display(21))
                    .foregroundStyle(r.succeeded ? VV.magma : VV.ashDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if r.succeeded { StarRow(earned: Int(r.starsEarned), size: 13, spacing: 2) }
            }
        }
        .padding(.horizontal, VV.s3 - 2)
        .padding(.vertical, VV.s2 + 2)
        .background(Color(hex: 0x200C06).opacity(0.9))
        .overlay(alignment: .leading) {
            Rectangle().fill(r.succeeded ? VV.magma : VV.obsidianLit).frame(width: 5)
        }
        .compositingGroup()
        .shadow(color: VV.ink.opacity(0.4), radius: 0, y: 3)
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total < 3600 { return "\(total / 60)m" }
        return "\(total / 3600)h \((total % 3600) / 60)m"
    }
}
