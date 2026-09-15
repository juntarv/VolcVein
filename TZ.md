**Concept:** VolcVein is an offline one-thumb puzzle-arcade game where you tap stone valves to shut branches of a volcano's magma vein network — you can never push or aim the magma, only decide where it cannot go — forcing rising chamber pressure into the rim molds you need to fill, while every branch you keep shut cools and crusts over for good.

---

## 1 · The mechanic

A volcano is drawn in cross-section. Magma rises out of a chamber at the bottom and climbs a **branching vein network** to a handful of **rim molds** at the crater edge. The player has exactly one verb.

**Tap a valve → that branch shuts.** The magma does not stop; it has to go somewhere, so all of it redistributes down the branches you left open. You never aim, drag, pour, or shoot. You sculpt the *negative space* and physics does the rest.

Three forces make that one verb into a game:

1. **Pressure rises continuously.** The chamber fills a gauge. Shut too much and it redlines → blowout, run over. Shut too little and the flow spreads too thin to fill anything before the level timer of rising pressure runs out.
2. **Shut veins cool.** A closed branch dims from magma to warm rock, and after `crustSeconds` it turns obsidian teal and **seals permanently**. You can **press and hold** a crusted valve to blow the crust out — but that vents a chunk of chamber pressure, which is sometimes exactly what you wanted and sometimes fatal.
3. **Molds have a tolerance band.** Each rim mold wants a target volume delivered inside a flow-rate window. Too much flow at once cracks it (lose the mold, lose yield). Too little for too long and the magma in it sets solid (mold is dead). So concentrating flow is both the only way to fill fast and the main way to lose.

Clear every mold on a vent and the rift **casts an obsidian piece** into your vault.

Scoring: `moldsFilled × 250 + yieldPercent × 6 + unusedPressureBonus − crackedMoldPenalty`, with a speed multiplier. Three **cast stars** per vent: (1) all molds filled, (2) yield ≥ 90%, (3) no vein crusted permanently.

---

## 2 · Screens

| # | Screen | Purpose |
|---|---|---|
| 1 | **Onboarding** (2 pages) | First-launch hook and the three rules. Sets `firstLaunchCompleted`. Skippable. |
| 2 | **Caldera** (main menu) | The home scene — the mountain itself. Launch point for everything; carries lifetime stats. |
| 3 | **Rift Map** | Level select: 24 vent nodes on a climbing vein, grouped into 4 rifts, with per-vent stars. |
| 4 | **Vent** (gameplay) | The single `SKScene` plus SwiftUI HUD. Where the game is played. |
| 5 | **Pause** (overlay on Vent) | Freeze, inspect mold and pressure state, resume / restart / leave. |
| 6 | **Cast Result** (overlay on Vent) | Win or loss verdict, obsidian cast reveal, star award, run ledger, next action. |
| 7 | **Vent Brief** (overlay on the map) | Pre-descent briefing: a live diagram of the vein graph, the vent's wrinkles, your best and the piece it casts. |
| 8 | **Obsidian Casts** (vault) | The 30-piece collection on six strata shelves, one per rift. |
| 9 | **Cast Detail** (overlay on the vault) | One piece at full size with its story, provenance and a route back into the vent that casts it. |
| 10 | **The Ledger** | Lifetime totals, the vigil streak, the rank ladder and the run-by-run history. |
| 11 | **Struck Marks** | The 40 achievements as marks on the caldera wall, grouped into seven tiers. |
| 12 | **The Valve House** (settings) | Haptics, Motion, where-you-stand figures, a how-it-works recap, Reset Progress. |
| — | **SplashView** | Mandatory dormant loader screen. Compiles, referenced from nowhere. |

Design references: `design/onboarding.png`, `design/onboarding-mechanic.png`, `design/menu.png`, `design/riftmap.png`, `design/gameplay.png`, `design/pause.png`, `design/results.png`, `design/gallery.png`, `design/achievements.png`, `design/settings.png`.

