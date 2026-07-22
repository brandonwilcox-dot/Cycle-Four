# Map Architecture Planning Brief
## Cycle Four — Strategic Map System Design

**Purpose:** Planning brief for a Cowork design session.
This document describes the current map implementation, the design goals driving a
more capable system, and the open architectural decisions that need to be resolved
before building further.

---

## 1. Current State (What Exists)

The game runs on a **30×17 cell grid** (1,920×1,088 px at 64 px/cell). Each cell is
one of a fixed set of types stored in a flat integer array:

| Type | Value | Meaning |
|---|---|---|
| GROUND | 0 | Open land; claimable by the Commander |
| OBSTACLE | 1 | Tower footprint; blocks enemy movement |
| PATH | 2 | Pre-defined enemy corridor |
| BASE | 3 | Player FOB; enemy destination |
| SPAWN_W/N/S/E | 4–7 | Enemy spawn points (one per cardinal direction) |
| WALL | 8 | Impassable terrain (reserved, not yet used) |
| CLAIMED | 9 | Commander territory; generates passive income |

### What the current system does well
- Enemy AStar pathfinding works correctly; towers block and reroute enemies.
- Claimed cells generate passive income (flat rate per cell, additive).
- Flanker enemies target claimed territory and reroute dynamically.
- Production buildings can be placed on claimed cells for bonus income.

### What it cannot do
- A cell has exactly one type. There is no way to say "this cell is GROUND *and*
  is in a high-value resource zone *and* has a fog-of-war environmental modifier."
- The map layout is hardcoded in GDScript (`_build_default_paths()`). There is no
  data-driven map loader; every map change requires editing code.
- There is no concept of a strategic control point, a named zone, or a
  resource-multiplier region.
- Environmental conditions (hazard tiles, restricted access, biome-specific
  traversal rules) have no representation.

---

## 2. Design Goals (What We Need)

### 2a. Strategic Capture Zones
Instead of all GROUND cells being equal, certain regions of the map should carry
distinct strategic value:

- **High-yield zones** — cells that produce more resources per second when claimed
  (e.g., near a mineral vein, ancient ruin, or stellar relay).
- **Chokepoint zones** — narrow corridors where controlling even one cell blocks or
  taxes enemy flanking paths.
- **Hazard zones** — cells that cost extra resources or Commander HP to claim, or
  that periodically deal damage to buildings placed on them.

### 2b. Strategic Control Points
One or more designated cells per map that unlock a special bonus when claimed:

- Could unlock a new resource type, a building tier, a temporary buff, or a
  production rate multiplier.
- Enemy flankers should prioritise these cells over ordinary claimed territory
  (higher raid-threat, higher reward).
- Visual treatment must make them clearly distinct from ordinary GROUND.

### 2c. Map Variety
The game lore defines three factions across six sub-paths, a galaxy of distinct
star systems, and biome-specific environmental conditions. This implies:

- Potentially **dozens of distinct map layouts** — different path topologies,
  spawn configurations, zone placements, and base positions.
- **Faction-flavoured maps** — Architect maps might feature symmetrical gridded
  corridors; Bloom maps might have organic winding paths; Mesh maps might use
  overlapping signal-relay networks.
- **Biome modifiers** — per core/17_units-maps-buildings.md:
  - Architects/Standard: open terrain, long sightlines
  - Architects/Spiritual-Tech: ancient ruins as obstacles
  - Bloom/Purist: heavy canopy, limited tower placement zones
  - Bloom/Assimilator: terrain mutates mid-wave
  - Mesh/Networked: relay towers as map features
  - Mesh/Dreamer: fragmented terrain, isolated islands

### 2d. Environmental Factors
Conditions that change how cells behave dynamically or per-run:

- **Fog / limited visibility** (units not visible until the Commander is nearby)
- **Terrain mutation** (Bloom Assimilator: cells shift type mid-wave)
- **Relay dependency** (Mesh: a resource zone only generates if a relay building
  is connected)
