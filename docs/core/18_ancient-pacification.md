# The Ancient Pacification Economy — What the Ruins Ask For

> Session 7 output. Specifies the mechanic by which the player buys
> non-aggression from the Ancients after the first milestone. Closes
> open question 4 in `10_faction-lore.md §10` and open question 5
> (Fragment pacing). Adjacent to but distinct from the cross-prestige
> ritual at the Pilgrimage site's central chamber, which is covered
> later under the Memory Tier system.

---

## 0. Design Premise

After the first milestone, the Ancients are *present.* They are not
yet allied, not yet hostile, and — crucially — not yet on a fixed
schedule. The lore in `10_faction-lore.md §4` is specific: the
Ancients react to dominance. They intervene when the leading faction
peaks. They do not intervene when the leading faction is contained.

The pacification mechanic is the player's lever on that judgment.
It does not make the Ancients friendly. It buys *attention deferred.*
The Ancients receive what is offered, log it, and — for a measured
interval — decide that this player's faction is not yet the one
that needs correcting.

Five design goals frame the mechanic:

1. **Honor the Ancients' character.** They do not negotiate. They do
   not trade. They *receive.* A sacrifice is given without
   guarantee of reciprocation. The player has to decide whether the
   sacrifice was worth it after the fact, not before.
2. **Make the sacrifice cost identity-shaped.** Each faction
   sacrifices what defines it. The Architect gives up knowledge.
   The Bloom gives up life. The Mesh gives up connection. Each is
   the most expensive thing that faction has to give.
3. **Control Fragment pacing without scripting it.** Sacrifices
   sometimes yield Fragments. The player who pacifies frequently
   gets the Option B reveal faster than the player who refuses.
   That's intentional. The Ancients reward attention.
4. **Reward tactical attention to the map.** A sacrifice has to be
   carried to the Ruins. The carrier is interceptable. This is the
   post-milestone equivalent of the wave 3 flank collapse from
   `16_first-session-flow.md` — a new kind of pressure the player
   has to fold into their existing posture.
5. **Be skippable.** A player who never pacifies is playing a
   harder, stranger game — but a playable one. The mechanic is
   load-bearing for the lore arc; it is not load-bearing for
   survival.

---

## 1. The State Machine

The Ruins are not a single object with one state. They move through
five states across a run, and most of the mechanic lives in the
transitions.

| State | When | What's happening | Player can interact? |
|---|---|---|---|
| **Inert** | Wave 1 through first milestone | Visible on map. No pulse. No response to interaction. | No. The Ruins ignore the player. |
| **Active** | First milestone fires | Begins pulsing in rhythm with the Pilgrimage subsonic. Visual: low glow at the threshold tiles. | Yes, but only the carrier mechanic — no other actions register. |
| **Ritualized** | Player begins a sacrifice | Glow intensifies. A trail of low light appears between the player's base and the Ruins, marking the carrier's route. | Yes — the player is mid-ritual. The carrier can still die. |
| **Engaged** | Sacrifice received | Pulse synchronizes briefly with the carrier's heartbeat (or equivalent), then resumes baseline rhythm. The Ruins log the offering. | No — the Ruins are processing. Cooldown 90 sec real time. |
| **Reproached** | Player crosses a Dominance threshold without pacifying | Pulse becomes irregular. Color shifts away from baseline toward the faction-counter aura. An Ancient unit may appear here on the next dominance increment. | No interaction; the window for sacrifice has closed for this tier. |

The state machine is the player-facing surface of the mechanic. The
**Dominance Meter** is the player-facing surface of the *threat.*

---

## 2. The Dominance Meter

The Dominance Meter is a passive UI element that appears the moment
the Ruins activate. It tracks how strongly the player's faction is
expressing its win-state metric — the same metric the player drove
toward to hit their first milestone, but unbounded now.

| Faction | Dominance metric | Why it's the right metric |
|---|---|---|
| Architects | Compounded production rate × current research tier | The Architect identity in one number. Higher rate × higher tier = more total compounding. |
| Bloom | Biomass coverage % × adaptation library depth | Spread × resilience. The Bloom's two strengths multiplied. |
| Mesh | Hacked Node count × network topology efficiency | Steal rate × routing quality. The Mesh win condition expressed continuously. |

