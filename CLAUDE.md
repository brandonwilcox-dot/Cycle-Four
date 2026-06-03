# Cycle Four -- Game Project

Godot 4.6.1 | GDScript | D:\AI\Cycle Four\

Design corpus lives at:
  C:\ClaudeProjects\Skippy Gaming Design Engineer Agent\core\
Read PROJECT-MEMORY.md and core/23_open-questions-resolved.md before
making any design decisions in code.

---

## The Game

**Title:** Cycle Four
**Genre:** Idle-Miner / Tower Defense / Endless Wave hybrid
**Three-layer gameplay:**
  1. Idle production -- always running, offline-capable (EconomyManager)
  2. Tower defense -- passive auto-attack, 5-min session viable (WaveManager)
  3. Unit production on cooldown -- active RTS layer (WaveManager + entities)

**Design philosophy:** Lore-first. The IP is the asset.
**Session target:** Meaningful in 5 minutes. Deep over months.

---

## The Four Factions

**Architects** (faction id: "architects")
- Philosophy: Efficiency is virtue. Multiplicative economy.
- Resources: energy (primary), schematics (secondary)
- Sub-paths: "standard" | "spiritual_tech"
- Strength: strongest idle loop, best diplomats
- Weakness: brittle under attack, accidentally trigger doomsday devices
- Units feel like: precision machines, clean geometric forms

**Bloom** (faction id: "bloom")
- Philosophy: Life spreads. Adapt or die.
- Resources: biomass (primary), lineages (secondary)
- Sub-paths: "purist" | "assimilator"
- Strength: units evolve from damage, near-unkillable late game
- Weakness: weakest early, buries Ruins (makes Ancients hostile)
- Units feel like: organic, asymmetric, grotesque beauty

**Mesh** (faction id: "mesh")
- Philosophy: Everything is a system. Hack it.
- Resources: signal (primary), routes (secondary)
- Sub-paths: "networked" | "dreamer"
- Strength: steals resources and infrastructure, strongest raider
- Weakness: weakest passive economy, dependent on stealing
- Units feel like: glitchy, fragmented, neon-edged constructs

**Ancients** (not playable)
- Librarians for the apocalypse. Seed vaults. Fled here from something.
- React to the leading faction by countering their core strength.
- The Custodian unit: unkillable, non-attacking, follows the player.
- Pacification economy: sacrifice faction-specific things at Ruins.

---

## Autoload Architecture

All autoloads are globally accessible. Do NOT import them -- they are
singletons injected by Godot at startup.

| Autoload | Responsibility |
|---|---|
| EventBus | All cross-system signals. Read/emit only -- no state. |
| GameState | Top-level state (faction, wave, prestige). Read anywhere, write via Managers. |
| EconomyManager | All resource production, storage, spending. Idle tick owner. |
| WaveManager | Wave spawning, enemy tracking, TD loop. |
| FactionManager | Faction selection, sub-path, faction-specific data lookups. |
| GalaxyManager | Persistent galaxy layer, star systems, treaties, alliances. |
| SaveManager | Save/load, auto-save, offline catch-up trigger. |

**Signal rule:** Systems communicate ONLY through EventBus signals.
A script that needs to tell another system something emits a signal.
It does NOT call the other system's methods directly (unless it owns it).

---

## File / Folder Conventions

```
src/autoloads/     -- Global singletons (one per Manager)
src/core/economy/  -- EconomyManager helpers, resource definitions
src/core/waves/    -- Wave table loaders, spawn logic
src/core/units/    -- Unit stat definitions, cooldown logic
src/core/galaxy/   -- Galaxy generation, cascade logic
src/core/ancients/ -- Pacification system, Dominance Meter
src/factions/architects/  -- Architect-specific scripts
src/factions/bloom/       -- Bloom-specific scripts
src/factions/mesh/        -- Mesh-specific scripts
src/ui/            -- HUD, panels, notification system
src/entities/      -- Unit, building, projectile base classes
src/utils/         -- Math helpers, constants, formatters
scenes/main/       -- Main game scene, game loop scene
scenes/ui/         -- UI subscenes
scenes/test/       -- Throwaway test scenes (not shipped)
resources/         -- .tres data files (unit stats, building defs, wave tables)
assets/            -- sprites, audio, fonts, shaders
```

