# Open Questions — Resolution Sweep

> Session 13 output. A comprehensive pass over every "Open Questions"
> section in the design corpus (`core/10`–`core/22`). Each question is
> assigned a disposition and, where possible, resolved outright. The
> goal is to close the corpus: to leave no open design decision
> undocumented before the project moves toward a build.
>
> Roughly fifty questions were swept. This document is the single
> place to learn the status of any of them.

---

## 0. Purpose

The design corpus was built across eleven design sessions, and most of
its documents end with an "Open Questions" section — items the
authoring session surfaced but deliberately did not resolve.
Individually, each was a reasonable deferral. Collectively, ~50
unresolved questions scattered across the corpus are a real liability:
a builder cannot tell which gaps are decided, which are waiting on
playtest data, and which are genuinely out of scope.

This sweep closes that liability. Every open question is now either
resolved here, shown to have been resolved already by a later
document, or explicitly triaged — and where a question is deferred, it
is given a **ship default**: a concrete decision the build can proceed
on today, even where final tuning waits on data.

Nothing in this document overrides a Hard Constraint from an existing
core doc. Where a resolution adds a value or a rule to an existing
system, the originating doc remains the primary reference; the
amendments those resolutions imply are listed in §5.

---

## 1. Disposition Key

| Disposition | Meaning |
|---|---|
| **CLOSED** | Already answered by a later corpus document. No action needed; the cross-reference is given. |
| **RESOLVED** | Decided in this document. A design decision is made and stated. Treat as spec. |
| **PLAYTEST** | The decision is a number or a feel that genuinely needs data. A ship default is given to build and test against. |
| **BUILD** | An engineering/implementation decision, not a design one. Forwarded to the implementation-architecture work. |
| **DEFERRED** | Out of scope for v1 — multiplayer, art-direction exploration, the sequel, or a future content/writing session. Parked deliberately. |

Several items carry a **primary** disposition plus a **secondary** tag
(e.g., RESOLVED in design, with tuning left to PLAYTEST). These are
noted inline and counted by primary disposition in §3.

---

## 2. The Sweep

### core/10 — Faction Lore (§10 — 5 questions)

**Q1 — What is "the next thing"?** — **CLOSED.** Answered by
`core/14_endgame-threat.md`, which defines the Arrival, and extended by
`core/19` and `core/20` (the silence vector). The original directive —
tease it through Fragments, never show it — is now a permanent canon
rule (`codex/10_canon-rules.md`). The Arrival never gets a face.

**Q2 — Multiplayer Option B / PvP.** — **DEFERRED.** Out of scope for
v1; PvP is gated behind a shipped single-player build. The civil-war
energy of two players running opposite sub-paths of one faction
remains the most promising PvP seed; revisit it as its own session
once single-player exists.

**Q3 — Commander voice writing.** — **CLOSED.** Done by
`core/12_wave-commanders.md` for tiers 11–25. One writing thread
remains for the tier 26–50 coalition commanders — carried below under
core/12.

**Q4 — Ancient pacification economy.** — **CLOSED.** Fully designed in
`core/18_ancient-pacification.md`.

**Q5 — First-time-player Fragment pacing.** — **PLAYTEST.** Ship
default: the `core/16` pacing stands — first milestone at 4:00–5:00 of
play, first Fragment delivered at the first Collapse. The open worry is
whether new players actually reach milestone 1 within the intended 3–5
hour window. Instrument time-to-first-milestone and first-Fragment
sentiment; if data says retune, adjust the milestone *trigger
thresholds*, never the Fragment cadence (one per Collapse is a Hard
Constraint).

### core/11 — Galaxy Politics (§7 — 5 questions)

All five of `core/11`'s open questions were answered by later
documents. They are **CLOSED**:

