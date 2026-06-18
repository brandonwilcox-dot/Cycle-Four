# Cycle Four — Improvement Implementation Plan

Status: DRAFT (2026-06-13). Source: TD/RTS feature recommendations + the veterancy
sight/sensor work already landed. Goal: ship the agreed systems in **as few passes as
possible**, grouping changes by the files/systems they touch so we don't re-open the same
code twice. Every pass ends with a **test phase** and a **git push milestone**.

Engine: Godot 4.6.1 · Repo: `D:\AI\Cycle Four` · Branch: `main` · Remote: `origin`
Verification tool: Godot MCP (`run_project` → `get_debug_output` → `stop_project`) +
computer-use playtest. Bar: **zero new errors**; benign EventBus/integer-division
warnings are accepted.

---

## Design principles for grouping

1. **Group by file cluster, not by feature theme.** Features that edit the same scripts
   ship together so each file is opened once per pass (Tower depth all lands together,
   combat-resolution all lands together, UI/readability all lands together).
2. **Order by dependency + risk.** Readability/control first (low risk, makes everything
   legible), then the combat-data core, then the deep tower features that build on both.
3. **Each pass is independently shippable and testable** — the game is playable and
   pushable at every milestone.

---

## Pass 0 — Land pending work (baseline)  ·  Milestone **M0**

The veterancy sight/sensor growth + level caps (Commander, Tower, FOB, Convoy) are done
but uncommitted. Lock them in as the baseline before new work.

- **Scope:** commit current working tree (`CLAUDE.md`, `Commander.gd`, `Convoy.gd`,
  `Tower.gd`). Also pushes the already-committed but unpushed "Major bug fix pass".
- **Test phase T0:** MCP run → clean compile (no errors); Continue into a game, move the
  Commander, confirm rings/territory render. (Already verified this session.)
- **Git M0:** commit `feat: veterancy sight/sensor growth + level caps` → `git push origin main`.

---

## Pass 1 — "See It & Control It"  ·  Readability & Control  ·  Milestone **M1**

Make the progression the player already has *visible and controllable*. Highest felt value
per unit of work; almost entirely additive, low regression risk.

| System | Touches |
|---|---|
| Veterancy chevrons / rank pips on all units | `Commander.gd`, `Tower.gd`, `Base.gd`, `Convoy.gd` (`_draw`/visual) |
| Tactical minimap (fog, territory, FOB, Commander, enemy blips) | new `src/ui/Minimap.gd` + node in `scenes/ui/HUD.tscn`; reads `MapGrid` |
| Tower targeting priority (First/Last/Strongest/Closest) | `Tower.gd` (target select), `src/ui/InspectionPanel.gd` (toggle) |
| Sell / refund towers & buildings | `scenes/main/Main.gd` (remove + refund %), `InspectionPanel.gd` (Sell btn), `EventBus` (`building_sold` exists) |
| Next-wave preview + "call early" bonus | `src/ui/WavePanel.gd`, `src/autoloads/WaveManager.gd` |

**Why grouped:** all live in the HUD / InspectionPanel / entity-`_draw` layer plus small
logic hooks. InspectionPanel is opened once for both targeting + sell; HUD once for minimap
+ wave preview.

**Test phase T1**
- MCP: compile + run clean (zero errors).
- Playtest (computer-use): chevrons appear and update on level-up; minimap reflects fog +
  territory + Commander position; targeting toggle changes which enemy a tower shoots;
  sell removes a tower and refunds; "call early" starts the next wave + grants the bonus.
- Regression: core loop (place → wave → combat) still works.

**Git M1:** `feat: minimap, veterancy chevrons, tower targeting, sell, wave preview` → push.

---

## Pass 2 — "Combat Identity"  ·  Data + resolution core  ·  Milestone **M2**  ·  ✅ IMPLEMENTED 2026-06-16 (compiles clean; awaiting playtest + push)

Give factions/units mechanical identity. This is the one pass that rewrites combat
resolution + the unit/tower data resources, so both data features land together.