The meter fills smoothly during normal play. There are four
**thresholds** at 25%, 50%, 75%, and 100%. Crossing a threshold
triggers an Ancient counter-response *of the corresponding severity*:

| Threshold | Severity | Ancient response |
|---|---|---|
| 25% | Minor | Brief faction-counter pulse (~10 sec); Null Field / Sterility Pulse / Signal Drown at low intensity in a small area. |
| 50% | Standard | Faction-counter aura at full intensity for ~30 sec; affects the player's whole base. |
| 75% | Severe | Same as standard, plus an Ancient observer unit appears at the Ruins edge for one wave cycle. Speaks one line. Does not attack. |
| 100% | Reproach | Full Ancient response from `10_faction-lore.md §4`. Sustained debuff for two waves. The Ancient observer unit *does* engage briefly — not to kill, but to *visit damage* on the faction's most exposed production node. |

The meter does not reset on its own. It only drops via
pacification or via the player's faction *losing ground* — biomass
shrinking, hacked nodes being recovered by their owners, research
chain stalling. The Ancients respect natural humility.

---

## 3. What You Sacrifice — Faction-Shaped Cost

The sacrifice is *not* a generic resource payment. Each faction has
to offer up the thing that defines it. The mechanic is the same
across factions; the texture is different in a way that matters.

### Architects — Sacrifice of Data

The Architects offer **catalog entries.** A catalog entry is a
unit of accumulated research — the by-product of every Refinery
turn, every Foundry conversion, every successful wave defense at
Tier 2 or above. The player's catalog accumulates passively. It is
not a visible currency until the Ruins activate; at that moment it
becomes a third resource column in the HUD.

Catalog entries are most valuable when *recent.* A research result
from the last five minutes is worth multiples of one from an hour
ago. The Ancients prefer fresh observations.

- **What it feels like to spend:** The player explicitly *un-files*
  a recent research result. The Compiler that gained Cascade
  Optimization yesterday — the one specific entry that made it
  refund 4% per kill — is uncatalogued. The unit keeps the
  capability, but the *knowledge of how* is gone. The next time
  the Architect player wants to research a similar capability,
  they have to start over.

The Architect ritual lore frame: *"We learned. We will now un-know
it. The next learner will start where we did. This is the cost."*

### The Bloom — Sacrifice of Life

The Bloom offers **lineages.** A lineage is a Sporeling cohort or
Bramble-Walker line that has accumulated adaptations across deaths.
The fire-resistant cohort. The Mire-Beast with the +20% kinetic
resistance. The Bramble-Walker line that grew aerial-attack
tendrils after enough Drone encounters.

These are the Bloom's most expensive assets, full stop. They
represent hours of casualty learning. The Bloom does not have a
"resource pool" to draw from. It has a *memory.* The sacrifice
deletes the memory.

- **What it feels like to spend:** The player picks a lineage from
  a list. The Ruins receive the lineage. From the next wave forward,
  the Bloom faction *un-remembers* that adaptation. New Sporelings
  spawn without the fire resistance. The Mire-Beast template
  resets to baseline. The damage these units took to develop the
  trait was not deleted — but the lesson was.

The Bloom ritual lore frame: *"This one was kindling. They became
many. We give them back. The fire will come again, and we will
learn again. This is what the colony does."*

### The Mesh — Sacrifice of Connection

The Mesh offers **routes.** A route is a Hacked Node plus the
network topology supporting it — the Sub-Router connection that
makes the hack profitable. The Mesh's most valuable asset is not
any single hacked structure; it is the *graph* of connections that
turns isolated hacks into a network.

- **What it feels like to spend:** The player picks a Hacked Node
  from their active list. The node is offered to the Ruins. The
  hack terminates immediately. The structure reverts to its
  rightful owner. The Sub-Router connection that fed it is severed
  permanently — that specific routing path can't be re-established
  for the rest of the run. The Mesh can hack a *different*
  structure to replace it; they cannot hack along the same edge.

The Mesh ritual lore frame: *"Route closing. We had a connection
here. We are returning it. This edge of the graph will not be
recovered. We have other edges. We will recompute."*

### Why faction-shaped sacrifice matters