| Question | Closed by |
|---|---|
| Neutral zone at the galactic core | `core/20` — the Neutral Core |
| Can factions form alliances | `core/20` — Alliances / super-treaties |
| What "the next thing" does to the galaxy map | `core/14` + `core/20` — the silence vector |
| Mesh inheritance of the core network | `core/20` — the Mesh Inheritance path |
| Bloom overgrowth as a player choice | `core/20` — Bloom Pruning (Assimilator-only) |

`core/11` is fully closed.

### core/12 — Wave Commanders (Implementation Notes — 1 thread)

**Coalition commander writing (tiers 26–50).** — **RESOLVED (design) /
DEFERRED (writing).** The design decision is made here: unlike the
one-shot tier 11–25 commanders, the tier 26–50 coalition commanders
are **persistent, recurring figures** who lead named forces across the
band. Cast size: **two to three recurring commanders per faction** —
not one per wave — each appearing multiple times so the player builds a
relationship with them. They carry the heaviest Option B material; by
this band the cracks seeded at tiers 20–25 have widened into
near-recognition. The line-writing is a content task, deferred to a
dedicated writing session in the mould of Session 1 — preceded by a
short roster bible (see §5).

### core/13–16 — No open questions

`core/13_pilgrimage-site.md`, `core/14_endgame-threat.md`,
`core/15_cosmetics-monetization.md`, and `core/16_first-session-flow.md`
each close with a Hard Constraints or Implementation section and carry
**no Open Questions**. Nothing to sweep — noted here so a reader knows
the omission is intentional, not an oversight.

### core/17 — Units, Maps, Buildings (§12 — 5 questions)

**Q1 — Cross-sub-path unit interactions** (e.g., an Assimilator
Chimera absorbing a Spiritual-Tech Warden's terrain-coupling pylon). —
**RESOLVED (design) / PLAYTEST (tuning).** Design ruling: cross-sub-path
absorption **works, and is embraced** — a faction literally wearing
another faction's technology is the seam of Option B made visible, and
the canon wants that. Mechanically: an absorbed component grants its
**baseline effect** but not its **sub-path synergy bonuses** — the
Chimera gains the Warden pylon's terrain-coupling buff, but cannot
chain it through Convocations the way a true Spiritual-Tech build can.
Numeric tuning of the baseline effect → playtest.

**Q2 — Hacked Node cap interaction with sub-paths.** — **RESOLVED.**
`core/17`'s floated option (a 3-cap for Dreamer Mesh, with two slots
freed for "Memory Nodes") is rejected: a 3-cap breaks the Mesh
milestone (hold 5 nodes). The Hacked Node cap stays **5 for both Mesh
sub-paths**, preserving the milestone and core/17's Hard Constraint.
No new "Memory Node" structure is introduced — it is unnecessary:
Dreamer Mesh's Fragment-farming identity is already fully delivered by
existing corpus content, the **Memory-Stack** milestone building
(`core/17` — one Fragment per wave cycle) and the **Anchor-Memory**
Tier 5 unit (`core/21` — Fragment-resonant). Networked and Dreamer are
differentiated by those distinct buildings and units, not by a
different node cap.

**Q3 — Bio-Titan vs. Apex matchup.** — **RESOLVED (design intent) /
PLAYTEST (numbers).** The late game must have counterplay, not pure
attrition. Ruling: the two signature units are **deliberately
non-mirror** and do not duel cleanly. The Apex out-damages anything but
is brittle; the Bio-Titan is near-unkillable, slow, and a
structure-crusher that self-spawns Sporelings. Neither hard-counters
the other — the matchup is decided by **map position and timing**. A
Bio-Titan that reaches the Apex's production base wins the economy war
before the Apex's uncapped scaling can matter; an Apex with range and
time wins before the Bio-Titan arrives. The Architect answer to the
Bio-Titan's spawn pressure is the Apex's Compile Cascade (AoE), not a
damage race. Exact stat tuning → the balance pass.

