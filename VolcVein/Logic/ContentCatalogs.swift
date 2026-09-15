import Foundation

// The written content of the game: six rifts, thirty obsidian casts, forty
// struck marks and the rank ladder. Seeded into Core Data on first launch.

struct RiftSpec {
    let index: Int
    let name: String
    let subtitle: String
    /// Roman numeral used on the map dividers.
    let numeral: String
}

enum RiftCatalog {
    static let all: [RiftSpec] = [
        RiftSpec(index: 1, name: "Emberfoot",
                 subtitle: "Where the mountain still forgives you",
                 numeral: "I"),
        RiftSpec(index: 2, name: "Cinder Steps",
                 subtitle: "Gas pockets in the lower stair",
                 numeral: "II"),
        RiftSpec(index: 3, name: "Ashfall Reach",
                 subtitle: "The rock shifts while you work",
                 numeral: "III"),
        RiftSpec(index: 4, name: "Throat of the Mountain",
                 subtitle: "Two chambers, one gauge, no slack",
                 numeral: "IV"),
        RiftSpec(index: 5, name: "Glass Gallery",
                 subtitle: "Five brittle molds at the end of a long fall",
                 numeral: "V"),
        RiftSpec(index: 6, name: "The Last Vent",
                 subtitle: "Three chambers and everything the rock knows",
                 numeral: "VI"),
    ]

    static func spec(_ index: Int) -> RiftSpec {
        all[min(max(index, 1), all.count) - 1]
    }

    static func name(_ index: Int) -> String { spec(index).name }
    static func numeral(_ index: Int) -> String { spec(index).numeral }

    /// The wrinkle the rift introduces, written once and used by both the vent
    /// brief and the rift dossier.
    static func wrinkle(_ index: Int) -> String {
        switch index {
        case 1:
            return "A clean split starves both molds. Shut one branch, fill the other, and get back before the crust sets. Everything the mountain does later is a variation on that one decision."
        case 2:
            return "Gas pockets. A marked segment doubles the chamber's output the first time magma runs through it, and the surge has to land somewhere — so keep a branch open for it before you trip one."
        case 3:
            return "The rock shifts here. Every tremor crusts an open branch without warning, and a crusted branch only comes back if you press and hold it open at the cost of pressure."
        case 4:
            return "Two chambers, feeding two trunks at two different rates, sharing one gauge. Whichever trunk you neglect is the one that backs up — and a blocked trunk drains nothing at all."
        case 5:
            return "Five brittle molds at the end of a long fall. Flow has to be steered a long way before it lands, and concentrating too hard cracks whatever it lands in."
        default:
            return "Three chambers and every wrinkle the mountain knows, at once. Leave a way out open at all times — there is no run here that survives a fully blocked junction."
        }
    }
}

struct CastSpec {
    let key: String
    let order: Int
    let name: String
    let story: String
    let asset: String
    let awardVent: Int
}