**Naming:**
- Scripts: PascalCase.gd (e.g. ArchitectUnit.gd)
- Scenes: PascalCase.tscn (e.g. TowerBase.tscn)
- Resources: snake_case.tres (e.g. architect_tier1_unit.tres)
- Constants: ALL_CAPS
- Signals: past_tense_snake_case (e.g. wave_ended, resource_changed)
- Functions: snake_case. Private functions prefix with _

---

## GDScript Style Rules

- Always use static typing (var x: float = 0.0, not var x = 0.0)
- Class-level doc comment with ## on the first line of every file
- Keep functions under 40 lines. Extract helpers if longer.
- No magic numbers -- define as const at top of file or in a constants file
- Signals are defined in EventBus.gd only -- scripts never define their own
  cross-system signals
- Use await sparingly -- prefer signals for async flow
- @export variables for anything a designer might tune in the editor

---

## Key Design Numbers (from core/23_open-questions-resolved.md)

- Idle tick rate: 1 second
- Offline cap: 8 hours
- Auto-save interval: 60 seconds
- Wave countdown between waves: 5 seconds
- First session target: meaningful content within 5 minutes
- Production tiers: 1-3 (standard), 4-5 (research-gated), 6 (post-milestone)
- Memory Tiers: 0-11 (cross-prestige Option B system)
- Fragments: 7 total (gate Memory Tier progression)

---

## Current Status (2026-05-30)

**Active work: UI / HUD systems.** Map architecture refactor (Phases 1–10) is COMPLETE as of 2026-05-30.
The hardcoded 30x17 cell grid is being replaced with a multi-layer,
data-driven architecture. Full specification lives at:

`C:\ClaudeProjects\Skippy Gaming Design Engineer Agent\planning\map-architecture-implementation-handoff.md`

**Read the handoff doc before touching any file in `src/core/map/`.**

### Map architecture phase tracker

| Phase | Status | Output |
|---|---|---|
| 1. Data structure scaffolding | COMPLETE | 8 Resource scripts in `src/core/map/` |
| 2. MapData loader + parity test | COMPLETE | `DefaultMapBuilder.gd`, `MapGrid.load_map_data()`, debug parity check in `_ready()` |
| 3. Zone-region overlay + reverse index | COMPLETE | `build_zone_index()`, `get_zones_at_cell()`, `ZoneIndexBench.gd` |
| 4. Spawn point migration | COMPLETE | `SpawnPoint` resources, `MapData.spawn_points` source-of-truth, `EventBus.spawn_activated(spawn_id: StringName)`, verified end-to-end via MCP |
| 5. Objective subsystem | COMPLETE | `ObjectiveManager` autoload, faction × sub_path keying, sealing (DORMANT/ACTIVE → SEALED), `map_completed` → PERMANENTLY_SEALED, verified end-to-end via MCP |
| 6. Fog-of-war | COMPLETE | `Commander.VISION_RADIUS=3`, `meta.revealed` writes, `EventBus.region_revealed`, fog-driven ON_REVEAL spawn activation, fog-aware `_draw` (unrevealed cells hidden + spawn squares hidden until revealed), safe zone radius 3 around FOB |
| 7. Friendly AStar + support graph + ancient paths | COMPLETE | `_friendly_astar` skeleton on MapGrid (GROUND/CLAIMED/BASE traversable, PATH excluded); SupportGraph stub with FOB + depot at (4,1); ancient `PathEdge` `nw_to_fob` (19 cells); auto-flagged ANCIENT_PATH_CROSSING zones (3); fog-driven `path_discovered` signal wiring. Path-cut/stranded logic deferred to Phase 8 with convoys. |
| 8. Convoy entity class | COMPLETE | `Convoy.gd` round-trip ferry (depot↔FOB, blue loaded / grey empty, 1.5s pause at each endpoint); `ConvoyManager` autoload with connectivity BFS on `path_discovered`, spawn-once-per-depot logic, cargo aggregator; fog visibility for both Convoy and Unit (enemies hidden in unrevealed cells); depot markers rendered as amber inset squares. Flanker damage / map-failure UX deferred to Phase 8b. |
| 9. Two progression curves | COMPLETE | Tower level/xp/_damage_multiplier (step function ×1.15/level, threshold 50×level²); Convoy proficiency (logarithmic) + rank (every 10 deliveries, +5% speed); Commander rank (every 25 cells, +5% speed, +10% damage, primary rapid-fire + secondary cannon AOE attacks); FOB fortification rank (every 10 cargo). Reusable `ProgressionBar` widget renders bars above Tower/Convoy/Commander/FOB. Spawn-flash fix for Unit/Convoy. |
| 10. Procedural generator + guardrails | COMPLETE | `MapGenerator.gd` static `generate(seed, biome, topology)` → MapData; 2–4 cardinal spawns randomized; winding multi-segment paths (1–3 intermediate waypoints with perpendicular offsets); random depot placement; ancient PathEdge auto-detected + crossings; full validation pass (every spawn reaches BASE, depots on GROUND, BASE intact) with reroll-on-failure up to 16 attempts. Replaces DefaultMapBuilder for fresh runs; DefaultMapBuilder kept as legacy reference + generator fallback. Phase 2 parity check retired (no longer applicable). |
| 9. Two progression curves | pending | |
| 10. Procedural generator with guardrails | pending | |

