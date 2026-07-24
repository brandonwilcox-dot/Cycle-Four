# Project Memory — Jump-Start File

> Read this first when resuming the project in a new session. It captures
> where things stand, the immediate practical context, and the open
> threads now that the Game Codex is complete. Companion to `CLAUDE.md`
> (which holds the live project-state index). Last updated 2026-05-30.
>
> **For implementation status, also read `D:\AI\Cycle Four\CLAUDE.md`** —
> the live state file for the Godot build is now maintained there.

---

## How to Use This File

This file exists so a fresh session can pick the project up cold. The
intended sequence at the start of the next session:

1. Read `CLAUDE.md` — the project-state index and document map.
2. Read this file — the narrative handoff and the open-threads list.
3. Read `docs/DESIGN-GUIDELINES.md` before importing or restyling visual assets.
4. Pick a next direction from "Where to Go Next" below.
5. Begin.

If returning after a long gap, also skim `core/10_faction-lore.md` (the
root lore document) and `codex/00_codex-index.md` (the canon reference).

---

## Where the Project Stands (2026-05-24)

The **design corpus is complete**. Across thirteen design sessions, the
project produced fourteen interlocking core documents (`core/10`
through `core/23`) covering faction lore, galaxy politics, wave
commanders, the Pilgrimage site, the endgame threat, monetization, the
first-session flow, unit/map/building rosters, the Ancient pacification
economy, the cross-prestige Memory Tier system, galaxy-scale strategy,
late-game progression, the unified interface design, and a sweep
resolving every open question the corpus had left dangling.

The game is titled **Cycle Four** (chosen 2026-05-21 — the Ancients'
log designation for this iteration of the convergence). It is an
**Idle-Miner / Tower-Defense / Endless-Wave hybrid**, engine target
Godot (not yet in development). The design is deliberately
**lore-first and game-type-agnostic** — the IP is the asset, not the
specific game implementation. That philosophy is the bridge to the next
task.

The corpus hangs together with real internal consistency: systems
reinforce each other, the Option A / Option B narrative structure is
load-bearing, and every mechanic ties back to faction identity. This is
a strong foundation for an IP, not just a game.

The **Game Codex is now complete** (Session 12). It lives in `codex/` —
an eleven-section canon reference plus an index, distilled from
`core/10`–`core/22`, presenting the world, characters, history, and
cosmology as a medium-agnostic canon. The corpus remains the spec for
*the game*; the Codex is the spec for *the IP*.

**Session 13** then swept the corpus's open questions:
`core/23_open-questions-resolved.md` triages all 49 "Open Questions"
items from `core/10`–`core/22` — 11 already closed by later docs, 23
resolved outright, 5 sent to playtest with ship defaults, 2 to the
build, 8 deferred out of scope. The corpus no longer carries an
undocumented open design decision.

---

## Implementation Status (2026-05-30)

The game build is underway. Godot 4.6.1 project at `D:\AI\Cycle Four`.
Live state file: `D:\AI\Cycle Four\CLAUDE.md` (read it before any
implementation work).

**Map architecture refactor — COMPLETE** as of 2026-05-30. All ten phases
of the implementation spec at
`planning/map-architecture-implementation-handoff.md` landed and were
verified end-to-end via the Godot MCP. The hardcoded 30×17 grid is gone,
replaced by a multi-layer data-driven system that supports fog-of-war,
procedurally-generated maps, objectives, ancient path discovery, persistent
convoy ferries, and a unified rank/level progression model across Tower /
Convoy / Commander / FOB. Summary of phases (all COMPLETE):

- Phase 1 — 8 Resource scripts scaffolded (`SystemData`, `MapData`,
  `ObjectiveData`, `SpawnPoint`, `ZoneRegion`, `SupportGraph`,
  `BuildingNode`, `PathEdge`).
- Phase 2 — `MapData` loader and parity check. The hand-authored
  default map now loads from a resource; the old `_build_default_paths()`
  is the parity reference, debug-only assert in `_ready()`.
- Phase 3 — Cell→zone reverse index with O(1) lookup API. Sub-frame
  perf budget verified via `ZoneIndexBench`.
