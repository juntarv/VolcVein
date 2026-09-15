**Art direction:** Molten Riso Poster — a screen-printed volcanic field poster where flat, genuinely saturated orange and sulfur inks are pressed onto warm ash paper, with hard-edged shapes, halftone grain and deliberate ink misregistration.

The world is a **daylight volcano seen in cross-section**, not a night scene. Nothing glows because it is neon — things glow because the rock is literally molten. Backgrounds are always *inked rock*, never flat fill: a warm orange-to-maroon wash with a halftone dot field over it and hand-drawn strata curves crossing it. Panels are ash-paper stock dropped onto that rock with a hard 4–6px ink offset shadow, like a sticker on a poster.

Explicitly rejected for this app: near-black backgrounds with a single neon accent; ivory/cream editorial minimalism with serif type; purple-indigo gradients; Inter/Roboto; rows of identical soft rounded cards. Corners are hard (2–8px max). Depth comes from **flat offset shadows and a second ink**, never from blur-heavy glassmorphism.

---

## Color palette

Values are authoritative and match `design-tokens.css` in the repo root.

### Dominant ink — molten orange
| Token | Hex | Use |
|---|---|---|
| `--vv-magma` | `#FF5A1F` | The app's voice. Live veins, score numerals, card accent rails, mold fill, pressure fill. |
| `--vv-magma-hot` | `#FF8A2B` | Lit edge of flowing rock, cleared map nodes, chamber upper band. |
| `--vv-magma-core` | `#FFD07A` | White-hot centre line of a flow, gout cores, sub-labels on ink. |
| `--vv-magma-pale` | `#FFE2A6` | Chamber surface skin, flow highlight stroke, bubble sparks. |

### Accent ink — sulfur yellow
| Token | Hex | Use |
|---|---|---|
| `--vv-sulfur` | `#FFC21A` | Primary actions (the fissure plate), open valves, earned marks, cast stars, safe-band brackets. |
| `--vv-sulfur-deep` | `#D99200` | Pressed/under side of every sulfur plate — the flat offset shadow. |

### Rock neutrals (warm browns — never near-black)
| Token | Hex | Use |
|---|---|---|
| `--vv-ink` | `#2B0F08` | Deepest ink: type on paper, every outline, header sash, world nav caption plates. |
| `--vv-rock-deep` | `#5A1E0C` | Lower background stop, unearned star fill, mold interior. |
| `--vv-rock` | `#8C3410` | Mid background stop, stone button faces, cooling (shut but not yet crusted) veins. |
| `--vv-rock-lit` | `#B8471A` | Upper background stop, ambient strata curves. |
| `--vv-rock-flare` | `#C9531F` | Top of the shelf/ledge gradient, brightest strata line. |

### Paper stock — contrast containers only
| Token | Hex | Use |
|---|---|---|
| `--vv-ash` | `#F2E7D8` | Panel/card/HUD stock. Every body paragraph sits on this. |
| `--vv-ash-mid` | `#C9B7A4` | Stone-button borders, dashed rules on paper, locked-plate type. |
| `--vv-ash-deep` | `#9A8776` | Sub-labels on ink, shut-valve body, secondary button underline. |
| paper shade | `#DCCBB6` | Empty track / empty mold inside a paper panel. |
| paper text-2 | `#7A4A32` | Secondary copy on ash paper. |
| paper text-3 | `#6B4030` | Body paragraph colour on ash paper. |

### Functional state ink — cooled rock ONLY
| Token | Hex | Use |
|---|---|---|
| `--vv-obsidian` | `#12383D` | Crusted vein, crusted valve, locked map node, uncast lump, finished obsidian body. |
| `--vv-obsidian-lit` | `#1E5A60` | Lit facet of obsidian, locked progress bar. |
| obsidian facet | `#79C0B8` | Single bright facet down the centre of a cast piece. |

This teal is the **only** cool colour in the app and it is never decorative — it always means *this is cold and no longer flowing*. That is what makes the shut-vein timer readable at a glance.