### Files in src/core/map/ (current state)

- `MapGrid.gd` — live grid, loads MapData via `load_map_data()` on `_ready()`
- `MapData.gd` — top-level map resource with cell types, meta bitfield, zones, spawn points, support graph, objectives. Has 12 meta accessors + zone index API.
- `SystemData.gd` — star-system container holding multiple MapData
- `ObjectiveData.gd` — authoritative side of objective→spawn seal relationship
- `SpawnPoint.gd` — replaces SPAWN_* cell types; SpawnState enum includes PERMANENTLY_SEALED
- `ZoneRegion.gd` — strategic zones including ANCIENT_PATH_CROSSING kind
- `SupportGraph.gd` — building-node logistics graph (FOB-rooted)
- `BuildingNode.gd` — graph node (building, HP, derived `connected_to_fob`)
- `PathEdge.gd` — graph edge with `kind` (ANCIENT/PLAYER_BUILT) and `discovered` flag
- `DefaultMapBuilder.gd` — Phase 2 bridge; replicates the old hardcoded layout into a MapData. Retire when Phase 10 generator lands.
- `ZoneIndexBench.gd` — Phase 3 perf bench; call `ZoneIndexBench.run()` to verify sub-frame lookup time on 100k random queries.

Phase 5 added one autoload (lives in `src/autoloads/`, not `src/core/map/`):

- `ObjectiveManager.gd` — autoload. Owns the active objective list, subscribes to `territory_claimed`/`territory_raided`/`faction_selected`, applies seal/unseal/permanent-seal rules. `set_map(map_data)` is called from `MapGrid.load_map_data()`.

### Tooling — Godot MCP wired in

The `Coding-Solo/godot-mcp` server is configured via `.mcp.json` in this
project. MCP tools available (prefix `mcp__godot__`): `get_godot_version`,
`get_project_info`, `list_projects`, `launch_editor`, `run_project`,
`stop_project`, `get_debug_output`, `create_scene`, `save_scene`,
`add_node`, `load_sprite`, `export_mesh_library`, `get_uid`,
`update_project_uids`.

Use these to run the project and capture debug output directly rather
than asking the user. The Phase 2 parity check (`MapGrid Phase 2 parity OK`)
and the `ZoneIndexBench.run()` Phase 3 benchmark are both verifiable
end-to-end via the MCP.

MCP source lives at `D:\AI\godot-mcp` (cloned from
github.com/Coding-Solo/godot-mcp, vetted: zero network code, child
processes restricted to Godot binary, MIT license, 3.9k stars).

### What's also already built in this project (not just map work)

Autoloads: EventBus, GameState, EconomyManager, FactionManager,
GalaxyManager, SaveManager, WaveManager.
Entities: Unit, Tower, Building, Base, Commander (+ *Data resources).
Waves: WaveTable, WaveSpawner.
UI: FactionSelectScreen, HUD, GameOverScreen.
Scenes for all of the above exist in `scenes/main/` and `scenes/ui/`.