A generic resource sacrifice would let the player optimize: bank
resources, dump them, repeat. The faction-shaped sacrifice forces
each player to give up something *they don't want to give up.* The
Architect player will hold their best research result longer than
is rational because it took *forever* to get. The Bloom player
will mourn the loss of a specific cohort lineage they were proud
of. The Mesh player will resent severing the elegant routing they
spent ten minutes establishing.

This is the right feeling. The Ancients don't ask for what is
easy to give. They ask for what hurts.

---

## 4. Ritual Tiers and Conversion Rates

Three tiers of sacrifice. Player chooses at the Ruins interface.

| Tier | What you offer | Dominance Meter drop | Buffer | Fragment chance | Gift chance |
|---|---|---|---|---|---|
| **Minor** | Recent catalog entry / single mature unit / one Hacked Node | -15% of current meter | 1 threshold's worth of immunity (the next threshold won't trigger a response) | 0% | 0% |
| **Standard** | Tier 2 research entry / matured lineage / Sub-Router edge | -35% of current meter | 2 thresholds' immunity | 15% | 0% |
| **Deep** | Tier 3 / milestone-adjacent research, lineage, or routing | -60% of current meter + 10-minute "Observed" status | All remaining thresholds for the current cycle | 50% | 5% |

**Buffer mechanic:** When a sacrifice grants "immunity" to a
threshold, the next time the meter would trigger a response at that
tier, the response is suppressed and the immunity is consumed. The
Ancients accept the offering as proxy for the dominance event.

**Observed status:** While Observed, the Dominance Meter cannot
fill. The Ancients have decided to watch this player specifically.
This is the only mechanic in the game that fully pauses a faction's
core progression metric — it is rare, deliberate, and only
available via Deep sacrifice. Observed has a side effect: any
Fragment in the player's possession becomes *legible* in a way it
wasn't before. The Dreamer Mesh player who has been hoarding
Fragments will discover that during Observed they can re-read
Fragments and surface a new line of subtext per Fragment per
Observed window. This is the lore-curious player's reward path.

### Why these numbers

Drops are intentionally **percentile** rather than flat. A player
near 90% Dominance who Minor-sacrifices drops to ~76% — still
high, but back below the 75% threshold for one tier-worth of
breathing room. A player at 30% who Minor-sacrifices drops to ~25%
— effectively avoiding the next 25% trigger for some time.
Percentile drops keep the mechanic relevant at all meter levels.

The Standard tier is the **expected pace.** A player playing for
the Option B lore arc will Standard-sacrifice every milestone or
so, accumulating one or two Fragments per prestige cycle. This is
the pacing target for §10 open question 5 in `10_faction-lore.md`.

The Deep tier is the **gambler's path.** 5% Gift chance is
intentionally low. The Ancient Gift is a cross-sub-path ability —
the §4 lore reference to "the Ancients will, on rare conditions,
gift the player a sub-path ability the player did not unlock." A
Standard-path Architect who Deep-sacrifices five times across a
long run has a real chance of receiving a Spiritual-Tech
capability. The math is loose enough that it's not a strategy; it
is a *gift,* and feels like one.

---

## 5. The Ritual Loop — How a Sacrifice Plays Out

Pacification is a procedure. Eight steps from selection to result.

1. **Interface opens.** Player approaches the Ruins (camera moves
   to it; no menu pause). The Ruins surface in the UI as a special
   structure, with three tier buttons and an offering selector.
2. **Player selects an offering.** A faction-appropriate UI:
   - Architects see a catalog browser with timestamps. They scroll
     and pick.
   - Bloom sees a lineage tree. They pick a branch.
   - Mesh sees a network graph. They pick a node.
3. **The carrier spawns.** A faction-specific bearer unit
   materializes at the player's nearest Tier 2+ production
   building. The carrier walks toward the Ruins on autopath. It
   is slow. It is marked. It is single-HP-pool: any damage kills
   it.
   - Architects: a **Scribe-Drone** — a modified Drone visibly
     holding a glowing data shard.
   - Bloom: a **Spore-Pilgrim** — a single oversized Sporeling
     walking alone.
   - Mesh: a **Burst-Packet** — a translucent skittering construct
     leaving brief light trails.
