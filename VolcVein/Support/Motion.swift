import SwiftUI

/// Every piece of SwiftUI motion in the app goes through here, so the Motion
/// switch in the Valve House genuinely turns all of it off — not just the
/// SpriteKit shake and bursts.
enum Motion {

    /// Mirrors `PreferenceEntity.animationsOn`. Set at boot and whenever the
    /// switch is thrown.
    static var enabled: Bool = true

    // MARK: - Curves

    /// The app's standard spring: quick, slightly heavy, no overshoot wobble.
    static func spring(_ response: Double = 0.34,
                       _ damping: Double = 0.78) -> Animation? {
        enabled ? .spring(response: response, dampingFraction: damping) : nil
    }

    /// A softer settle for panels arriving.
    static func ease(_ duration: Double = 0.28) -> Animation? {
        enabled ? .easeInOut(duration: duration) : nil
    }

    /// A continuous loop, or nothing at all.
    static func loop(_ duration: Double, autoreverses: Bool = true) -> Animation? {
        guard enabled else { return nil }
        return .easeInOut(duration: duration).repeatForever(autoreverses: autoreverses)
    }

    static func linearLoop(_ duration: Double) -> Animation? {
        guard enabled else { return nil }
        return .linear(duration: duration).repeatForever(autoreverses: false)
    }

    /// Stagger between successive entering elements.
    static let stagger: Double = 0.055
    static let entranceRise: CGFloat = 18
}

// MARK: - Entry

/// Slides and fades an element in, staggered by its position in the screen.
/// With motion off it simply appears.
private struct EntranceModifier: ViewModifier {
    let index: Int
    /// Owned by the element itself rather than a parent flag: a row built late
    /// by a lazy stack, or one whose animation is interrupted by a route
    /// change, still lands opaque because its own `onAppear` always runs.
    @State private var shown = false

    /// Nothing waits longer than this before it is on screen, whatever its
    /// position in the stagger.
    private static let maxDelay: Double = 0.3

    func body(content: Content) -> some View {
        let show = shown || !Motion.enabled
        return content
            .opacity(show ? 1 : 0)
            .offset(y: show ? 0 : Motion.entranceRise)
            .onAppear {
                guard Motion.enabled else {
                    shown = true
                    return
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)
                                .delay(min(Double(index) * Motion.stagger, Self.maxDelay))) {
                    shown = true
                }
            }
            .onDisappear { shown = false }
    }
}

// MARK: - Ambient

/// A slow breath — the ambient element most screens carry.
private struct AmbientPulse: ViewModifier {
    let from: Double
    let to: Double
    let period: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? to : from)
            .onAppear {
                guard Motion.enabled else { return }
                withAnimation(Motion.loop(period)) { on = true }
            }
    }
}

/// A slow drift, for plumes and clouds.
private struct AmbientDrift: ViewModifier {
    let x: CGFloat
    let y: CGFloat
    let period: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .offset(x: on ? x : -x, y: on ? y : -y)
            .onAppear {
                guard Motion.enabled else { return }
                withAnimation(Motion.loop(period)) { on = true }
            }
    }
}

/// Continuous rotation, for valve wheels and loader rings.
private struct AmbientSpin: ViewModifier {
    let period: Double
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard Motion.enabled else { return }
                withAnimation(Motion.linearLoop(period)) { angle = 360 }
            }
    }
}

/// A soft glow that swells and fades — used behind live/important things.
private struct AmbientGlow: ViewModifier {
    let colour: Color
    let radius: CGFloat
    let period: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .shadow(color: colour.opacity(on ? 0.75 : 0.2),
                    radius: on ? radius : radius * 0.45)
            .onAppear {
                guard Motion.enabled else { return }
                withAnimation(Motion.loop(period)) { on = true }
            }
    }
}

extension View {
    func vvEntrance(_ index: Int) -> some View {
        modifier(EntranceModifier(index: index))
    }

    func ambientPulse(from: Double = 0.97, to: Double = 1.03, period: Double = 2.4) -> some View {
        modifier(AmbientPulse(from: from, to: to, period: period))
    }

    func ambientDrift(x: CGFloat = 6, y: CGFloat = 0, period: Double = 6) -> some View {
        modifier(AmbientDrift(x: x, y: y, period: period))
    }

    func ambientSpin(period: Double = 22) -> some View {
        modifier(AmbientSpin(period: period))
    }

    func ambientGlow(_ colour: Color = VV.sulfur, radius: CGFloat = 14,
                     period: Double = 2.2) -> some View {
        modifier(AmbientGlow(colour: colour, radius: radius, period: period))
    }
}

// MARK: - Ambient embers

/// Drifting sparks over a background. Uses a timeline while motion is on and
/// settles into a still field when it is off, so every screen keeps its texture
/// either way.
struct AmbientEmbers: View {
    var count: Int = 16
    var tint: Color = VV.sulfur
    var speed: Double = 1
    var seed: UInt64 = 9

    private struct Mote {
        let x: Double
        let phase: Double
        let rise: Double
        let size: Double
        let alpha: Double
    }

    private var motes: [Mote] {
        var rng = SeededRandom(seed: seed)
        return (0..<count).map { _ in
            Mote(x: rng.unit(),
                 phase: rng.unit(),
                 rise: 0.55 + rng.unit() * 0.75,
                 size: 1.6 + rng.unit() * 2.8,
                 alpha: 0.24 + rng.unit() * 0.5)
        }
    }

    var body: some View {
        GeometryReader { geo in
            if Motion.enabled {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { ctx, size in
                        let t = timeline.date.timeIntervalSinceReferenceDate * 0.06 * speed
                        draw(ctx: &ctx, size: size, t: t)
                    }
                }
            } else {
                Canvas { ctx, size in
                    var c = ctx
                    draw(ctx: &c, size: size, t: 0)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for mote in motes {
            // Each mote climbs, wraps, and sways a little on the way up.
            let progress = (mote.phase + t * mote.rise).truncatingRemainder(dividingBy: 1)
            let y = size.height * (1 - progress)
            let sway = sin((progress + mote.phase) * .pi * 4) * 9
            let x = size.width * mote.x + sway
            let fade = sin(progress * .pi)          // fade in and out at the ends
            let r = mote.size
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect),
                     with: .color(tint.opacity(mote.alpha * fade)))
        }
    }
}

// MARK: - Shimmer

/// A sulfur highlight that travels along a filled bar — the ambient tell that a
/// progress figure is live rather than printed.
struct ShimmerRule: View {
    let fraction: Double
    var fill: Color = VV.magma
    var track: Color = Color(hex: 0x3E2118)
    var height: CGFloat = 9
    @State private var sweep: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            let w = max(0, min(1, fraction)) * geo.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle()
                    .fill(fill)
                    .frame(width: w)
                    .overlay(alignment: .leading) {
                        if Motion.enabled && w > 8 {
                            LinearGradient(
                                colors: [.clear, VV.magmaPale.opacity(0.85), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: 46)
                            .offset(x: sweep * (w + 46))
                            .blendMode(.screen)
                        }
                    }
                    .clipped()
            }
            .onAppear {
                guard Motion.enabled else { return }
                withAnimation(Motion.linearLoop(2.6)) { sweep = 1 }
            }
        }
        .frame(height: height)
    }
}
