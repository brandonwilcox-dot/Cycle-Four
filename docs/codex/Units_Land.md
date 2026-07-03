# Units_Land.md — Land Unit Design Codex (Phase 1)

**Suggested path in repo:** `docs/codex/Units_Land.md`
**Routing:** Load when the task is "design/implement a land unit," "balance the land roster," or "does this unit feel on-canon for its faction." Read `Soul.md` first (streaming Mass/Energy, T1–T4, endless-wave/Collapse structure), then the Tower/Garrison codex, then this file.

**Canon authority:** This file is a *mechanics* document. Where it touches world-truth it defers to the Codex (`00`–`11`). Two hard canon rules govern every unit below and must never be violated in-game:
1. The three factions are **one civilization fractured** (Option B). Units may *embody* the seams of that truth but the game **never states it**.
2. Each faction's **internal heresy is canon and load-bearing** (Architect Spiritual-Tech → Bloom; Bloom Assimilator → Mesh; Mesh Dreamer → the unbroken origin). The sub-path system in section 4 is built on these and may not remove them.

**Reconcile against the design corpus:** the mechanical specifics of Garrisons, tether radius, the Dominance Meter, and sub-path modifier slots live in `core/10`–`core/22` on disk (`D:\AI\Cycle Four`), which I can't read from chat. Fable-5-in-Code should cross-check section 2 and section 4 against those files and flag any conflict — where this file and the corpus disagree on *mechanics*, the corpus wins; where they disagree on *canon feel*, the Codex wins.

**Scope:** Phase 1, land only. Air/Naval reuse this framework later.

---

## 1. The hybrid structure this roster is built on

Three fixed pieces already exist; the land roster is designed around them, not on top of a new mechanic:

- **Towers** — immobile, player-placed. They own rooted defensive fire outright. No land unit competes with a Tower for that job.
- **Garrisons** — the unit source. Land units spawn from Garrisons on cooldown (the "active production" layer of the idle/TD/wave hybrid).
- **Tether** — spawned units must stay within a radius of their Garrison. They are full RTS units *inside the leash*, but the leash is fixed like a tower-defense layout. The battlefield reads as a set of Garrison **nodes**, each projecting a controllable pocket of army toward the approach to the Core.

This is the genre blend, and it's structural: the player thinks like a TD designer placing nodes and Towers, and like an RTS commander fighting inside each node's radius. No per-unit "anchor" toggle is needed — Towers cover rooted defense, the tether supplies the TD constraint. (The earlier Anchor Mode idea is cut.)

**The node is the unit of faction identity.** How a faction's Garrison + tethered units behave *over the life of a node* is where the canon fantasies live (section 2), more than in any single unit's stats.

---

## 2. Faction node identity — the three canon fantasies as mechanics

Each faction's SupCom mechanical DNA is now expressed through its **Codex fantasy**, not just borrowed wholesale. This is the main lever that keeps the three rosters from collapsing into "same tank, different color."

### Architects — **Compound** (UEF armor + Seraphim versatility)

> Canon: *"They build slowly and visibly, and then their work compounds — each improvement making the next improvement faster — until they outpace everything around them."* Peak: the Singularity. Fear: chaos, contamination, disorder.

- **Node behavior:** an Architect Garrison gets *more efficient the longer it operates undamaged* — production cooldown drops and/or reinforcement cost falls as an active timer climbs. Slow to start, dominant if protected.
- **Tether:** wide and stable. High unit survivability lets one node cover a lot of ground with few units.
- **SupCom DNA:** UEF high armor/HP (the node holds), Seraphim dual-role hybrid units (fewer unit *types*, each doing two jobs — so a compounding node needs fewer distinct units to stay complete).
- **The punish (from their canon fear):** taking damage to the Garrison, or losing tethered units, **resets or decays the compound timer.** Architects are the "protect the ramp" faction — their power is fragile at the base of the curve and overwhelming at the top, and chaos costs them the curve.

### Bloom — **Mature** (Aeon hover/shield/range + biological growth)

> Canon: *"fragile when young and nearly unkillable when mature, because a mature Bloom has survived most things and grown resistant to them."* Connected living worlds amplify each other by orders of magnitude. Peak: the Biosphere.

