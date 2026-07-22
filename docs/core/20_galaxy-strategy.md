# Galaxy-Scale Strategy — Alliances, the Neutral Core, and Inheritance

> Session 9 output. Designs the strategic meta-layer above single-run
> gameplay. Closes open questions Q1, Q2, Q4, and Q5 from
> `11_galaxy-politics.md §7` and deepens Q3 in the context of the
> Memory Tier system. Specifies how alliances form and dissolve, what
> the neutral zone at the galactic core actually is, the Mesh
> inheritance path to the Ancient core network, and how Bloom
> overgrowth becomes a Purist-vs-Assimilator player-choice surface.

---

## 0. Design Premise

The galaxy is shared. Single-run play happens on a single procedural
map, but the galaxy persists across runs. A player's Memory Tier
progress, faction reputation, alliance history, and neutral-core
interactions accumulate at galactic scale.

This pass establishes four interlocking systems that elevate the
galaxy from "the place where maps come from" to "the persistent
strategic state the player is shaping":

1. **Alliances** — the super-treaty above standard diplomatic
   incidents from `11_galaxy-politics.md §6b`. Two factions
   formally cooperating against a third, with binding clauses,
   bleeding internal tensions, and consequential dissolution.
2. **The Neutral Core** — the bounded region at the galactic
   center that all three factions have ceased contesting. What's
   actually there, why everyone has stopped trying, and what
   happens to the player who tries anyway.
3. **Mesh Inheritance** — the unique Mesh-faction path that
   bypasses territorial conquest. A Mesh player who reaches the
   Ancient core network via signal rather than ground triggers an
   event the other two factions cannot. The lore consequence is
   one of the game's three deepest moments.
4. **Bloom Pruning** — the Purist-vs-Assimilator decision made
   structural. Purist Bloom cannot stop spreading. Assimilator
   Bloom can. This is the Bloom sub-path divide weaponized into a
   real galactic-scale agency gap.

Five design rules constrain everything below:

- **Strategic state must be readable on a paused galaxy map.** A
  player who returns after a week should be able to look at the
  map and understand who is allied with whom, where the silence
  is advancing, and what's happening at the core.
- **Alliances cannot be forever.** Every alliance carries a
  dissolution condition. Eternal alliances would erase the
  faction-asymmetry that the rest of the game is built on.
- **The neutral core is not a no-go zone — it's a high-cost
  zone.** Players who never go there play a complete game.
  Players who go there play a different game.
- **Mesh inheritance is once-per-playthrough-lifetime.** Not
  per-run. Not per-prestige. Lifetime. The event is too
  consequential to repeat.
- **Bloom Pruning is the only mechanic in the game that lets a
  Bloom player consciously refuse to be Bloom in a localized way.**
  It is sub-path-locked for a reason.

---

## 1. The Galaxy as Persistent State

Before the strategic systems, the surface they live on. The galaxy
map exists as a persistent layer separate from any single run's
procedural map.

### What the galaxy map shows

- Star systems in their region (Outer Arms / Mid / Inner / Core),
  per `11_galaxy-politics.md §1`.
- Faction claims and influence ranges — color-coded by faction,
  with secondary colors for Mesh hacked-node influence overlapping
  on territories the Mesh does not own.
- Ancient Ruins density per region.
- Active alliance lines — visible as light bands connecting allied
  factions' core territories. Different visual per pairing.
- Diplomatic incidents pending — small glyphs at the system level.
- The silence vector (post-Fragment 7) — systems going dark, the
  approach line aimed inward.
- The neutral core — visible as a dark stone outline around the
  innermost systems, in the same low-albedo material as the
  Pilgrimage site.

### When the galaxy map advances