---

## 3 · Features per screen

### 1 · Onboarding — `OnboardingView`
- Two swipeable pages with a two-bar pager; `SKIP` chip top-right jumps straight to the Caldera.
- Page 1: the hook — stacked logo, the volcano with a live vein network and one already-crusted branch, the one-sentence premise.
- Page 2: three rule panels. Panel 1 embeds the real **before/after reroute diagram** (`diagram_shut_reroutes`); panels 2 and 3 cover crusting and mold tolerance. Keyword in each heading is inked in the colour of the thing it names.
- Final action `LIGHT THE RIFT` seeds `PreferenceEntity` defaults, seeds the 24 `VentProgressEntity` rows (vent 1 unlocked), 12 `CastEntity` rows, 18 `MarkEntity` rows and 4 `RiftEntity` rows, sets `firstLaunchCompleted = true`, saves, and routes to the Caldera.
- Skipped automatically when launched with `-screenshotTour`.

### 2 · Caldera — `CalderaView`
- Full-bleed mountain scene; **all navigation is world objects**, no button row.
- `ERUPT` fissure plate → resumes at the deepest unlocked vent (label shows exactly which); pressed scale + haptic.
- Obsidian plinth → Obsidian Casts, with a live `CASTS n/12` caption.
- Stone tablet → Struck Marks, with a live `MARKS n/18` caption.
- Valve wheel → The Valve House.
- The chamber wall carries live aggregates from Core Data: best cast score, rifts cleared, deepest vent reached, and lifetime average yield. Rendered with `.contentTransition(.numericText)` so they roll when you come back from a run.
- Long-press anywhere on the mountain is *not* a control — there are no dead gestures.

### 3 · Rift Map — `RiftMapView`
- Vertical `ScrollView` over one continuous vein, auto-scrolled to the live node on appear.
- 60 octagonal vent nodes in three states (cleared / live / locked), each tappable only when unlocked; locked nodes show a crust X and the requirement.
- Cleared nodes show their earned cast stars (0–3) beneath.
- Four dashed rift dividers with stone tags: `RIFT I · EMBERFOOT`, `RIFT II · CINDER STEPS`, `RIFT III · ASHFALL REACH`, `RIFT IV · THROAT OF THE MOUNTAIN`. Locked rifts get a teal tag and an explanatory plate.
- Header sash: stone back button, title, live `n/24 VENTS CAST` counter.
- A rift unlocks when the previous rift has ≥ 7 of its 10 vents cleared.

### 4 · Vent — `VentView` (`SpriteView` + HUD overlays)
- One `GameScene`, created once and held by `GameViewModel`; never constructed inside `body`. Pause/resume only via `scene.isPaused` in `onChange(of:)`.
- **Scene:** chamber, vein network, valves, rim molds, gouts, sparks — positioned as fractions of `scene.size`.
- **Tap a valve** → toggle shut/open (reopening a *warm* valve is free; a *crusted* one is not).
- **Press and hold a crusted valve** (0.6s, with a filling sulfur ring) → blowout: crust destroyed, branch live again, chamber pressure drops by `blowoutCost`, screen shake + heavy haptic.
- **Top HUD card:** vent and rift name, mold chip group, running cast score with numeric-text roll-up.
- **Pressure column** on the left: redline zone, safe-band brackets, fill, needle, percentage. Turns `--vv-danger` and pulses above 90%.
- **Hint strip** at the bottom, shown for the first three vents and then only when the player has been idle 6s.
- Pause plate → Pause overlay.
- Fail conditions: pressure hits 100% (blowout), or every remaining feed to an unfilled mold is crusted (choked), or three molds cracked.
- Win condition: all molds filled. Both routes end in the Cast Result overlay.
- Honours `-demoMode`: fixed RNG seed, fixed vent 07 layout, scripted valve taps.