### Side tasks queued (chip tray)

1. **Rapid-click hang investigation.** Reproducible UI race when the player clicks rapidly during/near tower upgrade interactions. Pre-existing since Phase 4 verification; not blocked on Phase 10. Investigation prompt + repro recipe baked into the chip.
2. **Map scale-up to 60×34.** Production target is ~4× the current 30×17. Touches MapData/MapGrid/MapGenerator constants plus CELL_SIZE or a camera. Spec captured in `planning/map-architecture-implementation-handoff.md` §11.5. Investigation prompt + recommended approach (A vs B) in the chip.

### Next session start (UI work)

**UI track approach:** faction-agnostic first (confirmed 2026-05-31). Skins are a later pass.

**Completed UI work:**

| Panel | Status | Files |
|---|---|---|
| Objective panel | COMPLETE (2026-05-31) | `src/ui/ObjectivePanel.gd`, `scenes/ui/HUD.tscn` (ObjSummaryBtn + ObjectivePanel nodes) |
| Wave panel | COMPLETE (2026-05-31) | `src/ui/WavePanel.gd`, `scenes/ui/HUD.tscn` (WavePanel nodes), `EventBus.wave_axis_committed`, `MapData.get_active_spawn_points()`, `WaveSpawner._spawn_queue` |
| BottomBar cleanup + four-cluster restructure | COMPLETE (2026-05-31) | `scenes/ui/HUD.tscn` rewritten (TopBar→ResourceCluster, BottomBar→ActionBar, NotificationStack bottom-right anchored). `src/ui/HUD.gd` rewritten (updated paths, removed duplicate wave handlers). **Note:** `.tscn` format does not support `##` comment lines between node declarations. |
| Building inspection panel | COMPLETE (2026-05-31) | `src/ui/InspectionPanel.gd` + nodes in `HUD.tscn`. Click tower → tier/dmg/range/level/XP/Upgrade btn. Click building → name/income. Upgrade now deliberate. `EventBus.panel_upgrade_requested`. `Main._screen_to_cell()` camera-aware. |
| Progressive disclosure wiring | COMPLETE (2026-05-31) | `HudDepth` enum (GLANCE/TACTICAL/ACTIVE) in HUD.gd. `_set_depth()`, `enter_glance_state()`. Wave start → GLANCE. ESC → GLANCE. Empty-cell click → close inspection. `hud_state_changed(depth)` emitted on every transition. |
| Wave panel expansion | COMPLETE (2026-05-31) | `EventBus.wave_composition_committed(unit_name, count)`. WaveSpawner emits it after `wave_axis_committed`. WavePanel: `ExpandBtn` (▶/▼) in WaveRow header, `CompositionDetail` label below EnemyLabel. Hidden until wave starts; collapsed each new wave; hidden on wave end. |

**Objective panel behavior:** `ObjSummaryBtn` in TopBar shows "Objectives: N/M", hidden until faction selected. Clicking toggles a PanelContainer anchored right (offset_left=-288, top=56, bottom=340). One row per `ObjectiveData`: description label + ProgressBar + ✓ status. Wired to `objective_progressed`, `objective_completed`, `objective_lapsed`, `map_completed`. On map complete: title turns green, summary btn says "Map Complete!".

**Next session start**

Camera and HUD click-through are complete. Three queued tracks below, each with a
self-contained session prompt. Recommended model listed with each.

---

### TRACK A — Convoy fix + Commander sensor rings
**STATUS: COMPLETE (2026-06-02)**
**Recommended model: Sonnet** (well-defined code work, files and logic are known)
**Prerequisite: none — start here**

#### Bug context
`ConvoyManager._spawn_for_newly_connected()` spawns a convoy as soon as the ancient
PathEdge is `discovered = true`. But `path_discovered` fires the moment ANY of the
edge's 19 cells enters the Commander's starting vision — which can happen at startup
before the player has ever walked to the depot. The depot endpoint cell may not be
revealed yet. Fix: guard in `_spawn_for_newly_connected()` that calls
`data.get_meta_revealed(sp_col + sp_row * data.dimensions.x)` on the depot node's
position before calling `_spawn_convoy()`. One file, one guard.

