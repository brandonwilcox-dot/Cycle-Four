# Cycle Four — Northstar

> READ THIS BEFORE CLAUDE.md. These truths cannot be cut, changed, or traded for
> convenience. If a proposed change violates one, stop and redesign.

---

## What this game IS (immutable)

**Cycle Four is a three-layer hybrid that is meaningful in 5 minutes and deep over months.**

Layer 1 — Idle production (always running, works offline, no interaction required)
Layer 2 — Tower defense (passive auto-attack, wave-based, session-viable solo)
Layer 3 — Active RTS (Commander + garrisons + orders, optional depth)

The player can ignore any layer they want. All three must coexist without blocking each other.

---

## The five truths

1. **Lore first.** The IP is the asset. Every system must feel like it belongs to the world.
   Mechanics emerge from faction philosophy, not the other way around.

2. **One session = 5 minutes minimum viable.** A player who opens the game for 5 minutes
   must feel progress. Idle income, a wave completed, territory gained — something tangible.

3. **Three factions, one triangle.** Architects / Bloom / Mesh are not skins.
   Each has a distinct economy, army feel, and playstyle. The combat triangle
   (Kinetic→Organic, Energy→Plated, Corrosive→Synthetic) must mean something in every fight.

4. **The galaxy is the endgame loop.** Individual battles are battles for territory nodes.
   Territory nodes are steps toward the galactic core. This never changes — it is the
   Total-War-style macro layer that gives individual battles meaning.

5. **Offline must feel fair.** Garrisons fight while the player is away. The offline
   resolution uses the real rules, not a shortcut formula. A player returning after 8 hours
   should see a territory that evolved, not a number that jumped.

---

## What can NEVER be removed

- `CadetAvatar._unhandled_input` — this IS the Academy player control. Do not touch.
- `Main._unhandled_input` (not `_input`) — GUI controls consume first; map clicks fall through.
- `SaveManager.DEV_CLEAR_SAVE = false` — this must stay false in any non-dev build.
- The combat triangle — Kinetic/Energy/Corrosive vs Organic/Plated/Synthetic. Hard-coded in `Combat.gd`.
- `WaveTableBuilder.enemy_of(player)` — enemies are ALWAYS the weak-matchup faction, not the player's own.
- **The heresy layer is NEVER captioned in-game.** U4's borrowed-mechanic modifiers (terrain-bond /
  wreckage-absorb / dream-stabilize) express as mechanics only — no tooltip, dialogue, achievement,
  or UI text may ever name why the three factions feel related.
- **The selective-emission + localized-light recipe** in `docs/DESIGN-GUIDELINES.md` is permanent.
  Structures glow in discrete channels with real local spill — never body-wide bloom.
- **Emission masks ship VRAM-compressed with mipmaps** (`compress mode=2`, `mipmaps=true`,
  `detect_3d/compress_to=0`). A blanket import-preset change must not break this.
- **Cycle Four is the sole source of truth for build AND design.** The corpus lives in-repo at
  `docs/core`, `docs/codex`, `docs/planning`. The former Skippy project is historical only —
  never read from or write back to it.

---

## The four build phases (ordered by dependency)

| Phase | Theme | Status |
|---|---|---|
| A | Enemy factions in waves | **DONE** |
| B | Faction-flavored enemy pathing | **DONE** |
| C | Garrisons + friendly army + offline resolution | **DONE (C1–C4)** |
| D | Micro→galactic zoom + per-territory persistence | **DONE** (Steps 1–5 + conquest persistence, 2026-06-24) |

The original four dependency phases are complete. Work since then has run as named tracks,
each of which assumed the A–D foundation:

| Track | Theme | Status |
|---|---|---|
| 3D | Full 2D→3D migration (Node3D entities, RTS camera, galaxy zoom) | **DONE** — merged to main 2026-07-01 |
| V | Visual supercharge V1–V6-lite (atmosphere, substrates, motion, set pieces) | **DONE** — wrapped 2026-07-02 |
| U | Land-unit plan U0–U5 (node identity, rosters, wave targeting, heresy layer) | **DONE** — 2026-07-17 |
| F1 | Gameplay terrain (impassable water, forest vision penalty, AStar routing) | **DONE** — shipped 2026-07-21, **never hand-playtested** |
| E | Environment skinning: E1 biomes/props/volumetrics ✓ · **E2 obstacles & ruins ← next** · E3 weather · E4 fauna | **ACTIVE** |
| M | Hi-fi structure models + emission-mask bake pipeline | **ACTIVE** |

**Next required milestone:** close out the structure-emission pass, then re-export.
Three things, in order:

1. **Blender geometry fix on the Architect FOB front gate** — it is still a flat teal panel in
   albedo, so a mask can only ever rim it. Inset/recess the opening. This is the one remaining
   item that genuinely requires Blender.
2. **Garrison Keep mask is BLOCKED** — its diffuse is fully achromatic (De-light stripped the
   cyan channels), and its existing mask is verifiably noise. Needs a Rodin re-export with
   De-light OFF, or the channels authored as a second emissive material in Blender.
   **Do not ship a colour-derived mask for it.**
3. **Hand-playtest the F1 terrain slice, then run `.\tools\export.ps1`.** Both exes are stale —
   last export 2026-07-24 16:58, which predates the Plasma Bastion T2 tower, the Commander nav
   standards / GPS route ribbon, and the rebuilt emission masks.

After that: **E2 — Obstacles & Ruins.**
Reference: `docs/DESIGN-GUIDELINES.md` (§2a) · `tools/bake_emission_mask.py`.

---

## Decisions that are locked

- Q ability = charge-gated (not cooldown)
- Veterancy icons condense every 3 ranks into a star pip
- `MapData.generate(seed)` is deterministic — no bulky map storage needed
- Galaxy = graph of territory nodes, each storing a `map_seed` + {adjacency, owner, ring}
- Battle↔Galaxy stays unified (same scene, continuous zoom) — NOT separate screens
- Academy is a director on the Battle screen, NOT a separate scene
- Waves are **player-summoned** with a long auto-fallback — Battle3D is the sole wave clock
- Faction FOB models must scale so the **Commander never out-heights the external walls**
- Emission masks are baked by `tools/bake_emission_mask.py` — blue-dominance → morphological
  OPEN → per-component shape classification → polygon faceting. **No blur, no dilate, ever.**
- Cosmetics apply to **player units only** — enemy units stay stock for readability
- The 5 unit roles (Inf/Cav/Armor/Support/Recon) are **behaviors, not a second RPS** —
  there is exactly one combat triangle

---

## Session start checklist for Claude Code

1. Read NORTHSTAR.md (this file) — confirm the change doesn't violate any truth above
2. Read NEVER_TOUCH.md — confirm the change doesn't touch guarded code
3. Read BACKLOG.md — if the request is already there, pull it; if it's new, add it first
4. Read CLAUDE.md — current architecture state
5. Scope: ONE system per session. State which file(s) will be touched. Touch no others.
6. After every file change: `mcp__godot__run_project` + `get_debug_output`. Zero new errors before proceeding.
7. Before importing, replacing, or materially restyling any visual asset: read `docs/DESIGN-GUIDELINES.md`.
8. After a change is verified: re-export with `.\tools\export.ps1`. The `.exe` does NOT auto-update,
   and `run_project` never touches it. Stale exes have been a recurring failure here.
9. After session: tag the working state with `git tag session-MMDD`
