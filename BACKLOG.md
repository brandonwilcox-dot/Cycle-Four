# Cycle Four — Backlog

> This file is READ-ONLY for Claude Code during implementation sessions.
> It is WRITE-ONLY during planning/review sessions.
>
> HOW TO ADD: tag with [PLAYTEST] [BUG] [ENHANCEMENT] [DEFERRED] [REGRESSION-RISK]
> Include: what you observed, when, rough priority (P1=blocks fun / P2=hurts feel / P3=polish).
> Do NOT schedule here — pull into improvement-plan.md when a session is planned.

---

## Bugs (defects — something broken)

- [DONE — playtest-verified 2026-06-24] Towers placed next to a spawn instakill enemies at the
  spawn point — enemies never reach the field; garrisons get no XP. FIXED 2026-06-22 with a
  spawn DMZ (`SPAWN_DMZ_CELLS` = 4, Chebyshev, around each ACTIVE spawn), two layers:
  (1) NO-FIRE — `Tower._select_target` skips targets in `MapGrid.is_in_spawn_dmz` (unit-position
  based, holds regardless of tower placement/range; always on so enemies always clear the mouth).
  (2) EXCLUSION (no-build) — `MapGrid.is_build_excluded` blocks tower + building placement (and
  greys the placement preview) inside the buffer. As of 2026-06-23 the lift is per-spawn and tied
  to conquest: each spawn projects its buffer only while its enemy base stands; destroying the base
  permaseals the spawn → it drops from the active set → its buffer lifts. (`_battle_won` removed.)
  See the conquest entry below. PLAYTEST-VERIFIED 2026-06-24: towers can't be built next to a live
  enemy base. Tune SPAWN_DMZ_CELLS later. (Found: 2026-06-20 | DMZ 2026-06-22 | verified 2026-06-24)

