# Faction Lore — Answers to the OpenLama Design Questions

> Working doc that extends `Cowork_Faction_Lore_Brief.md` and the prior
> `Game design ideas.md` pass. Builds on, rather than replaces, the four
> in-voice profiles already established for **The Architect**, **The Bloom**,
> **The Mesh**, and **The Ancients**.

> **Design pivot — 2026-05-10:** ULBFF V3 (large-scale traditional RTS
> simulator) is retired. Beyond-All-Reason satisfies that vision externally.
> This project is now committed to an **Idle-Miner / Tower Defense / Endless
> wave hybrid** — a game format suited to a player with limited session time.
> The faction lore is IP-first and intentionally game-type-agnostic; it can
> drive this game and future titles without rework.

---

## 0. Preamble — Resolving the Structural Question (Option A vs. Option B)

The lore brief left the structural question open on purpose:

> *Were these three factions always separate civilizations (Option A),
> or are they the fractured descendants of a single origin (Option B)?*

**Resolution: Option B is the truth of the fiction; Option A is the truth of
the game state.** They are not in conflict — they reinforce each other.

The factions themselves believe Option A. Each one tells an origin story in
which it was always separate, always sovereign, always right. But three pieces
of in-brief lore quietly point to Option B:

1. **The Ancients' line.** *"They are not enemies of each other. They are
   phases of the same process."* This is not metaphor. The Ancients have
   pattern-matched this exact divergence three times before.
2. **The parallel internal heresies.** Every faction has a sub-faction that is
   *evolving back toward what the others became.*
   - Architects have a Spiritual-Tech heresy — engineering harmonized with
     terrain, *which is what the Bloom does on principle.*
   - The Bloom has an Assimilator sub-strain — biology incorporating
     inorganic components, *which is what the Mesh did to itself.*
   - The Mesh has Dreamers — old nodes replaying pre-augmentation memories,
     *which is what the Architects insist humanity should remain.*
   These are not three coincidences. They are three pieces of the same
   civilization remembering itself under stress.
3. **The Mesh dream logs.** An Ancient memory fragment is embedded in a
   recovered node. That memory is not the Mesh's. It is older — old enough to
   predate the schism. The Mesh has been touching the shared past every
   low-activity cycle and classifying it as a buffer overflow.

This produces a clean dual structure for the game:

| Layer | Treats factions as | Why |
|---|---|---|
| **Mechanics / Balance** | Option A — three peer factions | Asymmetry is the design space; cleaner balance; supports multiplayer |
| **Narrative / Endless Arc** | Option B — fractured kin | The reveal earns the play hours; rewards multi-faction replay |

The endless-mode story arc, then, is the gradual exposure of Option B to a
player who started in Option A. Each faction's campaign uncovers a different
**Ancient Fragment** that, only when assembled across multiple playthroughs,
spells out the shared origin. *You have been fighting yourself* is the
late-game realization, and it is delivered by play, not cutscene.

This also answers a balance question before it's asked: factions can borrow
late-game abilities from each other because, lore-wise, they *used to be each
other.* The Architect's Spiritual-Tech path, the Bloom's Assimilator strain,
and the Mesh's Dreamer cells are not arbitrary tech-tree options — they are
the seams of Option B showing through the Option A surface.

---

## 1. Core Values and Playstyles per Faction

The playstyle for each faction is downstream of its philosophy. The lore
voice is the playstyle.

### The Architects — *Advanced Technology*

- **Core value:** Progress is law. Efficiency is virtue. Emotion is noise.
- **Loop identity:** *The Compounders.* Their economy is multiplicative —
  every upgrade improves the rate at which future upgrades arrive. The idle
  loop is strongest here; offline production compounds.
- **Early game:** Slow. Cautious. Visible long buildouts before payoff.
- **Mid game:** Acceleration. The factory of factories starts shipping.
- **Late game:** Singularity-class units that out-tier anything else on the
  map by a generation.
- **Strength:** Given uninterrupted time, they outproduce the planet.
- **Weakness:** Brittle. Their networks have no redundancy by design — they
  consider redundancy *waste*. A well-timed Mesh raid can collapse a
  multi-hour buildout in 90 seconds.
