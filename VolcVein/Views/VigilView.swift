import CoreData
import SwiftUI

/// The daily record: the streak, the three weeks behind it, and every Daily
/// Fissure the mountain has handed out.
struct VigilView: View {
    @Environment(\.managedObjectContext) private var ctx

    let onBack: () -> Void
    let onPlayDaily: () -> Void

    @FetchRequest(
        entity: DailyRunEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \DailyRunEntity.dayKey, ascending: false)]
    ) private var dailies: FetchedResults<DailyRunEntity>

    @State private var stats = CalderaStats()

    private static let stripDays = 21
    /// Below this much room above the dock the record panels tighten up, so a
    /// short screen still shows the start of the history under them.
    private static let compactViewport: CGFloat = 580

    private var kept: [String: DailyRunEntity] {
        Dictionary(dailies.compactMap { d -> (String, DailyRunEntity)? in
            guard let key = d.dayKey else { return nil }
            return (key, d)
        }, uniquingKeysWith: { a, _ in a })
    }

    private var completed: [DailyRunEntity] { dailies.filter { $0.completed } }
    private var bestDaily: Int { dailies.map { Int($0.score) }.max() ?? 0 }
    private var todayKey: String { VentCatalog.dayKey() }
    private var doneToday: Bool { kept[todayKey]?.completed ?? false }

    var body: some View {
        ZStack(alignment: .top) {
            RockBackground()
            AmbientEmbers(count: 18, tint: VV.sulfur, speed: 0.7, seed: 4242)
                .ignoresSafeArea()

            // Today's fissure is the screen's one call to action, so it rides a
            // dock above the home indicator; the record and history scroll over it.
            DockedScroll(contentAlignment: dailies.isEmpty ? .center : .top,
                         clearsHomeIndicator: true) { viewport in
                column(compact: viewport < Self.compactViewport)
            } dock: {
                if !dailies.isEmpty {
                    todayCard.vvEntrance(1)
                }
            }
            .belowSash()

            HeaderSash(title: "The", accent: "Vigil",
                       subtitle: "A new fissure every day",
                       onBack: onBack) {
                SashCounter(value: "\(stats.currentStreak)", caption: "Day streak")
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            stats = ProgressStore.stats(in: ctx)
        }
    }

    // MARK: - Column

    /// Everything above the dock. With no dailies yet the first-run plate keeps
    /// its own action — it is short enough to sit whole on an SE.
    @ViewBuilder
    private func column(compact: Bool) -> some View {
        VStack(spacing: compact ? VV.s2 + 4 : VV.s3) {
            if dailies.isEmpty {
                EdgeStatePlate(
                    art: "valve_open",
                    title: "No vigil kept yet",
                    message: "The mountain opens one fissure a day, the same one for everybody. Take today's and the count starts here.",
                    accent: VV.sulfur,
                    actionTitle: "Take today's fissure",
                    action: {
                        Haptics.knock()
                        onPlayDaily()
                    }
                )
                .vvEntrance(0)
            } else {
                streakHero(compact: compact).vvEntrance(0)
                strip(compact: compact).vvEntrance(2)
                totals(compact: compact).vvEntrance(3)
                historyHeader(compact: compact).vvEntrance(4)
                ForEach(Array(dailies.prefix(30).enumerated()), id: \.element.objectID) { i, d in
                    row(d).vvEntrance(min(5 + i, 11))
                }
            }
        }
    }

    // MARK: - Hero

    private func streakHero(compact: Bool) -> some View {
        InkPanel(rail: VV.sulfur, padding: compact ? VV.s2 + 4 : VV.s3) {
            HStack(alignment: .center, spacing: VV.s3) {
                Image(doneToday ? "cast_star_on" : "valve_open")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: compact ? 44 : 52, height: compact ? 46 : 54)
                    .ambientGlow(VV.sulfur, radius: 18, period: 2.0)
                    .ambientPulse(from: 0.96, to: 1.06, period: 2.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(stats.currentStreak)")
                        .font(VV.display(compact ? 42 : 52))
                        .foregroundStyle(VV.sulfur)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(stats.currentStreak == 1 ? "Day of vigil" : "Days of vigil")
                        .microLabel(VV.ashDeep)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(stats.bestStreak)")
                        .font(VV.display(24))
                        .foregroundStyle(VV.ash)
                        .contentTransition(.numericText())
                    Text("Longest").microLabel(VV.ashDeep)
                }
            }
        }
    }

    // MARK: - Three week strip

    private func strip(compact: Bool) -> some View {
        PaperPanel(rail: VV.magma, padding: compact ? VV.s2 + 4 : VV.s3) {
            VStack(alignment: .leading, spacing: compact ? VV.s2 : VV.s2 + 2) {
                HStack {
                    Text("The last three weeks").microLabel(VV.paperText2)
                    Spacer(minLength: VV.s1)
                    Text("\(completed.count) kept")
                        .microLabel(VV.sulfurDeep)
                }

                let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
                LazyVGrid(columns: columns, spacing: compact ? 4 : 5) {
                    ForEach(stripKeys, id: \.self) { key in
                        dayCell(key, height: compact ? 21 : 26)
                    }
                }

                HStack(spacing: VV.s3) {
                    legend(VV.sulfur, "Kept")
                    legend(VV.obsidian, "Missed")
                    legend(VV.magma, "Today")
                }
            }
        }
    }

    /// Oldest first, so the strip reads left-to-right like a calendar.
    private var stripKeys: [String] {
        (0..<Self.stripDays).reversed().compactMap { back in
            Calendar.current.date(byAdding: .day, value: -back, to: Date())
                .map { VentCatalog.dayKey(for: $0) }
        }
    }

    private func dayCell(_ key: String, height: CGFloat) -> some View {
        let entry = kept[key]
        let isToday = key == todayKey
        let done = entry?.completed ?? false
        let fill: Color = done ? VV.sulfur : (isToday ? VV.magma.opacity(0.35) : VV.obsidian)
        return Rectangle()
            .fill(fill)
            .frame(height: height)
            .overlay {
                if done, let stars = entry.map({ Int($0.stars) }), stars > 0 {
                    Text("\(stars)")
                        .font(VV.display(12))
                        .foregroundStyle(VV.ink)
                } else if isToday {
                    Text("·").font(VV.display(16)).foregroundStyle(VV.magmaCore)
                }
            }
            .overlay(Rectangle().stroke(isToday ? VV.magma : VV.ink.opacity(0.45),
                                        lineWidth: isToday ? 3 : 2))
            .ambientPulse(from: isToday && !done ? 0.94 : 1,
                          to: isToday && !done ? 1.06 : 1,
                          period: 1.6)
    }

    private func legend(_ colour: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(colour)
                .frame(width: 10, height: 10)
                .overlay(Rectangle().stroke(VV.ink.opacity(0.5), lineWidth: 1.5))
            Text(label).microLabel(VV.paperText2)
        }
    }

    // MARK: - Totals

    private func totals(compact: Bool) -> some View {
        PaperPanel(rail: VV.sulfur, padding: compact ? VV.s2 + 4 : VV.s3) {
            VStack(alignment: .leading, spacing: compact ? VV.s2 : VV.s2 + 3) {
                Text("The record").microLabel(VV.paperText2)
                HStack(spacing: VV.s2 + 2) {
                    StatCell(value: "\(completed.count)", caption: "Fissures cast", tint: VV.magma)
                    StatCell(value: "\(dailies.count)", caption: "Opened")
                    StatCell(value: bestDaily > 0 ? bestDaily.castFormatted : "—", caption: "Best score")
                }
                Rectangle().fill(VV.ashMid).frame(height: 1)
                HStack(spacing: VV.s2 + 2) {
                    StatCell(value: dailies.isEmpty ? "—"
                             : "\(Int((Double(completed.count) / Double(dailies.count) * 100).rounded()))%",
                             caption: "Kept rate")
                    StatCell(value: "\(completed.reduce(0) { $0 + Int($1.stars) })", caption: "Daily stars")
                    StatCell(value: "\(dailies.reduce(0) { $0 + Int($1.attempts) })", caption: "Attempts")
                }
            }
        }
    }

    // MARK: - Today

    /// Pinned in the dock rather than the column, so the day's fissure is one
    /// tap away however long the history below the record grows.
    private var todayCard: some View {
        let archetype = VentCatalog.dailyArchetype(todayKey)
        return Button {
            Haptics.knock()
            onPlayDaily()
        } label: {
            HStack(spacing: VV.s2 + 3) {
                Image(doneToday ? "cast_star_on" : "valve_open")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 34, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(doneToday ? "Today is kept" : "Today's fissure")
                        .font(VV.display(22))
                        .textCase(.uppercase)
                        .foregroundStyle(doneToday ? VV.magmaCore : VV.ash)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(RiftCatalog.name(archetype)) shape · \(doneToday ? "run it again" : "not taken yet")")
                        .microLabel(VV.ashDeep)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(VV.sulfur)
            }
            .padding(.horizontal, VV.s3)
            .padding(.vertical, VV.s2 + 4)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0x1C0904).opacity(0.93))
            .overlay(alignment: .leading) {
                Rectangle().fill(doneToday ? VV.sulfur : VV.magma).frame(width: 5)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 0, y: 4)
        }
        .buttonStyle(PressPlateStyle(scale: 0.97))
    }

    // MARK: - History

    private func historyHeader(compact: Bool) -> some View {
        HStack(spacing: VV.s2) {
            Text("Every fissure")
                .microLabel(VV.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(VV.ash)
            Rectangle().fill(VV.ashDeep.opacity(0.5)).frame(height: 2)
        }
        .padding(.top, compact ? 0 : VV.s1)
    }

    private func row(_ d: DailyRunEntity) -> some View {
        let done = d.completed
        let archetype = RiftCatalog.name(Int(d.archetype))
        return HStack(spacing: VV.s2 + 4) {
            Image(done ? "node_cleared" : "node_locked")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 38, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(prettyDate(d.dayKey))
                    .font(VV.display(19))
                    .textCase(.uppercase)
                    .foregroundStyle(VV.ash)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(archetype) shape · \(done ? "\(d.moldsFilled) molds · \(Int((d.yield * 100).rounded()))% yield" : "opened, not cast")")
                    .font(VV.body(11.5))
                    .foregroundStyle(VV.ashDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: VV.s1)

            VStack(alignment: .trailing, spacing: 3) {
                Text(Int(d.score).castFormatted)
                    .font(VV.display(21))
                    .foregroundStyle(done ? VV.magma : VV.ashDeep)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if done { StarRow(earned: Int(d.stars), size: 13, spacing: 2) }
            }
        }
        .padding(.horizontal, VV.s2 + 4)
        .padding(.vertical, VV.s2 + 2)
        .background(Color(hex: 0x200C06).opacity(0.9))
        .overlay(alignment: .leading) {
            Rectangle().fill(done ? VV.sulfur : VV.obsidianLit).frame(width: 5)
        }
        .compositingGroup()
        .shadow(color: VV.ink.opacity(0.4), radius: 0, y: 3)
    }

    /// "2026-09-14" reads as "14 Sep" on the row.
    private func prettyDate(_ key: String?) -> String {
        guard let key, key.count == 10 else { return key ?? "—" }
        let parts = key.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]),
              month >= 1, month <= 12 else { return key }
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return key == todayKey ? "Today · \(day) \(names[month - 1])" : "\(day) \(names[month - 1])"
    }
}