### Semantic
| Token | Hex | Use |
|---|---|---|
| `--vv-danger` | `#C22A12` | Redline zone on the pressure gauge, Reset Progress plate. |
| `--vv-scrim` | `rgba(43,15,8,.68–.78)` | Warm maroon scrim behind Pause / Results — never a black scrim. |
| locked lump | `#5A4A3E` / `#6E5B4C` | Uncast stone in the vault (deliberately *not* obsidian — it never cooled). |

### Background recipes
- **Rock screens** (Rift Map, Vault, Marks, Valve House, onboarding p2): `linear-gradient(172deg, #A8400F 0%, #7A2A0B 42%, #571C08 76%, #3E1306 100%)` + a 5px-pitch halftone dot field at `rgba(255,120,40,.26)`.
- **Gameplay stage:** `linear-gradient(175deg, #9A3A12 0%, #77290C 38%, #521A08 72%, #3A1206 100%)` + the same dot field at `.30`, plus four ambient strata curves in `#B8471A` at 26% opacity.
- **Daylight sky** (Caldera, onboarding p1): `linear-gradient(178deg, #FFF0C6 0%, #FFD089 30%, #FFA95A 62%, #FF8438 100%)` with the halftone masked so it fades in toward the horizon.
- **Grain:** an SVG `feTurbulence` fractal-noise tile (140px, desaturated) laid over the whole screen at `multiply`, 22–26% opacity. This is what makes it read as print rather than vector.

---

## Typography

Both families ship with iOS and macOS — nothing is downloaded, nothing drifts.

| Role | Family | iOS PostScript name | Weight |
|---|---|---|---|
| Display / all headings, numerals, micro-labels | **Avenir Next Condensed** | `AvenirNextCondensed-Heavy` | 800 |
| Display, secondary | Avenir Next Condensed | `AvenirNextCondensed-DemiBold` | 600 |
| Body paragraphs | **Avenir Next** | `AvenirNext-Regular` / `-DemiBold` | 400 / 600 |
| Airy captions (Splash only) | Avenir Next | `AvenirNext-UltraLight` | 200 |

The design runs on **two extremes** — 800 condensed for everything structural, 400 regular for the two or three places that need real reading. There is no 500/600 body middle ground outside of inline `<b>` emphasis.

### Scale — few steps, large jumps
| Step | Size | Tracking | Where |
|---|---|---|---|
| micro | **11 pt** | `+0.18…0.22em`, UPPERCASE | Every label, stat key, shelf tag, node plate, hint strip, pager captions |
| body | **15 pt** (13 pt in dense panels) | `0` | Onboarding copy, cast descriptions, mark descriptions, how-it-works |
| numeral | **21–23 pt** | `-0.01em` | HUD score sub-values, ledger figures, stat-wall row values, mark progress |
| title | **30 pt** | `-0.01em`, UPPERCASE | Screen sash titles, panel headings, card titles, nameplate |
| display | **42–52 pt** | `-0.02em`, UPPERCASE | Fissure-plate labels (`ERUPT`, `RESUME`), Pause `HELD.`, Results `CAST` |
| hero | **66 pt stacked** | `-0.03em`, UPPERCASE | The VolcVein logo lockup (two lines) |

11 → 15 → 30 → 66 is roughly a doubling-and-then-some at every step; the middle of the scale is deliberately empty so nothing reads as "medium".

### Print treatments
- **Logo lockup:** stacked `VOLC` / `VEIN`, ash over sulfur, on an ink slab rotated `-4.5°`, 7px magma rail on the left edge, `9px 9px 0 rgba(43,15,8,.32)` hard offset shadow. Each line carries a `3px 3px 0 rgba(255,90,31,.9)` misregistration ghost.
- **Every heading on paper** is ink `#2B0F08`; every heading on rock is ash `#F2E7D8` and sits inside an ink slab or paper panel. **No naked type over background art anywhere.**
- **Micro labels** always sit on a solid plate (ink, sulfur or paper) — never floating.

---

## Per-screen layout

### 1 · Onboarding — page 1 of 2 (`design/onboarding.png`)
Hot daylight sky over an inked ground, split at 430px. The **stacked logo slab** sits centred at the top, rotated, breaking into the sky. Below it a full-width volcano cross-section: cone silhouette with a sulfur rim-line, magma chamber at the foot, and the **branching vein network** drawn as ink casing → magma core → pale highlight, with one branch already crusted teal and X-marked. An ash-paper copy panel with a sulfur rail overlaps the volcano's base carrying the hook ("A mountain you steer by closing doors"). Two pager bars, then the jagged sulfur fissure plate (`GO ON`). `SKIP` is a small ink chip top-right.
*Mood: a travel poster for a place that is about to kill you.*