- **Node behavior:** a Bloom Garrison is *weak the moment it's placed and grows resistant/stronger the longer it survives* — passive regen, climbing armor/damage buffs, an ally aura that strengthens over waves and caps out. This is literal canon, not invented flavor.
- **Connection bonus:** two or more Bloom nodes whose radii connect amplify each other (a shared buff scaling with how many nodes are linked) — the "connected living worlds" fantasy. This is Bloom's version of a network, but organic and slow rather than instant.
- **Tether:** mid radius, hover/amphibious locomotion — Bloom units cross terrain other factions' units can't, so a node can project into map areas rivals can't hold.
- **SupCom DNA:** Aeon range + bubble shields + terrain-agnostic hover, plus bio regen/growth.
- **The punish:** a Bloom node is at its most vulnerable in the window right after placement, before it matures — aggression *early* is the answer, and the game should let enemy waves exploit fresh nodes.

### Mesh — **Take** (Cybran networked/stealth/glass-cannon)

> Canon: *"The network is the self — individual nodes are not people, they are nodes, and when a node is lost the Mesh does not mourn. It reroutes."* Weakest passive economy *by design*; built to take; survives on tempo, information, theft. Peak: Mesh Control.

- **Node behavior:** weakest base economy of the three (canon). Compensated by two network mechanics:
  - **Overlap targeting-share:** Mesh units inside the overlap of ≥2 Garrison radii share targeting data, granting RoF/accuracy scaled to how many nodes overlap. Rewards dense, clustered node placement.
  - **Reroute on loss:** when a Mesh Garrison is destroyed, its surviving tethered units *re-tether to the nearest Mesh node* instead of dying/disbanding. "Lose a node, reroute." This is Mesh's resilience identity and the reason its fragility is survivable.
- **Tether:** short — pushes the player toward many cheap, packed, overlapping nodes.
- **SupCom DNA:** Cybran high-RoF/low-HP glass cannons, direct-fire-only line units (no arc over terrain — rewards clean sightlines), stealth, and one on-death/on-hit *trick* per tier.
- **The punish:** Mesh units are individually disposable; a Mesh player who spreads into single non-overlapping pickets gets a weak version of every unit. The whole is worth far more than the parts, and *only* when clustered.

**Design rule:** when you spec a new land unit, its stats must make its faction's node fantasy the obvious way to play it. An Architect unit that only works in a tight disposable cluster is off-canon; a Mesh unit that's great as a lone wide picket is off-canon.

---

## 3. Land Unit Roster — Phase 1 (T1–T3)

One roster per faction. Roles repeat; identity lives in the faction column, the node fantasy (section 2), and the sub-path layer (section 4).

### Architects — precision, high armor, compounding nodes

| Tier | Role | Design note |
|---|---|---|
| T1 | Scout/Combat Hybrid | Seraphim dual-purpose: real combat stats on a scout chassis at a Mass premium over a pure scout. Signature Architect move — fewer unit types, each doing more, so a compounding node needs fewer distinct units to be complete. |
| T1 | Line Holder | Stat-anchor unit. High armor, mid everything else, no gimmick. Every other T1 unit in the game balances against this one. Holds the far edge of a wide tether without support. |
| T1 | Mobile AA | Single-job, no gimmick — the UEF "does one thing well." |
| T2 | Heavy Assault | Straight armor/DPS upgrade of the Line Holder. No special ability; Architects spike at T3, not T2 — consistent with a faction whose power is in the *compound*, not in any one unit. |
| T2 | Support/Shield Hybrid | Seraphim-style: a genuine shield-support unit that also deals real direct damage, each at reduced efficiency vs. a specialist. The "why run Architects" answer — lets one wide node self-sustain. |
| T3 | Versatile Assault Bot | Two jobs (anti-ground + anti-air, or + anti-structure) at ~80% efficiency each. Expensive. Lets a low-node-count Architect layout cover threats other factions need extra units for. |

### Bloom — organic, regenerating, maturing nodes

