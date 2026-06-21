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

---

## The four build phases (ordered by dependency)

| Phase | Theme | Status |
|---|---|---|
| A | Enemy factions in waves | **DONE** |
| B | Faction-flavored enemy pathing | **DONE** |
| C | Garrisons + friendly army + offline resolution | **DONE (C1–C4)** |
| D | Micro→galactic zoom + per-territory persistence | **D1 done; persistence in progress** |

**Next required milestone:** per-territory state persistence (buildings/claims/towers survive
deploy + Continue). Without this, C4 offline resolution and D1 galaxy deploy are incomplete.
Reference: `planning/persistence-design.md`.

---

## Decisions that are locked

- Q ability = charge-gated (not cooldown)
- Veterancy icons condense every 3 ranks into a star pip
- `MapData.generate(seed)` is deterministic — no bulky map storage needed
- Galaxy = graph of territory nodes, each storing a `map_seed` + {adjacency, owner, ring}
- Battle↔Galaxy stays unified (same scene, continuous zoom) — NOT separate screens
- Academy is a director on the Battle screen, NOT a separate scene

---

## Session start checklist for Claude Code

1. Read NORTHSTAR.md (this file) — confirm the change doesn't violate any truth above
2. Read NEVER_TOUCH.md — confirm the change doesn't touch guarded code
3. Read BACKLOG.md — if the request is already there, pull it; if it's new, add it first
4. Read CLAUDE.md — current architecture state
5. Scope: ONE system per session. State which file(s) will be touched. Touch no others.
6. After every file change: `mcp__godot__run_project` + `get_debug_output`. Zero new errors before proceeding.
7. After session: tag the working state with `git tag session-MMDD`
