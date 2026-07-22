# Map Architecture Implementation Handoff
## Cycle Four — From Single-Layer Grid to Multi-Layer System

> **Status:** Decisions landed. Ready for implementation.
> **Audience:** Claude Code, working in the Godot 4.6.1 project at `D:\AI\Cycle Four`.
> **Supersedes:** the open questions in `planning/map-architecture-brief.md §5`.
> **Honors:** every hard constraint in `planning/map-architecture-brief.md §7`.
> **Generated:** 2026-05-27

---

## 0. Purpose and How to Use This Document

This is the architectural specification for replacing the current hardcoded 30×17 cell grid with a multi-layer, data-driven map system. It is the result of a multi-round design session and is meant to be read in full before any production code is touched, then referenced section-by-section during implementation.

Two reading orders are supported. For a fast orientation, read §1 (TL;DR), §10 (constraints preserved), and §11 (migration plan). For deep implementation, read top-to-bottom; every section is referenced by at least one migration phase.

This document specifies the *technical* layer — data structures, subsystems, pathfinding, migration order. It is deliberately silent on *content* — what specific objectives a faction has on a given map, what bonus a control point unlocks, how many maps the MVP ships with. Content design is downstream of this architecture and lives in the core design corpus (`core/17`, `core/18`, `core/20`, `core/22`, `core/23`). Always cross-check content decisions against those docs before inventing new canon.

---

## 1. Decision Summary (TL;DR)

One-line decisions, in the order they cascade:

1. **Metadata model:** Combined Option B (per-cell meta array) + Option C (zone-region objects). Cell array stays as the traversal layer; zone-regions hold authored strategic intent; per-cell meta holds runtime state. A cached cell→zone reverse index makes lookups O(1).
2. **Authoring workflow:** Option D2 (structured `MapData` resource files), procedurally generated with strict accessibility guardrails. TileMap is not part of the primary pipeline.
3. **Data hierarchy:** Galaxy → Branch → Sector → **System → Map**. A `SystemData` container wraps one or more `MapData` instances; hot-swap operates within a system as well as across systems.
4. **Spawn points:** A list of objects with state, not enum cells. SPAWN_W/N/S/E is replaced by `spawn_points: [SpawnPoint]`. Sealed status is *derived* from objective completion, not stored.
5. **Fog-of-war:** First-class, per-cell meta field. Commander vision drives reveal; reveal events activate dormant spawns.
6. **Objectives:** A first-class subsystem, keyed by both **faction and sub-path**. Drive spawn sealing, map completion, and HUD state.
7. **Pathfinding:** Two AStar instances. Enemy AStar is immutable per wave (honors Constraint #1). Friendly AStar mutates as territory expands.
8. **Support graph:** Buildings as nodes, paths as edges, on top of the friendly cell layer. Connectivity is incrementally maintained, not rescanned per frame.
9. **Convoys:** A new entity class. Attrition starves research; total support loss fails the map.
10. **Progression:** Two coexisting curves — defensive structures level up (combat scaling), support/research units gain XP (organic improvement).
11. **Pressure model:** Reactive. Player activity (reveal, build, claim, objective progress) drives the wave generator. Idle is quiet. Baseline trickle remains.
12. **Persistence:** Systems are persistent once secured. Map state persists across map switches within a system. The only way a sealed system reopens is the late-game endgame threat (canon: silence vector / Arrival, `core/14` + `core/20`).

---

## 2. The Data Architecture

### 2.1 Layer overview

Five peer layers make up a fully-loaded map. They sit inside `MapData`, which sits inside `SystemData`. Each layer has a distinct write-rate and a distinct purpose.

| Layer | Purpose | Write-rate | Reset boundary |
|---|---|---|---|
| Cell type array | Enemy traversal class | Never mid-wave | Per-map authoring |
| Zone-region list | Authored strategic intent | Never at runtime | Per-map authoring |
| Per-cell meta array | Dynamic runtime state | Event-driven, occasional per-second | Per-run (some fields per-wave) |
| Friendly path graph | Convoy routing, connectivity | On territory change | Per-run within a map |
| Entity records | Convoys, towers, support/research units | Per-tick (entities) | Mixed |

The cell type array preserves the current 30×17 (parameterizable) integer layout — enemy AStar is unaware that any other layer exists. Constraints #1 and #2 (AStar shape immutability mid-wave, CLAIMED=9) are satisfied at this layer alone.

### 2.2 SystemData

Top-level loadable resource. Represents one star system.

Fields:
- `system_id: StringName` — stable across patches (see Build backlog: stable procedural seeds, `core/23 §4`).
- `name: String` — display name.
- `maps: Array[MapData]` — one or more playable maps in this system (planets, moons).
- `system_objectives: Array[Objective]` — objectives that span multiple maps. The system is "complete" when all are met.
- `secured: bool` — derived from objective state. Once true, the system is owned by the player and quiet, unless the endgame threat invades.
- `biome_template_refs: Array[StringName]` — which biome templates this system's maps draw from. A system in the galactic core has different biome odds than one in an outer arm.
- `faction_presence: Dictionary` — which NPC factions have territory or interest in this system. Drives some objective generation.

### 2.3 MapData

A single playable map (one planet or moon). Loadable resource. Procedurally generated, persisted once generated.

Fields:
- `map_id: StringName` — unique within the parent system.
- `dimensions: Vector2i` — defaults to (30, 17), parameterizable.
- `biome: StringName` — set at generation, drives modifiers (see `core/17 §9`).
- `topology_template: StringName` — which canonical topology this map was generated from. Per `core/17 §8`, topology is constant in spec; templates parameterize variations like single-vs-dual-Ruins (~88/12 split, `core/17 §8`).
- `cell_types: PackedByteArray` — flat array, length = dimensions.x * dimensions.y. Existing enum values (GROUND/OBSTACLE/PATH/BASE/WALL/CLAIMED). SPAWN_* values are no longer used here; see §2.5.
- `zones: Array[ZoneRegion]` — see §2.6.
- `meta: PackedByteArray` or `Array[CellMeta]` — per-cell meta field; see §2.7. Implementation choice between bitfield and dictionary depends on the final field set, but the field set is small enough that a bitfield with a per-field accessor API is recommended.
- `spawn_points: Array[SpawnPoint]` — see §2.5.
- `support_graph: SupportGraph` — see §2.8.
- `objectives_by_faction_subpath: Dictionary` — keyed by `(faction_id, subpath_id)` → `Array[Objective]`. Resolved at run start against the active player's selection.
- `ruins_sites: Array[RuinsSite]` — typically 0–2 per map per `core/17 §8`; canonical state machine in `core/18`.

A `MapData` resource is *self-contained* — it can be saved and reloaded to restore the map's runtime state (claimed cells, biomass spread, hacked nodes, etc.). Cross-map persistence within a system is implemented by saving each `MapData` snapshot back into its parent `SystemData` on map switch.

**Note on tick-relative fields:** The per-cell meta field `hacked_until_tick` (§2.7) stores a wave-tick deadline, not a duration. This value is meaningless without the current tick count. Every `MapData` snapshot saved during a run must include a `current_wave_tick: int` alongside it, or `hacked_until_tick` must be cleared to 0 on map switch. Recommended: include `current_wave_tick` in the snapshot; clearing it silently discards active hack state, which may be undesirable if a Mesh player mid-combo switches maps and back.

### 2.4 ObjectiveData

Each objective is a small object. Faction-and-sub-path keyed. Lives on `MapData.objectives_by_faction_subpath` or `SystemData.system_objectives`.

Fields:
- `objective_id: StringName`
- `description: String` — for HUD/UX.
- `kind: ObjectiveKind` — enum: SURVEY_RUINS, ESTABLISH_BIOMASS_COVERAGE, PLACE_RELAY_COVERAGE, ELIMINATE_SPAWN, HOLD_CONTROL_POINT, etc. The kind set is canonical; new kinds require a schema bump.
- `target: int` — quantitative target where applicable (e.g., 3 of 5 ruin sites).
- `progress: int` — current value.
- `complete: bool` — derived; `progress >= target`.
- `seals: Array[StringName]` — which spawn point ids this objective's completion seals.
- `tracked_refs: Array` — references to map state this objective reads from (specific zone-region ids, spawn point ids, cell sets).

The objective subsystem owns evaluation. On any tracked-state-changed event, the relevant objectives re-evaluate. Completion fires a signal the spawn system and HUD subscribe to.

### 2.5 SpawnPoint

Replaces the old SPAWN_W/N/S/E cell types. Lives in `MapData.spawn_points`.

Fields:
- `id: StringName`
- `position: Vector2i` — cell coordinates.
- `axis: SpawnAxis` — enum: PRIMARY, SECONDARY, TERTIARY (mirrors the canonical axes from `core/17 §8`).
- `activation_trigger: ActivationTrigger` — enum: ALWAYS_ON, ON_REVEAL, ON_BUILD_THRESHOLD, ON_OBJECTIVE_PROGRESS, ON_TIMER. Most spawns are ON_REVEAL — they activate when the commander reveals the cell or its vicinity.
- `state: SpawnState` — enum: DORMANT, ACTIVE, SEALED, PERMANENTLY_SEALED. Derived live. DORMANT if activation trigger has not fired. ACTIVE if trigger has fired and spawn is not sealed. SEALED if all referenced objectives are currently complete — but this is *conditional*: any referenced objective that lapses (regresses) causes the spawn to revert to ACTIVE. PERMANENTLY_SEALED is set by a broadcast from the map-completion signal (§6.3) and cannot be reversed by objective lapse. Before map completion, SEALED is always conditional.
- `seal_condition_refs: Array[StringName]` — derived at map load from `ObjectiveData.seals`; do not author this field directly (see §2.7a note on single source of truth). Empty means this spawn never seals (a Forever spawn — reserved for endgame-threat invasions).

The spawn manager polls state at a low cadence (e.g., on objective-changed signal) and pushes activation events to the wave generator.

### 2.6 ZoneRegion

Authored strategic regions. Immutable at runtime once a map is generated. Stored as `Array[ZoneRegion]` on `MapData.zones`.

Fields:
- `id: StringName`
- `kind: ZoneKind` — enum: MINERAL_VEIN, HAZARD, LEY_CLUSTER, CONTROL_POINT, TERTIARY_INCURSION, BIOMASS_PROHIBITED (e.g., sterile volcanic, sterile concrete), RELAY_REQUIRED (Mesh Cold-Sink zones), ANCIENT_PATH_CROSSING (cells where an ancient convoy route and an enemy traversal path overlap or are immediately adjacent — placed at generation, serves as a natural chokepoint), and a small open extension set.
- `shape: ZoneShape` — a Rect2i or an Array[Vector2i] (cell list) for irregular shapes. Rect first, polygons via the cell list when needed.
- `modifier: float` — generic numeric tag; meaning depends on `kind` (e.g., income multiplier for MINERAL_VEIN, damage-per-wave for HAZARD).
- `flags: int` — bitfield: faction-keyed bonuses, build-permitted, construction-cost-modifier (+50% on tertiary points per `core/23 §2/core/17 Q5`), commander-claim-cost-modifier.
- `linked_ruins_id: StringName` — for LEY_CLUSTER zones, the Ruins site they cluster near. Per `core/17 §8`, ley node density is proportional to the linked Ruins' importance.

Zones do not store cell membership directly. The reverse index (§2.10) handles cell→zone lookup.

### 2.7 Per-cell meta array

Per-cell runtime state. Same dimensions as the cell type array. Implemented as a bitfield with named accessor methods.

Fields (initial set; small, extensible):
- `revealed: bool` — fog-of-war.
- `claimed_by: u4` — faction id of the claimant, 0 = unclaimed. (See §2.7a for why claimed status appears in both this array and the cell type enum.)
- `biomass_progress: u4` — 0–15, ticks up when Bloom mechanics convert the tile. At max, the tile counts as full biomass for income/movement-slow purposes.
- `hacked_until_tick: u16` — wave-tick deadline for Mesh Hacked Node status; 0 if not hacked.
- `ruins_proximity_strength: u4` — cached effect of the active Ruins' state machine on this cell, recomputed when the Ruins phase changes.
- `relay_covered: bool` — Mesh relay coverage flag; affects Cold-Sink production and other relay-dependent mechanics.

Total: 30 bits per cell (1+4+4+16+4+1). A packed u32 per cell holds all fields with two bits to spare; two packed u16s are an equivalent alternative. Memory footprint at 30×17 is under 2KB regardless of packing strategy.

#### 2.7a Why CLAIMED appears in two layers

The cell type enum still has CLAIMED=9 because the existing flanker pathfinding, income, and placement logic all check `cell == 9` (Constraint #2). The per-cell meta also stores `claimed_by` because *who* claimed the cell matters for future mechanics (faction-keyed bonuses, multiplayer-readiness, raid-vs-recapture).

Rule: cell type 9 is the *binary* claimed flag; `claimed_by` is the *attribution* field. Any change to claimed status must update both atomically — wrap in a single function (`set_claim(cell, faction_id)` / `clear_claim(cell)`) used everywhere; do not write either field directly elsewhere.

### 2.8 Friendly path graph (SupportGraph)

A graph layer that models the logistics web. There are two categories of edge in this graph, reflecting the setting's history: **ancient paths** pre-placed at map generation (trade roads, relay corridors, Inca-scale infrastructure left by prior inhabitants), and **player-built connections** the commander establishes during a run. Both travel on the same graph but behave differently at generation time.

Ancient paths are the primary convoy surface. They follow terrain logic of their own — not the enemy traversal grid — and will often cross or run parallel to enemy advance routes. Where an ancient path cell overlaps or immediately borders an enemy-traversal cell, the generator places an `ANCIENT_PATH_CROSSING` zone (§2.6) at that position. These crossings are natural chokepoints: a player who holds them protects both the convoy line and the enemy advance corridor simultaneously.

Structure:
- `nodes: Dictionary[StringName, BuildingNode]` — keyed by building id. Each node has position, building type, current HP, and connectivity status (`connected_to_fob: bool`).
- `edges: Array[PathEdge]` — each edge has: two endpoint node ids, `kind: PathEdgeKind` (ANCIENT / PLAYER_BUILT), `discovered: bool`, a list of cell coordinates the path covers, and a current health/intactness value.
- `fob_node_id: StringName` — the root.

**Ancient path discovery:** Ancient path edges start with `discovered: false`. They are pre-loaded into the SupportGraph at map load but are inactive — convoys cannot route on them and they do not appear on the HUD. When the commander's vision radius reveals a cell that belongs to an ancient path edge, that edge transitions to `discovered: true` and becomes available for convoy routing. This fires a `path_discovered(edge_id)` event; the HUD subscribes to highlight the new route segment.

**Player-built connections:** Placed by the player as territory expands. Always start `discovered: true`. Can connect buildings that no ancient path reaches. Player-built edges fill logistics gaps; ancient paths are the spine.

Connectivity is maintained incrementally:
- On `add_node` or `add_edge` (or `path_discovered`): run a single BFS from the new node to the FOB; mark `connected_to_fob` accordingly.
- On `damage_edge` or `remove_node`: run a bounded BFS from the affected subgraph; update only nodes whose connectivity might have changed.

Convoys route exclusively on this graph (§3.2). The commander does not route on the SupportGraph.

### 2.9 Entity records

Three new entity classes, each with their own update loop. Implemented as nodes (or pooled objects) outside `MapData` — `MapData` stores spawn-position references, not entity instances.

- **Convoy** — fields: `route: Array[Vector2i]`, `cargo: ResourceType`, `hp: int`, `from_node: StringName`, `to_node: StringName`, `progress_along_route: float`.
- **DefensiveStructure** (subclass of building entity) — fields: `level: int`, `xp_to_next_level: int`, `scaling_curve_ref: StringName`. Levels up to track wave strength.
- **SupportUnit** / **ResearchUnit** — fields: `xp: float`, `proficiency: float`, `role: SupportRole`. Gain XP from work performed (idle ticks at a station, successful convoy completions, research tasks). Proficiency curve is continuous, not step-function.

### 2.10 Cell → zone reverse index

Built at map load. Rebuilt only on map hot-swap. Never rebuilt mid-wave.

Structure: `Dictionary[Vector2i, Array[StringName]]` — cell coordinate → list of zone ids the cell belongs to (a cell may be in multiple zones, e.g., a MINERAL_VEIN inside a LEY_CLUSTER).

This is the answer to Constraint #3 (no per-frame full-grid scans). All zone-membership queries are O(1) lookup followed by O(zones_on_cell) iteration, which in practice is 0–2 entries.

A parallel inverted index `zone_id → Array[Vector2i]` is also built for "give me all cells in zone X" queries (e.g., HUD overlays, flanker priority lists).

---

## 3. Pathfinding — Two AStar Instances

### 3.1 Enemy AStar (immutable per wave)

The existing AStar instance, unchanged in shape during a wave. Built at wave start from the current cell type array. Tower placement between waves may change the next wave's AStar; placement during a wave updates the *next-wave* AStar copy, not the live one.

This honors Constraint #1 absolutely. Do not loosen it.

### 3.2 Friendly AStar (mutable, expands with territory)

A second AStar instance, independent of the first. Reflects claimable / claimed cells the **commander** can traverse during exploration. Mutates as territory expands or contracts:

- Cell becomes CLAIMED → add to friendly graph.
- Cell loses CLAIMED status (raid) → remove from friendly graph.

**Routing surface split — commander vs convoys:** The commander and support units move on this AStar instance. Convoys do *not* use this instance — they route exclusively on the SupportGraph edge network (§2.8). This mirrors the design intent: the commander blazes a trail through unknown territory; once a path is discovered, convoys operate on that established route. The two surfaces are independent and can diverge significantly — the commander may cross terrain a convoy could never reach.

The consequence of this split: discovering an ancient path (§2.8) does not require the commander to walk the full length of it. Once any cell of an edge is within vision radius, the full edge activates. The commander is the scout; the SupportGraph is the logistics infrastructure that follows.

### 3.3 Path-cut detection

When a flanker damages a path cell, the affected `PathEdge` health drops. Below a threshold (config), the edge is marked invalid. The connectivity maintainer runs a bounded BFS from the orphaned subgraph; any building node that loses `connected_to_fob` enters a "stranded" state.

Stranded buildings:
- Cannot send or receive convoys.
- Their per-second economic contribution stops (Architects lose research throughput, Bloom loses growth rate, Mesh loses signal quality — faction-keyed effect lives in the building/faction rules layer, not the graph itself).
- They remain visible on the HUD with a "stranded" indicator (`core/22 §6` notification system; this is a soft-interrupt notification, not modal).

Reconnecting (repairing the path or routing around it) restores the building.

### 3.4 Connectivity caching

The connectivity state (`connected_to_fob` per node) is cached. It updates only on graph change events, never on a polling loop. This is the friendly-side answer to Constraint #3.

---

## 4. Spawn Point System

### 4.1 Authoring: list, not enum

`MapData.spawn_points` is an authored list. Procedural generation places spawns according to the topology template's rules: primary-axis terminus always has one, secondary-axis spawns optionally, tertiary-incursion sites at 2–4 per map (`core/17 §8`).

Spawn count varies per map. A small moon might have one spawn. A contested planet might have many.

### 4.2 Activation triggers

Default trigger is `ON_REVEAL`: the spawn activates when the commander reveals it (or a cell within a configurable proximity radius). This makes exploration the primary lever for pressure modulation.

Other triggers (used sparingly): `ALWAYS_ON` for the starting wave-axis spawn; `ON_BUILD_THRESHOLD` for spawns that activate when the player's economy crosses a value; `ON_OBJECTIVE_PROGRESS` for spawns that activate in response to objective milestones; `ON_TIMER` for fallback if all else fails.

### 4.3 Sealing: conditional until map completion

A spawn's SEALED/ACTIVE state is computed live from its `seal_condition_refs` (derived from `ObjectiveData.seals`). If every referenced objective is currently complete, the spawn is SEALED. If any referenced objective lapses (regresses — e.g., a captured control point is retaken), the spawn reverts to ACTIVE immediately.

This conditional sealing is intentional: until the full objective set is satisfied, no seal is permanent. The player may seal multiple spawns while completing the map, but a lapse anywhere can reopen a previously-quiet front. Establishing chokepoints at `ANCIENT_PATH_CROSSING` zones (§2.6) is the primary mitigation — a held crossing controls both the convoy route and the enemy advance path simultaneously.

Once all objectives on the map are complete, the `map_completed` signal fires (§6.3). The spawn manager subscribes and transitions every currently-SEALED spawn to PERMANENTLY_SEALED in a single pass. PERMANENTLY_SEALED cannot be reversed by objective state — it is a one-way terminal transition driven by map conditions, not a timer.

There is no separate "seal the spawn" player action. The spawn-as-physical-location goal ("reach and hold this spawn") is implemented by tying the relevant objective's progress condition to the commander reaching or controlling that spawn cell. The objective is the truth; the spawn state is the visible consequence.

### 4.4 Fog reveal as activation source

Per §5, fog reveal events fire to the spawn manager. The spawn manager checks any DORMANT spawns with `activation_trigger = ON_REVEAL` against the revealed region; matches transition to ACTIVE and notify the wave generator.

---

## 5. Fog-of-War

### 5.1 Per-cell revealed status

`meta.revealed` is the per-cell flag. Initial state at map load: all unrevealed except the safe zone around the FOB (per `core/17 §8`: 3 resource nodes always reachable, this region starts revealed).

### 5.2 Commander vision radius

The commander unit has a `vision_radius: int` (cells). Each tick the commander moves, cells within radius transition to revealed. Revealed is permanent within a map session — once seen, always seen (subject to fog re-application from specific enemy mechanics, deferred to later content design).

Performance: the per-tick reveal pass is bounded by the vision radius squared, not the grid size. No full-grid scan.

### 5.3 Reveal events feeding the wave generator

Each newly-revealed region fires a `region_revealed` event with the cell list. The spawn manager (§4.4) and the wave generator (§9.1) both subscribe.

### 5.4 Entity visibility under fog (Phase 8 clarification)

Cell-level fog hides cell rendering — but the canonical rule extends to **anything moving through a cell**. Enemy units, friendly convoys, and (future) flankers are hidden from rendering whenever their current cell is unrevealed. The check is a per-frame `visible = map_data.get_meta_revealed(cell_idx)` against the entity's current cell. This is what produces the canonical "emerging from the fog" feel: an enemy wave spawning at `(0, 8)` walks invisibly along the western corridor and only appears once it crosses into the player's revealed zone near the FOB.

Player infrastructure that lives **on** a cell rather than moving across it (depots, spawn markers, FOB) follows the same rule: render only if the cell is revealed. The FOB is the exception because it lives inside the always-revealed safe zone.

### 5.5 Depot markers (Phase 8 clarification)

Non-FOB `BuildingNode`s in the SupportGraph render as a small inset amber square in their cell — distinct from spawns (red) and FOB (green) — so the player can recognise "important spot" at a glance. Fog rule applies (invisible until revealed). Future placeholder for richer building art.

---

## 6. Objectives Subsystem

### 6.1 Faction + sub-path keying

`MapData.objectives_by_faction_subpath` is a 2D-keyed dictionary. At run start, the player's `(faction, sub_path)` selection picks a single objective list. The same map plays differently per sub-path — Architects/Standard might survey ruins for efficiency data while Architects/Spiritual-Tech surveys for ley resonance. Authoring effort scales with `factions × sub_paths × maps` (3 × 2 × N) but the replayability win is the reason.

### 6.2 Progress tracking

The objective evaluator subscribes to relevant world events (cell claimed, zone occupied, ruin pacified, building constructed, enemy killed, etc.). On each event, only objectives that reference the changed state re-evaluate. Progress fields update; completion fires a signal.

### 6.3 Map completion condition

A map is "complete" when every objective in the active list is `complete = true`. Completion fires a `map_completed` signal. Two systems subscribe:

1. **Spawn manager** — transitions every SEALED spawn to PERMANENTLY_SEALED (see §4.3). This is condition-driven, not timer-driven: the signal fires the moment the last objective completes, not after a delay.
2. **System manager** — evaluates whether system-level objectives (`SystemData.system_objectives`) are met; if so, transitions the system to `secured = true`.

The permanent seal is a consequence of the condition being met, not a separate confirmation step. No timer, no modal prompt — the world state updates as a direct result of the objective broadcast chain.

### 6.4 Spawn sealing trigger

The objective subsystem emits per-objective `objective_completed` / `objective_lapsed` events. The spawn manager subscribes and re-derives spawn state. See §4.3.

### 6.5 HUD hookup

Per `core/22 §6` (HUD design), the objective panel is a contextual panel — not always visible, summoned by the player. The HUD subscribes to `objective_progress_changed` events to update displayed progress; completion fires a soft-interrupt notification (`core/22` notification system).

---

## 7. Convoy + Support Building System

### 7.1 Building-as-node graph

See §2.8. Each support building is a node. Roads/paths connecting them are edges. The FOB is the graph root.

Support buildings are placed by the player as territory expands. The player chooses to expand; the *consequence* of expansion is needing more logistics infrastructure to feed the new perimeter. This enforces scale — bigger territory needs more graph.

### 7.2 Convoy entity type

A convoy is a **persistent round-trip ferry**: spawned **once** when a non-FOB node first connects to the FOB via discovered/built edges, then loops forever between the two endpoints — depot → FOB (loaded, delivers cargo on arrival) → pause → FOB → depot (returning empty) → pause → repeat. There is **not** a steady stream of convoys spawning on a tick; there is one persistent convoy per depot, with cargo throughput defined by its loop time and pause durations. Movement follows the edge cells (§2.8); convoys do not use the friendly AStar.

Convoy properties (recap from §2.9): `route_world` (the edge cells in world coords), `cargo`, `hp`, endpoints, direction (+1 forward, -1 reverse), pause timer. HP is small — convoys are not combatants, they die to a single flanker engagement most of the time (Phase 8b). When a convoy dies, ConvoyManager respawns a replacement at the depot.

### 7.3 Attrition and economic effect

Each successful convoy completion contributes to the receiving building's economic output (research throughput, growth, signal quality, etc.). Each failed convoy is a lost contribution.

Cumulative convoy loss is tracked. The economy subsystem aggregates `convoy_throughput_per_minute` and compares it against the threshold needed to sustain current research/production levels.

### 7.4 Map-failure threshold

If `convoy_throughput_per_minute` falls below the sustenance threshold for a configurable duration, support collapses. Affected support/research units start to deplete (this is the "economy can't support new researchers" failure mode). If support hits zero and cannot be re-established, the map fails — distinct from FOB destruction (instant fail) and Collapse (intentional run end).

A map-failure event is currently undefined in canon. Likely handling: the player is forced to retreat from the system with a partial-progress save state. Specific UX is deferred; the architecture just needs to support the failure path.

---

## 8. Two Progression Curves

### 8.1 Defensive structures (level-based)

Defensive structures (Sentry Spires, Plasma Bastions, etc., per `core/17`) level up to keep pace with the wave strength curve. Combat scaling is tier-based, step-function — explicit `level: int` and a lookup table for level-N stats.

Leveling is earned by combat work — damage dealt, kills credited, waves survived. The specific formula is balance work, deferred. The data structure (`level`, `xp_to_next_level`, lookup table reference) is what the architecture provides.

### 8.2 Support / research units (XP-based)

Support and research units improve continuously, not in steps. They "learn on the job" — proficiency rises with successful tasks (convoy deliveries, research tasks completed, hours spent at station).

Continuous proficiency means a multiplier on output rather than a tier jump. Curve shape (logarithmic vs sigmoid, cap, decay-on-death) is balance work, deferred.

Death is a significant setback per the design intent. When a support/research unit dies, its accumulated proficiency is lost — the replacement starts at baseline. This is the "death is a setback" lever; the architecture needs to enforce that proficiency does not transfer.

### 8.3 Commander and FOB progression (Phase 9 extension)

The handoff originally scoped progression to defensive structures and support units. Implementation surfaced that the player wants the same visible-rank pattern on the **Commander** and the **FOB** too — every entity-with-character on the board gets an "I'm getting better at this" loop.

- Commander rank advances per cells claimed (every 25 by default). Rank adds a small multiplicative speed bonus (+5%/rank) and damage bonus (+10%/rank) to the Commander's primary and secondary attacks.
- FOB rank ("fortification") advances per cargo received from convoys (every 10 by default). Stat effect TBD — earmarked for HP regen or defense bonuses in a future balance pass.
- A reusable `ProgressionBar` widget renders a small green fill above each ranking entity so the player sees the loop closing.

### 8.4 Cross-map persistent upgrade trees (future)

A future system, not yet specified: each ranking entity (Commander, Convoys, Towers, Support structures, FOB) gets a **player-chosen upgrade tree** whose choices **persist across maps** as the story progresses. This is distinct from per-run rank: it's the meta-progression that travels between worlds with the player.

Implications when this lands:
- `GalaxyManager` or `SaveManager` owns the persisted tree state.
- Tree nodes are unlocked by accumulated rank and/or specific in-map milestones (objective completions, ruins pacified, etc.).
- Loadout selection at run start picks which unlocked branches to activate this run.

Design space to settle when this phase opens: tree shape (linear vs branching vs tag), respec policy, how unlocks gate by Memory Tier, and how cross-map persistence interacts with the Collapse/prestige reset.

### 8.5 Unit traits and abilities (memo)

Deferred design conversation: the Tier 1-6 unit roster from `core/17` and `core/21` will need each unit's distinguishing **traits** (innate stats and resistances) and **active/passive abilities** spelled out. The current scaffolding treats units as a single damage/HP envelope; rich differentiation is a content-design pass that should run before the vertical-slice build.

---

## 9. Reactive Wave Generator Hooks

### 9.1 Events to expose

The map architecture exposes events the wave generator subscribes to:

- `region_revealed(cells)` — fog reveal.
- `spawn_activated(spawn_id)` — derived from §4.
- `cell_claimed(cell, faction_id)`.
- `building_constructed(building_id, kind, position)`.
- `objective_progressed(objective_id, old_progress, new_progress)`.
- `objective_completed(objective_id)` / `objective_lapsed(objective_id)`.
- `support_path_cut(edge_id)` / `support_path_restored(edge_id)`.
- `convoy_destroyed(convoy_id, by_unit_id)`.

The wave generator owns its own logic; the architecture's job is just to surface the right events at the right cadence.

### 9.2 Baseline trickle vs activity-driven pressure

The wave generator maintains a baseline pressure curve (the existing POC's trickle). On top of that, activity events stack additional pressure: revealing a region releases a chunk of pent-up pressure into the newly-active spawn; building a critical structure draws a probe; expanding claim territory across thresholds invites flankers.

Offline / idle behavior is governed by a quietness rule: in the absence of activity events for a configurable window, the wave generator drops back to baseline, then below baseline. The player returning to an undisturbed map should find it quiet.

### 9.3 Flanker target selection feed

Flankers are rare-spawn specialists with intent. They consume a `valuable_targets` query each time one spawns. The query is computed from the zone-region list, the per-cell meta, and the building entity registry:

- High-yield claimed cells (zones with `MINERAL_VEIN` kind, cells where `claimed_by` matches player).
- Control points and tertiary incursion sites (zones with `CONTROL_POINT` / `TERTIARY_INCURSION` kind).
- Support path bottlenecks (edges whose removal would disconnect the most nodes).
- High-cost player buildings (Compilers, Wardens, etc., per `core/17`).

The query is cached and invalidated on relevant events (zone-membership changes, building added/removed, path graph changes). Bounded; satisfies Constraint #3.

---

## 10. Hard Constraints Preserved

Per `planning/map-architecture-brief.md §7`. Each constraint and how this architecture honors it:

### 10.1 AStar graph must not change shape mid-wave

The enemy AStar instance (§3.1) is built from the cell type array. The cell type array does not change mid-wave under this architecture. Zone-regions are immutable. Per-cell meta changes never touch cell types. Friendly AStar (§3.2) is a separate instance; its mutability does not affect enemy pathing.

**Preserved.**

### 10.2 CLAIMED cell logic tied to cell type 9

Cell type 9 (CLAIMED) is retained. Existing flanker pathfinding, income, and placement code continues to check `cell == 9` and continues to work. The `claimed_by` field in per-cell meta is an *attribution* layer that supplements but never replaces the type-9 check (see §2.7a).

**Preserved.** Migration phase 2 includes a parity test confirming no existing behavior breaks.

### 10.3 No per-frame full-grid scans

Every query pattern this architecture introduces is either O(1) lookup (cell→zone via reverse index), event-driven (objective evaluation, connectivity maintenance), or bounded by a small subgraph (BFS on path-cut). The `valuable_targets` query for flankers is cached and event-invalidated.

**Preserved.** Migration phase 3 introduces the reverse index and validates lookup performance.

### 10.4 Maps must be loadable without scene reload

Maps are loaded by deserializing a `MapData` resource and populating `MapGrid` from it. `MapData` is hot-swappable: `MapGrid.load(new_map_data)` replaces the current state in one call. Within-system map switches save the outgoing `MapData` snapshot back to `SystemData` before loading the new one.

**Preserved.** Migration phase 2 implements this.

---

## 11. Migration Plan — Phased Rollout

Ten phases. Each is bounded and testable. Each leaves the game in a runnable state — no phase rewrites the world in one shot.

### Phase 1 — Data structure scaffolding (no runtime change)

Create the new Godot resource scripts: `SystemData`, `MapData`, `ObjectiveData`, `SpawnPoint`, `ZoneRegion`, `SupportGraph`, `BuildingNode`, `PathEdge`. Define fields per §2. No subsystem touches them yet. The current hardcoded `_build_default_paths()` still runs.

**Validation:** Project compiles. Existing gameplay is unchanged.

### Phase 2 — MapData loader + parity test

Implement `MapGrid.load_map_data(map_data: MapData)`. Convert the current hardcoded layout into a `MapData` resource by hand. Replace `_build_default_paths()` with a call to load that resource on `_ready()`. Run a parity test: gameplay should be pixel-perfect identical to before, including enemy pathing and flanker behavior.

**Validation:** Parity test passes. No behavioral regression.

### Phase 3 — Zone-region overlay + reverse index

Add `MapData.zones` and the cell→zone reverse index. Initially populate with zero zones. Add the query API (`get_zones_at_cell`, `get_cells_in_zone`). No gameplay effect yet.

**Validation:** Lookup performance bench: query 100k random cells, confirm sub-frame total time.

### Phase 4 — Spawn point migration

Replace SPAWN_W/N/S/E cell types with `MapData.spawn_points` list. Existing map gets one SpawnPoint per previously-active cardinal direction, all `ALWAYS_ON`. Update the wave generator to read from the list instead of scanning cell types.

**Validation:** Spawning behavior unchanged from before. Wave generator regression test passes.

### Phase 5 — Objective subsystem

Add `ObjectiveData`, the evaluator, and the HUD panel. Wire up faction-and-subpath keying. Author a minimal stub objective list per faction/subpath (e.g., one "claim N cells" objective each) to validate the pipeline. Wire spawn sealing logic.

**Validation (smoke tests):**
- Complete the stub objective → associated spawn(s) transition to SEALED.
- Force-lapse the objective (simulate control-point recapture) → spawn reverts to ACTIVE immediately.
- Re-complete the objective → spawn returns to SEALED.
- Complete *all* objectives → `map_completed` fires → spawn transitions to PERMANENTLY_SEALED → force-lapse one objective → spawn remains PERMANENTLY_SEALED (lapse has no effect after map completion).

### Phase 6 — Fog-of-war

Add `meta.revealed`, commander vision radius, the reveal pass, and the `region_revealed` event. Convert the existing map's safe zone to start revealed; everything else dark. Wire spawn `ON_REVEAL` activation.

**Validation:** Commander movement reveals cells. Spawns set to `ON_REVEAL` activate correctly.

### Phase 7 — Friendly AStar + support graph + ancient path discovery

Add the second AStar instance (commander routing) and the `SupportGraph` layer. Pre-load the hand-authored map's ancient path edges with `discovered: false`. Wire the fog-of-war reveal system (Phase 6) to the discovery check: when `region_revealed` fires, test each undiscovered ancient path edge for cell overlap with the revealed region; matches fire `path_discovered(edge_id)` and set `discovered: true`. Verify `ANCIENT_PATH_CROSSING` zones are flagged correctly at map load.

Convoy and stranded-building logic stubbed (no convoy entities yet). Path-cut detection wired to flanker damage events.

**Validation:**
- Commander moves near an ancient path cell → that path's edge activates; HUD reflects the new route.
- Cutting a path correctly marks downstream nodes as stranded. Restoring the path restores connectivity.
- `ANCIENT_PATH_CROSSING` zones appear at cells where ancient path edges and enemy traversal cells intersect.

### Phase 8 — Convoy entity class

Add Convoy as a pooled entity. Spawn convoys from support buildings on a tick. Movement on the friendly AStar. Death attrition feeds the economy aggregator. Map-failure threshold check.

**Validation:** Sustained flanker pressure on paths produces measurable research throughput drop. Total support loss correctly triggers map-failure event.

### Phase 9 — Two progression curves

Add `level` and `xp_to_next_level` to defensive structures. Add `xp` and `proficiency` to support/research units. Wire XP-gain hooks (damage, kills, convoys-completed, research-completed). Death clears proficiency.

**Validation:** Defensive structures level visibly over time. Support unit death clearly resets proficiency for the replacement.

### Phase 10 — Procedural generator with guardrails

Replace the hand-authored `MapData` from phase 2 with a generator that emits `MapData` given parameters: biome, topology template, faction-presence. Implement the validation pass — every resource node reachable from the FOB on the friendly graph, every spawn reachable by the commander, no zone sealed inside walls. Reroll on failure.

**Validation:** Generator produces N maps; all pass validation; spot-check by playing through several biomes.

---

## 11.5 Post-Phase-10 Polish — Map Scale Increase (TODO)

The map architecture refactor as implemented uses a 30×17 cell grid (510 cells). Playtesting in Phase 10 surfaced that this is **too small for the real game** — the design intent is roughly **4× the area** (target: ~60×34 cells, 2040 cells). The current size remains valid for tutorials, testing, and the initial smoke map; the production map size needs to be larger so winding paths, spread-out depots, and the Pilgrimage site can all coexist on one map.

Scope notes for this task when it's picked up:

- `MapData.DEFAULT_COLS/ROWS`, `MapGrid.COLS/ROWS`, `MapGenerator._COLS/_ROWS`, and `DefaultMapBuilder._COLS/_ROWS` all need to change in lockstep (or be derived from a single source). The MapData spec already supports per-map dimensions via `dimensions: Vector2i`; the hardcoded constants in the consumers need to read from `map_data.dimensions` instead.
- Cell render size is currently 64 px. At 60×34 the grid is 3840×2176 — larger than the 1920×1080 viewport. Either shrink the cell render size (32 px → 1920×1088, still fits) or add a camera that pans/zooms. The shrinkable approach is faster; the camera approach is more correct for the long term.
- Vision radius, attack ranges, and the safe-zone radius are all measured in cells. They should stay constant in cell terms (so they cover the same proportional area regardless of map size).
- The procgen path-generation parameters (waypoint count, perpendicular offset range) should scale with map size so paths still wind interestingly rather than going straight on a bigger canvas.

## 12. Deferred / Out of Scope for This Architecture Pass

These are deliberately not specified here and should not block the implementation:

- **Q6 — Galaxy layer specifics.** System unlock conditions, biome→sub-path favorability mapping, NPC faction galaxy-state propagation. See `core/20` for canon foundations; specific implementation belongs in a follow-on galaxy-layer ADR.
- **Q7 — MVP map count.** Content question. Once the architecture is in place and the generator works, 3–5 maps across distinct biomes is the suggested starter set.
- **Specific objective content per faction/sub-path.** What does an Architect/Spiritual-Tech player actually do on a Boreal Forest map? Content design — needs its own session, downstream of this architecture.
- **Specific bonus content for control points.** Same — content, not architecture.
- **Wave generator cadence and pressure tuning.** Numerical balance work. The architecture provides the events; the wave generator design owns the response curves.
- **Level-up curves, XP curves, leveling caps for both progression systems.** Balance work; ship defaults TBD.
- **Map-failure UX.** Architecture supports the failure path; the player-facing flow when a map fails is a UX design task.
- **Endgame-threat invasion mechanics.** Canon foundation in `core/14` and `core/20`. The architecture supports system unseal-on-invasion; the invasion event itself is endgame content.

---

## 13. References

Implementation should consult these documents alongside this handoff. Where this handoff and a referenced doc disagree, the referenced doc is authoritative on canon and this handoff is authoritative on technical structure.

| Document | Why consult |
|---|---|
| `planning/map-architecture-brief.md` | Original problem statement and hard constraints (§7). |
| `core/17_units-maps-buildings.md` | Standard map topology, biome modifiers, Ruins placement, faction unit/building rosters that interact with the map. |
| `core/18_ancient-pacification.md` | Ruins state machine and per-cell effects of Ruins phases. |
| `core/20_galaxy-strategy.md` | Galaxy-scale persistence and the silence-vector endgame threat (system unseal-on-invasion). |
| `core/22_interface-design.md` | HUD requirements for zone overlays, objective panel, notification system. |
| `core/23_open-questions-resolved.md` | Resolved canon values referenced in this handoff (tertiary-event 1-in-6 on Dual-Ruins, +50% build cost on tertiary points, etc.) and ship defaults to honor. |
| `codex/` | Medium-agnostic canon. Consult when implementation choices touch lore-visible content. |

---

*End of handoff.*