| Tier | Role | Design note |
|---|---|---|
| T1 | Spore Scout | Cheap detection *pulse* — Bloom utility reads as sensing/growth, never concealment. |
| T1 | Line Holder | Hover/amphibious — crosses terrain other T1 units can't, projecting a node into ground rivals can't hold. Easiest single differentiator to implement first (changes pathing on existing lanes for free). |
| T1 | Mobile Artillery | Long range, slow reposition. This archetype under-performs on a fluid RTS front but over-performs defending a fixed lane to a Core — exactly Cycle Four's shape. Should be a strong early pick here even though its Aeon equivalent was middling. |
| T2 | Regeneration Support | Passive HP-regen aura, no repair-beam engineering — *"living tech heals, it doesn't get fixed."* This unit is the mechanical heart of the maturing-node identity: it's what makes a node grow stronger the longer it survives. |
| T2 | Mobile Shield | Standard bubble shield. Needs pairing to justify cost — Bloom's one deliberate composition-tax unit (mirrors the Aeon pattern). |
| T3 | Adaptive Assault | Gains a small permanent stat buff per wave survived (capped). Bloom's maturation fantasy in a single unit — a node full of veterans is the payoff for holding the same ground across many waves. |

### Mesh — fast, fragile, networked, taking nodes

| Tier | Role | Design note |
|---|---|---|
| T1 | Stealth Scout | Short-duration, Energy-gated cloak. Cheapest unit in the game. |
| T1 | Line Holder | Highest T1 DPS in the game, direct-fire only (no arc over terrain/walls; needs a raycast LOS check). Deadly where two Mesh nodes overlap, exposed alone. Mesh's version of skill expression is *placement*, not micro. |
| T1 | Mobile AA | Same narrow single-job design as Architects' — identity is carried by the *other* roles, not by reinventing AA. |
| T2 | Heavy Assault | DPS upgrade of the Line Holder, same direct-fire/no-arc constraint carried up a tier. |
| T2 | Deceiver (stealth transport/decoy) | **Stretch unit** — only build if Cycle Four gets an enemy-vision/detection system to counter. Don't implement until that exists. |
| T3 | Siege Bot with on-death trick | One clean, single-word-tooltip trick — an EMP pulse or a targeting-redirect — that fires *visibly* on death or at a hit-threshold. This is where Mesh's "take" flavor lands: the trick should feel like an exploit, not just damage. One trick only, surfaced with a clear on-screen cue. The Cybran source gimmicks are mechanically great and pedagogically terrible (unteachable without a wiki); don't repeat that. |

---

## 4. The sub-path modifier layer — the heresies, as a build system

This is the biggest canon-driven addition, and the one that makes the unit system carry the IP's central truth without ever speaking it.

**Canon:** every faction has an **orthodox path and a heretic path**, and each heresy is *one step toward another faction*. The corpus gates **unit modifier slots by sub-path**. So a unit isn't just "an Architect tank" — it's an Architect tank built down the **Standard** path or the **Spiritual-Tech** path, and the path determines which modifier slots it can fill.

**The design move:** the heretic path lets a unit fill **one modifier slot with a mechanic borrowed from the faction the heresy steps toward.** Orthodox units are internally consistent and cleaner; heretic units are stranger, and quietly *feel like the other faction*.

| Faction | Orthodox path | Heretic path | What the heretic slot borrows |
|---|---|---|---|
| **Architects** | Standard | **Spiritual-Tech** (→ Bloom) | A *build-with-the-land* modifier: units gain a bonus when placed on/near specific terrain, or a rooting mechanic that draws from the ground. Architect stats, Bloom's relationship to terrain. |
| **Bloom** | Purist | **Assimilator** (→ Mesh) | A *take/absorb* modifier: units consume destroyed wreckage (enemy or friendly) on the field to convert it into resources or self-reinforcement. Bloom growth, Mesh's exploit. Resolves the "how predatory is Bloom" question — Purist is defensive/growth, Assimilator is absorptive/aggressive. |
| **Mesh** | Networked / Standard | **Dreamer** (→ the unbroken origin) | A *remember/stabilize* modifier: a unit that "dreams" gains reduced upkeep and a durability/consistency buff — the one Mesh path whose units are *not* purely disposable. Mesh network, Architect-flavored steadiness. |