- Phase 4 — SpawnPoint migration. `SPAWN_W/N/S/E` cell types retired;
  `MapData.spawn_points` is the source of truth. `EventBus.spawn_activated`
  signature changed from `Vector2i` to `StringName`. WaveSpawner, Commander,
  MapGrid, HUD all updated.
- Phase 5 — Objective subsystem. `ObjectiveManager` autoload, faction ×
  sub-path keying, DORMANT/ACTIVE → SEALED on completion, SEALED → ACTIVE
  on lapse, all SEALED → PERMANENTLY_SEALED on `map_completed`.
- Phase 6 — Fog-of-war. `Commander.VISION_RADIUS=3`, `meta.revealed`
  writes, `EventBus.region_revealed`, fog-driven ON_REVEAL spawn activation,
  fog-aware rendering, safe zone radius 3 around FOB.
- Phase 7 — Friendly AStar + SupportGraph + ancient paths. `_friendly_astar`
  skeleton; SupportGraph (FOB + stub depot); ancient `PathEdge` discovery
  via fog reveal; auto-flagged ANCIENT_PATH_CROSSING zones.
- Phase 8 — Convoy entity. Round-trip ferry (depot↔FOB, blue loaded / grey
  empty, 1.5s pause at each endpoint); `ConvoyManager` autoload with
  connectivity BFS, spawn-once-per-depot logic, cargo aggregator; fog
  visibility for both Convoy and Unit; depot markers as amber inset squares.
- Phase 9 — Progression curves. Tower level (step function ×1.15/level,
  threshold 50×level²); Convoy proficiency (logarithmic) + rank (every 10
  deliveries, +5% speed); Commander rank (every 25 cells, +5% speed, +10%
  damage, primary rapid-fire + secondary cannon AOE); FOB fortification
  rank (every 10 cargo); reusable `ProgressionBar` widget; spawn-flash fix.
- Phase 10 — Procedural generator. `MapGenerator.gd` static
  `generate(seed, biome, topology)` → MapData; 2–4 cardinal spawns
  randomized; winding multi-segment paths (1–3 intermediate waypoints
  with perpendicular offsets); random depot placement; ancient PathEdge
  auto-detected with crossings; full validation pass with reroll-on-failure
  up to 16 attempts. Replaces DefaultMapBuilder for fresh runs.

## Next track: UI / HUD (2026-05-30 → ongoing)

With the map architecture done, the natural next track is the unified HUD
per `core/22_interface-design.md`. The existing HUD has resource displays,
faction info, wave counter, FOB HP, build buttons, notification stream,
and territory counter. What's missing from §22:

- Four-cluster layout (top-left status / top-right faction events /
  bottom-left build / bottom-right command).
- Progressive disclosure (glance / tactical / active depth states).
- Contextual panels — objective panel, research tree, galaxy map,
  pacification meter. Most don't exist yet.
- Soft-interrupt notification ordering.
- Faction UI skin variants.
- Accessibility (color redundancy, text-flag annotations).

**Recommended entry wedge:** the objective panel. The objective subsystem
(Phase 5) is fully wired and emits `objective_progressed` /
`objective_completed` / `objective_lapsed` / `map_completed` signals, but
nothing in the HUD surfaces them. Standing up a contextual panel that
binds to those signals is the smallest cohesive UI delivery and exercises
the four-cluster + contextual-panel patterns from §22.

## Side tasks queued in the chip tray

1. **Rapid-click hang investigation.** Reproducible UI race when the
   player rapidly clicks during/near tower upgrade interactions. Pre-existing
   since Phase 4 verification, surfaced again in Phase 9 with the extra
   Commander-attack node churn. Chip carries the full repro recipe.
2. **Map scale-up to 60×34 (~4×).** Production target. Touches MapData/
   MapGrid/MapGenerator constants plus either a smaller CELL_SIZE or a
   pannable camera. Spec captured in handoff §11.5; chip has the
   implementation prompt and recommended approach split (A vs B).

**Godot MCP** (`Coding-Solo/godot-mcp`) is wired into the Cycle Four
project via `.mcp.json`. Smoke-tested 2026-05-30: returns
`4.6.1.stable.official.14d19694e`. Tools include `run_project`,
`get_debug_output`, `launch_editor`, scene/node manipulation. Phase
validation steps can now be executed and read back directly without
asking the user to drive the editor.

