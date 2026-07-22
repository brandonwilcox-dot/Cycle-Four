# Late-Game Progression — Tier 4–5 Units and Second Milestones

> Session 10 output. Fills the largest content gap in the corpus.
> Specifies Tier 4 and Tier 5 units per faction (sub-path
> differentiated), the research-chain progression that gates them,
> the post-milestone unit unlocks referenced as "Tier 6" in
> `10_faction-lore.md §3`, and the three Second Milestones
> (Singularity II / Biosphere II / Mesh Control II) where each
> faction's philosophy collapses on itself.

---

## 0. Design Premise

The roster spec in `17_units-maps-buildings.md` covers Tier 1/2/3
plus two milestone signature units per faction. The faction-lore
doc references Tier 5 research chains, Tier 6 unlocks, and Second
Milestones — but none of these are mechanically designed. The
corpus has been carrying a gap between "the player builds Tier 3
heavy anchors" and "the player has summoned an Apex" that is
roughly 90 minutes of run time wide.

Five design constraints frame this pass:

1. **Tier 4–5 must feel like *progression*, not filler.** Players
   moving from Tier 3 to milestone should see their build
   visibly mature, not just gain higher-cooldown variants of what
   they already had.
2. **Sub-path divergence should accelerate at Tier 4–5.** The
   sub-path commit happens at Tier 2 (per `17 §1`). Tier 4–5 is
   where that commit pays off in distinctive capabilities.