**The quiet part — for the designer only, never surfaced in-game:** a player who commits to a heresy path is *mechanically becoming one step toward another faction.* Spiritual-Tech Architects play a little like Bloom; Assimilator Bloom play a little like Mesh; Dreamer Mesh reach back toward the un-augmented origin the Architects insist on. That is the Option B seam expressed in the build system — the player **feels** the kinship through their own units before any Fragment ever spells it out. Per canon rule #1 and the "earned, never told" discipline: **the game must never caption this.** No tooltip, no dialogue, no achievement text points it out. It is there to be assembled, not delivered. Fable 5 should implement the mechanics and say nothing.

**Implementation shape (reconcile with corpus modifier-slot system):**
- `Unit` Resource carries `faction`, `sub_path`, and an array of `modifier_slots`.
- `sub_path` gates which `UnitModifier` resources are eligible for each slot.
- The heretic modifiers (terrain-bond / wreckage-absorb / dream-stabilize) are their own `UnitModifier` subtypes, only eligible on the heretic path.

---

## 5. What the enemy targets — counter-play the roster must answer

Canon: wave commanders attack the way their faction *thinks* (Codex §6). This directly shapes what a healthy player roster needs, because the enemy waves come in the same three flavors:

| Enemy wave flavor | Targets | What it punishes | What the player's land roster needs |
|---|---|---|---|
| **Architect waves** | Your production (Garrisons/economy) | Over-investing a single fat Garrison | Distributed nodes; ability to hold a Garrison under focus fire |
| **Bloom waves** | Your land/territory (tethered zones) | Thin, spread-out coverage | Concentrated overlapping coverage; units that hold ground |
| **Mesh waves** | Your single most expensive assets | Over-investing in one big T3 unit | Redundancy; not staking a wave on one hero unit |

The takeaway for balance: no single-flavor build should be safe. A player who turtles one giant Architect node dies to Architect waves; a player who spreads thin dies to Bloom waves; a player who dumps everything into one T3 dies to Mesh waves. The roster is tuned so **mixed composition is the answer**, which is the anti-micro pillar (composition decisions over click decisions) applied to the wave structure.

---

## 6. Anti-micro rules (canon-consistent)

- **Tether is enforced by the engine, never babysat.** Units auto-return if they'd break the leash. The leash is a design constraint, not a micro task.
- **All faction auras, links, and node bonuses apply automatically in radius** (Bloom regen/connection, Mesh overlap-targeting). No manual formation-boxing, no hand-assigning links.
- **One legible idea per unit.** If a gimmick needs a tooltip longer than one sentence, it's two units pretending to be one. (Mesh's on-death trick especially — surface it *visually*, don't make the player read rules.)
- **Line Holders are the per-faction T1 balance anchor.** Tune every other T1 unit against *its own faction's* Line Holder first. Factions are allowed unequal raw stats as long as each is internally consistent; the shared comparison axis is "value per node," not raw DPS.
- **Nothing about the heresy seam is ever explained in-game** (see §4). Earned, never told.

---

## 7. Visual identity (art-direction anchor, from Codex §11.3)

Keep unit art on-canon so faction reads instantly at strategic zoom:
- **Architects** — cold precision, amber accents. Clean geometry, visible engineering, seamless surfaces.
- **Bloom** — forest green, bioluminescence. Organic silhouettes, growth, no hard tool-marks.
- **Mesh** — near-black, electric blue. Fragmented, networked, glitch-edged forms.

