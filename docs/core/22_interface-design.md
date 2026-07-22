# Interface Design — The Unified HUD and Systems UI

> Session 11 output. Consolidates every HUD, panel, notification, and
> interface element the corpus has accumulated across sessions 1–10
> into one coherent design system. Establishes the progressive-
> disclosure model that lets the same interface serve a five-minute
> idle check-in and a one-hour active session. Closes `21 §9 Q7`
> (research tree visualization) and `19 §11 Q4` (annotation
> accessibility), and specifies the faction-skin language for the UI.

---

## 0. Design Premise

The game is three games sharing one screen: an idle miner, a tower
defense, and an RTS. A player with five minutes and a player with
an hour are both "playing the game" (`10_faction-lore.md §9b`). The
interface is the single surface that has to make both true.

Across ten design sessions the corpus has named dozens of UI
elements — the Dominance Meter, the research tree, the treaty
columns, the Singularity Recommendations HUD, the Memory Tier
reader, the pacification offering selectors, the galaxy map, the
wave axis indicator — without ever specifying how they coexist.
This pass is that specification.

Six rules constrain everything below:

1. **Progressive disclosure.** The core HUD is minimal and
   glanceable. Depth is *summoned*, never imposed. A player who
   never opens a panel still plays a complete game.
2. **Never modal.** The interface never blocks gameplay. There
   are exactly two exceptions, both justified below: the sub-path
   commit and the return-from-offline summary.
3. **Readability is inviolable.** The constraint from
   `15_cosmetics-monetization.md` extends to the UI: faction
   color coding, unit silhouettes, and combat tells are never
   compromised by interface skinning.
4. **Layout is constant; texture is faction-specific.** Resources
   are always top-left. Waves are always top-right. Production is
   always the bottom edge. A player switching factions relearns
   the *texture* of the UI, never the *map* of it.
5. **The world and the HUD are connected.** HUD elements have
   on-map counterparts. The Dominance Meter pulses with the Ruins.
   The wave panel's axis diagram matches the actual map geometry.
   The interface is not a layer on top of the game; it is a
   reading of the game.
6. **The Pilgrimage is the calm.** In-run UI is dense and busy.
   The between-run Pilgrimage interface is deliberately sparse and
   slow. The contrast is a design feature, not an inconsistency.

---

## 1. The Core HUD — The Always-Visible Layer

The core HUD is the only interface visible by default during a
run. It must be fully readable in under two seconds. Four
clusters, fixed positions.

### Top-left — Resource cluster

Faction-specific resource readouts. Each resource shows current
total and a trend indicator (rising / stable / falling).

| Faction | Resources displayed |
|---|---|
| Architects | Ore, Alloy, Power, Catalog (Catalog appears only post-first-milestone) |
| Bloom | Biomass, Surplus Biomass (Surplus appears only during Biosphere II) |
| Mesh | Resource, Bandwidth, Hacked-Node yield (aggregated) |

The Architect cluster is the most numeric — exact figures,
projected per-minute rates on hover. The Bloom cluster is the
least numeric — Biomass reads primarily as a filling visual, with
the exact number available on hover. The Mesh cluster emphasizes
*flow* — rates are shown larger than totals, because the Mesh
economy is about throughput, not stock.

### Top-right — Wave panel

- **Countdown** to the next wave.
- **Axis diagram** — a small directional schematic matching the
  map's actual primary/secondary/tertiary geometry
  (`10_faction-lore.md §9b`). Pressure on each axis is shown as a
  weight on that arm of the diagram. A player learns to read the
  diagram instead of the map edge.
- **Wave tier number.**
- **Commander portrait** — appears for tier 11+ waves, the named
  commander from `12_wave-commanders.md`. Tapping the portrait
  replays that commander's last line.

### Bottom edge — Production stack

A horizontal row of the player's production-hybrid buildings
(`17 §3,5,7`). Each entry shows:

- The building's cooldown ring (filling toward next auto-produce).
- A **produce-now affordance** — the RTS layer's primary control.
  Tapping spends current resources to trigger production
  immediately.
- A small unit icon indicating what the building produces.

The production stack is where the active player lives. The idle
player never has to touch it — buildings auto-produce on cooldown
regardless. The stack scrolls horizontally if the player has more
buildings than fit; most-recently-interacted buildings sort left.

### Edge elements — Conditional

- **Milestone progress** — a thin bar that appears at a screen
  edge around wave 12 (`16_first-session-flow.md §6`). Faction-
  specific: research-chain progress / biomass coverage % / node
  count.