- **Voice rule (for commander dialogue):** Speak in passive constructions
  and engineering terms. Never raise volume. *"Variable seventeen is
  overperforming. Correcting."*

### The Bloom — *Biological-Technology*

- **Core value:** Adaptation. Diversity. Cyclical time.
- **Loop identity:** *The Adapters.* Units and structures *evolve* in response
  to what damages them. A unit killed by fire respawns flame-resistant. A
  base hit by Mesh raids regrows with anti-hack countermeasures.
- **Early game:** Genuinely fragile. The first 5–8 waves are the most
  dangerous window — they haven't had time to be hurt yet.
- **Mid game:** Power inflection. Biomass spreads as both economy and
  area-denial; territory itself becomes a weapon.
- **Late game:** Near-unkillable. Mature Bloom forests resist most damage
  types because they've *seen* most damage types.
- **Strength:** Sustained-pressure inevitability. The longer the fight, the
  more the Bloom wins it.
- **Weakness:** Burst damage and unfamiliar damage types. New threats hurt
  before adaptation triggers.
- **Voice rule:** Patient cadence. Organic metaphors. No urgency, ever.
  *"You are kindling. We have been here for centuries. We will be here when
  the fire is over."*

### The Mesh — *Cyber-punk Borg*

- **Core value:** Everything is a system. Every system has an exploit.
- **Loop identity:** *The Raiders.* The Mesh has the weakest passive
  economy on purpose — they are designed to steal. Hacking enemy structures
  diverts that enemy's resource stream into the Mesh's own.
- **Early game:** Fast. Aggressive. Fragile. Their first 10 minutes look
  like a kid with a slingshot picking fights with two giants.
- **Mid game:** A web of hacked nodes inside enemy territory. They are
  fighting on someone else's economy.
- **Late game:** Network cascade. They don't beat the other factions —
  they *become* the bandwidth those factions need to function.
- **Strength:** Tempo. Information dominance. One precise raid can cripple a
  faction's late-game tech path.
- **Weakness:** Resource-starved if hacking is denied. Paper defenses.
  Visible nodes are kill-on-sight.
- **Voice rule:** Fragments. Present tense. Hard pivots. *"You built a door.
  We built a key. You built a stronger door. We are inside the lock now."*

These three loops are deliberately incompatible. Architects want the game
to be slow; Bloom wants it to be long; Mesh wants it to be loud. The wave
system (§5) plays them against the player at angles they can't fully
defend.

---

## 2. Sub-Paths Within Each Faction — Not Cosmetic, Mechanically Distinct

The OpenLama question framed sub-paths as "cosmetic." That framing is wrong
for this game. **The internal heresies named in the lore brief are
load-bearing.** They are also where Option B leaks into Option A.

Each faction gets a Standard path and a Heresy path. The player commits to
one around Tier 2 (mid-game). The Heresy path is weaker on average but
unlocks late-game synergies the Standard path can't reach — and it carries
narrative weight, because choosing the heresy is the player partially
accepting that their faction is not as separate as it claims.

### Architects: Standard vs. Spiritual-Tech

| Standard | Spiritual-Tech (Heresy) |
|---|---|
| Pure optimization tree | Terrain-harmonics tree |
| No terrain dependency | +12–18% efficiency on buildings adjacent to natural features (water, high ground, forest tiles) — the exact number quietly admitted in the lore brief |
| Highest tech ceiling | Lower ceiling, lower floor variance |
| Brittle | More resilient because power draws are distributed |
| Signature unit: **Apex** — late-game singularity weapon | Signature unit: **Warden** — terrain-bound guardian construct, draws power from ley lines, immobile but devastating in chokepoints |

**Lore hook:** Choosing Spiritual-Tech publicly declares the heresy. NPC
Architect commanders in waves will speak of you with contempt.

### The Bloom: Purist vs. Assimilator