#### New feature: two commander rings
Commander.gd currently has one `VISION_RADIUS = 3` doing fog reveal, spawn activation,
and convoy gating all at once. Split into two concentric rings:

**LoS ring (keep as VISION_RADIUS ≈ 3):** fog reveal, spawn activation, convoy depot
gating. Behavior unchanged; just explicitly named.

**Sensor ring (new SENSOR_RADIUS ≈ 8–10):** larger pass in `_reveal_around()` that
sets `ObjectiveData.sensed = true` and emits `EventBus.objective_sensed(id)` without
activating the objective. The player sees the depot in the ObjectivePanel as
"DETECTED" (dimmed, question-mark marker) before they've walked to it. Convoy still
only spawns once the depot is within LoS.

Draw the sensor ring on-screen as a faint dashed circle around the Commander (use
`_draw()` or a Line2D polygon approximation). The LoS ring can be a slightly brighter
inner circle.

#### Files to touch
- `src/autoloads/ConvoyManager.gd`    -- depot-reveal guard (bug fix)
- `src/entities/Commander.gd`         -- add SENSOR_RADIUS, second sweep, draw both rings
- `src/autoloads/EventBus.gd`         -- add `objective_sensed(objective_id: StringName)`
- `src/core/map/ObjectiveData.gd`     -- add `var sensed: bool = false`
- `src/autoloads/ObjectiveManager.gd` -- connect objective_sensed, update sensed state
- `src/ui/ObjectivePanel.gd`          -- show sensed rows dimmed with "?" prefix

Run via Godot MCP after the bug fix, then again after sensor rings. Zero new errors.

---

### TRACK B / B-2 — Ability system design (core/24 §1–11)
**STATUS: COMPLETE (2026-06-02)**
**Recommended model: Opus**
**Prerequisite: Track A complete**

#### Context
Commander.gd has a secondary cannon AOE that fires automatically every 5 seconds.
The user wants this converted to a deliberate player-triggered ability with a keyboard
binding, similar to an MMO skill bar.

Current combat in Commander.gd:
- Primary: auto-fire, 0.4s interval, 8 dmg, single target, always automatic (keep)
- Secondary: auto-fire, 5s interval, 30 dmg AOE, needs to become deliberate

#### Design questions to answer
1. Ability slot count for the first pass (recommend 1–4)
2. Keybind convention: Q/E, 1/2/3/4, or something else? Tradeoffs?
3. Cost model: cooldown only, resource cost + cooldown, or charge-based?
4. Are abilities faction-neutral or faction-specific from the start? Reference
   core/12_wave-commanders.md and core/17_units-maps-buildings.md for faction feel.
5. Hotbar HUD position in the four-cluster layout (§22). Bottom edge is the
   production stack — does the hotbar sit here or get its own cluster?
6. Unlock/progression path: available from start, or gated by research/rank?
7. What 2–3 other abilities beyond the cannon AOE make sense for the first build?

#### Output
Write `C:\ClaudeProjects\Skippy Gaming Design Engineer Agent\core\24_ability-system.md`
covering all of the above plus implementation handoff notes (files to touch, new
resource types, signal names). This doc is the spec for Track C.

---

### TRACK C / C-2 — Ability system build (full kit + faction divergence + ultimates)
**STATUS: COMPLETE (2026-06-02)**
**Recommended model: Sonnet**
**Prerequisite: Track B complete**

#### What to build (high level — defer to the spec for details)
1. Remove auto-fire secondary timer from Commander._process()
2. `src/entities/AbilityData.gd` — new Resource: cooldown, damage/effect, range,
   input_action (StringName), display_name
3. `Commander.gd` — load abilities, _unhandled_input for ability keys, cooldown
   tracking per slot, emit `EventBus.ability_used(ability_id, position)`
4. `EventBus.gd` — add `ability_used` signal
5. `src/ui/AbilityBar.gd` + nodes in `scenes/ui/HUD.tscn` — one slot per ability:
   key label, cooldown ring (ProgressionBar style), ready/not-ready tint
6. Input map — register action names via InputMap API at startup (no project.godot edits)

Run via Godot MCP after each step. Zero new errors is the bar.

