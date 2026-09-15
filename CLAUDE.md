# CLAUDE.md — Game Profile (SwiftUI shell + SpriteKit gameplay)

You are building a production-ready iOS game. Base rules match the app
profile; SpriteKit specifics below override where they conflict.

## Base rules (same as app profile — restated briefly)

- iOS 16+, portrait only, offline only, English UI. Core Data, NOT SwiftData.
- Scaffold with XcodeGen — same `project.yml` template as the app profile:
  name `<AppName>`, deploymentTarget "16.0", `GENERATE_INFOPLIST_FILE: YES`,
  `INFOPLIST_KEY_UILaunchScreen_Generation: YES`, portrait-only
  `INFOPLIST_KEY_UISupportedInterfaceOrientations`, bundle id
  `com.<lowername>`, `TARGETED_DEVICE_FAMILY: 1`,
  `sources: [<AppName>]`, PLUS the release-SDK packages exactly as in the
  app profile: top-level `packages:` AppsFlyerLib
  (github.com/AppsFlyerSDK/AppsFlyerFramework, from: 6.15.0) and OneSignal
  (github.com/OneSignal/OneSignal-iOS-SDK, from: 5.2.0), and target
  `dependencies:` linking products AppsFlyerLib and OneSignalFramework.
  These are linked but DORMANT: never import or initialize them in code,
  never remove them from project.yml. Then `xcodegen generate`. `.xcdatamodeld` and
  `Assets.xcassets` inside the sources folder are picked up automatically.
- Core Data: every entity `id: UUID` + `createdAt: Date`; PreferenceEntity
  singleton (`hapticsOn`, `animationsOn`, `firstLaunchCompleted`);
  `sortDescriptors` on every FetchRequest; `viewContext.save()` after every
  mutation.
- App file = `WindowGroup { HomeView() }` only. HomeView orchestrates
  onboarding → main menu (NO splash in the launch flow). MANDATORY dormant
  file `Views/SplashView.swift`: a complete, polished loader screen in the
  game's art direction (logo, animated loading indicator, themed bg),
  compiling, self-contained, referenced from NOWHERE — the release team
  wires it up later; never delete it as unused.

### Forbidden APIs (must NEVER appear)

- URLSession, WKWebView, any networking; StoreKit/IAP/paywalls/"Premium";
  SwiftData; sign-in/accounts; push notifications; ad SDKs; share sheets;
  external links (App Store/Privacy/Terms/Support); camera, microphone,
  location, contacts, calendar.
- ALL audio APIs: AVAudioPlayer, AVPlayer, AVAudioEngine,
  AudioServicesPlaySystemSound, SystemSoundID, AVAudioSession; no
  `import AVFoundation` for audio. Sound concepts get VISUAL substitutes:
  animated waveform (Canvas + Path), pulse synced to a Timer, hit-flash /
  screen shake standing in for sound feedback. Never show Play/Pause/Volume
  UI without real audio behind it — either no audio UI, or visual-only.
(Exception: the AppsFlyerLib/OneSignal SPM packages declared in project.yml are
release infrastructure — LINKED but never imported or initialized in code. The
bans above are on USING such APIs in the generated code, not on those two
package declarations — do not remove them.)


### Settings

Keep Settings minimal and functional for an offline app. NEVER include
store-unsafe items: Rate Us, Share App, Contact/Support, Privacy
Policy/Terms links, Subscription/Premium/Pro, Sign In/Account,
notifications toggle, language switcher, App Icon picker, social links.
If Reset Progress exists it must confirm (alert), wipe domain entities,
re-seed defaults and return to onboarding (`firstLaunchCompleted = false`)
— never a black screen.

### Every button does real work