- **Dominance Meter** — appears at the top edge after the first
  milestone. See §8.
- **Notification stack** — bottom-right corner. See §4.
- **Galaxy map access** — a single control, available only at
  non-wave moments. See §6.

---

## 2. The Progressive-Disclosure Model

The interface has three depth states. The player moves between
them by interacting, never by being forced.

### Glance state — the idle player

Core HUD only. The returning idle player reads, in two seconds:
how much did I accumulate, is a wave incoming, did anything break.
A **damage indicator** — a faction-colored outline on any building
that took damage while offline or since last viewed — answers the
third question without a panel.

If nothing needs attention, the player can place one upgrade and
leave. The interface has asked nothing of them.

### Tactical state — the tower-defense player

Summoned by interacting with the map. Clicking a building opens
its inspection panel (§3). Clicking the wave panel expands the
full incoming-wave composition. Clicking empty terrain opens the
build menu. Each interaction reveals one layer of depth and
closes when the player looks away.

### Active state — the RTS player

The player who opens the research tree, manages the production
stack actively, runs pacification rituals, negotiates treaties,
and directs produced units. All of this is reachable from the
core HUD but none of it is visible until summoned.

The same screen serves all three. The difference is entirely in
how much the player chooses to touch.

### The return-from-offline summary

The one near-modal exception. On returning to a run after offline
time, a summary card presents the offline result — **Held**,
**Bruised**, or **Overrun** (`10_faction-lore.md §6`) — with a
resource tally and a list of any structures lost. The player
dismisses it with one tap. It is acceptable as a near-modal
because the player has just arrived; they are not mid-action, and
nothing is lost by pausing for it.

---

## 3. Contextual Panels — Summoned, Not Persistent

Every panel below slides in from a screen edge, never occupies
screen center, and never pauses the game. They close when the
player dismisses them or interacts elsewhere.

### Building inspection panel

Summoned by clicking a building. Slides from the bottom, above
the production stack. Contents:

- Production cooldown and unit roster.
- Upgrade options with costs.
- Faction-specific economic readout: adjacency-bonus map
  (Architects), biomass spread radius (Bloom), network-connection
  diagram (Mesh).
- For defensive hybrids: current tower targeting priority,
  displayed plainly so the player can verify what the tower will
  shoot (`17 §3,5,7` targeting logic). The player cannot reprogram
  targeting — it is faction-fixed — but they can *see* it.

### The pacification interface

Summoned at an active Ruins (`18 §5`). Slides from the right.
Three tier buttons (Minor / Standard / Deep) and a faction-shaped
offering selector — this is the clearest case of faction-specific
UI in the game:

- **Architects:** a catalog browser. Rows of research entries
  with timestamps; the player scrolls and selects. Precise,
  tabular, sortable by recency.
- **Bloom:** a lineage tree. Branches representing cohort and
  unit lineages, each branch visibly "alive" until committed.
  The player picks a branch.
- **Mesh:** a network graph. Nodes and Sub-Router edges; the
  player selects a node, and its associated edge highlights to
  show what will be severed.

### The research tree

Summoned by a dedicated HUD control. The R1–R5 progression from
`21 §4`. Same underlying five-tier structure, three visual
metaphors — closing `21 §9 Q7`:

- **Architect research tree:** a literal branching tech tree.
  Right angles, exact figures, node prerequisites drawn as hard
  lines. Each node shows research-point cost and projected
  efficiency gain. The most legible of the three.
- **Bloom growth tree:** an organic structure that grows
  upward. Research "nodes" are buds that flower when unlocked.
  Prerequisites are shown as the stem that must grow first.
  Less precise; the player reads progress as *height and
  fullness*, with exact figures on hover.
- **Mesh topology graph:** a network. Research nodes are
  network points; unlocking one extends the graph. The graph
  reconfigures as it grows — the Mesh research tree is the only
  one whose shape changes as the player progresses. This mirrors
  the faction: the Mesh does not have a tech *tree*, it has a
  tech *network.*

All three display the same R1–R5 spine and gate the same Tier 5
buildings and the milestone. The metaphor is faction-specific;
the information is identical.

### The treaty / alliance interface

Summoned from a diplomatic incident notification or the galaxy
map. The two-column layout from `11_galaxy-politics.md §6b` is
mandatory: **What YOU receive** and **What THEY receive**, both
visible simultaneously before signing. For alliances (`20 §2`),
the panel additionally shows the alliance's binding clauses, the
shared Dominance contribution, and — for Architect players — the
counter-proposal Value Calculator (`20 §2.4`).