| Purist | Assimilator (Heresy) |
|---|---|
| Fully organic — no inorganic incorporation | Absorbs and integrates inorganic components from destroyed enemy units |
| Faster evolution rate | Slower evolution but broader adaptation library |
| Strong against Mesh (no tech to hack) | Strong against everything once mature — adapts faster than the others can specialize |
| Signature unit: **Mother-Spire** — central biomass propagator | Signature unit: **Chimera** — modular bio-mech hybrid that swaps weapons mid-fight by digesting and re-extruding components from kills |

**Lore hook:** Purists treat Assimilators as contaminated. Wave commanders
from a Bloom faction with the opposite path will *target the player Bloom
first* — civil war energy.

### The Mesh: Networked vs. Dreamers

| Networked | Dreamer (Heresy) |
|---|---|
| Pure-collective: individual nodes have no identity | Old nodes retain pre-augmentation memory fragments |
| Fastest tempo, most aggressive | Slower tempo but unique abilities sourced from dream logs |
| Network cascade endgame | "Recall" endgame — Dreamers can reconstruct lost capabilities, including capabilities the Mesh doesn't officially have yet |
| Signature unit: **Hydra-Daemon** — instantaneously relocates between hacked nodes | Signature unit: **The Remembered** — a unit that fights in two layers: present-day combat and an overlaid memory of a past battle. Cannot be killed until both layers are resolved |

**Lore hook:** Dreamers are how the Ancients' fragments are *first surfaced
to the player.* If you play Mesh-Dreamer, you get the most direct exposure
to the Option B reveal. This is the lore-curious player's path.

### Why these sub-paths matter structurally

The three heresy paths — Spiritual-Tech, Assimilator, Dreamer — are each
one step toward another faction. They are the seams of Option B made
visible. A player who unlocks all three across multiple campaigns sees
the convergence pattern. That is the meta-narrative.

---

## 3. Faction Goals and Milestones (Endless Mode Has No "Win")

The previous design pass got this right: there are no hard win states in an
endless RTS-idle hybrid. There are **milestones** — moments of arrival that
escalate everything. The milestone is also a *philosophical statement*: it
is the faction proving its worldview can be made real.

| Faction | Milestone | Trigger | Lore framing | Mechanical consequence |
|---|---|---|---|---|
| Architects | **Singularity** | Complete Tier 5 research chain + build the Nexus Core | "Efficiency has reached its terminal condition. The system can now optimize itself." | Wave intensity doubles. Ancients activate. Tier 6 unlocked. |
| Bloom | **Biosphere** | Biomass covers 60% of the map | "We have become the world. The world cannot lose to itself." | Hybrid evolution units unlock. Environmental hazards (toxic blooms, root-quakes) become available. Ancients activate. |
| Mesh | **Mesh Control** | Hack and hold 5 enemy command nodes simultaneously for 60 seconds | "The walled garden has doors now. We are the doors." | Network cascade ability — for 30 seconds, captured enemy waves attack their parent faction. Ancients activate. |

Each milestone fires the same narrative event from a different angle: the
Ancients *notice you.* Up until that moment they have been atmospheric.
After it, they are present.

A second milestone (post-prestige) for each faction reveals the *cost* of
its philosophy:

- Architect Singularity II: the system becomes recursive and starts
  optimizing the player's own production *toward the Singularity goal,*
  forcing the player to fight their own efficiency.
- Bloom Biosphere II: the Bloom begins reproducing without the player's
  input. The player has to decide whether to prune themselves.
- Mesh Control II: the Mesh's hacked nodes start hacking each other. You
  fight a civil war inside your own network.

These second-tier milestones are how the game admits, mechanically, that
each faction's philosophy contains the seed of its own collapse.

---

## 4. The Ancients — Not Playable, Not Allied, Not Quite Hostile

The lore brief was specific: the Ancients are *not* arguing with the other
three. They are *watching to see if the contents survive being poured.*
Build the alien faction around that posture.

### Design role

- **Not playable** — they are the planet's gravity, not a competitor.
- **Not allied** — but pacifiable. Sacrifice-of-resources rituals at
  Ancient Ruins buy you a wave or two of non-aggression.
- **Reactive** — they target the *leading* faction's mechanic, not the
  player specifically. If you are losing, they back off. If you are
  dominating, they intervene.
