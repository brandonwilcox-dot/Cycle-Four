# Detection / fog-of-war rework + spawn fix — plan

> **STATUS — IMPLEMENTED 2026-06-21 (~4:51 PM).** All 5 requirements coded + export-verified (release
> build EXIT 0, zero script/parse errors → all six files compile clean). Desktop `.exe` rebuilt at
> `C:\Users\Brand\OneDrive\Desktop\Cycle Four.exe`; runtime behavior pending hand-playtest.
> Files: #1 → `Tower.gd` (reveal = max(detector,range)) + `Building.gd` (joins "detectors", 160px);
> #2 → `Commander.get_detector_radius()` = `_los_radius()` (sight ring); #3 → `Unit.gd` RevealTier
> HIDDEN/BLIP/FULL + `Commander.get_sensor_radius()` = `_sensor_radius()` (drawn sensor ring);
> #4 → `Unit.minimap_reveal()` + `Minimap.gd` gating; #5 → `MapGenerator.gd` (all spawns default
> ACTIVE + stub objective no longer instant-seals a spawn).

> **Scheduled execution: 2026-06-21 ~2:40 PM** (after the user's usage-credit reset). Source: user
> playtest feedback 2026-06-21. Do NOT start before then. Bar: zero new errors via the Godot MCP
> (`run_project` → `get_debug_output` → `stop_project`); verify behavior in-game where feasible; the
> restore/detection runtime is only confirmable by a hand-playtest, so rebuild the desktop `.exe` at the end.
>
> **READ FIRST** (per the recurring-regression lesson): `CLAUDE.md` (esp. "Phase 4 — Detection Counterplay")
> + memory `reference-cycle-four-input-scene-gotchas`. Don't change Academy/world-input code casually.

## Requirements (verbatim intent, user 2026-06-21)

1. **Towers + garrisons get reveal capability.** Today only the FOB, Commander, and dedicated detector
   towers (`mesh_t2b` Relay Pylon, the T3 apexes) reveal stealth (the `"detectors"` group +
   `get_detector_radius()`). Every **Tower** and every **garrison/Building** should reveal hidden units
   within a radius.
2. **Commander reveal = sight-ring size.** Today `Commander.get_detector_radius()` = `VISION_RADIUS*64`
   (fixed 192px). Make it track the LIVE sight ring (`_los_radius() * CELL_SIZE_PX`), which grows with rank,
   so the reveal matches the drawn sight ring.
3. **Tiered reveal — sight = full, sensor = blip.** Inside the **sight** ring: full reveal (current). Inside
   the larger **sensor** ring: a PARTIAL reveal — a position-only **blip/marker**, NOT full unit info. So a
   hidden unit in sensor range shows only where it is; in sight range it shows fully.
4. **Hidden units off the minimap until revealed.** `Minimap.gd` must not plot enemy markers for
   undetected units — show an enemy only once detected. (Decide: does the sensor "blip" tier also appear on
   the minimap as a dim marker, mirroring the world? Default: yes, dim blip; full = normal.)
5. **Spawn-from-one-direction (recurring bug #4).** Multiple spawns exist but only ONE is active in play.
   Investigate `Battle._activate_all_spawns()` + `WaveSpawner` per-wave spawn/route distribution — ensure
   units actually emit from all active spawns, not a single funnel.

## Approach sketch (research + confirm at execution — don't assume; verify current code)

- **Detection model (current, per CLAUDE.md Phase 4):** entities in group `"detectors"` expose
  `get_detector_radius()` (px). `Unit` recomputes detection on a ~0.15s throttle by scanning the detectors
  group (`_within_active_detector()`), and is visible/targetable only inside a detector radius.
- **#1** Give `Tower` and `Building` a `get_detector_radius()` + join `"detectors"` (base reveal bubble;
  keep dedicated detector towers stronger). Pick radii (suggest: tower ≈ its sight; garrison ≈ a modest
  bubble) — list as an open decision.
- **#2** `Commander.get_detector_radius()` → `float(_los_radius()) * CELL_SIZE_PX`.
- **#3** Add a SECOND, larger **sensor/blip** tier separate from the **full/sight** tier. Detectors expose
  both (full radius + larger sensor radius). `Unit` picks the strongest tier it's inside: full → normal
  render; sensor-only → a new minimal **blip** visual (position dot, no health/type); none → hidden. This is
  the core new mechanic — design the Unit visibility states carefully.
- **#4** `Minimap.gd`: filter enemy markers by detection state (hidden → omit; blip → small dim dot; full →
  normal). Mirror the world tiering.
- **#5** Read `_activate_all_spawns` + `WaveSpawner` spawn assignment; confirm whether each wave distributes
  across all ACTIVE spawns or funnels to one (single-enemy-per-map wave may pick one route). Fix.

## Files likely involved
`src/entities/Unit.gd` (detection tiers + blip render) · `src/entities/Commander.gd` (detector radius) ·
`src/entities/Tower.gd` + `src/entities/Building.gd` (add detector) · `src/entities/Base.gd` (reference) ·
`src/ui/Minimap.gd` (filter by detection) · `src/core/waves/WaveSpawner.gd` + `scenes/main/Battle.gd`
(`_activate_all_spawns`) for the spawn bug.

## Open decisions (resolve at execution; ask the user if it affects feel)
- Exact reveal radii: towers vs garrisons vs dedicated detector towers (keep detectors meaningfully stronger).
- Does the sensor **blip** tier also show on the minimap, or in-world only?
- Should garrison reveal differ from tower reveal?

## Suggested execution order (each MCP-verified, committed separately)
1. #5 spawn-distribution fix (isolated; high-value; unblocks readable combat).
2. #2 Commander reveal = sight ring (one line).
3. #1 towers + garrisons reveal (additive detectors).
4. #3 tiered sight/sensor blip (the big one — new Unit visibility states).
5. #4 minimap filter (depends on #3's detection state).
Rebuild the desktop `.exe` at the end for a hand-playtest.
