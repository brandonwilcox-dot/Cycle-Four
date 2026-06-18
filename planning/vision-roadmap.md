# Cycle Four — Vision Roadmap (post-MVP)

> Captured 2026-06-16 from a design-direction session. This is the north star for the
> next era of work, beyond the shipped MVP (dashboard, combat triangle, stealth, tower
> mastery, detection, FOB doctrine, RTS controls). Grounded in `codex/` canon.

## The four pillars

### 1. Multi-faction conflict (enemies = the other two factions)
The "enemies" are the **other two factions**, all contesting the same territory.
- Most maps: **one** enemy faction pressuring you.
- Some maps: **all three factions converge** on one map — a three-way fight where you
  can't hold with a single strategy (the combat triangle becomes live and decisive).
- Endless conflict across **multiple fronts**, from the micro (a single unit) to the
  macro (the galactic view).
- **This activates the combat triangle we already built** — today waves spawn the
  player's own faction (neutral damage), so the RPS barely fires. Switching waves to
  enemy factions is the foundational unlock.

### 2. Faction-flavored enemy pathing (RTS-loose, not rigid TD lanes)
Enemy movement should follow faction norms (codex §05):
- **Architects** — cut **direct** paths to their goal (efficiency; shortest route).
- **Bloom** — **spread in all directions**, blocking paths less travelled (sprawl).
- **Mesh** — spread like Bloom but with **directional purpose** like Architects
  (raider intent: spread to find weak points, then commit).
Paths stay readable but feel looser/organic rather than fixed conveyor lanes.

### 3. Garrisons & a living friendly army (the active RTS layer + offline loop)
Buildings gain real purpose — supporting faction growth + defense, AND acting as
**rally points / garrisons** for friendly units.
- **Structures spawn friendly units over time**, by role:
  **Infantry / Cavalry / Armor / Support / Recon** (different structures → different roles).
- When a garrison has **enough units → a patrol starts**.
- Patrols **gain experience → the garrison levels up → new unit types unlock**.
- Players spend **resources to develop garrisons** (accelerate/steer growth).
- **Endless offline play:** successful defenses, or **raids launched from standing
  orders**, give a sufficiently experienced army the opportunity to **claim new
  territory** while away.

### 4. Macro view & zoom (micro → galactic)
A true representation lets the player **zoom from a single unit out to the galactic
view**. Zooming into individual territory conflicts extends the endless play to the
full map; the galaxy is a web of concurrent fronts.

---

## Proposed phasing (dependency-ordered)

| Phase | Scope | Why this order | Size |
|---|---|---|---|
| **A. Enemy factions in waves** | Waves spawn the *other* factions (1 enemy faction default; rare 3-way). Wire to the combat triangle so type match-ups matter. | Foundational — makes the triangle + FOB doctrine + tower branches *mean something*. Smallest high-impact change. | M |
| **B. Faction-flavored enemy pathing** | Architect direct / Bloom sprawl / Mesh directional-spread, layered on the existing path system. | Builds on A; needs enemy factions present to express their norms. | M–L |
| **C. Garrisons & friendly army** | Structures as garrisons spawning role-based units (Inf/Cav/Armor/Support/Recon); patrols; garrison XP/leveling; resource investment; standing-order raids; offline territory claims. | The big "active RTS layer + endless offline" pillar. Largest gameplay system; benefits from A/B being in place to fight against/with. | XL |
| **D. Macro view & zoom** | Camera/scene architecture for micro→galactic zoom; multiple concurrent fronts; galaxy as the meta-board. | Architectural; best last, once a single front is fully realized so it can be replicated across the map. | XL |

## Notes / open design questions
- **A:** how is the enemy faction chosen per map? (galaxy-politics §11 has the cascade
  / adjacency model — likely reuse it.) Mixed 3-way: spawn weighting per front?
- **B:** pathing cost modifiers per faction vs. distinct algorithms; keep AStar but bias
  weights (Architect: straight-line bias; Bloom: multi-goal flood; Mesh: weak-point seek).
- **C:** unit role rock-paper-scissors? (Inf/Cav/Armor triangle on top of the
  damage/armor triangle.) Garrison level gating; offline simulation tick model.
- **D:** how many fronts run concurrently; LOD/simulation fidelity when zoomed out.

## Decided
- Q ability stays **charge-gated** (not converting to cooldown).
- Veterancy icons **condense** (stars collapse 3 ranks each) — done 2026-06-16.

## Progress
- **Phase A — DONE 2026-06-16.** Waves spawn the player's weak-matchup faction (`WaveTableBuilder.enemy_of`).
- **Phase B — DONE 2026-06-17.** Diverse-route set + per-faction assignment policy
  (Architect direct / Bloom sprawl / Mesh weak-point seek), penalty-method bias on AStar.
  Playtest exposed that maps gave 1 route/spawn → followed up with a **branching map-generator
  pass** (`MapGenerator._carve_branching_path`: 2 parallel corridors/spawn; verified ≥2 routes).
  Divergence now expressible on every generated map. See `CLAUDE.md`.
- **Map persistence / galactic alignment (decided 2026-06-17).** No new map format — `MapData`
  already serializes (Resource) and `generate(seed)` is deterministic. Added `MapData.map_seed`:
  Phase D's galaxy = a **graph of territory nodes**, each storing a seed + {adjacency, owner,
  distance-to-core}; battle maps regenerate from seed on demand. Total-War-style expansion toward
  the galactic core. (Future-Phase-D direction, not built yet.)