- **Counter-spec:**
  - vs. Architect dominance → emit a *Null Field* that disables production
    multipliers in an area
  - vs. Bloom dominance → emit a *Sterility Pulse* that pauses biomass
    spread and evolution triggers
  - vs. Mesh dominance → broadcast a *Signal Drown* that breaks hacked
    connections and reverts captured nodes
- **They speak rarely.** When an Ancient unit appears, time briefly
  desaturates. They deliver one line. Then they act.

### What the Ancients are actually doing

This is the late-game reveal, paced across a full playthrough:

1. **Early atmosphere:** Ruins are visible but inert from wave 1. The
   player walks past them.
2. **First milestone:** The Ruins activate. Ancients appear. They do not
   speak yet.
3. **Mid prestige cycles:** Each prestige, an Ancient unit drops a
   **Fragment** — a small lore artifact that hints at what is coming.
4. **Late game (after multiple prestiges):** The Ancients begin to
   *teach.* They will, on rare conditions, gift the player a sub-path
   ability the player did not unlock — because the Ancients have decided
   the player's faction is the right *vessel.*
5. **Endgame revelation:** What the Ancients have been preparing for is
   not the player. It is *the next thing*, the one that ended the other
   three worlds. The Ancients fled here because this world's three
   factions are an experiment they could not run at home — a controlled
   test of whether civilization can survive the convergence.

### Ruins

The Ancients built the Ruins. Each faction interprets them differently:

- Architects say they are *abandoned infrastructure.*
- The Bloom says they are *old growth — petrified, but still rooted.*
- The Mesh says they are *the one system we could not hack* (this is
  technically true; the Ancients designed them to refuse the Mesh
  specifically).

The truth — withheld from the player for many hours — is that the Ruins
are *seed vaults*. They contain the genetic, technological, and digital
record of every prior civilization the Ancients have watched go through
this convergence. The Ancients are not building anything new. They are
*backing up* the things worth saving from each fall.

This makes the Ancients tragic, not antagonistic. They are not the boss.
They are the librarian for the apocalypse.

---

## 5. Wave Structure — Composition, Intent, and Voice

Waves do three things at once: they pressure-test the player's economy,
they teach the player how other factions play (so multi-faction replay is
informed), and they deliver the narrative through wave commanders.

### Composition by wave tier

| Wave Tier | Composition | Design purpose | Lore frame |
|---|---|---|---|
| 1–10 | Single faction, basic units | Teach the player one threat at a time; learn your own counters | Skirmishes — the other factions are testing the player's reach |
| 11–25 | Cross-faction pairs (e.g., Architect siege + Mesh raiders) | Force priority decisions, dual-axis defense | Temporary alliances of convenience — the enemies don't trust each other but they trust *you* less |
| 26–50 | Coalition waves led by named commanders | Strategic prioritization; pattern recognition; *story* | The factions have decided you are the threat, and they are wrong about that, but it doesn't matter to you in the moment |
| 50+ (Endless) | Coalition + periodic Ancient boss every 10 waves | Milestone pressure; gear check | The world is closing on the player and reaching for the Ancient question |

### Wave intent — legible behavior, not just numbers

A good wave can be read by a skilled player before it lands. Each faction
attacks with intent:

- **Architect waves** bring **siege equipment** for defensive structures.
  They target your *production chain.* They want your buildings, not your
  units.
- **Bloom waves** carry **spore-spreaders** that drop biomass tiles onto
  the player's territory. They want your *map*, not your buildings.
- **Mesh waves** target your **highest-value structures and most expensive
  units.** They want your *capital expenditure*, not your map.

These three intents map exactly to the three loop identities (§1). The
factions attack the way they play. A player who plays Bloom learns to read
Architect siege waves the hard way, and that hard lesson teaches them how
to *use* Architect-style attacks when they replay as Architects.

### Named commanders and dialogue

Every wave from Tier 11+ has a named enemy commander with two short
spoken lines: one before the attack, one when defeated (or one when they
break through). The voice rules from the lore brief apply:

Examples (drafted in faction voice):

- *Architect — Magistrate Vell, before attack:* "Output rate non-compliant.
  We will recover it." *On defeat:* "Variance noted. Updating model."