**Q4 — Tertiary axis frequency on Dual-Ruins maps.** — **RESOLVED.**
Raise it: tertiary-event frequency goes from the standard ~1-in-8
waves to **~1-in-6** on Dual-Ruins maps. More Ruins means more Ancient
activity, which is thematically correct, and it gives the rare map a
distinct rhythm an attentive player can feel.

**Q5 — Production building placement on tertiary points.** —
**RESOLVED.** Allow it, at a premium: tertiary-point construction costs
**+50% build cost**. Late-game players can fortify their incursion
points; new players will not bother, so the surprise of an early
tertiary event is preserved.

### core/18 — Ancient Pacification (§10 — 6 questions)

**Q1 — Sacrifice value drift (should cost scale with run length?).** —
**RESOLVED.** Per core/18's own leaning: the *drop value* scales **down**
across a long run — a Deep sacrifice yields a smaller Dominance-Meter
drop the deeper into a run it happens — but the *cost* of a sacrifice
**never increases**. A rising cost reads to the player as a tax on
survival; a shrinking benefit reads as natural diminishing returns.
Adopt the shrinking-benefit model.

**Q2 — Carrier visibility to other factions in multiplayer.** —
**DEFERRED.** Multiplayer is out of scope for v1.

**Q3 — Diplomatic ritual offering table.** — **RESOLVED (structure) /
BUILD (numbers).** The diplomatic ritual — repairing a damaged faction
relationship by offering what the *other* faction values — is
structured by severity: a **Watch-Listed** standing clears with a
Standard-equivalent offering; a **Designated Threat** standing requires
a Deep-equivalent. The diplomatic offering is priced **one tier above**
the equivalent pacification offering: buying back trust costs more than
deferring attention. Exact conversion values → implementation/balance.

**Q4 — Carrier voice during travel.** — **RESOLVED.** Include it: each
carrier speaks **one short faction-voiced line at the midpoint** of its
trip to the Ruins. It is not clutter — it reinforces the
escort-and-bereavement feeling core/18 explicitly wants (most of all
for the Bloom Spore-Pilgrim), and "story in the seams" is the IP's
whole delivery model. A small writing task, folded into the next voice
session.

**Q5 — Cross-faction visibility of sacrificed items.** — **RESOLVED.**
Yes, but tightly scoped. A tier 20+ wave commander may reference the
*type* of the player's **most recent** sacrifice — not a running
catalogue. One such variant line per faction, gated on a recent
sacrifice. This extends the pacification-aware commander variants
core/18 §8 already established. Writing folded into the next voice
session.

**Q6 — Memory Tier integration.** — **CLOSED.** Designed in full by
`core/19_memory-tiers.md`.

### core/19 — Memory Tiers (§11 — 6 questions)

**Q1 — Token-tier offering pacing (+5 vs. +8 brightness).** —
**PLAYTEST.** Ship default: **+5**, as written. The worry is whether a
brutally hard, asset-stripped run feels penalized by the minimum
offering. Instrument Mark-brightness gain on low-asset runs and player
sentiment after a forced or Token Collapse; if survival-mode players
feel cheated, raise to +8.

**Q2 — Faction-switch nudging.** — **RESOLVED.** No nudge. The
Convergence palette unlocking on the first faction switch is the entire
signal, and that is correct. A directive highlight on un-played wings
would violate the IP's core delivery rule — "the player either sees it
or they don't." The game does not push the player toward Option B; it
lets them find it.

**Q3 — In-run receptacle items / a Custodian achievement for visiting
all stored offerings.** — **DEFERRED.** Feature creep for v1, per
core/19's own assessment. A pleasant post-launch addition; not a gap.

**Q4 — Memory Tier annotation accessibility.** — **CLOSED.** Resolved
by `core/22 §10`: annotations are screen-reader-legible and carry an
explicit text-flag marker, never visual decoration alone.