- [FEATURE][P1 — runtime-pending] Conquest: enemy bases anchor spawns (Phase 1, 2026-06-23).
  Fixes the auto-completing CLAIM_TERRITORY default win condition (FOB starts ~1705 cells claimed
  vs a 200 target, so every territory was "conquered" on arrival → exclusion zone lifted on frame 1).
  Now each active spawn has a destructible `EnemyBase` (500 HP, group `enemy_bases`). Army assault:
  Commander + garrison `FriendlyUnit`s damage bases via take_damage (towers can't — no-fire DMZ).
  Destroying a base permaseals its spawn (stops emitting + lifts its DMZ) and ticks the new
  `DESTROY_BASES` objective; last base → map_completed → capture. Compile-verified; NEEDS PLAYTEST
  (drive Commander to a base, grind it, confirm seal+DMZ-open+objective tick; clear all → captured).
  Tune `EnemyBase.MAX_HEALTH`. Plan: planning/territory-conquest-plan.md.
  Deferred follow-ups: [Phase 2] intermediate encampments that spawn enemies + gate exploration
  (currently ~90s to skirt the perimeter); [Phase 3] build limits (can't carpet towers); base
  destroyed-state persistence (Continue/return currently respawns bases — same class as the
  [BUG][P2] ObjectiveManager-completion-not-persisted gap).

- [DONE — playtest-verified 2026-06-24] Commander as engineer — build + repair (Phase 2B, 2026-06-23).
  First slice of "make the Commander a mortal, overworked engineer-leader" so building isn't pointless
  (Phase-1 playtest: Commander solos everything). Towers + garrisons spawn INERT at 10 HP (tower won't
  shoot; garrison earns no income / no production) and ghosted; the Commander must park at them and
  channel its weapon-as-tool (`receive_engineering`, green beam, BUILD_RATE 50 HP/s, range 110px) to
  bring them online; same tool repairs damage. Restored structures load built. PLAYTEST-VERIFIED
  2026-06-24 (Commander must complete tower + garrison construction). Tune BUILD_RATE /
  MAX_HEALTH (T100/G120) / ENGINEER_RANGE_PX. Plan: planning/commander-and-faction-systems.md.
  Follow-ups: building still lacks urgency until PRESSURE lands (Commander mortality + enemy-base
  response, next slices); verify the Academy path (may place/expect instant-working towers); incomplete
  builds aren't persisted distinctly (a saved-then-restored half-built structure loads as built).

- [DONE — playtest-verified 2026-06-24] Commander mortality (Phase 2A, 2026-06-24). The Commander has HP
  (300, ~FOB-durable, tunable) + a health bar; enemies grind it in melee (`Unit._engaged_friendly` now
  includes the "commander" group, 8 dmg/interval each). At 0 HP → `commander_destroyed` → forced retreat
  (`Battle._on_commander_destroyed`: stop waves, clear enemies, abandon invasion, revive at board centre,
  zoom to galaxy; in-battle progress lost). Academy-guarded (revives in place during scenarios).
  PLAYTEST-VERIFIED 2026-06-24 (Commander destroyed by enemy units → forced retreat). Tune
  `Commander.MAX_HEALTH`. Plan: planning/commander-and-faction-systems.md.

- [DONE — playtest-verified 2026-06-24] Enemy bases fight back (Phase 3, 2026-06-24). Bases field a standing
  guard of their faction's units (`Unit` defender mode: guards the base, chases player targets within
  220px, leashed 240px, melee via `_engaged_friendly`; death doesn't count vs a wave). `EnemyBase`
  produces them — cap 3 idle / 5 threatened, 5s / 2s interval (responds to an assault) — in the
  EnemyBaseLayer (survives wave clears), freed on base death; `Battle` passes the enemy faction.
  Closes the standby gap (assaulting is dangerous pre-wave) and completes "justify building" (a lone
  Commander can't crack a defended base → need a garrison army + towers). PLAYTEST-VERIFIED 2026-06-24
  (defenders keep a lone Commander off the base; with support you can crack it). Tune `EnemyBase.DEFENDER_*`
  / `Unit.DEFENDER_AGGRO`/`DEFENDER_LEASH` to fine-tune the response later.
  The Commander-bottleneck arc (Phases 2A/2B/3) is PLAYTEST-VERIFIED — the "justify building" loop holds:
  Commander can't solo the map. Plan: planning/commander-and-faction-systems.md.

- [BUG][P1][LIKELY-FIXED — confirm in play] Enemies only entered from ONE spawn in wave play.
  Code re-verify 2026-06-22: every procgen spawn now defaults to ACTIVE (MapGenerator._build_spawn_points),
  `_activate_all_spawns()` runs post-Academy as a backstop, and `_build_spawn_queue` splits units
  across ALL active spawns — so the path is correct. The 2026-06-21 detection rework also fixed the
  "instant-seal" root cause. Added a debug-gated log at each wave start (`[WaveSpawner] wave
  distribution — active spawns=N: …`) so the next playtest confirms multi-direction emission.
  Close this once a playtest shows active spawns ≥ 2. (Found: 2026-06-20 | code-verified: 2026-06-22)

- [BUG][P1][MONITOR] SYSTEM HANG — entire OS became unresponsive; Godot process wouldn't close.
  Scenario: garrisons near spawn points claiming territory + new wave of Mesh units
  (orange) un-claiming territory. Collision/race on same cells. Theory: rapid
  claim/unclaim event ping-pong, rendering bottleneck, or pathfinding deadlock.
  Repro strategy: (1) place garrisons in a 3×3 cluster near a spawn; (2) watch them
  claim outward; (3) call a new wave; (4) monitor frame rate—if <1fps and process
  won't exit, log the frame count at hang. No crash dump found; logs show clean exit.
  Fix direction: instrument claim_area/unclaim_cell with frame counts; add render
  coalescing; check for mutual waiting in FriendlyUnit pathfinding vs MapGrid updates.
  STATUS: hardened the hot path (MapGrid.claim_area single-redraw batching documented;
  Building._complete_raid event loop split) but found no definitive root cause — a whole-OS
  freeze points more at GPU/driver/memory than a GDScript infinite-loop. DID NOT RECUR in the
  2026-06-22 playtest. Left open as MONITOR: if it returns, capture frame count at hang.
  (Found: playtest 2026-06-21 | not reproduced: 2026-06-22)

- [BUG][P2] Garrison leveling has no felt effect. Design says levels raise squad cap +
  production speed, but no difference perceived in playtest. Verify level-up effects apply;
  surface garrison level + current effect in InspectionPanel. (Found: playtest 2026-06-20)

- [BUG][P2] Convoy not operational — depot↔FOB ferry never ran during playtest. Investigate
  ConvoyManager spawn conditions (connectivity BFS on `path_discovered`, depot detection).
  Likely no depot/path discovered on played map, or convoy never spawned. (Found: playtest 2026-06-20)

- [DONE — 2026-06-22] Per-territory persistence — Continue restore VERIFIED 2026-06-21
  (garrison, tower, FOB HP, energy rate, map seed, offline catch-up all restored). Deploy
  A→B capture verified. The remaining gap (no UI to deploy back to a held territory) was
  closed by the galaxy return-nav work; restore-on-return is now reachable and playtested
  2026-06-22. Residual: objective completion not persisted on Continue — tracked separately
  as the [BUG][P2] ObjectiveManager entry below.

- [BUG][P3] Academy scenarios (75/90/90s phases) had no player control pre-fix. Partially
  addressed 2026-06-21: Battle now accepts world input during scenario phase. Tower placement
  during scenarios still needs HUD shown — smaller follow-up. (Flagged: 2026-06-21)

- [BUG][P2] ObjectiveManager completion state not persisted on Continue. On restore,
  objectives reset to 0/N even if they were completed before quit. An active garrison
  re-triggering territory_claimed immediately masks this, but objectives that require
  a one-time-only event (path_discovered, convoy_spawned) will stay stuck at 0 until
  that event fires again. Fix direction: persist completed-objective IDs in save and
  replay them into ObjectiveManager on restore. (Found: playtest 2026-06-21)

---

## Enhancements (new design — not currently built)

- [FEATURE][P2 — runtime-pending] Phase 4A faction build preferences (2026-06-24). `FactionPerks.gd`
  centralizes faction build tuning. **Architects** build faster (×1.6 rate) + sturdier (×1.4 structure
  HP); **Bloom** towers grow over time (+8% HP / +6% dmg per 5s tick, cap 6, subtle scale-up); **Mesh**
  connected-tower chains buff endpoints (+12% dmg per linked tower, `_compute_chain_mult`). Tower damage
  factors `_growth_mult * _chain_mult`. Compile-verified; NEEDS PLAYTEST per faction (F1 architects /
  F2 mesh / F3 bloom). Tune in `FactionPerks`. Next: Phase 4B passives (walls / pollen / hijack), then
  Phase 5 build limits. Plan: planning/commander-and-faction-systems.md.

- [DONE — playtest-verified 2026-06-24] Phase 4B Architect walls (2026-06-24). `Wall.gd` — a destructible,
  Commander-built barrier NOT in the enemy AStar; enemies path into a built wall and must destroy it to
  pass (`Unit._engaged_friendly` includes built walls as blockers). Architect-only "Build Wall" HUD button
  (programmatic, ActionBar HBox) → `wall_placement_requested` → Battle wall-placement mode (cost 15;
  density cap `WALL_MIN_SPACING` 2; no connectivity test). Walls in tower_layer (cleared on deploy);
  `_wall_cells` pruned of destroyed walls. PLAYTEST-VERIFIED 2026-06-24: walls build, take damage,
  Commander repairs after construction, spacing good, towers farm stalled enemies. Tune `Wall.MAX_HEALTH`
  / `WALL_COST` / `WALL_MIN_SPACING` later if needed. Remaining 4B: Bloom pollen (AoE slow+blind), Mesh
  hijack (convert an enemy). Then Phase 5 build limits. Plan: planning/commander-and-faction-systems.md.

- [FEATURE][P2 — runtime-pending] Phase 4B Bloom pollen + Mesh hijack (2026-06-24). **Bloom:** built
  towers emit a slow(×0.45)+blind cloud (radius 130, refresh 0.5s, lingers 1.1s); `Unit.apply_pollen`
  slows movement + suppresses melee; `Tower._emit_pollen` + aura `_draw`. **Mesh:** built towers hijack
  the nearest enemy (radius 180, cd 8s, dur 6s); `Unit.apply_hijack` swaps units→friendly_units (cyan),
  chases + melees enemies, reverts on expiry (`_end_hijack`); `Tower._try_hijack`. Compile-verified;
  NEEDS PLAYTEST (F3 bloom / F2 mesh). Tune `FactionPerks.BLOOM_POLLEN_*` / `MESH_HIJACK_*`. With this,
  Phase 4B is feature-complete (walls already playtest-verified). Next: Phase 5 build limits — the last
  faction-arc piece. Plan: planning/commander-and-faction-systems.md.

- [ENHANCEMENT][P1] Garrison unit-type selection and composition. Player chooses which unit
  types to spawn; XP improves those types; higher levels unlock mixed-squad combinations.
  Needs: garrison loadout UI, per-type XP, multi-type squad logic. (Found: playtest 2026-06-20)

- [DONE — 2026-06-21] Galaxy nav only supports outward deploys. Fixed: `_handle_galaxy_click`
  now allows clicking any owned non-active node; `_deploy_to_node` sets `invading_node = ""`
  for returns so `map_completed` doesn't re-capture an already-owned territory.

- [DONE — 2026-06-21] Per-territory win conditions. `ObjectiveManager` now generates a
  default `CLAIM_TERRITORY` objective (200 cells, faction-voiced) when the resolved list is
  empty. 200 claimed → `map_completed` → `capture_system` → frontier opens. HUD repopulates
  on deploy via `HUD.refresh_objectives()`. Compile-verified; runtime needs hand-playtest.

- [ENHANCEMENT][P2] HUD shown during Academy scenario phase. Tower placement during
  scenarios is currently unavailable (HUD hidden). Show a reduced HUD during scenarios
  so the player can experiment with placement while the behavior tracker watches.
  (Flagged: 2026-06-21)

- [ENHANCEMENT][P2] Standing-order toggle UI for garrisons. Currently implicit
  (expand when safe, defend when threatened). Explicit toggle lets player lock a garrison
  into defense-only mode. (Flagged: C3, 2026-06-17)

- [ENHANCEMENT][P3] Galaxy view HUD labels. Node names, owner faction colors, distance-to-core
  indicators. (Flagged: D1 follow-up, 2026-06-17)

- [ENHANCEMENT][P3] Diplomacy layer — treaty/alliance stubs in GalaxyManager already exist.
  Needs design pass from core/11 + core/20. (Flagged: D design, deferred)

- [ENHANCEMENT][P3] Resource gauge bars in HUD top strip. Resources are uncapped so fill
  needs a meaningful reference — deferred until soft-cap/storage model chosen.
  (Flagged: UI session 2026-06-16)

- [ENHANCEMENT][P3] Detector-radius ring visual. Mechanics work; ring is invisible.
  (Flagged: Phase 4 detection rework, 2026-06-16)

- [ENHANCEMENT][P3] Aura-ring visual for support towers. Mechanics work; ring is invisible.
  (Flagged: Pass 3, 2026-06-16)

---

## Deferred systems (large — needs design pass before implementation)

- [DEFERRED] Cross-territory income model. `territory_rates` is a single global accumulator
  that leaks across deploys. Belongs with the galaxy-campaign economy model. (Flagged: Step 5, 2026-06-20)

- [DEFERRED] Ancient pacification economy. Sacrifice faction-specific things at Ruins.
  Custodian unit (unkillable, non-attacking). Dominance Meter. (Core/ancients system — not designed)

- [DEFERRED] Prestige / Memory-Tier loop (cross-run progression). Core/21 option B system,
  0–11 tiers, 7 Fragments gate progression. Large design-driven system.

- [DEFERRED] Convoy cargo → economy hookup. Cargo aggregator wired but economy hookup
  not complete. (Flagged: review session 2026-06-13)

- [DEFERRED] Galaxy/treaty meta-layer beyond adjacency + ownership. Diplomacy actions,
  faction cascade, alliance formation. (Core/11 + core/20)

- [DEFERRED] Accessibility pass — colorblind-safe territory/fog, motion reduction options.
  (Core/22 §10)

- [DEFERRED] Balance retune — `EconomyManager.TERRITORY_RATE_PER_CELL` + FOB/Commander
  sphere radii. Area-claim economy grows fast; retune after persistence and garrison fixes
  land. (Flagged: territory rework 2026-06-13)

- [DEFERRED] Rally points / RTS unit-production polish. Garrison select → set rally point
  → squad deploys to rally. Needs garrison loadout UI first.

- [DEFERRED] Rapid-click hang investigation. Reproducible UI race when clicking rapidly
  during/near tower upgrade. Pre-existing issue; not blocking core loop.

---

## Regression risks (guard these — past injuries)

- [REGRESSION-RISK] `CadetAvatar._unhandled_input` — removing it breaks Academy player control.
  It is intentional, not a bug. See NORTHSTAR.md and NEVER_TOUCH.md.

- [REGRESSION-RISK] `Main._unhandled_input` vs `_input` — must stay `_unhandled_input` or GUI
  buttons stop receiving clicks (Track G fix, 2026-06-03).

- [REGRESSION-RISK] `_build_visual` Control children must stay `MOUSE_FILTER_IGNORE` — any
  new world-space visual using Control nodes must set this or clicks break.

---

## Playtest notes (raw observations — not yet triaged)

_(Add new observations here with date. Format: "DATE — observation. Repro: steps.")_

---

## How to pull from this backlog

When scheduling work in a Code session:
1. Copy the item to `planning/improvement-plan.md` under a new Pass
2. Change its tag here to [SCHEDULED — PassN] so it doesn't get picked twice
3. After shipping: change to [DONE — date]