- **Ruin interference** (cells near an active Ruins site have modified income until
  the Ruins are pacified — see core/18_ancient-pacification.md)

---

## 3. The Core Architectural Problem

The current cell-type array is a **single-layer representation**. A given cell can
only be one thing. The design goals above require that a cell simultaneously carry:

1. **Traversal class** — how enemies (and towers) interact with it (unchanged)
2. **Zone membership** — which named region it belongs to
3. **Strategic value** — resource multiplier, control-point flag, hazard level
4. **Environmental state** — current modifiers (fog, mutation, ruin proximity)

These are independent dimensions. They need to coexist without colliding.

---

## 4. Architectural Options

### Option A: Extend the Cell Type Enum
Add new type values for every combination needed:
`GROUND_HIGH_YIELD`, `GROUND_HAZARD`, `GROUND_CONTROL_POINT`, etc.

**Pros:** Simple, no new data structures, pathfinding unchanged.
**Cons:** Combinatorial explosion — with 4 zone types × 3 hazard levels × 2 flags
= 24+ new cell types. Adding environmental *state* on top makes this unmanageable.
Every new modifier requires new enum values and new match branches everywhere.
**Verdict:** Only viable for 1–2 additional modifiers. Does not scale to the design goals.

---

### Option B: Parallel Metadata Array
Keep the cell-type array for traversal logic. Add a second `_meta` array (same
30×17 size) where each cell stores a bitfield or small dictionary of properties:
zone ID, strategic value multiplier, control-point flag, hazard flag, environmental
state flags.

```
_cells[cell_id]  = GROUND  (traversal — unchanged)
_meta[cell_id]   = { zone: "mineral_vein", multiplier: 2.0, is_control_point: false, hazard: 0 }
```

**Pros:**
- Traversal logic and AStar are completely unaffected.
- Any number of modifiers can coexist on one cell.
- Environmental state can change at runtime without touching the traversal layer.
- Clean separation of concerns.

**Cons:**
- Two arrays to keep in sync.
- Map authoring now requires populating two structures — needs tooling or careful
  resource file design.
- Slightly more complex to query ("get all high-yield cells in range").

**Verdict:** Best fit for the design goals. Recommended baseline.

---

### Option C: Zone-Region Objects (No Per-Cell Metadata)
Instead of per-cell meta, define named rectangular (or polygon) *regions* as
separate objects. A cell's zone membership is resolved at query time by checking
which region it falls inside.

```
zones = [
  Zone { rect: Rect2(3, 3, 5, 4), type: "mineral_vein", multiplier: 2.0 },
  Zone { rect: Rect2(20, 10, 4, 4), type: "hazard", damage_per_wave: 5.0 },
]
```

**Pros:**
- Maps are very compact to author (define a few rectangles, not 510 cells).
- Easy to visualise and hand-tune in a resource file or editor.
- Regions can be animated or shifted at runtime.

**Cons:**
- Per-cell queries require iterating regions (manageable if there are <20 regions).
- Irregular zone shapes require polygon support or multiple rectangles.
- Environmental *per-cell* state (e.g., individual cells mutating) still needs
  per-cell storage somewhere.

**Verdict:** Good complement to Option B — use regions for zone definition,
per-cell meta for runtime state. Can be combined.

---

### Option D: Data-Driven Map Resource Files
Separate from the metadata question, the map *layout* (path topology, spawn
positions, zone placements) needs to move out of hardcoded GDScript and into
loadable resource files. Two sub-options:

**D1: Godot TileMap authoring**
- Design maps visually in Godot's TileMap editor.
- Each tile layer corresponds to one data layer (traversal, zones, etc.).
- Export/bake to the cell arrays at runtime or build time.

  Pros: WYSIWYG editor, fast iteration, visual feedback.
  Cons: Requires setting up tile sets and export pipeline; locks map authoring
  to the Godot editor.

**D2: Structured resource files (.tres / .json)**
- Each map is a `MapData` resource: arrays of cell types, zone definitions,
  spawn configs, faction tags, biome ID.
