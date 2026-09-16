import CoreData
import SpriteKit
import SwiftUI

/// The gameplay screen: one SpriteView holding the single scene, with every
/// readable element as a SwiftUI overlay on top of it.
struct VentView: View {
    @Environment(\.managedObjectContext) private var ctx

    let startingVent: Int
    /// Non-nil when this run is the Daily Fissure rather than a numbered vent.
    let dailyKey: String?
    let onLeave: () -> Void
    let onMap: () -> Void

    @StateObject private var vm = GameViewModel()
    @State private var started = false

    @FetchRequest(
        entity: PreferenceEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PreferenceEntity.createdAt, ascending: true)]
    ) private var preferences: FetchedResults<PreferenceEntity>

    var body: some View {
        ZStack {
            // Created once in the view model — never constructed in `body`.
            SpriteView(scene: vm.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            hud

            if vm.state == .paused {
                PauseOverlay(vm: vm, onLeave: onLeave)
                    .transition(.opacity)
            }

            if vm.state == .gameOver, let summary = vm.summary {
                CastResultOverlay(vm: vm, summary: summary, onMap: onMap, onLeave: onLeave)
                    .transition(.opacity)
            }
        }
        .animation(Motion.ease(0.22), value: vm.state)
        .onAppear {
            vm.configure(context: ctx, prefs: preferences.first)
            if !started {
                started = true
                if let dailyKey {
                    vm.startDaily(dayKey: dailyKey)
                } else {
                    vm.start(vent: startingVent)
                }
            }
        }
        .onChange(of: vm.state) { newState in
            // Pause and resume only ever touch `isPaused`.
            vm.scene.isPaused = (newState == .paused || newState == .gameOver)
        }
        .onDisappear { vm.scene.isPaused = true }
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 0) {
            topBar.vvEntrance(0)
            HStack(alignment: .top, spacing: 0) {
                pressureColumn
                Spacer(minLength: 0)
            }
            .padding(.top, VV.s3 - 2)
            .vvEntrance(1)
            Spacer(minLength: 0)
            if vm.chokeWarning > 0 {
                chokeStrip.transition(.opacity)
            } else if vm.hintVisible {
                hintStrip.transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, VV.s1)
        .padding(.bottom, 10)
        .animation(Motion.ease(0.3), value: vm.hintVisible)
        .animation(Motion.ease(0.2), value: vm.chokeWarning > 0)
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                vm.pause()
            } label: {
                Image("btn_pause_valve")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .frame(width: 52, height: 58)
                    .background(VV.ink)
                    .overlay(alignment: .bottom) { Rectangle().fill(VV.sulfur).frame(height: 3) }
                    .shadow(color: .black.opacity(0.4), radius: 0, y: 4)
            }
            .buttonStyle(PressPlateStyle())
            .accessibilityLabel("Pause")

            HStack(spacing: 10) {
                // The name block is the one compressible thing in the bar: the
                // chips and the score are live readouts and hold their size, so
                // a six-mold vent with a long rift name shortens the title
                // rather than pushing the whole screen off to the right.
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.runTitle)
                        .font(VV.display(22))
                        .foregroundStyle(vm.isDaily ? VV.magma : VV.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(vm.isDaily ? "Daily fissure · \(vm.riftName2)" : "Rift \(vm.riftNumeral) · \(vm.riftName)")
                        .font(VV.display(9))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(VV.paperText2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: chipGap) {
                    ForEach(vm.moldFills.indices, id: \.self) { i in
                        moldChip(index: i)
                    }
                }
                .padding(.horizontal, 8)
                .overlay(alignment: .leading) { chipRule }
                .overlay(alignment: .trailing) { chipRule }
                .layoutPriority(1)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(vm.score.castFormatted)
                        .font(VV.display(28))
                        .foregroundStyle(VV.magma)
                        .contentTransition(.numericText())
                        .animation(Motion.spring(0.32, 0.7), value: vm.score)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Cast")
                        .font(VV.display(9))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(VV.paperText2)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .frame(maxWidth: .infinity)
            .background(VV.ash)
            .overlay(alignment: .leading) { Rectangle().fill(VV.magma).frame(width: 5) }
            .compositingGroup()
            .shadow(color: VV.ink.opacity(0.45), radius: 0, y: 4)
            .shadow(color: VV.ink.opacity(0.35), radius: 12, y: 8)
        }
    }

    /// Six molds share the strip four do, so the chips tighten instead of
    /// widening the bar past the screen.
    private var chipWidth: CGFloat { vm.moldCount >= 5 ? 10 : 13 }
    private var chipGap: CGFloat { vm.moldCount >= 5 ? 3 : 4 }

    private var chipRule: some View {
        Rectangle()
            .fill(VV.ashMid)
            .frame(width: 2)
            .mask(VStack(spacing: 3) { ForEach(0..<5, id: \.self) { _ in Rectangle().frame(height: 3) } })
    }

    private func moldChip(index: Int) -> some View {
        let state = index < vm.moldStates.count ? vm.moldStates[index] : .filling
        let fill = index < vm.moldFills.count ? vm.moldFills[index] : 0
        return ZStack(alignment: .bottom) {
            Rectangle().fill(state == .dead || state == .cracked ? VV.obsidian : VV.paperShade)
            if state == .full {
                Rectangle().fill(VV.sulfur)
            } else if state == .filling {
                Rectangle().fill(VV.sulfur).frame(height: max(0, min(1, fill)) * 18)
            }
        }
        .frame(width: chipWidth, height: 18)
        .overlay(Rectangle().stroke(VV.ink, lineWidth: 2))
        .animation(Motion.spring(0.3, 0.7), value: fill)
        .animation(Motion.spring(0.3, 0.7), value: state)
    }

    // MARK: - Pressure column

    private var pressureColumn: some View {
        GeometryReader { geo in
            let barrelHeight = max(180, geo.size.height * 0.62)
            VStack(spacing: 5) {
                Text("Pressure").microLabel(VV.ash)
                    .shadow(color: VV.ink, radius: 3)

                ZStack(alignment: .bottom) {
                    Rectangle().fill(VV.ink)
                    Rectangle().fill(Color(hex: 0x3A1206)).padding(3)

                    // Redline zone.
                    VStack {
                        Rectangle()
                            .fill(VV.danger.opacity(0.55))
                            .frame(height: barrelHeight * 0.17)
                        Spacer(minLength: 0)
                    }
                    .padding(3)

                    // Fill.
                    Rectangle()
                        .fill(vm.pressure > 0.9 ? VV.danger : VV.magma)
                        .frame(height: max(2, CGFloat(min(1, vm.pressure)) * (barrelHeight - 6)))
                        .overlay(alignment: .top) {
                            Rectangle().fill(VV.magmaPale).frame(height: 4)
                        }
                        .padding(.horizontal, 3)
                        .padding(.bottom, 3)

                    // Safe band brackets on both sides.
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .stroke(VV.sulfur, lineWidth: 3)
                            .frame(height: barrelHeight * 0.35)
                            .frame(height: barrelHeight * 0.35)
                        Spacer(minLength: 0)
                            .frame(height: barrelHeight * 0.40)
                    }
                }
                .frame(width: 42, height: barrelHeight)
                .overlay(Rectangle().stroke(VV.ash.opacity(0.6), lineWidth: 2.5))
                .shadow(color: VV.ink.opacity(0.6), radius: 10, y: 6)

                Text("\(Int((vm.pressure * 100).rounded()))%")
                    .font(VV.display(20))
                    .foregroundStyle(vm.pressure > 0.9 ? VV.danger : VV.sulfur)
                    .contentTransition(.numericText())
                    .animation(Motion.spring(0.3, 0.75), value: vm.pressure)
                    .shadow(color: VV.ink, radius: 3, y: 2)
            }
            .frame(width: 58)
        }
        .frame(width: 58, height: 430)
    }

    /// The rim is sealed off — every unfinished mold is behind crust, and the
    /// run ends unless a crust gets blown open.
    private var chokeStrip: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image("valve_crusted")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 24, height: 26)
                Text("Rim sealed · hold a crusted valve")
                    .font(VV.display(VV.tMicro))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(VV.ash)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            RuleBar(fraction: 1 - vm.chokeWarning, fill: VV.danger,
                    track: Color(hex: 0x3E2118), height: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(hex: 0x2A0A04).opacity(0.94))
        .overlay(alignment: .leading) { Rectangle().fill(VV.danger).frame(width: 4) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 0, y: 4)
    }

    // MARK: - Hint

    private var hintStrip: some View {
        HStack(spacing: 10) {
            Image("valve_open")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 24, height: 26)
            Text(vm.hint)
                .font(VV.display(VV.tMicro))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundStyle(VV.ash)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(hex: 0x1C0904).opacity(0.9))
        .overlay(alignment: .leading) { Rectangle().fill(VV.sulfur).frame(width: 4) }
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 0, y: 4)
    }
}