MCP source: `D:\AI\godot-mcp` (cloned from
github.com/Coding-Solo/godot-mcp; audited — no network code, child
processes restricted to the Godot binary, MIT, 3.9k stars).

---

## Immediate Practical Context

- **Virtualization.** The shell tooling runs in a lightweight VM. On a
  machine without virtualization support, the sandboxed Linux
  environment cannot boot — so git operations and code execution via
  the agent's shell are unavailable. File tools (read/write/edit) still
  work fully. A machine with virtualization support restores the full
  toolset and makes the eventual Godot build far smoother.
- **Uncommitted work.** The corpus, the `codex/` directory, and the
  *Cycle Four* title were committed by the user at the end of Session
  12. Session 13 added `core/23_open-questions-resolved.md` and edits to
  `CLAUDE.md` and `PROJECT-MEMORY.md` — not yet committed (the agent's
  sandboxed shell remains down). Suggested commit:
  ```
  git add core/23_open-questions-resolved.md CLAUDE.md PROJECT-MEMORY.md
  git commit -m "Add core/23 - open-questions resolution sweep (Session 13)"
  ```
  Local git is unaffected by the virtualization issue; the user can
  commit from their own machine at any time.
- **The .docx that wasn't.** The Codex was requested in both Markdown
  and `.docx`. Native `.docx` generation needs the sandboxed shell,
  which is hard-down (`HYPERVISOR_VIRT_DISABLED`). The substitute is
  `codex/The-Codex.html` — a single-file edition that opens in Word
  (File → Save As → .docx) and is readable in any browser. If a future
  session runs on a machine with virtualization enabled, generating a
  native `.docx` from the `codex/` Markdown is a quick task.

---

## The Design Corpus — Quick Map

All in `core/`. Sessions 1–5 produced docs 12–16; sessions 6–11 produced
docs 17–22. Docs 01–09 are RETIRED (pre-pivot ULBFF V3 material).

| Doc | Subject |
|---|---|
| 10_faction-lore | Root lore. Factions, sub-paths, milestones, the loop, Option A/B. |
| 11_galaxy-politics | Galaxy map, diplomacy, treaties, cascade effects. |
| 12_wave-commanders | Named commander dialogue, tiers 11–25. |
| 13_pilgrimage-site | The Pilgrimage: visual/spatial design, the Mark. |
| 14_endgame-threat | "The Arrival." 7-Fragment arc. Sequel hook. |
| 15_cosmetics-monetization | Cosmetic ladder. Option B reskins. |
| 16_first-session-flow | New-player experience, 0:00–5:00. |
| 17_units-maps-buildings | Faction rosters, buildings, standard map spec. |
| 18_ancient-pacification | Pacification economy, Dominance Meter, Ruins ritual. |
| 19_memory-tiers | Cross-prestige Option B delivery. Eleven Memory Tiers. |
| 20_galaxy-strategy | Alliances, Neutral Core, Mesh inheritance, Bloom Pruning. |
| 21_late-game-progression | Tier 4–6 units, research chain, Second Milestones. |
| 22_interface-design | Unified HUD, progressive disclosure, faction UI skins. |

---

## The Game Codex — Complete

The Codex was built in Session 12 and lives in `codex/`. It presents the
world, characters, history, and cosmology as a medium-agnostic canon
reference — the canon extracted from `core/10`–`core/22` and organized
so it can drive any expression of the IP.

This is the formal expression of the project's stated philosophy: "the
IP is the asset, not the specific game implementation."

### What was built

- A `codex/` directory: `00_codex-index.md` plus eleven section files
  (`01`–`11`): The Premise, Cosmology, The Ancients, The Galaxy, The
  Three Factions as Cultures, Characters, The Timeline, The Central
  Mystery, Themes & Tone, Canon Rules, Adaptation Notes.
- `codex/The-Codex.html`: a single-file edition combining all sections,
  styled for reading and for Word/`.docx` export.

### Decisions taken (confirmed with the user at session start)