4. **The trail lights.** A subtle path appears on the ground from
   the carrier's spawn point to the Ruins. This is informational
   for the player and for enemy targeting AI: waves that intersect
   the trail will prioritize the carrier.
5. **Carrier travels.** Standard route is the secondary axis (the
   one waves use for flanking). Travel time: 30–60 seconds
   depending on map size. The carrier is interruptible. If it
   dies, the sacrifice is *forfeited* — the offering is consumed
   by the dropped catalog/lineage/node, but no Dominance drop
   occurs, no buffer, no Fragment chance. The Ancients did not
   receive the gift; the player paid for nothing.
6. **Carrier reaches the Ruins.** The carrier dissolves into the
   threshold stone. The Ruins pulse intensifies briefly and the
   state transitions to **Engaged.**
7. **Processing — 90 sec real time.** The Ruins are not
   interactable. No further offerings until the cooldown clears.
8. **Result surfaces.** Dominance Meter drops. Buffer applies.
   Fragment rolls. Gift rolls. Any Fragment or Gift surfaces as a
   single one-line notification — the Ancients do not announce
   their generosity.

The 90-second processing window is a deliberate constraint. A
player can't chain-sacrifice through a crisis. Each ritual has
weight.

---

## 6. Faction Ritual Voice

The same ritual, three faction interpretations. Each maps to the
faction's voice rules from `10_faction-lore.md §1`.

### Architect ritual

The interface is a precise catalog browser. The carrier spawn line
is text-only, in the player's HUD:

> *Offering selected: Catalog Entry 4F-7c, Compiler/Cascade
> Optimization variant. Filing reversal initiated. Carrier
> deployed. Estimated transit: 47 seconds.*

The Scribe-Drone travel is silent. On Ruins contact:

> *Filing reversal complete. Result pending.*

When the result arrives, it is a single line. Fragment outcomes are
filed as anomalies the catalog does not recognize:

> *Anomaly recorded. Designation: ANT-029. Format unknown.
> Archived.*

Architects do not experience Fragments as gifts. They experience
them as data points they cannot yet contextualize. The Option B
reveal is coming for them through the Catalog, slowly.

### Bloom ritual

The interface is a lineage tree visualization. The selected
lineage is shown breathing — animation-wise, *alive* — until the
player commits. After commit, the carrier line is in faction voice:

> *The cohort that knew fire is being returned. Walk with them
> while we can.*

The Spore-Pilgrim moves slowly. The Bloom player will feel the trip
to the Ruins acutely — there is a sense of escort, even though the
unit is small. When the Pilgrim dissolves at the Ruins:

> *They are still ours. They are also yours now.*

Fragment results are framed as memories the colony has not yet had
time to compost:

> *We carried something we did not put down. We will carry it
> until we understand it.*

Bloom players experience the ritual as bereavement. This is by
design. The mechanic and the lore are aligned: giving up a lineage
*should* hurt, and the game says so.

### Mesh ritual

The interface is a network topology graph. The selected node and
its associated Sub-Router edge are highlighted in red. The
carrier line is in fragment Mesh voice:

> *Route 7-Kerath closing. Sub-edge severed. Packet dispatched.
> Latency estimate: 41 seconds.*

The Burst-Packet skitters fast for the first half of the trip,
then visibly slows as it approaches the Ruins — Mesh code does not
parse the Ruins protocol, and the packet itself is decompressing
into something the Ancients can read. On Ruins contact:

> *Handshake unrecognized. Packet accepted anyway. Logging.*

Fragment results are filed as buffer overflows that did not close —
the exact phrase from `10_faction-lore.md §0`:

> *Buffer overflow. Not closing. Filing as feature.*

The Mesh ritual is faster than the others by 20%. The Mesh
attempted to make the Ruins a system; the system refused; the
attempt itself was the offering. The Mesh player gets the
fastest ritual cadence and the highest Fragment rate of the three
factions. This is the Dreamer-path advantage made structural.

---

## 7. Failure Modes

### Carrier killed in transit

The most common failure. A wave's secondary axis probe finds the
carrier. The offering is consumed (the catalog entry, lineage, or
node is gone) but no benefit accrues. The Ruins return to **Active**
state.

