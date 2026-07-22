# Units, Maps, and Buildings — Faction Rosters and Standard Map Spec

> Session 6 output. Specifies the unit roster (Tier 1–3 plus two milestone
> signature units), the building set (production + defense), and the standard
> procedural map layout for all three playable factions. Every design choice
> is downstream of the loop identities and sub-path commitments already
> established in `10_faction-lore.md`, the wave pressure model in
> `10_faction-lore.md §9b`, and the first-session flow in `16_first-session-flow.md`.

---

## 0. Design Premise

The roster has to do three jobs at once because the game has three layers:

1. **Idle.** Buildings produce resources offline. The roster has to be
   readable in resource terms — a player returning after eight hours should
   instantly understand what their base did while they were away.
2. **Tower defense.** Defensive structures auto-engage waves with
   faction-specific targeting logic. The roster has to telegraph priority:
   what does an Architect tower hit first, and why is that *Architect*?
3. **Active RTS.** Defensive structures double as production facilities.
   Units produced during a wave push back, flank, raid. Each unit needs a
   clear active-mode purpose distinct from its passive-mode contribution.

This rules out one common RTS shortcut: the "generalist meat unit" that
exists to fill a number in a damage equation. Every unit on the roster
must mean something. Three tiers per faction, two milestone signatures
per faction (one per sub-path) — eleven distinct units per faction, total
thirty-three across the playable roster.

Buildings follow the same rule. Production structures aren't background
infrastructure; they're the faction's economic philosophy made concrete.
Architect refineries compound. Bloom pools spread. Mesh taps siphon. You
should be able to look at a screenshot of a base and know which faction
built it without seeing a single unit.

---

## 1. The Universal Roster Pattern

All three factions share a structural skeleton. The flavor is everything,
but the skeleton is consistent so the player can transfer mental models
between factions on replay.

| Tier | Cooldown | Role | When it matters |
|---|---|---|---|
| Tier 1 | 30 sec | Light / fodder / harasser | Waves 1–10. Cheap, plentiful. Teaches active play. |
| Tier 2 | 90 sec | Mid generalist / durable | Waves 8–25. The workhorse. Survives long enough to matter. |
| Tier 3 | 4 min | Heavy anchor / specialist | Waves 20+. Expensive. Rarely lost. Defines mid-game posture. |
| Milestone | 15 min | Signature unit | Post-milestone. Faction-defining capability. Sub-path specific. |

Tier 1 is shared across sub-paths. Tier 2 is the **sub-path commit point**
in mechanics: the unit itself is the same, but two of its modifier slots
are locked by sub-path choice. Tier 3 is sub-path-flavored — same chassis,
different specialization. Milestone units are entirely distinct between
sub-paths.

This means a player who switches sub-paths between prestige runs is not
re-learning the roster — they're re-tuning it. That's the right friction.

---

## 2. The Architects — Roster

### Tier 1: **Drone**
A small flying probe with a low-power auto-rifle. Cheap, fast, fragile.
Twenty-five of them are not a stack; they are a *swarm with a spreadsheet.*

- **Active mode:** Scout the map. Drones don't take resource nodes; they
  *survey* them, briefly improving the production rate of an adjacent
  Architect building for sixty seconds. This is the Architect promise in
  a single unit: even your fodder makes things compound.
- **Passive mode (when produced from a Sentry Spire):** Patrols a short
  loop around the spire. Engages anything that crosses the path. Dies fast.
  Buys the Auger-Walker behind it three more seconds.
- **Lore:** Repurposed delivery drone. Manufacturing log lists it as
  "Asset Class C-7, multipurpose."

### Tier 2: **Auger-Walker**
A bipedal walker carrying a plasma carbine. Mid-range, durable, the
faction's calm middle voice. Slow but reliable.

- **Compounder trait — Self-Calibration:** While within range of a
  friendly production building, the Auger-Walker regenerates 1% HP per
  second and gains +5% damage. The Architect believes a unit standing
  next to its factory is performing better, and the game agrees.