- *Bloom — The Root-That-Remembers, before attack:* "You will be soil.
  We will be patient." *On defeat:* "Compost is still useful."
- *Mesh — //fang.exe, before attack:* "Found your weakest port. It's
  hello." *On defeat:* "Reroute. Back tomorrow."

Across 50+ waves, the commander dialogue tells the *enemy* side of the
story. The player accumulates an opera of voices, half-overheard, that
slowly outlines the Option B truth. By wave 40, a Bloom commander mutters
something like "we used to be them," and a Mesh commander says, "the
dream logs are getting longer." These lines do not appear early. They are
earned by survival.

---

## 6. Endless Mode — The Loop, the Idle, the Prestige

### The core loop

1. **Build** — optimize production during quiet phases (idle-strong).
2. **Survive** — hold waves of escalating composition and intent.
3. **Milestone** — hit the faction-specific escalation trigger (§3).
4. **Ancient encounter** — the Ancients arrive, drop a Fragment, leave.
5. **Choose** — *Collapse* (prestige reset with permanent bonuses) or
   *Continue* (next cycle, higher difficulty, more late-game content).

### Idle / offline behavior

- Production runs while the player is away.
- Resources accumulate at faction-specific offline rates (Architect highest,
  Mesh lowest — Mesh needs the player active to raid).
- If a wave fires offline, it auto-resolves against the player's defensive
  posture at logout. The player returns to one of:
  - **Held** — no losses, full resources.
  - **Bruised** — some structures destroyed, half resources.
  - **Overrun** — significant loss, *forced prestige* (this is bad, but it's
    not punishment; the prestige itself confers carryover bonuses).

This is the mechanism by which the game respects the player's time. A bad
offline result still moves the game forward.

### Procedural map elements

- Maps are procedurally generated with biome variation.
- Some biomes favor specific sub-paths: forests favor Spiritual-Tech and
  Purist Bloom; cityscapes favor Networked Mesh and Assimilator Bloom;
  open terrain favors Standard Architects.
- Ancient Ruins always appear, but their location is randomized — and
  occasionally there are *two* sites, which is rare and meaningful.

### Prestige and the Collapse cycle

Every Collapse confers:

- Permanent multiplier (small)
- One **Memory Tier** unlocked — a layer of fragment dialogue that becomes
  visible the next cycle
- Optional faction-switch for the next run

The Memory Tiers are how the game tells the Option B story over multiple
playthroughs. After ~7–10 prestiges (across one or multiple factions),
the player has assembled enough fragments to read the full convergence
history. This is the deep replay engine.

---

## 7. Design Challenges — Answered Directly

### Balance — keep the asymmetries; use sub-paths as the lever

Each faction has a deliberate Achilles heel that is also its identity:

- Architects are brittle.
- Bloom is slow.
- Mesh is starved without targets.

These are features. Do **not** try to balance them away. Instead, balance
*within* the asymmetry: give each faction a Heresy sub-path that partially
compensates for its weakness. Architects who pick Spiritual-Tech trade
ceiling for resilience. Bloom that picks Assimilator trades evolution
speed for breadth. Mesh that picks Dreamer trades tempo for unique unit
capability.

The sub-path commit point (Tier 2) is the player's main balance lever. It
lets a player who is being bullied in their current style switch to a
more defensive variant of the same faction without abandoning the run.

### Alien faction integration — earn the reveal

The Ancients should not appear in the first ten waves. Their presence is:

- Visible (Ruins on the map from wave 1)
- Inert (do nothing yet)
- Activated by the first milestone

Players who pay attention to lore see the Ruins, wonder what they are,
and feel rewarded when the answer arrives on their own milestone trigger.
Players who don't notice the Ruins still get a clean surprise. Both
audiences are served.

After activation, the Ancients are a tuning dial: they intervene against
whoever is leading, which means they soft-cap dominance without nerfing
specific factions in code. A player who is winning hard gets harder
Ancient attention. A player who is barely surviving gets ignored by the
Ancients and can recover.

### Narrative arc in an endless game — three layers

1. **Per-wave dialogue** — wave commanders speak in faction voice. Short
   lines. Cumulative.