At strategic zoom these collapse to role-coded icons (per Soul.md's SupCom zoom pillar) — but the color triad should survive the collapse so faction is legible even as an icon.

---

## 8. Sample leaf files — one per faction, Line Holder role

Follow this pattern for every unit in section 3 (mirrors your `Leftpinkytoe.md` structure). Note the new `sub_path` and `modifier_slots` fields.

```markdown
# Unit: Architects T1 Line Holder ("placeholder name")

**Faction:** Architects   **Tier:** 1   **Role:** Stat-anchor; holds the far edge of a wide tether
**Sub-paths:** Standard | Spiritual-Tech

## Stats (starting dials, not final)
- HP: high | Armor: high | Speed: mid
- Weapon: direct-fire, standard arc | RoF: mid
- Mass cost: baseline for all T1 mass-cost comparisons
- Tether radius: wide (Architect default)

## Sub-path modifiers
- Standard: no borrowed modifier (clean, reliable)
- Spiritual-Tech: unlocks a terrain-bond modifier slot (+stats when placed on/near favored terrain)

## Godot notes
- `LandUnit` Resource, `faction = Faction.ARCHITECTS`, `sub_path`, `modifier_slots: Array[UnitModifier]`
- Tether: `garrison_ref` + `tether_radius: float`; movement clamps within radius
- No base gimmick — implement first; it's the balance anchor for every other T1 land unit

## Counter-play
- Out-damaged by Mesh's Line Holder head-on; wins on attrition/survivability
```

```markdown
# Unit: Bloom T1 Line Holder ("placeholder name")

**Faction:** Bloom   **Tier:** 1   **Role:** Stat-anchor; terrain-agnostic node projection
**Sub-paths:** Purist | Assimilator

## Stats (starting dials, not final)
- HP: mid, passive regen | Armor: mid | Speed: mid, hover/amphibious (ignores rough-terrain penalty)
- Weapon: direct-fire, standard arc | RoF: mid
- Tether radius: mid; effective coverage grows as the node matures

## Sub-path modifiers
- Purist: growth/regen modifiers only (defensive maturation)
- Assimilator: unlocks a wreckage-absorb modifier slot (consume field wreckage → resource/reinforce)

## Godot notes
- `LandUnit`, `ignores_terrain_penalty = true`; regen ticks passively
- Node maturity timer scales unit buffs and/or tether radius over waves

## Counter-play
- Weakest the moment its node is placed; strongest if a wave lets it mature — punish it early
```

```markdown
# Unit: Mesh T1 Line Holder ("placeholder name")

**Faction:** Mesh   **Tier:** 1   **Role:** Stat-anchor; highest raw T1 DPS, wants overlap
**Sub-paths:** Networked | Dreamer

## Stats (starting dials, not final)
- HP: low | Armor: low | Speed: mid
- Weapon: direct-fire ONLY — cannot hit past terrain/walls (raycast LOS required)
- RoF: high | DPS: highest of the T1 roster across all factions
- Tether radius: short (encourages dense, overlapping nodes)

## Sub-path modifiers
- Networked: overlap-targeting + reroute modifiers (disposable, network-dependent)
- Dreamer: unlocks a stabilize modifier slot (−upkeep, +durability — the one non-disposable Mesh path)

## Godot notes
- `LandUnit`, `has_line_of_sight_requirement = true`
- Overlap bonus: inside ≥2 Garrison radii → subscribe to shared-targeting buff (§2)
- Reroute: on owning Garrison destroyed → re-tether to nearest Mesh node (§2)

## Counter-play
- Anything that outranges it or breaks LOS; dies fast if focused; cost-inefficient as a lone picket
```

---

## 9. Open questions for Fable 5 to resolve against the corpus (`core/10`–`core/22`)

- **Node-timer mechanics already exist?** Section 2 assumes Garrisons can carry per-faction state over time (Architect compound timer, Bloom maturity timer, Mesh reroute). Confirm the Garrison system supports this or scope it as new work.
- **Sub-path modifier slots** — section 4 assumes the corpus's "sub-paths gate unit modifier slots" system is real and land units plug into it. Confirm the slot schema so the heretic modifiers (terrain-bond / wreckage-absorb / dream-stabilize) are authored as first-class `UnitModifier` resources, not one-offs.
- **Tether radius per faction / scaling** — does radius vary by faction and scale with Garrison tier/upgrades? Section 2's identities (Architect wide, Bloom mid-growing, Mesh short) assume yes.
- **Economy asymmetry** — Mesh is canon-specified as the *weakest passive economy*. Confirm the Mass/Energy model lets a faction start economically behind and win on tempo, or Mesh's whole identity needs a different expression.
- **Dominance Meter interaction** — Ancients intervene against whoever's dominating. Do the player's *land units* factor into the dominance calculation, and should any unit design account for drawing (or avoiding) Ancient attention? Out of Phase 1 scope but flag if the Garrison/unit code needs a dominance hook.
