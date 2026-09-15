import CoreData
import SwiftUI

/// Forty marks struck into the caldera wall, grouped by tier so progress reads
/// as a path rather than a leaderboard.
struct MarksView: View {
    let onBack: () -> Void

    @FetchRequest(
        entity: MarkEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MarkEntity.orderIndex, ascending: true)]
    ) private var marks: FetchedResults<MarkEntity>

    private var earnedCount: Int { marks.filter { $0.earned }.count }
    private var total: Int { max(marks.count, MarkCatalog.all.count) }

    /// The tiers the catalog is authored in, by order index.
    private static let tiers: [(title: String, range: ClosedRange<Int16>)] = [
        ("The first hour", 1...6),
        ("The six rifts", 7...12),
        ("Depth", 13...18),
        ("Craft", 19...28),
        ("Stars and score", 29...33),
        ("The vault", 34...36),
        ("The vigil", 37...40),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            RockBackground()
            AmbientEmbers(count: 12, tint: VV.sulfur, speed: 0.6, seed: 2048)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: VV.s2 + 4) {
                    if earnedCount == 0 {
                        EdgeStatePlate(
                            art: "mark_crustbreaker",
                            title: "Nothing struck yet",
                            message: "Forty marks are cut into this wall and every one of them is still blank. Fill a single rim mold and the first is yours.",
                            accent: VV.obsidianLit
                        )
                        .padding(.bottom, 4)
                    }

                    ForEach(Array(Self.tiers.enumerated()), id: \.element.title) { i, tier in
                        let group = marks.filter { tier.range.contains($0.orderIndex) }
                        if !group.isEmpty {
                            tierHeader(tier.title, group: group).vvEntrance(i)
                            ForEach(group, id: \.objectID) {
                                strip(for: $0).vvEntrance(min(i + 1, 8))
                            }
                        }
                    }

                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, VV.s3)
            }
            .belowSash()

            HeaderSash(title: "Struck", accent: "Marks",
                       subtitle: "Forty to strike",
                       onBack: onBack) {
                SashCounter(value: "\(earnedCount)/\(total)", caption: "Struck")
            }

            VStack {
                Spacer()
                banner
                    .padding(.horizontal, VV.s3)
                    .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func tierHeader(_ title: String, group: [MarkEntity]) -> some View {
        let done = group.filter { $0.earned }.count
        return HStack(spacing: 9) {
            Text(title)
                .microLabel(VV.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(done == group.count ? VV.sulfur : VV.ash)
            Text("\(done)/\(group.count)").microLabel(VV.ashDeep)
            Rectangle()
                .fill(VV.ashDeep.opacity(0.5))
                .frame(height: 2)
        }
        .padding(.top, 6)
    }

    private func strip(for mark: MarkEntity) -> some View {
        let earned = mark.earned
        let progress = mark.target > 0 ? Double(mark.progress) / Double(mark.target) : 0

        return HStack(spacing: 12) {
            Image(mark.assetName ?? "mark_first_cast")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 52, height: 52)
                .saturation(earned ? 1 : 0.15)
                .opacity(earned ? 1 : 0.85)
                .ambientPulse(from: earned ? 0.97 : 1, to: earned ? 1.04 : 1,
                              period: 2.6 + Double(mark.orderIndex % 4) * 0.35)

            VStack(alignment: .leading, spacing: 3) {
                Text(mark.title ?? "")
                    .font(VV.display(21))
                    .textCase(.uppercase)
                    .foregroundStyle(earned ? VV.ink : VV.ash)
                    .fixedSize(horizontal: false, vertical: true)

                Text(mark.detail ?? "")
                    .font(VV.body(12))
                    .foregroundStyle(earned ? VV.paperText2 : VV.ashDeep)
                    .fixedSize(horizontal: false, vertical: true)

                ShimmerRule(fraction: progress,
                            fill: earned ? VV.magma : VV.obsidianLit,
                            track: earned ? VV.paperShade : Color(hex: 0x3E2118),
                            height: 7)
                    .padding(.top, VV.s1)
            }

            if earned {
                Image(systemName: "checkmark")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(VV.sulfurDeep)
            } else {
                Text("\(mark.progress)/\(mark.target)")
                    .font(VV.display(19))
                    .foregroundStyle(VV.ashDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, VV.s3 - 2)
        .padding(.vertical, VV.s2 + 4)
        .background(earned ? VV.ash : Color(hex: 0x200C06).opacity(0.9))
        .overlay(alignment: .leading) {
            Rectangle().fill(earned ? VV.sulfur : VV.obsidianLit).frame(width: 6)
        }
        .compositingGroup()
        .shadow(color: VV.ink.opacity(earned ? 0.5 : 0.4), radius: 0, y: 4)
        .shadow(color: VV.ink.opacity(0.3), radius: 12, y: 8)
    }

    private var banner: some View {
        HStack(spacing: 12) {
            Text("\(earnedCount)/\(total)")
                .font(VV.display(28))
                .foregroundStyle(VV.sulfur)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            VStack(alignment: .leading, spacing: 5) {
                Text(earnedCount == total && total > 0
                     ? "Every mark on the wall is struck."
                     : "Marks struck into the caldera wall")
                    .font(VV.body(12))
                    .foregroundStyle(earnedCount == total && total > 0 ? VV.magmaCore : VV.ashDeep)
                    .fixedSize(horizontal: false, vertical: true)
                ShimmerRule(fraction: total > 0 ? Double(earnedCount) / Double(total) : 0, height: 10)
            }
        }
        .padding(.horizontal, VV.s3)
        .padding(.vertical, 11)
        .background(VV.ink)
        .overlay(alignment: .bottom) { Rectangle().fill(VV.magma).frame(height: 4) }
        .compositingGroup()
        .shadow(color: VV.ink.opacity(0.5), radius: 22, y: 12)
    }
}
