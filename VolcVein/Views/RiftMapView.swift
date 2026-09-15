import CoreData
import SwiftUI

/// Sixty vent nodes climbing one vein, banded into six rifts.
struct RiftMapView: View {
    @Environment(\.managedObjectContext) private var ctx

    let onBack: () -> Void
    let onEnter: (Int) -> Void
    let onOpenRift: (Int) -> Void

    @FetchRequest(
        entity: VentProgressEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \VentProgressEntity.ventNumber, ascending: true)]
    ) private var vents: FetchedResults<VentProgressEntity>

    @State private var briefing: Int?

    private var clearedCount: Int { vents.filter { $0.cleared }.count }
    private var liveVent: Int {
        vents.filter { $0.unlocked }.map { Int($0.ventNumber) }.max() ?? 1
    }

    var body: some View {
        ZStack(alignment: .top) {
            RockBackground()
            // Sparks rising off the vein — the map's ambient element.
            AmbientEmbers(count: 20, tint: VV.magmaHot, speed: 1.1, seed: 512)
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    // Deepest vent at the top of the scroll, so the map reads as
                    // a climb the way the design draws it.
                    LazyVStack(spacing: 0) {
                        ForEach(Array(vents.reversed()), id: \.objectID) { vent in
                            let n = Int(vent.ventNumber)
                            if n % VentCatalog.ventsPerRift == 0 {
                                riftBand(for: VentCatalog.riftIndex(forVent: n))
                            }
                            ventRow(vent: vent, number: n)
                                .id(n)
                        }
                        Color.clear.frame(height: 40)
                    }
                }
                .belowSash()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(Motion.ease(0.45)) { proxy.scrollTo(liveVent, anchor: .center) }
                    }
                }
            }

            HeaderSash(title: "Rift", accent: "Map",
                       subtitle: "Six rifts · sixty vents",
                       onBack: onBack) {
                SashCounter(value: "\(clearedCount)/\(VentCatalog.ventCount)", caption: "Vents cast")
            }

            if let briefing {
                VentBriefOverlay(
                    ventNumber: briefing,
                    onEnter: { onEnter(briefing) },
                    onClose: { self.briefing = nil }
                )
                .transition(.opacity)
            }
        }
        .animation(Motion.ease(0.2), value: briefing)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Rows

    private func ventRow(vent: VentProgressEntity, number: Int) -> some View {
        // Alternate the node left and right so the vein visibly snakes.
        let leading = number % 2 == 0
        let unlocked = vent.unlocked
        let cleared = vent.cleared

        return HStack(spacing: 12) {
            if !leading { Spacer(minLength: 0) }

            Button {
                guard unlocked else {
                    Haptics.warn()
                    return
                }
                briefing = number
            } label: {
                VStack(spacing: 5) {
                    Image(cleared ? "node_cleared" : (unlocked ? "node_live" : "node_locked"))
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 62, height: 68)
                        .overlay {
                            Text("\(number)")
                                .font(VV.display(21))
                                .foregroundStyle(unlocked ? VV.ink : VV.ashMid)
                                .offset(y: -1)
                                .shadow(color: (unlocked ? VV.magmaPale : VV.obsidian).opacity(0.8),
                                        radius: 2)
                        }
                        .shadow(color: VV.ink.opacity(0.5), radius: 8, y: 5)
                        .ambientPulse(from: number == liveVent && !cleared ? 0.94 : 1,
                                      to: number == liveVent && !cleared ? 1.07 : 1,
                                      period: 1.8)

                    if cleared { StarRow(earned: Int(vent.starsEarned), size: 17, spacing: 3) }
                }
                .frame(minWidth: 62, minHeight: 68)
            }
            .buttonStyle(PressPlateStyle(scale: 0.92))
            .disabled(!unlocked)

            InkPlate(underline: unlocked ? VV.magma : VV.obsidianLit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vent \(String(format: "%02d", number))")
                        .microLabel(unlocked ? VV.ash : VV.ashMid)
                    if cleared {
                        Text("Best \(Int(vent.bestScore).castFormatted) · \(Int((vent.bestYield * 100).rounded()))%")
                            .microLabel(VV.magmaCore)
                    } else if number == liveVent {
                        Text("Tap to brief").microLabel(VV.sulfur)
                    } else if !unlocked {
                        Text("Sealed").microLabel(VV.ashDeep)
                    } else {
                        Text("Open").microLabel(VV.ashDeep)
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            if leading { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, VV.s2 + 1)
        .background(alignment: .center) {
            Rectangle()
                .fill(unlocked ? VV.magma.opacity(0.85) : VV.obsidian)
                .frame(width: 9)
                .shadow(color: VV.ink, radius: 0, x: 3, y: 0)
                .shadow(color: VV.ink, radius: 0, x: -3, y: 0)
        }
    }

    private func riftBand(for index: Int) -> some View {
        Button { onOpenRift(index) } label: { riftBandLabel(for: index) }
            .buttonStyle(PressPlateStyle(scale: 0.98))
    }

    private func riftBandLabel(for index: Int) -> some View {
        let spec = RiftCatalog.spec(index)
        let inRift = vents.filter { Int($0.riftIndex) == index }
        let unlockedRift = inRift.contains { $0.unlocked }
        let clearedInRift = inRift.filter { $0.cleared }.count
        let starsInRift = inRift.reduce(0) { $0 + Int($1.starsEarned) }

        return VStack(spacing: 7) {
            HStack(spacing: 8) {
                dashes
                Text("Rift \(spec.numeral) · \(spec.name)")
                    .microLabel(unlockedRift ? VV.ink : VV.ashMid)
                    .fixedSize()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(unlockedRift ? VV.ash : VV.obsidian)
                    .compositingGroup()
                    .shadow(color: VV.ink.opacity(0.5), radius: 0, y: 3)
                dashes
            }

            if unlockedRift {
                HStack(spacing: VV.s2 + 2) {
                    Text("\(clearedInRift)/\(VentCatalog.ventsPerRift) cast")
                        .microLabel(VV.ashDeep)
                    ShimmerRule(fraction: Double(clearedInRift) / Double(VentCatalog.ventsPerRift),
                                fill: VV.magma, height: 6)
                        .frame(width: 104)
                    Text("\(starsInRift)★").microLabel(VV.sulfur)
                    Text("Dossier ›").microLabel(VV.magmaCore)
                }
            } else {
                Text("Sealed · clear seven of the rift below · tap for the dossier")
                    .microLabel(VV.ashDeep)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private var dashes: some View {
        Rectangle()
            .fill(VV.ashDeep)
            .frame(height: 3)
            .mask(
                HStack(spacing: 7) {
                    ForEach(0..<6, id: \.self) { _ in Rectangle().frame(width: 9) }
                }
            )
    }
}