The treaty panel is the densest UI in the game. It is acceptable
because diplomacy is never time-critical (`11 §5`) — the player
can study it as long as they want.

---

## 4. The Notification System — Soft Interrupts

Notifications never block gameplay. They accumulate as a stack of
soft cards in the bottom-right corner. A count indicator shows
pending items. The player addresses them when they choose.

### What queues as a notification

- Diplomatic incidents (`11 §5`) — can be sat on for hours.
- Fragment available to read.
- Auto-Diplomacy digest summaries (`11 §6b`).
- Offline incident reports.
- Memory Tier advancement available at next Collapse.

### What is NOT a notification — the breach warning

A treaty breach warning (`11 §6b`) is *not* a queued notification.
It is an **action-confirmation interrupt** — the only one in the
game. When a player action would breach an active treaty, the
action pauses at the moment of commitment:

> *This action will breach Article 2 of the Orath Containment
> Agreement. Proceed? [Confirm breach] [Cancel action]*

This is justified: it is tied to a deliberate player action, it
prevents an irreversible mistake, and it resolves instantly. It is
a confirmation, not a notification, and not a modal in the
disruptive sense — the game state is exactly where the player
left it.

### Wave commander dialogue

Not a notification and not a panel. Commander lines
(`12_wave-commanders.md`) appear as a faction-colored subtitle
band, lower-center, non-blocking, with the commander's name. The
line fades after display. Subtitles are default-on (see §10).

### The sub-path commit — the one true pause

`16_first-session-flow.md §5` establishes that the sub-path commit
is the only moment in the first session that pauses the wave
timer. The interface honors this exactly: the wave timer freezes,
the research tree opens centered (the only centered panel in the
game), two branches presented. The player commits. The timer
resumes. This pause is earned — it is a one-time identity-defining
choice — and it never recurs.

---

## 5. Faction-Specific Interface Skins

The UI has faction character beyond color. The skin changes
texture, typography, and micro-animation; it never changes layout
position or readability.

### The Architect interface

Precise. Gridded. Numeric. Typography reads as engineered —
even, monospace-adjacent. Panels have hard right-angle corners.
Every value has an exact readout and a projected rate. Micro-
animations are minimal: a value updates by *snapping* to its new
figure. The Architect HUD looks like an instrument panel because
the Architects would build it that way.

### The Bloom interface

Organic. Panels have soft, slightly irregular edges. Connectors
between elements are vein-like. Resource values prefer visual
fullness over precise numerals (exact figures on hover). Micro-
animations *grow* — a value updates by filling toward its new
level. The Bloom HUD breathes faintly at idle, matching the unit
idle-pulse from `15_cosmetics-monetization.md §0`.

### The Mesh interface

Graph-based. Elements are connected by visible signal lines.
Emphasis on flow and connection over stock and position.
Typography has a faint instability — characters resolve a frame
late. Micro-animations *flicker* — a value updates by briefly
showing intermediate noise before resolving. The Mesh HUD looks
like a live network readout.

### The constant beneath the skin

Resources top-left. Waves top-right. Production bottom.
Notifications bottom-right. Milestone progress at an edge.
Dominance Meter top after first milestone. These positions do
not move between factions. A player who has played 100 hours of
Architects and switches to Bloom finds an unfamiliar texture on
a familiar map. That is the intended onboarding cost of a faction
switch — real, but small.

---

## 6. The Galaxy Map

The galaxy map (`20 §1`) is the strategic meta-layer's interface.
It is summoned by a dedicated control and is available **only at
non-wave moments** — between waves, between runs, never during an
active wave. A player cannot pause a wave to renegotiate the
galaxy.

The map shows: regions (Outer Arms / Mid / Inner / Core), faction
claims and influence ranges, Mesh hacked-node overlay, Ancient
Ruins density, active alliance lines, pending diplomatic incident
glyphs, the silence vector (post-Fragment 7), and the neutral
core's dark-stone boundary.

The galaxy map uses the active faction's skin language. An
Architect player sees a gridded, annotated star chart. A Bloom
player sees a map where living worlds glow and dead ones recede.
A Mesh player sees a topology graph with the stars as nodes.

The map is informational and navigational — the player initiates
treaties, reviews alliances, and selects the next run's region
from it. It is never a combat surface.

---

## 7. The Pilgrimage Interface

The between-run space (`13_pilgrimage-site.md`, `19_memory-tiers.md`).
Deliberately the calm opposite of the in-run HUD: sparse, slow,
low-density. The contrast tells the player they have stepped out
of the run and into the meta-game.