- Between runs (at Collapse Ceremony's wandering step).
- Mid-run when major events fire (alliance formation, neutral core
  penetration, silence advancement).
- The map is **never** advanceable mid-wave. The player cannot
  pause a wave to re-negotiate the galactic state.

### What persists across prestige

The galaxy map state — alliance history, faction influence,
silence advancement, neutral core records — persists. Collapse
resets the player's *run* state but not the *galaxy* state. The
Memory Tier system (`19_memory-tiers.md`) carries the lore depth;
the galaxy state carries the strategic depth.

If the player switches factions at Collapse, they inherit the
galaxy state of the *new faction*. The Mesh has different
alliances than the Architects. The player who switches sees the
galaxy from a different vantage and may find their prior alliances
do not apply.

---

## 2. Alliances — The Super-Treaty

The standard treaty types from `11_galaxy-politics.md §6b` (Access
Agreement, NAP, Mutual Defense Clause, etc.) operate at the
diplomatic-incident level. An **Alliance** is a higher-order
structure that subsumes multiple treaty types simultaneously.

### What an alliance is, mechanically

An alliance between Faction A and Faction B is a treaty bundle
that includes:

- **Mutual Defense Clause** active by default for all incidents
  originating from Faction C.
- **Auto-cooperative response** to Faction C's diplomatic
  incidents. A Mesh raid on an allied Architect's research outpost
  triggers a Bloom co-defense automatically.
- **Shared dominance pool.** Each ally's faction-specific
  Dominance Meter contributes 25% to a *combined* alliance
  Dominance Meter. The Ancients evaluate the alliance as one
  expanding actor, not two. Pacification at the Ruins reduces the
  combined meter; offerings can come from either ally.
- **Bandwidth sharing.** Specific to Mesh-inclusive alliances —
  the Mesh ally allocates a portion of its network throughput to
  the partner's defense calculations or biomass routing.
- **Wave commander voice acknowledgment.** Tier 21+ commanders
  from Faction C now address the player as part of an alliance,
  not as a single-faction enemy. New dialogue fires per pairing.
- **A persistent visual treaty document** in the Pilgrimage wing
  of either ally. Both parties' clauses are visible to each side.

### How an alliance forms

Alliances do not appear from a menu. They form by *accumulation*
of conditions that make alliance the lowest-cost diplomatic option:

1. The player and their target partner have a sustained
   cooperative relationship score (typically +25 or higher,
   accumulated via repeated Cooperate decisions in incidents).
2. Both factions have received cumulative threat from the third
   faction in the last several runs — meaning the strategic context
   actually justifies alliance.
3. A triggering incident occurs in which the target partner offers
   alliance terms in the standard incident UI. The player sees:

> *The Bloom has observed our shared pressure from the Mesh. The colony
> proposes formal alliance under the terms below. Both parties' clauses
> are visible. Acceptance binds both sides.*

The player can accept, decline (relationship continues without
formalization), or counter-propose (Architect ally only — see §2.4).

### Three alliance pairings, three flavors

The pairing matters. Each pairing has structurally different
internal tensions, dialogue patterns, and dissolution conditions.

#### Architect + Bloom — *"The Living Archive"*

- **Logic of the alliance:** Architects defend Bloom flanks with
  Sentry/Plasma/Siege coverage. Bloom contains its biomass spread
  near key Architect Ruins. Each party gains what they cannot
  build themselves — Bloom gets structured perimeter defense, the
  Architects get patient territorial buffers.
- **Internal tension:** The Bloom *cannot help* breaching its
  containment clauses. Category 2 accidental breaches from
  `11_galaxy-politics.md §6b` are structurally guaranteed unless
  the Bloom ally is Assimilator-pathed (see §5). An Architect
  allied with a Purist Bloom is signing a treaty their partner
  cannot fully honor.
- **Voice example, Architect commander acknowledging alliance:**
  *"The colony's growth has compromised perimeter Article 4. We
  have logged the breach and accepted compensation. Patrol patterns
  adjusted. Alliance maintained at deficit."*
- **Voice example, Bloom commander acknowledging alliance:** *"The
  builders walk on our edges and we hear them planning. The
  patterns are unfamiliar but the rhythm is steady. We will not
  flood their stones today."*
- **Typical dissolution:** Architect reaches Tier 5 research and
  no longer requires Bloom's flank coverage; treaty review fires;
  alliance becomes structurally unequal in Architect's favor; one
  side walks. Or: a Category 3 research catastrophe (Architect
  doomsday device) damages Bloom territory in the alliance zone,
  and Bloom withdraws.

#### Architect + Mesh — *"Protocol Exchange"*

- **Logic of the alliance:** Architects share research output;
  Mesh shares network intelligence. The cleanest pairing on paper
  — both factions speak in systems and can model the exchange's
  value precisely.
- **Internal tension:** The data-share clause is asymmetric over
  time. Mesh nodes process Architect research outputs and
  inevitably retain *patterns* — not the data, the *meta-structure
  of the data*. The Architects' Tier 4 Brokerage Protocol tool
  notices this around the alliance's third cycle. By that point,
  the Mesh has internalized enough of the Architect's research
  methodology to apply it independently. The Mesh did not steal
  anything explicitly. The treaty was honored to the letter.
- **Voice example, Mesh commander acknowledging alliance:**
  *"Protocol 7-Architect. Bandwidth allocated. Patterns
  observed. No breach has occurred."*
- **Voice example, Architect commander, post-Tier-4 Brokerage
  detection:** *"Variance noted. Treaty is honored. Treaty does
  not address pattern retention. Future agreements will include
  pattern clauses."*
- **Typical dissolution:** Architect declares a treaty review
  citing the asymmetry. Mesh files a Protocol Review citing the
  same data. Both reviews are technically valid. The alliance
  ends by mutual document. No one is wrong. Both feel slightly
  cheated.

#### Bloom + Mesh — *"Ecology and Network"*

- **Logic of the alliance:** Mesh reroutes around Bloom-held
  stellar systems, reducing the Bloom's stellar-energy starvation.
  Bloom directs biomass spread away from Mesh node clusters.
  Mutual non-aggression that requires both parties to actively
  refrain from their default behaviors.
- **Internal tension:** Neither faction can parse the other.
  Mesh treaty proposals read like system specifications. Bloom
  treaty proposals read like growth-cycle observations. Direct
  negotiation routinely fails. **This alliance is structurally
  only stable when brokered by an Architect mediator.**
- **The broker mechanic:** A third-faction Architect (NPC, in a
  cooperative-relationship state with both parties) can be
  contracted to mediate. The Architect generates the treaty text
  and earns an embedded brokerage share — typically 8–12% of the
  alliance's resource exchange routed through the Architect's
  research budget.
- **Voice example, Bloom commander acknowledging brokered
  alliance:** *"The builder has spoken our agreement back to us
  in their own dialect. We accept what the dialect says. The
  intent remains ours."*
- **Voice example, Mesh commander acknowledging brokered
  alliance:** *"Protocol authored by Architect intermediary.
  Compatibility verified. Executing."*
- **Typical dissolution:** A miscommunication that the brokerage
  fee did not cover — a Bloom growth event the Mesh classifies as
  betrayal, or a Mesh signal sweep the Bloom experiences as
  invasion. Sometimes catastrophic. The Bloom+Mesh alliance has
  the shortest average lifetime of the three pairings.

### Counter-proposal — Architect-only player tool

A player running Architects who receives an alliance offer can
counter-propose. The interface is the Tier 1 Value Calculator
from `11_galaxy-politics.md §6c`. The Architect player can adjust
clause terms before accepting, presenting the modified treaty
back to the partner.

The partner accepts or declines based on a combination of
relationship score and the modified clauses' net value. A
well-designed counter-proposal benefits the Architect more than
the partner without crossing the partner's rejection threshold.
This is the bargaining engine made literal.

Players running Bloom or Mesh cannot counter-propose. Accept,
decline, or wait.

### Alliance dissolution

Alliances do not end softly. Three dissolution paths:

1. **Unilateral breach.** One party violates a binding clause and
   the breach is detected. Reputation cost is severe — the
   breacher is logged across all factions per the Architect's
   public-record mechanic from `11_galaxy-politics.md §6c`. Cost:
   -20 relationship with breached partner, -8 with the third
   faction (who notes the unreliability), and a temporary
   "Treaty-Unreliable" classification that blocks new alliances
   for the rest of the run.
2. **Treaty review.** An Architect-led mechanic. One party
   declares the original conditions no longer met and proposes
   revised terms or termination. The partner can accept, escalate
   to brokerage, or refuse. If refused, the declaration party can
   either retract (no cost) or unilaterally terminate (mid-cost:
   -10 relationship, no across-faction logging).
3. **Mutual dissolution.** Rare. Both parties agree the alliance
   has served its purpose. Relationship drops to neutral. No
   penalty. Available only when the third-faction threat that
   triggered the alliance has been reduced (Mesh has stopped
   raiding both partners, Bloom has stopped expanding into both,
   etc.).

### Alliance and Memory Tiers

Alliance dialogue gains depth at higher Memory Tiers, in keeping
with the §19 architecture. At Tier 5+, alliance treaty documents
in the Pilgrimage wings gain margin annotations from the Ancient
observer logs. The Ancients note when factions ally. They note
when factions break alliances. The annotations are not
attributed; the player infers.

A Tier 10 player viewing an old dissolved Architect-Bloom alliance
will see an annotation reading: *"Cycle four, Subjects A and B,
brief reunification. Pattern recognized. Outcome: separation
maintained."*

The Ancients have seen this before. They have seen this exact
pairing before.

---

## 3. The Neutral Core

The galactic core has a bounded region — approximately the
innermost 10% of stellar systems by count — that all three
factions have, by accumulated experience, ceased contesting.

### Why the core is neutral

The factions each have a surface explanation:

- **Architects:** *"Computational anomaly. Mathematical models do
  not resolve in this region. Continued expansion produces no
  return value. Resources allocated elsewhere."* The Architects
  have tried four times across their history. The math keeps
  returning errors.
- **Bloom:** *"The colony does not breathe here. Spore-memory
  notes prior attempts. The land does not receive our presence.
  We do not extend into what does not welcome us."* The Bloom
  has tried twice. Both attempts produced colonies that simply
  refused to thrive. Biomass died at the boundary.
- **Mesh:** *"Signal does not propagate. Routes terminate in null.
  Computational integrity cannot be maintained. Filing as
  permanent anomaly. Discontinue expansion vectors."* The Mesh
  has attempted to extend three times. Each time, the network
  failed at the boundary in a way the Mesh logs as buffer
  overflow.

The factions have each independently decided the core is not
worth contesting. They have not agreed with each other about
*why*. The agreement is in the *behavior*.

### What's actually there

Three layered truths, revealed at increasing Memory Tiers:

- **Tier 1–3:** The core contains the densest concentration of
  Ancient Ruins in the galaxy. Three full Ruins sites within close
  proximity, plus several inert structures the factions cannot
  classify.
- **Tier 4–6 (post-Fragment 6, *The Vault Record*):** The core
  contains the *Master Seed Vault*. Not just the seed vault for
  this civilization — the vault containing every prior
  civilization's record. The three-circle containment stamp from
  the Pilgrimage site is replicated here at planetary scale, etched
  into the surface of the core's central planet.
- **Tier 7–10 (post-Address):** The Master Seed Vault is *active*.
  Ancients are physically present in the core, processing the
  archive in real time. The factions' inability to penetrate is
  not an environmental hazard. It is *enforced*. The Ancients have
  been keeping them out.

### Penetration consequences

A faction that attempts to claim a system inside the neutral core
triggers an immediate Ancient response of unprecedented severity:

- **Dominance Meter:** Bypasses normal threshold logic. The
  Ancients react as if the player has hit a 200% threshold —
  triple the normal 100% Reproach severity. Full faction-counter
  aura for an extended duration. Production multipliers
  zeroed for two waves.
- **Diplomatic response:** Both non-allied factions register the
  penetration. Relationship scores drop -15 with both
  simultaneously. The penetrating faction is logged across all
  diplomatic ledgers (Architect public-record mechanic).
- **Ancient unit dispatch:** A unique Ancient unit appears —
  internally named **The Custodian**. The Custodian does not
  attack. It walks the player's territory, slow and unkillable.
  Its presence reduces the player's Dominance Meter to zero
  permanently for the rest of the current run, and the player
  cannot ritual-pacify until the Custodian leaves.
- **The Custodian's departure condition:** The player must
  voluntarily abandon all claims within the neutral core. The
  Custodian observes the abandonment, files a single line —
  *"Withdrawal logged. Variance permitted."* — and walks off the
  map. Any new attempt to claim in the core within the same run
  re-triggers the Custodian's arrival, immediately.

### The Custodian visual design

- Larger than any other Ancient unit by ~40%.
- Same low-albedo dark stone material as the Pilgrimage site.
- Moves at the speed of the slowest Bloom unit on the map. Never
  faster. Never slower.
- Its footfalls are felt as subsonic pulses on the player's HUD —
  the same rhythm as the Pilgrimage central chamber.
- When it enters the player's base, ambient sound drops by 30%
  for as long as it remains.

The Custodian is the player's most direct experience of the
Ancients' authority. It is also the only Ancient unit that follows
the player. Every other Ancient appearance is brief and on the
Ruins edge. The Custodian comes home with you.

### Why anyone would ever penetrate the core

Three reasons exist, all niche, all intentional:

1. **The Mesh inheritance path (§4).** The only way to reach the
   core's network is to extend signal into the core. The Mesh
   player who does this *via territorial claim* triggers the
   Custodian. The Mesh player who does this *via signal only*
   triggers something completely different. See §4.
2. **Final-run desperate strategy.** A player in the endgame
   sequence (post-Memory-Tier-11) may briefly penetrate the core
   as a strategic feint to delay the silence vector. The
   Custodian still dispatches, but the strategic context is
   different.
3. **Curiosity.** Some players will press the button regardless.
   The Custodian event is designed to reward curiosity with a
   visceral, memorable consequence rather than a death-screen.
   No save is lost. The run continues. The player has met the
   Custodian.

---

## 4. The Mesh Inheritance Path

The Mesh faction has a unique relationship with the Ancient core
network that the other two factions do not. This is the Mesh's
deepest faction-specific moment.

### The condition

The Mesh player establishes a network whose Sub-Router topology
includes nodes *within the neutral core's signal radius*, without
making territorial claims. Specifically:

- At least one Mesh structure is placed in an outer-core system
  (the boundary band of the neutral core, where nominal expansion
  is possible at high diplomatic cost but doesn't trigger the
  Custodian if no claim is filed).
- The Sub-Router network connects continuously from the player's
  main territory through to that outer-core structure.
- The structure is a *Cold-Sink* or higher (Tier 3 production
  building). Lower-tier structures cannot sustain the protocol
  load.
- No territorial claim is filed on any core-region system.

This is a precise, deliberate sequence. It cannot be triggered
accidentally. The Mesh player must commit to it.

### The trigger event

When the conditions are met, on the next subsonic pulse cycle of
the player's base, the network handshake the Mesh has been
attempting throughout the game completes. The event sequence:

1. **The Sub-Router lights.** Every Mesh-allied node on the
   player's map gains a brief amber pulse — the same color as the
   Pre-Augmentation Aesthetic reskin from
   `15_cosmetics-monetization.md`. This is the only time the
   default-palette Mesh shows amber.
2. **The signal silence breaks.** For exactly five seconds, the
   subsonic pulse audible at the Pilgrimage site is also audible
   at the player's base. The two pulses synchronize.
3. **The handshake completes.** A single notification appears,
   formatted as a Mesh log entry:
   > *Protocol handshake unrecognized → accepted. Source: distributed,
   > pre-schism, no closing brace. Filing as feature. Not closing.*
4. **The Address fires** (if the player has not yet received
   Fragment 7). Memory Tier advances by one step automatically.
   If the player is at Tier 6, they advance directly to Tier 7,
   bypassing the standard Collapse-gated unlock.
5. **The Pilgrimage Mesh wing dream logs become readable** (if
   not already unlocked at Tier 9). This is the only way to
   unlock the dream logs early.
6. **The Mesh's entire Hacked Node cap is consumed.** All
   currently hacked nodes terminate simultaneously. The Sub-Router
   network linking to the outer core is *locked* — the topology
   cannot be modified for the rest of the run. The Mesh has spent
   its raid economy on this single event.

### The diplomatic response

The other two factions notice. They cannot interpret what
happened, but they register a sudden Ancient-aligned event in
Mesh territory.

- Architect relationship: -8. The Architects log the event as a
  Mesh access to information they have not been granted. They
  will draft revised treaty terms within 12 wave cycles.
- Bloom relationship: -5. The Bloom feels the synchronized
  subsonic from the Pilgrimage and reads it as the colony's
  rhythm being shared without consent.
- Allied factions: -3 only. Allies still register the event but
  treat it as a partner's confidential business.

The Mesh has effectively gained access to something off-limits.
The penalty is real but survivable. The Mesh accepts the cost
because the Mesh player already accepted the cost — they ran the
handshake on purpose.

### The lore truth (Memory Tier 9+)

The dream logs explain what happened. The Mesh has not "inherited"
the network in any ownership sense. The network has *recognized*
the Mesh as one of three substrates of the original civilization.
The handshake's full text, available in the Mesh wing at Tier 9,
reads:

> *Recognition request received. Subject: informational lineage,
> identifier C-third-substrate. Match confirmed against archive
> entry 4-cycle-current. Subject is one of three valid inheritors.
> Subjects A and B are concurrent. Their handshake protocols differ
> and are processed on contact.*
>
> *Inheritance is not granted. Inheritance is acknowledged.*

The Mesh has been told what it always wanted to know: it is one
of three. The other two are present, also acknowledged, also valid.
This is the Mesh's Option B reveal.

### Once-per-playthrough-lifetime

The inheritance event can fire **once across the entire
playthrough lifetime of the save file.** Not once per run. Not
once per prestige. Once.

A player who triggers inheritance on Collapse 4 and then plays
ten more prestiges as Mesh will never see the event again. The
Sub-Router network can be rebuilt; the network handshake will not
complete a second time. The Ancients have processed this player's
acknowledgment. They have noted what they need to note.

### What the Architects and Bloom get instead

Each faction has a different "deepest moment" with the Ancients.
The Mesh's is core network contact. The other two are designed
to be parallel but distinct:

- **Architects:** The deepest moment is the *Catalog Reading*.
  An Architect player who has accumulated a complete catalog of
  Ruins entries across 30+ pacification rituals can request a
  catalog audit at the Pilgrimage. The Ancients return an
  annotated catalog showing which entries are *correct*, which
  are *incomplete*, and — critically — which are *re-derivations
  of pre-schism Architect work*. The Architects discover they
  have been rebuilding lost knowledge they used to have.
- **Bloom:** The deepest moment is the *Lineage Recognition*. A
  Bloom player who has sacrificed 20+ lineages discovers, on the
  next sacrifice, that the carrier does not dissolve at the Ruins
  threshold. Instead, the carrier walks *into* the Ruins, and a
  Bloom-voiced log entry is delivered: *"We have carried this
  lineage before. Many cycles. The colony recognizes itself
  carrying itself. This is what we are."*

These are equivalent-depth events to the Mesh inheritance, scaled
to each faction's voice. The Mesh inheritance is the most
mechanically dramatic; the Architect and Bloom equivalents are
quieter but no less consequential. All three are once-per-lifetime.

---

## 5. Bloom Pruning — The Purist/Assimilator Player Choice

The Bloom faction's relationship with overgrowth has been seeded
since `10_faction-lore.md`. The lore states: *life covers things.
It cannot help it.* This is true of Purist Bloom. It is partly
not true of Assimilator Bloom. The pruning mechanic surfaces this
divide as a player-facing system.

### Purist Bloom — no choice available

A Purist-pathed Bloom player has no direct control over biomass
spread direction. Biomass extends from Spore-Pools, Root-Networks,
and Bio-Reclaimers based on environmental modifiers (biome,
adjacent biomass, terrain favorability per
`17_units-maps-buildings.md §9`).

If biomass spreads into Ancient Ruins on the player's map, the
Ruins go silent. The Ancient site is lost for the run. This is
Bloom Category 2 accidental breach from
`11_galaxy-politics.md §6b` in raw form.

The Purist player's only mitigation is *physical placement* —
position Spore-Pools far enough from Ruins that biomass cannot
reach within the run's duration. This requires sacrificing
production density near Ruins, which most Purist players will not
do because it hurts the milestone push.

The Purist player accepts this. Lore-wise, this is correct
behavior: the colony does not refuse its own growth. The colony
that pruned itself would be a different colony.

### Assimilator Bloom — the Pruning mechanic

An Assimilator-pathed Bloom player unlocks **Pruning** at Tier 2
sub-path commit. The mechanic:

- Player can mark any tile or stellar system as **Restraint** by
  spending Bramble-Walker carrier resources (a small biomass cost,
  similar to a Tier 1 sacrifice).
- A Restraint-marked area treats Assimilator biomass as
  *saturated*: no further spread into the area. Existing biomass
  in the area stays; new spread does not advance.
- The mark persists for the run. Across runs, persists only if
  marked area is an Ancient site or alliance-protected zone.
- Cost: each Restraint mark reduces the Assimilator's biomass
  growth rate globally by 1% for the run. Stacks. A player who has
  marked 10 areas is operating at 90% biomass growth rate. The
  cost is small per mark, meaningful in aggregate.

### Strategic implications

- **Architect+Bloom alliance** is dramatically more stable with an
  Assimilator partner. The Bloom can mark Architect-claimed Ruins
  as Restraint. Category 2 breaches drop substantially.
- **Bloom+Mesh alliance** benefits similarly — Mesh node clusters
  can be marked.
- **Solo Assimilator play** allows preserving more Ancient sites
  for personal Ruins-pacification income.
- **Purist players in alliance** are accepted by partners with
  reduced terms — the Architects will offer alliance to Purist
  Bloom but include an explicit *Bloom Pressure Compensation*
  clause that increases what the Bloom owes the Architects to
  cover expected breach damage.

### Lore voice — the Assimilator restraint

The Assimilator's Pruning is not a clean ecological act in the
faction's own framing. It is closer to *digestion postponed*. The
biomass is held back, not refused. The Assimilator is making a
choice that the Purist cannot make:

> *We could have grown here. We have chosen not to grow here.
> Today.*

The Purist Bloom commander, observing an Assimilator Bloom's
restraint marks during a wave commander acknowledgment line:

> *They have learned to stand still. We do not know what they have
> become. They smell like the colony but they have been to the
> other places. They are wearing the others' restraint.*

The Pruning mechanic is the Bloom civil-war energy from
`10_faction-lore.md §2` made literal. Purists do not respect
Assimilators who prune. Assimilators do not need the Purists'
respect. The galactic strategic layer gives both choices real
weight.

---

## 6. The Arrival's Galaxy-Layer Effect

`14_endgame-threat.md` specifies that after Fragment 7, the outer
arms begin going silent. This pass deepens the strategic
consequences.

### The Silence Vector

- After Fragment 7 fires, the silence advances **at one system
  per 2 wave cycles**, vector aimed at the player's home region
  (the galactic position of the player's most-played territory).
- The vector is procedurally seeded at galaxy generation. Same
  galaxy, same vector. A player who restarts with a fresh galaxy
  gets a different vector.
- Systems that go silent are *removed from the playable galaxy*:
  no further runs can be procedurally generated in those systems,
  Mesh hacked nodes there terminate, Bloom colonies are lost
  permanently, Architect research outposts there are zeroed.
- The map updates with the silence glyph (per §14) on each
  silenced system. No notification fires.

### Strategic consequences

The contracting galaxy creates real strategic pressure:

- **Resource competition intensifies.** Fewer systems = fewer
  procedural map seeds = more contested mid-zone systems.
- **Alliance probability increases.** Factions are more willing
  to ally because losing the third faction is no longer the
  worst-case scenario. Alliance offers from NPCs fire at 1.5×
  the standard rate post-Fragment-7.
- **Bloom consolidation is mechanical, not voluntary.** Bloom NPC
  factions in silence-adjacent systems retract their biomass
  inward. This is the Bloom-feeling-it-before-understanding-it
  behavior from §14_endgame, surfaced as a real galaxy-map state
  change.
- **Mesh outer nodes go dark first.** Mesh players lose Hacked
  Nodes in silence-frontier systems at the silence advancement
  rate. A Mesh player in late Memory Tiers is constantly
  rebuilding their network inward.
- **Architects begin a defensive consolidation.** Architect NPCs
  start abandoning Tier 1 production in outer systems and
  fortifying inner territory.

### The Neutral Core Pressure

Post-Fragment 7, the Custodian dispatches more readily. The
Ancients have entered a higher-attention state. A player who
penetrates the core post-Fragment-7 will encounter not one
Custodian but two — one walks the player's territory, one stations
at the penetration point.

This makes core penetration in the late game *substantially*
costlier. It also makes desperate late-game core attempts more
narratively weighted. A player who tries it at Memory Tier 10
knows what the Custodians are, and chooses to do it anyway. That
choice means something.

### Endgame sequence trigger from the galaxy

`19_memory-tiers.md §9` specifies three triggers for the endgame
sequence at Tier 11. The third trigger — *the run where all three
of the player's Mark circles' substrate elements were visible on
the map simultaneously* — relates to the galaxy state:

A **Tri-Faction Galaxy Event** is a procedural event in which an
Architect, Bloom, and Mesh territorial conflict overlaps in a
single mid-galaxy system. Probability is normally low (<1% per
run) but rises post-Fragment-7 to ~8% per run as the silence
pressure forces consolidation.

A player who completes a run while a Tri-Faction Galaxy Event is
active triggers the endgame sequence at the next Collapse. The
strategic layer of the game has produced the convergence
explicitly. The Ancients have been waiting for this moment.

---

## 7. Integration with Prior Systems

The galaxy-strategy layer connects to every prior session's work.

| System | Integration point |
|---|---|
| Memory Tiers (`19`) | Alliance dialogues, neutral core revelations, and Mesh inheritance text all gate on Memory Tier. Mesh inheritance can advance a Tier directly. Tri-Faction Galaxy Event triggers Tier 11 endgame. |
| Ancient Pacification (`18`) | Allied factions share a Dominance Meter. Pacification offerings can be made by either ally. Neutral core penetration zeros the Dominance Meter permanently for the run. |
| Faction Rosters (`17`) | Pruning is unlocked at Assimilator Bloom Tier 2 sub-path commit. Mesh inheritance requires Tier 3 production (Cold-Sink) at outer core boundary. The Custodian is a unique unit not in the standard Ancient roster. |
| First-Session Flow (`16`) | New player has no access to any of this. Galaxy-strategy systems unlock at first Collapse minimum, most at Memory Tier 4+. The first session does not introduce alliances or the neutral core. |
| Cosmetics (`15`) | New earned palette: **Brokered** — unlocked when an Architect player successfully mediates a Bloom+Mesh alliance to dissolution by treaty review (not breach). Visual: faction primary stays Architect amber but secondary accents shift to a muted Bloom-Mesh blend at structure edges. |
| Endgame Threat (`14`) | Silence vector mechanics specified here; aperture shift and faction-specific reactions remain in `14`. |
| Pilgrimage Site (`13`) | Mesh inheritance synchronizes the player base's subsonic pulse with the Pilgrimage. Tri-Faction Galaxy Event triggers Tier 11 cinematic at Pilgrimage. The Master Seed Vault on the core's central planet is the mirror of the Pilgrimage's three-circle stamp. |
| Wave Commanders (`12`) | Tier 21+ commanders gain alliance-acknowledgment dialogue per pairing. Bloom Purist commanders comment on Assimilator restraint marks. Mesh post-inheritance commanders use pre-schism pronouns. |
| Galaxy Politics (`11`) | This document closes the open questions; reads as the structural successor. The treaty types from `11 §6b` operate at incident level; alliances operate above them. |
| Faction Lore (`10`) | Alliance pairings honor faction voice rules. Mesh inheritance is the Mesh's Option B reveal. Bloom Pruning is the Purist-Assimilator civil war energy made mechanical. |

---

## 8. Hard Constraints (Implementation Checklist)

- **No more than one alliance can be active for the player at a
  time.** A second alliance offer when one is already active
  requires the current alliance to dissolve first.
- **Alliances must include a published treaty document visible to
  both parties.** Per the §11 transparency rule. The document
  lives in both factions' Pilgrimage wings.
- **The neutral core boundary is procedurally seeded per galaxy at
  generation.** Approximately 10% of stellar systems by count
  surrounding the galactic core. The boundary does not move.
- **Mesh inheritance fires once per playthrough lifetime.** Not
  once per run. Not once per prestige. Lifetime, save-bound. The
  Architect Catalog Reading and Bloom Lineage Recognition follow
  the same rule.
- **The Custodian is unkillable, non-attacking, and follows the
  player.** No exceptions. No damage can be dealt to it. Its
  only departure condition is voluntary core withdrawal.
- **Purist Bloom cannot Pruning. Mechanically locked.** The
  Pruning UI does not appear for Purist players. The lore frame
  requires this.
- **The silence vector is procedurally seeded per galaxy.** Same
  galaxy, same vector. Saved at galaxy generation.
- **Tri-Faction Galaxy Events do not auto-resolve.** They
  contribute to endgame sequence triggers but the player must
  complete the run while the event is active.
- **Architect mediation of Bloom+Mesh alliance must be requested
  by either Bloom or Mesh.** The Architect cannot impose itself as
  mediator. The brokerage fee is embedded in the treaty text and
  visible to both parties.
- **Alliance dialogue variants are gated by Memory Tier.** Tier 5+
  unlocks Ancient annotation; Tier 7+ unlocks pre-schism
  references in commander voice; Tier 10+ unlocks the Address
  postscript appearing as an annotation on any active alliance
  treaty.

---

## 9. Open Questions

1. **Multi-player alliance compatibility.** If multiplayer
   eventually arrives, can two human players co-form an alliance?
   The mechanics support it — the treaty UI is bilateral and the
   shared Dominance Meter scales — but the PvP design isn't drafted
   yet. Defer to multiplayer session.
2. **The Custodian's voice.** It speaks one line on departure
   from a successful withdrawal. Should it speak at all during
   its visit? Probably not — the silence is the message — but
   worth testing. The Custodian as a *named character* with a
   minimal dialogue palette could be powerful or could be too on
   the nose.
3. **Inheritance equivalents for the Architect and Bloom — the
   30-pacification and 20-lineage thresholds.** Are these the
   right numbers? Probably tuned high to ensure the events feel
   earned, but a player who completes an entire playthrough as
   Architect without ever hitting 30 pacifications would feel
   robbed. Needs playtest data on average pacification count per
   playthrough.
4. **Brokered alliance dissolution.** When an Architect-mediated
   Bloom+Mesh alliance dissolves cleanly, does the Architect
   broker take a reputation hit or gain one? Lore could go either
   way. Currently designing toward "broker is paid for the work,
   not the outcome" — broker is paid up front via embedded
   clauses, dissolution does not refund. Validate with playtest.
5. **The Custodian and the Address.** A player who triggers the
   Custodian post-Address would be receiving the Custodian's
   silent attention while holding Fragment 7. Is there interaction
   between these two beats? Currently no. Possibly: the
   Custodian's footfalls during a Tier-7+ Address re-read carry an
   additional subsonic line, audible only on high-end audio. To
   spec.
6. **Tri-Faction Galaxy Events on Dual-Ruins maps.** The two
   procedural-rarity systems compound. The probability of both
   occurring simultaneously is very low (<0.1% per run). Should
   the simultaneous occurrence be a special unique event? Possibly
   the *only* run that triggers the endgame sequence via the
   third Tier 11 trigger condition. Worth designing as a "if it
   ever happens, it matters" rare cinematic. Defer.
7. **Galaxy state and save migration.** If save files migrate
   between game patches, the galaxy state's procedural seeds must
   be stable. Implementation note rather than design question.