2. **Per-milestone events** — the Ancients arrive, speak rarely, drop
   Fragments.
3. **Per-prestige Memory Tiers** — fragments resolve into a longer story
   across cycles.

No cutscenes. No forced stops. The story is delivered in the seams of
gameplay, which is the only way a story works in an endless game.

---

## 8. Sub-Path Specification (Mechanics Sketch)

For implementation handoff. Six paths total, two per playable faction.

| Faction | Path | Key Building | Key Unit | Idle Modifier | Combat Modifier |
|---|---|---|---|---|---|
| Architects | Standard | Nexus Core | Apex | +25% offline production | Tier 6 superweapons |
| Architects | Spiritual-Tech | Ley-Spire | Warden | +15% offline production, +12–18% conditional on terrain | Strong area control, weak mobility |
| Bloom | Purist | Mother-Spire | Bio-Titan | Biomass grows offline | Strong adaptation; immune to hacking |
| Bloom | Assimilator | Crucible-Hive | Chimera | Slower biomass growth | Modular adaptation; can use captured tech |
| Mesh | Networked | Daemon-Forge | Hydra-Daemon | Minimal offline resource | Network cascade; raid economy |
| Mesh | Dreamer | Memory-Stack | The Remembered | Minimal offline resource | Unique two-layer combat; access to Ancient Fragments |

