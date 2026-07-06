# Land Units Work Plan — refactored from `docs/codex/Units_Land.md` (2026-07-03)

> Source spec: `docs/codex/Units_Land.md` (authored by the user; copied from the design repo
> at its suggested path). Authority chain per that doc: **corpus wins on mechanics, Codex wins
> on canon feel.** This plan reconciles the spec against BOTH the corpus (`core/10`–`core/22`,
> esp. core/17 + core/21) and the actual code on `main`, answers the spec's §9 questions, and
> replaces the old unit-work items (backlog **J1 real-wave parity is absorbed into phase U5**).

---

## 0. Reconciliation findings (spec §9 answered against corpus + code)

### What ALREADY EXISTS in code (the spec's structural bets are safe)
- **Towers / Garrisons / Tether — all real.** Towers are immobile player defense ✓. Garrisons
  (`Building.gd`) produce `FriendlyUnit`s on cooldown ✓. **The tether exists**: `FriendlyUnit.
  MAX_LEASH = 220` clamps movement around the home garrison, engine-enforced, never babysat —
  spec §6's first anti-micro rule is already satisfied. Patrols, raids, and body-blocking exist.
- **Detection/stealth exists** (UnitData.stealth, reveal tiers, `detectors` group) — so the
  Mesh **Deceiver (§3) is NOT a stretch unit anymore**; its stated prerequisite is met.
  Reclassified: normal T2, still sequenced late.
- **Bloom adaptation scaffolding exists**: `UnitData.evolve_threshold`/`evolved_unit` (evolve
  on damage) — the T3 Adaptive Assault's per-wave-buff variant extends this, not new ground.
- **Garrison state-over-time partially exists** (§9 Q1): `Building` has kill-XP **leveling**
  (bigger/faster squads). It is kill-based, not time-based, and not per-faction. Phase U1
  replaces/absorbs it with the three node fantasies.
- **Economy asymmetry is supported** (§9 Q4): per-faction resources + rates already flow
  through FactionManager/EconomyManager; Mesh theft mechanics exist (tower hijack, raids).
  **Naming conflict → corpus wins:** the game's resources are **energy/schematics** (per
  faction), not SupCom Mass/Energy; the spec's "Mass cost" dials map onto the existing model.
  There is no *streaming* economy; rate-based accrual is the corpus model and stays.
- **Enemy waves now field real rosters** (J1-lite, 2026-07-02): counter-faction/territory-owner
  units, t1→t2→t3 by wave, runner/brute archetypes, boss Alphas. U5 builds on this.

### What DOES NOT exist (new work, scoped below)
- **Per-faction node timers** (§9 Q1): Architect compound / Bloom maturity + connection /
  Mesh overlap-share + reroute — none present. **U1.**
- **Sub-path modifier slots** (§9 Q2): sub-paths exist only as a string on FactionManager;
  there is NO `UnitModifier` schema anywhere. core/17 confirms the *concept* (T2 = sub-path
  commit point; T3 sub-path-flavored) but the slot system must be built. **U0 + U4.**
- **Per-faction tether radii** (§9 Q3): radius is a global const today. Trivial to vary by
  faction (wide/mid/short) and to scale with garrison state. **U0 (static) + U1 (scaling).**
- **Mesh direct-fire LOS** (raycast, no shooting over walls/terrain): not present. Real
  gameplay terrain that BLOCKS anything is itself still open (backlog F1 — current terrain is
  visual-only), so at first "LOS" means walls + structures; terrain occlusion arrives with F1.
- **Shields** (Bloom Mobile Shield, Architect Support/Shield Hybrid): no shield system exists.
  **U3 introduces one shared bubble-shield component.**
- **Dominance Meter** (§9 Q5): entirely unbuilt (core/18 pacification pending). Per spec:
  out of Phase 1; U1 adds a no-op `dominance_hook()` stub on node state so the wiring point
  exists when pacification lands.

### The one REAL corpus conflict — needs the user's call (flagged per the spec's own rule)
**core/17 defines ONE named unit per tier** (Architects: Drone → Auger-Walker → Compiler,
+ Apex/Warden milestones; Bloom: Sporeling → Bramble-Walker → Mire-Beast, + Bio-Titan/Chimera;
Mesh equivalent), with production cadence T1 30s / T2 90s / T3 4min and T2 as the sub-path
commit. **Units_Land §3 specifies SIX roles per faction.** The spec says corpus wins on
mechanics — but the spec is newer intent from the same author.

