import CoreData
import SwiftUI

/// The thirty obsidian pieces, resting on strata shelves at deliberately
/// unequal sizes — one shelf per rift, never a uniform grid.
struct CastVaultView: View {
    @Environment(\.managedObjectContext) private var ctx

    let onBack: () -> Void
    let onPlayVent: (Int) -> Void

    @FetchRequest(
        entity: CastEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CastEntity.orderIndex, ascending: true)]
    ) private var casts: FetchedResults<CastEntity>

    @State private var detailKey: String?

    private var unlockedCount: Int { casts.filter { $0.unlocked }.count }

    /// Shelf heights shrink as the rifts go deeper, so the wall reads as strata
    /// rather than a grid.
    private static let shelves: [(rift: Int, height: CGFloat)] = [
        (1, 96), (2, 84), (3, 74), (4, 66), (5, 60), (6, 56),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            RockBackground()
            // Ember dust settling over the shelves.
            AmbientEmbers(count: 14, tint: VV.magmaCore, speed: 0.5, seed: 1024)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if unlockedCount == 0 {
                        EdgeStatePlate(
                            art: "cast_locked_lump",
                            title: "The vault is empty",
                            message: "Thirty molds are waiting and not one of them has been filled. Clear Vent 02 and the mountain hands over its first piece.",
                            accent: VV.obsidianLit,
                            actionTitle: "Back to the caldera",
                            action: onBack
                        )
                        .padding(.horizontal, VV.s3)
                        .padding(.top, 20)
                    }

                    ForEach(Array(Self.shelves.enumerated()), id: \.element.rift) { i, shelf in
                        shelfRow(rift: shelf.rift, height: shelf.height)
                            .vvEntrance(i)
                    }

                    Color.clear.frame(height: 40)
                }
            }
            .belowSash()

            HeaderSash(title: "Obsidian", accent: "Casts",
                       subtitle: "Every vent leaves a shape",
                       onBack: onBack) {
                SashCounter(value: "\(unlockedCount)/\(CastCatalog.all.count)", caption: "Cast")
            }

            if let detailKey {
                CastDetailOverlay(
                    castKey: detailKey,
                    onClose: { self.detailKey = nil },
                    onPlayVent: onPlayVent
                )
                .transition(.opacity)
            }
        }
        .animation(Motion.ease(0.2), value: detailKey)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Shelves

    /// Three to a ledge, the way the design lays them out — five across a single
    /// row left every name truncated.
    private static let perLedge = 3

    private func shelfRow(rift: Int, height: CGFloat) -> some View {
        let spec = RiftCatalog.spec(rift)
        let first = VentCatalog.firstVent(ofRift: rift)
        let last = VentCatalog.lastVent(ofRift: rift)
        let items = casts.filter { Int($0.awardVent) >= first && Int($0.awardVent) <= last }
        let got = items.filter { $0.unlocked }.count
        let ledges = stride(from: 0, to: items.count, by: Self.perLedge).map {
            Array(items[$0..<min($0 + Self.perLedge, items.count)])
        }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: VV.s2) {
                Text("Rift \(spec.numeral) · \(spec.name)")
                    .microLabel(VV.ashDeep)
                    .padding(.horizontal, 9)
                    .padding(.vertical, VV.s1)
                    .background(VV.ink)
                Text("\(got)/\(items.count)")
                    .microLabel(got == items.count && got > 0 ? VV.sulfur : VV.ashDeep)
                Spacer(minLength: 0)
            }
            .padding(.leading, VV.s3)
            .padding(.bottom, VV.s2 - 2)

            ForEach(Array(ledges.enumerated()), id: \.offset) { _, ledge in
                HStack(alignment: .bottom, spacing: VV.s2) {
                    ForEach(ledge, id: \.objectID) { cast in
                        shelfItem(cast: cast, height: height)
                            .frame(maxWidth: .infinity)
                    }
                    // Keep the columns even when a ledge is short.
                    ForEach(0..<(Self.perLedge - ledge.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
                .padding(.horizontal, VV.s3)

                Rectangle()
                    .fill(LinearGradient(colors: [VV.rockFlare, VV.rock, Color(hex: 0x3A1206)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 16)
                    .overlay(alignment: .top) { Rectangle().fill(Color(hex: 0xE8712B)).frame(height: 3) }
                    .shadow(color: VV.ink.opacity(0.55), radius: 12, y: 8)
                    .padding(.top, 2)
                    .padding(.bottom, VV.s3 + 2)
            }
        }
    }

    private func shelfItem(cast: CastEntity, height: CGFloat) -> some View {
        let unlocked = cast.unlocked
        let spec = CastCatalog.spec(key: cast.castKey)
        let lockedArt = (cast.orderIndex % 2 == 0) ? "cast_locked_lump" : "cast_locked_lump_b"

        return Button {
            detailKey = cast.castKey
        } label: {
            VStack(spacing: VV.s1) {
                Image(unlocked ? (cast.assetName ?? "cast_emberdrop") : lockedArt)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: height)
                    .shadow(color: VV.ink.opacity(0.5), radius: 8, y: 6)
                    .ambientPulse(from: unlocked ? 0.985 : 1, to: unlocked ? 1.02 : 1,
                                  period: 3.0 + Double(cast.orderIndex % 5) * 0.4)

                // Two lines and a scale floor, so a full name always reads.
                Text(unlocked ? (cast.name ?? "") : (spec.map(CastCatalog.requirement) ?? "Sealed"))
                    .font(VV.display(VV.tMicro))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(unlocked ? VV.ash : VV.ashMid)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(unlocked ? VV.ink : VV.obsidian.opacity(0.95))
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PressPlateStyle(scale: 0.93))
    }
}