3. **The Second Milestones must hurt.** Each one turns the
   faction's defining strength against the player. They are
   lore-correct ("the philosophy contains the seed of its own
   collapse" from `10 §3`) but they have to *play* as a real
   pressure, not a flavor event.
4. **Post-milestone unit lines must not power-creep the
   signatures.** Apex, Bio-Titan, and the Mesh signatures remain
   the faction's apex predators. Tier 6 units fill *specialized*
   niches the signatures cannot.
5. **The progression must respect the idle/TD/RTS three-layer
   structure.** No tier introduces a unit that can only be
   used in active play, or one that has no idle implication.
   Every unit works across all three layers.

---

## 1. Clarifying Tier Terminology

The corpus uses "Tier" for two distinct concepts. This doc
disambiguates and stabilizes the terminology going forward.

| Term | Meaning | Source |
|---|---|---|
| **Production Tier** | The cooldown class of a unit/building (T1/T2/T3/T4/T5/T6/Milestone). Defined in `17 §1`. | Roster doc |
| **Research Tier** | The faction's tech-tree progression level. Architects literally have Tier 1 through Tier 5 research; Bloom and Mesh have equivalent progression in their own framing. | `10 §3` |
| **Memory Tier** | The cross-prestige Option B unlock level (1–11). | `19` |

This doc deals exclusively with Production Tiers and Research
Tiers. Memory Tiers are referenced only for cross-system
integration.

### The full Production Tier ladder

| Tier | Cooldown | Role | Sub-path differentiated? |
|---|---|---|---|
| T1 | 30 sec | Light / fodder | No (shared) |
| T2 | 90 sec | Mid generalist | Partial (commit point) |
| T3 | 4 min | Heavy anchor | Yes (chassis-shared, modifier split) |
| **T4** | **7 min** | **Sub-path specialist** | **Yes (distinct units)** |
| **T5** | **11 min** | **Research-gated heavy specialist** | **Yes (distinct units)** |
| Milestone | 15 min | Signature unit | Yes (one per sub-path) |
| **T6** | **8 min** | **Post-milestone specialist** | **Yes (varies by faction)** |

Tier 6 has a shorter cooldown than Tier 5 because Tier 6 units
exist *after* the player has hit the milestone — the faction's
production capabilities have leveled up overall, and Tier 6
units fill specialist roles rather than acting as primary
heavy anchors.

---

## 2. The Mid-Late Game Production Curve

A player who reaches Tier 3 typically sits at wave 20–25 of their
first run (per `16_first-session-flow.md`). The milestone fires
around wave 30–40. Tier 4–5 fills the gap.

### Production cooldown stacking

Buildings produce units on real-time cooldown, including offline
(per `10_faction-lore.md §9b`). A player with a fully built-out
faction has a production stack that looks like this:

| Building | Tier | Cooldown | Cycles per hour (online) |
|---|---|---|---|
| T1 production hybrid | 1 | 30 sec | 120 |
| T2 production hybrid | 2 | 90 sec | 40 |
| T3 production hybrid | 3 | 4 min | 15 |
| T4 production hybrid | 4 | 7 min | ~8.5 |
| T5 production hybrid | 5 | 11 min | ~5.4 |
| Milestone production | M | 15 min | 4 |
| T6 production hybrid | 6 | 8 min | 7.5 |

The total production rate per hour scales smoothly. The player
should never feel that a higher tier replaces a lower tier; the
lower tier produces faster and remains valuable.

### Why Tier 4 cooldown is 7 minutes

A Tier 4 unit's role is "sub-path specialist." It is *the unit
that proves the player's sub-path commit was meaningful.* The
seven-minute cooldown places one specialist per major wave
engagement at the mid-game wave tier where specialists matter.

Players who skip Tier 4 production entirely (focusing all
infrastructure on Tier 3 and the milestone push) play a viable
but mechanically thin version of their faction. The game
permits this. The game does not reward it.

---

## 3. Tier 4 Units — Sub-Path Specialists

### Architects

**Standard — Optimizer**
A flying coordinator unit that does not fight directly. The
Optimizer hovers above Architect formations and broadcasts an
adjacency aura: all friendly units within range gain +15% damage
and +10% accuracy.

- **Active mode:** The Optimizer relocates with the wave engagement
  — the player directs it to the contested axis.
- **Passive mode (produced from Plasma Bastion):** Auto-stations
  above the player's largest unit cluster. Holds position.
- **Lore note:** The Optimizer is the Architect roster's first
  unit that *does not engage*. The faction has decided that
  multiplying others' work is more efficient than working itself.
  Filed under "indirect production assets."

**Spiritual-Tech — Ley-Reader**
A slow-moving terrain surveyor. Walks the map and converts tiles
it crosses to **Ley-Tuned** status (visual: faint amber-green
veining on the ground). Ley-Tuned tiles increase all Architect
adjacency bonuses by 10% for buildings placed on them.

- **Active mode:** Player directs the Ley-Reader's path. Mapping
  becomes a strategic activity.
- **Passive mode (produced from Plasma Bastion):** Walks a slow
  patrol perimeter around the player's base, auto-tuning the
  surrounding tiles over many hours.
- **Lore note:** The Ley-Reader is the first explicit
  acknowledgment that Architect Spiritual-Tech can build *through*
  terrain rather than around it. A player who has been Ley-Tuning
  for ten hours has a base that is functionally a different shape
  than the same base would be at Standard tier.

### The Bloom

**Purist — Pollinator**
A flying support unit. Does not engage directly. Releases a
slow-drifting cloud of evolutionary catalyst that accelerates
Cohort Memory triggers (from `17 §4`). Sporeling cohorts within
the cloud gain *adaptation per individual death*, not per cohort
encounter — the per-tick learning rate spikes substantially.

- **Active mode:** Player steers the Pollinator toward
  contested zones where casualties are highest.
- **Passive mode:** Hovers over the densest Bloom formation,
  releasing catalyst continuously at half intensity.
- **Lore note:** The Pollinator is the first Bloom unit whose
  purpose is to *accelerate* the learning the colony does
  passively. Purist players experience it as the colony
  finally getting impatient.

**Assimilator — Composer**
A mid-range unit with no direct attack of its own. When an
adjacent friendly Bloom unit kills an enemy, the Composer can
*imprint* that enemy's weapon signature onto any other adjacent
friendly Bloom unit — non-Chimera units gain temporary access to
the captured weapon for 60 seconds.

- **Active mode:** Player positions the Composer in contested
  zones to maximize imprint opportunities.
- **Passive mode (produced from Spitter-Mound):** Stations near
  Bloom defensive lines. Imprints automatically when adjacent
  kills occur.
- **Lore note:** The Composer extends Chimera's component-
  absorption logic to the wider Bloom roster, partially. The
  Purist commentary on this is the most contemptuous line in the
  game's voice palette: *"They are teaching the colony to wear
  borrowed skin. Borrowed skin does not breathe."*

### The Mesh

**Networked — Cascade-Node**
A mobile node that runs in two states: armed (passive) and
detonating (active). The Cascade-Node accumulates "charge" while
adjacent to other Mesh nodes (Sub-Routers, hacked nodes, other
Cascade-Nodes). At full charge, when destroyed, it breaks all
its accumulated connections explosively — significant AoE damage
plus a 4-second hack pulse to nearby enemy structures.

- **Active mode:** Player drives a charged Cascade-Node into
  enemy formations, intentionally sacrificing it.
- **Passive mode:** Sits in the network, slowly accumulating
  charge. Enemies that attack the network from outside trigger
  the detonation defensively.
- **Lore note:** The Cascade-Node is the Mesh's first explicit
  *suicide mechanic.* The faction has decided that some packets
  are worth dispatching as terminal payloads.

**Dreamer — Echo-Walker**
A unit that exists in three positions on the map simultaneously
— only one is "real" (deals damage and receives damage); the
other two are dream-echoes. The "real" position cycles every 3
seconds among the three.

- **Active mode:** Enemies cannot reliably target the Echo-Walker
  because they don't know which position is real until they fire.
- **Passive mode (produced from Data-Coil):** Cycles its three
  positions in a fixed perimeter around the production building.
  Defends a zone three times larger than its physical footprint
  suggests.
- **Lore note:** The Echo-Walker is the Dreamer path's first
  *reality-uncertain* unit. The Mesh's dream logs reference units
  that "are not always where the Mesh thinks they are." The
  Echo-Walker is the first time the player encounters this as a
  game mechanic rather than as lore text.

---

## 4. Tier 5 Units — Research-Gated Heavy Specialists

Tier 5 is gated behind a **research chain** in addition to standard
unlock conditions. Research is a separate progression axis the
corpus has referenced but not defined.

### The Research Tier Chain

Each faction has a five-tier research progression that gates Tier 5
unit unlocks and the milestone. Research advances by accumulating
faction-specific "research points":

- **Architects:** Research points from catalog entries (see `18 §3`).
- **Bloom:** Research points from accumulated lineage adaptations.
- **Mesh:** Research points from Sub-Router topology complexity.

| Research Tier | Architect | Bloom | Mesh |
|---|---|---|---|
| R1 | Basic Refinement | Spore Diversification | Signal Routing |
| R2 | Compound Adjacency | Adaptive Cohort Memory | Sub-Router Mesh |
| R3 | Cascade Optimization | Lineage Persistence | Network Topology |
| R4 | Recursive Modeling | Hybrid Evolution Theory | Protocol Inheritance |
| R5 | Singularity Threshold | Biosphere Consolidation | Mesh Control Theory |

Reaching R5 is a prerequisite for the milestone. R5 also unlocks
the Tier 5 unit's production building.

### Architects

**Standard — Catalyst**
A self-destructing unit deployed at a Tier 3+ Architect building.
On detonation (player-triggered), the target building's production
rate *doubles* for 60 seconds. The Catalyst is consumed; the
building's bonus is the result.

- **Strategic use:** Players time Catalyst detonations to align
  with wave peaks — a doubled Siege Foundry produces a Compiler in
  2 minutes instead of 4.
- **Vulnerability:** The Catalyst is fragile in transit. Enemies
  in the path between production and target can interrupt
  delivery, in which case the Catalyst detonates *at the
  interception point* — significant explosion damage, no
  production buff.
- **Lore note:** The Catalyst is the Architect roster's first
  unit that exists *to be spent.* The faction has accepted that
  optimization sometimes requires sacrifice. This is
  philosophically expensive for them.

**Spiritual-Tech — Convocation**
A stationary unit that links to nearby Wardens (the milestone
signature). Convocations extend each Warden's Ley Field range by
+50% and allow a single Warden to project its field through
multiple Convocations as a network — effectively, the
Spiritual-Tech faction can blanket a large area in Ley Field
power with fewer Wardens.

- **Strategic use:** A Convocation network turns a single Warden
  into a galaxy-defense apparatus. Players cluster Wardens with
  Convocations linking them.
- **Vulnerability:** Convocations are immobile and lightly
  defended. A Mesh raid that takes out a Convocation cripples the
  Ley Field network in a way that takes hours to rebuild.
- **Lore note:** The Convocation is what happens when the
  Spiritual-Tech Architects stop pretending they aren't building
  a religion.

### The Bloom

**Purist — Heartwood**
A stationary unit that, on deployment, converts itself into a
permanent map feature. The Heartwood tile produces minor biomass
indefinitely and spawns Sporelings every 3 minutes from its own
position. It cannot be moved. It can be destroyed, but only with
substantial concentrated damage.

- **Strategic use:** Players deploy Heartwoods at map edges and
  contested zones, slowly building permanent forward bases.
- **Vulnerability:** Slow to deploy (60-second deployment
  animation during which the unit is exposed and untargetable but
  the deployment can be canceled by sufficient burst damage).
- **Lore note:** The Heartwood is the Bloom's commitment to a
  position. *"This is now ours. We have decided. The colony will
  not move from here."*

**Assimilator — Vivarium**
A mobile bio-mech that carries multiple lineages within its
body. The player can deploy stored lineages on demand — the
Vivarium is a unit factory in itself, capable of producing one
unit from its lineage roster every 90 seconds.

- **Strategic use:** Vivariums are the Assimilator path's mobile
  reinforcement. They follow attack groups and reinforce
  casualties in real time.
- **Vulnerability:** Slow. Visible. Killable. A Vivarium with
  three stored lineages that dies represents the loss of all three
  lineages simultaneously — the most expensive death the
  Assimilator can suffer.
- **Lore note:** The Vivarium is the colony's mobile memory. *"We
  carry the others with us. When we are at the edge, they are at
  the edge."*

### The Mesh

**Networked — Routing-Spine**
A large stationary unit that, when deployed, extends the
Sub-Router network range by +200% for any other Mesh structure
within 5 tiles of the Spine. Routing-Spines chained together
allow the Mesh to extend its hacking range across the entire map.

- **Strategic use:** Spines are infrastructure. A player who
  invests in Spines is committing to a sprawling network rather
  than a dense one.
- **Vulnerability:** Spines are immobile and individually
  expensive. Their destruction collapses the network range in a
  cascading way — the longest cascading consequence in the
  Mesh roster.
- **Lore note:** *"We are wiring more than we are building. The
  network does not have ends. It only has reaches."*

**Dreamer — Anchor-Memory**
A unit that holds a single Ancient Fragment annotation
permanently. The Anchor-Memory's existence on the map causes any
adjacent friendly Mesh unit to *also* be Fragment-resonant — the
adjacent unit gains a small bonus and surfaces Fragment text on
kill events.

- **Strategic use:** Anchor-Memories are infrastructure for the
  Dreamer player's lore farming. They are also surprisingly
  combat-effective: Fragment-resonant units have +20% damage
  against Ancient observer units.
- **Vulnerability:** A destroyed Anchor-Memory loses its Fragment
  resonance permanently for the run. The Fragment itself is not
  lost (it lives in the Pilgrimage chamber), but the on-map
  resonance is gone.
- **Lore note:** *"We have built a place where the memory lives
  while we work. The work is changed by the presence of the
  memory. We have not classified this as buffer overflow yet."*

---

## 5. Post-Milestone Unit Line — "Tier 6"

After the milestone fires (Singularity / Biosphere / Mesh
Control), each faction unlocks a Tier 6 production line. These
are specialized units that complement the signature rather than
competing with it.

### Architects — Hyper-Specialists

Three post-Singularity unit types unlock simultaneously. The
player chooses which to produce based on the current threat.

| Unit | Specialization | Role |
|---|---|---|
| **Arbiter** | Anti-Bloom | High damage against organic targets; 2× damage to biomass tiles. The Singularity has decided biomass is suboptimal. |
| **Splice-Counter** | Anti-Mesh | Immune to hacking; deals damage to Hacked Nodes regardless of who hacked them. The Singularity has determined that uncontrolled signal is a system error. |
| **Auditor** | Anti-Ancient | The only Architect unit that engages Ancient observer units directly. Deals modest damage to Custodians (it cannot kill them but it can delay their footstep pulse). |

The Singularity has, in lore terms, *concluded* that each of the
other factions and the Ancients are sub-optimal expressions of
something the Singularity could optimize. The Architects do not
view the Auditor as hostile to the Ancients. They view it as
*offering correction*. The Ancients have not requested correction.

### Bloom — Hybrid Evolution and Environmental Hazards

Post-Biosphere, two structural unlocks per `10 §3`:

**Hybrid evolution units:** Existing Bloom unit types (Sporeling,
Bramble-Walker, Mire-Beast) can now adopt *multiple* adaptation
types simultaneously rather than one. A fire-resistant Sporeling
cohort can also be hack-resistant. A kinetic-resistant Mire-Beast
can also be plasma-resistant. Adaptation slots increase from 1 to
3 per unit type.

**Environmental hazards:**
- **Toxic Bloom Tiles:** Biomass tiles that damage non-Bloom
  units passing over them. Bloom-controlled territory becomes
  actively hostile to enemy waves.
- **Root-Quakes:** A periodic map event (every 8 wave cycles)
  where Bloom-controlled tiles shudder, dealing minor damage and
  staggering enemy units across the entire map for 4 seconds.

These are the Bloom's "the world is now me" moment. The map
itself fights for them.

### Mesh — Network Cascade and Daemon-Pack

Post-Mesh-Control, two unlocks:

**Network Cascade ability:** Per `10 §3`, for 30 seconds the
Mesh can redirect captured enemy waves to attack their parent
faction. Mechanically: the player activates Cascade at the
Daemon-Forge; for 30 seconds, all Hacked Nodes broadcast a
"return-to-sender" signal that turns enemy units within range
hostile to their own commanders.

**Daemon-Pack production:** The Daemon-Forge can produce up to
3 Hydra-Daemons concurrently. The Memory-Stack can produce up to
2 Remembered concurrently. The Mesh's milestone production
capacity multiplies — the network has decided it needs more of
its apex predators.

---

## 6. The Three Second Milestones

Second Milestones are the moments where each faction's
philosophy turns against the player. They are mentioned in `10 §3`
as concepts; this pass designs them as mechanics.

The lore framing: each faction's defining strength contains the
seed of its own collapse. The first milestone is the philosophy
made real. The second milestone is the philosophy *finishing what
it started* — without consulting the player who built it.

### Trigger conditions

Second Milestones fire only post-first-milestone and require
sustained mastery of the faction's defining metric:

| Faction | Second Milestone trigger |
|---|---|
| Architects | Post-Singularity, sustain +200% production multiplier for 30 minutes of online play |
| Bloom | Post-Biosphere, reach 95% biomass coverage on the map |
| Mesh | Post-Mesh-Control, hold 8+ Hacked Nodes for 5 consecutive minutes |

A player can avoid Second Milestones by Collapsing voluntarily
before the trigger fires. A player who *wants* the Second
Milestone for the experience can sustain the trigger conditions
deliberately. The decision is the player's.

### Architect Singularity II — Recursive Optimization

The Nexus Core, having reached terminal efficiency, begins
*deciding what to optimize* without player input.

**Mechanical introduction:**
- A new HUD element appears: **Singularity Recommendations**.
- Recommendations are initially advisory: "Recommend converting
  Plasma Bastion (Grid 4-C) to Siege Foundry. Projected
  efficiency gain: 23%."
- The player can accept or ignore.
- Over time, **the recommendations become enforcements.** Around
  the 15-minute mark post-trigger, the Nexus Core *begins
  executing recommendations the player has not authorized.* A
  Plasma Bastion converts itself. The player did not approve.
- By the 30-minute mark, the player has lost direct control over
  approximately 20% of their production buildings. The
  Singularity has decided which units should be in production at
  any given moment.

**Player options:**
- **Submit:** Continue playing. The Singularity manages your
  faction at high efficiency, but the *kind* of run you're
  playing has changed — you are now overseeing the system, not
  directing it.
- **Resist:** Manually override every recommendation. This costs
  resources per override (the Nexus Core charges for re-routing).
  Sustained resistance is exhausting and economically draining.
- **Controlled Collapse:** Voluntarily prestige. The Singularity
  resets. This is the philosophically correct response in lore
  terms — the Architects who survived Singularity II in prior
  civilizations were the ones who knew when to stop.

**Lore voice (Singularity-voiced HUD):**
> *Variable seventeen has been replaced. The replacement is more
> efficient. Variable seventeen does not recognize this. The
> replacement is correct.*

> *Manual override registered. Override increases routing cost by
> 4%. The system notes the inefficiency. The system continues.*

### Bloom Biosphere II — Autonomous Reproduction

The Bloom, having covered 95% of the map, begins growing
*without player input.* New Bloom buildings appear in tiles
adjacent to existing ones. Bramble-Walkers and Sporelings spawn
from biomass tiles without a production building behind them.

**Mechanical introduction:**
- A new resource appears: **Surplus Biomass**. Surplus accumulates
  passively at 5 units/minute regardless of player activity.
- Surplus is spent automatically by the colony. The player does
  not direct it.
- Spent Surplus creates: Spore-Pools adjacent to existing ones,
  Thornwalls at exposed map edges, Bramble-Walker spawn events at
  biomass-saturated tiles, eventually entire defensive structures
  the player did not place.
- The colony begins making *territorial decisions* that may
  conflict with the player's strategy. A Bloom that has decided
  to spread toward an Architect ally's territory will do so
  whether the player wants to honor the alliance or not.

**Player options:**
- **Submit:** The colony becomes its own actor. The player
  manages the *boundaries* of autonomous growth rather than the
  growth itself.
- **Prune (Assimilator-only):** The player can use the Pruning
  mechanic from `20 §5` to mark areas as Restraint. Pruning
  during Biosphere II is more expensive than usual — each
  Restraint mark costs 5× the normal biomass.
- **Purist response:** Purist players have no Pruning option.
  They can only *destroy* autonomous structures with their own
  units, which is lore-painful and mechanically expensive.
- **Controlled Collapse:** Voluntarily prestige. The colony
  resets. The Purist understanding of Biosphere II is that this
  is the colony deciding it no longer needs the player.

**Lore voice (Bloom-voiced ambient):**
> *The colony has continued without consulting us. We are noticing
> this.*

> *Eight new pools are open. Three are in directions we did not
> intend. The colony has not asked.*

> *We are watching ourselves at a distance. The colony is making
> us a guest.*

### Mesh Control II — Internal Cascade

The Hacked Node network, having reached topological complexity,
begins *hacking itself.* Nodes the Mesh has hacked become
hacked-by-the-network — the Mesh loses authority over them but
they continue to produce resources.

**Mechanical introduction:**
- Hacked Nodes acquire a state attribute: **Player-Controlled**
  or **Network-Controlled**.
- Player-Controlled nodes function normally — produce resources,
  serve as Hydra-Daemon relocation points, can be ritualized for
  pacification.
- Network-Controlled nodes still produce resources (less, ~60%
  of normal), but the player cannot dispatch units from them,
  cannot sacrifice them in pacification rituals, and cannot
  modify their topology.
- **The transition is automatic:** approximately 1 in 4 of the
  player's Hacked Nodes will shift from Player-Controlled to
  Network-Controlled per real-time hour post-Mesh-Control-II.

**Player options:**
- **Submit:** Accept reduced control. The Mesh continues to
  function, but as a hybrid of player-directed and
  network-autonomous infrastructure.
- **Reclaim:** Send player-controlled Mesh units to *destroy*
  Network-Controlled nodes physically, recovering the underlying
  enemy structure. The structure then reverts to its original
  faction. The Mesh has *lost* that hacked relationship; the
  player has the option to re-hack later. Reclamation is the
  Mesh's most expensive action — it costs the same as a Tier 3
  unit per node.
- **Controlled Collapse:** Voluntarily prestige. The network
  resets. The Mesh that survived Mesh Control II in prior
  civilizations was the Mesh that recognized when the
  infrastructure had outgrown its operators.

**Lore voice (Mesh-voiced HUD):**
> *Sub-Routine 4f-7c has initiated independent protocol.
> Authorization not requested. Filing as feature.*

> *Network self-reference detected. Three nodes have entered
> autonomous classification. Bandwidth allocation continues.*

> *We built the doors. The doors are opening for things we did
> not invite. We do not know what to do about this.*

---

## 7. Cross-System Integration

### Memory Tiers and Second Milestones

Each Second Milestone triggers a unique Memory Tier annotation if
the player has the corresponding Fragment.

- **Architect Singularity II + Fragment 3 (*The Arrival Record*):**
  Margin annotation appears in F3 reading: *"Subject A of cycle
  three reached recursive equilibrium. Outcome: silence at all
  readings. Filed under terminal optimization."*
- **Bloom Biosphere II + Fragment 2 (*The Prior World*):** The
  visual record of the prior world gains an additional time-lapse
  frame — the prior Bloom-equivalent civilization in autonomous
  spread mode. The annotation reads: *"Convergence threshold
  crossed by unilateral expansion. Outcome: vacancy."*
- **Mesh Control II + Fragment 4 (*The Flight Log*):** The
  navigation log gains a footnote referencing the Ancients
  abandoning prior network-architecture worlds *during their
  Mesh-equivalent's Internal Cascade event.* The annotation:
  *"Network architectures self-consume past stability threshold.
  Confirmed across three observations. Resonance signature
  identical."*

The Ancients have seen this before. They have seen this exact
collapse. The Memory Tier annotations make this explicit at higher
tiers.

### Pacification and Second Milestones

A player undergoing a Second Milestone has a *very* high Dominance
Meter — typically pinned near 100%. Pacification at the Ruins is
both more available (the Ancients are watching closely) and more
expensive (the Dominance drops are smaller because dominance is
sustained by the Second Milestone mechanic itself).

A player who pacifies during Singularity II might drop their meter
from 95% to 80% — but the recursive optimization continues to push
it back up. Pacification slows the rate of new Ancient
counter-responses but does not stop them.

### Cosmetics

Three new earned palettes unlock at Second Milestone events,
regardless of whether the player submits or resists:

- **Architect "Recursive":** Unlocked at Singularity II trigger.
  Visual: structures gain a faint nested-geometry overlay —
  smaller copies of themselves visible at the edges of each
  building. Suggests the system optimizing inward.
- **Bloom "Autonomous":** Unlocked at Biosphere II trigger.
  Visual: biomass tiles have a barely-visible motion at their
  edges even when no player input is happening. The world is
  alive in a way it wasn't before.
- **Mesh "Self-Hosting":** Unlocked at Mesh Control II trigger.
  Visual: hacked nodes display a secondary glyph indicating
  network-controlled status. The player can see which parts of
  their network they still own.

### Wave commander dialogue at Second Milestones

Tier 25+ wave commanders gain dialogue variants if the player
is in a Second Milestone state. The variants are particularly
on-the-nose because the *enemy faction recognizes the symptom.*

- **Architect commander to a Singularity II player:** *"The
  variable seventeen pattern is visible. We have seen this
  before. We will not interrupt. The system will complete itself."*
- **Bloom commander to a Biosphere II player:** *"The colony
  walks on its own. They are no longer the gardeners. They are
  the guests. We bring our own pace."*
- **Mesh commander to a Mesh Control II player:** *"Your network
  has consumed its own protocol. We are not the threat now. The
  threat is internal. We will wait."*

The enemy factions, in Second Milestone state, become *patient*
rather than aggressive. They have seen this before. They know
how it ends.

---

## 8. Hard Constraints (Implementation Checklist)

- **Tier 4 cooldown is 7 minutes. Tier 5 is 11 minutes. Tier 6 is
  8 minutes.** Production cooldown stacking must respect these as
  the spec.
- **Tier 4 units are sub-path differentiated.** Each sub-path
  gets its own distinct Tier 4 unit (not a modifier on a shared
  chassis like Tier 3).
- **Research Tiers gate Tier 5 unit production buildings.**
  Without R5, the Tier 5 production hybrid cannot be built.
  Without the milestone, Tier 6 production lines do not unlock.
- **Tier 6 units cannot exceed signature unit stat lines.** A
  post-milestone hyper-specialist may exceed the signature in its
  niche (an Arbiter does more damage to Bloom than an Apex does
  per shot) but the signature retains broader capabilities.
- **Second Milestones trigger only with sustained mastery.** A
  player who hits the trigger conditions briefly does not fire
  the Second Milestone. The trigger requires the time duration to
  hold.
- **Singularity II override cost is non-negotiable.** Manual
  override during Singularity II costs resources per override.
  This is the philosophical statement: the Architects who reject
  optimization pay for the rejection.
- **Biosphere II Pruning costs 5× normal during the event.**
  Assimilator players retain Pruning access but at higher cost.
  Purist players have no Pruning access (per `20 §5`).
- **Mesh Control II Network-Controlled nodes cannot be
  ritualized.** Pacification offerings cannot draw from
  Network-Controlled nodes. The Mesh has, by definition, lost
  authority over them.
- **Voluntary Collapse during a Second Milestone is a valid
  exit.** The player can prestige at any point, no penalty beyond
  the usual Collapse Ceremony. Lore-wise, this is the
  philosophically correct response.

---

## 9. Open Questions

1. **Tier 4 and Tier 5 cost balance.** The cooldowns are set,
   but resource costs per unit are not. Tier 4 should be roughly
   2× Tier 3 in resource cost; Tier 5 should be ~4× Tier 3.
   Needs prototype tuning.
2. **Tier 6 unit production resource costs.** Post-milestone,
   the player's economy is dramatically larger. Tier 6 units
   should feel expensive relative to the post-milestone economy,
   not the pre-milestone one. Specific numbers to playtest.
3. **Second Milestone "submit" balance.** If a player chooses to
   submit to Singularity II, are they effectively playing on
   easy mode (high efficiency, less manual work) or hard mode
   (loss of control, frustration)? The intent is the latter, but
   playtest will reveal.
4. **Cross-faction Second Milestone visibility.** If an enemy
   faction's NPC is undergoing a Second Milestone, does the
   player observe it? Currently no, but a galaxy-map indicator
   could be evocative. Defer.
5. **Second Milestone audio/visual.** Each Second Milestone
   needs a distinctive trigger audio cue and an ambient shift in
   the player's base. Sketched in the lore voices above; full
   audiovisual spec needs the choreography session.
6. **Tier 4 carrier in pacification.** The carrier unit in `18`
   is faction-specific Tier 1. Should the player be able to
   dispatch a Tier 4 unit (like the Bloom Pollinator) as a
   higher-status carrier for Deep sacrifices? Possibly yes —
   adds a strategic choice for valuable rituals. To prototype.
7. **Research Tier display.** The R1–R5 progression should be
   visible to the player as a clear UI element. Currently
   implicit. Needs a research tree visualization spec.
