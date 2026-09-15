import CoreData
import SwiftUI

enum Route: Hashable {
    case caldera
    case riftMap
    case riftDossier(Int)
    case vent(Int)
    case daily
    case vault
    case marks
    case ledger
    case vigil
    case settings
}

/// Owns the launch flow (onboarding → Caldera) and, under `-screenshotTour`,
/// drives the automated walk through the app.
struct HomeView: View {
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(
        entity: PreferenceEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PreferenceEntity.createdAt, ascending: true)]
    ) private var preferences: FetchedResults<PreferenceEntity>

    @State private var route: Route = .caldera
    @State private var booted = false
    @State private var tourIndex = 0

    private let tourTick = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    private static let tourRoutes: [Route] = [
        .caldera, .vent(LaunchFlags.demoVent), .riftMap, .riftDossier(3),
        .vault, .marks, .ledger, .vigil, .settings,
    ]

    private var prefs: PreferenceEntity? { preferences.first }
    private var onboardingDone: Bool { prefs?.firstLaunchCompleted ?? false }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VV.rockDeep.ignoresSafeArea()

                if !booted {
                    RockBackground()
                } else if !onboardingDone {
                    OnboardingView(onFinish: completeOnboarding)
                        .transition(.opacity)
                } else {
                    routed
                        .transition(.opacity)
                }
            }
            .environment(\.safeTop, geo.safeAreaInsets.top)
            .environment(\.safeBottom, geo.safeAreaInsets.bottom)
        }
        .animation(Motion.ease(0.28), value: onboardingDone)
        .animation(Motion.ease(0.25), value: route)
        .onAppear(perform: boot)
        .onReceive(tourTick) { _ in advanceTour() }
    }

    @ViewBuilder
    private var routed: some View {
        switch route {
        case .caldera:
            CalderaView(
                onPlay: { route = .vent(ProgressStore.liveVent(in: ctx)) },
                onDaily: { route = .daily },
                onMap: { route = .riftMap },
                onVault: { route = .vault },
                onMarks: { route = .marks },
                onLedger: { route = .ledger },
                onSettings: { route = .settings }
            )
        case .riftMap:
            RiftMapView(
                onBack: { route = .caldera },
                onEnter: { route = .vent($0) },
                onOpenRift: { route = .riftDossier($0) }
            )
        case .riftDossier(let rift):
            RiftDossierView(
                riftIndex: rift,
                onBack: { route = .riftMap },
                onEnter: { route = .vent($0) }
            )
        case .vent(let number):
            VentView(
                startingVent: number,
                dailyKey: nil,
                onLeave: { route = .caldera },
                onMap: { route = .riftMap }
            )
        case .daily:
            VentView(
                startingVent: 1,
                dailyKey: VentCatalog.dayKey(),
                onLeave: { route = .caldera },
                onMap: { route = .ledger }
            )
        case .vault:
            CastVaultView(
                onBack: { route = .caldera },
                onPlayVent: { route = .vent($0) }
            )
        case .marks:
            MarksView(onBack: { route = .caldera })
        case .ledger:
            LedgerView(
                onBack: { route = .caldera },
                onPlay: { route = .vent(ProgressStore.liveVent(in: ctx)) },
                onVigil: { route = .vigil }
            )
        case .vigil:
            VigilView(
                onBack: { route = .caldera },
                onPlayDaily: { route = .daily }
            )
        case .settings:
            ValveHouseView(
                onBack: { route = .caldera },
                onReset: { route = .caldera }
            )
        }
    }

    // MARK: - Boot

    private func boot() {
        guard !booted else { return }
        let prefs = Seeder.preferences(in: ctx)

        if LaunchFlags.screenshotTour {
            // Separate path — a normal launch never runs this.
            Seeder.seedTourProgress(in: ctx)
            route = Self.tourRoutes[0]
        } else {
            Seeder.seedDomainIfNeeded(in: ctx)
            route = .caldera
        }

        Haptics.enabled = prefs.hapticsOn && !LaunchFlags.screenshotTour
        Motion.enabled = prefs.animationsOn
        booted = true
    }

    private func completeOnboarding() {
        let prefs = Seeder.preferences(in: ctx)
        Seeder.seedDomainIfNeeded(in: ctx)
        prefs.firstLaunchCompleted = true
        ctx.saveChanges()
        route = .caldera
    }

    // MARK: - Screenshot tour

    private func advanceTour() {
        guard LaunchFlags.screenshotTour, booted else { return }
        tourIndex = (tourIndex + 1) % Self.tourRoutes.count
        route = Self.tourRoutes[tourIndex]
    }
}
