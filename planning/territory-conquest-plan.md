# Territory Conquest — Design Plan

> Captured 2026-06-23 from a playtest design session. Supersedes the "claim 200 cells"
> default win condition (see Problem). Grounded in the post-MVP vision-roadmap.md.

## Problem (observed 2026-06-23, debug playtest)

- The default win condition `CLAIM_TERRITORY` (target 200 cells) **auto-completes on frame one**:
  the starting FOB influence sphere already claims ~1705 cells. So every territory is flagged
  "conquered" the moment you arrive → `map_completed` fires immediately → `MapGrid.set_battle_won(true)`
  → the spawn no-build exclusion zone lifts before the player does anything. Win condition is a no-op.
- Exploration is trivial: the commander can skirt the perimeter and reveal the whole map in ~90s
  before any wave is fought.
- No build limits: the player can fill nearly every cell with towers + support buildings.

## Vision (user, 2026-06-23)

Conquering a territory should be an **active push through persistent threats**, not a passive claim.
The map represents a large territory to take; there should be "more things to trip on."

1. **Enemy bases anchor each wave spawn.** Destroying a base is what lifts that spawn's no-build DMZ
   and counts toward conquering — giving the exclusion zone a concrete *reason* (an enemy structure is
   there) instead of an arbitrary no-build area.
2. **Intermediate encampments / strongholds** sit between the center and the perimeter spawns. They
   spawn enemies (persistent threats) and must be defeated before you can expand outward to the wave
   spawn points. This slows the ~90s free-reveal run into a fought-for advance.
3. **Win = destroy all enemy bases** (replaces claim-200). `map_completed` fires on the last base.
4. **Build limits** cap towers + support buildings so the player can't carpet the map.

## Phased build (dependency-ordered — ONE per session)

### Phase 1 — Enemy bases at spawns (keystone)
Foundation: turns each spawn into a destructible objective and fixes the broken win condition.
- New destructible **EnemyBase** structure at each active spawn (HP bar, faction-colored, in a group).
- While alive: the spawn emits waves **and** its local DMZ no-build holds.
- Destroyed: that spawn **seals** (stops emitting) and its local DMZ **lifts**.
- Win-condition rewrite: `DESTROY_BASES` objective — progress = bases destroyed / total; on the last
  base, `map_completed` → capture. Removes the auto-completing `CLAIM_TERRITORY` default.
- DMZ becomes per-base: `is_build_excluded` keyed to whether the nearest base still stands, not a
  single map-wide `_battle_won` flag.
- **Open decision (see below): how a base is destroyed given the no-fire DMZ.**

### Phase 2 — Intermediate encampments
- Generator places smaller enemy structures mid-map (between center and perimeter spawns).
- They spawn weaker, persistent enemies and contest the ground around them.
- Must be cleared to expand toward the perimeter bases (gates exploration + expansion).
- Tuning target: the whole-map reveal should require fighting, not a 90s perimeter skirt.

### Phase 3 — Build limits
- Caps on towers + support buildings (per-territory or global), with a HUD capacity readout.
- Forces placement choices; prevents carpeting.
- Possible refinement: caps scale as bases/encampments are cleared (expansion unlocks capacity).

## Key design decision — how is an enemy base destroyed?

The no-fire DMZ deliberately stops towers hitting *units* near a spawn (so enemies clear the mouth).
A base sits at the spawn, inside that buffer. Options:
- **A. Army assault (commander + friendly units).** Towers hold the line; your army marches out to
  take bases. Active RTS push that matches "expand out to the spawn points." Reuses existing
  friendly-unit two-way combat. The no-fire DMZ stays purely about roaming units. [recommended]
- **B. Towers can damage the base structure** (just not roaming units in the DMZ). Defensive play
  alone can win; less active.
- **C. Both** — army or towers can damage bases.

## Notes / interactions
- Galaxy capture loop is unaffected: it still triggers on `map_completed`, just from a new condition.
- Per-territory persistence: base HP / destroyed-state must be captured into node `development`
  alongside claims/buildings/towers/fob (replaces the `won` bool with per-base state).
- The `[WaveSpawner]` multi-spawn re-verify log + the DMZ no-fire layer both stay; only the
  no-build gating and the win condition change.
