# Cycle Four — Backlog

> This file is READ-ONLY for Claude Code during implementation sessions.
> It is WRITE-ONLY during planning/review sessions.
>
> HOW TO ADD: tag with [PLAYTEST] [BUG] [ENHANCEMENT] [DEFERRED] [REGRESSION-RISK]
> Include: what you observed, when, rough priority (P1=blocks fun / P2=hurts feel / P3=polish).
> Do NOT schedule here — pull into improvement-plan.md when a session is planned.

---

## Bugs (defects — something broken)

- [BUG][P1][FIX — runtime-pending] Towers placed next to a spawn instakill enemies at the
  spawn point — enemies never reach the field; garrisons get no XP. FIXED 2026-06-22 via a
  no-fire DMZ: `MapGrid.is_in_spawn_dmz(world_pos)` returns true within `SPAWN_DMZ_CELLS`
  (=4, Chebyshev) of any ACTIVE spawn; `Tower._select_target` skips DMZ targets. Unit-position
  based, so it holds regardless of tower placement or range. Compile-verified; needs a playtest
  to confirm enemies clear the mouth and DMZ size feels right (tune SPAWN_DMZ_CELLS).
  (Found: playtest 2026-06-20 | fixed: 2026-06-22)

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