- **Sub-path branch — Tier 2 commit:** Standard Augers are armored heavier
  (HP-leaning). Spiritual-Tech Augers carry a secondary terrain-coupling
  pylon that buffs the next adjacent Auger by +10% damage when both stand
  on the same natural terrain feature. Sub-path commits a slot here.

### Tier 3: **Compiler**
A long-range artillery platform on tracks. Slow. Must deploy before firing.
Devastating against the wave's primary axis from across the map.

- **Cascade Optimization:** Every enemy killed by a Compiler refunds 4%
  of that enemy's wave reward immediately. Kills compound; the Compiler
  is the unit that proves the multiplicative economy is real.
- **Vulnerability:** The Compiler is the Architect's most expensive
  unit before the milestone, and it's the one Mesh raiders will go
  for first. A player who has lost a Compiler will not lose another.

### Milestone (Standard): **Apex**
The singularity-class weapon. There is no fixed maximum.

- **Recursive Optimization:** The Apex gains +1% damage per ten seconds
  active in a wave. There is no cap. It is the only unit in the game
  whose stat line is not bounded.
- **Once-per-cycle:** Can fire a "Compile Cascade" that simultaneously
  damages every enemy on the primary axis. Costs the Apex 30% of its
  current HP. Architects measure power output, not life.
- **Lore:** Magistrate Vell's commander dialogue references "Apex
  recursion variance" by wave 30. The player understands what it means
  the first time their own Apex doesn't stop scaling.

### Milestone (Spiritual-Tech): **Warden**
Immobile. Bound to one terrain feature for the rest of its existence.
Devastating in the right spot, useless in the wrong one.

- **Ley Bond:** The Warden must be placed on a natural terrain feature
  (water, high ground, forest tile, or — rarest — a ley node tile that
  the map occasionally generates near Ancient Ruins). Its damage scales
  with the number of adjacent natural tiles.
- **Ley Field:** All friendly units within a generous radius gain +25%
  damage. The Warden is a force multiplier first, a damage dealer second.
- **Vulnerability:** Cannot move. If the wave's secondary axis breaks
  through and reaches the Warden, the loss is total.
- **Lore framing:** The Spiritual-Tech Architects regard the Warden as
  *the structure that knew it was a structure.* This is heresy and is
  treated as such by Standard Architect wave commanders.

### Architect roster expression in play

A player running Standard Architects fields a small number of expensive
units, all of them moving toward the player's choice of axis. The base
looks orderly. The cooldowns are staggered to keep production flowing.
Wave commanders who attack this player — particularly Architect-on-
Architect wave commanders post-milestone — speak with contempt for the
sub-path the player did not choose.

A Spiritual-Tech player's base looks different from orbit: it hugs the
terrain. Buildings cluster on ridgelines and along water. The Warden
sits at a chokepoint that the player has shaped the rest of the base
around. The Standard Architect player is building a factory. The
Spiritual-Tech player is building a fortress *that grew there.*

---

## 3. The Architects — Buildings

The Architect building set is a pure multiplicative economy in
architecture form. Every building's stated effect is local; every
building's *real* effect is to amplify everything next to it.

### Production buildings

| Building | Tier | Function | Adjacency / compounder effect |
|---|---|---|---|
| Refinery | T1 | Base resource extractor on a node | None alone. Two adjacent Refineries gain +10% each. |
| Foundry | T2 | Converts ore to alloy (mid-tier resource) | +5% per adjacent Refinery. Stacks. |
| Reactor | T3 | Generates power; passive +20% to all adjacent buildings | Has a hard cap on adjacencies (4) to prevent runaway. |

The compounder math is intentional. A Standard Architect base with four
Refineries around a Foundry around a Reactor produces more than the sum
of its parts by a wide margin. This is where the "given uninterrupted
time, they outproduce the planet" promise lives.

### Defensive / production hybrids