---

### UI track (ongoing — no dedicated prompt needed)
Continue from the current §22 spec. Next natural wedges in order:
The §22 tactical-state layer is now **fully wired**. All three triggers from §22 §2 are live:
- Click tower/building → InspectionPanel ✓
- Click wave panel expand → composition detail ✓
- Panels close when player looks away (empty click, ESC, wave start) ✓

**Ability system — COMPLETE (2026-06-02):**
4 slots Q/W/E/R live. Lance charge-based (60 dmg). Suppression Field ground-targeted.
Overdrive self-amp. Faction divergences + 3 ultimates (Compile Cascade / Verdant Bulwark /
System Seizure) all verified. §9 forward queue closed (charge meter, faction branches,
slot 4, accessibility pass). Files: `src/abilities/`, `src/ui/AbilityBar.gd`.

**Remaining §22 UI work (deferred):**
1. Damage indicator overlay — needs tower/building gradual HP first (Track E unblocks)
2. Active state panels (research tree, galaxy map, pacification) — future tracks
3. Faction UI skins — deferred until faction selection is stable (Track D-2 unblocks)

---

### TRACK D — First-Session Flow (core/16)
Design spec: `core/16_first-session-flow.md`. Full 5-chapter arc: Academy → first map →
waves 1–20 → sub-path commit → first milestone → Ancient activation.

Split into sub-tracks by dependency and scope. Start with D-1.

---

#### D-1 — Milestone System
**Recommended model: Sonnet**
**Status: COMPLETE + verified (2026-06-03)**

Per-faction milestone conditions, progress tracking, and `milestone_reached` emission.
Currently `milestone_reached` is never emitted — Overdrive (slot E) and the faction
Ultimate (slot R) never unlock. This is the highest-priority unblock.

**Per-faction milestone targets (core/21, core/16 Chapter 6):**
- **Architects:** Research chain R1–R5 complete (EconomyManager stub: gate on cumulative
  schematics spent ≥ threshold OR a 5-stage research counter). For v1: simple counter
  that the player can trigger from a "Research" button, 5 stages at increasing cost.
- **Bloom:** Biomass coverage ≥ 60% of GROUND cells (CLAIMED cells as proxy — already
  tracked by Commander). `_claimed_count / total_ground_cells >= 0.60`.
- **Mesh:** 5 convoy routes simultaneously active (5 `connected_to_fob = true` depots
  at the same time). ConvoyManager already tracks connectivity.

**What to build:**
1. `src/core/MilestoneManager.gd` — new autoload. Subscribes to `territory_claimed`,
   `path_discovered`, `convoy_spawned`. Evaluates condition each relevant event.
   When met: emit `EventBus.milestone_reached(FactionManager.active_faction, 0)`.
   Idempotent — only fires once per run.
2. `EventBus` already has `milestone_reached(faction_id, milestone_index)` — no change.
3. Register MilestoneManager in project.godot autoloads.
4. For Architects v1: add a "Research" button to ActionBar or a simple progress counter
   in ResourceCluster. 5 clicks × increasing schematics cost = milestone. Deferred UI
   until D-2 fleshes the tech tree — for now, trigger on R1 research spending threshold.
5. Progress indicator in HUD: a compact bar/counter specific to each faction's milestone
   condition (per core/16 Chapter 6: appears "~wave 12–14"). Show in ResourceCluster
   once faction is selected, hidden until wave 10 starts.

**Key numbers (core/16 + core/21):**
- Architect research: 5 stages. Costs: 50/100/200/400/800 schematics each.
- Bloom coverage: 60% of total GROUND cells on the map.
- Mesh connectivity: 5 depots `connected_to_fob = true` simultaneously.

Run via Godot MCP. Zero new errors.

---

#### D-2 — Sub-path Commit UI
**Recommended model: Sonnet**
**Status: COMPLETE + verified (2026-06-03)**

Wave-timer pause between waves 9–10, two-branch tech tree overlay, sub-path
confirmation. Fires `EventBus.faction_selected` with the committed sub-path string
(re-emit with updated sub_path, or add a new `subpath_committed` signal). Currently
`active_sub_path` is never set after faction selection — Suppression Field unlock
depends on this event.

