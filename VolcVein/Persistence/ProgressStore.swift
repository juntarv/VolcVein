import CoreData
import Foundation

/// Lifetime numbers the Caldera carves into its chamber wall.
struct CalderaStats {
    var bestCast: Int = 0
    var riftsCleared: Int = 0
    var riftsTotal: Int = VentCatalog.riftCount
    var deepestVent: Int = 1
    var averageYield: Double = 0
    var castsUnlocked: Int = 0
    var castsTotal: Int = CastCatalog.all.count
    var marksEarned: Int = 0
    var marksTotal: Int = MarkCatalog.all.count
    var ventsCleared: Int = 0
    var ventsTotal: Int = VentCatalog.ventCount

    var totalStars: Int = 0
    var starsTotal: Int = VentCatalog.ventCount * 3
    var rank: RankSpec = RankCatalog.all[0]
    var nextRank: (RankSpec, Int)?

    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var totalRuns: Int = 0
    var dailyDoneToday: Bool = false

    /// Nothing played yet — the Caldera shows its first-run face.
    var isFirstRun: Bool { totalRuns == 0 && ventsCleared == 0 }
    /// Every vent cast — the mountain is spent.
    var isComplete: Bool { ventsCleared >= ventsTotal }
}

/// Lifetime figures for the Ledger.
struct LedgerTotals {
    var runs: Int = 0
    var casts: Int = 0
    var blowouts: Int = 0
    var chokes: Int = 0
    var magmaCast: Int = 0
    var crustsBlown: Int = 0
    var veinsCrusted: Int = 0
    var moldsFilled: Int = 0
    var bestScore: Int = 0
    var bestYield: Double = 0
    var averageYield: Double = 0
    var timeUnderTheRim: Double = 0

    var successRate: Double { runs > 0 ? Double(casts) / Double(runs) : 0 }
}

/// What a finished run changed, so the result overlay can say so.
struct CommitOutcome {
    var newCast: CastSpec?
    var newMarks: [String] = []
    var unlockedVent: Int?
    var unlockedRift: Int?
    var isNewBest: Bool = false
    var newRank: RankSpec?
    var streakAfter: Int = 0
}

/// The single place the app reads and writes progress. The scene never touches
/// Core Data — `GameViewModel` calls `commit` once, at game over.
enum ProgressStore {

    // MARK: - Reads