### 5 · Pause — `PauseOverlay`
- Warm scrim over the live (frozen) scene.
- Basalt slab showing the four rim-mold gauges at their live fill and the chamber pressure track with the safe band drawn on it — so pausing is genuinely informative, not just a menu.
- `RESUME` (fissure plate), `RESTART VENT` (re-runs the same layout from zero), `LEAVE TO CALDERA` (abandons the run, no score written).

### 6 · Cast Result — `CastResultOverlay`
- Two verdicts sharing one layout: `CAST` (success) and `CHOKED` / `BLOWOUT` (failure, magma-red slab, no cast reveal, stars all unearned).
- On success: burst starfield, the obsidian piece revealed at hero scale, star row animating in one by one with a haptic each, nameplate with `NEW OBSIDIAN CAST · n OF 12` when it is the first time.
- Ledger: molds filled, yield %, veins crusted shut, peak pressure, cast score.
- `NEXT VENT` (unlocks and enters the next vent), `RECAST` (retry), `RIFT MAP`.
- Writes one `RunRecordEntity`, updates `VentProgressEntity` (best score, best stars, best yield, attempts), unlocks the next vent and possibly the next rift, unlocks the `CastEntity` if this vent awards one, and advances every affected `MarkEntity`. One `viewContext.save()` per transaction.

### 7 · Obsidian Casts — `CastVaultView`
- Three strata shelves holding all 12 pieces at deliberately unequal sizes.
- Unlocked pieces show their obsidian art; locked ones are grey uncast lumps with their unlock requirement on the plate.
- Tapping any piece fills the bottom detail card: name, the piece at detail scale, how it was cast, its rift, stars and yield at the time. Locked pieces show the requirement instead.
- Header counter `n/12`.

### 8 · Struck Marks — `MarksView`
- Scrolling wall of 18 mark strips, earned ones first is *not* used — order is fixed by tier so progress reads as a path.
- Each strip: medallion disc, title, one-line description, progress bar with `current/target`, or a ✓ when earned.
- Pinned bottom banner with the `n/18` total and a wall-wide track.

### 9 · The Valve House — `ValveHouseView`
- **Haptics** toggle → `PreferenceEntity.hapticsOn`, saved immediately; gates every haptic in the game.
- **Motion** toggle → `PreferenceEntity.animationsOn`; when off, screen shake, particle bursts and numeric roll-ups are suppressed (gameplay unaffected).
- **How a vent works** recap card — the same three rules, using the real valve / crust / mold art.
- **Reset progress** → confirmation alert → deletes all `VentProgressEntity`, `CastEntity`, `MarkEntity`, `RiftEntity`, `RunRecordEntity` rows, re-seeds defaults, sets `firstLaunchCompleted = false`, saves, and returns to Onboarding (never a black screen).
- Nothing else. No links, no store, no account, no notifications, no language picker, no icon picker.

---

## 4 · Content plan

### 60 vents across 6 rifts
Every vent is a hand-authored network layout — vein topology, valve positions, mold targets, pressure curve and crust timer — stored as plain Swift value types in `VentCatalog.swift` (no SpriteKit import; unit-testable).

| Rift | Vents | Name | Network | Molds | Crust timer | New wrinkle |
|---|---|---|---|---|---|---|
| I | 1–10 | **Emberfoot** | 1 junction, 2–3 branches | 2 | 9.0s → 7.0s | The core loop: shut a branch, watch flow double elsewhere. |
| II | 11–20 | **Cinder Steps** | 2–3 junctions, 4 branches | 3–4 | 6.8s → 5.4s | **Gas pockets** — a marked vein segment that doubles flow for 1.5s when magma first reaches it. |
| III | 21–30 | **Ashfall Reach** | 3–4 junctions, 5 branches | 4 | 5.2s → 4.2s | **Tremors** — every 12–18s a random *open* vein crusts instantly; the pressure curve steepens. |
| IV | 31–40 | **Throat of the Mountain** | 4–5 junctions, twin trunks | 4–5 | 4.0s → 3.2s | **Twin chambers** feeding at different rates, each with its own relief vent. |
| V | 41–50 | **Glass Gallery** | Two tiers over a long cascade | 5 | 3.6s → 3.0s | **Brittle molds** at the end of a long fall — concentrate too hard and they crack. |
| VI | 51–60 | **The Last Vent** | Three trunks, six branches | 5–6 | 3.2s → 2.6s | **Three chambers** at three rates, and every earlier wrinkle at once. | **Twin chambers** feeding the network at different rates; molds with narrow tolerance bands. |