enum CastCatalog {
    static let all: [CastSpec] = [
        CastSpec(key: "emberdrop", order: 1, name: "Emberdrop",
                 story: "The first shape the mountain ever handed you — a single bead of cooled magma, still warm at the core.",
                 asset: "cast_emberdrop", awardVent: 2),
        CastSpec(key: "twin_vane", order: 2, name: "Twin Vane",
                 story: "Two blades pulled from one split, cast the run you first learned to starve a branch on purpose.",
                 asset: "cast_twinvane", awardVent: 4),
        CastSpec(key: "sulfur_knot", order: 3, name: "Sulfur Knot",
                 story: "A knot of black glass with a sulfur heart trapped inside it, still faintly warm to hold.",
                 asset: "cast_sulfurknot", awardVent: 6),
        CastSpec(key: "bridle", order: 4, name: "Bridle",
                 story: "Named for the way it fits the hand, as if the rift meant for you to lead it somewhere.",
                 asset: "cast_bridleshard", awardVent: 8),
        CastSpec(key: "emberfoot_seal", order: 5, name: "Emberfoot Seal",
                 story: "Emberfoot's parting gift, pressed flat by the weight of the rock above it.",
                 asset: "cast_crownfracture", awardVent: 10),
        CastSpec(key: "crownfracture", order: 6, name: "Crownfracture",
                 story: "Three spires off one base — what a gas pocket leaves behind when you ride it instead of fighting it.",
                 asset: "cast_crownfracture", awardVent: 12),
        CastSpec(key: "gutterspine", order: 7, name: "Gutterspine",
                 story: "A long ridged shard from the bottom of the Cinder Steps, ribbed where the flow kept changing its mind.",
                 asset: "cast_bridleshard", awardVent: 14),
        CastSpec(key: "ashglass_lens", order: 8, name: "Ashglass Lens",
                 story: "Clear enough to look through, if you are willing to hold volcanic glass up to a sulfur sky.",
                 asset: "cast_sulfurknot", awardVent: 16),
        CastSpec(key: "cinder_tooth", order: 9, name: "Cinder Tooth",
                 story: "Single, curved and far sharper than a thing made of cooled rock has any business being.",
                 asset: "cast_emberdrop", awardVent: 18),
        CastSpec(key: "step_key", order: 10, name: "The Step Key",
                 story: "Closes the Cinder Steps. The teeth match no lock anyone has found yet.",
                 asset: "cast_twinvane", awardVent: 20),
        CastSpec(key: "riftcomb", order: 11, name: "Riftcomb",
                 story: "Every tooth is a branch you kept open while the ground shook underneath the whole reach.",
                 asset: "cast_crownfracture", awardVent: 22),
        CastSpec(key: "black_pennant", order: 12, name: "Black Pennant",
                 story: "Thin, flat and sharp — what you get from a run that never once backed up.",
                 asset: "cast_twinvane", awardVent: 24),
        CastSpec(key: "tremorglass", order: 13, name: "Tremorglass",
                 story: "Cast mid-tremor. The ripples in it are a record of the exact second the rock moved.",
                 asset: "cast_sulfurknot", awardVent: 26),
        CastSpec(key: "ashfall_bead", order: 14, name: "Ashfall Bead",
                 story: "Small, perfectly round, and heavier than it looks. Ashfall Reach makes nothing by accident.",
                 asset: "cast_emberdrop", awardVent: 28),
        CastSpec(key: "reach_seal", order: 15, name: "Reach Seal",
                 story: "The Reach signs its work. This is the signature.",
                 asset: "cast_bridleshard", awardVent: 30),
        CastSpec(key: "chokestone", order: 16, name: "Chokestone",
                 story: "Cast from a chamber that came within a breath of blowing, and cooled instead.",
                 asset: "cast_emberdrop", awardVent: 32),
        CastSpec(key: "twin_draught", order: 17, name: "Twin Draught",
                 story: "Two chambers poured into one mold at two different speeds. The seam never quite closed.",
                 asset: "cast_twinvane", awardVent: 34),
        CastSpec(key: "ninefold_shard", order: 18, name: "Ninefold Shard",
                 story: "Nine facets, one per branch you had to hold open at the same time to get it.",
                 asset: "cast_sulfurknot", awardVent: 36),
        CastSpec(key: "gauge_stone", order: 19, name: "Gauge Stone",
                 story: "It reads like a pressure column frozen mid-climb, which is more or less what it is.",
                 asset: "cast_crownfracture", awardVent: 38),
        CastSpec(key: "throat_key", order: 20, name: "The Throat Key",
                 story: "Closes the Throat of the Mountain. Cold on one side, still warm on the other.",
                 asset: "cast_bridleshard", awardVent: 40),
        CastSpec(key: "gallery_pane", order: 21, name: "Gallery Pane",
                 story: "Flat as poured water and just as easy to break. The Glass Gallery names itself.",
                 asset: "cast_sulfurknot", awardVent: 42),
        CastSpec(key: "brittle_crown", order: 22, name: "Brittle Crown",
                 story: "Five points, one per mold, and not one of them thicker than a fingernail.",
                 asset: "cast_crownfracture", awardVent: 44),
        CastSpec(key: "long_fall", order: 23, name: "The Long Fall",
                 story: "Drawn out and tapered — the shape magma takes when it has a very long way to travel.",
                 asset: "cast_bridleshard", awardVent: 46),
        CastSpec(key: "cold_lantern", order: 24, name: "Cold Lantern",
                 story: "Hollow, and it rings when you tap it. Whatever was inside cooled and left.",
                 asset: "cast_emberdrop", awardVent: 48),
        CastSpec(key: "gallery_seal", order: 25, name: "Gallery Seal",
                 story: "The Gallery's last piece, and the only one in it that will survive being dropped.",
                 asset: "cast_twinvane", awardVent: 50),
        CastSpec(key: "three_mouths", order: 26, name: "Three Mouths",
                 story: "Three chambers fed this one. You can see all three seams if you turn it to the light.",
                 asset: "cast_crownfracture", awardVent: 52),
        CastSpec(key: "deadweight", order: 27, name: "Deadweight",
                 story: "Cast from magma that had nowhere to go until you gave it somewhere. Heavier than the rest.",
                 asset: "cast_emberdrop", awardVent: 54),
        CastSpec(key: "last_bridle", order: 28, name: "Last Bridle",
                 story: "The same shape as the Bridle you pulled in Emberfoot, and four times the size.",
                 asset: "cast_bridleshard", awardVent: 56),
        CastSpec(key: "sixfold", order: 29, name: "Sixfold",
                 story: "Six molds, six facets, one run. There is no wider vent in the mountain.",
                 asset: "cast_sulfurknot", awardVent: 58),
        CastSpec(key: "mountain_key", order: 30, name: "The Mountain Key",
                 story: "The last piece the mountain has. Three stars on the final vent, or nothing at all.",
                 asset: "cast_twinvane", awardVent: 60),
    ]

