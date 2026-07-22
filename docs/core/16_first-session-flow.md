# First Playable Session Flow

> Session 5 output. Maps the complete new player experience from first launch
> through first faction milestone (~3-5 hours). Structured as a sequence of
> moments: what the player sees, what they do, what the game teaches, what
> they feel. This is the design spec for the tutorial build.

---

## Design Spine

The first session teaches five things in order, each one building on the last:

1. **This world is old and strange.** (Academy / Pilgrimage opening)
2. **Passive defense works — until it doesn't.** (Waves 1-3, intentional flank collapse)
3. **Active play raises the ceiling.** (Waves 4-7, unit production)
4. **You are a specific kind of player.** (Sub-path commit)
5. **Something has been watching.** (First milestone, Ancient activation)

The player never reads these as lessons. They experience them as events.

**Emotional arc:** Wonder → Competence → Identity → Mastery → Revelation

---

## Chapter 0 — Arrival at the Pilgrimage
*Time: 0:00 – 0:03*

The game opens not on a title screen but on the Pilgrimage site from orbit.
No UI. No prompts. The ring wall is visible as a geological feature. The
camera descends slowly. The player has not pressed anything yet.

At ground level: the central chamber. Too large. Too quiet. The low-albedo
stone absorbs the light. A subsonic pulse moves through the floor. The
player's first unit — a single cadet, no faction insignia — stands in the
center beneath the celestial aperture.

Five seconds of nothing. Then a single line of text, no speaker attributed:

*"Before you are assigned, you will be observed."*

The Academy begins.

**Player feels:** Curiosity. Slight unease. Something here is older than they
are and it knows it.

---

## Chapter 1 — The Academy
*Time: 0:03 – 0:12*

Three scenarios. Each 60-90 seconds of active play. No wrong answers stated.
No scores shown. The game observes.

**Scenario 1 — Base under simultaneous attack from two directions**
Two enemy probes approach from opposite angles simultaneously. Three response
options available (defend production chain / defend territory edge /
counterattack the weaker probe). No instruction on which to choose. The player
acts on instinct.

**Scenario 2 — Surplus resources mid-wave**
A wave is in progress. The player has more resources than needed. Build the
next production tier? Expand the perimeter? Launch a probe at the incoming
wave? No guidance.

**Scenario 3 — Ancient Ruins appear on the map edge**
Mid-scenario, a Ruins marker appears. The player can send a scout, observe
from a distance, or ignore it. The Ruins do not respond to any interaction —
inert. This is intentional. The player now has a relationship with Ruins before
their first procedural map.

**Sorting output:**
Camera pulls back to the full chamber. Three faction sigils appear above the
containment stamp on the floor, illuminated by instinct-match degree.

One line per recommendation, in faction voice:
- *Architects: "Efficiency potential assessed. Path available."*
- *Bloom: "You watched before you moved. We noticed."*
- *Mesh: "You found the weak point first. Good."*

Player accepts top recommendation, chooses differently, or declines entirely.
Declining: a fourth blank sigil appears — *"The unsorted cadets remember things
they were never taught."* Harder start, Dreamer sub-path nudge at Tier 2.

**Player feels:** Seen. The game has watched them and drawn conclusions. They
are now thinking about what kind of player they are. That is the point.

---

## Chapter 2 — First Map, First Build
*Time: 0:12 – 0:35*

**The transition:**
Faction selected. The Pilgrimage chamber fades. For exactly two seconds, the
player's chosen faction color washes across the Ancient stone. The chamber
briefly lit in Architect amber, or Bloom green-gold, or Mesh blue. Then the
map loads. The game does not explain this. The Pilgrimage site acknowledged
the choice. That is all.

**First map placement:**
Outer arm. Low hazard. Three things visible immediately: starting position,
two resource nodes, and — at the map edge — an Ancient Ruins marker.

No tutorial popup fires yet. Thirty seconds to explore freely.

**First prompts (minimal, integrated, never modal):**
Brief faction-voiced annotations on relevant elements. Never separate UI
windows that pause the game.

- Resource node prompt: faction-voiced, one line. Player clicks to connect.
  First idle tick fires. Resources accumulate. A moment passes — long enough
  to feel the idle layer working.
