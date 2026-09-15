import CoreData
import SwiftUI

/// The bridge between the scene and SwiftUI, and the only place that writes a
/// run to Core Data. State transitions all happen here.
final class GameViewModel: ObservableObject {

    /// Created once, here. Never constructed inside a `body`.
    let scene: GameScene

    @Published private(set) var state: GameState = .playing
    @Published private(set) var ventNumber: Int = 1
    @Published private(set) var riftIndex: Int = 1
    @Published private(set) var score: Int = 0
    @Published private(set) var pressure: Double = 0.28
    @Published private(set) var moldFills: [Double] = []
    @Published private(set) var moldStates: [MoldVisualState] = []
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var crustedCount: Int = 0
    /// 0…1 while every unfinished mold is sealed behind crust.
    @Published private(set) var chokeWarning: Double = 0

    @Published var summary: RunSummary?
    @Published var commitOutcome: CommitOutcome?
    @Published var awardedCast: CastSpec?

    @Published private(set) var hint: String = VentHints.all[0]
    @Published var hintVisible: Bool = true

    /// A run is either a numbered vent or the Daily Fissure.
    @Published private(set) var isDaily: Bool = false
    private(set) var dayKey: String = ""

    private var context: NSManagedObjectContext?
    private var committed = false
    private var idleSeconds: Double = 0
    private var lastInteractionMolds: Int = -1

    var riftName: String { isDaily ? "Daily Fissure" : RiftCatalog.name(riftIndex) }
    var riftNumeral: String { RiftCatalog.numeral(riftIndex) }
    var runTitle: String { isDaily ? "Daily" : "Vent \(String(format: "%02d", ventNumber))" }
    /// The rift the daily borrowed its shape from, for the HUD subtitle.
    var riftName2: String { RiftCatalog.name(riftIndex) }
    var moldCount: Int { moldFills.count }
    var moldsFilled: Int { moldStates.filter { $0 == .full }.count }
    var isFinalVent: Bool { isDaily || ventNumber >= VentCatalog.ventCount }

    init() {
        scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        scene.bridge = self
    }

    // MARK: - Setup

    func configure(context: NSManagedObjectContext, prefs: PreferenceEntity?) {
        self.context = context
        Haptics.enabled = (prefs?.hapticsOn ?? true) && !LaunchFlags.screenshotTour
        let motion = prefs?.animationsOn ?? true
        scene.motionEnabled = motion
        Motion.enabled = motion
        Haptics.prime()
    }

    /// Loads the Daily Fissure into the existing scene.
    func startDaily(dayKey key: String) {
        let layout = VentCatalog.dailyLayout(dayKey: key)
        isDaily = true
        dayKey = key
        ventNumber = layout.ventNumber
        riftIndex = layout.riftIndex
        hint = VentHints.hint(for: layout.ventNumber)
        hintVisible = false
        resetRunState(layout: layout)
        scene.load(layout: layout)
        state = .playing
        scene.isPaused = false
    }

    /// Loads a vent into the existing scene — the SpriteView is never rebound.
    func start(vent: Int) {
        isDaily = false
        dayKey = ""
        ventNumber = min(max(vent, 1), VentCatalog.ventCount)
        riftIndex = VentCatalog.riftIndex(forVent: ventNumber)
        hint = VentHints.hint(for: ventNumber)
        hintVisible = ventNumber <= 3
        resetRunState(layout: VentCatalog.layout(for: ventNumber))
        scene.load(vent: ventNumber)
        state = .playing
        scene.isPaused = false
    }

    private func resetRunState(layout: VentLayout) {
        idleSeconds = 0
        committed = false
        summary = nil
        commitOutcome = nil
        awardedCast = nil
        score = 0
        elapsed = 0
        crustedCount = 0
        chokeWarning = 0
        moldFills = [Double](repeating: 0, count: layout.moldCount)
        moldStates = [MoldVisualState](repeating: .filling, count: layout.moldCount)
    }

    // MARK: - Intents

    func pause() {
        guard state == .playing else { return }
        state = .paused
        Haptics.tap()
    }

    func resume() {
        guard state == .paused else { return }
        state = .playing
        Haptics.tap()
    }

    func restart() {
        Haptics.knock()
        if isDaily { startDaily(dayKey: dayKey) } else { start(vent: ventNumber) }
    }

    func advanceToNextVent() {
        Haptics.knock()
        start(vent: min(VentCatalog.ventCount, ventNumber + 1))
    }

    // MARK: - Scene callbacks

    /// Called every frame from the scene. Only assigns when something the HUD
    /// can actually show has changed, so SwiftUI is not re-rendered at 60 Hz.
    func sync(from run: VentRun) {
        let newPressure = run.pressure
        if abs(newPressure - pressure) > 0.004 { pressure = newPressure }

        let liveScore = Int((Double(run.moldsFilled) * 250 + run.yieldFraction * 600).rounded())
        if liveScore != score { score = liveScore }

        if Int(run.elapsed) != Int(elapsed) { elapsed = run.elapsed }
        let crustedChanged = run.veinsCrusted != crustedCount
        if crustedChanged { crustedCount = run.veinsCrusted }
        let warn = run.chokeWarning
        if abs(warn - chokeWarning) > 0.02 || (warn == 0) != (chokeWarning == 0) {
            chokeWarning = warn
        }

        var fillsChanged = false
        for i in moldFills.indices where i < run.moldFill.count {
            let f = run.fillFraction(i)
            if abs(f - moldFills[i]) > 0.01 { moldFills[i] = f; fillsChanged = true }
        }

        for i in moldStates.indices where i < run.moldState.count {
            let v = Self.visual(run.moldState[i])
            if v != moldStates[i] { moldStates[i] = v }
        }

        // The hint returns if the player has gone quiet for a while.
        if ventNumber > 3 {
            if fillsChanged || crustedChanged {
                idleSeconds = 0
                if hintVisible { hintVisible = false }
            } else {
                idleSeconds += 1.0 / 60.0
                if idleSeconds > 6 && !hintVisible { hintVisible = true }
            }
        }
    }

    func runDidFinish(run: VentRun, outcome: VentOutcome) {
        // The tour just keeps playing — it never scores or shows an overlay.
        guard !LaunchFlags.deterministic else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.restart()
            }
            return
        }
        guard !committed else { return }
        committed = true

        let result = ScoreRules.summarise(run: run, outcome: outcome)
        summary = result
        score = result.score
        if let context {
            let commit = isDaily
                ? ProgressStore.commitDaily(result, dayKey: dayKey, in: context)
                : ProgressStore.commit(result, in: context)
            commitOutcome = commit
            awardedCast = commit.newCast
        }
        state = .gameOver
    }

    private static func visual(_ s: MoldState) -> MoldVisualState {
        switch s {
        case .filling: return .filling
        case .cast: return .full
        case .cracked: return .cracked
        case .setSolid: return .dead
        }
    }
}