    static func vents(in ctx: NSManagedObjectContext) -> [VentProgressEntity] {
        let request = NSFetchRequest<VentProgressEntity>(entityName: "VentProgressEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "ventNumber", ascending: true)]
        return (try? ctx.fetch(request)) ?? []
    }

    static func vent(_ number: Int, in ctx: NSManagedObjectContext) -> VentProgressEntity? {
        let request = NSFetchRequest<VentProgressEntity>(entityName: "VentProgressEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "ventNumber", ascending: true)]
        request.predicate = NSPredicate(format: "ventNumber == %d", number)
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    static func casts(in ctx: NSManagedObjectContext) -> [CastEntity] {
        let request = NSFetchRequest<CastEntity>(entityName: "CastEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        return (try? ctx.fetch(request)) ?? []
    }

    static func marks(in ctx: NSManagedObjectContext) -> [MarkEntity] {
        let request = NSFetchRequest<MarkEntity>(entityName: "MarkEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        return (try? ctx.fetch(request)) ?? []
    }

    static func rifts(in ctx: NSManagedObjectContext) -> [RiftEntity] {
        let request = NSFetchRequest<RiftEntity>(entityName: "RiftEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "riftIndex", ascending: true)]
        return (try? ctx.fetch(request)) ?? []
    }

    static func runs(in ctx: NSManagedObjectContext, limit: Int = 400) -> [RunRecordEntity] {
        let request = NSFetchRequest<RunRecordEntity>(entityName: "RunRecordEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = limit
        return (try? ctx.fetch(request)) ?? []
    }

    static func dailyRuns(in ctx: NSManagedObjectContext, limit: Int = 90) -> [DailyRunEntity] {
        let request = NSFetchRequest<DailyRunEntity>(entityName: "DailyRunEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "dayKey", ascending: false)]
        request.fetchLimit = limit
        return (try? ctx.fetch(request)) ?? []
    }

    /// Deepest vent the player may enter right now.
    static func liveVent(in ctx: NSManagedObjectContext) -> Int {
        let unlocked = vents(in: ctx).filter { $0.unlocked }
        guard let deepest = unlocked.map({ Int($0.ventNumber) }).max() else { return 1 }
        return deepest
    }

    static func starsInRift(_ rift: Int, in ctx: NSManagedObjectContext) -> Int {
        vents(in: ctx)
            .filter { Int($0.riftIndex) == rift }
            .reduce(0) { $0 + Int($1.starsEarned) }
    }

    static func stats(in ctx: NSManagedObjectContext) -> CalderaStats {
        var s = CalderaStats()
        let allVents = vents(in: ctx)
        s.ventsCleared = allVents.filter { $0.cleared }.count
        s.bestCast = allVents.map { Int($0.bestScore) }.max() ?? 0
        s.deepestVent = allVents.filter { $0.unlocked }.map { Int($0.ventNumber) }.max() ?? 1
        s.totalStars = allVents.reduce(0) { $0 + Int($1.starsEarned) }
        s.rank = RankCatalog.rank(forStars: s.totalStars)
        s.nextRank = RankCatalog.next(afterStars: s.totalStars)

        let yields = allVents.filter { $0.cleared }.map(\.bestYield)
        s.averageYield = yields.isEmpty ? 0 : yields.reduce(0, +) / Double(yields.count)

        s.riftsCleared = (1...VentCatalog.riftCount).filter { rift in
            let inRift = allVents.filter { Int($0.riftIndex) == rift }
            return !inRift.isEmpty && inRift.allSatisfy { $0.cleared }
        }.count

        s.castsUnlocked = casts(in: ctx).filter { $0.unlocked }.count
        s.marksEarned = marks(in: ctx).filter { $0.earned }.count

        let v = vigil(in: ctx)
        s.currentStreak = Int(v.currentStreak)
        s.bestStreak = Int(v.bestStreak)
        s.totalRuns = Int(v.totalRuns)
        s.dailyDoneToday = todaysDaily(in: ctx)?.completed ?? false
        return s
    }

    static func ledgerTotals(in ctx: NSManagedObjectContext) -> LedgerTotals {
        var t = LedgerTotals()
        let all = runs(in: ctx, limit: 1000)
        t.runs = all.count
        guard !all.isEmpty else { return t }
        for r in all {
            if r.succeeded { t.casts += 1 }
            t.magmaCast += Int(r.moldsFilled)
            t.moldsFilled += Int(r.moldsFilled)
            t.crustsBlown += Int(r.crustsBlown)
            t.veinsCrusted += Int(r.veinsCrusted)
            t.bestScore = max(t.bestScore, Int(r.score))
            t.bestYield = max(t.bestYield, r.yield)
            t.timeUnderTheRim += r.durationSeconds
            if !r.succeeded {
                if r.peakPressure >= 0.99 { t.blowouts += 1 } else { t.chokes += 1 }
            }
        }
        t.averageYield = all.reduce(0) { $0 + $1.yield } / Double(all.count)
        return t
    }

    // MARK: - The vigil

    @discardableResult
    static func vigil(in ctx: NSManagedObjectContext) -> VigilEntity {
        let request = NSFetchRequest<VigilEntity>(entityName: "VigilEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        request.fetchLimit = 1
        if let existing = try? ctx.fetch(request).first { return existing }
        let v = VigilEntity(context: ctx)
        v.id = UUID()
        v.createdAt = Date()
        v.currentStreak = 0
        v.bestStreak = 0
        v.totalDays = 0
        v.totalRuns = 0
        ctx.saveChanges()
        return v
    }

    /// Counts one finished run against the vigil. A streak survives a missed day
    /// only if the last play was yesterday.
    @discardableResult
    static func registerPlay(in ctx: NSManagedObjectContext, on date: Date = Date()) -> Int {
        let v = vigil(in: ctx)
        v.totalRuns += 1

        let today = VentCatalog.dayKey(for: date)
        guard v.lastPlayDay != today else { return Int(v.currentStreak) }

        let yesterday = VentCatalog.dayKey(
            for: Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date)
        v.currentStreak = (v.lastPlayDay == yesterday) ? v.currentStreak + 1 : 1
        v.bestStreak = max(v.bestStreak, v.currentStreak)
        v.lastPlayDay = today
        v.totalDays += 1
        return Int(v.currentStreak)
    }

    // MARK: - The Daily Fissure

    static func todaysDaily(in ctx: NSManagedObjectContext,
                            on date: Date = Date()) -> DailyRunEntity? {
        daily(dayKey: VentCatalog.dayKey(for: date), in: ctx, createIfMissing: false)
    }

    @discardableResult
    static func daily(dayKey: String, in ctx: NSManagedObjectContext,
                      createIfMissing: Bool = true) -> DailyRunEntity? {
        let request = NSFetchRequest<DailyRunEntity>(entityName: "DailyRunEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "dayKey", ascending: false)]
        request.predicate = NSPredicate(format: "dayKey == %@", dayKey)
        request.fetchLimit = 1
        if let existing = try? ctx.fetch(request).first { return existing }
        guard createIfMissing else { return nil }

        let d = DailyRunEntity(context: ctx)
        d.id = UUID()
        d.createdAt = Date()
        d.dayKey = dayKey
        d.archetype = Int16(VentCatalog.dailyArchetype(dayKey))
        d.completed = false
        ctx.saveChanges()
        return d
    }

    /// The daily keeps only its best attempt, and can be retried all day.
    @discardableResult
    static func commitDaily(_ summary: RunSummary, dayKey: String,
                            in ctx: NSManagedObjectContext) -> CommitOutcome {
        var out = CommitOutcome()
        guard let d = daily(dayKey: dayKey, in: ctx) else { return out }
        d.attempts += 1
        if Int32(summary.score) > d.score {
            d.score = Int32(summary.score)
            d.yield = summary.yield
            d.stars = Int16(summary.stars)
            d.moldsFilled = Int16(summary.moldsFilled)
            out.isNewBest = summary.succeeded
        }
        if summary.succeeded && !d.completed {
            d.completed = true
            d.playedAt = Date()
        }

        writeRunRecord(summary, isDaily: true, in: ctx)
        out.streakAfter = registerPlay(in: ctx)
        out.newMarks = advanceMarks(for: summary, isDaily: true, in: ctx)
        ctx.saveChanges()
        return out
    }

    // MARK: - Write

    private static func writeRunRecord(_ summary: RunSummary, isDaily: Bool,
                                       in ctx: NSManagedObjectContext) {
        let record = RunRecordEntity(context: ctx)
        record.id = UUID()
        record.createdAt = Date()
        record.ventNumber = Int16(isDaily ? 0 : summary.ventNumber)
        record.riftIndex = Int16(summary.riftIndex)
        record.score = Int32(summary.score)
        record.yield = summary.yield
        record.peakPressure = summary.peakPressure
        record.veinsCrusted = Int16(summary.veinsCrusted)
        record.crustsBlown = Int16(summary.crustsBlown)
        record.moldsFilled = Int16(summary.moldsFilled)
        record.moldsCracked = Int16(summary.moldsCracked)
        record.starsEarned = Int16(summary.stars)
        record.succeeded = summary.succeeded
        record.durationSeconds = summary.duration
    }

    /// Writes the run record, updates the vent, unlocks what the run unlocked
    /// and advances every affected mark. One save.
    @discardableResult
    static func commit(_ summary: RunSummary, in ctx: NSManagedObjectContext) -> CommitOutcome {
        var out = CommitOutcome()
        let starsBefore = vents(in: ctx).reduce(0) { $0 + Int($1.starsEarned) }

        writeRunRecord(summary, isDaily: false, in: ctx)

        if let vent = vent(summary.ventNumber, in: ctx) {
            vent.attempts += 1
            if Int32(summary.score) > vent.bestScore {
                vent.bestScore = Int32(summary.score)
                out.isNewBest = summary.succeeded
            }
            vent.starsEarned = max(vent.starsEarned, Int16(summary.stars))
            vent.bestYield = max(vent.bestYield, summary.yield)
            vent.bestMoldsFilled = max(vent.bestMoldsFilled, Int16(summary.moldsFilled))
            if summary.succeeded && !vent.cleared {
                vent.cleared = true
                vent.clearedAt = Date()
            }
        }

        if summary.succeeded {
            // Next vent opens; a new rift needs seven of ten behind it.
            let next = summary.ventNumber + 1
            if next <= VentCatalog.ventCount, let nextVent = vent(next, in: ctx), !nextVent.unlocked {
                let nextRift = VentCatalog.riftIndex(forVent: next)
                if nextRift == summary.riftIndex {
                    nextVent.unlocked = true
                    out.unlockedVent = next
                } else {
                    let clearedInRift = vents(in: ctx)
                        .filter { Int($0.riftIndex) == summary.riftIndex && $0.cleared }.count
                    if clearedInRift >= 7 {
                        nextVent.unlocked = true
                        out.unlockedVent = next
                        if let rift = rifts(in: ctx).first(where: { Int($0.riftIndex) == nextRift }),
                           !rift.unlocked {
                            rift.unlocked = true
                            out.unlockedRift = nextRift
                        }
                    }
                }
            }

            if let spec = CastCatalog.spec(awardedBy: summary.ventNumber) {
                let needsThree = spec.key == "mountain_key"
                let qualifies = !needsThree || summary.stars >= 3
                if qualifies,
                   let cast = casts(in: ctx).first(where: { $0.castKey == spec.key }),
                   !cast.unlocked {
                    cast.unlocked = true
                    cast.earnedAt = Date()
                    cast.earnedStars = Int16(summary.stars)
                    cast.earnedYield = summary.yield
                    out.newCast = spec
                }
            }
        }

        out.streakAfter = registerPlay(in: ctx)
        out.newMarks = advanceMarks(for: summary, isDaily: false, in: ctx)

        let starsAfter = vents(in: ctx).reduce(0) { $0 + Int($1.starsEarned) }
        if RankCatalog.rank(forStars: starsAfter).title != RankCatalog.rank(forStars: starsBefore).title {
            out.newRank = RankCatalog.rank(forStars: starsAfter)
        }

        ctx.saveChanges()
        return out
    }

    // MARK: - Marks

    private static func advanceMarks(for summary: RunSummary, isDaily: Bool,
                                     in ctx: NSManagedObjectContext) -> [String] {
        let allMarks = marks(in: ctx)
        var freshlyEarned: [String] = []

        func bump(_ key: String, to value: Int) {
            guard let mark = allMarks.first(where: { $0.markKey == key }), !mark.earned else { return }
            let capped = Int32(min(value, Int(mark.target)))
            if capped > mark.progress { mark.progress = capped }
            if mark.progress >= mark.target {
                mark.earned = true
                mark.earnedAt = Date()
                freshlyEarned.append(mark.title ?? key)
            }
        }
        func add(_ key: String, delta: Int) {
            guard let mark = allMarks.first(where: { $0.markKey == key }), !mark.earned, delta > 0 else { return }
            bump(key, to: Int(mark.progress) + delta)
        }

        let allVents = vents(in: ctx)
        let v = vigil(in: ctx)

        bump("first_pour", to: summary.moldsFilled)
        bump("hundred_runs", to: Int(v.totalRuns))

        for rift in 1...VentCatalog.riftCount {
            let cleared = allVents.filter { Int($0.riftIndex) == rift && $0.cleared }.count
            bump("rift_\(rift)_cleared", to: cleared)
        }

        let deepestRift = allVents.filter { $0.unlocked }.map { Int($0.riftIndex) }.max() ?? 1
        for rift in 2...VentCatalog.riftCount where deepestRift >= rift {
            let names = ["", "", "reach_rift_two", "reach_rift_three", "reach_rift_four",
                         "reach_rift_five", "reach_rift_six"]
            bump(names[rift], to: 1)
        }

        bump("whole_mountain", to: allVents.filter { $0.cleared }.count)
        bump("stars_10", to: allVents.filter { $0.starsEarned >= 3 }.count)
        bump("stars_30", to: allVents.filter { $0.starsEarned >= 3 }.count)
        bump("stars_all", to: allVents.filter { $0.starsEarned >= 3 }.count)

        if summary.succeeded {
            bump("first_cast", to: 1)
            if summary.stars >= 3 { bump("three_stars", to: 1) }
            if summary.reopenCount == 0 { bump("never_shut_twice", to: 1) }
            if summary.veinsCrusted == 0 { bump("cold_hands", to: 1) }
            if summary.peakPressure >= 0.90 { bump("redline_nerve", to: 1) }
            if summary.peakPressure <= 0.60 { bump("steady_hand", to: 1) }
            if summary.yield >= 0.999 { bump("perfect_pour", to: 1) }
            if summary.yield >= 0.90 { add("nothing_wasted", delta: 1) }
            if summary.moldsCracked == 0 { add("unbroken", delta: 1) }
            if summary.moldsFilled >= 6 { bump("wide_rim", to: 1) }
            if summary.tremorsSurvived >= 3 { bump("tremor_proof", to: 1) }
            if summary.score >= 10_000 { bump("deep_cast", to: 1) }
            if summary.score >= 20_000 { bump("deeper_cast", to: 1) }
            if summary.riftIndex >= 6 && summary.crustsBlown == 0 { bump("no_help", to: 1) }
            if isDaily { bump("daily_first", to: 1) }
        }

        if summary.crustsBlown > 0 {
            bump("first_crust", to: 1)
            add("crustbreaker", delta: summary.crustsBlown)
        }
        if summary.gasPocketsRidden > 0 && summary.moldsCracked == 0 {
            add("gas_handler", delta: summary.gasPocketsRidden)
        }

        let unlockedCasts = casts(in: ctx).filter { $0.unlocked }.count
        bump("vault_10", to: unlockedCasts)
        bump("vault_half", to: unlockedCasts)
        bump("vault_full", to: unlockedCasts)

        bump("daily_seven", to: Int(v.currentStreak))
        bump("daily_thirty", to: Int(v.currentStreak))

        return freshlyEarned
    }
}