**Q5 — Sequel transition / Tier 11 as the pre-sequel save state.** —
**RESOLVED (forward-compat constraint) / DEFERRED (the sequel
itself).** The sequel is out of scope. But one decision must be honored
*now*: the Tier 11 save state is the designated pre-sequel handoff, so
the **Tier 11 save schema must not be broken** by any later patch — a
future sequel build must be able to read a Tier 11 save and open the
world in its silenced-outer-arms state. This is a standing
forward-compatibility constraint on the save model (forwarded to the
implementation work).

**Q6 — PvP intersection (Memory Tier asymmetry between players).** —
**DEFERRED.** Multiplayer, out of scope for v1.

### core/20 — Galaxy Strategy (§9 — 7 questions)

**Q1 — Multi-player alliance compatibility.** — **DEFERRED.**
Multiplayer, out of scope for v1. (Noted: the alliance UI is already
bilateral and the shared Dominance Meter already scales, so the systems
would not fight a future PvP build.)

**Q2 — The Custodian's voice.** — **RESOLVED.** The Custodian speaks
**only** its one departure line ("Withdrawal logged. Variance
permitted."). It is silent throughout its visit. The silence *is* the
message; the 30% ambient-sound drop and the subsonic footfalls carry
the dread without dialogue.

**Q3 — Inheritance-equivalent thresholds** (30 pacifications for the
Architect Catalog Reading, 20 lineages for the Bloom Lineage
Recognition). — **PLAYTEST.** Ship defaults: **30** and **20**, as
written. These must feel earned but must be reachable in a normal full
playthrough. Instrument median pacification and lineage counts per
playthrough; if the median player finishes without reaching their own
faction's deepest moment, lower the numbers.

**Q4 — Brokered alliance dissolution (does the Architect broker gain
or lose reputation?).** — **RESOLVED.** Neither. Per core/20's leaning:
the broker is paid for the work, not the outcome. The Architect's
brokerage fee is embedded in the treaty up front; a clean dissolution
by treaty review neither refunds the fee nor adjusts reputation. The
broker did the job; the job is done.

**Q5 — The Custodian and the Address interaction.** — **RESOLVED.**
Include the deep-cut beat: if the Custodian is present during a
Tier-7-or-later re-read of the Address, its footfalls carry **one
additional subsonic line**, surfaced via high-end audio and via the
accessibility visual-pulse option. Cheap to build, on-theme, and a
genuine reward for the player who reads closely.

**Q6 — Tri-Faction Galaxy Event on a Dual-Ruins map.** — **RESOLVED.**
Yes — when both rarities co-occur (probability <0.1% per run), treat it
as a **designated unique event**: a guaranteed Tier 11 endgame trigger
with a one-off cinematic framing. The principle is "if it ever happens,
it matters" — the rarest state the procedural systems can produce
should never be a shrug.

**Q7 — Galaxy state and save migration (stable procedural seeds).** —
**BUILD.** The galaxy's procedural seeds — the Neutral Core boundary
and the silence vector — must be persisted at galaxy generation and
remain stable across patches. An engineering constraint; forwarded to
the implementation-architecture work.

### core/21 — Late-Game Progression (§9 — 7 questions)

**Q1 — Tier 4 / Tier 5 cost balance.** — **PLAYTEST.** Ship defaults,
per core/21's own estimate: Tier 4 ≈ **2×** Tier 3 resource cost,
Tier 5 ≈ **4×** Tier 3. Fine-tune in the balance pass against the
mid-late production curve.

**Q2 — Tier 6 unit production resource costs.** — **PLAYTEST.** Ship
default: Tier 6 units are priced against the **post-milestone**
economy, not the pre-milestone one — roughly as routine, relative to
economy size at that stage, as a Tier 3 unit is pre-milestone. Tune in
the balance pass.

**Q3 — Second Milestone "submit" balance (easy mode or hard mode?).** —
**RESOLVED (intent) / PLAYTEST (validation).** Design intent, fixed:
submitting to a Second Milestone is **not** easy mode. It keeps the
faction efficient but takes away authorship — the player becomes an
overseer of a system making choices that visibly cost them things they
wanted. The target feeling is *unsettling*, not *relaxing*. Playtest
validates the feeling; if "submit" reads as a pure power-up, add
friction until the autonomous system's choices sting.

**Q4 — Cross-faction Second Milestone visibility.** — **RESOLVED.**
Yes, lightly: a **galaxy-map glyph** marks an NPC faction that has
entered a Second Milestone. No notification. It is strategically
meaningful — a faction collapsing inward will behave differently — and
it is evocative.

**Q5 — Second Milestone audio/visual.** — **DEFERRED to the
audio/visual choreography pass.** Each Second Milestone needs a trigger
cue and an ambient shift; that is choreography work — the project's
other named design-gap thread — and belongs there, not here.

**Q6 — Tier 4 unit as a higher-status pacification carrier.** —
**RESOLVED.** No. core/18's Hard Constraint — carrier units are
single-HP-pool, any damage kills them, not configurable — is
load-bearing for the ritual's tactical risk. A Tier 4 carrier could not
be made more survivable without breaking that rule, and would otherwise
add nothing. Keep the dedicated faction carriers (Scribe-Drone /
Spore-Pilgrim / Burst-Packet).

**Q7 — Research Tier display.** — **CLOSED.** Resolved by `core/22 §3`:
the research tree visualization, three faction metaphors (tech tree /
growth tree / topology graph) over one shared R1–R5 spine.

### core/22 — Interface Design (§12 — 7 questions)

**Q1 — Mobile / touch viability.** — **RESOLVED (commitment) /
DEFERRED (layout study).** Decision: **mobile is a first-class
target.** The game's whole profile — short sessions, idle-friendly, the
produce-now tap affordance, progressive disclosure — was built for it.
The commitment is made now so later design respects it. The dedicated
mobile-layout study (treaty-panel density, the research tree on a small
screen) is its own UI pass, deferred but scheduled.

**Q2 — Controller support depth.** — **DEFERRED.** Platform-dependent.
Production-stack controller cycling is already committed (`core/22
§10`). Whether the full interface — galaxy map, treaty negotiation,
research tree — is controller-complete waits until platform targets are
fixed.

**Q3 — Notification flood handling.** — **RESOLVED.** A **digest card**
groups similar incidents. On return from a long absence, queued
incidents of the same type collapse into one grouped card;
time-sensitive incidents still surface individually. The notification
stack never scrolls indefinitely.

**Q4 — Production stack scaling (15+ buildings).** — **RESOLVED.**
Horizontal scroll (already specced) plus a **filter toggle by tier**.
Most-recently-interacted buildings already sort left; the tier filter
handles the maxed-out base. No grouping rework needed.

**Q5 — First-session prompt integration / handoff to the notification
system.** — **BUILD.** The `core/16` faction-voiced tutorial prompts
must hand off cleanly to the `core/22` notification system when the
tutorial ends. An implementation-sequencing detail; forwarded to the
build.

**Q6 — Galaxy map and the Pilgrimage — separate spaces or one
meta-screen?** — **RESOLVED.** Separate, as core/22 currently designs
them: the Pilgrimage is navigable space, the galaxy map is an overlay
summoned from it. The transition should be validated for coherence in
playtest, but the design decision is settled — do not merge them.

**Q7 — Diegetic vs. overlaid HUD.** — **DEFERRED to an art-direction
pass.** The two-second-readability rule (a Hard Constraint) takes
priority and is satisfied by the conventional overlaid HUD. A diegetic
HUD — the interface as faction technology projected by the player's own
units — is an art-direction exploration, not a systems-design gap.

---

## 3. Summary Tally

| Disposition | Count | What it means for the build |
|---|---|---|
| **CLOSED** | 11 | Already answered elsewhere in the corpus. |
| **RESOLVED** | 23 | Decided here. Treat as spec. |
| **PLAYTEST** | 5 | Build the ship default; instrument; tune on data. |
| **BUILD** | 2 | Engineering decisions for the implementation work. |
| **DEFERRED** | 8 | Deliberately out of scope for v1. |

Forty-nine questions, swept. Several RESOLVED items also carry a
secondary tag — a number left to playtest, a value left to the build,
or a sub-part parked — but in each the *design* itself is settled;
only the tuning remains.

The corpus no longer has an undocumented open design decision. Every
gap is now either closed, decided, or parked with a reason.

---

## 4. The Forward Queue

What remains genuinely open, consolidated into four backlogs.

### Playtest backlog (ship the default, tune on data)

- First-milestone pacing — target 4:00–5:00 of play, 3–5 hour window.
- Token offering brightness — default +5.
- Inheritance-equivalent thresholds — default 30 pacifications / 20
  lineages.
- Tier 4 / Tier 5 unit costs — default 2× / 4× Tier 3.
- Tier 6 unit costs — priced against the post-milestone economy.
- Plus tuning on resolved items: cross-sub-path absorption values,
  Bio-Titan vs. Apex stat lines, Second Milestone "submit" friction.

### Build backlog (for the implementation-architecture work)

- Stable, persisted procedural seeds for the galaxy (Neutral Core
  boundary, silence vector) — survive patches.
- Tier 11 save-schema forward-compatibility constraint — must remain
  readable by a future sequel build.
- Tutorial-prompt → notification-system handoff sequencing.
- Diplomatic ritual offering-table values.

### Content / writing backlog (a future voice session)

- Tier 26–50 coalition commanders — 2–3 recurring per faction, heaviest
  Option B material. Needs a roster bible first (see §5).
- Carrier midpoint voice lines — one per faction.
- Sacrifice-aware tier-20+ commander variants — one per faction.

### Out of scope for v1 (deliberately parked)

- All multiplayer / PvP work (`core/10 Q2`, `core/18 Q2`, `core/19 Q6`,
  `core/20 Q1`).
- Custodian "visit all stored offerings" achievement (`core/19 Q3`).
- Controller-completeness beyond the production stack (`core/22 Q2`).
- Diegetic-HUD art exploration (`core/22 Q7`).
- The sequel itself (`core/19 Q5` — though its save-compat constraint
  is honored now).

The two remaining *named* design-gap threads — the **late-game balance
pass** and the **audio/visual choreography pass** — are not in these
backlogs because they are substantial design work in their own right,
not loose questions. They remain available as future sessions.

---

## 5. Amendments the Resolutions Imply

The resolutions in §2 add a few concrete values and rules that the
originating documents do not yet carry. These small annotations should
be made so each core doc stays self-consistent; none changes a Hard
Constraint.

- **`core/17 §8` (map spec)** should record two new values from §2:
  tertiary-event frequency is **~1-in-6** on Dual-Ruins maps (vs.
  ~1-in-8 standard), and tertiary-point construction carries a **+50%
  build-cost premium**.
- **`core/17 §4` (the Chimera)** should note that Component Digestion
  explicitly accepts cross-faction *and* cross-sub-path components,
  granting the baseline effect but not sub-path synergy bonuses.
- **`core/18`** should note the carrier midpoint voice line and the
  shrinking (not rising) sacrifice-drop value as confirmed design.
- **`core/21`** should note the Tier 6 costing principle
  (post-milestone-economy relative) and the cross-faction Second
  Milestone map glyph.

One genuinely **new task** surfaced: before the tier 26–50 coalition
commanders can be written, they need a short **roster bible** — names,
the named force each leads, and the multi-appearance arc each follows
across the band. This is a design-lite task that should precede the
writing session, not be folded into it. It is the one piece of net-new
design work this sweep created.