Per-vent authored values: `ventNumber`, `riftIndex`, `nodes[]` (chamber / junction / mold anchors as unit-space points), `edges[]` (from, to, initial state, gasPocket flag), `molds[]` (target volume, min/max flow rate), `pressureCurve` (base rate + acceleration), `crustSeconds`, `blowoutCost`, `tremorInterval` (0 = none), `parTime`.

### 30 obsidian casts
Awarded on the first clear of every second vent, five per rift.

| # | Cast | Vent | Notes |
|---|---|---|---|
| 1 | Emberdrop | 2 | First piece you ever pull. |
| 2 | Twin Vane | 4 | Two blades — the first two-branch split. |
| 3 | Sulfur Knot | 6 | Closes Rift I. |
| 4 | Bridle | 8 | |
| 5 | Crownfracture | 10 | |
| 6 | Gutterspine | 12 | Closes Rift II. |
| 7 | Ashglass Lens | 14 | |
| 8 | Riftcomb | 16 | |
| 9 | Black Pennant | 18 | Closes Rift III. |
| 10 | Chokestone | 20 | |
| 11 | Ninefold Shard | 22 | |
| 12 | The Throat Key | 24 | Final piece; needs 3 stars on vent 24. |

Each carries a name, a one-sentence casting story, and the art asset it draws.

### 40 struck marks
| # | Mark | Condition |
|---|---|---|
| 1 | First Pour | Fill your first rim mold. |
| 2 | Emberfoot Cleared | Clear all six Rift I vents. |
| 3 | Never Shut Twice | Clear a vent without reopening a vein. |
| 4 | Redline Nerve | Hold pressure above 90% for 10s and still cast. |
| 5 | Crustbreaker | Blow open 25 crusted veins. |
| 6 | Nothing Wasted | Finish a rift at 100% yield across all six vents. |
| 7 | Three Stars | Earn 3 cast stars on any vent. |
| 8 | Nine Stars | Earn 3 cast stars on nine vents. |
| 9 | Cinder Steps Cleared | Clear all six Rift II vents. |
| 10 | Gas Handler | Ride 20 gas pockets without cracking a mold. |
| 11 | Cold Hands | Clear a vent with zero veins permanently crusted. |
| 12 | Ashfall Reach Cleared | Clear all six Rift III vents. |
| 13 | Tremor Proof | Clear a vent that threw three tremors at you. |
| 14 | Half The Vault | Unlock six obsidian casts. |
| 15 | Throat Of The Mountain | Reach Rift IV. |
| 16 | Full Vault | Unlock all twelve obsidian casts. |
| 17 | Deep Cast | Score 10,000 on a single vent. |
| 18 | The Whole Mountain | Clear all 24 vents. |

### Retention — the vigil, the daily and the rank ladder
- **Daily Fissure.** One date-seeded vent per calendar day, the same for every run that day, drawn from the middle of a randomly chosen rift. Retryable all day; only the best attempt is kept. Backed by `DailyRunEntity`.
- **The vigil.** A consecutive-day streak kept by `VigilEntity`, advanced by any finished run. Surfaced on the Caldera banner, the Ledger and the result overlay, and gated by three marks.
- **Rank ladder.** Nine titles from Ash-hand to Keeper Of The Last Vent, driven by total cast stars (0–180) so it moves on runs that unlock nothing. Shown on the Caldera, the Ledger, Settings, and announced on the result overlay when it changes.

