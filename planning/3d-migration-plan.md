# 3D Migration Plan — Cycle Four goes 3D

> **Decision (2026-06-28):** after comparing a 2.5D spike vs. a true-3D spike
> (`scenes/test/Spike25D.tscn`, `scenes/test/Spike3D.tscn`), the user committed to
> **full 3D** — real `Node3D` entities, a `Camera3D` at ~45°, real lighting/shadows,
> real perspective. This doc is the staged, MCP-verified migration plan. Read it before
> touching any rendering/entity code. Mirrors the discipline of the map-architecture
> refactor (10 phases) and the architecture-north-star (staged + verified).

## Why staged + branched

This is the largest change the project has taken: Godot does **not** mix `Node2D` and
`Node3D` in one viewport, so every world entity, the camera, the map, fog, VFX, selection,
and the galaxy view must move to 3D. Converting `Unit` to `Node3D` immediately breaks the
2D `Battle`, so we cannot keep a working 2D build *and* migrate in the same tree.

**Strategy:** do the migration on a dedicated git branch (e.g. `feat/3d`), keeping `main`
as the last good 2D build (VFX + A1) until 3D reaches parity. **Commit the current 2D work
to `main` first as a checkpoint.** Each stage is MCP-verified (zero new errors) and, where
it makes sense, playtested before the next.

## What is PRESERVED (no/low change)

The pivot is **rendering + spatial**, not design or simulation logic:
- All gameplay design + the corpus/codex — unchanged.
- Autoloads / EventBus / economy / waves / objectives / milestones / save — coordinate-light;
  adapt only where they pass `Vector2` world positions.
- `.tres` data (units, towers, buildings, wave tables) — unchanged.
- **HUD stays a 2D `CanvasLayer` overlay** — that's normal for 3D games; no rewrite.
- Galaxy *logic* (`GalaxyManager` graph) — unchanged; only its *view* is reworked.
- The A1 tower identity (stat-driven silhouette: tier shape, barrel count∝fire-rate,
  length∝range, thickness∝damage, damage-type core) and the VFX design (tracers, muzzle,
  impact, death) **carry over conceptually** — re-expressed as meshes/particles.

## Conventions (Stage 0 decisions)

- **Coordinate mapping:** gameplay stays on a logical plane. Keep existing pixel units
  (CELL_SIZE 64) and map 2D→3D as `Vector3(x, height, y)` — i.e. the old 2D Y becomes 3D Z,
  +Y is up. A cell `(cx,cy)` center → `Vector3(cx*64+32, 0, cy*64+32)`. This keeps MapGrid
  cell math, ranges, and `.tres` distances valid with no rescaling.
- **Coordinate helper (new):** `src/core/World3D.gd` (static) — `to3(v2, h=0.0) -> Vector3`,
  `to2(v3) -> Vector2`, and `ground_point(camera, screen_pos) -> Vector2` (ray vs. the Y=0
  plane, for picking/placement). Single source for the mapping; everything routes through it.
- **Camera:** a `Camera3D` rig — fixed pitch ~50°, height-based zoom (replaces the Camera2D
  zoom), pan on the XZ plane. Galaxy zoom-out = pull the rig far back (same continuous-zoom
  idea, now in 3D). Replaces `CameraController`.
- **Picking/placement:** screen → ray → Y=0 plane → cell. Replaces 2D `get_global_mouse_position`.
- **Entity height:** structures get real height (towers ~tier-scaled), units low boxes/capsules,
  so the 45° camera reads height. Health bars/labels become `Sprite3D`/`Label3D` or stay in a
  2D overlay anchored to `unproject_position`.

## Stages

Each stage compiles clean via MCP before the next; the bulk (Stage 2) is per-entity.

- **Stage 0 — Conventions + scaffold.** This doc + `World3D` helper. No behavior change.
- **Stage 1 — Camera + ground vertical slice.** A `Battle3D` scene: `Camera3D` rig +
  `DirectionalLight3D` + a 3D ground built from the current `MapData` cells + the FOB/`Base`
  as a mesh. Click→ground raycast working. Proves camera/coordinate/picking. (Parallel scene
  so the slice is testable in isolation.)
- **Stage 2 — Entities to `Node3D`, one at a time, each MCP-verified:** Unit → Tower →
  Building → Base → Commander → EnemyBase → Wall → FriendlyUnit → Convoy → AncientWatcher.
  Movement runs on XZ via existing waypoints mapped through `World3D`; visuals become
  `MeshInstance3D`. Re-express A1 tower identity as meshes.
- **Stage 3 — Map / terrain in 3D.** Replace `MapGrid._draw` with 3D ground tiles; fog-of-war
  via shader/tile-dimming. (Sets up backlog **F1 terrain** — real height, water, biomes.)
- **Stage 4 — VFX in 3D.** Rebuild `Vfx` (tracers, muzzle, impact, death) with meshes /
  `GPUParticles3D`; same design language.
- **Stage 5 — Galaxy view in 3D.** Reconcile the tactical→galactic continuous zoom with the
  3D camera rig.
- **Stage 6 — Selection / controls / parity pass.** RTS controls (select / move / chain),
  inspection panel, placement preview all via 3D raycast; re-verify the full loop
  (Academy → faction → waves → conquest → galaxy → persistence). Switch `main_scene` to 3D
  once at parity; merge the branch.

## Follow-ups logged during Stage 2 (do before Stage 6 parity)

- **AbilityController plane-coordinate pass.** `src/abilities/AbilityController.gd` (a `Node` child of
  the Commander) still stores `field_center`/`hazard_center`/`bulwark` as `Vector2` and compares them to
  unit `global_position` (now `Vector3`). With a controller present and an ability cast, that mixes
  Vector2/Vector3 → runtime error. It no-ops without a controller and isn't used in Battle3D, but must be
  converted (route reads through `World3D.node_plane`, keep centers as plane `Vector2`) before abilities
  work in the 3D game.
- **Deferred visuals** to rebuild in 3D: per-entity XP/rank progression bars + veterancy chevrons
  (Tower/Base/Commander/Convoy used the 2D `ProgressionBar`/`RankChevrons`); Commander LoS/sensor rings,
  move-path preview, ability field/hazard rings, engineer beam, shot flash (were 2D `_draw`/`Line2D`).
- **3D VFX** (Stage 4): tracers, muzzle, impact, death poofs — the 2D `Vfx` autoload no-ops in 3D.

## Risks / notes

- **Scope:** multi-session (weeks of evenings). Expect the game to be non-playable on the
  branch mid-migration until Stage 6 parity. `main` stays playable throughout.
- **Selection precision** in 3D (ray vs plane) must match the old 58px select feel — tune.
- **Input gotchas** (`_unhandled_input`, GUI-eats-clicks, the Academy click-to-move) still
  apply — see [[reference-cycle-four-input-scene-gotchas]] and the Academy regression notes.
- **Export/templates** already support 3D (Forward Mobile, Vulkan; verified by the 3D spike).
- Keep the spikes (`scenes/test/Spike3D.tscn`) as a reference for camera/material/mesh setup.