No empty closures, no print-only handlers, no stub functions, no
NavigationLink to `Text(...)`/`EmptyView()`, no `.constant()` bindings in
interactive controls. A button with no meaningful action gets removed.
Grep before finishing (must return empty): `Button\([^)]+\)\s*\{\s*\}`,
`action:\s*\{\s*\}`, `NavigationLink\(destination:\s*(Text|EmptyView)`,
`(Toggle|Picker|Slider|Stepper)[^{]*\.constant\(`.

### Text readability

Every Text ≥ 14pt over decorated or gameplay backgrounds sits in a
contrast container: material pill/card (`.ultraThinMaterial`), solid card
+ shadow, double text shadow (black 0.6 radius 4 + black 0.4 radius 8),
or frosted `.regularMaterial` strip. Never naked Text over background
art. Applies to main menu, HUD overlays, level map, achievements, settings.

### Adaptive layout & Apple HIG (mandatory)

The game must look correct on EVERY iPhone from SE 3rd gen (375x667 pt)
to Pro Max (440x956 pt). Automated QA screenshots the -screenshotTour on
BOTH a small and a large simulator and sends broken layouts back.

- SwiftUI shell (menu, settings, achievements, HUD overlays): no
  hardcoded screen dimensions — design/*.png are 390x844 references,
  translate to flexible layout (Spacer, `.frame(maxWidth: .infinity)`);
  lists/level maps in ScrollView; tight labels get
  `.minimumScaleFactor(0.75)` + `.lineLimit(1)`; only full-bleed
  backgrounds use `.ignoresSafeArea`, interactive elements never sit
  under the notch/Dynamic Island or the home indicator; every tappable
  control ≥ 44x44 pt hit area.
- SKScene: use `scaleMode = .resizeFill` (or size the scene from the
  actual SpriteView size) and position gameplay/HUD-critical nodes
  RELATIVE to `scene.size` with safe margins — never absolute points
  tuned to one device; nothing playable may hide under the HUD, notch or
  home indicator on the small screen.

### Visual style

Visual style is defined by DESIGN.md and the design references for THIS
game — follow them, not a house style. Whatever the style: interactive
elements need visible pressed feedback, cards/surfaces need some depth
treatment consistent with the design, and primary actions should be
visually prominent. Do not reuse a memorized component library across
apps — design components that fit this game's look. If PNG tab icons
exist, build a custom tab bar (native `TabView` templates PNGs
monochrome); its visual design follows DESIGN.md.

Composition quality bar: design/*.png screens are the BINDING layout
reference — match them closely. A game menu is a SCENE, not a settings
list: full-bleed themed background, the game's title as art (depth
shadow), one clearly dominant Play (pressed scale + haptic), secondary
actions as rich themed elements, stats integrated INTO the scene —
never floating chips. This is a QUALITY BAR, not a layout template:
do NOT reproduce one memorized arrangement across games. In particular,
"two circular corner buttons on top + logo in the top third + one giant
pill Play + two square cards + a stats strip at the bottom" is our
overused house default — if a menu design lands on exactly that, it must
be restructured. Vary per game where the title sits, the shape and
placement of the primary action, the navigation idiom (themed cards,
banners, map nodes, objects on a shelf, a path, tabs) and where stats
live — the game's world should dictate the layout. FORBIDDEN: plain or
tinted-SF-symbol circles in a uniform row as navigation (rich thematic
ART icon buttons integrated into the scene are ENCOURAGED); a vertical
stack of equal rounded rectangles; naked square images in a widget
column; flat single-color background with floating widgets — the
background always gets a treatment (gradient wash, ambient shapes,
asset texture).

### Forbidden strings in code

"Lorem ipsum", "TODO", "Coming Soon", "Not implemented", "Placeholder",
"Sample Data", "Example Item", "MyApp".

## Architecture: SwiftUI shell + one SKScene

- SwiftUI owns everything outside gameplay: main menu, settings,
  achievements, onboarding, level select.
- ONE `SKScene` hosted via `SpriteView`. The scene is created ONCE and
  stored (e.g. in a `@StateObject` ViewModel or `@State` let-once holder) —
  NEVER constructed inside `body`, or it re-instantiates on every render.
- Pause/resume via `scene.isPaused` inside `onChange(of:)` — never by
  conditionally rebinding or recreating the `SpriteView`.

## Game/ folder layout

```
Game/
├── GameScene.swift        // the single SKScene
├── PhysicsCategory.swift  // ALL physics bitmasks live ONLY here
├── GameState.swift        // enum state machine (menu, playing, paused, gameOver)
├── GameViewModel.swift    // ObservableObject bridge scene <-> SwiftUI
└── Entities/              // node subclasses / entity factories
```

- `PhysicsCategory` is the single source of truth for collision bitmasks.
  Never define or modify a bitmask anywhere else.
- `GameState` is an explicit enum state machine; transitions happen in one
  place (the ViewModel or scene controller), not scattered ad hoc.
- `GameViewModel: ObservableObject` publishes score/lives/state to SwiftUI
  and forwards user intents to the scene.

## Rendering and layering

Fixed `zPosition` layers — never improvise values:

| Layer | zPosition |
|---|---|
| background | -100 |
| game entities | 0 |
| effects (particles, flashes) | 50 |
| HUD | 100 |

- HUD, pause menu and game-over screens are SwiftUI overlays on top of the
  `SpriteView` (testable, accessible) — NOT `SKLabelNode`s.

## Performance rules

- NO allocation inside `update(_:)`. Pre-allocate and pool projectiles,
  enemies and other spawnables; recycle via `isHidden` +
  `removeFromParent()`-free reuse.
- Game logic — scoring, spawn tables, difficulty formulas — lives in plain
  testable structs OUTSIDE the scene (no SpriteKit imports needed to test).
- The scene NEVER touches Core Data. The ViewModel persists results at
  game-over / checkpoint only.

## Demo mode + screenshot tour

- Honor the `-demoMode` launch argument: fixed RNG seed, fixed level/spawn
  script — deterministic frames for screenshots.
- `-screenshotTour` launch argument is MANDATORY: onboarding is
  skipped automatically; the app cycles by itself — 3 seconds per screen,
  looping forever, zero user interaction — through: main menu → gameplay
  running a staged demo level (reuse the `-demoMode` deterministic script)
  → level map → achievements → settings. Implement as a coordinator in
  HomeView driving programmatic navigation. Seed demo progress (unlocked
  levels, scores, a few earned achievements) so no screen is empty; tour
  seeding is a separate path — normal launches unaffected.

## Juice checklist (mandatory — flat games get rejected)

- Haptics on hits/pickups/deaths (gated on `PreferenceEntity.hapticsOn`)
- Screen shake on impacts (small amplitude, short duration)
- Hit-flash on damaged entities (white colorize pulse)
- Particle bursts on destroy/collect (SKEmitterNode or pooled sprites)
- Score roll-up animation in HUD (`.contentTransition(.numericText)`)

## Textures

- When image frames exist, load via `SKTextureAtlas` from folders named
  `<Name>.atlas` inside the sources folder.
- Pixel-art assets: `texture.filteringMode = .nearest`.
- No image assets? Draw with `SKShapeNode`, gradients and generated
  textures — the game must still look deliberate, not placeholder.

## Build loop

```bash
xcodebuild -project <AppName>.xcodeproj -scheme <AppName> \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build -configuration Debug build 2>&1 | tail -120
```

Iterate until `BUILD SUCCEEDED` (cap 15 iterations; same error twice →
change approach). Then grep the forbidden strings and dead-button patterns
above — all must return empty.

## Completion marker

When your task is BUILDING the app (writing code / fixing / rebuilding),
the LAST line of your output must be exactly `BUILD SUCCESS: <AppName>`
(no fence, no trailing text) — the worker parses this marker, wrong format
means the job is marked failed. Review-only sessions (e.g. visual QA)
follow their own task's output contract instead.