### Edge states
- **Empty** — the vault, the marks wall and the Ledger each carry a written empty plate; the Ledger's offers a route straight into a vent.
- **First run** — the Caldera reads "The mountain · Unworked" instead of a best score, and the ERUPT plate says "Your first vent".
- **Completed** — every vent cast flips the ERUPT plate to "Recast" and the marks banner to "Every mark on the wall is struck".
- **Filtered-empty** — the Ledger's Cast / Lost filters have their own plates rather than a blank list.

### Copy inventory
2 onboarding pages, 6 rift names + subtitles, 60 vent labels, 30 cast names + casting stories, 40 mark titles + descriptions, 9 rank titles, 6 per-rift briefing warnings, 12 rotating gameplay hints, 4 edge-state plates, 3 settings plaques, 3 how-it-works steps, 9 ledger labels, 3 verdict strings. No stand-in text anywhere.

### Demo mode & screenshot tour
- `-demoMode`: seeded `SeededRandom`, forces vent 07's layout, and runs a scripted valve sequence that lands gouts cleanly — deterministic frames.
- `-screenshotTour`: skips onboarding, seeds a worked mountain (27 vents cleared through Rift III, 13 casts, 16 marks, a 9-day vigil with a 14-day best, 240 run records and a fortnight of dailies with two deliberate misses), then auto-cycles at 3s per screen, looping forever, with zero interaction: **Caldera → Vent (running the demo script) → Rift Map → Obsidian Casts → Struck Marks → The Ledger → The Valve House**. Driven by a `TourCoordinator` in `HomeView`. Tour seeding is a separate code path — normal launches are untouched.

---

## 5 · Core Data entities

Every entity has `id: UUID` and `createdAt: Date`. Every `FetchRequest` carries `sortDescriptors`. `viewContext.save()` runs after every mutation.

### `PreferenceEntity` — singleton
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date | |
| `hapticsOn` | Bool | default `true` |
| `animationsOn` | Bool | default `true` |
| `firstLaunchCompleted` | Bool | default `false` |

### `RiftEntity` — 6 rows, seeded
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date | |
| `riftIndex` | Int16 | 1…6, sort key |
| `name` | String | "Emberfoot" |
| `subtitle` | String | "Where the mountain still forgives you" |
| `unlocked` | Bool | rift 1 true at seed |
| `ventCount` | Int16 | 10 |
| `vents` | to-many → `VentProgressEntity` | inverse `rift` |

### `VentProgressEntity` — 60 rows, seeded
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date | |
| `ventNumber` | Int16 | 1…60, sort key |
| `riftIndex` | Int16 | |
| `unlocked` | Bool | vent 1 true at seed |
| `cleared` | Bool | |
| `bestScore` | Int32 | |
| `starsEarned` | Int16 | 0…3 |
| `bestYield` | Double | 0…1 |
| `bestMoldsFilled` | Int16 | |
| `attempts` | Int32 | |
| `clearedAt` | Date? | |
| `rift` | to-one → `RiftEntity` | |

### `CastEntity` — 30 rows, seeded
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date | |
| `castKey` | String | "sulfur_knot", unique |
| `orderIndex` | Int16 | 1…30, sort key |
| `name` | String | "Sulfur Knot" |
| `story` | String | one-sentence casting story |
| `assetName` | String | "cast_sulfurknot" |
| `awardVent` | Int16 | vent that awards it |
| `unlocked` | Bool | |
| `earnedAt` | Date? | |
| `earnedStars` | Int16 | stars held when first cast |
| `earnedYield` | Double | |

