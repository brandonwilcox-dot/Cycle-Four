# Per-territory persistence — design

> **Goal:** a galaxy territory's *development* (placed buildings, towers, claimed cells, FOB rank)
> survives leaving it AND survives a Continue — so offline army resolution has garrisons to run and
> the Total-War campaign state holds. **Status: IN PROGRESS (2026-06-20). Step 1 landing.**
>
> **Backbone (already true):** saves are JSON (`user://cycle_four_save.json`, `SaveManager`). The
> galaxy graph (`GalaxyManager.star_systems`: node → `{owner, ring, px/py, adj, seed}`) and treaties
> already persist; each node's battle map regenerates deterministically via
> `MapGenerator.generate(seed)`. **Missing:** per-node *development* + which node you're in.

## Model

Per galaxy node, persist a `development` payload alongside its seed:
- `buildings`: `[{id, cell, level}]`  — garrisons; `id` = the `.tres` resource path
- `towers`:    `[{id, cell, level, branch}]`
- `claimed`:   `[cell, …]`  — CLAIMED cells (runtime-only in `MapGrid._cells`, wiped on map load)
- `fob`:       `{rank}`

Stored in `GalaxyManager` (keyed by node id), saved inside the existing `galaxy` save block. Plus
persist `active_node` / `invading_node` (which territory you're in / capturing).

## The seed-reconcile (why the home territory works)

`MapGrid._ready` loads the FIRST map via `generate()` → a random (time-based) seed, NOT the active
node's seed; `map_data.map_seed` records the *actual* seed used. So instead of forcing a reload at
game start, on a fresh start we **pin the home node's seed to `map_data.map_seed`** — the node now
points at the exact map the player is on, and a Continue (`generate(node.seed)`) reproduces it.
`generate(seed)` reproduces the map at attempt 0 (the stored seed already passed validation).

## Capture / restore

- **Capture** (on deploy-away + on save): snapshot the current battle — Battle's `_building_cells` /
  `_occupied_cells`, MapGrid CLAIMED cells, FOB rank — into the active node's `development`.
- **Restore** (Continue, or returning to a developed node): after loading the node's seeded map
  (reuse the `_deploy_to_node` clear+load+activate routine), re-place buildings/towers, re-claim
  cells, restore FOB rank.

## Save format

Bump `version` 1 → 2. v1 saves load fine (no `development`/`active_node` → defaults: blank
territories, rim-start node). Additive, backward-compatible.

## Incremental plan (each MCP-verified; bar = zero new errors)

1. ✅ **Persist `active_node`/`invading_node` + reconcile the home node's seed** (fresh start only — on
   restore we keep the saved seed). *Foundation; additive.* **DONE 2026-06-20.**
2. ✅ **Continue-path map reload + restore claimed cells.** On restore, load `active_node`'s seeded map
   (reusing `Battle._load_territory_map`) and re-apply saved CLAIMED cells — capture via `game_saving`
   → `_capture_territory_development`; restore via MapGrid `apply_claimed_indices`. **DONE 2026-06-20.**
3. ✅ **Persist/restore buildings (garrisons).** Capture `[{id, cell, level}]` (`_capture_buildings`);
   restore via `_restore_building`, which skips the income re-add (`Building.setup(data, restored=true)`
   → `_ready` guard) since territory_rates already includes it. **DONE 2026-06-20 — unblocks offline
   resolution on a real Continue.**
4. **Persist/restore towers (level/branch) + FOB rank.** Full investment fidelity.
5. **Capture-on-deploy.** Snapshot a territory when you leave it, so multi-territory state holds.

## Verification note

`_start_game_world` (where the reconcile + restore live) only runs after the Academy completes or an
F-key dev-skip — neither injectable via the Godot MCP. So MCP runs confirm parse/load/compile cleanly
(no regression); the runtime reconcile/restore logic is verified by inspection + reuse of the proven
`_deploy_to_node` load path, and ultimately by a hand-playtest Continue.