- Defensive structure prompt: Player places first tower/thorn/trap. Auto-targets
  a training dummy. Fires. Destroys it. No explanation required.
- Production structure prompt: Player builds first unit-production facility.
  Thirty-second cooldown begins. First unit produces.

**Player feels:** Capable. The systems are readable. The game is responsive.

---

## Chapter 3 — The First Waves
*Time: 0:35 – 1:15*

**Wave 1 — Primary axis only, single unit type**
Tower handles the wave without player input. Resources awarded.
*Lesson (no text):* Passive defense works.

**Wave 2 — Primary axis, slightly more units**
Tower handles it again, takes more shots. Economy visibly growing.

**Wave 3 — Primary axis + secondary axis flank probe**
The main assault approaches — tower handles it. Simultaneously, a smaller
probe appears on the secondary axis. No tower covers that angle. No prompt
has fired to explain flanking yet. This was deliberate.

The flank probe hits. A resource node takes damage. A Tier 1 structure may
be briefly disrupted. Not catastrophic. But the player watched it happen and
could not stop it.

After the wave, the faction-voiced prompt fires:
- *Architects: "Secondary axis breach. Coverage gap documented. Unit production addresses this."*
- *Bloom: "The tendril found the gap. A defender placed there would have held it."*
- *Mesh: "You covered the front. They went around. Always go around."*

Unit production tutorial unlocks now — but the player already knows why they
need it. The lesson was the damage, not the text.

**Player feels:** Caught off-guard, then immediately oriented. The game was
not unfair — it showed them a gap and let them feel it before explaining how
to close it.

---

## Chapter 4 — Learning Active Play
*Time: 1:15 – 2:00*

**Waves 4-5:** Player uses unit production to intercept secondary axis probes.
First time a player-produced unit defeats a flanking enemy: the unit's
faction-specific idle animation plays briefly. No reward text. No points pop.
*I made that. It did something.*

**Wave 6:** First named enemy commander (tier 11). Pre-attack line plays.
Commander is defeated. Defeat line plays. The player may not catch every word.
They will remember there was a voice.

**Sub-path nudge:** If player behavior has been consistent with a sub-path
lean, a faint glow appears on the heresy branch in the tech tree. No
annotation. No explanation.

**Wave 7 — First cross-faction pair:**
Two factions attacking together. Announced as a temporary alliance.
Architect-type units target the production chain. Bloom-type units target
territory. Player cannot cover both perfectly. Makes a choice. Wave ends.
Player now knows different enemy types want different things.

**Player feels:** The loop is real. They are making meaningful choices, not
just clicking timers.

---

## Chapter 5 — The Engine Running
*Time: 2:00 – 2:45*

**The idle inflection point:**
Around wave 7-8, idle production has compounded enough that the player
briefly has more resources than they need. Faction-specific expression:
- Architects: upgrade cascade — one unlocks another in the same cycle
- Bloom: biomass spreads to a second node without player direction
- Mesh: enough bandwidth to hack a structure in the incoming wave

The player notices the moment. The idle loop has delivered its promise.

**Waves 8-10 — Pattern recognition:**
Player is anticipating waves before they land, not just reacting. Mastery
beginning to form. Ruins at map edge remain inert.

**Sub-path commit fires (between waves 9 and 10):**
The wave timer pauses. The only pause in the first session. The tech tree
opens. Two branches visible.

Faction framing:
- *Architects: "The standard optimization path is available. An alternative configuration has been flagged. Committing to one closes the other."*
- *Bloom: "The colony has reached the branching point. Two growth strategies are available. The network cannot hold both."*
- *Mesh: "Fork in the protocol detected. Standard network path. Or — the other one. Decision required before next wave."*

Player commits. No commentary from the game on their choice. Timer resumes.
Wave 10 hits.

**Player feels:** Invested. They are now a Spiritual-Tech Architect or a
Purist Bloom or a Dreamer Mesh. Identity within identity.

---

## Chapter 6 — The Milestone Push
*Time: 2:45 – 4:00*

