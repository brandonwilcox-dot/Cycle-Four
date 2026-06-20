# Cycle Four — Architecture North Star

> **Top-level architectural reference. Read this before adding any new screen, system, or scene.**
> It defines the single rule that stops us breaking things as we grow:
> **one active screen at a time, swapped by a manager, with state in autoloads.**
>
> **Status:** PROPOSED — 2026-06-20. Direction approved by the user; **migration not yet started**
> (no code changed). This doc is the contract the migration and every future system obey.
>
> **Where this sits among the docs**
> - `core/` + `codex/` (design repo) = **the canon** — what the game *is*.
> - `planning/vision-roadmap.md` = **what** we build next (post-MVP pillars A–D).
> - `planning/improvement-plan.md` = gameplay **passes** (combat, towers, …).
> - **this doc** = **how the project is structured** to hold all of the above without collapsing.
> - Live build state: `CLAUDE.md`. Input/scene traps: memory `reference-cycle-four-input-scene-gotchas`.

## 0. Why this document exists

The user named the symptom precisely: *"the game is being assembled piece by piece while
breaking things along the way."* That is accurate, and it has one structural cause: **there is no
screen-lifecycle contract.** Every system to date (Academy, HUD, galaxy view, garrisons…) has
been attached to a single ever-growing `Main` scene. Because they all live and run at once, each
addition can collide with the input and lifecycle of the others. The recurring "something ate the
click" bugs are all the same bug wearing different hats.

This document removes that at the root: it names the states the game is made of, the rule that
only one is live at a time, and where state lives versus where behavior lives. With the contract
written down, future systems slot in predictably instead of fighting the ones already there.

## 1. The vision in one screen

**Cycle Four** — a **lore-first** hybrid. You command one of three factions — **Architects**
(efficiency, strongest idle economy), **Bloom** (adaptation, near-unkillable late), **Mesh**
(theft, raiding) — racing across a **shared galaxy** toward the Ancient **core**. The **Ancients**
watch and counter whoever leads. The **IP is the asset**: the canon (the Codex) is
medium-agnostic; this game is its first expression.

- **Three gameplay layers, one board:** idle production (always on, offline-capable) · tower
  defense (passive, 5-min-session viable) · active RTS army (garrisons, raids, territory).
- **Two narrative layers:** **Option A** (survive convergence) over **Option B** (the Mark, 7
  Fragments, Memory Tiers, the Arrival — the cross-prestige mystery that pays off over months).
- **Session promise:** *meaningful in 5 minutes, deep over months.*

## 2. The end-state runtime — the states the game is made of

Work backwards from the finished game and it is a player moving through a small set of **distinct
top-level states, one at a time**:

| State | What it is | Today |
|---|---|---|
| **Title** | New Game / Continue / Options / Quit | ✅ separate scene (`TitleScreen.tscn`) |
| **Academy** | the tutorial — a *guided first Battle* (observed play) | ✅ a first-run **director on the Battle screen** (unified, like Galaxy); `CadetAvatar` is now a non-interactive prop |
| **Faction Select** | choose faction + sub-path (sigil) | ✅ the **Academy's finale** (sorting reveal), not a separate screen; orphaned `FactionSelectScreen` deleted |
| **Galaxy ⇄ Battle** | the **primary/home space**: the galaxy map. Zoom IN through region → system → planet/moon — battles resolve at the body you capture; you conquer the galaxy for your faction. One continuous space. | ✅ one-scene continuous zoom exists (Phase D, flat: node ↔ one battle map); nested region/system/body zoom is the end-state target |
| **Pilgrimage / Collapse** | prestige, the Mark, Memory Tiers (Option B) | ⬜ future |
| **The Arrival** | endgame threat | ⬜ future |

**That table is the architecture.** The only problem is that four of these states are currently
crammed into one scene instead of being the separate states they plainly are.

## 3. A five-minute Godot primer (so this doc stands alone)

Just enough to read the rest without deep Godot fluency:

- **Node / Scene.** A *node* is one object (a sprite, a label, a script-holder). A *scene* is a
  saved tree of nodes (e.g. `HUD.tscn`). Scenes can be *instanced* inside other scenes.
- **The SceneTree has ONE "current scene."** Godot runs a single active scene tree. You can
  replace it wholesale (`change_scene_to_file()` / `change_scene_to_packed()`), or manage it
  yourself by adding/removing scene instances under a persistent root.
- **Autoload (singleton).** A script registered to load once at startup and **persist across scene
  changes** — global, always on. Your Managers (`EventBus`, `GameState`, …) are autoloads; this is
  the right tool for state that must outlive any one screen.
- **CanvasLayer.** A layer that draws on top of the world and does **not** move with the game
  camera (used for UI). Critically, a parent `Node2D.hide()` does **not** hide child CanvasLayers —
  a lingering CanvasLayer keeps drawing and **keeps capturing input**.