### 2 · Onboarding — page 2 of 2 (`design/onboarding-mechanic.png`)
Rock background. A rotated ink slab headline ("Three rules of the rift"). Three ash-paper panels stacked with 8px gaps, each with a numbered condensed heading whose keyword is inked in the colour of the thing it names (`STEER` magma, `CRUST` obsidian teal, `RIM MOLDS` magma). Panel 1 carries a **before/after diagram** on a dark inset: an open Y-junction, a sulfur arrow labelled TAP, then the same junction with one branch plugged grey and the surviving branch visibly thicker. Fissure plate reads `LIGHT THE RIFT`.

### 3 · Caldera — main menu (`design/menu.png`)
**The menu is the mountain, seen whole.** No corner-button row, no centred logo-over-pill stack.
- Top third: hot sky, a bleached sun disc top-right, an ash plume billowing from the summit.
- The **logo slab sits upper-LEFT**, rotated `-4.5°`, overlapping both the sky and the mountain's shoulder, carrying the tagline "Shut a vein · steer the pressure".
- The mountain fills the rest full-bleed: sulfur rim-line along the silhouette, a small glowing crater mouth at the summit, five strata curves, and the **vein network as the hero motif** — trunk from the chamber, two sulfur junction valves, three live rim vents, one crusted dead branch with a grey X.
- **Primary action:** a jagged sulfur **fissure plate** cut diagonally across the mountain's throat (`ERUPT` + `RIFT II · VENT 07`), rotated `-3°`. Not a pill, not centred, not full-width.
- **Navigation is three world objects at three different heights and scales:** an obsidian shard on a basalt plinth on the left slope (`CASTS 5/12`), a stone tablet wedged into the right slope higher up (`MARKS 7/18`), and a small basalt valve wheel down in the chamber wall at bottom-right (`SETTINGS`). Each is thematic art with an ink caption plate — no SF-symbol circles.
- **Stats are carved into the chamber wall**, not a floating strip: a dark rock plate with a magma rail on the left edge sits inside the glowing magma chamber at the foot of the screen, holding `BEST CAST 8,420` and a three-column row (`RIFTS 2/4`, `DEEPEST 11`, `YIELD 93%`). The chamber's molten pool spills out to the right of it.

### 4 · Rift Map (`design/riftmap.png`)
A vertically scrolling cross-section. An ink header sash (clipped so its lower edge is skewed) with a stone back button, `RIFT MAP`, and a `9/24 VENTS CAST` counter in sulfur. The body is one continuous **vein climbing bottom-left to top-right**, live magma where you have been, crusted teal above your frontier. **Level nodes are octagonal valves on the vein**: cleared = magma-hot with a pale core, live = sulfur with a magma core, locked = obsidian with a grey X. Cast stars sit as a small row under each cleared node. Rift boundaries are **dashed strata rules with a centred stone tag** (`RIFT II · CINDER STEPS`; locked rifts get a teal tag). A rotated sulfur "TAP TO ENTER" tab points at the live node.

### 5 · Vent — gameplay (`design/gameplay.png`)
Full-bleed `SpriteView` with SwiftUI overlays. Layers follow the profile z-table exactly: strata + crater shelf at `-100`, chamber/veins/valves/molds at `0`, gout + spark burst at `50`, HUD at `100`.
- **Scene:** magma chamber across the bottom; vein casings in thick ink with magma cores and pale highlight lines; live branches bright, a shut branch dimmed to `--vv-rock`, a crusted branch dashed teal. Two sulfur octagon valves (open), one grey plugged valve with an ash bar, one teal crusted valve with an X. Four rim molds at the top — one full with a cast obsidian shard and a sulfur ✓ vent badge, one at 65%, one at 25%, one starved and dark with a grey badge. A white-hot gout mid-flight with ember sparks and a sulfur burst star.
- **Top HUD:** an ink pause plate (52pt wide, sulfur underline) beside an ash-paper card with a magma rail — `VENT 07` / `RIFT II · CINDER`, a dashed-bordered mold-chip group, and the running cast score in magma at 30pt.
- **Left edge:** a vertical **pressure column** — ink barrel, `--vv-danger` redline zone at the top, magma fill, pale crest line, sulfur safe-band brackets on both sides, a sulfur needle, and a 20pt sulfur readout below.
- **Bottom:** a dark hint strip with a sulfur rail and a valve glyph: "Tap a valve to **shut** it · hold to **blow a crust**".