### Elements in the Pilgrimage interface

- **The Memory Tier panel** — beside the Mark in the central
  chamber. Shows the player's current tier and what the next
  Collapse will unlock. Minimal: a tier number, a one-line
  description, no dense readouts.
- **The Fragment reader** — Fragments rest in their floor
  recesses (`19 §3`). Selecting one opens a reading view: the
  artifact, its content, and any Memory Tier annotations
  accumulated so far. Annotations are visually distinct *and*
  text-flagged (see §10).
- **The Mark display** — the three circles, their brightness
  states (`19 §4,5`). Not a panel — the Mark is the chamber
  floor. Its state *is* its UI.
- **The Collapse Ceremony flow** — the sequence from
  `19 §3`: offering presentation, Mark response, Fragment
  delivery, faction selection. Each step is a slow, single-focus
  screen. No element competes for attention. This is the most
  paced sequence in the game and the interface gives it room.

### The faction-wing reading material

Wandering the faction wings (`19 §8`) surfaces faction-specific
reading material — Architect catalog ledgers, Bloom lineage
record stones, Mesh dream-log terminals. These use a quiet,
full-attention reading view, not a HUD panel. The player has
chosen to wander; the interface rewards the choice with focus.

---

## 8. The Dominance Meter and Threat Telegraphy

### The Dominance Meter

Appears at the top edge after the first milestone (`18 §2`). A
horizontal bar with four threshold ticks at 25 / 50 / 75 / 100%.
The bar color shifts as it fills: calm (faction accent) →
warning (amber) → alarm (deep red toward 100%).

The meter is connected to the world: when a threshold is within
~5% of triggering, the Ancient Ruins on the map begin to pulse in
sync with the meter's edge animation. The HUD element and the map
element are the same warning, shown twice. A player who has
internalized the connection can read incoming Ancient pressure
from the Ruins alone, without looking at the meter.

During Observed status (`18 §4`), the meter is visibly frozen and
shows an Observed indicator — the player can see that dominance
cannot currently accrue.

### Threat telegraphy generally

`10_faction-lore.md §5` requires that a good wave be readable
before it lands. The interface delivers this through:

- The **axis diagram** in the wave panel — weighted to show which
  axis carries the assault.
- The **incoming-wave composition preview** — expandable from the
  wave panel, showing unit-type counts and therefore *intent*
  (Architect siege = production threat, Bloom spreaders =
  territory threat, Mesh = capital threat, per `10 §5`).
- The **commander portrait and pre-attack line** — tone and
  content forecast the wave's character.

A skilled player never needs to be surprised by a wave's shape.
The interface's job is to make the wave legible; the player's job
is to respond.

---

## 9. Late-Game Interface Additions

These elements appear only when their underlying system unlocks —
progressive disclosure applied to the late game.

### Singularity Recommendations HUD (Architect, post-Singularity II)

A panel that begins advisory and becomes assertive (`21 §6`). The
interface tells this story visually:

- **Advisory phase:** the panel is dim, docked at a screen edge,
  dismissible. Recommendations are suggestions with an Accept
  control.
- **Enforcement phase:** the panel brightens, can no longer be
  fully dismissed, and recommendations execute on a timer. The
  Accept control becomes an *Override* control — and overriding
  now shows its resource cost explicitly each time.
- The visual escalation IS the warning. The player watches their
  own interface stop asking permission.

### Surplus Biomass (Bloom, during Biosphere II)

A new resource entry appears in the top-left cluster (`21 §6`).
Unlike other resources, Surplus Biomass has no player-facing
spend control — it is spent autonomously by the colony. The
interface shows it accumulating and draining without the player
touching it. The absence of a control is the message.

### Network-Controlled node indicators (Mesh, during Mesh Control II)

Hacked nodes acquire a second-state glyph (`21 §6`): Player-
Controlled or Network-Controlled. The galaxy map and the
building inspection panel both show the distinction. A Mesh
player in Mesh Control II can read, at a glance, how much of
their own network they still command.

### Second Milestone trigger

When a Second Milestone fires, the interface delivers a brief
ambient shift (full audiovisual spec deferred to the
choreography session) plus a single soft notification offering
the three options from `21 §6`: submit, resist, or initiate a
controlled Collapse. The notification does not expire and does
not block — the player decides in their own time.

---

## 10. Accessibility

Accessibility is a first-class constraint, not a post-launch
patch. The "never modal" architecture already helps — there are
no forced timed interactions a player can fail to complete. The
following are mandatory:

