import SwiftUI

/// Dormant loader screen, built to the same print grammar as the rest of the
/// game. It is complete and self-contained, and is referenced from nowhere —
/// the release team wires it up later. Do not delete it as unused.
struct SplashView: View {
    @State private var sweep: Double = 0
    @State private var emberPulse: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0xFFF0C6), Color(hex: 0xFFC97A),
                             Color(hex: 0xC9531F), Color(hex: 0x3A1206)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Image("hero_caldera_poster")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(0.9)
                    .ignoresSafeArea()

                HalftoneField(tint: Color(hex: 0xC43A0A).opacity(0.22))
                    .ignoresSafeArea()
                AmbientEmbers(count: 20, tint: VV.sulfur, speed: 0.9, seed: 1)
                    .ignoresSafeArea()
                AshGrain().ignoresSafeArea()

                LinearGradient(colors: [Color.clear, VV.ink.opacity(0.72)],
                               startPoint: .center, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Image("logo_title")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: min(geo.size.width * 0.86, 330))
                        .shadow(color: VV.ink.opacity(0.55), radius: 26, x: 6, y: 16)

                    Spacer(minLength: 24)

                    ZStack {
                        Image("splash_loader_ring")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 108, height: 108)
                            .rotationEffect(.degrees(sweep))

                        Circle()
                            .fill(VV.sulfur.opacity(emberPulse ? 0.28 : 0.05))
                            .frame(width: 128, height: 128)
                            .scaleEffect(emberPulse ? 1.12 : 0.92)
                    }
                    .shadow(color: VV.ink.opacity(0.55), radius: 16, y: 10)

                    Text("Warming the chamber")
                        .font(VV.thin(17))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundStyle(VV.ash)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(VV.ink.opacity(0.82))
                        .padding(.top, 26)

                    Spacer(minLength: 0)

                    Text("Shut a vein · steer the pressure")
                        .microLabel(VV.magmaCore)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(VV.ink.opacity(0.7))
                        .padding(.bottom, 34)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            guard Motion.enabled else { return }
            withAnimation(Motion.linearLoop(2.4)) { sweep = 360 }
            withAnimation(Motion.loop(1.1)) { emberPulse = true }
        }
    }
}