The player who has just lost a Standard-tier carrier has
demonstrably wasted significant resources. The game does not
punish this further — but the Ancients log it. Repeated carrier
failures within a single run (3+) trigger an Ancient observer
unit appearance with one line:

> *The path has not been kept. Observation continues.*

This is the Ancients noting that the player tried and failed. It
is neither hostile nor friendly. The observer leaves after one
line. No combat occurs.

### Player begins ritual, then pushes for another dominance peak

The ritual completes, the Dominance Meter drops, but the player's
ongoing dominance growth can refill the meter before the buffer
expires. The buffer is consumed at the next threshold cross
regardless of *which side* of the threshold the meter is on.

This means a player who Minor-sacrifices at 60% and then climbs to
90% within the buffer window: the 75% threshold is suppressed (the
buffer eats it), but the 100% threshold fires normally. The buffer
was used; it just wasn't used efficiently.

### Player refuses to pacify

Entirely valid play. The Defector path against the Ancients.
- Counter-responses fire on every threshold.
- Severity accumulates. After 3 unpacified responses in one run,
  the next response is upgraded by one severity tier. After 5,
  upgraded by two tiers. A player who has refused pacification
  for the whole run will, at their next 100% threshold, receive
  a response normally reserved for end-game.
- Fragment generation slows substantially. Refusenik players see
  Memory Tier progression in their prestige slow to a crawl.
- *No gameplay-state is impossible.* A defector player can still
  win. They are playing the hard version.

The Ancients' line, after a fifth unpacified response in a single
run:

> *This world has been observed. The variance is now logged.*

This is the lore signal that the Ancients have decided this
specific faction-run is the *kind of civilization* that will not
survive convergence. The player's prestige will reflect this; see
the Memory Tier system in the next design pass.

### Over-pacification

Not actually possible. The Dominance Meter has a floor of 0% but
no penalty for being there. A player who sacrifices aggressively
will simply find that their Bloom lineages are baseline, their
Architect catalogs are sparse, and their Mesh routes are minimal —
the cost of over-pacification is *playing without the assets you
gave up.* The Ancients do not punish generosity. The faction does.

---

## 8. Interaction with Existing Systems

### Diplomatic relationships (`11_galaxy-politics.md §5–6c`)

The Ruins double as a **neutral site** for the resource-sacrifice
relationship-repair mentioned in `11_galaxy-politics.md §5`:

> *resource sacrifice at a neutral site*

A player who has been classified as a Designated Threat by the
Mesh can perform a *diplomatic ritual* at any Ruins on their map.
The diplomatic ritual is structurally similar to the pacification
ritual but the offering is different — the player offers what the
*other faction* would value, not what their own faction holds dear.
An Architect repairing Mesh relations sacrifices a route (a
Sub-Router edge the Mesh would value). A Bloom repairing Architect
relations sacrifices a Foundry building.

This is the only path by which a player can recover from a
sustained-defection cascade without prestige. It is expensive on
purpose.

The Ancients permit this use of the Ruins because they don't read
the offering's faction context the way the diplomatic faction does.
They see the gesture; they do not parse the politics. The
Architects, the Bloom, and the Mesh all interpret the gesture
through their own faction's diplomatic toolkit. The Ancients
*receive.* That is all they ever do.

### Wave commander dialogue (`12_wave-commanders.md`)

Tier 20–25 commanders, who already carry Option B hints, should
have additional dialogue variants that fire when the player has
pacified recently. The Bloom commander whose pre-attack line is
normally *"You will be soil"* gets a variant after the player has
just sacrificed a Bloom lineage:

> *You returned the cohort that knew fire. The colony noticed.
> So did we. You will still be soil.*

This is the enemy faction acknowledging the player's relationship
with the Ancients without acknowledging the Ancients themselves —
which is in voice for every faction.

### Cosmetics (`15_cosmetics-monetization.md`)

A prestige unlock for players who have completed 50+ Standard
sacrifices across all runs: the **Threshold Walker** palette. The
faction's units gain a faint trail-glow effect matching the
Ruins-pulse rhythm. Lore frame: *you have walked the path to the
Ruins enough times that you carry the rhythm with you.*

This is a non-gameplay cosmetic. Pure recognition of player
behavior pattern. No purchase option exists; it is earned only.