    static func spec(awardedBy vent: Int) -> CastSpec? {
        all.first { $0.awardVent == vent }
    }

    static func spec(key: String?) -> CastSpec? {
        guard let key else { return nil }
        return all.first { $0.key == key }
    }

    /// What the vault plate shows while a piece is still locked.
    static func requirement(for spec: CastSpec) -> String {
        spec.key == "mountain_key" ? "Vent 60 · 3★" : "Vent \(spec.awardVent)"
    }
}

struct MarkSpec {
    let key: String
    let order: Int
    let title: String
    let detail: String
    let asset: String
    let target: Int
}

enum MarkCatalog {
    static let all: [MarkSpec] = [
        // — Tier 1: the first hour —
        MarkSpec(key: "first_pour", order: 1, title: "First Pour",
                 detail: "Fill your first rim mold.", asset: "mark_first_cast", target: 1),
        MarkSpec(key: "first_cast", order: 2, title: "First Cast",
                 detail: "Clear your first vent outright.", asset: "mark_first_cast", target: 1),
        MarkSpec(key: "three_stars", order: 3, title: "Three Stars",
                 detail: "Earn three cast stars on any vent.", asset: "mark_first_cast", target: 1),
        MarkSpec(key: "never_shut_twice", order: 4, title: "Never Shut Twice",
                 detail: "Clear a vent without reopening a vein.", asset: "mark_dry_run", target: 1),
        MarkSpec(key: "cold_hands", order: 5, title: "Cold Hands",
                 detail: "Cast a vent with zero veins crusted shut.", asset: "mark_crustbreaker", target: 1),
        MarkSpec(key: "first_crust", order: 6, title: "Crust Broken",
                 detail: "Blow open your first crusted vein.", asset: "mark_crustbreaker", target: 1),

        // — Tier 2: the rifts —
        MarkSpec(key: "rift_1_cleared", order: 7, title: "Emberfoot Cleared",
                 detail: "Clear all ten Rift I vents.", asset: "mark_first_cast", target: 10),
        MarkSpec(key: "rift_2_cleared", order: 8, title: "Cinder Steps Cleared",
                 detail: "Clear all ten Rift II vents.", asset: "mark_dry_run", target: 10),
        MarkSpec(key: "rift_3_cleared", order: 9, title: "Ashfall Reach Cleared",
                 detail: "Clear all ten Rift III vents.", asset: "mark_deep_rift", target: 10),
        MarkSpec(key: "rift_4_cleared", order: 10, title: "The Throat Cleared",
                 detail: "Clear all ten Rift IV vents.", asset: "mark_deep_rift", target: 10),
        MarkSpec(key: "rift_5_cleared", order: 11, title: "Glass Gallery Cleared",
                 detail: "Clear all ten Rift V vents.", asset: "mark_full_yield", target: 10),
        MarkSpec(key: "rift_6_cleared", order: 12, title: "The Last Vent Cleared",
                 detail: "Clear all ten Rift VI vents.", asset: "mark_deep_rift", target: 10),

        // — Tier 3: depth —
        MarkSpec(key: "reach_rift_two", order: 13, title: "Into The Steps",
                 detail: "Reach Rift II.", asset: "mark_deep_rift", target: 1),
        MarkSpec(key: "reach_rift_three", order: 14, title: "Into The Reach",
                 detail: "Reach Rift III.", asset: "mark_deep_rift", target: 1),
        MarkSpec(key: "reach_rift_four", order: 15, title: "Into The Throat",
                 detail: "Reach Rift IV.", asset: "mark_deep_rift", target: 1),
        MarkSpec(key: "reach_rift_five", order: 16, title: "Into The Gallery",
                 detail: "Reach Rift V.", asset: "mark_deep_rift", target: 1),
        MarkSpec(key: "reach_rift_six", order: 17, title: "The Last Vent",
                 detail: "Reach Rift VI.", asset: "mark_deep_rift", target: 1),
        MarkSpec(key: "whole_mountain", order: 18, title: "The Whole Mountain",
                 detail: "Clear all sixty vents.", asset: "mark_deep_rift", target: 60),

        // — Tier 4: craft —
        MarkSpec(key: "nothing_wasted", order: 19, title: "Nothing Wasted",
                 detail: "Cast ten vents at 90% yield or better.", asset: "mark_full_yield", target: 10),
        MarkSpec(key: "perfect_pour", order: 20, title: "Perfect Pour",
                 detail: "Cast a vent at 100% yield.", asset: "mark_full_yield", target: 1),
        MarkSpec(key: "redline_nerve", order: 21, title: "Redline Nerve",
                 detail: "Cast a vent after peaking above 90% pressure.", asset: "mark_redline", target: 1),
        MarkSpec(key: "steady_hand", order: 22, title: "Steady Hand",
                 detail: "Cast a vent that never went above 60% pressure.", asset: "mark_redline", target: 1),
        MarkSpec(key: "crustbreaker", order: 23, title: "Crustbreaker",
                 detail: "Blow open 50 crusted veins.", asset: "mark_crustbreaker", target: 50),
        MarkSpec(key: "gas_handler", order: 24, title: "Gas Handler",
                 detail: "Ride 40 gas pockets without cracking a mold.", asset: "mark_redline", target: 40),
        MarkSpec(key: "tremor_proof", order: 25, title: "Tremor Proof",
                 detail: "Cast a vent that threw three tremors at you.", asset: "mark_redline", target: 1),
        MarkSpec(key: "unbroken", order: 26, title: "Unbroken",
                 detail: "Cast twenty vents without cracking a single mold.", asset: "mark_full_yield", target: 20),
        MarkSpec(key: "wide_rim", order: 27, title: "Wide Rim",
                 detail: "Fill six rim molds in one run.", asset: "mark_first_cast", target: 1),
        MarkSpec(key: "no_help", order: 28, title: "No Help Needed",
                 detail: "Cast a Rift VI vent without blowing a single crust.", asset: "mark_dry_run", target: 1),

        // — Tier 5: stars and score —
        MarkSpec(key: "stars_10", order: 29, title: "Ten Stars",
                 detail: "Earn three cast stars on ten vents.", asset: "mark_full_yield", target: 10),
        MarkSpec(key: "stars_30", order: 30, title: "Thirty Stars",
                 detail: "Earn three cast stars on thirty vents.", asset: "mark_full_yield", target: 30),
        MarkSpec(key: "stars_all", order: 31, title: "Every Star",
                 detail: "Earn three cast stars on all sixty vents.", asset: "mark_full_yield", target: 60),
        MarkSpec(key: "deep_cast", order: 32, title: "Deep Cast",
                 detail: "Score 10,000 on a single vent.", asset: "mark_redline", target: 1),
        MarkSpec(key: "deeper_cast", order: 33, title: "Deeper Cast",
                 detail: "Score 20,000 on a single vent.", asset: "mark_redline", target: 1),

        // — Tier 6: the vault —
        MarkSpec(key: "vault_10", order: 34, title: "Ten In The Vault",
                 detail: "Unlock ten obsidian casts.", asset: "mark_first_cast", target: 10),
        MarkSpec(key: "vault_half", order: 35, title: "Half The Vault",
                 detail: "Unlock fifteen obsidian casts.", asset: "mark_full_yield", target: 15),
        MarkSpec(key: "vault_full", order: 36, title: "Full Vault",
                 detail: "Unlock all thirty obsidian casts.", asset: "mark_full_yield", target: 30),

        // — Tier 7: the vigil —
        MarkSpec(key: "daily_first", order: 37, title: "First Vigil",
                 detail: "Cast the Daily Fissure once.", asset: "mark_dry_run", target: 1),
        MarkSpec(key: "daily_seven", order: 38, title: "Seven Nights",
                 detail: "Keep a seven day vigil streak.", asset: "mark_dry_run", target: 7),
        MarkSpec(key: "daily_thirty", order: 39, title: "A Month At The Rim",
                 detail: "Keep a thirty day vigil streak.", asset: "mark_deep_rift", target: 30),
        MarkSpec(key: "hundred_runs", order: 40, title: "A Hundred Descents",
                 detail: "Finish one hundred runs, cast or not.", asset: "mark_crustbreaker", target: 100),
    ]
}