**Named commanders become the enemy's civilization:**
From wave 11 onward every wave has a named commander. Player accumulates
voices. Tier 11-19 commanders are pure faction voice — no cracks, no Option B
hints yet. Player builds a picture of the enemy as a civilization, not just
a threat.

**The milestone path becomes visible (~wave 12-14):**
A progress indicator appears at the edge of the UI that wasn't there before:
- Architects: Research chain progress bar. Nexus Core blueprint unlocked.
- Bloom: Biomass coverage percentage, 60% threshold highlighted.
- Mesh: Node count tracker. Five simultaneous nodes is the goal.

Player now has a destination. Everything points to the same objective.

**Waves 16-20 — The final approach:**
The hardest waves before the milestone. Resources tight from milestone
investment. Secondary axis probes are dangerous. Two or three waves will
feel genuinely close. The player may lose a production structure.

Commander voices in waves 17-19 land differently when the player is two
waves from their milestone. The enemy is trying to prevent exactly what the
player is trying to do.

**Player feels:** Stretched. The milestone should feel earned, not inevitable.

---

## Chapter 7 — First Milestone
*Time: 4:00 – 5:00 (faction-dependent)*

**The milestone fires:**
- Architects: Nexus Core completes. Research chain resolves. Upgrade cascade.
- Bloom: Coverage crosses 60%. Map shifts color — deeper, darker.
- Mesh: Five nodes held sixty seconds. Network cascade unlocks.

**The Ruins activate.**

The Ancient Ruins marker — inert since wave 1 — begins to pulse. The same
rhythm as the Pilgrimage site's subsonic pulse. The player has felt this
before without knowing it.

The screen desaturates to near-grey. No announcement. No notification.

An Ancient unit appears at the edge of the Ruins. It does not move toward
the player. It does not attack. It delivers one line:

- vs. Architects: *"The compound has reached terminal efficiency. Observation confirmed."*
- vs. Bloom: *"The world has been claimed. Observation confirmed."*
- vs. Mesh: *"The network has taken the walls. Observation confirmed."*

It emits the faction-counter response (Null Field / Sterility Pulse / Signal
Drown). Temporary. The player weathers it. Color returns to the map.

The Ancient unit is gone.

A single notification: *"First milestone reached. New wave tiers available. Ruins: active."*

No fanfare. No rewards screen. The game continues, harder than before, with
a new feature on the map and a new question in the player's mind.

**Player feels:** The world got larger. Something that was background became
foreground. The Ruins are there. The player knows what the Academy scenario
meant. They want to know what happens when they approach it now.

---

## Flow Summary

| Chapter | Time | Core event | Lesson delivered |
|---|---|---|---|
| 0 — Arrival | 0:00-0:03 | Pilgrimage site, opening | This world is old |
| 1 — Academy | 0:03-0:12 | Sorting scenarios | You are a specific kind of player |
| 2 — First Build | 0:12-0:35 | Map placement, first structures | The three layers exist |
| 3 — First Waves | 0:35-1:15 | Waves 1-3, flank collapse | Passive has limits; feel it first |
| 4 — Active Play | 1:15-2:00 | Waves 4-7, unit production | Active play raises the ceiling |
| 5 — Engine Running | 2:00-2:45 | Idle inflection, sub-path commit | You are committed now |
| 6 — Milestone Push | 2:45-4:00 | Waves 11-20, named commanders | The enemy has a civilization |
| 7 — First Milestone | 4:00-5:00 | Milestone fires, Ruins activate | Something has been watching |

---

## Hard Constraints (Implementation Checklist)

- The Pilgrimage site is the Academy space. No other location.
- The flank collapse in wave 3 is **never prevented by the tutorial.** The
  tooltip fires after, not before.
- The sub-path commit pauses the wave timer. This is the only pause in the
  first session.
- The Ancient unit at the milestone **does not speak faction-specific wisdom.**
  It confirms observation. That is all.
- The Ruins are visible from wave 1 and inaccessible until the milestone. No
  tooltip explains them. Their activation is the payoff for the player who
  noticed them.
- The first Ancient appearance is never announced. No "ANCIENT UNIT DETECTED"
  notification. It simply appears. The desaturation is the signal.