### 6 · Pause overlay (`design/pause.png`)
The live scene stays visible under a warm maroon scrim at 68%. A single **basalt slab** — ash paper with a chipped `clip-path` outline and a 6px flat drop — holds an ink cap bar (`HELD.` at 52pt with a sulfur full stop, `VENT 07 · RIFT II` right-aligned), a row of four tall **mold gauges** filling from the bottom, and a chamber-pressure track with the sulfur safe-band bracket drawn over it. Actions below the slab: sulfur fissure plate `RESUME`, then two ink buttons (`RESTART VENT` ash-underlined, `LEAVE TO CALDERA` magma-underlined). A micro line reassures that vent progress is kept.

### 7 · Cast result overlay (`design/results.png`)
Same warm scrim. A rotated ink slab verdict `CAST` with a magma rail, and a sulfur tab beneath naming the vent. Behind the centre, a low-opacity **burst starfield** in magma and sulfur. The **obsidian cast is revealed at hero scale** in the middle. A row of three cast stars (earned sulfur, unearned rock-deep with a grey stroke). An ink nameplate with a sulfur underline gives the piece's name and `NEW OBSIDIAN CAST · 6 OF 12`. An ash-paper **ledger** lists five dashed rows — molds filled, yield, veins crusted, peak pressure, cast score (figures in magma where they are the headline). Actions: sulfur fissure `NEXT VENT`, then `RECAST` and `RIFT MAP` side by side.

### 8 · Obsidian Casts — vault (`design/gallery.png`)
Header sash with a `5/12` counter. The content is **three strata shelves cut across the rock** (a bright `#C9531F` top edge falling to `#3A1206`, with a long soft drop under each). Pieces *rest on* the shelves at deliberately unequal sizes and heights — three large on shelf 1, four mid on shelf 2, five small on shelf 3 — each with a small ink name plate. Unlocked pieces are obsidian shards with a bright centre facet; locked ones are **rough grey uncast lumps** with a chalk X and a requirement plate (`NEEDS 3★`, `VENT 12`). Shelf tags sit above each row on ink. A selected-piece **detail card** in ash paper pins to the bottom with the piece at 70pt, its name at 26pt, how it was cast, and a sulfur micro line of provenance.

### 9 · Struck Marks — achievements (`design/achievements.png`)
Header sash with `7/18`. A scrolling wall of **mark strips**: earned ones are ash paper with a sulfur rail and a sulfur medallion disc; locked ones are dark ink plates with a teal rail and a teal-and-grey disc. Each strip is `disc · title (21pt condensed) + one-line description + progress bar · count`. Earned bars fill magma on `#DCCBB6`; locked bars fill obsidian-lit on `#3E2118`; earned strips show a sulfur-deep ✓ instead of a count. A pinned ink banner at the bottom carries the big `7/18` in sulfur with a wall-wide progress track.

### 10 · The Valve House — settings (`design/settings.png`)
Header sash (`THE VALVE HOUSE` / `SETTINGS · PLAYS OFFLINE`). A stack of ash-paper plaques with sulfur rails: **Haptics** and **Motion**, each with a themed icon and a chunky two-state ink switch (`OFF` / `ON`, active half filled sulfur). Below them a dark **"How a vent works"** recap card with a magma rail and three illustrated steps reusing the real valve / crust / mold art. Last, a **Reset progress** plate on ink with a `--vv-danger` rail, a hammer icon, "Wipes vents, casts and marks. Asks first.", and a red `RESET` button. A micro footer reads `VOLCVEIN · 24 VENTS · 12 CASTS · V1.0`. Nothing else — no links, no store items, no notification toggle.