**What to build:**
1. Pause wave countdown at the start of the between-waves-9-10 gap.
2. Modal overlay (the only modal in the first session per core/16 §5 constraint):
   two sub-path cards, faction-voiced description, confirm button.
3. On confirm: `FactionManager.set_sub_path(id)` → emit signal → WaveManager resumes.
4. The existing `ability_unlock` for Suppression Field already connects to
   `faction_selected` — re-emitting after sub-path commit is the simplest wire.

---

#### D-3 — Academy Scene
**STATUS: COMPLETE + verified (2026-06-02)**
**Recommended model: Opus for implementation design, Sonnet to build**
**Prerequisite: D-2 complete**

Pilgrimage opening (Chapter 0), three sorting scenarios (Chapter 1), faction
recommendation + selection. Implementation design: `planning/academy-scene-implementation-handoff.md`.

Files: `scenes/main/Academy.tscn`, `src/ui/Academy.gd`, `src/academy/` (AcademyScenario,
CadetAvatar, ChamberFloor, ChamberMark, ChamberRingWall), `resources/academy/scenario_1..3.tres`.
Swapped `FactionSelectScreen` → Academy in `Main.tscn`/`Main.gd`. `GameState.academy_completed`
+ `GameState.unsorted` added with save round-trip. Skip guard: Academy plays only when
`current_faction.is_empty() OR NOT academy_completed`. Sorting: 3 votes, sigil alpha = votes/3,
tie-break = last-voted, 3-way = neutral line. Decline sets `unsorted = true`. All paths
call `FactionManager.select_faction(faction, default_sub_path)` → emit `selection_confirmed`.

---

#### D-4 — Wave Scripted Events
**Recommended model: Sonnet**
**Prerequisite: D-3 complete ✓**
**Status: NEXT**

- Wave 3: guarantee a secondary-axis flanker probe (scripted, not random).
  WaveSpawner gains a `scripted_overrides: Dictionary` that forces spawn composition
  for specific wave numbers.
- Faction-voiced one-liners: brief notification toasts on key events (resource node
  connected, first unit defeat, wave 3 flank hit, sub-path commit). NotificationStack
  already exists.
- Ancient activation at milestone: desaturation effect (full-screen ColorRect, alpha
  0 → 0.7 grey over 0.5s then back), Ancient unit spawns at Ruins position, walks to
  Ruins edge, delivers one dialogue line, emits faction-counter debuff, despawns.
  Unit is not in "units" group — it does not participate in wave logic.

---

### TRACK E — Economy & Idle Loop
**Recommended model: Sonnet**
**Prerequisite: Track D complete (D-1 at minimum for research cost integration)**

Real idle tick income (`idle_tick` signal already in EventBus but never fired),
offline catch-up (SaveManager stub), resource caps, secondary resource production
(schematics/lineages/routes — currently never generated). Wire EconomyManager's
production rates to the idle tick. Prerequisite for the §22 damage indicator.

---

### TRACK F — Wave Content
**Recommended model: Sonnet**
**Prerequisite: Track E complete**

Real wave tables per faction (core/17 Tier 1–3 units + 2 milestone signatures each),
wave escalation curve across waves 1–25+, named commander integration (core/12).
Currently all waves spawn generic placeholder units.

---

### TRACK G — Rapid-Click Hang (Bug)
**Recommended model: Sonnet — anytime, independent**

Pre-existing UI race when clicking rapidly near tower upgrade interactions. Reproducible
since Phase 4. Investigation: add input-event logging to `_unhandled_input` in Main.gd
and HUD.gd; check for double-free or signal double-connect on the InspectionPanel
upgrade button path.

---

### TRACK H — Map Scale-Up to 60×34
**Recommended model: Sonnet — anytime, independent**

Production target is ~4× the current 30×17 map. Touches `MapData.dimensions` defaults
in `MapGenerator.gd` and `DefaultMapBuilder.gd`, `MapGrid` cell count, camera
`min_zoom` formula (already self-adjusting: `max(vp_w/map_w, vp_h/map_h)`), and any
hardcoded 30/17 constants. Estimated 3–5 files. Spec in
`planning/map-architecture-implementation-handoff.md §11.5`.