- **Input order (the bug magnet).** GUI `Control`s receive clicks (`_gui_input`) **before**
  `_unhandled_input`. Among `_unhandled_input` handlers, Godot dispatches **deepest node first,
  scene root last**. So a decorative `Control`, or a deeper node, can silently eat a click before
  the handler you expect runs. (See memory `reference-cycle-four-input-scene-gotchas`.)

The architecture below exists to make these input hazards *structurally impossible* rather than
individually patched.

## 4. What we have today — and why it breeds bugs

`Main.tscn` is one scene holding everything:

```
TitleScreen.tscn        ← separate ✅
   │  New Game / Continue
   ▼
Main.tscn ─────── ONE scene holding EVERYTHING ───────
├── WorldMap            the LIVE board: MapGrid, Commander, towers, camera  ← alive from frame 0
├── WashLayer (CanvasLayer)
├── FactionDialogueHUD
└── UILayer (CanvasLayer, layer 10)
    ├── Academy         the tutorial — painted ON TOP of the already-running board
    ├── HUD
    └── GameOverScreen
```

On **New Game**, the entire battlefield boots immediately — `Commander`, map, camera, input
handlers all live — and the Academy is laid over it. `_start_game_world()` then `queue_free()`s
the overlay to *reveal* the game that was running all along.

**This one fact generates the entire bug history:**

- **Two "player units" at once** — the Academy's `CadetAvatar` *and* the live `Commander` — with
  **opposite input contracts** (Academy left-click = *move the cadet*; game left-click = *select*).
- **Competing input handlers and CanvasLayer Buttons** over the same clicks → "Academy buttons eat
  LMB," "lingering CanvasLayer," "first click eaten."
- **Freeing a focused Button mid-transition** leaves dangling focus/input state.

**Worked example — "Commander shifts slightly then returns" (reported 2026-06-20).** During the
Academy, `Main._unhandled_input` returns early (`if not GameState.academy_completed: return`), so
you are not touching the Commander at all — you are nudging the `CadetAvatar`, whose left-click
handler walks it toward the click via a fragile screen→local transform (raw screen pixels through
a `CanvasLayer`-pinned `Node2D` under canvas-item stretch). That transform collapses clicks toward
chamber-center, so the avatar drifts and appears to "return." It exists **only** because the
Academy is an overlay rather than its own scene with its own camera. It is not fixable in
isolation; it is removed by separating the scene.

## 5. The target architecture

**Principle (the missing leg): one active screen at a time, swapped by a thin manager.** You
already do the other two legs the Godot docs call for — persistent state in autoloads, and
decoupled communication via a signal bus (`EventBus`).

```
Root.tscn   (run/main_scene) — thin bootstrapper, ~no game logic
└── SceneManager     loads ONE screen, frees the previous, runs the fade
        ├─ TitleScreen.tscn
        ├─ Battle.tscn           ← the gameplay screen (renamed from Main): WorldMap (+ Galaxy
        │                          continuous-zoom), HUD, GameOver overlay, AND the first-run
        │                          ACADEMY director (tutorial = observed play; faction-select is
        │                          its finale). Unified, like Galaxy — not a separate screen.
        ├─ Pilgrimage.tscn       ← future systems arrive as their OWN screen
        └─ Arrival / endgame
  Persistent under every swap:  EventBus · GameState · EconomyManager · WaveManager ·
                                FactionManager · GalaxyManager · SaveManager · … (autoloads)
```

**One screen is alive at a time.** While the Academy runs there is no live `WorldMap` beneath it,
no second commander, no competing handler, nothing to free mid-click. The whole "something
ate/nudged the click" class becomes impossible by construction.

**What stays unified — on purpose.** **The Galaxy is the home space and Battle is its deepest zoom
level — one continuous scene.** The player's primary view is the galaxy map; they zoom *in* through
region → system → planet/moon, and a battle resolves at the body being captured. Conquering bodies
is *how you take the galaxy for your faction*. This whole spatial hierarchy is one continuous-zoom
scene (Phase D ships a flat first pass: galaxy node ↔ one battle map; the nested region/system/body
zoom is the end-state target). "Separate scenes" means lifting the **menus and tutorial** out of
gameplay — it never means splitting the galaxy from the battles inside it.

**Where state lives vs where behavior lives.**
- **State that must survive a screen swap → an autoload.** Faction, sub-path, wave number,
  economy, galaxy ownership, save data, Memory-Tier/Fragment progress. (Already true — keep it.)
- **Behavior + visuals for one screen → that screen's scene.** The Battle scene owns the board,
  units, HUD; the Academy scene owns the tutorial tableau; neither reaches into the other.
- **Cross-screen messages → `EventBus` signals.** Never a direct call from one screen into another.

