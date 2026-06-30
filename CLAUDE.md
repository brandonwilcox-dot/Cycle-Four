# Cycle Four -- Game Project

Godot 4.6.1 | GDScript | D:\AI\Cycle Four\

Design corpus lives at:
  C:\ClaudeProjects\Skippy Gaming Design Engineer Agent\core\
Read PROJECT-MEMORY.md and core/23_open-questions-resolved.md before
making any design decisions in code.

---

## Build / Export — keeping the .exe current

The exported `.exe` does NOT auto-update. The Godot MCP `run_project` is a
from-source compile/boot check only; it never touches the desktop `.exe`. After a
change is verified, re-export so the playable build reflects it.

**Routine:** `tools/export.ps1` (run from a terminal, or I run it after a confirmed change).
- `.\tools\export.ps1`            → builds BOTH release + debug
- `.\tools\export.ps1 -OnlyDebug` → debug only (fast iteration)
- `.\tools\export.ps1 -OnlyRelease`

**Two outputs on the desktop (`C:\Users\Brand\OneDrive\Desktop\`):**
- `Cycle Four.exe` — RELEASE. `OS.is_debug_build()=false`; dev keys F1-F4 OFF; must
  play the full Academy. This is the "latest confirmed-working build" — rebuild it
  after a change is verified (and ideally playtest-confirmed).
- `Cycle Four (DEBUG).exe` — DEBUG. `OS.is_debug_build()=true`; F1/F2/F3 skip Academy →
  architects/mesh/bloom, F4 = +1h offline sim; debug prints (e.g. the `[WaveSpawner]`
  multi-spawn log) write to `%APPDATA%\Godot\app_userdata\Cycle Four\logs\`. Use for
  quick playtests; rebuild freely while iterating.

A clean export compiles every script into the PCK, so a successful run also serves as
a whole-project compile check. See [[reference-cycle-four-release-export]].

---

## Session 2026-06-28 (4) — 3D migration Stages 0/1/2a — on branch feat/3d

Branch `feat/3d` (main = 2D checkpoint `69f3694`). Per `planning/3d-migration-plan.md`:
- **Stage 0** (`6b37883`) — `src/core/World3D.gd`: 2D⇄3D mapping (old Y→Z, +Y up, pixel units) +
  ground-ray picking + `node_plane()` bridge for mixed 2D/3D reads.
- **Stage 1** (`6b37883`) — `src/core/CameraRig3D.gd` (RTS rig ~52° pitch, wheel zoom, WASD/middle
  pan) + `scenes/test/Battle3D.tscn` slice: 3D ground at real grid (60×34×64), grid overlay, FOB
  mesh, light/shadows, click→cell picking marker. MCP + playtest verified.
- **Stage 2a** (`ac4fd10`) — **enemy `Unit` → `Node3D` (model/view).** Sim stays on a logical plane
  (`_p`); transform driven via `World3D` (`_set_plane` + faces travel dir); cross-entity reads via
  `plane_pos()`/`World3D.node_plane()`. Visual = `MeshInstance3D` (+ billboard HP bar, damage tint)
  replacing the ColorRect; hijack/pollen/reveal adapted to material tinting. `Unit.tscn` root retyped
  Node3D. Battle3D demo spawns a marching column. MCP-verified clean.

- **Camera controls** (`bcf8e6c`) — `CameraRig3D` now orbits: hold MIDDLE+drag = rotate (yaw/pitch),
  MIDDLE+wheel = pitch, wheel = zoom, WASD = pan, Delete = reset to preferred, Insert = lock current
  view as preferred. (Pitch clamped 15–80°.)
- **Stage 2b** (`7ed8fe1`) — **`Tower` → `Node3D`.** Static plane pos `_p` + `place_at()`/`plane_pos()`;
  all targeting/aura/chain/pollen/hijack/sight via `World3D.node_plane()`. A1 silhouette re-expressed
  as meshes: tier-sided body (cylinder 4/6/8 seg) + torus tier rings + stat-driven box barrels
  (count~fire-rate, length~range, thickness~damage) on a yawing turret + emissive damage-type core +
  role emblem (support halo / detector antenna). Construction ghosts via material alpha + billboard
  build bar. 2D XP-bar/chevrons deferred (null-guarded). `Tower.tscn` root→Node3D; `TowerData.range`
  warning silenced. Battle3D demo: a spread of tiers/branches/roles shoot the marching units. MCP clean.

- **Stage 2c** (`018bbd3`) — **`Building` (garrison) → `Node3D`.** Box garrison + raised cross identity;
  ghost via material alpha. Production/raid/level/offline logic preserved (defender spawn passes plane
  coords, no-ops until FriendlyUnit is 3D). `Building.tscn` root→Node3D.
- **Stage 2d** (`cd0efd7`) — **`Base` (FOB) → `Node3D`.** 3D bunker (apron/body/corners/turret) +
  billboard HP bar recoloring by ratio. HP/fortification/influence/doctrine preserved; 2D rank bar
  deferred. Battle3D spawns the real Base (shoots units, takes breach damage). `WorldMap.tscn` (2D world,
  abandoned) left untouched per plan.

**STAGE 2 COMPLETE — all 10 entities are Node3D** (`2a`–`2j`): Unit, Tower, Building, Base, Commander,
EnemyBase, Wall, FriendlyUnit, Convoy, AncientWatcher. Pattern throughout: logic on a logical plane
(`_p`), 3D transform via `World3D`, cross-entity reads via `plane_pos()`/`World3D.node_plane()`, visuals
as `MeshInstance3D` (+ billboard bars). Battle3D is a full 3D mini-battle: FOB + towers + Commander
shooting a marching enemy column, an enemy base fielding defenders, walls on the approach, a garrison.

**Carry-overs / follow-ups before Stage 6 parity:**
- **AbilityController** (`src/abilities/AbilityController.gd`, a `Node` child of Commander) still mixes
  `Vector2` field/hazard centers with (now `Vector3`) unit positions — needs a plane-coordinate pass.
  No-ops without a controller; not exercised in Battle3D. **Do before abilities work in the 3D game.**
- 3D VFX (tracers/muzzle/impact/death/shot-flash/engineer-beam) → Stage 4 (2D `Vfx` no-ops in 3D).
- Deferred 3D overlays: tower/commander/base/convoy XP/rank bars + chevrons, Commander LoS/sensor/
  move-path/ability rings. Defender production needs a live faction + 3D unit layer.

**STAGE 3 COMPLETE** (`aed8795`) — `MapGrid` → `Node3D`; board renders as a MultiMesh of flat tiles
(per-instance colored by cell type + fog) replacing 2D `_draw`; `queue_redraw()` repurposed as a
dirty-flag so all callers keep working; logic (cells/AStar/claim/reveal) unchanged. Battle3D spawns the
real MapGrid → a true 3D battlefield with fog revealing around FOB/Commander + claimed cells greening.
Depot markers + real terrain features (height/water/biomes — backlog F1) deferred.

**STAGE 4 COMPLETE** (`9941f30`) — `Vfx`/`VfxBolt`/`VfxPulse` rebuilt as Node3D. API still takes plane
`Vector2` so callers are unchanged: Tower (muzzle/bolt) + Unit (death) render in 3D for free; also wired
3D tracers for Commander primary (restores the shot flash), FOB turret, FriendlyUnit. Bolt = emissive
tracer bar + impact `CPUParticles3D` sparks; muzzle/death = expanding emissive sphere. Effects spawn into
a `VfxLayer` under the MapGrid; no-op without a map.

**STAGE 5 COMPLETE** (`09d6068`) — `GalaxyView` → `Node3D`; the territory graph renders as 3D meshes
(owner-colored system spheres + edge bars + active/frontier rings), visible when the camera rig reports
`is_galaxy_zoom()`. CameraRig3D zoom range extended to galaxy distance + `is_galaxy_zoom()`; rig in group
`camera_rig`. Zoom out → board shrinks → 3D galaxy. `node_at()` pick kept for deploy.

**STAGE 6a+6b COMPLETE — the 3D build is a PLAYABLE TD round.**
- 6a (`f35f294`) — RTS controls via 3D ground raycast: LEFT select Commander / RIGHT move (shift-chain) /
  B tower-build mode w/ live green-red placement preview; wired to `MapGrid.can_place_at`/`mark_tower_placed`
  + Commander engineering.
- 6b (`3d9f2f7`) — real waves: enemies trickle from the map's spawn cells down their `get_path_to_base`
  A* routes into a UnitLayer; FOB/towers/Commander defend with 3D tracers. Fog reveals as you explore.
- Playtest build (`eda2fcb`) — `run/main_scene` → `Battle3D.tscn` (BRANCH-ONLY, temporary) so the exported
  debug exe boots straight into the playable 3D battle. **Revert this before merge.**
- Engineer beam (`e5f2e52`) — 3D build/repair beam Commander→structure (playtest-flagged build feedback).
- HUD overlay (`c171287`, **6c partial**) — the real `HUD.tscn` (Control) overlays the 3D battle on a
  CanvasLayer; EventBus-driven so resources/waves/notifications/objectives display live. Build button wired
  to 3D placement (works once faction-select lands); B-key meanwhile.
- Camera snaps (`a6c7cbc`) — PgUp birds-eye (top-down, map-centered), PgDn focus Commander (~sensor
  range), Insert/Delete custom lock/reset; G garrison placement. Playtest-confirmed working.
- **Playtest-confirmed 2026-06-29:** movement, build (now w/ beam), tower aim/response, enemy damage +
  death poof, camera angles, B/G placement all good; "mechanics feel solid."

**Stage 6c progress:**
1. ✅ **Faction-select flow** (`e6c6f0d`) — Battle3D selects architects/standard at startup (after the HUD
   is listening). HUD now shows faction resources + build buttons + starter tower; garrison produces
   friendly units (gets roster unit + resolves unit layer via new "unit_layer" group; Building lazy-resolves
   it). Fixed the "garrison no units" + "HUD only energy" playtest issues.
2. ✅ **HUD build button** (`c8aea1c`) — was correctly `can_afford`-gated (no resources at battle start);
   seeded demo starting resources after faction-select so it's usable. (B-key bypasses economy.)
3. ✅ **Tower upgrades** (`c8aea1c`) — LEFT-click a built tower selects it; **U** upgrades to `data.upgrade_to`
   via `Tower.upgrade()`. Demo: free (real game charges + offers the A/B branch).
4. **Backlog I1 (deep, → C2/D1):** friendly-unit movement/formations — patrol clips through buildings;
   units should form up outside the garrison perimeter, move only when needed. In playtest-backlog doc.
5. ✅ **HUD build buttons** (`9ec526c`) — unlock on placement end (Battle3D calls `HUD.end_placement_mode()`,
   which now resets the building button too); garrison button wired (`building_placement_requested`).
6. ✅ **Rapid-upgrade crash fix** (`f3d97a0`) — 0.35s upgrade debounce (the free-all+rebuild churn in
   `Tower.upgrade` thrashed under rapid U → crash; the known [P1][MONITOR] rapid-interaction class).
7. ✅ **Galaxy deploy** (`1bea2f0`) — zoomed-out LEFT-click a frontier node → `node_at` → load that
   territory's seeded map (`MapGenerator.generate(seed)`), recolor terrain, recenter graph, re-collect
   spawns, snap camera back to the battlefield. The tactical→galactic→deploy loop in 3D.
8. ✅ **Commander move clamp** (`90ae399`) — `_clamp_to_map` keeps move orders inside the play area
   (the ground ray hits the infinite Y=0 plane, so off-board right-clicks used to send it wandering).
9. ✅ **Deploy = clean transition + capture-on-clear** (`2562343`) — deploy resets the battlefield
   (`_reset_battlefield`: free towers/buildings/units/walls/enemy bases via destroy() for income
   unwind, Commander back to base), spawns a fresh `EnemyBase` (territory's owner faction) at the new
   map's first spawn cell; destroying it → `enemy_base_destroyed` → `GalaxyManager.capture_system`
   flips the node + expands the frontier. The full tactical→deploy→clear→capture loop runs in 3D.
10. ✅ **Q/E camera yaw** (`b60a964`) — hold Q/E to rotate the view (CameraRig3D `_process`), with
    middle-drag rotate.
11. ✅ **GameOver overlay** (`2a92614`) — mounted the self-wiring `GameOverScreen.tscn` in the 3D HUD;
    shows on `base_destroyed`, Try Again / Return to Menu reload Battle3D.
12. ✅ **Commander LoS/sensor range rings** (`c50e87b`) — flat ground TorusMesh rings (vision green /
    sensor blue) shown when selected, sized to rank-scaled radii. (3D HP bars already done on units +
    Commander; enemy units already have HP bar + damage tint.)
13. ✅ **Faction-select screen** (`9413e0a`) — replaced hardcoded architects with a choose-your-faction
    CanvasLayer chooser (Architects/Bloom/Mesh + Academy-default sub-paths); picking one selects the
    faction, seeds demo resources, and `_start_battle()` builds the faction-dependent world. World
    spawn + waves + gameplay input gated on `_battle_started`. (User scope: faction-select only.)
14. ✅ **Bug sweep** (`8dcfed4`) — paced finite waves (8s grace + rests, no immediate unending stream);
    move-marker fades on Commander arrival; Architect walls now build (wired `wall_placement_requested`
    → wall placement; Commander raises them).
15. ✅ **SCENE PROMOTED** (`039215a`) — Battle3D moved scenes/test → scenes/main; `main_scene` restored
    to `Root.tscn`; `TitleScreen.BATTLE_SCENE` → Battle3D. Real flow now: **Root → Title → SceneManager
    → 3D Battle**. 2D `Battle.tscn` kept as fallback.
16. 🔶 **save/load — IN PROGRESS (1/3)** (`15f596c`): SaveManager already auto-persists faction/economy/
    galaxy(+dev). ✅ (1) Continue-aware boot — `_continue_game()` restores faction + active-node map,
    skips faction-select. TODO (2) capture 3D development on `game_saving`; (3) restore towers/
    buildings/walls/claims/FOB rank on Continue/return (port the proven 2D Battle.gd helpers).
17. TO-DO: full scripted Academy tutorial (with scene-promotion arc); AbilityController plane pass +
    ability/move-path overlays; merge `feat/3d` → main.

**Remaining: Stage 6b — full Battle-controller parity + merge (its own focused arc, the riskiest piece).**
Battle3D is a test scene; the real game still routes Title → (2D, now-broken) `Battle.tscn`/`WorldMap.tscn`.
6b = make the 3D path the real game: rebuild/retarget the **Battle controller** (the ~1000-line `Battle.gd`
driving Academy/HUD/FactionSelect/GameOver/waves/save/galaxy-deploy-capture) onto a 3D world scene
(promote `Battle3D` or replace `WorldMap.tscn`); **HUD reconnect** (2D CanvasLayer overlay + entity bars
via `unproject_position`); building/wall placement through the HUD; deploy/capture via the 3D GalaxyView;
then **switch `run/main_scene`** off the 2D path and **merge `feat/3d` → main**. Fold in deferred items:
engineer beam, ability/LoS/move-path rings, 3D XP/rank bars + chevrons, AbilityController plane-coord pass.
`scenes/test/Battle3D.tscn` is the proven reference assembling every 3D building block.

---

## Session 2026-06-28 (3) — MAJOR DECISION: commit to full 3D + staged migration plan

After comparing two throwaway spikes — `scenes/test/Spike25D.tscn` (faked-height 2.5D, pure 2D
`_draw`) vs. `scenes/test/Spike3D.tscn` (true 3D: `Camera3D` ~45°, `DirectionalLight3D` shadows,
mesh tower/units, turret yaw) — **the user chose full 3D.** This is the largest change the project
has taken: Godot can't mix `Node2D`/`Node3D` in one viewport, so entities, camera, map, fog, VFX,
selection, and galaxy view all move to 3D; HUD stays a 2D `CanvasLayer`.

**Plan written: `planning/3d-migration-plan.md`** — staged + MCP-verified, on a dedicated branch
(`main` keeps the working 2D build until parity). Conventions: keep pixel units (CELL_SIZE 64), map
2D→3D as `Vector3(x, height, y)` (old Y→Z), new `src/core/World3D.gd` helper for to3/to2/ground-ray
picking, `Camera3D` rig at ~50° pitch. Stages: 0 conventions+helper → 1 camera+ground+Base slice →
2 entities to Node3D one-by-one → 3 terrain/fog → 4 VFX → 5 galaxy view → 6 controls/parity, then
switch `main_scene`. **Preserved:** all design/corpus, autoloads/EventBus/economy/waves/objectives,
`.tres` data, HUD, galaxy logic; the A1 tower identity + VFX design carry over as meshes/particles.

**Spikes kept** for reference. **Recommended next step:** commit current 2D work (VFX + A1) to `main`
as a checkpoint, branch `feat/3d`, start Stage 1. Awaiting go-ahead on committing/branching.

---

## Session 2026-06-28 (2) — A1: distinct per-tier/branch tower visuals — PLAYTEST VERIFIED (+ aim fix)

**Playtest 2026-06-28:** tiers 1→3 + both tier-2 branches now visually distinct (confirmed all
factions); antenna/detector + support halo confirmed; Bloom growth + tier changes read well.
**In-session fix:** the turret barrel appeared "locked" (only re-aimed on fire, so it froze on
cooldown / when not firing). Replaced with **continuous aim tracking** — `Tower._update_aim(delta)`
re-scans the best target on a 0.1s cadence and lerps `_aim_angle` toward it every frame
(`AIM_TURN_RATE` 9.0), so barrels visibly track enemies. `_try_attack` now sets `_aim_target_angle`
(goal) instead of snapping `_aim_angle`. Compile-clean via MCP, debug exe re-exported + relaunched.

**Backlog from this playtest (captured, NOT scheduled — see `planning/playtest-backlog-2026-06-28.md`
addendum H1–H6):** H1 Bloom corrosive feel early-game; **H2 tower won't fire on point-blank enemy
(spawn-DMZ/detection, pre-existing, not A1)**; H3 Mesh hijack too strong (tone down); H4 power curve
too steep (wave-5 all-maxed, one T3 holds the line); H5 faction-distinct tower silhouettes (A1
follow-on); **H6 [MAJOR] 3D/2.5D rendering w/ ~45° camera — strategic decision pending.**

---

## Session 2026-06-28 (2 archived note) — A1 original compile entry

First item off the playtest backlog (`planning/playtest-backlog-2026-06-28.md` A1): upgraded towers
used to look near-identical (old `_build_visual` only scaled the body 4px/tier + tiny pips). Now the
whole tower body is **drawn procedurally in `Tower._draw()`**, with a stat-driven, readable identity:
- **Tier → body plate:** 4/6/8-sided polygon (diamond → hexagon → octagon), radius 16/20/24, ring count
  = tier, plus a rotated inner accent at tier ≥ 2.
- **Stats → barrels:** count = round(attack_speed) clamped 1–4 (gatling vs single cannon), length ∝ range,
  thickness ∝ damage. So e.g. Architect Railgun (slow/long/high-dmg) = one long thick barrel; Bloom Toxic
  Spore (fast) = a 3-barrel spread — distinguishing the two tier-2 branches that share the DAMAGE role.
- **Core gem** tinted by damage type (gold/cyan/green) — **matches the tracer bolt color** from session 1.
- **Role emblem:** support/aura towers get a gold halo ring; detector towers get an antenna. Role derived
  from `aura_radius`/`detector_radius` (`Tower._role()`).
- **Turret aims at its target:** `_aim_angle` snaps toward the current target in `_try_attack` (+`queue_redraw`),
  so the barrels point where the tracer flies.

`_build_visual` now only builds the overlay widgets (XP bar, chevrons, construction bar) — body/border/pips
ColorRects removed; body is `_draw`-rendered. Lifecycle unchanged: `upgrade()` rebuilds + redraws (new tier
shape in place); `_refresh_build_visual()` still ghosts via `modulate` (works on `_draw` output) and drives
`queue_redraw`. No external refs to the removed child nodes (placement preview is its own ColorRect).
New helpers: `_tier_sides`/`_tier_rot`/`_role`/`_regular_poly`/`_barrel_poly`; const `DAMAGE_CORE`.

**Compile:** booted clean via MCP (zero new errors; only the standing benign EventBus warnings). Debug exe
re-exported + launched 2026-06-28. **Runtime: needs playtest** — F1 → place/build T1 → upgrade through
T2 (try both branches) → T3; confirm each tier/branch looks distinct, barrels aim at targets, core color
matches the tracer, support/detector emblems show. Tune body radii, barrel remap ranges, `DAMAGE_CORE`.

---

## Session 2026-06-28 — VISUAL TRACK BEGINS: combat juice/VFX pass 1 — PLAYTEST VERIFIED

New direction (user, back after a gap): gameplay is feature-complete enough — pivot to **visual
enhancements**. Chosen approach: **procedural "juice" in pure GDScript, NOT a sprite-art pipeline**
(everything was `ColorRect`/`Label`/`_draw()` primitives; `assets/` held only `icon.svg`; the local
vision model is text-only so an art pipeline is a slow bottleneck). All effects are **cosmetic only** —
they never touch damage/gameplay, so balance can't regress.

**New `Vfx` autoload + `src/vfx/` (3 files):**
- `src/vfx/Vfx.gd` (autoload `Vfx`) — factory: `bolt(from,to,damage_type)`, `muzzle(at,dt)`,
  `death(at,faction_col,radius)`, `spark_burst(at,color,amount,speed)`, + `damage_color(dt)` /
  `faction_color(fid)`. Spawns effects into a lazily-created world-space `VfxLayer` under `WorldMap`
  (resolved via `main_controller` group → `WorldMap`; **no-ops safely if the world isn't present** —
  headless/offline). Generates a 6px white spark texture in code so `CPUParticles2D` is visible with
  no asset. Damage tints: Kinetic=pale gold, Energy=cyan, Corrosive=acid green. Faction death tints:
  architects=blue, bloom=green, mesh=purple.
- `src/vfx/VfxBolt.gd` — traveling tracer (head + tapering trail) from tower to target over a
  distance-scaled lifetime (SPEED 1400 px/s, clamped 0.04–0.18s); spawns an impact spark burst on
  arrival, then frees itself. Damage is still dealt instantly by the tower — the bolt is pure decoration.
- `src/vfx/VfxPulse.gd` — expanding/fading ring (+ optional filled core) for muzzle flashes + death poofs.

**Wired (3 call sites):** `Tower._try_attack` → `Vfx.muzzle` + `Vfx.bolt` (before the existing instant
`take_damage`); `Unit._die` → `Vfx.death` (faction-tinted poof + sparks) before `queue_free`.
**Deliberately skipped** a modulate-based hit-flash this pass — `modulate` is already used by hijack
(cyan tint) / pollen / spawn-flash, so overwriting it would fight those; the impact burst at the target
serves as hit feedback. Revisit with a shape-conforming overlay later.

**Compile:** booted clean via MCP (`Vfx` autoload + all 3 scripts + Tower/Unit reload; zero new errors,
only the standing benign EventBus "signal never used" warnings). **PLAYTEST VERIFIED 2026-06-28** (debug
exe): tower fire bloom, tracer bolt + trail, impact sparks, and enemy death poof all confirmed working;
bolt speed + colors confirmed good. Tunables if needed: `VfxBolt.SPEED`, spark `amount`/`speed`,
`Vfx.DAMAGE_COLORS`/`FACTION_COLORS`. Debug exe re-exported 2026-06-28; release export still pending.

**Playtest surfaced a large design backlog — captured, NOT scheduled.** See
`planning/playtest-backlog-2026-06-28.md` (assault phases + boss, garrison/enemy formations, terrain,
dynamic enemy paths, convoy pathing, **A1: upgraded towers need distinct per-tier/branch visuals**).
Do not implement any of it without picking the item with the user.

**Next juice candidates:** **A1 tower-tier visuals** (pure-visual, direct follow-on), environment pass
(starfield/nebula backdrop, terrain texture, prettier territory fills/fog — overlaps backlog F1),
Commander/FOB firing VFX (Commander attacks + base defenders reuse the same `Vfx` calls), screen shake on
base breach, then optionally the sprite-art track.

---

## Session 2026-06-24 (7) — Persistence: conquest state survives Continue/return — COMPILE VERIFIED

Closes the [BUG][P2] persistence gap for the live game. The per-territory `development` snapshot now
also carries the conquest state, so Continue / returning to a held territory no longer resets it.
- **Destroyed bases** — `dev["bases_destroyed"]` = spawn-ids of bases already destroyed. On restore
  `Battle._spawn_enemy_bases` permaseals those spawns (so they don't respawn + their DMZ stays lifted),
  repopulates `_destroyed_base_ids` (→ build caps restored), and calls
  `ObjectiveManager.restore_bases_progress(n)` so the DESTROY_BASES objective keeps its progress and the
  win still fires when the remaining bases fall. Half-conquered stays half-conquered; fully conquered
  returns peaceful + buildable.
- **Walls** — `dev["walls"]` = wall cells; `_restore_walls` recreates them as built (`Wall.mark_built`),
  mirroring how towers/garrisons restore.
- Backward-compatible: old saves lack the keys → `.get(..., [])` → behaves like a fresh deploy.
- Build-cap refactor: `_bases_destroyed:int` → `_destroyed_base_ids:Array` (one source for caps +
  persistence); the per-battle reset now lives in `_spawn_enemy_bases` (re-read from dev), not
  `_load_territory_map`.

**Compile:** zero new errors via MCP + clean export. **Runtime: needs playtest** — destroy a base, quit,
Continue → base stays down, spawn sealed, cap raised, any walls present.

**Residual:** general one-time-event objectives (path_discovered / convoy_spawned) still aren't persisted,
but no procgen map uses them (default is DESTROY_BASES, now handled). Revisit only if an authored map needs it.

---

## Session 2026-06-24 (6) — Phase 5: build limits — COMPILE VERIFIED (4A/4B now playtest-verified)

Closes the faction-identity arc. Caps on player towers + garrisons, raised by conquest.
- `TOWER_CAP_BASE` 8 + 2 per enemy base destroyed; `GARRISON_CAP_BASE` 4 + 1 per base (`Battle._tower_cap`
  / `_garrison_cap`, scaled by `_bases_destroyed`). Walls are uncapped (their density cap limits them).
- Enforced in `_try_place_tower` / `_try_place_building` (reject at cap — "destroy an enemy base to raise
  it"); the placement preview greys at cap (`_is_cell_placeable`); placement toasts show the count
  ("Tower sited (4/8)"). Destroying a base bumps `_bases_destroyed` + announces the new capacity. Reset
  per battle (`_load_territory_map`).
- Ties capacity to the conquest loop: fortify modestly early (forces placement choices), earn more as you
  take bases. Stops carpeting.

**Compile:** zero new errors via MCP + clean export. **Runtime: needs playtest** (place towers to the cap →
blocked + greyed preview; destroy a base → cap rises). Tune `TOWER_CAP_*` / `GARRISON_CAP_*`.

**Faction-identity arc (Phases 4–5) feature-complete.** Also flipped Phase 4A (build prefs) + 4B
pollen/hijack to PLAYTEST VERIFIED (2026-06-24 — user confirmed all factions good). Remaining horizons:
Phase 6 multiplayer (far future) + the standing backlog (Continue persistence, monitored hang, garrison
leveling/unit-type, convoy).

---

## Session 2026-06-24 (5) — Phase 4B (ii/iii): Bloom pollen + Mesh hijack — PLAYTEST VERIFIED 2026-06-24

The remaining two faction passives — Phase 4B is now feature-complete (compile).
- **Bloom pollen:** built Bloom towers emit a cloud (`BLOOM_POLLEN_RADIUS` 130) that **slows** (×0.45)
  and **blinds** (can't attack) enemies inside, re-applied every 0.5s and lingering ~1.1s after they
  leave. `Unit.apply_pollen` slows movement (both move paths) + suppresses the melee hit; `Tower._emit_pollen`
  applies it on a cadence and `Tower._draw` shows the aura ring. A control aura — pair with walls/towers
  for a kill box.
- **Mesh hijack:** built Mesh towers convert the nearest enemy in range (`MESH_HIJACK_RADIUS` 180) every
  `MESH_HIJACK_COOLDOWN` 8s for `MESH_HIJACK_DURATION` 6s. `Unit.apply_hijack` swaps groups
  (units → friendly_units, cyan tint) so the player's towers/Commander ignore it and enemies attack it; a
  hijack branch in `Unit._process` makes it chase + melee the nearest remaining enemy; `_end_hijack`
  reverts group + tint on expiry. `Tower._try_hijack` triggers it.

**Compile:** zero new errors via MCP + clean export. **Runtime: needs playtest** (F3 bloom: enemies crawl
+ stop attacking in a green cloud; F2 mesh: an enemy periodically turns cyan and fights its allies). Tune
`FactionPerks.BLOOM_POLLEN_*` / `MESH_HIJACK_*`. **Phase 4B feature-complete** — walls verified; pollen +
hijack compile-clean, need playtest. Next: **Phase 5 build limits** — the last faction-arc piece.

---

## Session 2026-06-24 (4) — Phase 4B (i): Architect walls — PLAYTEST VERIFIED 2026-06-24

Verified in play: walls build, take damage, the Commander repairs them after construction, spacing
reads well, and towers farm enemies stalled at a wall (the intended kill-zone synergy). First faction PASSIVE. New `src/entities/Wall.gd`: a destructible, cell-occupying Architect barrier,
Commander-built (construction state like towers). Deliberately NOT added to the enemy AStar — enemies
path straight into a built wall and must DESTROY it to pass ("block paths enemies have to unblock").
`Unit._engaged_friendly` now also returns built walls as blockers, so an enemy stops + grinds a wall in
melee, then proceeds once it's down. Commander's engineering scan includes "walls" (it builds/repairs them).
- **Placement:** Architect-only "Build Wall" button (added programmatically to the HUD ActionBar HBox,
  shown on faction select for architects) → `wall_placement_requested` → `Battle` wall-placement mode (a
  third mode beside tower/build: preview ghost, LEFT place / RIGHT|ESC cancel). `WALL_COST` 15.
- **Density cap:** `WALL_MIN_SPACING` 2 — no two walls within 2 cells (can't make a solid wall). No
  connectivity test (walls are meant to block; enemies destroy them rather than reroute).
- Walls live in `tower_layer` (cleared on deploy); `_wall_cells` tracks them, pruned of enemy-destroyed
  walls (they free themselves) and cleared on deploy.

**Compile:** zero new errors via MCP + clean export. **Runtime: needs playtest** — F1 architects → "Build
Wall" → place on the enemy corridor → Commander raises it → enemies stop + grind it down to pass (towers
shoot the stalled enemies). Tune `Wall.MAX_HEALTH`, `WALL_COST`, `WALL_MIN_SPACING`.
**Remaining 4B:** Bloom pollen (AoE slow + blind), Mesh hijack (convert an enemy). Then Phase 5 build limits.

---

## Session 2026-06-24 (3) — Phase 4A: faction build preferences — PLAYTEST VERIFIED 2026-06-24

First slice of faction identity. New `src/core/FactionPerks.gd` is the single source of faction
build-pref tuning, preloaded by Commander/Tower/Building (global class_name resolution is unreliable).
- **Architects** — build faster (Commander build rate × `ARCHITECT_BUILD_RATE_MULT` 1.6) + sturdier
  structures (Tower/Building `_max_health` × `ARCHITECT_HEALTH_MULT` 1.4) at construction.
- **Bloom** — towers grow while they stand: a tick (every `BLOOM_GROW_INTERVAL` 5s, cap 6) raises
  `_max_health` (+8%, heals to match) and a `_growth_mult` on damage (+6% compounding) with a subtle
  scale-up. `Tower._apply_growth`, gated in `_process` on `active_faction == "bloom"`.
- **Mesh** — connected tower chains empower endpoints: towers within `MESH_LINK_RANGE` (200px) form a
  graph; an endpoint (≤1 link) gets `_chain_mult` = 1 + 12%·(chain size − 1); interior relays don't.
  `Tower._compute_chain_mult` on the existing buff throttle (`_recompute_buffs`).
- Tower damage now factors `* _growth_mult * _chain_mult` alongside veterancy/aura/territory.

**Compile:** zero new errors via MCP + clean export. **Runtime: needs playtest** per faction (F1 architects
= faster/tougher builds; F2 mesh = build a tower line, the ends hit harder; F3 bloom = towers strengthen
the longer they stand). Tune in `FactionPerks`. **Next:** Phase 4B passives (walls / pollen / hijack), then
Phase 5 build limits.

---

## Session 2026-06-24 (2) — Phase 3: enemy bases fight back — PLAYTEST VERIFIED

**MILESTONE (playtest 2026-06-24): the Commander-bottleneck arc (Phases 2A + 2B + 3) is verified end
to end — the Commander can't solo the map.** Confirmed in play: towers can't be built next to a live
enemy base; the Commander must complete tower + garrison construction; base defenders keep a lone
Commander off the base (you need support); the Commander is destroyed by enemy units and forced to
retreat. Defender-response fine-tuning deferred. **"Justify building" is solved.**

Completes the "justify building" loop — enemy bases now defend themselves, so assaulting is a real
fight and the danger exists even before a wave is called (closes the standby gap).

- **Defender mode (`Unit`):** `setup_as_defender(data, home)` — no waypoints; guards the base, chases
  the nearest player target (commander/friendly) within DEFENDER_AGGRO (220) of the base, leashed to
  DEFENDER_LEASH (240); the existing `_engaged_friendly` melee applies the damage. A defender's death
  does NOT count against a WaveManager wave.
- **Defender production (`EnemyBase`):** fields a standing guard of its faction's units
  (`FriendlyRoster.garrison_unit(enemy_faction)`) — cap 3 idle / 5 when a player target is within
  DEFENDER_THREAT_RADIUS (240); interval 5s idle / 2s threatened (it *responds* to an assault).
  Defenders live in the EnemyBaseLayer (not UnitLayer, which waves clear) and are freed when the base
  dies. `Battle._spawn_enemy_bases` passes the enemy faction so bases defend with the right units.

**Compile:** zero new errors via MCP + clean export. **Runtime: needs playtest** — approach a base with
just the Commander → it spawns defenders that swarm + grind you (mortality bites) → you need a garrison
army + the Commander to crack it. Tune `EnemyBase.DEFENDER_*` and `Unit.DEFENDER_AGGRO/LEASH`.

**The loop is now whole:** building is gated by the Commander (2B), the Commander is mortal (2A), and
bases generate real pressure (3) — a lone Commander can't solo, so you must build garrisons (army) +
towers (defense). Next per plan: Phase 4 faction identity (build prefs + passives), Phase 5 build limits.

---

## Session 2026-06-24 — Phase 2A: Commander mortality — PLAYTEST VERIFIED 2026-06-24

Second slice of the Commander-bottleneck arc — the Commander can now be destroyed.

- **HP + health bar** (`Commander.MAX_HEALTH` 300, ~FOB-durable, tunable) below the body;
  `take_damage(amount, type)` (flat — the triangle governs units, not the hero), `revive()`, and a
  `_dead` gate that halts all action (move/attack/engineer/claim) until revived.
- **Enemies grind the Commander:** `Unit._engaged_friendly()` now also scans the "commander" group, so
  any enemy within MELEE_ENGAGE_RANGE stops and hits it (ENEMY_MELEE_DAMAGE 8/interval each). Parking in
  the fray — e.g. on a base amid spawns — is now dangerous.
- **Death → forced retreat** (`commander_destroyed` → `Battle._on_commander_destroyed`): stop waves
  (`WaveManager.reset`), clear pressing enemies, abandon the invasion (`invading_node=""`), revive the
  Commander at board centre, zoom out to the galaxy. In-battle progress is lost (redeploy reloads fresh)
  — that's the cost. Academy guard: during live scenarios the Commander just revives in place (no retreat).

**Compile:** zero new errors via MCP + clean export. **Runtime: needs playtest** — let a wave swarm the
Commander → health bar drains → at 0 it's destroyed, "forced to retreat," zoomed to the galaxy with a
healed Commander to redeploy. Tune `Commander.MAX_HEALTH`.

**Loop note:** mortality bites while waves are live, but you can still destroy bases during STANDBY (no
enemies = no danger). Closing that needs the next slice — **Phase 3 enemy-base response** (bases spawn
defenders) — so assaulting is dangerous even before a wave is called. That completes "can't recklessly solo."

---

## Session 2026-06-23 (2) — Phase 2B: Commander as engineer (build + repair) — PLAYTEST VERIFIED 2026-06-24

Phase 1 playtest: the Commander could solo every base, so building was pointless. Locked w/ user
(full vision in planning/commander-and-faction-systems.md): make the Commander a mortal, overworked
engineer-leader. First slice (user's pick = engineering): structures need the Commander to construct + repair.

**Construction state (`Tower.gd`, `Building.gd`):**
- Both gain `_max_health`/`_health`/`_built` + `is_built()` / `needs_engineering()` / `receive_engineering(amount)`.
- Fresh placements spawn at START_HEALTH (10), `_built=false`, INERT — a tower doesn't attack/buff/tick;
  a garrison earns no income and runs no production/raids (gated in `_process`; income deferred to
  `_complete_build`). Restored structures load already built (`Tower.setup(data, true)`; Building via `_restored`).
- Visual: ghosted (modulate α 0.5) + a green build/repair bar until complete (`_refresh_build_visual`).
- MAX_HEALTH: Tower 100, Building 120 (tunable).

**Commander engineering (`Commander.gd`):**
- `_try_engineering(delta)` each frame channels build/repair onto the nearest friendly structure within
  ENGINEER_RANGE_PX (110) that `needs_engineering()`, at BUILD_RATE (50 HP/s). The weapon is the tool — a
  green beam drawn in `_draw`. Short range forces the player to park the Commander at the structure.
- The bottleneck: building now competes with claiming / attacking / base assault for the Commander's
  position, so a lone Commander can no longer do everything.

**`Battle.gd`:** `_restore_tower` passes built=true; placement messages now say "move your Commander to
it to finish construction."

**Compile:** zero new errors via MCP + clean export. **Runtime: needs playtest** — place a tower, watch it
sit ghosted/inert; move the Commander onto it, watch the green build beam + bar fill → "online"; confirm it
then shoots. Tune BUILD_RATE / MAX_HEALTH / ENGINEER_RANGE_PX.

**Next (Phase 2 continues):** Commander mortality (health bar + death = forced out), then enemy-base
response (pressure). Note: building still lacks *urgency* until pressure lands (mortality + enemy response).
Risk to verify: the Academy may place/expect instant-working towers — check the Academy path in playtest.

---

## Session 2026-06-23 — Conquest Phase 1: enemy bases anchor spawns — COMPILE VERIFIED

A debug playtest exposed that the `CLAIM_TERRITORY` default win condition auto-completed:
the FOB starts ~1705 cells claimed vs a 200 target, so every territory was "conquered" on
arrival and the spawn no-build exclusion lifted on frame one. New direction (locked w/ user;
full plan in `planning/territory-conquest-plan.md`): conquest = destroy the enemy base anchoring
each spawn. Army assault (Commander + garrison units; towers can't, by the no-fire DMZ).

**Phase 1 (this session):**
- **EnemyBase** (`src/entities/EnemyBase.gd`): destructible structure (500 HP, crimson body +
  HP bar), group `enemy_bases`; `take_damage` → on death emits `EventBus.enemy_base_destroyed(spawn_id)`.
- **One per active spawn** via `Battle._spawn_enemy_bases()` (after `_activate_all_spawns`, in both
  the start and deploy paths) into a dedicated `EnemyBaseLayer` (not cleared at wave end).
- **Army assault:** `Commander._find_nearest_unit_in_range` and `FriendlyUnit._acquire_target` now
  also target `enemy_bases` (reuse `take_damage`). Towers deliberately do NOT.
- **Base destroyed → spawn permasealed** (`MapData.permaseal_spawn_by_id` via `Battle._on_enemy_base_destroyed`):
  the spawn stops emitting and its DMZ (no-fire + no-build) lifts, because the DMZ keys on ACTIVE spawns.
- **Win = DESTROY_BASES** (`ObjectiveData.ObjectiveKind` + `ObjectiveManager._make_bases_objective`):
  target = active-spawn count, +1 per `enemy_base_destroyed`; last base → `map_completed` → capture.
  Retires the auto-completing `CLAIM_TERRITORY` default (kind kept for authored maps).
- **Removed `_battle_won`** (MapGrid flag + `dev["won"]` persistence + map_completed/restore wiring):
  redundant now that the DMZ keys purely on active spawns (= standing bases).

**Compile:** zero new errors via MCP + clean release export. **Runtime: needs playtest** — drive the
Commander onto a base, grind it down, confirm the spawn seals + that spawn's DMZ opens + the objective
ticks; clear all bases → "Territory captured." Tune `EnemyBase.MAX_HEALTH` for feel.

**Deferred (next phases):** Phase 2 intermediate encampments (gate the ~90s perimeter skirt), Phase 3
build limits. Also: base destroyed-state isn't persisted yet (Continue/return respawns bases — same
class as the [BUG][P2] objective-persistence gap).

---

## Session 2026-06-22 — Per-territory win conditions + galaxy return nav — PLAYTEST VERIFIED

Closes the two P2 BACKLOG items from the persistence session. Hand-playtested
2026-06-22: the full deploy → claim → capture loop and galaxy return nav both play well.

**Per-territory win conditions (`ObjectiveManager`, `ObjectiveData`):**
- Added `CLAIM_TERRITORY` kind to `ObjectiveData.ObjectiveKind`.
- `ObjectiveManager._resolve_for_current_faction()` now falls back to `_make_territory_objective()`
  when the resolved list is empty (all procgen maps). The default objective: claim 200 cells,
  faction-voiced description (Architects/Bloom/Mesh variants). `TERRITORY_CLAIM_TARGET = 200`.
- Each `territory_claimed` event increments the objective by 1 (existing Phase-5 stub behavior).
  At 200 claimed cells: `map_completed` fires → `Battle._on_map_completed` → `capture_system`.

**Galaxy return nav (`Battle._handle_galaxy_click`, `_deploy_to_node`):**
- `_handle_galaxy_click` now accepts owned (non-active) nodes in addition to frontier nodes,
  unlocking the `_deploy_to_node` restore-on-return path that was unreachable via UI.
- `_deploy_to_node` distinguishes invading (`invading_node = node_id`) from returning
  (`invading_node = ""`) so `map_completed` on an already-owned territory is a no-op for capture.
- Notification text is context-aware ("Deploying to contested territory — claim 200 sectors…"
  vs "Returning to held territory.").

**HUD repopulate on deploy (`HUD.refresh_objectives`):**
- Added `HUD.refresh_objectives()` — reads `ObjectiveManager.get_active_objectives()` and
  repopulates the panel + summary button. Called from `_deploy_to_node` after `_load_territory_map`.
  Without this, the panel would keep showing the previous territory's objectives after deploy.

**Compile status:** zero new errors (only standing benign EventBus warnings).
**Runtime:** PLAYTESTED 2026-06-22 — deploy → claim → capture loop and held-territory return
nav both play correctly. Game is stable across an extended session.

**Hang investigation (same session):** earlier playtest produced a hard hang (whole-OS
unresponsive, Godot process wouldn't close) when garrisons near a spawn were claiming
territory while a fresh Mesh wave was flank-raiding (un-claiming) the same cells. No crash
dump; logs showed a clean exit. No definitive GDScript-level root cause found — a whole-OS
freeze points more at GPU/driver/memory pressure than a script infinite-loop. Hardened the
hot path anyway (`MapGrid.claim_area` single-redraw batching documented; `Building._complete_raid`
event loop split) and logged a [BUG][P1] with a concrete repro strategy. **Did NOT recur in the
2026-06-22 playtest** — left open on BACKLOG as monitor-pending-recurrence, not closed.

**Known follow-up (out of scope):** ObjectiveManager completion not persisted on Continue
([BUG][P2] in BACKLOG) — on restore, the 200-cell objective resets to 0. Active garrisons
re-fill it quickly via raids, but one-time objectives (path_discovered) stay stuck.

---

## Session 2026-06-21 — Persistence verification COMPLETE + two new BACKLOG items

Hand-playtest of all persistence paths. Zero new errors across three game runs.

**Step 2 (Continue restore) — VERIFIED:**
- Garrison, tower, FOB 300 HP, energy rate all restored exactly
- Map seed regenerated identical layout; offline catch-up (schematics) working
- ⚠️ ObjectiveManager completion resets on Continue — re-completes via garrison raids for
  territory objectives; one-time events (path_discovered, convoy_spawned) stay at 0 on restore
  → added to BACKLOG as [BUG][P2]

**Step 3 (Deploy A→B, capture) — VERIFIED (code review + runtime):**
- `_capture_territory_development` confirmed running before node switch; seeded map loads clean
- ⚠️ Deploy B→A blocked: `_handle_galaxy_click` only accepts `is_frontier` nodes; clicking
  the owned home node emits "That territory isn't on your frontier." Galaxy nav is outward-only.
  The `restore-on-return` path in `_deploy_to_node` (lines 197–201) exists but is unreachable
  without the galaxy-nav enhancement → added to BACKLOG as [ENHANCEMENT][P2]

**New BACKLOG entries (2026-06-21):** [BUG][P2] ObjectiveManager completion not persisted on
Continue; [ENHANCEMENT][P2] Galaxy nav outward-only — no UI to return to held territory.

**Next session (candidates — user picks):**
1. [BUG][P2] Persist ObjectiveManager completion across Continue — directly shores up the
   win-conditions track just shipped (a captured-but-quit territory currently resets its
   200-cell objective to 0 on restore). Natural follow-on.
2. [BUG][P1] Tower-next-to-spawn instakill (DMZ buffer) and [BUG][P1] enemies from only one
   spawn — the two oldest gameplay-feel P1s still open from the 2026-06-20 playtest.
3. [BUG][P1] System-hang monitor — if it recurs, capture frame count at hang per the repro
   strategy in BACKLOG. Not reproduced 2026-06-22.

---

## REGRESSION FIX — Academy cadet control restored — 2026-06-21

The Stage-2 change "make `CadetAvatar` a non-interactive prop (fixes bug #1)" was a **REGRESSION** that
made the Academy unplayable (couldn't move/click during it). **Root cause (git-confirmed: `CadetAvatar.gd`
was the ONLY changed file in the Academy/input path vs the working build 6a395b2):** the cadet's
`_unhandled_input` (click-to-move) IS the player's control during the Academy — `Battle._unhandled_input`
deliberately yields world clicks then (`if not academy_completed: return` → "leave world clicks to the
CadetAvatar"). Removing the handler left NOTHING handling input.
**Fix:** `git checkout 6a395b2 -- src/academy/CadetAvatar.gd` (click-to-move restored). Rebuilt, boots clean.
**DO NOT REPEAT:** the cadet's click-to-move is by-design. "Bug #1" (cadet nudges/drifts on click) IS
click-to-move working — it is NOT a bug; do not remove the handler.

**Pre-existing, NOT regressions (open enhancements, were like this in 6a395b2 too):** (a) the Academy
*scenarios* are passive — the cadet is hidden during them (`Academy._run_all_scenarios`) and `Battle` is
guarded, so the 75/90/90s scenarios had no player control. **FIXED 2026-06-21:** `Battle` now accepts
world input during the scenario phase (`_academy_scenarios_active`, gated on `academy_phase_started`/`_ended`)
+ pre-selects the Commander → the player commands the real Commander during scenarios (move/select/attack,
feeding the behavior tracker). Tower placement during scenarios still needs the HUD shown (smaller follow-up).
(b) the input-spam "crash" is the
known queued **rapid-click hang**.

## Per-territory persistence — Steps 1–5 COMPLETE — 2026-06-20 — RUNTIME VERIFIED 2026-06-21

Goal: a galaxy territory's development (buildings/towers/claims/FOB) survives leaving it + a Continue —
unblocks offline resolution on a real Continue + the Total-War campaign loop. Design + 5-step plan:
`planning/persistence-design.md`.

- **Step 1 (committed):** `SaveManager` persists `active_node`/`invading_node` (save v2, additive).
  `Battle._start_game_world(is_restore)` — on a FRESH start, pins the home node's seed to the actual
  played map's `map_data.map_seed`, so a Continue regenerates THAT map (initial map uses a random
  time-seed at `MapGrid._ready`).
- **Step 2 (this change):** Continue restore reloads the active node's seeded map (new
  `Battle._load_territory_map`, shared with `_deploy_to_node`) + re-applies saved CLAIMED cells.
  Capture: new `EventBus.game_saving` → `Battle._capture_territory_development` writes claims into the
  node's `development`. MapGrid `get_claimed_indices` / `apply_claimed_indices` (JSON-safe flat
  indices, GROUND→CLAIMED only; economy is restored separately so no double-count).
- **Verification caveat:** the restore/capture run only on a real Continue / during play — NOT
  MCP-injectable. MCP confirms compile/load clean (zero errors; only the new benign `game_saving`
  warning). Real proof = a hand-playtest Continue (New Game → play → quit → Continue → map + claimed
  ground return).
- **Step 3 (this change):** persist/restore buildings (garrisons). Capture `[{id, cell, level}]` into the
  node's `development` (`Battle._capture_buildings`); restore via `Battle._restore_building` after the
  map + claims load. `Building.setup(data, restored)` + a `_restored` guard skip the `_ready`
  `add_territory_rate` on restore (territory_rates already includes it → no income double-count on
  Continue). **Unblocks offline army resolution on a real Continue** — garrisons now exist to fast-forward.
- **Step 4 (this change):** persist/restore towers + FOB rank. Towers captured as `[{id, cell, level}]`
  — the current-tier `.tres` (id) encodes the upgrade branch, so `Battle._restore_tower` re-instantiates
  at that tier, calls `mark_tower_placed` (pathing), and `Tower.restore_level` re-derives damage
  multiplier/XP/sight/chevrons. FOB rank via `Base.restore_rank` (re-applies the rank-scaled sphere;
  idempotent vs the already-restored claims → no economy double-count). Towers add no income → no guard.
- **Step 5 (this change):** capture-on-deploy + restore-on-return. `_deploy_to_node` snapshots the
  leaving territory (`_capture_territory_development`, before switching `active_node`) and restores the
  destination's saved development (shared `_restore_territory_development`, also used by Continue) — so
  development holds across multi-territory play, not just save/Continue. **Per-territory persistence
  COMPLETE (Steps 1–5).**
- **Known follow-ups (flagged, out of scope):** cross-territory income is approximate (`territory_rates`
  is a single global accumulator that leaks across deploys → belongs with the galaxy-campaign economy
  model); FOB rank is modeled per-territory (one FOB node fortifies independently per territory).
- **Runtime verified 2026-06-21:** Continue restore confirmed (garrison/tower/FOB HP/energy rate/map
  seed/offline catch-up all correct). Deploy A→B capture confirmed. Deploy B→A (restore-on-return)
  unreachable via current UI — galaxy nav only accepts frontier nodes; see galaxy-nav BACKLOG item.

## Architecture North Star (PROPOSED) — scene-separation refactor — 2026-06-20

Strategic review prompted by the recurring Commander-select / "click eaten" bugs. **Root cause is
architectural, not a code defect:** the Academy + FactionSelect + GameOver are layered into the
single `Main.tscn` as CanvasLayer overlays on top of the already-live `WorldMap`, so multiple input
handlers and two "player units" (`CadetAvatar` vs `Commander`) coexist. Every "something ate the
click" bug — including the 2026-06-20 "Commander shifts slightly then returns" (you're nudging the
Academy's `CadetAvatar`, not the `Commander`; `Main` ignores world clicks until `academy_completed`)
— is the same class.

**Target (user-approved direction, NOT yet built):** a thin `Root` + `SceneManager` swapping ONE
screen at a time (Title / Academy / FactionSelect / Battle⇄Galaxy / Pilgrimage / Arrival); state
stays in autoloads; comms stay on EventBus; **Battle⇄Galaxy stays unified** (Phase-D continuous
zoom). Migration is incremental + MCP-verified: **Stage 1** Root+SceneManager, **Stage 2** lift
Academy+FactionSelect out (kills the bug class), **Stage 3** rename `Main`→`Battle`, **Stage 4+**
new systems arrive as their own screen.

**Full reference: `planning/architecture-north-star.md`** — READ before adding any screen/system.
**Status:** doc approved; **Stage 1 DONE 2026-06-20** — `Root` boot scene (`scenes/Root.tscn` +
`src/core/Root.gd`) + `SceneManager` autoload (`src/autoloads/SceneManager.gd`, fade swap that keeps
the active screen as `current_scene` so `reload_current_scene()` still works); `run/main_scene` →
`Root.tscn`; `TitleScreen` New Game/Continue route through `SceneManager.change_to`. Boots clean via
MCP, zero new errors.

**Stage 2 DONE 2026-06-20** (revised with the user — the Academy is a *guided first Battle* that
observes real play, NOT a separable screen, so it stays a **director on the Battle screen**, like
Galaxy⇄Battle). Killed the bug sources: `CadetAvatar` is now a non-interactive cutscene prop (fixes
the 2026-06-20 "cadet drifts on click" = bug #1; it never was the Commander); deleted the orphaned
`FactionSelectScreen` (.gd/.uid/.tscn — the Academy superseded it); renamed `Main.gd`'s misleading
`faction_select` → `academy`. `Main.tscn` runs clean via MCP (zero errors; only standing benign
warnings). **Stage 3 DONE 2026-06-20** — renamed the gameplay scene/script `Main`→`Battle` (`scenes/main/
Battle.tscn` + `.gd` + `.gd.uid`; root node `Main`→`Battle`); `TitleScreen`'s `MAIN_SCENE`→
`BATTLE_SCENE` path constant. Only 5 functional refs existed (nothing referenced the node by name;
the `main_controller` group string is unchanged). Verified via MCP: `Battle.tscn` runs clean AND
normal boot (Root→Title) clean — zero errors both. **Stages 1–3 (the SceneManager + scene-separation
refactor) COMPLETE.** Stage 4+ = ongoing discipline (new systems arrive as their own screen).

## Fix — Commander select regression: world-space Controls ate the click — 2026-06-17 (verified live)

The 2026-06-16 Academy-`queue_free()` fix only *masked* this. Root cause: entity visuals are
built from `ColorRect`/`Label` nodes (`Control`s), which default to `MOUSE_FILTER_STOP` and
consume LMB in `_gui_input` **before** `_unhandled_input` runs — so a dead-centre click on the
Commander (where the FOB body + gold `_visual` overlap) reached **neither** the Commander nor
`Main`. Off-centre clicks within the 58px select radius worked, which hid the bug.

**Fix:** every entity's `_build_visual` now loops its `Control` children and sets them to
`Control.MOUSE_FILTER_IGNORE`. Applied to `Base` (FOB), `Commander`, `Unit`, `FriendlyUnit`,
`Building`, `Tower`, `Convoy`. Diagnosed with temp `push_warning` probes in
`Commander._unhandled_input` + `Main._unhandled_input` (removed); when neither fired on a
click, a GUI `Control` was the culprit. **Verified live:** deselect (empty ground) → reselect
dead-centre on the Commander → green ring reappears; clean compile, no new warnings.
Rule going forward: any decorative `Control` in world space must be `MOUSE_FILTER_IGNORE`.

## Phase D1 — Galaxy layer: continuous zoom + seeded-territory deploy — 2026-06-17 (verified live)

First slice of the Total-War campaign pillar. Design chosen with the user: **continuous
tactical→galactic zoom** (not a separate screen) + **battle integration** (deploy to a node
loads its battle map; winning captures it).

- **Galaxy graph** (`GalaxyManager`): `generate_galaxy` builds concentric rings of territory
  nodes around a central **core**, webbed to adjacent rings + ring neighbours; player starts
  owning one rim node. Each node = JSON-safe `{owner, ring, px/py, adj[], seed}`. `frontier()` =
  nodes adjacent to an owned node (capturable). `ensure_galaxy` generates once per save;
  deterministic per `galaxy_run_number`. `active_node` / `invading_node` track "you are here" /
  the node a win captures.
- **Continuous zoom** = literal spatial zoom: `GalaxyView` (`src/ui/GalaxyView.gd`, mounted under
  WorldMap) draws the graph in world space **recentred so the active node sits at the board
  centre**, far larger than the board. `CameraController` now zooms out past board-min down to
  `GALAXY_ZOOM_MIN` and pans freely there (`is_galaxy_zoom()`/`board_min_zoom()`); the view only
  renders while zoomed out, so wheeling out shrinks the board to the home node and reveals the
  rings. Nodes coloured by owner (yours/neutral/rival/core); active = white ring, frontier =
  yellow ring.
- **Deploy + capture loop** (`Main`): a left-click while zoomed out picks a frontier node
  (`_handle_galaxy_click`) → `_deploy_to_node` clears the battle's transient entities and
  `MapGrid.load_map_data(MapGenerator.generate(node.seed))` (the territory's own seeded map),
  zooms back in. Capturing triggers on **`map_completed`** (`_on_map_completed` →
  `GalaxyManager.capture_system`) — winning the territory's objectives flips ownership and opens
  new frontier.

**Verified live:** zoomed out → galaxy graph (home node + frontier + adjacency edges) → clicked a
frontier node → its seeded battle map loaded and the camera zoomed back in; zero errors (one
`owner` shadow warning fixed). **Capture-on-win is wired but not yet played-out live** (needs the
territory's claim objective completed). **Key follow-up:** persist per-territory state (buildings,
claims, ownership) — the `map_seed` model holds the layout, but a territory's *progress* isn't
saved yet, so this + Phase-C offline resolution only fully land once that persistence exists. Also
deferred: HUD/labels in galaxy view, win-condition design per territory, diplomacy layer
(treaty/alliance stubs already in `GalaxyManager`, core/11+20).

---

## Phase C4 — Live offline resolution — 2026-06-17 (verified live) — PHASE C COMPLETE

Closes the garrison pillar and the "endless offline" promise: time away is resolved by
fast-forwarding the army's REAL behavior, not a hand-wavy formula.

- **`Building.simulate_offline_raids(seconds)`** runs the garrison's standing-order raids
  cycle-by-cycle over elapsed time (`OFFLINE_RAID_CYCLE` 30s/raid, capped `OFFLINE_MAX_RAIDS`
  20), using the *same* `get_raid_target` + `claim_area` against the live map — so each claim
  advances the frontier exactly as it would have online. Naturally bounded by `RAID_RANGE_CELLS`
  around the garrison. Returns cells claimed.
- **`Main._resolve_offline_army(seconds)`** sums every garrison's offline raids and pushes one
  summary: "While you were away (N min), your garrisons claimed N cells of territory."
- **Wired to `EventBus.offline_catch_up`** (`Main._on_offline_catch_up`) — the existing
  `SaveManager` → `EconomyManager.apply_offline_time` (8h cap) path. **Caveat:** placed buildings
  and claimed cells are NOT persisted in the save yet, so a real Continue has no garrisons to run
  — correctly wired for when that persistence lands (it belongs with the galactic-map territory
  state, `map_seed` model). Exercisable now via **dev key F4** (debug build, in-game) = simulate
  1 hour.

**Verified live:** F1 → place garrison → F4 → Territory jumped to 44 cells (from ~12), claimed
region expanded, income rose, claim objective complete; zero errors.

**Phase C (Garrisons & friendly army) is COMPLETE** — C1 production, C2 two-way combat + patrols
+ leveling, C3 standing-order raids, C4 offline resolution. **Follow-ups before this fully
lands in normal play:** persist buildings + claimed cells in the save (ties into the per-territory
galactic-map state) so offline resolution and territory survive a Continue; explicit standing-order
toggle UI; resource-investment to develop garrisons; role/tier unlocks at higher garrison levels.
Next pillar: **D — macro→galactic zoom / multi-front** (the Total-War campaign layer).

---

## Phase C3 — Standing-order raids (territory expansion) — 2026-06-17 (verified live)

The army goes offensive: garrisons expand the player's territory during lulls — the on-map
seed of the galactic "capture adjacent ground toward the core" vision, and the loop C4 will
fast-forward offline.

- **Raid-target finder:** `MapGrid.get_raid_target(from_cell, max_radius)` → nearest GROUND cell
  on the CLAIMED frontier (orthogonally adjacent to CLAIMED/BASE) within range, so territory
  grows outward contiguously (`_has_claimed_neighbor` helper). Claiming reuses `claim_area`.
- **Raid mode on units:** `FriendlyUnit.set_raid_target/clear_raid` — a raiding unit marches to
  the target with the **leash released** (`_move_toward(..., clamp_leash=false)`). Priority in
  `update()` is **defense > raid > patrol > guard**, so raiders drop everything to fight.
- **Garrison raid logic:** `Building._update_raid()` (each production tick) — when the squad is
  full (`RAID_MIN_SQUAD`) and **safe** (`_enemy_within(RAID_THREAT_RADIUS)` false), it picks a
  frontier target and points the squad at it; on a raider reaching it (`RAID_REACH_DIST`), it
  `claim_area`s a pocket (`RAID_CLAIM_RADIUS`), registers economy + `territory_claimed`, and
  notifies. Enemies near the garrison **withhold/abort** the raid (defense first) → the army
  expands in lulls, defends in waves.
- This is the "standing order" implicitly = *expand when strong and safe* (no toggle UI yet).

**Verified live:** placed a garrison, no waves → squad filled, raided the frontier, "Raiding
party claimed 6 cells", Territory 12 cells, claim objective 1/1; zero errors. **Next:** C4 live
offline resolution (fast-forward the `update()`/raid ticks over elapsed time). Deferred: explicit
standing-order toggle UI; raids scaling with garrison level; raiders self-defending far from home.

---

## Phase C2 — Two-way combat, patrols, garrison leveling — 2026-06-17 (verified live)

Makes the friendly army feel alive — the real RTS clash on top of C1's defenders.

- **Two-way combat (enemies blocked):** `Unit.gd` (enemy) — when a `friendly_units` member is
  within `MELEE_ENGAGE_RANGE` (40px), the enemy STOPS advancing and attacks it on
  `MELEE_INTERVAL` via the one triangle (`Combat.faction_damage_type(data.faction_id)` vs the
  friendly's armor; `_melee_damage()` = `max(attack_damage, ENEMY_MELEE_DAMAGE)` fallback).
  Multiple enemies on one defender swarm it. `_engaged_friendly()` helper.
- **Defenders body-block + report kills:** `FriendlyUnit.gd` — now closes to `BLOCK_RANGE`
  (28px) to physically stop a foe (replacing C1's self-attrition; enemies now deal the damage),
  and on a killing blow calls its garrison's `report_kill()`.
- **Patrols:** idle defenders roam a slow loop (`PATROL_RADIUS`/`PATROL_ANGULAR_SPEED`,
  phase-staggered) once the squad reaches `GARRISON_PATROL_THRESHOLD` (2); the garrison toggles
  `set_patrol()` each production tick. Below threshold they return to the guard post.
- **Garrison leveling:** `Building.gd` — `report_kill()` banks XP; every
  `GARRISON_XP_PER_LEVEL × level` kills → level up (notification). Level raises the squad cap
  (`_max_units` = base + level−1) and speeds production (`_produce_interval`, floored at 2s).

**Verified live:** placed a garrison, ran wave 1 — it produced a spread squad that held the
line; FOB ended at 294/300 vs 6 enemies; zero runtime errors. Tick logic stays in `update()`/
`_process` so the C4 offline sim can fast-forward it. **Next:** C3 standing-order raids; C4 live
offline resolution. (Deferred polish: resource-investment UI to develop a garrison; role/tier
unlocks at higher garrison levels.)

---

## Phase C1 — Garrison foundation (friendly army) — 2026-06-17 (verified live)

First slice of the biggest pillar (active-RTS + offline army, `planning/vision-roadmap.md` §3).
Design locked with the user: **(1) one combat triangle** — the 5 roles (Inf/Cav/Armor/Support/
Recon) are behaviors, not a second RPS; **(2) live offline simulation** — so the army layer is
built tick-driven (`FriendlyUnit.update(delta)`) to fast-forward later; **(3) faction-specific
rosters** (core/17) — friendly units reuse the same roster as the waves (your faction's Drone
defends; the enemy faction's Drone attacks).

**What C1 ships:**
- `UnitData` += `attack_damage` / `attack_range` / `attack_interval` (default 0 — enemies stay
  inert non-combatants; only friendly combat units use them).
- `src/core/army/FriendlyRoster.gd` — maps player faction → its Tier-1 roster unit (loads the
  real `*_t1.tres`, duplicates it, applies default T1 attack stats if unset; note singular file
  names vs plural faction ids).
- `src/entities/FriendlyUnit.gd` — friendly combat unit (group `friendly_units`). Leashed to its
  home garrison (`MAX_LEASH`), acquires nearest detectable enemy in `AGGRO_RADIUS`, fires via
  `Combat.faction_damage_type(active_faction)` → the triangle, takes attrition from adjacent
  enemies (`CONTACT_DPS_PER_ENEMY` — swarms punish a lone defender), dies. Behavior is in
  `update(delta)` so the C4 offline sim can drive it headlessly/accelerated.
- `Building.gd` → every production building is now also a **garrison**: produces a defender on a
  `GARRISON_PRODUCE_INTERVAL` (5 s) cooldown up to `GARRISON_MAX_UNITS` (3). Spawns into the
  shared `WorldMap/UnitLayer` (`../../UnitLayer`), pruning dead units each tick.

Towers target group `units` only, so they ignore friendlies; enemies don't yet target friendlies
(C2). **Verified:** placed a building → it produced a cyan defender → wave 1 dropped 6→2 with the
FOB untouched as defenders engaged. Zero new errors.

**Next sub-passes:** C2 patrols + garrison leveling (and enemies retaliating / being blocked by
friendlies); C3 standing-order raids claiming adjacent ground; C4 live offline resolution.

---

## Phase B — Map-generator pass: branching corridors + galactic-persistence hook — 2026-06-17 (verified)

Resolves the Phase B "divergence is latent" finding: `MapGenerator` carved exactly ONE
corridor per spawn, so `get_diverse_paths_to_base` always returned a single route and the
faction policy had nothing to express.

**Branching corridors.** Replaced `_carve_winding_path` (single winding L-chain per spawn)
with **`_carve_branching_path`**: two parallel corridors per spawn that bend to OPPOSITE sides
of the spawn→base axis and rejoin only at the endpoints (`_carve_h_corridor` / `_carve_v_corridor`,
lane offset ±`spread` 5–9 cells). Each spawn now offers ≥2 genuinely distinct routes; corridors
from different spawns also cross, multiplying options (the RTS-loose feel). **Verified live:
every spawn → 2 routes** (temp `BPATH-VERIFY` log, since removed); the map now renders as a
parallel-rail network around the FOB instead of a single cross. Faction divergence (Architect
direct / Bloom sprawl / Mesh weak-point) is now expressible on every generated map.

**Persistence / galactic-map architecture decision (answer to "do we switch map formats?").**
**No format switch.** `MapData` already `extends Resource` with all state `@export`-ed — it
serializes to `.tres` natively ("saving and reloading restores the full runtime state"). And we
don't need to *store* maps either: `MapGenerator.generate(seed)` is deterministic, so a battle
map is reproducible from its seed alone. Added **`MapData.map_seed`** (set to `rng.seed` at
generation; named `map_seed` not `seed` to avoid shadowing the built-in). **Galactic vision
(Total-War-style, future Phase D):** the galaxy is a graph of *territory nodes*, each storing a
`map_seed` + campaign metadata (adjacency, owner, distance-to-core); you expand by capturing
nodes adjacent to your holdings, pushing toward the core, and each node's battle map regenerates
from its seed on demand — persistence without bulky storage, and random-spawn testing still works
(seed 0 = random). The cardinal spawns a territory exposes would eventually mirror that node's
graph adjacency.

---

## Phase B — Faction-flavored enemy pathing — 2026-06-16 (core landed; compiles clean, units path live)

Vision pillar #2 (`planning/vision-roadmap.md`, codex §05): enemy movement follows faction
norms instead of one fixed lane. Built on the existing AStar lane graph + waypoint units —
no rewrite. Two pieces:

1. **`MapGrid.get_diverse_paths_to_base(spawn_cell, k=3)`** — returns up to `k` DISTINCT
   world-space routes, shortest-first, via the **penalty method**: query shortest path,
   inflate the `weight_scale` of its interior cells (×3), re-query for a detour, repeat,
   then restore all weights so other AStar queries are unaffected. Where the map has no
   alternate corridor the routes collapse to one (returns fewer than k). Dedupes by cell
   signature.
2. **`WaveSpawner` per-faction assignment policy** (`_faction_path`, reads
   `_current_unit_data.faction_id`): **Architects → route 0** (direct/efficient);
   **Bloom → least-used route** (`_least_used_route_idx`, even sprawl across all corridors);
   **Mesh → least-defended route** (`_weakpoint_route_idx` scores towers within 160px of each
   route, picks the softest, with a 25% probe of a random alternate — raider weak-point seek).
   Route sets are cached per spawn cell and invalidated on `wave_started` / `wave_ended` /
   `path_changed` (so a tower placed mid-wave reshapes the routes).

Flankers and the Academy keep their own pathing (unchanged). Reroute on `path_changed` still
uses the plain shortest path (faction-agnostic fallback — acceptable for the rare mid-wave
block). Verified: F1→architects, Begin Waves — Mesh enemies spawn from 4 axes and path to the
FOB, wave resolves, zero new errors.

**DEV keys (debug builds only, `OS.is_debug_build()`):** F1 = Architects, **F2 = Mesh,
F3 = Bloom** — skip the Academy straight into a game as that faction (each faces a different
enemy: Architects→Mesh, Mesh→Bloom, Bloom→Architects). Used to playtest all three enemy
pathing styles. (F2/F3 hardcode each faction's own first sub-path — `standard`/`networked`/
`purist`; passing the wrong sub-path trips an `assert` in `FactionManager.select_faction`.)

### Playtest findings — 2026-06-16 (instrumented route logging + all three factions)

Ran F1/F2 with temporary `BPATH-DIAG` logging of route counts + per-faction assignment. **The
mechanism is verified correct and crash-free for all three enemy factions**; the assignment
policy executed exactly as designed (Architect→route 0; Bloom→least-used; Mesh→least-defended,
which correctly == route 0 when no towers are down). **Key finding: divergence is currently
LATENT because maps rarely offer parallel corridors.** `get_diverse_paths_to_base` returned 2
equal-length routes on one procedural seed (proving the penalty method works) but **1 route per
spawn on most maps — both the procedural generator and the hand-authored `DefaultMapBuilder`**
(verified: forcing DefaultMapBuilder still gave 1 route/spawn — its corridors are single, not
the two-branch layout that lives in `MapGrid._build_default_paths`). When AStar finds no genuine
alternate, the penalty method correctly returns one route, so Bloom sprawl / Mesh weak-point
seek have nothing to express. **The real Phase B "make it expressive" follow-up is to make the
map generator produce parallel corridors / loops reliably** (then the existing policy lights up
for free). Other follow-ups: optional lateral jitter; faction-aware reroute; possibly a stronger
diverse-route penalty. (Also surfaced: rapid F-key presses during the Academy chamber can trip
the known rapid-click hang — unrelated to Phase B.)

---

## UI session — 2026-06-16 (windowing fixes + SupCom-style dashboard)

Three reported bugs, all traced to one root cause, plus a HUD reskin into a
Supreme Commander: Forged Alliance–style dashboard layout (original art, FA
layout conventions — no copied assets). Verified clean via Godot MCP: ran both
the full project and `HUD.tscn` directly; zero errors (only the standing benign
EventBus "signal never used" warnings).

1. **Can't sell towers / buttons under the taskbar / window won't foreground** —
   all three were borderless-fullscreen sitting *behind* the always-on-top
   Windows taskbar, so the InspectionPanel's bottom Sell button was physically
   un-clickable. The sell *wiring* was always correct
   (`InspectionPanel._on_sell_pressed` → `EventBus.panel_sell_requested` →
   `Main._on_panel_sell_requested`). Fixes:
   - `project.godot`: launch **maximized** (`window/size/mode=2`).
   - `TitleScreen.gd`: `DisplayServer.window_move_to_foreground()` on `_ready`;
     fullscreen toggle + settings load now use **EXCLUSIVE_FULLSCREEN** (covers
     the taskbar) when on, **MAXIMIZED** (respects work area, above taskbar) when
     off — never a tiny floating window.
2. **Academy intro misaligned** — the Academy is instanced under a CanvasLayer at
   a fixed `position = Vector2(960, 540)` (center of the 1920×1080 base). With
   `window/stretch/aspect="expand"` the canvas anchors top-left and grows on
   non-16:9 (maximized) windows, drifting that center. Changed aspect to **`keep`**
   (letterbox), which re-centers every fixed-1920×1080-authored layout, Academy
   included.
3. **Final HUD layout (per user direction, revised from the FA mockup):**
   minimap → **bottom-center** (`Minimap.gd` self-positions); abilities + build
   options → **bottom-left as a two-row grid** (`AbilityBar` row above the
   `ActionBar` build row in `HUD.tscn`); selection panel → bottom-right; resources
   → top strip. `HUD.gd` no longer positions the minimap.
4. **Dashboard reskin (FA layout language):**
   - `HUD.gd` builds a programmatic dark/angular **Theme** (`_build_dashboard_theme`)
     applied at the HUD root — near-black panels with a cyan top-edge frame, dark
     angular buttons with cyan-hover / orange-press accents, dark-track/cyan-fill
     progress bars. Cascades to every panel, button, and AbilityBar slot.
   - `HUD.tscn` re-anchored: `ResourceCluster` → full-width **top economy strip**
     (inner `VBox` switched to `HBoxContainer`; node name kept so `@onready` paths
     hold); `InspectionPanel` → **bottom-right**. (Command/ability bars and the
     minimap were re-placed again per item 3 above.)

Still TODO on the dashboard: true resource **gauge bars** in the top strip
(resources are uncapped, so a fill needs a meaningful reference — deferred until
a soft-cap/storage model is chosen). Visual confirmation in-game (selling,
target cycle, layout) is best done by launching a New Game run; the prior
window-focus chaos made automated computer-use playtests unreliable.

---

## Phase A — Enemy factions in waves — 2026-06-16 (compiles clean)

Waves now spawn an **enemy faction**, not the player's own units — the combat triangle
(and FOB doctrine / tower branches) is finally live. `WaveTableBuilder.enemy_of(player)`
returns the faction the player is WEAK against (Architect→Mesh, Mesh→Bloom,
Bloom→Architect), so the player must adapt to win. `WaveSpawner._on_faction_selected`
builds the wave table from that enemy and pushes a "Hostile faction on this front: X"
notification. Single enemy per run (vision: most maps = one enemy; alternating + 3-way
convergence are later enhancements, see vision-roadmap.md). B (faction pathing) and C
(garrisons/army) are queued in improvement-plan.md.

NOTE: faction_selected also fires during the Academy pre-seed (architects), so the
"hostile faction" toast may flash in the chamber — harmless, re-fires correctly on the
real faction commit. Flip the default enemy in `WaveTableBuilder._DEFAULT_ENEMY` if the
weak-matchup start feels too punishing.

---

## Vision roadmap + veterancy condense — 2026-06-16 (compiles clean)

- **Veterancy icons condense.** `RankChevrons.gd` rewritten: every 3 ranks collapse
  into a filled "star" diamond pip (gold → cyan past 3 stars), remainder shown as small
  chevrons. Rank 9 = 3 stars instead of 9 triangles. Used by Commander / Tower / Base /
  Convoy. Q ability stays charge-gated (design decision).
- **`planning/vision-roadmap.md`** captures the post-MVP direction: (1) enemies = the
  other two factions converging on shared territory, (2) faction-flavored enemy pathing
  (Architect direct / Bloom sprawl / Mesh directional-spread), (3) garrisons that spawn a
  role-based friendly army (Inf/Cav/Armor/Support/Recon) with patrols, garrison leveling,
  standing-order raids, and offline territory claims, (4) micro→galactic zoom / multi-front.
  Proposed phasing A→D in that doc; **Phase A (enemy factions in waves)** is the
  foundational unlock that makes the combat triangle live.

---

## Fix — Commander couldn't be selected (lingering Academy ate left-clicks) — 2026-06-16 (verified live)

**Symptom (user):** "Unable to move the commander… can't get it selected… selection box
might be too small." Couldn't select even when zoomed all the way in/out.

**Root cause (found via live diagnostics over Godot MCP + computer-use):** the Academy
(`$UILayer/Academy`, a `Node2D`) was only **hidden + process-disabled** on entering the game
world, never freed. `hide()` on a Node2D does **not** hide its child **CanvasLayer** nodes
(`TextLayer`, `SortingLayer` with their Buttons). Those overlays stayed visible and
interactive. A Godot `Button` **consumes left-clicks but lets right-clicks fall through to
`_unhandled_input`** — which is exactly why **right-click move worked but left-click select
never reached `Main._handle_select_click`** (proved with temp `push_warning` probes: F1 key and
RMB reached Main, LMB never did). This affected the **real Academy-completion path too**, not
just the F1 dev-skip — both route through `_start_game_world`.

**Fixes (`Main._start_game_world`, `Commander.gd`):**
1. `_start_game_world` now **`queue_free()`s the whole Academy subtree** (guarded by
   `is_instance_valid`), killing the CanvasLayer overlays and the CadetAvatar's input handler.
   Covers normal-completion, F1-skip, and save-restore entry paths.
2. Selection radius was genuinely too tight: a dead-center click measured **104 world-units**
   from the Commander vs a **93-unit** radius. Bumped `COMMANDER_SELECT_SCREEN_PX` 38 → **58**
   (~140 world-units / ~2.2 cells) and the visible `SELECT_RING_RADIUS` 32 → **44** for a
   clearer "selected" indicator.

**Verified live:** click empty ground → deselects; click Commander → selects (ring shows);
right-click → moves. Zero new errors.

---

## Controls overhaul + FOB doctrine + hit box — 2026-06-16 (compiles clean)

1. **RTS commander controls (centralized in Main).** The Commander no longer moves on
   left-click. Main owns all world clicks: **LEFT = select** (Commander / tower /
   building / FOB), **RIGHT = move** the selected Commander, **Shift+RIGHT = chain**
   waypoints. The Commander always draws a **selection ring** when selected; the **queued
   move path is SupCom-style — drawn only while Shift is held** (`_shift_held`, polled via
   `Input.is_key_pressed(KEY_SHIFT)` in `_process`), so it no longer trails the Commander
   during normal movement. Holding Shift previews the path and chains more waypoints; while
   shown during movement it redraws each frame to stay anchored. (2026-06-17 UX tweak.)
   `Commander`: `_move_queue` + `set_selected`/`is_selected`/`move_command`; its
   `_unhandled_input` now only delivers ground-targeted ability casts. This also kills
   the old Commander-vs-Main click race (source of the inconsistent panel opening). A
   New Game guard skips world clicks until `academy_completed`.
2. **Generous hit box.** Structure selection is now distance-based
   (`_structure_at_world`, `STRUCTURE_HIT_RADIUS=40`) instead of exact-cell — clicking
   anywhere on/near a tower/building/FOB selects it. Commander select radius is tighter
   (26px) and takes priority.
3. **FOB doctrine (RPS upgrade).** Click the FOB → pick one of three faction-aligned
   doctrines (re-selectable, costs `FOB_DOCTRINE_COST=80` primary). Each sets the FOB
   turret's damage type in the combat triangle + a playstyle perk:
   Architect = Kinetic + ×1.6 fire rate; Bloom = Corrosive + 4 HP/s regen; Mesh =
   Energy + 3-cell detection. `Base._doctrine` + `set_doctrine`/`get_doctrine`/
   `_turret_damage_type`; `EventBus.fob_doctrine_requested`; `Main._on_fob_doctrine_requested`;
   doctrine buttons in `InspectionPanel.open_fob`.

---

## Fixes — playtest round 3 — 2026-06-16 (compiles clean)

1. **Tower panel inconsistent / wouldn't reliably open + FOB had no menu** — root
   issues: (a) the FOB wasn't clickable, so with towers packed around it imprecise
   clicks hit the menu-less FOB → felt random; (b) the panel auto-sizing was flaky.
   Fixes: added **FOB inspection** (click FOB → HP / fortification rank / detection
   radius; not sellable/upgradable) — `Main._open_fob_inspection` + `_fob_cell()` in
   `structure_at_screen`, `HUD.open_fob_inspection`, `InspectionPanel.open_fob`. Made
   the InspectionPanel deterministic: fixed 360px width via `custom_minimum_size`,
   content-height with `grow_vertical=0` (pinned bottom-right, grows up). Now every
   click on the FOB/tower cluster opens a relevant panel.
2. **Wave panel off-screen** — the "Next: Wave N … [Begin = call early]" preview is a
   long single line that overflowed the 216px panel off the right edge. WavePanel now
   insets further (`offset_right=-12`), widened, and `grow_horizontal=0` so long lines
   grow left instead of off-screen.
3. **Q ability AOE invisible** — `_cast_lance` only spawned the ring when it hit a
   unit (`if hits > 0`); pressing Q with no enemies adjacent fired but showed nothing.
   Now always flashes the ring on cast.

NOTE: the "panel delayed by a wave" symptom should be resolved by the deterministic
sizing + clickable FOB; if it recurs, capture exact repro (during/between waves,
tower position) — likely an input-precision case the FOB click now absorbs.

---

## Fixes — playtest round 2 — 2026-06-16 (compiles clean)

1. **Stealth regression** — the FOB's stealth-detector used `(sight+sensor)*64` and
   scaled with fortification, ballooning past 1000px so a leveled FOB revealed units
   at the spawns. Now a fixed `FOB_DETECTOR_RADIUS_CELLS = 6` (384px) bubble — covers
   the base approach, never reaches map-edge spawns. (`Base.get_detector_radius`.)
2. **Tower/building panel didn't open** — the `autowrap` Label I'd added to
   `InspectionPanel` collapsed the `PanelContainer` layout (Godot feedback loop), so
   the panel rendered as a sliver. Removed autowrap, enlarged to a fixed 360×320 (grows
   up via `grow_vertical=0`), and split the stats into short lines so nothing overflows.
3. **Commander rank icon unstable/vanishing during movement** — gave `_rank_bar` and
   `_rank_chevrons` `z_index = 20` so the moving sight/sensor rings can't visually
   swallow them. (Tentative — confirm in playtest; if it persists the cause is likely
   per-frame claim/reveal churn, which we'd throttle.)
4. **Q ability radius was a square** — `_spawn_cannon_ring` drew a `ColorRect`. Now
   drawn as a **circle** in `Commander._draw` at `ATTACK_RANGE_PX` (= base sightline),
   faded over ~0.5s via `_cannon_ring_t`.

---

## Fix — Map framed clear of HUD bars — 2026-06-16 (compiles clean)

Playtest report: enemies entering from the NORTH spawn were hidden under the
full-width top header bar. Root cause — `CameraController._update_zoom_min` used
`maxf` (cover: the board fills the whole viewport, so its top row sits under the
66px header). Fix: the camera now **contains** the board within the band between
the top header (`HUD_TOP_INSET=72`) and the bottom HUD (`HUD_BOTTOM_INSET=120`),
centred in that band. The board is narrower than 16:9, so this leaves dark side
margins (~176px) — intentional framing, and free space for future SupCom-style
side panels. `_clamp_position` generalized to keep the playable band (not the full
viewport) within the map; horizontal clamp unchanged. No Camera2D.offset is used,
so screen↔world math (clicks, placement, zoom-to-cursor) is untouched. Zooming in
(up to 3×) + panning still work; the default view shows the whole board clear of UI.

---

## Phase 4 — "Detection Counterplay" — 2026-06-16 (backlog; compiles clean)

First backlog item after the scheduled Passes 0–3. Upgrades Pass 2 stealth from
"permanent-once-swept" to live transient detection. Verified via Godot MCP
(`Main.tscn`, zero new errors/warnings).

- **Detectors group.** The FOB, the Commander, and any tower with
  `TowerData.detector_radius > 0` join the `"detectors"` group and expose
  `get_detector_radius()` (px). FOB = full sensor sphere `(sight+FOB_SENSOR_EXTRA)*64`
  (grows with fortification); Commander = `VISION_RADIUS*64` (192, line-of-sight);
  towers = their `detector_radius`. `Tower._refresh_detector_group()` runs in
  `_ready` and on upgrade.
- **Live stealth.** `Unit` now recomputes detection on a 0.15s throttle
  (`_within_active_detector()` scans the detectors group). Stealth units are visible
  (`_update_fog_visibility`) and targetable (`is_detectable`) only while inside a
  detector's radius — replacing the Pass 2 `sensed`-bit read. Stealth units get a
  cloaked cyan-translucent tint when revealed. (The MapData `sensed` bit + the
  `region_sensed` event remain for objective telegraphy; the bit is now vestigial
  for stealth.)
- **Content.** Detector towers: `mesh_t2b` Relay Pylon (256px, on top of its aura),
  and the three T3 apexes (240px). So every faction has a buildable detector, plus
  baseline FOB/Commander coverage. InspectionPanel shows "◎ detects stealth".

Deferred: detector-radius ring visual; detector buildings; stealth that resists
specific detectors. Backlog now: rally points/RTS unit production, accessibility
pass (core/22 §10), balance retune (territory rate + sphere radii).

---

## Pass 3 — "Tower Mastery" — 2026-06-16  ·  Milestone M3 (compiles clean)

Branching upgrades, aura/support towers, territory empowerment, max-level
promotion per `planning/improvement-plan.md`. Verified via Godot MCP (ran
`Main.tscn`, zero new errors/warnings; the branch `.tres` load clean).

**Branching upgrades.** `TowerData.upgrade_to_b` (second branch). At T1 the player
picks T2-A (existing, balanced) or **T2-B** (new specialization); both reconverge
on the shared T3 apex (T2→T3 stays linear — one branch point). `EventBus`
`panel_upgrade_requested(branch:int)`; InspectionPanel shows up to two upgrade
buttons (name + cost, per-branch affordability) emitting branch 0/1; `Main._try_upgrade_tower(cell, branch)`
picks `upgrade_to` / `upgrade_to_b`. New resources: `architects_t2b` (Railgun Array
— long-range siege), `bloom_t2b` (Blight Mortar — heavy lobber), `mesh_t2b` (Relay
Pylon — **aura/support** tower). T1 `.tres` rewired with `upgrade_to_b`.

**Aura / support + promotion.** `TowerData.aura_radius` / `aura_damage_bonus`. A
tower provides an aura if its data sets one OR it hits max level (veteran promotion:
`VETERAN_AURA_RADIUS=160`, `VETERAN_AURA_BONUS=+10%`). Towers receive the best aura
in range. `Tower.get_aura_radius/get_aura_bonus/provides_aura`, recomputed on a 0.5s
cadence in `_recompute_buffs` (not per-frame).

**Territory empowerment.** A tower on a claimed cell deals +15% damage
(`TERRITORY_DAMAGE_BONUS`, `_on_claimed_ground` via MapGrid `is_claimed`). NOTE: this
replaces the plan's literal "regen" — towers have no HP/attacker yet, so a heal
would be invisible; empowerment is the meaningful territory payoff. Effective damage
= `data.damage × level_mult × aura_mult × territory_mult`. InspectionPanel shows the
active "+X% aura / +Y% territory / ◈ radiates aura" line.

Deferred: aura-ring visual (mechanics + panel text cover feedback); second branch
point at T2→T3; tower HP/repair (needs an attacker model first).

---

## Pass 2 — "Combat Identity" — 2026-06-16  ·  Milestone M2 (compiles clean)

Damage/armor type triangle + stealth detection per `planning/improvement-plan.md`.
Verified via Godot MCP (ran `Main.tscn` — full tree incl. preloaded Tower/Unit —
zero new errors; only the standing benign warnings).

**Damage triangle (`src/combat/Combat.gd`, new).** Static helpers + constants;
preloaded by consumers (`const Combat = preload(...)`) — not class_name (Godot 4.6
global-class flakiness). 3 damage × 3 armor, strong ×1.5 / neutral ×1.0 / weak ×0.66:
- Kinetic → strong vs Organic, weak vs Synthetic
- Energy → strong vs Plated, weak vs Organic
- Corrosive → strong vs Synthetic, weak vs Plated
Faction signatures: Architect = Kinetic/Plated, Bloom = Corrosive/Organic,
Mesh = Energy/Synthetic. The whole player kit deals its faction's damage type, so
each faction naturally counters one other (cross-faction RPS; Pass 3 branching
upgrades will let towers diversify type).

**Data.** `UnitData`: `armor_type` enum + `stealth` bool. `TowerData`: `damage_type`
enum (ordinals match `Combat`). `.tres` tagged: bloom units armor_type=1, mesh
units armor_type=2 (mesh_t1 "Shard" `stealth=true`), bloom towers damage_type=2,
mesh towers damage_type=1; Architect uses defaults (0 = Plated / Kinetic).

**Resolution.** `Unit.take_damage(amount, damage_type := -1)` applies
`Combat.multiplier(type, armor_type)` then flat armor (−1 = untyped contact damage,
×1.0). Every player damage source now passes its faction type: `Tower._try_attack`
(tower's own type), `Base`/`Commander`/`AbilityController` via
`Combat.faction_damage_type(active_faction)`. InspectionPanel shows the type.

**Stealth.** New persistent `sensed` meta bit (MapData bit 30). `MapGrid.sense_area`
now flags the full sensor disk as sensed (region_sensed event unchanged). Stealth
units render only where sensed (`Unit._update_fog_visibility`) and expose
`is_detectable()` — Tower/Base/Commander skip undetected stealth (AoE abilities
ignore it). Sensing is permanent-once-swept (transient-sensor counterplay is backlog).

---

## Review session — 2026-06-13 (full-project review + ship-readiness pass)

Ran a full code review across the autoloads, entities, waves, abilities, and
HUD. Project compiles and runs clean (no errors; remaining warnings are benign:
EventBus per-class "signal never used" false-positives, intended integer
divisions, and the `range` export name in TowerData). Changes made:

1. **BUG (high impact) — Architect ability kit was dead.** `AbilityController.gd`
   compared `FactionManager.active_faction == "architect"` (singular) in 6 places,
   but the faction id is `"architects"`. This silently disabled the Architect Lance
   stun, Overdrive compounding/duration, ultimate display-name/cooldown setup, AND
   made the Architect ultimate (Compile Cascade) never fire — the `match` fell
   through. Fixed all 6 to `"architects"`. Bloom/Mesh were already correct.
2. **Ship flag — `SaveManager.DEV_CLEAR_SAVE` flipped `true → false`.** It was
   wiping saves every launch, which disabled the entire (completed) save +
   offline-catch-up system in real play. The code comment already said to flip it
   before shipping. Persistence + offline income now work across launches.
3. **Gap — faction Ultimate (slot R) was unreachable.** It unlocks on
   `milestone_reached(faction, 1)`, but nothing emitted index 1. Added a minimal
   Second-Milestone trigger in `MilestoneManager` (`_on_wave_started`): once the
   first milestone has fired, reaching wave `SECOND_MILESTONE_WAVE` (=20) emits
   index 1 and unlocks the Ultimate. **v1 proxy** — replace with the core/21
   faction-specific conditions (Singularity II / Biosphere II / Mesh Control II)
   when that system is built.
4. Lint hygiene: removed unused `EconomyManager._last_save_timestamp`; renamed
   unused `FactionManager.get_production_rates(sub_path)` param to `_sub_path`.

Note: `F1` Academy-skip dev bypass in `Main.gd` is gated on `OS.is_debug_build()`
so it compiles out of release exports — left in place intentionally.

Still genuinely unbuilt (acknowledged, not bugs): galaxy/treaty meta-layer,
Ancient pacification economy, prestige/Memory-Tier loop, convoy cargo → economy
hookup. These are large design-driven systems and were out of scope for a
review/bugfix pass.

---

## Production session — 2026-06-13 (title screen + full playtest)

Added a production entry flow and play-tested the game end-to-end via computer-use
(driving the real window) cross-checked against the Godot MCP. All verified working.

**New: Title screen** (`scenes/ui/TitleScreen.tscn` + `src/ui/TitleScreen.gd`, now the
`run/main_scene`). New Game / Continue / Options / Quit, built programmatically.
- New Game → `GameState.reset_for_new_game()` → Main (Academy plays fresh).
- Continue → `SaveManager.load_game()` → Main (restores world). Disabled when no save.
- Options → master volume + fullscreen, persisted to `user://settings.cfg`.
- `SaveManager` no longer auto-loads on startup; the title screen owns the load decision.
  Added `SaveManager.has_save()` / `clear_save()`.

**Bugs found & fixed during the playtest:**
1. **Academy ran in the background on every Main load** (incl. Continue) — `Academy._ready`
   unconditionally started the sequence, spawning scenario enemies that breached the FOB
   and leaving the cadet competing for input. Guarded `Academy._ready` on
   `GameState.academy_completed` (hide + `PROCESS_MODE_DISABLED` + hide its CanvasLayers);
   `Main._start_game_world` now also disables the Academy and emits `academy_clear_units`.
2. **Tower placement / inspection clicks were stolen by the Commander.** Track G moved
   `Main` to `_unhandled_input`; as the root it runs LAST, so the Commander (deeper) consumed
   world clicks first. Added `GameState.placement_active` (Commander yields during
   placement) and `Main.structure_at_screen()` via the `main_controller` group (Commander
   yields clicks that land on a tower/building → Main opens inspection). Place → inspect →
   upgrade now all work.
3. **`SaveManager._on_dirty_event()` crashed on `tower_placed`** — it was a 0-arg method
   connected to 2-arg signals (Godot 4 errors, doesn't drop args). Latent until placement
   worked; gave it two optional ignored params.
4. **F1 debug-skip left "Begin Waves" hidden** — Academy emits `academy_phase_started`
   (hides the button); F1 bypassed `academy_phase_ended`. F1 now emits it.

**Verified in-game (Architects):** title→options→new game→academy→continue (with offline
catch-up), save persistence, waves + axis diagram, FOB/Commander auto-fire, Lance (Q) charge
+ cast, economy, tower placement, tower inspection panel + upgrade button, Commander movement.

---

## Veterancy sight/sensor growth + level caps — 2026-06-13

Every player unit now grows its sight (and sensor) sphere with experience, all capped.

- **Commander** (rank from territory, cap `RANK_CAP=15`): LoS `_los_radius()` 3→6 (+1/5
  ranks), sensor `_sensor_radius()` 9→14 (+1/3 ranks). Because the Commander claims its
  LoS, leveling also widens the territory swath. Speed/damage rank bonuses now capped too.
- **Tower** (level from kills, cap `TOWER_MAX_LEVEL=10`): sight 3→6 (+1/3 levels),
  re-revealed on each level-up via `_apply_sight()`.
- **FOB** (rank from cargo, cap `FOB_MAX_RANK=10`): existing sphere now bounded.
- **Convoy** (rank from deliveries, cap `CONVOY_MAX_RANK=6`): reveals a small scout sphere
  2→5 as it travels (set `CONVOY_SIGHT_BASE=0` to restore hidden-in-fog logistics).

All radii/caps are named constants per entity — easy to retune. Verified: compiles + runs
clean (no errors), rings draw via the dynamic-radius functions every frame.

---

## Territory & sphere-of-influence rework — 2026-06-13

Territory no longer claims one tile at a time. It now flows from sight and buildings.

- **MapGrid** gained area ops: `claim_area(center, radius)` (returns newly-claimed
  GROUND cells), `reveal_area(center, radius)` (fog reveal + emits `region_revealed`),
  `sense_area(center, inner, outer)` (sensor ring + emits `region_sensed`). MapGrid now
  joins the `map_grid` group so entities resolve it without a relative path.
- **EconomyManager** owns the per-cell income: `const TERRITORY_RATE_PER_CELL = 0.05`
  + `register_claimed_cell()`. Single tuning knob for all territory income.
- **Commander** claims its whole line-of-sight ring (`VISION_RADIUS`) as it moves —
  `_claim_around()` replaces the old single-cell `_try_claim_cell()`.
- **FOB (`Base.gd`)** projects a sphere of influence that grows with fortification rank:
  reveals sight (`FOB_SIGHT_RADIUS_BASE=5 + rank`), senses beyond it, and **claims a
  territory sphere** (`FOB_CLAIM_RADIUS_BASE=2 + rank`). Applied at start (deferred) and
  on every rank-up.
- **Towers & buildings** project a sight+sensor sphere on placement (vision only, no
  claim): `Main._apply_structure_influence()` (`STRUCTURE_SIGHT_RADIUS=3`).

Verified in-game: FOB starts inside a claimed sphere; the Commander paints a sight-width
swath of territory as it moves; fog reveal expands with it. No runtime errors.

**Balance note:** area-claim grows territory income and map coverage much faster than
before — retune `EconomyManager.TERRITORY_RATE_PER_CELL` and the radii if the economy /
Bloom-coverage milestone races. Also note `territory_rates` persists in the save while the
map regenerates each run, so a loaded rate can look high relative to the fresh map.

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
**Status: COMPLETE + verified (2026-06-03)**

Files: `src/core/waves/WaveSpawner.gd` (scripted_overrides + `_apply_scripted_override`),
`src/core/FactionDialogue.gd`, `src/ui/FactionDialogueHUD.gd`,
`src/entities/AncientWatcher.gd`, `scenes/main/AncientWatcher.tscn`,
`scenes/main/Main.tscn` (WashLayer/MilestoneWash + FactionDialogueHUD nodes),
`scenes/main/Main.gd` (_on_milestone_reached, _play_milestone_wash, _spawn_ancient_watcher).
`EventBus.wave_flank_triggered(wave_number)` added.

Key lesson: `class_name RefCounted` scripts must be `preload()`-ed by callers — global
class registration is unreliable at parse time in Godot 4.6.

---

### TRACK E — Economy & Idle Loop
**Recommended model: Sonnet**
**Status: COMPLETE + verified (2026-06-03)**

Idle tick, production rates, territory rates, building income, caps, and offline
catch-up math were already wired from earlier tracks. Three gaps fixed:
1. `territory_rates` now persisted in `SaveManager._collect_all_state()` / `_apply_all_state()` — building income and Commander territory bonuses survive reload.
2. Offline catch-up toast in `HUD._on_offline_catch_up()` — "Welcome back! Xh Ym of idle income collected."
3. `SaveManager.mark_dirty()` now wired to `faction_selected`, `building_placed`, `tower_placed` so the 60-second auto-save actually triggers.

---

### TRACK F — Wave Content
**Recommended model: Sonnet**
**Status: COMPLETE + verified (2026-06-03)**

6 new unit resources (T2 + T3 per faction):
- `resources/units/architect_t2.tres` (Auger-Walker: 200 HP, 55 spd, 5 armor)
- `resources/units/architect_t3.tres` (Compiler: 420 HP, 35 spd, 12 armor)
- `resources/units/bloom_t2.tres` (Bramble-Walker: 320 HP, 45 spd, evolves at 30% HP)
- `resources/units/bloom_t3.tres` (Mire-Beast: 700 HP, 28 spd, 15 armor, `status_immune`)
- `resources/units/mesh_t2.tres` (Spike: 155 HP, 72 spd, hacks on death)
- `resources/units/mesh_t3.tres` (Carver: 300 HP, 62 spd, wider hack radius)

`src/core/waves/WaveTableBuilder.gd` — builds 30-wave curves in code. T1 waves 1–12
(count 6→24, interval 1.6→0.9s), T2 waves 13–19 (5→12, 1.6→1.1s), T3 waves 20–25+
(3→10, 2.0→1.4s). Commander names at waves 11/13/15/18/20/23/25 per faction.
WaveSpawner falls back to `WaveTableBuilder.build(faction_id)` when no .tres exists.
HUD shows purple toast "Wave N — Commander Name" at wave 11+.

---

### TRACK G — Rapid-Click Hang (Bug)
**Recommended model: Sonnet — anytime, independent**
**Status: COMPLETE + verified (2026-06-03)**

Root cause: `Main` used `_input()`, which fires BEFORE Godot's GUI system processes
events. Every click on the InspectionPanel Upgrade button was intercepted by
`Main._input()` first — it mapped the button's screen position to a tower cell,
opened inspection, and marked the event handled. The Upgrade button never saw the click.

Fix: one line — `func _input` → `func _unhandled_input` in `scenes/main/Main.gd`.
GUI controls (buttons) now consume their clicks first; map clicks (no GUI consumed)
still reach Main. Commander already used `_unhandled_input` for the same reason.

---

### TRACK H — Map Scale-Up to 60×34
**Recommended model: Sonnet — anytime, independent**
**Status: COMPLETE + verified (2026-06-03)**

5 files changed. Map is now 3840×2176 px (60×34 cells at 64 px/cell).
- `MapData.gd`: DEFAULT_COLS/ROWS 30/17 → 60/34
- `MapGrid.gd`: COLS/ROWS, BASE_POS (30,17), all 4 spawn positions updated; doc comment
- `MapGenerator.gd`: _COLS/_ROWS, _BASE_POS, _CARDINAL_SPAWNS, waypoint offsets ×2
- `DefaultMapBuilder.gd`: constants + simplified 4 straight L-paths replacing old hand-authored 30×17 layout
- `WorldMap.tscn`: Background 1920×1080→3840×2176; Base+Commander position (992,544)→(1952,1120)

Camera self-adjusted — min_zoom formula was already self-adjusting for any map size.