- MapGrid loads the resource in `_ready()` instead of running `_build_default_paths()`.

  Pros: No editor dependency, maps can be generated procedurally, easy to version
  in git, scriptable from outside Godot.
  Cons: No visual editor — must author cell arrays by hand or write a separate
  authoring tool.

---

## 5. Questions to Resolve in This Design Session

The following decisions shape everything downstream. They should be answered
before any new map code is written.

### Q1. What is the metadata model?
Which combination of Options B, C, D best fits the project?
- Per-cell metadata array (Option B) for runtime state?
- Zone-region objects (Option C) for authored strategic areas?
- Both combined?

### Q2. What is the map authoring workflow?
- TileMap editor (Option D1) or structured resource files (Option D2)?
- Who authors maps — is it always the developer, or should it be accessible to
  a designer without deep Godot knowledge?
- Do maps need to be generated procedurally at any point, or are they always
  hand-authored?

### Q3. What are the control point rules?
- How many control points per map (1? 2? variable)?
- What bonus does capturing a control point unlock?
- Do control points reset between waves, or are they permanent until raided?
- Can the enemy "own" a control point (e.g., if a flanker raids it)?

### Q4. What is the resource zone model?
- Flat multiplier on income rate (e.g., 2× per second per claimed cell in zone)?
- Unlocks a new resource type entirely?
- Applies only to buildings placed in the zone, not bare claimed cells?
- Does zone value decay if the zone is partially raided?

### Q5. What is the environmental modifier model?
- Are modifiers static per map (defined in map data) or dynamic per run?
- Which modifiers are visual-only vs. mechanical?
- Do modifiers interact with faction sub-paths (e.g., Bloom/Assimilator terrain
  mutation is a faction-specific mechanic, not a general map feature)?

### Q6. How do maps relate to the galaxy layer?
- Is each star system a fixed map, or does the map layout vary per run?
- Do faction-specific biomes map 1:1 to sub-paths, or can any faction play
  any biome map?
- Does the galaxy meta-progression (see core/20_galaxy-strategy.md) unlock
  new maps, or just change modifiers on existing maps?

### Q7. What is the minimum viable map set for the first playable build?
- How many distinct maps are needed before the game is worth playtesting?
- Can the current hardcoded map serve as "Map 001" with a data-driven
  version created in parallel?

---

## 6. Relevant Design Documents

The following existing design docs contain decisions relevant to this session.
Reading them before or during the session will prevent conflicts with established lore.

| Document | Relevant Sections |
|---|---|
| `core/17_units-maps-buildings.md` | Standard map topology, biome modifiers per sub-path, Ruins placement rules |
| `core/18_ancient-pacification.md` | How Ruins sites interact with claimed territory and income |
| `core/20_galaxy-strategy.md` | Galaxy-scale map progression, faction relationships to territories |
| `core/22_interface-design.md` | How map state (zones, control points) should be communicated in the HUD |
| `core/23_open-questions-resolved.md` | Forward queue: which map/balance decisions are still open |

---

## 7. Constraints (Non-Negotiable)

These are hard constraints from the existing implementation that any new map
system must respect:

1. **AStar graph must not change shape mid-wave** — rebuilding the AStar graph
   while units are navigating causes rerouting errors. Zone/meta changes at runtime
   must not touch traversal cell types.
2. **CLAIMED cell logic is tied to cell type 9** — flanker pathfinding, territory
   income, and building placement all check `cell == 9`. Any zone system must
   preserve this check or update all three systems simultaneously.
3. **No per-frame full-grid scans** — the recent flanker crash was caused by
   O(claimed × path) work per frame. Any new query pattern (e.g., "find all
   control point cells") must be cached or bounded.
4. **Maps must be loadable without scene reload** — if the galaxy layer allows
   moving between star systems, maps may need to hot-swap. The current hardcoded
   approach cannot support this.

---

*Generated: 2026-05-27*
*Project: Cycle Four | Engine: Godot 4.6.1 | Working directory: D:\AI\Cycle Four*