These are sketch values, not balanced numbers. The data lives in
configuration, not engine code, per the constitution's data-driven
preference (`core/02_constitution.md`, rule 7).
Project files located at: `D:\AI\Cycle Four\` (design corpus under `docs\`)

---

## 9. The Academy — Ultra Leader Origin and Playstyle Sorting

### Concept

The player begins as a cadet with no faction allegiance and no fixed
identity. The Academy is a series of short simulation scenarios — each one
a pressure test with no wrong answer — that read the player's instincts and
route them toward a faction, sub-path, and play style.

Think Sorting Hat, not personality quiz. The scenarios are *situations*, not
questions. The player acts; the Academy observes.

### Structure

**3–5 scenarios, each 60–90 seconds of active play.** Short enough to
respect the player's time. Long enough to reveal genuine instinct under
pressure.

Each scenario presents a tactical problem with multiple viable solutions.
The Academy scores the *approach*, not the outcome:

| Scenario | What it tests | Architect signal | Bloom signal | Mesh signal |
|---|---|---|---|---|
| Base under simultaneous attack from two directions | Priority under pressure | Defends the production chain first | Defends the territory edge first | Counterattacks the weaker flank immediately |
| Surplus resources mid-wave | Expand vs. fortify vs. bank | Builds the next production tier | Expands biomass / fortification perimeter | Launches a probe raid on the incoming wave |
| Enemy unit wounded and retreating | Aggression vs. conservation | Holds and recalculates | Lets it go — not worth the exposure | Pursues, harvests the node, keeps pressure on |
| Ancient Ruins appear on the map edge | Curiosity vs. caution | Sends a scout unit to catalog it | Observes from distance — patience | Immediately attempts to interface with it |
| Ally commander sends a distress call | Cooperation vs. self-interest | Calculates whether the assist benefits long-term output | Responds — the network of living things matters | Ignores or exploits the distraction |

The fourth scenario (Ancient Ruins) also seeds the lore reveal — the
player's first hint that something older is present before any wave fires.

### Sorting output

After the scenarios, the Academy presents **three faction recommendations**
ranked by instinct match — not a forced assignment. The player can:

- Accept the top recommendation (fastest onboarding, path bonuses)
- Choose a different faction (minor starting penalty, player agency preserved)
- Decline sorting entirely (harder start, Dreamer path hint — the unsorted
  cadets are the ones who remember things they were never taught)

The sorting also flags sub-path lean. A player who consistently plays
defensively and terrain-aware within an Architect run gets a Spiritual-Tech
nudge at the Tier 2 commit point. A Mesh player who pauses before every
action gets a Dreamer nudge.

### Lore framing

The Academy is not a neutral institution. Each faction funds a wing of it
and interprets its graduates differently:

- **Architect wing:** The Academy is a filtering system. Cadets are sorted
  by efficiency potential. The ones who hesitate go to Bloom.
- **Bloom wing:** The Academy is a germination period. Cadets who survive
  it without being shaped by it are the interesting ones.
- **Mesh wing:** The Academy is a honeypot. The real recruitment happens in
  the simulations themselves — they are not tests, they are tutorials for
  the systems the Mesh already runs.

The player never learns which wing ran their simulation until much later.
This is the first layer of Option B — even your origin story is contested.

---

## 9b. Core Gameplay Loop — Tower Defense + Unit Production Clarification

### The hybrid structure

The game operates on three simultaneous layers:

**Layer 1 — Idle production (always running)**
Resource nodes generate income over time, online and offline. This is the
idle spine. Player returns to accumulated resources and builds from there.

**Layer 2 — Tower defense (passive combat layer)**
Defensive structures are placed on the map and auto-engage incoming waves.
Towers do not require active management during a wave — they fire based on
faction-specific targeting logic (Architect towers prioritize high-threat
units; Bloom thorns prioritize territory-spreading units; Mesh traps
prioritize high-value targets). The player places and upgrades between
waves, not during.

**Layer 3 — Unit production (active combat layer)**
Defensive structures double as production facilities. Each structure has a
**production cooldown** and a **resource cost per unit**. During a wave the
player can trigger production manually — spending current resources to spawn
units that actively push back, flank, or raid returning waves.

This gives the player two modes of engagement with the same structure:
- *Set it and forget it* (tower defense mode — passive auto-attack)
- *Actively manage it* (RTS mode — spend resources, direct produced units)

A player with five minutes gets the tower defense experience.
A player with an hour gets the RTS experience.
Both are playing the same game.

### Production cooldown design

| Structure tier | Cooldown | Unit type | Role |
|---|---|---|---|
| Tier 1 | 30 sec | Light unit | Fodder, speed |
| Tier 2 | 90 sec | Mid unit | Generalist, durable |
| Tier 3 | 4 min | Heavy unit | Anchor, high damage |
| Milestone | 15 min | Faction signature unit | Apex / Bio-Titan / Hydra-Daemon |

Cooldowns run in real time, including offline — a Tier 3 structure starts
a production cycle before the player logs off, and the unit is ready on
return. This bridges the idle and active layers.

Resource cost per unit is a fraction of the wave reward — production is
funded by surviving waves, not banked from idle income. This keeps
production decisions tied to combat performance, not just patience.

### Wave pressure model

Waves do not come from one direction. Each wave has a **pressure axis**:

- **Primary axis** — the main assault. Tower defense handles this.
- **Secondary axis** — a flanking probe at lower strength. Ignoring it
  costs territory (Bloom), production (Architects), or node connections (Mesh).
- **Tertiary event** — optional: an Ancient Ruins pulse, a named commander
  appearing, or a cross-faction surprise alliance. Adds variety without
  scripting every wave.

The secondary axis is where active unit production matters most. Towers
cover the primary. A player who has been producing units during the primary
assault has forces ready to push back the flank.

---

## 10. Open Questions for the Next Pass

The OpenLama questions are answered. These are the next-tier questions
this doc surfaces but does not resolve:

1. **What is "the next thing"?** The Ancients fear it. We have not named
   it. Whatever it is, it should be teased through Fragments and never
   shown in this game — keep it as the hook for a sequel or a final
   prestige tier.
2. **Multiplayer Option B.** If two players play the same faction's
   opposite sub-paths, what does the matchup feel like? The civil-war
   energy is rich; this might be the spine of the eventual PvP design.
3. **Commander voice writing.** The wave commander lines need a writing
   pass with proper voice consistency. The brief established the voices;
   the lines should be drafted in batches per faction by someone who can
   stay in one voice at a time.
4. **Ancient pacification economy.** What exactly do you sacrifice to
   the Ruins, and what's the conversion rate? The mechanic is sketched;
   the tuning is not.
5. **First-time-player Fragment pacing.** A new player hits their first
   milestone around hour 3–5 of play. Is that the right pacing for the
   first Ancient appearance, or should we earlier-tease? Test this with
   playtest data, not theory.
