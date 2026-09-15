import CoreData
import Foundation

/// First-launch seeding, plus the separate screenshot-tour path. A normal
/// launch never runs the tour code.
enum Seeder {

    // MARK: - Preferences

    @discardableResult
    static func preferences(in ctx: NSManagedObjectContext) -> PreferenceEntity {
        let request = NSFetchRequest<PreferenceEntity>(entityName: "PreferenceEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        request.fetchLimit = 1
        if let existing = try? ctx.fetch(request).first { return existing }

        let prefs = PreferenceEntity(context: ctx)
        prefs.id = UUID()
        prefs.createdAt = Date()
        prefs.hapticsOn = true
        prefs.animationsOn = true
        prefs.firstLaunchCompleted = false
        ctx.saveChanges()
        return prefs
    }

    // MARK: - Domain content

    /// Creates the rifts, vents, casts and marks if they are absent, and tops up
    /// an older store that was seeded when the mountain was smaller.
    static func seedDomainIfNeeded(in ctx: NSManagedObjectContext) {
        let request = NSFetchRequest<VentProgressEntity>(entityName: "VentProgressEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "ventNumber", ascending: true)]
        let existing = (try? ctx.count(for: request)) ?? 0
        if existing == 0 {
            seedDomain(in: ctx)
        } else if existing < VentCatalog.ventCount {
            topUpDomain(in: ctx)
        }
        ProgressStore.vigil(in: ctx)
    }

    static func seedDomain(in ctx: NSManagedObjectContext) {
        let now = Date()

        var riftsByIndex: [Int: RiftEntity] = [:]
        for spec in RiftCatalog.all {
            let rift = RiftEntity(context: ctx)
            rift.id = UUID()
            rift.createdAt = now
            rift.riftIndex = Int16(spec.index)
            rift.name = spec.name
            rift.subtitle = spec.subtitle
            rift.ventCount = Int16(VentCatalog.ventsPerRift)
            rift.unlocked = spec.index == 1
            riftsByIndex[spec.index] = rift
        }

        for vent in 1...VentCatalog.ventCount {
            let entity = VentProgressEntity(context: ctx)
            entity.id = UUID()
            entity.createdAt = now
            entity.ventNumber = Int16(vent)
            let riftIndex = VentCatalog.riftIndex(forVent: vent)
            entity.riftIndex = Int16(riftIndex)
            entity.unlocked = vent == 1
            entity.cleared = false
            entity.rift = riftsByIndex[riftIndex]
        }

        for spec in CastCatalog.all { makeCast(spec, at: now, in: ctx) }
        for spec in MarkCatalog.all { makeMark(spec, at: now, in: ctx) }

        ProgressStore.vigil(in: ctx)
        ctx.saveChanges()
    }

    /// Adds whatever the catalogs gained since this store was first written,
    /// without disturbing anything the player already earned.
    private static func topUpDomain(in ctx: NSManagedObjectContext) {
        let now = Date()

        var riftsByIndex: [Int: RiftEntity] = [:]
        let existingRifts = ProgressStore.rifts(in: ctx)
        for rift in existingRifts {
            rift.ventCount = Int16(VentCatalog.ventsPerRift)
            riftsByIndex[Int(rift.riftIndex)] = rift
        }
        for spec in RiftCatalog.all where riftsByIndex[spec.index] == nil {
            let rift = RiftEntity(context: ctx)
            rift.id = UUID()
            rift.createdAt = now
            rift.riftIndex = Int16(spec.index)
            rift.name = spec.name
            rift.subtitle = spec.subtitle
            rift.ventCount = Int16(VentCatalog.ventsPerRift)
            rift.unlocked = false
            riftsByIndex[spec.index] = rift
        }

        let haveVents = Set(ProgressStore.vents(in: ctx).map { Int($0.ventNumber) })
        for vent in 1...VentCatalog.ventCount where !haveVents.contains(vent) {
            let entity = VentProgressEntity(context: ctx)
            entity.id = UUID()
            entity.createdAt = now
            entity.ventNumber = Int16(vent)
            let riftIndex = VentCatalog.riftIndex(forVent: vent)
            entity.riftIndex = Int16(riftIndex)
            entity.unlocked = false
            entity.cleared = false
            entity.rift = riftsByIndex[riftIndex]
        }

        let haveCasts = Set(ProgressStore.casts(in: ctx).compactMap(\.castKey))
        for spec in CastCatalog.all where !haveCasts.contains(spec.key) {
            makeCast(spec, at: now, in: ctx)
        }

        let haveMarks = Set(ProgressStore.marks(in: ctx).compactMap(\.markKey))
        for spec in MarkCatalog.all where !haveMarks.contains(spec.key) {
            makeMark(spec, at: now, in: ctx)
        }

        ctx.saveChanges()
    }

    private static func makeCast(_ spec: CastSpec, at now: Date, in ctx: NSManagedObjectContext) {
        let cast = CastEntity(context: ctx)
        cast.id = UUID()
        cast.createdAt = now
        cast.castKey = spec.key
        cast.orderIndex = Int16(spec.order)
        cast.name = spec.name
        cast.story = spec.story
        cast.assetName = spec.asset
        cast.awardVent = Int16(spec.awardVent)
        cast.unlocked = false
    }

    private static func makeMark(_ spec: MarkSpec, at now: Date, in ctx: NSManagedObjectContext) {
        let mark = MarkEntity(context: ctx)
        mark.id = UUID()
        mark.createdAt = now
        mark.markKey = spec.key
        mark.orderIndex = Int16(spec.order)
        mark.title = spec.title
        mark.detail = spec.detail
        mark.assetName = spec.asset
        mark.target = Int32(spec.target)
        mark.progress = 0
        mark.earned = false
    }

    // MARK: - Reset

    static func wipeDomain(in ctx: NSManagedObjectContext) {
        for name in ["VentProgressEntity", "CastEntity", "MarkEntity", "RiftEntity",
                     "RunRecordEntity", "DailyRunEntity", "VigilEntity"] {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            if let rows = try? ctx.fetch(request) as? [NSManagedObject] {
                rows.forEach(ctx.delete)
            }
        }
        ctx.saveChanges()
    }

    /// Confirmed reset: wipe, re-seed, and drop back to onboarding — never a
    /// blank screen.
    static func resetProgress(in ctx: NSManagedObjectContext) {
        wipeDomain(in: ctx)
        seedDomain(in: ctx)
        let prefs = preferences(in: ctx)
        prefs.firstLaunchCompleted = false
        ctx.saveChanges()
    }

    // MARK: - Screenshot tour

    /// Separate path used only under `-screenshotTour`: a mountain that has been
    /// worked for weeks, so every screen shows a living product.
    static func seedTourProgress(in ctx: NSManagedObjectContext) {
        wipeDomain(in: ctx)
        seedDomain(in: ctx)

        let now = Date()
        let clearedThrough = 27          // deep into Rift III
        let unlockedThrough = 28

        let vents = ProgressStore.vents(in: ctx)
        for vent in vents {
            let n = Int(vent.ventNumber)
            guard n <= unlockedThrough else { continue }
            vent.unlocked = true
            guard n <= clearedThrough else { continue }
            vent.cleared = true
            // A believable spread: mostly two, a run of threes, the odd one.
            let stars: Int16 = [3, 3, 2, 3, 2, 3, 2, 2, 3, 1][n % 10]
            vent.starsEarned = stars
            vent.bestScore = Int32(1_640 + n * 214 + (n % 5) * 180)
            vent.bestYield = min(1.0, 0.82 + Double((n * 7) % 16) * 0.011)
            vent.bestMoldsFilled = Int16(VentCatalog.layout(for: n).moldCount)
            vent.attempts = Int32(1 + (n % 4))
            vent.clearedAt = now.addingTimeInterval(-Double(unlockedThrough - n) * 5_400)
        }

        for rift in ProgressStore.rifts(in: ctx) where rift.riftIndex <= 3 {
            rift.unlocked = true
        }

        // Casts follow the cleared vents: everything awarded at or below 27.
        for cast in ProgressStore.casts(in: ctx) where Int(cast.awardVent) <= clearedThrough {
            cast.unlocked = true
            cast.earnedAt = now.addingTimeInterval(-Double(clearedThrough - Int(cast.awardVent)) * 6_200)
            cast.earnedStars = Int16([3, 2, 3, 2][Int(cast.orderIndex) % 4])
            cast.earnedYield = min(1.0, 0.86 + Double(Int(cast.orderIndex) % 9) * 0.014)
        }

        let vigil = ProgressStore.vigil(in: ctx)
        vigil.currentStreak = 9
        vigil.bestStreak = 14
        vigil.totalDays = 31
        vigil.lastPlayDay = VentCatalog.dayKey(for: now)

        // Run history — enough for the Ledger to look lived-in.
        var runIndex = 0
        for n in 1...clearedThrough {
            let attempts = 1 + (n % 3)
            for a in 0..<attempts {
                let succeeded = a == attempts - 1
                let record = RunRecordEntity(context: ctx)
                record.id = UUID()
                record.createdAt = now.addingTimeInterval(-Double(240 - runIndex) * 1_850)
                record.ventNumber = Int16(n)
                record.riftIndex = Int16(VentCatalog.riftIndex(forVent: n))
                record.score = Int32(succeeded ? 1_640 + n * 214 : 320 + n * 46)
                record.yield = succeeded ? min(1.0, 0.82 + Double((n * 7) % 16) * 0.011) : 0.48 + Double(n % 5) * 0.05
                // Failures split between blowouts and chokes so the Ledger's
                // breakdown is not one-sided.
                record.peakPressure = succeeded
                    ? 0.58 + Double(n % 6) * 0.055
                    : (n % 2 == 0 ? 1.0 : 0.62 + Double(n % 4) * 0.05)
                record.veinsCrusted = Int16(n % 3)
                record.crustsBlown = Int16((n + a) % 4)
                record.moldsFilled = Int16(succeeded ? VentCatalog.layout(for: n).moldCount : max(0, n % 3))
                record.moldsCracked = Int16(succeeded ? 0 : 1)
                record.starsEarned = Int16(succeeded ? [3, 3, 2, 3, 2, 3, 2, 2, 3, 1][n % 10] : 0)
                record.succeeded = succeeded
                record.durationSeconds = 52 + Double(n) * 1.4 + Double(a) * 6
                runIndex += 1
            }
        }
        vigil.totalRuns = Int32(runIndex)

        // Three weeks of dailies, with a few misses so the strip reads real.
        for back in 0..<21 {
            let date = Calendar.current.date(byAdding: .day, value: -back, to: now) ?? now
            let key = VentCatalog.dayKey(for: date)
            guard back != 4 && back != 11 && back != 16 else { continue }   // the missed days
            guard let daily = ProgressStore.daily(dayKey: key, in: ctx) else { continue }
            daily.completed = true
            daily.playedAt = date
            daily.attempts = Int32(1 + back % 3)
            daily.score = Int32(3_100 + back * 137)
            daily.stars = Int16([3, 2, 2, 3, 1][back % 5])
            daily.yield = min(1.0, 0.84 + Double(back % 7) * 0.018)
            daily.moldsFilled = 4
        }

        // Marks, advanced to match everything above.
        let marks = ProgressStore.marks(in: ctx)
        let earnedKeys: Set<String> = [
            "first_pour", "first_cast", "three_stars", "never_shut_twice", "cold_hands",
            "first_crust", "rift_1_cleared", "rift_2_cleared", "reach_rift_two",
            "reach_rift_three", "redline_nerve", "perfect_pour", "vault_10",
            "daily_first", "daily_seven", "steady_hand",
        ]
        for mark in marks {
            guard let key = mark.markKey else { continue }
            if earnedKeys.contains(key) {
                mark.earned = true
                mark.progress = mark.target
                mark.earnedAt = now.addingTimeInterval(-Double(mark.orderIndex) * 4_100)
            } else {
                mark.progress = Int32(Double(mark.target) * (0.25 + Double(Int(mark.orderIndex) % 5) * 0.13))
                mark.progress = min(mark.progress, max(0, mark.target - 1))
            }
        }

        let prefs = preferences(in: ctx)
        prefs.firstLaunchCompleted = true
        prefs.hapticsOn = true
        prefs.animationsOn = true

        ctx.saveChanges()
    }
}