| Building | Tier | Tower role | Produces | Cooldown |
|---|---|---|---|---|
| Sentry Spire | T1 | Auto-rifle, prioritizes nearest threat | Drone | 30s |
| Plasma Bastion | T2 | Heavy plasma cannon, prioritizes high-HP targets | Auger-Walker | 90s |
| Siege Foundry | T3 | Long-range, prioritizes structures (yes — it can fire on enemy wave spawners that have entered the map) | Compiler | 4min |
| Nexus Core | Milestone (Standard) | No direct combat function; broadcasts +50% production to all buildings on map | Apex | 15min |
| Ley-Spire | Milestone (Spiritual-Tech) | No direct combat function; broadcasts Ley Field aura to all terrain-adjacent buildings | Warden | 15min |

**Targeting logic** (the part that makes a tower feel *Architect*):
Architect towers prioritize **threat to the production chain** above all
else. A Bloom Mire-Beast walking toward a Refinery will draw Architect
fire over a closer but lower-tier target. This is the faction's
defensive personality made literal.

---

## 4. The Bloom — Roster

### Tier 1: **Sporeling**
The Bloom does not produce a single unit per cooldown. It produces a
*cohort* — five Sporelings per 30-second cycle, each individually weak,
collectively a tide.

- **Active mode:** Move as a loose pack. Latch onto enemies with corrosive
  bites, modest per-unit damage, significant total. When a Sporeling dies,
  it leaves a small toxic biomass tile that damages enemies who walk over
  it and is impassable to siege equipment.
- **Adaptation trigger — Cohort Memory:** If a Sporeling cohort takes
  significant damage from one source (fire, hacking, etc.), the *next*
  cohort produced gains partial resistance to that damage type. The Bloom
  learns through casualties. The learning persists for the rest of the run.
- **Lore:** Bloom commanders refer to a recently lost cohort as "the
  ones who taught us." It is not a euphemism.

### Tier 2: **Bramble-Walker**
A mid-sized plant-creature that walks on four root-legs and attacks with
whip-tendrils. Melee. Durable. Patient.

- **Cellular Regeneration:** Regenerates 2% HP per second when stationary.
  Bloom players quickly learn to position Bramble-Walkers as a holding
  line rather than a charging spearhead.