/// The rank ladder — a title that comes from total cast stars, so it moves even
/// on runs that do not unlock anything.
struct RankSpec {
    let title: String
    let starsRequired: Int
}

enum RankCatalog {
    static let all: [RankSpec] = [
        RankSpec(title: "Ash-hand", starsRequired: 0),
        RankSpec(title: "Vent Tender", starsRequired: 8),
        RankSpec(title: "Valvewright", starsRequired: 22),
        RankSpec(title: "Flow Reader", starsRequired: 40),
        RankSpec(title: "Crustbreaker", starsRequired: 62),
        RankSpec(title: "Moldmaster", starsRequired: 88),
        RankSpec(title: "Riftwarden", starsRequired: 118),
        RankSpec(title: "Mountainwright", starsRequired: 152),
        RankSpec(title: "Keeper Of The Last Vent", starsRequired: 180),
    ]

    static func rank(forStars stars: Int) -> RankSpec {
        all.last { stars >= $0.starsRequired } ?? all[0]
    }

    /// The next title and how many stars are still owed, or nil at the top.
    static func next(afterStars stars: Int) -> (RankSpec, Int)? {
        guard let next = all.first(where: { stars < $0.starsRequired }) else { return nil }
        return (next, next.starsRequired - stars)
    }
}

/// Rotating one-liners on the gameplay hint strip.
enum VentHints {
    static let all: [String] = [
        "Tap a valve to shut it · hold to blow a crust",
        "Shut branches cool — reopen before they seal",
        "A 50/50 split starves both molds · concentrate",
        "Blowing a crust vents pressure as well as rock",
        "Overflow into a finished mold is wasted yield",
        "A dead-end vent bleeds pressure but casts nothing",
        "Never block a junction completely · magma backs up with nowhere to drain",
        "Tremors crust an open branch without asking · keep a spare",
        "A gas pocket doubles the chamber for a moment · have somewhere for it",
        "Molds crack if you funnel everything into one of them",
        "Sealed rim? Hold a crusted valve before the run runs out",
        "Yield is what you did not spill · it buys the second star",
    ]

    static func hint(for ventNumber: Int) -> String {
        all[abs(ventNumber - 1) % all.count]
    }
}