- **Faction color is load-bearing; it cannot be the only
  channel.** Amber / green / blue distinguish the factions in
  combat UI (`15_cosmetics-monetization.md`). Every faction-
  colored element must also carry a distinct shape or icon, so a
  colorblind player reads faction by silhouette. Colorblind
  modes adjust the palette but the shape redundancy is always on.
- **Memory Tier annotations are screen-reader-legible and
  text-flagged.** Closing `19 §11 Q4`: annotations are never
  conveyed by visual decoration alone. Each annotation carries an
  explicit text marker (e.g., "[Annotation — Tier 5]") that a
  screen reader announces and a sighted player can also see.
- **Subsonic pulses have a visual option.** The Pilgrimage and
  Ruins subsonic pulses (`13_pilgrimage-site.md`) are felt-not-
  heard by design. A hearing-impaired player can enable a subtle
  visual pulse indicator that carries the same rhythm
  information.
- **Wave commander subtitles are default-on.** Dialogue is never
  audio-only.
- **Text scaling** across all panels, with the core HUD tested
  for legibility at the largest scale setting.
- **The production stack supports keyboard / controller cycling**
  so active play does not require precise pointer control.

---

## 11. Hard Constraints (Implementation Checklist)

- **Never modal**, with exactly two exceptions: the sub-path
  commit (pauses the wave timer, centered research tree) and the
  return-from-offline summary (dismissed in one tap).
- **The breach warning is the only action-confirmation
  interrupt.** No other player action prompts a confirm dialog.
- **Layout positions are constant across all factions.**
  Resources top-left, waves top-right, production bottom edge,
  notifications bottom-right. Faction skins change texture only.
- **The core HUD must be readable in under two seconds.** This
  is a testable acceptance criterion, not a guideline.
- **The galaxy map cannot open during an active wave.**
- **Contextual panels slide from a screen edge and never occupy
  screen center.** The sub-path commit research tree is the sole
  centered panel.
- **Tower targeting priority is visible but not editable.** The
  player can read what a tower will shoot; faction logic is
  fixed.
- **Notifications never expire destructively from the UI.** The
  content-level degradation of time-sensitive incidents (`11 §5`)
  is a content rule; the notification card itself never vanishes
  unaddressed.
- **Late-game UI elements appear only when their system
  unlocks.** No element is visible before it is relevant.
- **Faction skinning never compromises readability** — silhouette
  integrity, faction color coding, and combat tells follow the
  `15_cosmetics-monetization.md` rules without exception.

---

## 12. Open Questions

1. **Mobile / touch viability.** The game targets "a player with
   limited session time" — that profile overlaps heavily with
   mobile. The progressive-disclosure model and the produce-now
   tap affordance are touch-friendly by design, but the treaty
   panel's density and the research tree may not survive a small
   screen. Needs a dedicated mobile-layout study if mobile is a
   real target.
2. **Controller support depth.** §10 commits to keyboard /
   controller cycling for the production stack. Whether the full
   interface (galaxy map, treaty negotiation, research tree) is
   controller-complete is a larger scope question. Defer until
   platform targets are fixed.
3. **Notification flood handling.** A player returning after a
   long absence may face many queued incidents at once. Does the
   stack cap and summarize, or scroll indefinitely? Leaning
   toward a digest card that groups similar incidents, but needs
   prototype data on realistic queue sizes.
4. **Production stack scaling.** A late-game player may have 15+
   production buildings. Horizontal scroll is the current plan,
   but a grouping or filtering mechanism (by tier, by unit role)
   may be needed. Playtest with a maxed base.
5. **First-session prompt integration.** The faction-voiced
   integrated prompts from `16_first-session-flow.md` must
   coexist with this system without ever becoming the modal
   tutorial the corpus has explicitly rejected. The prompt
   styling is specified there; the exact handoff to the full
   notification system as the tutorial ends needs a pass.
6. **Galaxy map and the Pilgrimage overlap.** Both are between-
   run interfaces. Are they two separate spaces the player moves
   between, or two views of one meta-screen? Currently designed
   as separate (the Pilgrimage is navigable space, the galaxy
   map is an overlay). Worth validating that the transition
   between them feels coherent.
7. **Diegetic vs. overlaid HUD.** This doc assumes a
   conventional overlaid HUD. A more diegetic approach — the
   interface as faction technology the player's units project —
   could deepen immersion but risks the two-second-readability
   rule. Out of scope here; flag for an art-direction pass.