### 11 · Splash (dormant, `Views/SplashView.swift`)
Not in the launch flow; built to the same grammar. Hot-sky-over-rock split, the stacked logo slab centred, and the **`splash_loader_ring`** art below it — an ink ring with a sulfur arc sweeping around a magma valve octagon — rotating continuously. One `AvenirNext-UltraLight` caption ("Warming the chamber") on an ink plate.

---

## Asset brief

Raster imagery the harvested CSS/SVG elements cannot express — painterly texture and atmosphere. Generate exactly these; they ship alongside `design/assets/`.

- `bg_ash_sky` — bg — Caldera menu, Onboarding p1 — *Screen-printed poster sky over a volcano at midday: flat bands of pale cream, sulfur yellow and saturated orange with visible halftone dots, coarse paper tooth and slight ink misregistration, no gradients smoother than a riso pull.*
- `bg_rock_wall` — bg — Rift Map, Vault, Marks, Valve House — *Painterly basalt strata wall in warm orange-maroon inks, horizontal sedimentary bands with dry-brush edges and heavy paper grain, screen-print texture, no highlights and no glow.*
- `bg_chamber_glow` — bg — Vent gameplay — *A magma chamber seen in cross-section as a riso print: a molten pool in saturated orange and sulfur bleeding into dark maroon rock, hard-edged colour separations, halftone dot shading, gritty paper texture.*
- `tex_obsidian_facet` — texture — Vault, Cast result — *Flat-shaded volcanic glass surface in deep teal-black with a few pale mint conchoidal fracture facets, screen-print styling with crisp edges and paper grain, no photographic reflections.*
- `tex_ash_grain` — overlay — every screen — *A seamless tile of fine volcanic ash speckle and printing-press grain in transparent warm grey, for multiply overlay at low opacity.*
- `hero_caldera_poster` — hero — SplashView — *A riso travel-poster portrait of a single volcano in cross-section at midday, black basalt cone against a sulfur sky, a branching network of glowing orange veins threading up through the rock to three rim vents, flat inks, halftone grain, deliberate misregistration.*

---

## Harvested assets

Everything in `design/assets/` is a transparent @3x PNG rendered from the real design elements and ships inside the app. 53 files.

### Core gameplay entities (SpriteKit nodes)
| Asset | Role |
|---|---|
| `valve_open.png` | Sulfur octagon valve with a magma core — an open junction; the tap target. |
| `valve_shut.png` | Grey basalt plug with an ash bar — a branch you closed, still warm. |
| `valve_crusted.png` | Obsidian octagon with a chalk X — sealed; needs a press-and-hold blowout. |
| `crust_plate.png` | Irregular obsidian scab with hairline cracks — the crust that grows over a shut vein. |
| `mold_empty.png` / `mold_part.png` / `mold_full.png` / `mold_set.png` | The four rim-mold states: waiting, filling, cast, and starved-solid. |
| `gout_blob.png` | A white-hot pooled magma gout in flight — the pooled projectile. |
| `ember_spark.png` | Four-point sulfur spark — the pooled particle for bursts and impacts. |
| `gauge_pressure_column.png` | The vertical chamber-pressure barrel with redline zone, safe-band brackets and needle. |
| `mold_row.png` | The four-mold gauge row used on the Pause slab. |

### Branding & chrome
| Asset | Role |
|---|---|
| `app_icon_volcvein.png` | **App icon art** — saturated orange field, black cone, sulfur Y-vein and valve. |
| `logo_volcvein.png` | Landscape logo slab with tagline — the Caldera menu lockup. |
| `logo_volcvein_stacked.png` | Stacked two-line logo slab — Onboarding and Splash. |
| `splash_loader_ring.png` | Ink ring + sulfur arc + magma valve — the dormant SplashView loader. |
| `btn_back_stone.png` | Carved stone back chevron — every header sash. |
| `btn_pause_valve.png` | Ink pause plate with sulfur bars — gameplay HUD. |
| `fissure_play_plate.png` | The jagged sulfur `ERUPT` plate — Caldera primary action. |
| `fissure_resume_plate.png` | The `RESUME` fissure plate — Pause. |
| `fissure_next_plate.png` | The `NEXT VENT` fissure plate — Cast result. |