### `MarkEntity` — 40 rows, seeded
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date | |
| `markKey` | String | "crustbreaker", unique |
| `orderIndex` | Int16 | 1…40, sort key |
| `title` | String | |
| `detail` | String | |
| `assetName` | String | "mark_crustbreaker" |
| `target` | Int32 | e.g. 25 |
| `progress` | Int32 | |
| `earned` | Bool | |
| `earnedAt` | Date? | |

### `DailyRunEntity` — one row per calendar day the Daily Fissure was opened
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date | |
| `dayKey` | String | "2026-09-14", unique |
| `archetype` | Int16 | which rift's shape the day drew |
| `attempts` | Int32 | |
| `completed` | Bool | |
| `score` / `stars` / `yield` / `moldsFilled` | Int32 / Int16 / Double / Int16 | best attempt only |
| `playedAt` | Date? | |

### `VigilEntity` — singleton, the streak
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date | |
| `currentStreak` | Int32 | consecutive days with a finished run |
| `bestStreak` | Int32 | |
| `lastPlayDay` | String? | dayKey of the last finished run |
| `totalDays` | Int32 | |
| `totalRuns` | Int32 | |

### `RunRecordEntity` — history, one row per finished run
| Field | Type | Notes |
|---|---|---|
| `id` | UUID | |
| `createdAt` | Date | sort key, descending |
| `ventNumber` | Int16 | 0 marks a Daily Fissure run |
| `riftIndex` | Int16 | |
| `score` | Int32 | |
| `yield` | Double | |
| `peakPressure` | Double | |
| `veinsCrusted` | Int16 | |
| `crustsBlown` | Int16 | |
| `moldsFilled` | Int16 | |
| `moldsCracked` | Int16 | |
| `starsEarned` | Int16 | |
| `succeeded` | Bool | |
| `durationSeconds` | Double | |

`RunRecordEntity` backs the Caldera's lifetime aggregates and the whole Ledger screen — totals, cast rate, mean yield, time under the rim and the run-by-run history — and feeds the cumulative marks. The `SKScene` never touches Core Data — `GameViewModel` writes once, at game over.

---

## 6 · Architecture notes

```
VolcVein/
├── VolcVeinApp.swift            // WindowGroup { HomeView() }
├── HomeView.swift               // onboarding → Caldera, + TourCoordinator
├── Views/
│   ├── SplashView.swift         // dormant, referenced from nowhere
│   ├── OnboardingView.swift
│   ├── CalderaView.swift
│   ├── RiftMapView.swift
│   ├── VentView.swift           // SpriteView + HUD overlays
│   ├── PauseOverlay.swift
│   ├── CastResultOverlay.swift
│   ├── CastVaultView.swift
│   ├── MarksView.swift
│   └── ValveHouseView.swift
├── Game/
│   ├── GameScene.swift          // the single SKScene
│   ├── PhysicsCategory.swift    // all bitmasks, nowhere else
│   ├── GameState.swift          // .menu .playing .paused .gameOver
│   ├── GameViewModel.swift      // ObservableObject bridge + the only Core Data writer
│   └── Entities/
│       ├── VeinNode.swift
│       ├── ValveNode.swift
│       ├── MoldNode.swift
│       └── GoutPool.swift       // pre-allocated gouts + sparks, no update() allocation
├── Logic/                       // plain structs, no SpriteKit, unit-testable
│   ├── VentCatalog.swift        // all 24 authored layouts
│   ├── FlowSolver.swift         // pressure redistribution across open edges
│   ├── CrustClock.swift         // shut-vein cooling timers
│   ├── ScoreRules.swift
│   └── SeededRandom.swift
└── Persistence/
    ├── PersistenceController.swift
    ├── Seeder.swift             // first-launch + tour seeding paths
    └── VolcVein.xcdatamodeld
```

`FlowSolver` is the heart and lives entirely outside SpriteKit: given the edge graph, which edges are open, and the chamber pressure, it returns a flow rate per edge and per mold. `GameScene` only renders that result and reports touches back. No allocation happens inside `update(_:)` — gouts and sparks come from `GoutPool`.