- **Sub-path branch — Tier 2 commit:**
  - *Purist:* Bramble-Walkers grow secondary tendril attacks against
    aerial targets (the Bloom answer to Architect Drones).
  - *Assimilator:* Bramble-Walkers gain a digestion claw — they can
    consume a fallen enemy corpse (any faction's) within 5 seconds to
    refund 10% of their own cost as biomass.
- **Adaptation trigger:** Survives an encounter with a damage type
  it has not seen — next Bramble-Walker spawned has +15% resistance to
  that type.

### Tier 3: **Mire-Beast**
A massive bio-tank. Slow, lumbering, biome-shaping. Where it walks,
biomass tiles spread.

- **Terraforming Footsteps:** Each tile the Mire-Beast crosses converts
  to Bloom biomass after 8 seconds. Bloom biomass tiles slow non-Bloom
  units by 15% and boost adjacent Bloom production by 5%. The Mire-Beast
  is, mechanically, a slow-walking map control tool that also happens
  to be a tank.
- **Adaptive Hide:** Every Mire-Beast logs its damage intake. The *next*
  Mire-Beast produced spawns with a permanent +20% resistance to the
  top damage source. The faction is learning across generations.
- **Status immunity:** Immune to slow, stun, and hack effects. Its body
  has seen those before.

### Milestone (Purist): **Bio-Titan**
The Mother-Spire's first child. Colossal. Living siege beast.

- **Spawning:** While alive, continuously produces Sporeling cohorts at
  half-rate from its own body. It is a mobile factory.
- **Cannot be hacked:** No mechanical components. The Mesh has no
  surface to attach to. Bloom-on-Mesh play with a Bio-Titan in the field
  is one of the most lopsided matchups in the game.
- **Footstep damage:** Structures in the Bio-Titan's path take significant
  damage from its weight. Architect bases fall in *seconds* when it
  reaches them.

### Milestone (Assimilator): **Chimera**
A modular bio-mech hybrid that consumes the dead to update its loadout.

- **Component Digestion:** When the Chimera kills (or stands within 3
  tiles of a friendly kill), it absorbs that target's primary weapon as
  one of three slots. An Architect plasma carbine, a Mesh data-fang, a
  Bloom whip-tendril — any of them.
- **Loadout slots:** Three. The Chimera fights with whatever it has most
  recently absorbed. A player who has been on the field for an hour is
  fielding a Chimera carrying tech from every faction in the game.
- **Lore:** The Bio-Titan is the Bloom's answer to "what happens when we
  grow without limit." The Chimera is the Bloom's answer to "what
  happens when we admit we are not the only kind of life." Civil-war
  energy between the two sub-paths is at its highest when both signature
  units are on the field.

### Bloom roster expression in play

A Bloom base is messy. Buildings sprawl. Biomass tiles creep across the
map without permission. Unit cooldowns produce *more* units per tick
than the other factions, but each unit is individually flimsy. The
player is managing a population, not a battalion.

The Bloom player's bad day is the first ten waves of a run. The Bloom
player's best day is wave 35 onward, when the cohort memory has stacked
six different resistance bonuses and the Mire-Beasts are immune to
everything the wave is throwing.

---

## 5. The Bloom — Buildings

The Bloom building set spreads. Every Bloom structure increases the
faction's *territory*, not just its output.

### Production buildings

| Building | Tier | Function | Spread mechanic |
|---|---|---|---|
| Spore-Pool | T1 | Biomass extractor; placed on any tile, terraforms 1 adjacent tile to biomass | Production rate scales with adjacent biomass tile count |
| Root-Network | T2 | Connects Spore-Pools; +10% production per connected Pool | A connected Pool network is a single circulatory system; one cut Pool damages all |
| Bio-Reclaimer | T3 | Converts wreckage on Bloom-controlled tiles into biomass | Most valuable late-game when the map is dotted with dead Mesh nodes |

The Bloom economy gets exponentially stronger as biomass coverage
increases. This is the **Biosphere milestone** in slow motion — the
first hour of a Bloom run is building toward the second.

### Defensive / production hybrids

| Building | Tier | Tower role | Produces | Cooldown |
|---|---|---|---|---|
| Thornwall | T1 | Short-range whip; prioritizes nearest territory-spreading enemy unit | Sporeling cohort (5) | 30s |
| Spitter-Mound | T2 | Mid-range acid spitter; prioritizes ranged enemies | Bramble-Walker | 90s |
| Mire-Crucible | T3 | AoE entangling roots; slows and damages clusters | Mire-Beast | 4min |
| Mother-Spire | Milestone (Purist) | Passive aura: all Bloom units within range gain +1% HP regen | Bio-Titan | 15min |
| Crucible-Hive | Milestone (Assimilator) | Absorbs enemy wreckage in radius into biomass passively | Chimera | 15min |

**Targeting logic:** Bloom towers prioritize **territory-threatening
units** above all else. A Mesh probe that has placed a hack-node beacon
on a Bloom tile draws Thornwall fire faster than a closer high-damage
target. The Bloom defends *land,* not *resources.*

---

## 6. The Mesh — Roster

### Tier 1: **Probe**
A pencil-thin hovering chassis with a data-fang. Extremely fast,
extremely fragile, extremely impatient.

- **Data Drain:** Each melee hit drains 1% of the target's resource
  reward from the wave economy directly into the Mesh's resource pool.
  Probes don't just deal damage; they *steal.*
- **Suicide protocol:** On death, the Probe burns out the local sensor
  net, blinding nearby Architect/Bloom towers for 4 seconds. Players
  who use Probes well are using them as flankers, not skirmishers.
- **Lore:** Probe identifiers are 4-character hex strings. They are not
  named. They do not need to be.

### Tier 2: **Spike**
A ranged data-rifle platform on tripod legs. Pauses to fire. The
faction's middle voice.

- **Hack Pulse:** Spike attacks deal modest physical damage and apply a
  brief 5-second "disable" debuff to enemy structures. A Spike cannot
  kill a Compiler, but it can keep one from firing for a minute if
  positioned well.
- **Sub-path branch — Tier 2 commit:**
  - *Networked:* Spikes operate in pairs. Two Spikes within 4 tiles of
    each other gain +20% fire rate. Pure-collective ethos.
  - *Dreamer:* Spikes occasionally fire a "Memory Echo" instead of a
    normal shot — a delayed strike that hits the target's position 3
    seconds later. The dreamer Spike fights one beat in the past.

### Tier 3: **Carver**
A hovering data-vehicle with a shield breaker and a siphon array. The
Mesh's premier raid platform.

- **Data Siphon (active ability):** Channel 4 seconds on an enemy
  structure to convert it into a Hacked Node for 30 seconds. While
  hacked, the structure produces resources for the Mesh *and stops
  producing them for its owner.* This is the Mesh win condition in
  miniature: every successful Siphon is a transfer.
- **Vulnerability:** Channels are interruptible. A Carver caught
  mid-siphon by a Bramble-Walker dies in two hits.

### Milestone (Networked): **Hydra-Daemon**
Instant relocator. Teleports between any two Hacked Nodes on the map.

- **Network Jump:** Once every 8 seconds, the Hydra-Daemon can
  instantaneously relocate to any active Hacked Node. There is no
  travel time. There is no telegraph.
- **Glass cannon:** Highest DPS in the Mesh roster. Lowest HP at its
  tier. The Hydra-Daemon does not survive being caught.
- **Lore:** The Hydra-Daemon does not move. It *is* in multiple
  positions and chooses which one is real on each network tick.

### Milestone (Dreamer): **The Remembered**
A unit that fights in two layers simultaneously — present-day combat
and an overlaid memory of a past battle.

- **Two-layer existence:** The Remembered has two HP pools. Damage to
  the "present" pool reduces its body. Damage to the "memory" pool
  reduces its persistence. Both pools must be depleted for The
  Remembered to die.
- **Ancient access:** Once per wave, The Remembered surfaces an Ancient
  Fragment to the player — a short lore card that would otherwise only
  appear at prestige. Dreamer Mesh players accumulate Fragments faster
  than any other faction by a margin.
- **Lore:** Architects have argued whether The Remembered counts as
  one unit or two. The Bloom does not consider this question
  interesting. The Mesh has filed the question as a buffer overflow.

### Mesh roster expression in play

A Mesh base does not look like a base. It looks like a *distribution.*
Probes scatter across the map. Spikes lurk at vantage points. Carvers
slip into enemy territory and hack structures that the Mesh never built.
A Mesh player on wave 25 may have more enemy structures working for them
than friendly structures of their own.

When a Mesh raid succeeds, the impact is immediate: enemy production
drops audibly, the Mesh resource bar climbs visibly. When a Mesh raid
fails, the player has lost a Carver and gained nothing. Tempo is the
whole game.

---

## 7. The Mesh — Buildings

The Mesh building set is **deliberately underpowered in passive output.**
Mesh production buildings produce less than Architect or Bloom equivalents
by design. The faction is meant to *steal* the difference back.

### Production buildings

| Building | Tier | Function | Network mechanic |
|---|---|---|---|
| Tap | T1 | Base resource siphon; ~70% of Architect Refinery output | None alone |
| Sub-Router | T2 | Links Taps into a node network; passes Hacked Node income through the network | A Mesh base without a Sub-Router cannot benefit from hacked structures |
| Cold-Sink | T3 | Doubled passive output, must be placed on cold terrain (snow/water/shadow tiles) | The Mesh's premier production building is environmental |

The Mesh production economy is a triangle: Taps + Sub-Router + Hacked
Nodes elsewhere on the map. Cut any leg and the Mesh's resource flow
collapses. This is the "resource-starved if hacking is denied" weakness
in architecture.

### Defensive / production hybrids

| Building | Tier | Tower role | Produces | Cooldown |
|---|---|---|---|---|
| Snare-Node | T1 | Short-range disruptor; prioritizes nearest fast unit | Probe | 30s |
| Data-Coil | T2 | Mid-range hacking pulse; prioritizes structures over units | Spike | 90s |
| Excavator-Rig | T3 | Long-range siphon beam; prioritizes high-value enemy targets | Carver | 4min |
| Daemon-Forge | Milestone (Networked) | Doubles Hacked Node duration on map | Hydra-Daemon | 15min |
| Memory-Stack | Milestone (Dreamer) | Generates one Ancient Fragment per wave cycle | The Remembered | 15min |

**Targeting logic:** Mesh towers prioritize **highest-cost enemy
target** above all else. A Compiler is more attractive than three
Augers. A Bio-Titan is the only target on the map. This is the
"capital expenditure" intent from `10_faction-lore.md §5` in
literal targeting code.

---

## 8. Map Structure — Standard Layout Spec

All maps are procedurally generated, but the topology obeys a strict
spec. The procedural variation is in biome, resource node placement,
and terrain features. The wave-axis structure is constant — players
should never be confused about where pressure is coming from.

### Standard map topology

The map is roughly elliptical. The player's starting position is on the
long axis, near one end. The map's structure is defined by three axes:

- **Primary axis:** The long approach lane from the opposite end of the
  ellipse to the player's base. This is where the bulk of every wave
  travels. Length: 4–5 minutes of standard unit travel time. Wide
  enough for towers to chain coverage; not so wide that a single tower
  line can cover it without gaps.
- **Secondary axis:** A shorter, angled approach lane that joins the
  primary axis roughly 60% of the way from the wave spawn to the
  player base. The secondary axis carries flank probes, raid units,
  and (at higher tiers) Bloom spore-spreaders that want to drop biomass
  on player territory rather than fight through the primary.
- **Tertiary points:** Two to four irregular incursion sites scattered
  off-axis. These activate rarely (Ancient pulses, named commander
  arrivals, cross-faction surprise alliances). The player does not
  build to defend tertiary points by default; tertiary events are
  meant to surprise.

### Resource node distribution

- **Safe zone (player base):** 3 resource nodes. Always reachable
  without crossing either wave axis. Enough income to start.
- **Inner contested:** 2–3 resource nodes between the player base and
  the secondary axis convergence point. The bulk of mid-game economy
  comes from these — they are defensible but not free.
- **Outer contested:** 3–5 resource nodes between the secondary axis
  convergence point and the wave spawn. These are dangerous to hold
  and dramatically rewarding when held. Mesh players who hack a Bloom
  Spore-Pool on an outer node are operating exactly where the faction
  wants to operate.

### Ruins placement

The Ancient Ruins always appear on the **map edge**, never on a wave
axis, and never within the player's safe zone. They are visible from
wave 1 and inert until the player's first milestone.

- **Single-Ruins map (default, ~88% of generations):** One Ruins site
  on the map edge, biased toward the secondary axis side. This makes
  the Ruins a *peripheral curiosity* during early gameplay — a player
  who scouts toward the Ruins is naturally exploring near where flank
  pressure will eventually come from.
- **Dual-Ruins map (~12% of generations):** Two Ruins sites on opposite
  map edges. Rare and meaningful. Both pulse at milestone. The Ancient
  unit may appear at either or both. Players who see a Dual-Ruins map
  for the first time should be told nothing; the wrongness should be
  felt.
- **Ley node tiles:** Generated in clusters near Ruins, at a density
  proportional to the Ruins' importance on the map. Spiritual-Tech
  Architects who place a Warden on a ley node tile near a Ruins site
  get the strongest stat line in the game — and the lore reason is
  not lost on anyone.

### Wave behavior on the standard map

- Waves spawn at the long-axis terminus opposite the player base.
- Primary axis pressure is roughly 70–80% of the wave's mass.
- Secondary axis probes carry 15–25% of the mass, faction-mixed at
  wave tier 11+.
- Tertiary events fire on average 1 in 8 waves; they are not balanced
  to be optional. A player who has not built any tertiary defense
  cushions will be punished by tertiary events eventually.

---

## 9. Biome Modifiers per Sub-Path

The procedural map generator picks a biome at run start. Biome affects
visual presentation, ambient pulse, and — crucially — sub-path
performance. The same map biome is **not always favorable to the
player's sub-path.** A Spiritual-Tech Architect dropped on Open Plains
is in a worse position than a Standard Architect on the same map. This
is intentional. It is also where the Defector/Cooperator galaxy layer
(`11_galaxy-politics.md`) starts to matter: the player can choose to
expand toward biomes that favor their sub-path, or stay generalist.

| Biome | Visual signature | Favors | Penalizes |
|---|---|---|---|
| **Open Plains** | Wide flat grass; minimal terrain features | Standard Architects (no terrain dependency); long Compiler sightlines | Spiritual-Tech Architects (no terrain to bond with); Purist Bloom (slower biomass spread on dry soil) |
| **Boreal Forest** | Dense conifer canopy; ridgelines; cold streams | Spiritual-Tech Architects (+12–18% adjacency to forest tiles); Purist Bloom (biomass spreads 1.5× normal rate) | Networked Mesh (canopy disrupts node line-of-sight) |
| **Wetlands** | Marsh, shallow water, scattered islands | Purist Bloom (saturated soil = max biomass rate); Standard Architects with water-adjacency Refineries | Networked Mesh (water disrupts signal); Dreamer Mesh moderately (subsonic doesn't carry well through wet ground) |
| **Ruined Cityscape** | Pre-collapse industrial infrastructure; concrete; rebar | Networked Mesh (existing tech to hack — Carver targets pre-placed on the map); Assimilator Bloom (inorganic components to absorb) | Purist Bloom (sterile concrete blocks biomass spread); Standard Architects neutral |
| **Volcanic / Tectonic** | Active geothermal features; tectonic fissures; ash | Dreamer Mesh (subsonic harmonics from tectonics align with memory pulses, generating Fragments 2× rate); Standard Architects with high-thermal Reactors | Purist Bloom (sterile volcanic soil); Spiritual-Tech Architects partially (unstable ley nodes) |
| **Snowfield / Cold Desert** | White expanse; minimal cover; cold | Networked Mesh (Cold-Sinks at 1.5× output); Assimilator Bloom (less competition to absorb) | Purist Bloom (slow biomass growth); Standard Architects neutral |
| **Ruin-Adjacent (rare)** | Heavy concentration of Ancient ley node tiles; dark stone outcroppings | Spiritual-Tech Architects (Warden at peak power); Dreamer Mesh (Fragment generation accelerated) | Standard Architects mildly (efficiency tree gets no bonus from terrain it cannot model) |

Players who scout the map at start should be able to read the biome and
adjust their sub-path commitment accordingly. A player who has already
committed to Spiritual-Tech and drops onto Open Plains is in a harder
run — that is a known and intentional risk of the heresy paths.

---

## 10. Cross-Faction Asymmetry Check

Quick sanity pass that the rosters honor the loop identities:

| Identity claim | Roster expression |
|---|---|
| Architects are slow-ramp, multiplicative, brittle | Refinery → Foundry → Reactor compounding chain; Drones buff adjacent production; Compiler refunds wave rewards; Mesh raiders break the chain in a way that is *legibly catastrophic* |
| Architects' weakness is burst raid | Compiler is single most expensive pre-milestone target; one Carver Siphon can disable the Reactor that powers an entire wing |
| Bloom is slow, then unstoppable | Sporelings are *cohorts,* not units; Bramble-Walker regen; Mire-Beast adaptive hide stacks across deaths; Bio-Titan is a self-producing factory |
| Bloom's weakness is the first 5–8 waves | T1 Sporelings have low individual HP; no panic-button defenses available before T2; the wave 3 flank collapse from `16_first-session-flow.md` is felt harder by Bloom than the others |
| Mesh has the weakest passive economy | Mesh Taps explicitly produce 70% of Architect Refinery output; Cold-Sink is environmental, not freely placeable |
| Mesh wins on tempo and theft | Probe Data Drain steals from wave reward; Carver Siphon converts enemy structures; Hydra-Daemon teleports across the map via Hacked Nodes; Mesh towers prioritize highest-cost target |

Each weakness is mechanical, not flavor. Each strength is mechanical,
not flavor. The factions are not playing the same game with different
sprites; they are playing three games on the same map.

---

## 11. Hard Constraints (Implementation Checklist)

- **Sub-path commit is at Tier 2.** Tier 1 is always shared. Players
  who skip Tier 2 entirely (rare but possible builds) commit at Tier 3.
- **Milestone signature units are 15-minute cooldown, hard.** Cooldown
  runs offline. A player logs out with milestone production cycling
  will return to a signature unit waiting.
- **Architect compounding is local-only, never global.** Adjacency
  bonuses must stop at the building's footprint. No "global +10%
  Architect production" stat exists until the Nexus Core milestone.
- **Bloom Sporeling cohorts are 5 per produce cycle.** Not configurable.
  The cohort identity is the unit identity.
- **Mesh Hacked Nodes have a hard cap of 5 active simultaneously.**
  This is the same number as the Mesh milestone (`10_faction-lore.md §3`).
  Hitting the cap is the milestone trigger; below the cap is the
  faction's normal operating range.
- **Ruins placement is map-edge, never axis-aligned, never in safe
  zone.** Dual-Ruins maps are ~12% generation rate, no announcement.
- **Towers double as production buildings without exception.** A
  building that fires on enemies also produces units. No standalone
  production buildings, no standalone defense buildings. This is the
  three-layer architecture's load-bearing rule.
- **Biome modifiers must surface in the UI on map scout.** A player
  should see biome name + "Favors: Standard Architects" before
  committing a sub-path. The Academy can refuse this information to
  the unsorted Dreamer-path player as part of the harder start.

---

## 12. Open Questions for the Next Pass

1. **Cross-sub-path unit interactions.** What happens when an Assimilator
   Bloom Chimera absorbs a Spiritual-Tech Warden's terrain-coupling
   pylon? The mechanic is suggestive of Option B leakage; the tuning is
   not specified. Test in playtest.
2. **Hacked Node cap interaction with sub-paths.** Networked Mesh
   benefits from the 5-cap. Dreamer Mesh might benefit from a 3-cap
   instead, with the 2 freed slots reserved for "Memory Nodes" that
   generate Fragments. This is a balance question that needs a
   prototype.
3. **Bio-Titan vs. Apex matchup.** The two strongest milestone units
   exist on a continuum — Apex scales without limit, Bio-Titan is
   functionally unkillable to most of the game's weapons. Do they
   meet, and what happens if they do? This is the question that
   determines whether the late-game has counterplay or attrition.
4. **Tertiary axis frequency on Dual-Ruins maps.** The dual-Ruins
   generation already produces one of the strangest maps in the pool.
   Should tertiary events fire more frequently when both Ruins are
   present? This affects pacing more than it affects mechanics.
5. **Production building placement on tertiary points.** Should the
   game allow players to fortify tertiary incursion points proactively?
   Or does that defeat the surprise design? Probably let them, but
   make tertiary point construction expensive enough that only late-
   game players bother.
