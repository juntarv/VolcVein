import SwiftUI

/// Held. The slab shows live mold and pressure state, so pausing tells you
/// something rather than just stopping the clock.
struct PauseOverlay: View {
    @ObservedObject var vm: GameViewModel
    let onLeave: () -> Void

    /// Both ways out of a held run throw away everything cast so far, so
    /// neither fires on the first tap.
    private enum Exit: Identifiable {
        case restart, leave
        var id: Int { self == .restart ? 0 : 1 }
    }
    @State private var pendingExit: Exit?

    var body: some View {
        ZStack {
            VV.scrim.ignoresSafeArea()
            AmbientEmbers(count: 10, tint: VV.magmaHot, speed: 0.4, seed: 88)
                .ignoresSafeArea()

            GeometryReader { geo in
                // SE-class screens (under ~700pt of safe height) get a tighter
                // dock, so the slab keeps its room above the plates.
                let short = geo.size.height < 700

                DockedScroll(horizontalPadding: VV.s4 - 2,
                             dockSpacing: short ? 8 : 12,
                             contentAlignment: .center) { viewport in
                    // The slab floats mid-screen above the plates, as drawn; it
                    // only tightens its own type and gaps when the viewport runs short.
                    slab(compact: viewport < 450)
                        .padding(.vertical, short ? VV.s2 : VV.s3)
                        .vvEntrance(0)
                } dock: {
                    actions(compact: short).vvEntrance(1)
                    Text("Progress on this vent is kept until you leave")
                        .microLabel(VV.ashMid)
                        .padding(.top, short ? 0 : VV.s1)
                        .vvEntrance(2)
                }
            }

            if let exit = pendingExit {
                confirm(exit).transition(.opacity)
            }
        }
        .animation(Motion.ease(0.2), value: pendingExit?.id)
    }

    @ViewBuilder
    private func confirm(_ exit: Exit) -> some View {
        switch exit {
        case .restart:
            ConfirmPlate(title: "Restart this vent?",
                         message: "The molds you have filled and the score on them are poured out. The vent starts cold again.",
                         confirmTitle: "Restart vent",
                         confirmIcon: "arrow.counterclockwise",
                         onConfirm: {
                             pendingExit = nil
                             vm.restart()
                         },
                         onCancel: { pendingExit = nil })
        case .leave:
            ConfirmPlate(title: "Leave to the caldera?",
                         message: "This descent is abandoned. Nothing from it is written to the ledger.",
                         confirmTitle: "Leave the vent",
                         confirmIcon: "triangle",
                         onConfirm: {
                             pendingExit = nil
                             onLeave()
                         },
                         onCancel: { pendingExit = nil })
        }
    }

    private func slab(compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                HStack(spacing: 0) {
                    Text("Held")
                        .font(VV.display(compact ? 40 : 50))
                        .foregroundStyle(VV.ash)
                    Text(".")
                        .font(VV.display(compact ? 40 : 50))
                        .foregroundStyle(VV.sulfur)
                }
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Spacer(minLength: 0)
                Text("Vent \(String(format: "%02d", vm.ventNumber)) · Rift \(vm.riftNumeral)")
                    .microLabel(VV.ashDeep)
            }
            .padding(.horizontal, 20)
            .padding(.top, compact ? 12 : 16)
            .padding(.bottom, compact ? 10 : 14)
            .frame(maxWidth: .infinity)
            .background(VV.ink)

            VStack(alignment: .leading, spacing: 0) {
                Text("Rim molds").microLabel(VV.paperText2)
                    .padding(.bottom, compact ? 5 : 6)

                HStack(spacing: 8) {
                    ForEach(vm.moldFills.indices, id: \.self) { i in
                        MoldGauge(index: i + 1,
                                  fill: vm.moldFills[i],
                                  state: i < vm.moldStates.count ? vm.moldStates[i] : .filling)
                    }
                }

                Divider()
                    .overlay(VV.ashMid)
                    .padding(.vertical, compact ? 9 : 14)

                HStack(alignment: .center, spacing: 8) {
                    Image("gauge_pressure_column")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: compact ? 12 : 14, height: compact ? 28 : 34)
                    Text("Chamber pressure").microLabel(VV.paperText2)
                    Spacer(minLength: 0)
                    Text("\(Int((vm.pressure * 100).rounded()))%")
                        .font(VV.display(compact ? 21 : 23))
                        .foregroundStyle(vm.pressure > 0.9 ? VV.danger : VV.magma)
                        .contentTransition(.numericText())
                }
                PressureTrack(value: vm.pressure)
                    .padding(.top, 7)
                Text("Safe band 40–75% · redline at 95%")
                    .microLabel(VV.paperText2)
                    .padding(.top, 7)

                Divider()
                    .overlay(VV.ashMid)
                    .padding(.vertical, compact ? 8 : 12)

                HStack(spacing: 18) {
                    ledger("Veins crusted", "\(vm.crustedCount)", compact: compact)
                    ledger("Molds cast", "\(vm.moldsFilled)/\(vm.moldCount)", compact: compact)
                    ledger("Elapsed", "\(Int(vm.elapsed))s", compact: compact)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, compact ? 12 : 16)
            .padding(.bottom, compact ? 14 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VV.ash)
        }
        .compositingGroup()
        .shadow(color: VV.ink.opacity(0.55), radius: 0, y: 6)
        .shadow(color: VV.ink.opacity(0.55), radius: compact ? 20 : 30, y: compact ? 12 : 18)
    }

    private func ledger(_ caption: String, _ value: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(VV.display(compact ? 19 : 21))
                .foregroundStyle(VV.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption).microLabel(VV.paperText2)
        }
    }

    /// Pinned in the dock: Resume stays the dominant sulfur plate at every size,
    /// the stone slabs just give up a little height on short screens.
    private func actions(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 11) {
            FissurePlate(title: "Resume",
                         height: compact ? 68 : 78,
                         titleSize: compact ? 30 : 34) {
                vm.resume()
            }
            StonePlate(title: "Restart vent",
                       systemIcon: "arrow.counterclockwise",
                       height: compact ? 50 : 56) {
                pendingExit = .restart
            }
            StonePlate(title: "Leave to caldera",
                       systemIcon: "triangle",
                       underline: VV.magma,
                       height: compact ? 50 : 56) {
                pendingExit = .leave
            }
        }
    }
}
