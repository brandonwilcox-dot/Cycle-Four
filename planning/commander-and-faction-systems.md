# The Commander Bottleneck & Faction Identity — Design Plan

> Captured 2026-06-23 from a playtest design session. Answers "why build anything if the
> Commander can solo every base?" by making the Commander a **mortal, overworked engineer-leader**
> rather than a self-sufficient win-button. Buildings become the player's real force; the Commander
> enables and protects them. Extends planning/territory-conquest-plan.md (Phase 1 = enemy bases, done).

## The problem (debug playtest, 2026-06-23)

Phase 1 made conquest = destroy the enemy base anchoring each spawn (army assault). But the
Commander can solo every base with no reason to build:
- Bases are passive (no enemy response yet).
- Waves are opt-in (Begin Waves) — base destruction needs no combat at all; you can clear all
  bases during STANDBY.
- The Commander is a Swiss-army unit: it claims territory, fights units, AND cracks bases — alone,
  everywhere, risk-free.

So towers and garrisons are pointless: nothing makes the Commander insufficient.

## The fix (user direction, 2026-06-23)

The Commander must be **insufficient alone — mortal, and consumed with tasks.** All three levers
from the design fork apply (siege / bases-fight-back / commander-leads-army), unified by making
the Commander the bottleneck and the buildings the force.

### Core mechanics (verbatim intent)
1. **Commander health + death.** The Commander has a health bar; it can be destroyed → you LOSE
   and are forced out of the territory.
2. **Commander completes construction.** You can place a tower/garrison anywhere, but it spawns at
   ~10 HP and is *incomplete* until the Commander moves to it and finishes the build. The
   Commander's weapon doubles as the engineering tool. Only the Commander can complete a build.
3. **Commander repairs.** A damaged structure can only be repaired by the Commander (same tool).
4. **Faction structure identity (load balance / preference):**
   - **Architects** — build faster, stronger structures.
   - **Bloom** — towers grow stronger over time.
   - **Mesh** — node connections between towers; the last tower in a connected line is strengthened.
5. **Faction passive abilities (towers / garrisons):**
   - **Architects** — walls that block enemy paths (enemies must clear them; max one wall per X spaces).
   - **Bloom** — pollen that slows + blinds enemies.
   - **Mesh** — hijack enemies to fight their former allies (time-delayed; wears off).
6. **Enemy bases are faction-based** and respond within that faction's abilities (the deferred
   enemy-response, now faction-flavored — an enemy Bloom base defends like Bloom, etc.).
7. **Future: multiplayer.** The asymmetric, commander-led, faction-kit model is built to enable PvP later.

## Phased build (dependency-ordered — ONE system per session)

### Phase 2 — The Commander bottleneck (the core fix) — NEXT
- **2A. Commander mortality:** HP + health bar; enemies attack the Commander; destroyed → territory
  loss / forced retreat to the galaxy.
- **2B. Commander-as-engineer:** towers/garrisons spawn incomplete (~10 HP, non-functional) until
  the Commander reaches them and channels the build (weapon = tool); only the Commander repairs damage.
- Result: the Commander is consumed with tasks and mortal; defenses depend on Commander-time; you can
  no longer solo everything. **Building becomes necessary.**

### Phase 3 — Enemy bases respond (per-faction pressure)
- Bases fight back within their faction's abilities (deferred enemy-response). Supplies the pressure
  that makes spending Commander-time on defenses worth it.

### Phase 4 — Faction structure identity
- **4A.** Build preferences (Architect speed/strength, Bloom growth-over-time, Mesh node-chains).
- **4B.** Faction passives (Architect walls, Bloom pollen slow/blind, Mesh hijack).

### Phase 5 — Build limits & economy tuning
- Structure caps (from the earlier ask) + economy retune now that the Commander gates building.

### Phase 6+ (future) — Multiplayer scenarios
- Asymmetric commanders + faction kits + bases enable PvP. Far horizon; the architecture above allows it.

## Open design questions (resolve when we reach each phase)
- **"Forced out of territory" semantics** (Phase 2A): retreat to the galaxy + the territory reverts to
  enemy/contested? Any penalty (lost development)?
- **Construction model** (2B): instant-on-arrival vs a short channel/progress bar? Can several
  incomplete builds sit waiting? Does an incomplete structure block its cell / cost upkeep?
- **Build limits** (Phase 5): does an incomplete build count against the cap?
- **Mesh node-connections** (4A): how is a "line" defined — cell adjacency, range, or player-drawn links?
- **Pressure source** (Phase 3): do waves stay opt-in (Begin Waves) or do standing bases auto-pressure?