### Map structure (`17_units-maps-buildings.md §8`)

Dual-Ruins maps (~12% generation rate) allow the player to
pacify at *either* Ruins independently. The Dominance Meter is
faction-wide and applies to both. Carriers can be dispatched to
either. Failure modes apply at either. The dual configuration
does *not* halve the sacrifice cost — it simply doubles the
player's tactical options for ritual logistics on a map where
flank routes are unusually exposed.

Ancient observer units that appear on Dual-Ruins maps may appear
at *both* Ruins simultaneously. Players experiencing this for the
first time should be told nothing.

---

## 9. Hard Constraints (Implementation Checklist)

- **The Ruins are inert until the first milestone.** No
  pacification interface exists pre-milestone. This is also the
  rule from `16_first-session-flow.md`.
- **The Dominance Meter does not exist until the first milestone
  fires.** Pre-milestone, the player has no concept of dominance
  thresholds. Post-milestone, the meter is permanent UI.
- **Sacrifices are faction-shaped, not generic.** No resource
  payment option exists. The player must spend Architect catalog
  entries, Bloom lineages, or Mesh routes — never raw resources.
- **Carrier units are single-HP-pool.** Any damage kills them.
  This is not configurable. The mechanic depends on tactical
  risk; armoring the carrier would erase the design intent.
- **The 90-second processing window is hard.** No chain-sacrifice
  through a crisis. The cooldown applies even on failed (carrier-
  killed) attempts — the Ruins are unavailable for 90 seconds
  after a sacrifice begins, regardless of outcome.
- **Fragment and Gift rolls are independent.** A Deep sacrifice
  can yield neither, one, or both. The player cannot game the
  probability with sequential offerings; each roll is fresh.
- **Observed status cannot be self-renewed.** A player under
  Observed cannot Deep-sacrifice to extend Observed; the second
  Deep sacrifice will fire normally but produce no additional
  Observed window. The Ancients' attention is not a renewable
  resource.
- **Carrier route AI uses the secondary axis when present.** If
  the standard secondary axis is destroyed (rare, but possible
  on heavily reshaped maps), the carrier uses primary axis and
  the player should expect a higher interception rate. The route
  is not player-configurable.
- **No tutorial fires for the pacification mechanic.** The first
  milestone activates the Ruins and surfaces the Dominance Meter.
  That is the entire onboarding. The mechanic is discovered by
  attention. This is consistent with the design rule in
  `13_pilgrimage-site.md` that the receptacles are not explained.

---

## 10. Open Questions

1. **Sacrifice value drift.** Should the cost of pacification
   scale with run length? A Tier 3 lineage in hour 10 is harder
   to grow back than the same lineage in hour 1. Probably the
   *drop value* should scale (Deep gives less Dominance drop in
   late game) but the *cost* should not — the player will feel
   any cost increase as a tax. To test in playtest.
2. **Carrier visibility to other factions in multiplayer.** If
   the game eventually supports PvP, does the opposing player
   see the carrier? Probably yes — the trail is a tell, and a
   competitive opponent should be able to disrupt a ritual. But
   this is a multiplayer-design question, not a single-player
   one.
3. **Diplomatic ritual specifics.** §8's diplomatic-ritual
   variant needs its own offering table. An Architect offering
   to the Mesh sacrifices a route — but at what tier? The
   conversion needs prototype data. Defer to next pass when
   alliances are designed.
4. **Carrier voice during travel.** Each carrier could speak one
   short line halfway through its trip — a single sentence in
   faction voice that the player would hear in the audio mix.
   Possibly worth writing; possibly clutter. Defer.
5. **Cross-faction visibility of sacrificed items.** If the
   player has sacrificed three lineages, can a Bloom enemy wave
   commander reference them by name? The current commander
   dialogue draft does not assume this level of state-awareness.
   Could be a high-value lore detail in late-game waves; needs a
   pass on `12_wave-commanders.md` to evaluate.
6. **Memory Tier integration.** The cross-prestige version of
   pacification — the Pilgrimage central chamber ritual, the
   three-circle Mark, the multi-faction offering — lives in the
   Memory Tier design pass. This doc deliberately stops at the
   in-run Ruins. The connection between the two layers is the
   spine of the next session.