| System | Touches |
|---|---|
| Damage & armor types (small rock-paper-scissors triangle) | `UnitData.gd`, `TowerData.gd`, `Unit.take_damage`, `Tower`/`Base`/`Commander` attack, `AbilityController` damage, `resources/units/*.tres`, `resources/towers/*.tres` |
| Detection vs stealth (some enemies only visible inside a **sensor** sphere) | `UnitData.gd` (stealth flag), `Unit.gd` (visibility ties to sensor not just LoS), `Tower`/`Commander` targeting (can't hit undetected) |

**Why grouped:** both edit `take_damage` / targeting / the `*Data` resources. Doing them
together means the combat-resolution path is rewritten once. Depends on nothing from Pass 1
but benefits from the targeting UI shipped there.

**Test phase T2**
- MCP: compile + run clean.
- Playtest: verify a tower strong-vs-type kills faster than weak-vs-type; armor reduces
  damage as expected; a stealth enemy is invisible/untargetable until it enters a sensor
  ring, then becomes attackable.
- Regression: existing waves still resolve; ability damage still applies.

**Git M2:** `feat: damage/armor types + stealth detection` → push.

---

## Pass 3 — "Tower Mastery"  ·  Tower-system depth  ·  Milestone **M3**  ·  ✅ IMPLEMENTED 2026-06-16 (compiles clean; awaiting playtest + push). Deviations: "repair/heal from territory" shipped as a +15% damage empowerment (towers have no HP/attacker yet); branching is one point at T1→T2 (T2→T3 linear); aura-ring visual deferred.

The deep tower features. All live in `Tower.gd` + `TowerData.gd` + `InspectionPanel.gd`,
so one focused pass over the tower system. Builds on Pass 1 (inspection UI) and Pass 2
(damage types feed branch choices).

| System | Touches |
|---|---|
| Branching upgrade paths (pick 1 of 2 specializations per tier) | `TowerData.gd` (two `upgrade_to` branches), `InspectionPanel.gd` (choice UI), `resources/towers/*.tres` |
| Support / aura towers (buff nearby towers via sphere-of-influence) | `Tower.gd` (aura emit/consume), reuses `MapGrid` radius helpers |
| Repair / heal from claimed territory | `Tower.gd` (regen when on/near CLAIMED), `MapGrid` query |
| Max-level promotion effect (rank-10 tower gains an aura/ability) | `Tower.gd` (`_level_up` at cap) |

**Why grouped:** every item edits the tower scripts + tower resources + the inspection
panel. Shipping them together avoids three separate reopenings of `Tower.gd`.

**Test phase T3**
- MCP: compile + run clean.
- Playtest: upgrade a tower down each branch and confirm distinct stats; a support tower
  visibly buffs neighbors; a tower on claimed ground regenerates; a maxed tower gains its
  promotion effect.
- Regression: placement, targeting (Pass 1), damage types (Pass 2) all intact.

**Git M3:** `feat: branching upgrades, aura/support towers, territory repair, promotion` → push.

---

## Shared test strategy (every pass)

1. **Compile/run gate:** Godot MCP `run_project` + `get_debug_output` — zero errors.
2. **Feature checks:** computer-use playtest of the pass's new behaviors (see each T#).
3. **Regression smoke:** Title → New Game/Continue → place tower → Begin Waves → cast Lance
   → confirm no crash and core loop intact.
4. **Only commit/push once 1–3 pass.**

## Git workflow per milestone

```
# after a pass's tests pass:
git add -A
git commit -m "<milestone message>
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin main
```
Branch `main`. (Optionally branch per pass and PR — current flow commits to `main`.)

## Sequencing summary

| Pass | Theme | Risk | Depends on | Milestone |
|---|---|---|---|---|
| 0 | Land veterancy/sight | none | — | M0 (push) |
| 1 | Readability & control | low | M0 | M1 (push) |
| 2 | Combat identity | medium | M0 | M2 (push) |
| 3 | Tower mastery | medium | M1, M2 | M3 (push) |

## Vision phases (scheduled — full detail in `vision-roadmap.md`)

The post-MVP direction. Dependency-ordered A→D.

| Phase | Theme | Status |
|---|---|---|
| **A** | **Enemy factions in waves** — waves spawn the enemy faction the player is weak against (single enemy per map; engages the combat triangle / FOB doctrine / tower branches). | DONE 2026-06-16 |
| **B** | **Faction-flavored enemy pathing** — Architect direct routes / Bloom sprawl-and-block / Mesh directional-spread. Bias AStar weights per faction. | DONE 2026-06-17 — diverse-route set + per-faction assignment (WaveSpawner) + **branching map generator** (`MapGenerator._carve_branching_path`: 2 corridors/spawn, verified ≥2 routes). Divergence now expressible on every map. `MapData.map_seed` added as the galactic-persistence hook. |
| **C** | **Garrisons & friendly army** — structures spawn role-based units (Inf/Cav/Armor/Support/Recon); patrols; garrison XP/leveling; resource investment; standing-order raids; offline territory claims. The active-RTS + endless-offline pillar (largest). | **COMPLETE (C1–C4) 2026-06-17.** C1 production · C2 two-way combat + patrols + leveling · C3 standing-order raids (claim frontier ground) · C4 live offline resolution (fast-forward garrison raids over elapsed time, reusing the real raid rules; wired to `offline_catch_up`, dev key F4). **Blocker for offline in normal play: buildings + claimed cells aren't persisted in saves yet (ties into per-territory galactic state).** Next pillar: D — macro→galactic zoom / Total-War campaign. |
| **D** | **Micro→galactic zoom / Total-War campaign** — camera + scene architecture for concurrent fronts. | **D1 DONE 2026-06-17** — galaxy graph (rings→core) + continuous tactical→galactic zoom (`GalaxyView` + camera zoom-out) + deploy to a frontier node's seeded battle map; capture on `map_completed` (wired). **Blocker for full loop: per-territory state persistence (buildings/claims/ownership) — shared with C4 offline.** Next: that persistence, then per-territory win conditions + diplomacy layer. |

Open design Qs for B/C captured in `vision-roadmap.md` (enemy selection per map, 3-way
convergence, pathing-bias vs distinct algorithms, unit-role RPS, offline sim tick model).

## Backlog (not scheduled — pull into a later pass on request)

- Rally points / RTS unit-production polish.
- ✅ Detection counterplay depth — DONE 2026-06-16. Live transient detection: FOB + Commander + detector towers (mesh_t2b Relay Pylon, T3 apexes) reveal stealth only within radius. Replaced the permanent sensed-bit model. (Deferred: detector ring visual, detector buildings, detector-specific stealth resistance.)
- Accessibility pass (colorblind-safe territory/fog, motion options).
- Balance retune of `EconomyManager.TERRITORY_RATE_PER_CELL` + sphere radii once the
  above ship (area-claim economy currently grows fast).