- **Format:** a `codex/` directory of section files, not one document.
- **Scope:** pure canon; game mechanics confined to Adaptation Notes.
- **File type:** both Markdown (the master) and a shareable formatted
  edition — delivered as HTML, since native `.docx` was blocked by the
  disabled sandbox.
- **Adaptation coverage:** equal treatment of game, tabletop/GM,
  graphic novel, and YA fiction.

### Verification

The Codex was cross-checked against `core/10`–`core/22` for canon
consistency. One inaccuracy was caught and corrected during the pass:
the commander Magistrate Vell was mis-described as pre-dating the
named-commander tiers — corrected in both `codex/06_characters.md` and
`codex/The-Codex.html`. The deep-time figures (40,000-cycle Bloom
memory, ~80,000-cycle prior world), the Fragment set, the commander
roster, the three Mark substrates, and the "never state the reveal"
rule all reconcile cleanly with the corpus.

---

## The IP Vision

The user's intent is to **turn this into an IP** — a property that can
support multiple media, not a single game. The stated horizons:

- **The game** — the Idle/TD/RTS hybrid. The design corpus is its spec.
- **Tabletop / "game master" use** — the Codex should be usable by a
  game master to run *any type of game* in this world. This means the
  canon must be presented system-neutrally: characters, factions, and
  history that a GM can pick up and run with.
- **A graphic novel** — flagged as a future opportunity. The Option B
  reveal, the wave-commander voices, and the Pilgrimage imagery are
  strong visual-narrative material.
- **Young Adult fiction** — flagged as a future opportunity. The
  cadet-origin Academy framing and the identity themes ("what kind of
  player are you," "you have been fighting yourself") suit YA.

The Codex is the keystone: it is the artifact that makes the IP
portable across all of these. Build it well and every later medium
inherits a coherent, consistent world.

---

## Where to Go Next

The corpus, the Codex, and the open-questions sweep are all complete.
The project is at a genuine branch point — no single mandated next
task. Options, roughly in order of how naturally they follow from here:

1. **Start the UI / HUD track.** Map architecture is done. The objective
   panel is the recommended entry wedge — see Next track section above.
2. **Commit the map architecture work.** All ten phases of implementation
   plus the handoff doc edits are sitting uncommitted in
   `D:\AI\Cycle Four\src\core\map\`, `src/autoloads/`, `src/entities/`,
   `src/ui/`, and the planning directory. Worth a single big commit
   ("Complete map architecture refactor — phases 1–10") before the next
   session starts.
3. **The late-game balance pass.** One of the two remaining named
   design threads — Bio-Titan vs. Apex stat tuning, Tier 4–6 cost
   curves, Second Milestone tuning. `core/23` settled the *design* of
   these; this pass would settle the *numbers*.
4. **The audio/visual choreography pass.** The other remaining thread —
   the endgame cinematic, the Custodian, the Mesh inheritance
   handshake, the three Second Milestone cues.
5. **Start an adaptation.** The Codex makes the IP portable;
   `codex/11_adaptation-notes.md` sketches the tabletop, graphic-novel,
   and YA paths.
6. **Generate a native `.docx`** of the Codex, if a session ever runs
   on a machine with virtualization enabled.

---

## Open Design Threads

The loose open questions are now swept (`core/23`). What remains is a
small set of substantial threads — each real work in its own right:

- **Late-game balance & matchup math** — Bio-Titan vs. Apex stat
  lines, cross-sub-path tuning, Tier 4–6 cost curves, Second Milestone
  tuning. (`core/23` settled the design; this is the numbers.)
- **Audio/visual choreography** — endgame cinematic, the Custodian, the
  Mesh inheritance handshake, the Second Milestone cues.
- **Implementation architecture** — data-driven config, Godot
  scene/node structure, the save model, offline-resolution math.
- **Coalition commander writing** — the tier 26–50 recurring
  commanders; needs a short roster bible first (`core/23 §5`), then a
  writing session like Session 1.
- **Multiplayer / Option B PvP** — deferred until a single-player build
  exists.

`core/23 §4` holds the detailed Forward Queue — the playtest backlog
(with ship defaults), the build backlog, and the content/writing
backlog — for whoever picks up any of these.