### Scene art
| Asset | Role |
|---|---|
| `mountain_cross_section.png` | The full Caldera menu mountain with strata, chamber and vein network. |
| `onboard_hero_volcano.png` | The onboarding volcano with a live network and one crusted branch. |
| `ash_plume.png` | Billowing summit ash cloud — Caldera sky. |
| `burst_cast.png` | Magma/sulfur starburst behind the revealed cast — Result. |
| `diagram_shut_reroutes.png` | The before/after "tap a valve and flow reroutes" teaching diagram. |

### World navigation (Caldera menu)
| Asset | Role |
|---|---|
| `icon_obsidian_plinth.png` | Obsidian shard on a basalt plinth → Obsidian Casts. |
| `icon_stone_tablet.png` | Struck stone tablet → Struck Marks. |
| `icon_valve_wheel.png` | Basalt valve wheel → The Valve House. |

### Map & scoring
| Asset | Role |
|---|---|
| `node_cleared.png` / `node_live.png` / `node_locked.png` | The three Rift Map vent-node states. |
| `cast_star_on.png` / `cast_star_off.png` | Earned and unearned cast stars — map, result, vault. |
| `cast_stars_row.png` | Pre-composed 2-of-3 star row — Result reveal. |

### Obsidian casts (collection art)
| Asset | Role |
|---|---|
| `cast_emberdrop.png` | Cast 1 — Emberdrop. |
| `cast_twinvane.png` | Cast 2 — Twin Vane. |
| `cast_sulfurknot.png` | Cast 3 — Sulfur Knot. |
| `cast_bridleshard.png` | Cast 4 — Bridle. |
| `cast_crownfracture.png` | Cast 5 — Crownfracture (vault size). |
| `cast_crownfracture_hero.png` | Crownfracture at reveal scale — Cast result. |
| `cast_detail_sulfurknot.png` | Sulfur Knot at detail-card scale — Vault. |
| `cast_locked_lump.png` / `cast_locked_lump_b.png` | Two uncast grey stone lumps — locked vault slots. |

### Struck marks (achievement medallions)
| Asset | Role |
|---|---|
| `mark_first_cast.png` | First Pour — earned style. |
| `mark_dry_run.png` | Never Shut Twice — earned style. |
| `mark_redline.png` | Redline Nerve — earned style. |
| `mark_crustbreaker.png` | Crustbreaker — locked style. |
| `mark_full_yield.png` | Nothing Wasted — locked style. |
| `mark_deep_rift.png` | Throat Of The Mountain — locked style. |

### Settings iconography
| Asset | Role |
|---|---|
| `icon_haptics.png` | Buzzing handset — Haptics plaque. |
| `icon_animations.png` | Valve with motion ticks — Motion plaque. |
| `icon_reset_hammer.png` | Red stone hammer — Reset progress plate. |

---

## Interaction & motion rules

- **Pressed feedback is mandatory and physical.** Sulfur plates drop their `0 4px 0 var(--vv-sulfur-deep)` offset and scale to `0.96`; ink buttons drop their underline; world-nav objects scale to `0.93` and nudge 2pt down. Every press fires a haptic when `hapticsOn`.
- **Hit areas:** every tappable control is ≥ 44×44 pt. In-scene valves get a 56pt circular touch region regardless of drawn size.
- **Juice:** haptic on valve toggle / gout landing / mold cast / blowout; a 4–6pt, 0.2s screen shake on a blowout or a cracked mold; a white colorize pulse on an overfilled mold; pooled `ember_spark` bursts on every mold fill and crust break; the HUD score rolls with `.contentTransition(.numericText)`.
- **Adaptive:** the shell has no hardcoded screen sizes — the Caldera composes from `GeometryReader` proportions, the Rift Map and Vault scroll, tight labels take `.minimumScaleFactor(0.75)` + `.lineLimit(1)`. The `SKScene` uses `.resizeFill` and positions the chamber, vein anchors and rim molds as fractions of `scene.size` with a top inset that clears the HUD card and a bottom inset that clears the hint strip. Only full-bleed backgrounds use `.ignoresSafeArea`.
- **Text readability:** no `Text` ≥ 14pt ever sits directly on rock or on the gameplay scene. It is on ash paper, on an ink plate, or on a sulfur tab. The HUD card, hint strip, node plates and stat wall exist for exactly this reason.