**Save / Continue.** `SaveManager` stays an autoload. Flow: Title → *Continue* →
`SaveManager.load_game()` → `SceneManager` swaps to **Battle** (restoring faction/world). *New
Game* → Academy → FactionSelect → Battle. The "Academy ran in the background on Continue" trap
disappears because the Academy is no longer inside the gameplay scene.

## 6. The scene-lifecycle contract (the rules)

1. **One active screen.** Exactly one top-level screen scene is alive at a time, owned by
   `SceneManager`. The previous screen is **freed**, not hidden.
2. **No screen layered on the live board.** A menu, tutorial, or prestige flow is its **own**
   screen, never a CanvasLayer overlay on a running gameplay scene. (In-gameplay UI like the HUD
   belongs *to* the Battle scene — that is fine; it is part of that one screen.)
3. **State outlives screens via autoloads; behavior lives in the active screen.** If a value must
   survive a swap, it lives in a Manager. If it is only meaningful while a screen is up, it lives
   in that screen.
4. **Screens talk only through `EventBus`.** No sibling screen reaches into another. Within a
   screen: signals up, calls down.
5. **One input owner per screen.** Each screen has a single, clear place that owns world input. No
   two entities interpret the same click differently in the same screen.
6. **Decorative `Control`s in world space must be `MOUSE_FILTER_IGNORE`.** (Carried from the
   memory note — still law.)
7. **New system = new screen (or a clearly-owned part of one), swapped in by the manager.** Never
   bolt it onto the live board "for now."

## 7. Migration plan (incremental, each stage MCP-verifiable)

No big-bang rewrite — the autoloads + EventBus already carry the state, so this is mechanical and
stageable. Bar at each stage: `run_project` → zero new errors → `stop_project`.

| Stage | Work | Payoff |
|---|---|---|
| **0 ✅** | This doc. | The contract exists. |
| **1 ✅** | Add a thin `Root` scene + `SceneManager` (load / swap / free + fade). Boot still lands on Title. | Foundation; zero behavior change. **Done 2026-06-20 — boots clean (MCP), zero new errors.** |
| **2 ✅** | **Revised — the Academy is a *guided first Battle* (it observes real play; faction-select is its finale), not a separable screen.** Kept it as a **director on the Battle screen** (unified, like Galaxy⇄Battle). Killed the bug sources instead: `CadetAvatar` → non-interactive prop (**bug #1 fixed**); deleted the orphaned `FactionSelectScreen`; renamed `faction_select`→`academy`. | **Done 2026-06-20 — `Main.tscn` runs clean (MCP), zero errors.** |
| **3 ✅** | Rename `Main` → `Battle` (files + root node + `TitleScreen` path const). Pure gameplay scene (Academy is its director; menus are out). Continue already loads straight in. | **Done 2026-06-20 — `Battle.tscn` + normal boot both run clean (MCP), zero errors.** |
| **4+** | Each future system (Pilgrimage/prestige, Arrival, multi-front) arrives as its **own** screen the manager swaps to. | The bug class never returns. |

Stages 1–3 are the refactor that pays off the "stop breaking things" concern. Stage 4+ is just
"obey the contract" going forward.

## 8. Why this is the recommended Godot setup

Two of the three pillars are already correct in Cycle Four; this migration adds the third.

| Godot best practice | In Cycle Four |
|---|---|
| Persistent global state in **autoloads** (survive scene changes) | ✅ EventBus, GameState, the Managers |
| **Loose coupling** — signals up, calls down, siblings via a bus | ✅ EventBus signal rule |
| **One active scene**, swapped via `change_scene_to_*` or a persistent manager that instances/frees screens | ❌ **the missing leg — this migration adds it** |

Sources (authoritative Godot documentation):
- [Change scenes manually](https://docs.godotengine.org/en/stable/tutorials/scripting/change_scenes_manually.html)
- [Scene organization (best practices)](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)
- [When to use scenes vs scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html)

## 9. Glossary (canonical names used going forward)

- **Root** — the thin bootstrapper scene set as `run/main_scene`; hosts the SceneManager. No game logic.
- **SceneManager** — owns the active screen; loads / swaps / frees screens; runs transitions.
  (Autoload vs Root's script: decided in Stage 1.)
- **Screen** — a top-level scene that is the sole live scene while active (Title, Academy,
  FactionSelect, Battle, Pilgrimage, …).
- **Battle** — the gameplay screen (today's `Main`, minus the menus): board + HUD + galaxy zoom.
- **Manager / autoload** — a persistent global singleton holding state that outlives screens.

---

*Stage-1 open questions (decide when the refactor starts — none block approving this direction):
SceneManager as an autoload vs the Root scene's script; transition style (instant vs fade);
whether GameOver/Arrival are full screens or in-Battle overlays.*