**Proposed merge (recommended):** keep core/17's *cadence, named units, and T2 commit point*;
treat Units_Land's roles as the ROSTER EXPANSION around them:
- core/17's named T1 IS the **Line Holder** (Drone/Sporeling/Mesh-T1 = the stat anchors —
  conveniently these are exactly the `.tres` files already in the game).
- core/17's named T2 IS the faction's Heavy Assault / workhorse role.
- core/17's named T3 IS the T3 role (Compiler = Versatile Assault Bot, Mire-Beast = Adaptive
  Assault, Mesh T3 = Siege Bot w/ trick).
- Units_Land's scouts / AA / artillery / support / shield become NEW roster slots beside them,
  named in core/17's voice when authored.
This keeps both documents true. **Confirm or override before U2.**

### Missing referenced docs (flagged)
`Soul.md`, a "Tower/Garrison codex," and `Leftpinkytoe.md` are referenced for routing but
exist in neither repo. Not blocking (this plan + core/17 cover the ground), but the routing
preamble should be updated or those docs written.

---

## 1. The phases

Each phase is session-sized-ish, MCP-verified, exported, committed — house rules apply
(zero new errors; anti-micro acceptance criteria from spec §6 checked every phase).

### U0 — Schema foundations — **SHIPPED 2026-07-05** (`72627e6`)
1. `UnitData` gains: `role` (enum: SCOUT/LINE/AA/ARTILLERY/SUPPORT/SHIELD/ASSAULT/SIEGE),
   `tier`, `sub_path_lock` (which sub-path a T2+ unit belongs to, per core/17's commit point),
   `modifier_slots : Array[UnitModifier]`.
2. New `UnitModifier` Resource (`src/entities/UnitModifier.gd`): `id`, `eligible_sub_paths`,
   stat deltas + a `kind` enum for scripted behaviors (TERRAIN_BOND / WRECKAGE_ABSORB /
   DREAM_STABILIZE / plain stat mod). First-class resources per spec §4 — never one-offs.
3. Per-faction tether radii: `FactionPerks.TETHER_RADIUS = {architects: wide, bloom: mid,
   mesh: short}` replacing the global `MAX_LEASH`; FriendlyUnit reads it.
4. Anti-micro acceptance: nothing in U0 adds a player toggle.

### U1 — Node identity: the three canon fantasies on the Garrison — **SHIPPED 2026-07-05** (`885c2f4`, playtest-confirmed)
Replaces kill-XP leveling with per-faction node state (`Building` + a small `NodeState`).
- **Architects — Compound:** undamaged-uptime timer → production cooldown −X%/min and/or
  reinforcement cost decay, capped. Garrison damage or tethered-unit loss resets/decays the
  timer (their canon fear, mechanized). HUD: a small compound-tick readout on the garrison.
- **Bloom — Mature + Connect:** placed-weak → climbing regen aura / armor / damage over
  survival time, capped; **connection bonus** when ≥2 Bloom garrison radii touch (shared buff
  scaling with linked count). Tether radius grows slightly with maturity (Q3 scaling).
- **Mesh — Overlap + Reroute:** units inside ≥2 Mesh garrison radii get RoF/accuracy share
  scaled by overlap count; on garrison death, surviving tethered units **re-tether to the
  nearest Mesh garrison** instead of orphaning. Short tether (U0) makes clustering the game.
- All auras/links automatic in-radius (spec §6). `dominance_hook()` stub for core/18 later.
- Wave exploit windows (spec §2 punishes) verified in playtest: fresh Bloom nodes are
  attackable, Architect ramps resettable, lone Mesh pickets weak.

### U2 — T1 roster build-out — **SHIPPED 2026-07-05** (`63ef826`, playtest-confirmed; Mobile AA deferred — no air layer)
- Line Holders = the existing `*_t1.tres`, re-tuned to spec dials (Architect high-armor wide;
  Bloom hover/amphibious mid w/ regen; Mesh highest-DPS/low-HP direct-fire). Every other T1
  balances against ITS OWN faction's Line Holder (spec §6), axis = value-per-node.
- New: Architect Scout/Combat Hybrid + Mobile AA; Bloom Spore Scout (detection pulse) +
  Mobile Artillery (long range, slow reposition — strong on fixed lanes); Mesh Stealth Scout
  (energy-gated cloak, cheapest unit) + Mobile AA.
- **Mesh direct-fire LOS**: raycast vs walls/structures (terrain occlusion deferred to F1).
- **Bloom hover**: `ignores_terrain_penalty` flag — mechanically inert until F1 gives terrain
  a penalty; wired now so F1 activates it for free. (Visual: hover fits the Aeon+bio anchor.)
- Garrison production UI: role choice per garrison (this finally lands the old backlog item
  "garrison unit-type selection").
- Visuals ride the existing pipeline: UnitBodies role variants per the SupCom anchors
  (Seraphim/Aeon+bio/Cybran), color triad legible at zoom (spec §7 = codex 11.3 ✓ already law).

### U3 — T2/T3 roster + shared systems
- **Shield component** (one implementation, two consumers): Bloom Mobile Shield (pure) and
  Architect Support/Shield Hybrid (shield + real damage at reduced efficiency).
- Bloom Regeneration Support (regen aura — "living tech heals"; no repair beam).
- Architect Heavy Assault (clean stat upgrade; Architects spike at T3 not T2), Mesh Heavy
  Assault (direct-fire constraint carried up).
- T3: Architect Versatile Assault Bot (two jobs @ ~80%), Bloom Adaptive Assault (per-wave
  survivor buff, capped — extends the evolve system), Mesh Siege Bot with ONE legible
  on-death trick (EMP pulse, big visible cue, one-sentence tooltip).
- Mesh Deceiver (unblocked — detection exists): stealth decoy vs the reveal-tier system.
- T2 = sub-path commit point enforced (core/17): T2+ units check `sub_path_lock`.

### U4 — The heresy modifier layer (the Option B seam, never captioned)
- Author the three heretic `UnitModifier`s: **terrain-bond** (Spiritual-Tech: bonus on/near
  favored terrain — real once F1 lands; near-water/relief works TODAY via the map data),
  **wreckage-absorb** (Assimilator: consume field wreckage → resource/reinforce; needs a
  small wreckage-leaves-a-husk mechanic on unit death), **dream-stabilize** (Dreamer:
  −upkeep +durability, the one non-disposable Mesh path).
- Slot gating by sub-path; orthodox paths get clean stat mods only.
- **HARD RULE carried from the spec + Codex:** no tooltip, dialogue, or achievement ever
  names the faction-kinship pattern. Mechanics only. (Canon rule #1; "earned, never told.")
- **Terminology reconciliation:** the spec's "Dreamer" heretic path vs the game's current
  Mesh default sub-path string `networked` — core/20's Mesh paths are Networked/Dreamer ✓;
  code already uses "networked" as Mesh default ✓ consistent.

### U5 — Enemy-side integration (absorbs backlog J1) — **SHIPPED 2026-07-06** (`1f6ffda`)
Missions + telegraphy landed (saboteurs / flankers / hunters, 1/3 of spawns from wave 3).
Remaining J1 slice, deferred: enemy RANGED combat + roster-role enemy compositions.
- Waves field the full role rosters (not just line/runner/brute synthesis).
- **Faction wave TARGETING per spec §5:** Architect waves focus production (garrisons/economy),
  Bloom waves take territory (tethered zones/claims), Mesh waves hunt the single most
  expensive asset. This is the real J1 payload: WaveTableBuilder grows composition + behavior
  tables; commanders (core/12) attack the way their faction thinks.
- Balance tuning goal: no single-flavor build safe (turtle dies to Architect waves, spread
  dies to Bloom waves, hero-unit dies to Mesh waves) → mixed composition is the answer.

### Sequencing + dependencies
**U0 → U1 → U2 → U5 → U3 → U4** recommended. U1 is the identity payoff and needs no roster
growth; U5 before U3 because enemy pressure shapes T2/T3 tuning. Cross-cutting dependency:
**backlog F1 (gameplay terrain)** activates Bloom hover, Mesh terrain-LOS, and the
terrain-bond modifier — F1 rises in priority and should land around U2/U3.

### Out of scope (Phase 1, per the spec)
Air/naval; Dominance Meter behavior (hook only); tier 4–6 lines (core/21) — the schema (U0)
must not preclude them.
