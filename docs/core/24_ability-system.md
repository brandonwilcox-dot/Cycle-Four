# Commander Ability System — Design Spec

> Track B output. Designs the Commander ability hotbar for Cycle Four:
> slot count, keybinds, cost model, faction handling, HUD placement,
> progression, and a three-ability launch roster. Resolves the secondary
> cannon from an auto-firing weapon into a deliberate, player-triggered
> ability. Every decision is made and justified here; nothing is left
> open. The Implementation Handoff (§8) is written for a Sonnet build pass.
>
> Reference state: `src/entities/Commander.gd` (primary auto-fire 0.4s/8dmg
> single-target; secondary auto-fire 5s/30dmg AOE-in-range). HUD per
> `core/22_interface-design.md`. First-session arc per
> `core/16_first-session-flow.md`. Faction feel per `core/12` and `core/17`.

---

## 1. Design Summary

The Commander gains a three-slot ability hotbar bound to **Q / W / E**.
Slot 1 is the existing secondary cannon, converted from a passive 5-second
auto-fire into a deliberate, cooldown-gated burst the player chooses to
spend. Slots 2 and 3 add a zone-control field and a self-amplification
buff — three distinct tactical roles (burst, control, sustain) that cover
the situations a five-minute defensive session actually produces. The cost
model is **cooldown-only**: no resource drain, no charge meter, press when
ready. Abilities are **faction-neutral in mechanics and faction-flavored
in name and color** for the first build, honoring the lore-first surface
without paying for three divergent kits before the kit is proven. The three
slots unlock across the first session in lockstep with its emotional arc:
the cannon from the start (Competence), the control field at sub-path
commit (Identity), the self-buff at the first milestone (Mastery). The
hotbar lives bottom-center, directly above the ActionBar, where MOBA
muscle memory already expects it.

---

## 2. Ability Slot Count & Keybinds

**Decision: 3 slots. Bound to Q (slot 1), W (slot 2), E (slot 3). R is
reserved for a future slot 4 / ultimate.**

Slot count reasoning. One slot does not justify a hotbar — it is just a
keybind for the cannon, and the UI overhead of a bar to hold a single
button is not worth it. Four slots is more than an idle-adjacent player
on a five-minute session will track or want to track; the fourth slot
becomes the one nobody presses, and it dilutes the identity of the other
three. Three is the smallest count that lets each slot own a *distinct
tactical role* — burst, control, sustain — so there is never a slot whose
job overlaps another's. Three also leaves a clean upgrade path: slot 4 (R)
becomes a faction-specific ultimate in a later track without re-teaching
the layout.

Keybind reasoning. The player moves by **left-clicking anywhere on the
world** (`Commander.gd._unhandled_input`), so the mouse is fully occupied
with movement and unit/building placement. The keyboard hand is free and
resting. **Q / W / E** is the dominant convention for ability casting in
the genre players will arrive from (MOBAs, ARPGs), it is a single relaxed
hand position with no reach, and the three keys are physically adjacent so
the slot→key mapping is spatially obvious. Rejected alternatives:

- **1 / 2 / 3 / 4** — requires reaching up off the home row; reads as
  "build menu / production hotkeys," which would collide with the
  ActionBar's role.
- **Space** — universally reads as pause / confirm / "do the obvious
  thing"; binding a damage ability to it invites misfires.
- **Mouse buttons (right-click, etc.)** — right-click is the natural home
  for a future context action (cancel / queue-move) and should be kept
  clear.

ESC retains its existing role (collapse to GLANCE state, cancel targeting).

---

## 3. Cost Model

**Decision: cooldown-only for the first build. No resource cost, no charge
meter.**

Each ability has a fixed cooldown and is free to cast the moment it is
ready. Reasoning, against the two alternatives:

- **Resource-cost + cooldown** — rejected for v1. The economy is already
  the idle layer's central tension, and the territory-income loop
  (`RATE_PER_CLAIMED_CELL`, offline accrual) is built to be *enjoyed on
  return*, not spent down in combat. Taxing abilities against the primary
  resource couples two systems that should stay legible apart, and it
  produces the specific feel-bad of returning from an idle session and not
  being able to afford your own defensive button. It also adds an
  affordability check and a cost readout to every slot in the HUD.
- **Charge-based (builds from kills/damage)** — rejected for v1, retained
  as the v2 evolution. Charge meters are the *right* long-term home for the
  offensive slot — they reward aggression and make the cannon feel earned —
  but they require damage/kill-attribution plumbing the Commander does not
  yet have, and a per-slot charge readout in the HUD. Shipping cooldown-only
  first proves the kit is fun before building that plumbing. **Slot 1 is the
  designated future charge slot;** when charge lands, the cannon's cooldown
  becomes a charge bar and slots 2–3 stay on cooldowns.

Cooldown-only is the cleanest readable model — a radial sweep on each slot
is the entire UI — and it matches the "press when ready" mental model an
idle-adjacent player brings.

---

## 4. Faction Handling

**Decision: faction-neutral mechanics, faction-flavored presentation, from
day one. Three abilities, identical numbers across all factions; name,
color, and cast-VFX differ per faction.**

This mirrors how the build has already handled the HUD — faction-agnostic
systems first, skins deferred — and it is the correct reading of the
lore-first philosophy here. Lore-first means *identity is expressed*, not
that every system forks three ways on first contact. A player must feel
that the Architect cannon is a precise geometric lance and the Mesh cannon
is a glitchy EMP cascade; they do **not** need those two to have different
cooldowns or different damage to feel like different factions on the first
build. Three mechanically-distinct kits (3 factions × 3 abilities = 9
bespoke abilities, each with its own tuning, edge cases, and balance pass)
is a large, premature cost before the three-role kit is even validated as
fun.

So: one set of mechanics, three presentation layers. The presentation layer
is cheap — a name string, a color, and a particle/Line2D style per faction,
all data on the `AbilityData` resource. The flavor notes in §7 specify the
per-faction name and read for each ability.

**Deferred to a later track (post-validation):** mechanically-divergent
faction kits — e.g. the Bloom control field leaving lingering biomass, the
Mesh cannon also draining wave reward on hit, the Architect self-buff
compounding the longer it runs. These are good and they are written down;
they wait until the neutral kit proves out.

---

## 5. HUD Layout

**Decision: AbilityBar is a fixed cluster, bottom-center, anchored directly
above the ActionBar. It does not displace the ActionBar and stays clear of
the bottom-right NotificationStack.**

The four existing clusters (`core/22`) are unchanged: ResourceCluster
top-left, WavePanel top-right, ActionBar full-width bottom, NotificationStack
bottom-right above the ActionBar. The AbilityBar slots into the vertical gap
between the ActionBar and the play field, horizontally centered, so it reads
as a distinct band of *combat* actions sitting above the band of *build*
actions. This separation is deliberate: build actions are **clicked** (mouse,
ActionBar), combat abilities are **pressed** (keyboard, AbilityBar), and the
spatial split reinforces the input split. Bottom-center is also where the
genre's players already look for their abilities.

```
+--------------------------------------------------------------+
| [ResourceCluster]                            [WavePanel]     |
|                                                              |
|                                                              |
|                       (play field)                           |
|                                                              |
|                                          [Notification]      |
|                                          [   Stack     ]     |
|                  +------------------+                        |
|                  | Q  | W  | E  |                            |  <- AbilityBar
|                  +------------------+                        |     (bottom-center,
| [  Begin Waves  |  Place Tower  |  Place Building          ] |      above ActionBar)
+--------------------------------------------------------------+
```

Each slot shows: ability icon, a cooldown radial sweep that fills while on
cooldown (slot dimmed and unclickable until ready), the keybind glyph
(Q/W/E) in the corner, and a lock overlay for not-yet-unlocked slots.
Casting flashes the slot. The bar respects the HUD click-through rule from
the build (container `mouse_filter = IGNORE`, the slot buttons `STOP`).

The AbilityBar is part of core HUD and is visible in all three depth states
(glance / tactical / active) — abilities must always be castable, including
mid-combat when a contextual panel is open.

---

## 6. Progression & Unlock

**Decision: the three slots unlock across the first session, each tied to a
beat of the `core/16` emotional arc.**

| Slot | Ability | Unlocks at | Arc beat |
|---|---|---|---|
| 1 (Q) | Lance | Start — present in the Academy | Competence |
| 2 (W) | Suppression Field | Sub-path commit (Chapter 4, waves 4–7) | Identity |
| 3 (E) | Overdrive | First faction milestone | Mastery |

Reasoning. The first-session spine teaches five things in order
(Wonder → Competence → Identity → Mastery → Revelation). Abilities should
arrive *on* that spine, not all at once at the start where a new player
would be overwhelmed and would not yet have a situation that needs them.

- **Lance from the start.** The cannon already exists in the Academy as the
  Commander's heavy attack; the only change the player experiences is that
  it is now theirs to time rather than firing on its own. This is the
  Competence beat — "passive defense works, then I take the wheel."
- **Suppression Field at sub-path commit.** The control field arrives exactly
  when the player is being asked *what kind of player they are* (Chapter 4,
  the Identity beat). Zone control is the first ability that rewards
  intention over reflex, which is the right teaching moment.
- **Overdrive at the first milestone.** The self-amp buff lands on the
  Mastery/Revelation beat, when the milestone unit and the Ancient
  activation are reframing the whole run. Overdrive is the "now you can melt
  a priority threat" tool — the right capstone to a first session.

On the HUD, locked slots show a lock overlay with the keybind dimmed, so the
player can *see* there is more coming. Each unlock fires a soft-interrupt
notification (per `core/22`, non-modal) naming the new ability and its key.

Across prestige runs the unlock cadence holds, but unlock *triggers* may
fast-path for returning players (see Implementation Handoff). For v1, gate
strictly on the three events above.

---

## 7. Ability Roster

All numbers are v1 ship values, tuned against the existing Commander combat
constants (primary 0.4s/8dmg, old secondary 5s/30dmg AOE,
`ATTACK_RANGE_PX = VISION_RADIUS * 64 = 192px`). `_damage_multiplier`
(rank scaling) applies to ability damage exactly as it does to attacks.

### Slot 1 — Lance (Q)

- **Effect:** Deals **45 damage to every enemy within `ATTACK_RANGE_PX`** of
  the Commander, instantly. The converted secondary cannon.
- **Cooldown:** 6s.
- **Cost:** None (cooldown-only).
- **Tactical role:** **Burst / clear.** The answer to a clustered wave or a
  cohort bunched on the Commander. Throughput is intentionally *lower on
  average* than the old auto-fire (old: 30 every 5s = 6 dmg/s unconditional;
  new: 45 every 6s = 7.5 dmg/s but only when the player spends it), so the
  reward is timing — fire it when the cluster is densest, not on a metronome.
- **Faction flavor:**
  - *Architect — "Overcharge Lance":* a single geometric beam that sweeps
    the radius; precise, white-gold, surgical.
  - *Bloom — "Spore Burst":* a corrosive cloud blooms outward and settles;
    organic, sickly green, lingering visually (mechanically instant).
  - *Mesh — "Cascade Pulse":* a neon EMP ring snaps out and glitches; harsh
    cyan, stuttering.

### Slot 2 — Suppression Field (W)

- **Effect:** Ground-targeted. Press W, then left-click a cell to place a
  **3-cell-radius (192px) field**. For **4 seconds**, every enemy inside the
  field has **−50% move speed and −50% fire rate**. Deals no damage.
- **Cooldown:** 12s.
- **Cost:** None.
- **Targeting:** Pressing W enters targeting mode (the next left-click places
  the field instead of moving the Commander); ESC or right-click cancels.
- **Status-immunity note:** Enemies flagged status-immune (lore: Bloom
  Mire-Beasts and similar are "immune to slow, stun, and hack") ignore the
  debuff. v1 may apply to all wave units if the immunity flag is not yet
  present, with a TODO to honor it once enemy data carries the flag.
- **Tactical role:** **Zone control / lane denial.** Buys time on a
  collapsing flank, holds a chokepoint while towers catch up, or splits a
  wave's timing. The only ability the player places on the map rather than
  on themselves — it rewards reading the wave's geometry.
- **Faction flavor:**
  - *Architect — "Calibration Grid":* a luminous targeting lattice; enemies
    slow as if caught in a precision-denial mesh.
  - *Bloom — "Root Snare":* tendrils erupt from the ground and entangle.
  - *Mesh — "Static Net":* a jagged signal-jam field; movement and fire
    stutter as systems are jammed.

### Slot 3 — Overdrive (E)

- **Effect:** Self-buff. For **6 seconds**, the Commander's **primary fire
  rate is doubled** (interval 0.4s → 0.2s) and **primary damage is +50%**.
  Resets the primary timer on activation so the boost starts immediately.
- **Cooldown:** 20s.
- **Cost:** None.
- **Tactical role:** **Sustain / single-target melt.** Where Lance is a
  one-shot burst on a cluster, Overdrive is a sustained window against a
  durable priority target — a Tier-3 anchor, a milestone unit, a structure
  pushing the line. The Commander parks and grinds. Distinct from both other
  slots: it is the only one that scales with *time on target*.
- **Faction flavor:**
  - *Architect — "Recursive Optimization":* explicit callback to the Apex's
    uncapped-scaling signature; the Commander's fire visibly accelerates.
  - *Bloom — "Adrenal Bloom":* a flush of growth; the chassis pulses.
  - *Mesh — "Overclock":* the rig redlines in neon; glitch artifacts trail
    each shot.

---

## 8. Implementation Handoff

Written for a Sonnet implementation pass. Verify all signal/node/action
names against the live project before wiring — placeholders below mark where
to confirm against existing code.

### 8.1 Files to touch

| File | Change |
|---|---|
| `src/entities/Commander.gd` | **Remove the auto-secondary.** Delete `_secondary_timer` decrement + `_try_secondary_attack()` call in `_process`; keep `_try_secondary_attack`'s damage loop but rename it as the Lance effect, invoked by the controller. Keep primary auto-fire untouched. Add an `_overdrive_until` timestamp and have `_process` use boosted primary interval/damage while active. Add a targeting-mode flag so `_unhandled_input` consumes the next left-click as a Suppression Field cast position instead of a move when targeting is armed. |
| `src/abilities/AbilityData.gd` *(new)* | `Resource` defining one ability: `id: StringName`, `display_name: String`, `key_action: StringName`, `cooldown: float`, `unlock_event: StringName`, `targeting: int` (enum SELF / GROUND / NONE), `params: Dictionary` (damage, radius, duration, slow_pct, etc.), and presentation fields `color: Color`, `vfx: StringName`. |
| `src/abilities/AbilityController.gd` *(new)* | Child node of Commander (or component). Owns the three `AbilityData` resources, per-slot cooldown timers, unlock state. Reads input actions, gates on cooldown + unlock, dispatches to effect functions, drives the ground-targeting handshake with Commander, applies/reverts Overdrive, emits the EventBus signals below. |
| `src/abilities/effects/` *(new, optional)* | If effects grow, split each ability's effect into its own small script/function. For v1, three methods on `AbilityController` (`_cast_lance`, `_cast_suppression`, `_cast_overdrive`) are sufficient. |
| `src/ui/AbilityBar.gd` + `.tscn` *(new)* | The bottom-center HUD cluster. Three slot controls; subscribes to EventBus cooldown/unlock signals; renders radial cooldown, keybind glyph, lock overlay, cast flash. |
| `src/data/abilities/*.tres` *(new)* | Nine resources (3 abilities × 3 factions) or — preferred for v1 — three neutral `AbilityData` resources plus a per-faction presentation lookup, so mechanics live once. FactionManager selects the presentation layer at runtime. |
| `project.godot` | Add the input actions in §8.3. |
| HUD scene (wherever the four clusters are assembled) | Instance `AbilityBar` anchored bottom-center above ActionBar; container `mouse_filter = IGNORE`, slot buttons `STOP` (per the build's click-through rule). |

### 8.2 New EventBus signals

```gdscript
signal ability_used(slot_id: int)                                   # cast fired; AbilityBar flashes the slot
signal ability_cooldown_changed(slot_id: int, remaining: float, total: float)  # per-frame-ish; drives the radial
signal ability_ready(slot_id: int)                                  # cooldown hit zero
signal ability_unlocked(slot_id: int, ability_id: StringName)       # slot opened; AbilityBar clears lock + fires notification
signal ability_targeting_changed(slot_id: int, active: bool)        # ground-target armed/cancelled; cursor + Commander input
```

`AbilityBar` subscribes to all five. `Commander` (or its input handler)
subscribes to `ability_targeting_changed` to know when to consume a click
as a cast position.

### 8.3 New input actions (`project.godot`)

```
ability_1   -> Q   (Lance)
ability_2   -> W   (Suppression Field)
ability_3   -> E   (Overdrive)
```

Cancel reuses the existing ESC binding (and/or right-click) — no new action
needed if `ui_cancel` is already mapped; otherwise add `ability_cancel -> ESC`.

### 8.4 Unlock wiring

Gate each slot on an existing project event; confirm the real signal names:

| Slot | Unlock trigger | Likely signal (verify) |
|---|---|---|
| 1 Lance | available at session start | none — unlocked in `_ready` |
| 2 Suppression Field | sub-path commit | `EventBus.subpath_committed` *(placeholder — confirm)* |
| 3 Overdrive | first faction milestone | `EventBus.milestone_reached` *(placeholder — confirm)* |

`AbilityController` listens for these and emits `ability_unlocked`. If the
sub-path / milestone signals do not exist yet, add a TODO and temporarily
unlock all three at start behind a debug flag so the kit is testable.

### 8.5 AbilityBar node structure

```
AbilityBar            (Control, anchored bottom-center, mouse_filter = IGNORE)
└── Slots             (HBoxContainer, mouse_filter = IGNORE)
    ├── Slot1         (Panel/TextureButton, mouse_filter = STOP)
    │   ├── Icon          (TextureRect)
    │   ├── CooldownArc   (TextureProgressBar, radial fill mode; 0 when ready)
    │   ├── KeyLabel      (Label, "Q", corner)
    │   └── LockOverlay   (ColorRect/TextureRect, visible until unlocked)
    ├── Slot2         (... "W")
    └── Slot3         (... "E")
```

Slot states: **locked** (LockOverlay shown, dimmed), **ready** (full color,
clickable, KeyLabel bright), **cooling** (CooldownArc sweeping, slot dimmed,
not castable), **casting** (one-frame flash via `ability_used`). Clicking a
ready slot casts it (mouse parity with the keybind); clicking slot 2 also
arms ground-targeting.

### 8.6 Effect implementation notes (GDScript-only; no physics, no animation)

- **Lance:** reuse the existing `_try_secondary_attack` loop — iterate
  `get_tree().get_nodes_in_group("units")`, distance-check against
  `ATTACK_RANGE_PX`, apply `45 * _damage_multiplier` via `take_damage`, spawn
  the existing cannon-ring VFX (recolor per faction). Pure iteration.
- **Suppression Field:** on cast, store field center + an expiry timestamp.
  Each frame while active, iterate units, distance-check against the field
  radius, and apply a slow/fire-rate multiplier to those inside (units need
  to honor a `set_speed_multiplier` / `set_fire_rate_multiplier`, or a
  generic timed-debuff method — add one if absent). Skip units flagged
  status-immune. Draw the field as a `draw_arc`/`ColorRect` while active.
  Pure timers + iteration.
- **Overdrive:** set `_overdrive_until = now + 6.0`. In `Commander._process`,
  while active, use `PRIMARY_INTERVAL * 0.5` and multiply primary damage by
  `1.5`. Revert automatically on expiry. Pure timer + arithmetic.

None of the three requires the physics server, an `AnimationPlayer`, or
tween infrastructure beyond the brief `Line2D`/`ColorRect` flash helpers the
Commander already uses.

---

## 9. Forward Queue (post-v1)

Parked deliberately; written down so they are not re-litigated.

- **Charge-based cost** for slot 1 (Lance), replacing its cooldown with a
  meter that fills from damage dealt. Requires damage/kill attribution.
- **Faction-divergent mechanics** for all three slots (Bloom field leaves
  biomass; Mesh Lance drains wave reward; Architect Overdrive compounds
  the longer it runs). The presentation layer already forks; this forks the
  numbers.
- **Slot 4 (R) — faction ultimate.** The reserved key. A faction-specific
  signature tied to the milestone unit's identity.
- **Charge/cooldown readout polish** and accessibility pass (color-redundant
  cooldown state, per `core/22` accessibility rules).

> **Status update (Track C built + verified).** The neutral three-slot kit
> ships and runs clean. The Lance charge-meter item above is **done** (slot 0
> fills 0→60 from primary damage; `EventBus.ability_charge_changed`,
> `add_lance_charge()`, overflow capped). The remaining two stubs —
> faction-divergent mechanics and the slot-4 ultimate — are promoted out of
> the queue and fully specified in §10 and §11 below, grounded against the
> built code (`src/abilities/AbilityController.gd`, `src/abilities/AbilityData.gd`,
> `src/entities/Unit.gd`, `src/entities/Base.gd`, `FactionManager`,
> `EconomyManager`).

---

## 10. Faction-Divergent Mechanics

The neutral kit is proven; the divergences now fork it. Each ability keeps
its neutral numbers as the floor — the faction layer **adds** behavior, it
does not rebalance the base. Dispatch is trivial and cheap: at cast time the
controller reads `FactionManager.active_faction` (a `String`, already set on
faction select) and branches. There is no need to fork the `AbilityData`
resources; the per-faction branch lives in the cast methods, and any tunable
numbers ride in `params` under faction-keyed sub-dictionaries if desired.

A recurring dependency surfaces across three of the six divergences: **the
enemy `Unit` has no status-immunity flag and no damage-over-time or stun
mechanic today.** `Unit.set_debuff()` modifies *move speed only*, and enemies
do not fire (they navigate to the base), so "fire-rate" debuffs are inert on
them. Two small additions to the unit layer unblock everything below:

- **`UnitData.status_immune : bool` (new export, default `false`).** Set
  `true` on heavy/lore-immune chassis (Mire-Beast, Bio-Titan). The
  Suppression Field slow and the Architect stun both check it.
- **`Unit.apply_stun(duration: float)` and a `Unit._stun_until` timestamp
  (new).** In `Unit._process`, if stunned, skip the movement block. Because
  enemies don't attack, freezing movement *is* a complete stun for them. The
  method early-returns if `data.status_immune`.

One gotcha caught from reading `Unit.take_damage()`: it subtracts
`data.armor` **per call**. Any per-frame DoT (`take_damage(5 * delta)`) would
be zeroed by armor every frame. DoT must therefore tick in whole-second
intervals (one `take_damage(5.0)` per second), where armor is meaningful but
not dominant — not continuously. The Bloom biomass hazard below uses this
1-second tick.

### 10.1 Architect Lance — "Overcharge Lance"

- **Effect:** the neutral 45-damage in-range AOE, plus a **1.0 s stun** on
  every non-immune enemy hit. Precision denial: the Architect doesn't just
  hit the cluster, it freezes it in place for the towers.
- **Mire-Beast / status-immune interaction:** immune units take the 45 damage
  but are **not** stunned — `apply_stun()` early-returns on
  `data.status_immune`. This is the correct lore read (the Mire-Beast "has
  seen those before") and it makes the immunity flag visibly matter the first
  time a player Lances a heavy and watches it keep walking.
- **Implementable now?** Needs the new `Unit.apply_stun()` +
  `UnitData.status_immune` (above). With those, the change to
  `AbilityController._cast_lance()` is two lines: after `unit.take_damage(...)`,
  `if FactionManager.active_faction == "architect": unit.apply_stun(1.0)`.
- **Files:** `Unit.gd` (+`apply_stun`, `_stun_until`, `_process` guard),
  `UnitData.gd` (+`status_immune`), `AbilityController.gd` (`_cast_lance`).

### 10.2 Bloom Suppression Field — "Root Snare"

- **Effect:** the neutral 4 s / −50 % slow field, and **on expiry it does not
  clear — it leaves a biomass hazard tile for 8 s.** Enemies inside the
  hazard take **5 damage per second** (1 s ticks) and move at **70 % speed**.
  The field becomes lingering map control: the Bloom plants ground, it doesn't
  just press a button.
- **How it's drawn / what manages it:** the active field is already rendered
  by `Commander._draw()` reading `AbilityController` state
  (`field_active`, `field_center`). The hazard reuses that exact path. Add
  `hazard_active : bool`, `_hazard_until : float`, `_hazard_center : Vector2`,
  and a `_hazard_next_tick : float` to the controller. When `_end_field()`
  runs under the Bloom branch, instead of fully clearing it transitions into
  the hazard: set `hazard_active = true`, `_hazard_until = now + 8.0`. In
  `_process`, while `hazard_active`: every frame apply `set_debuff(0.7)` to
  units in `FIELD_RADIUS_PX` of `_hazard_center` (and `1.0` to those leaving),
  and once per second call `take_damage(5.0)` on units inside.
  `Commander._draw()` gains one branch: if `hazard_active`, draw a sickly-green
  filled disc (dimmer than the live field) at `_hazard_center`.
- **Implementable now?** Yes — entirely on the existing field plumbing plus
  the 1-second DoT tick. No new node; the controller already owns field
  state and drives `Commander.queue_redraw()`.
- **Files:** `AbilityController.gd` (hazard state + `_process` branch +
  Bloom branch in `_end_field`), `Commander.gd` (`_draw` hazard disc).

### 10.3 Mesh Lance — "Cascade Pulse"

- **Effect:** the neutral 45-damage burst, and **each enemy killed by the
  burst refunds 25 % of the charge cost.** Charge cost is
  `LANCE_CHARGE_MAX = 60`, so each kill returns **15 charge**, capped at **one
  full charge (60) per cast** — a 4-kill burst fully re-arms the Lance. The
  Mesh weaponizes a packed wave: clear it and you immediately hold another
  Lance.
- **Implementable now?** Yes, cleanly. `Unit.take_damage()` already returns
  `true` on death. In `_cast_lance()`, count kills
  (`if unit.take_damage(...): kills += 1`), and after the existing
  `lance_charge = 0.0` reset, under the Mesh branch set
  `lance_charge = minf(kills * 15.0, LANCE_CHARGE_MAX)` and recompute
  `lance_charged = lance_charge >= LANCE_CHARGE_MAX`. If it re-arms, emit
  `EventBus.ability_ready.emit(0)` so the HUD flashes. No new systems.
- **Files:** `AbilityController.gd` (`_cast_lance` kill count + Mesh refund).

### 10.4 Architect Overdrive — "Recursive Optimization"

- **Effect:** the neutral self-amp (×0.5 interval, ×1.5 damage), but the
  damage multiplier **compounds ×1.05 every 2 s while active, up to 3 stacks**
  (1.5 → 1.575 → 1.654 → 1.736). To give all three stacks real uptime, the
  Architect Overdrive **duration is 8 s** (vs. the neutral 6 s); ticks land at
  +2 s, +4 s, +6 s. Reverts fully on expiry. The explicit callback to the
  Apex's uncapped-scaling signature — the longer it runs, the harder it hits.
- **Implementable now?** Yes. `is_overdrive_active` and
  `overdrive_damage_mult` already exist and are read live by `Commander`. Add
  `_overdrive_next_tick : float` and a stack counter; in `_process`, while
  `is_overdrive_active` and `active_faction == "architect"` and
  `now >= _overdrive_next_tick` and stacks < 3, multiply
  `overdrive_damage_mult *= 1.05`, increment stacks, advance the tick by 2 s.
  Because `Commander` reads `overdrive_damage_mult` every frame, no further
  wiring is needed. Set duration from a faction branch in `_cast_overdrive`.
- **Files:** `AbilityController.gd` (`_cast_overdrive` duration branch +
  `_process` compounding tick).

### 10.5 Bloom Overdrive — "Adrenal Bloom"

- **Effect:** the neutral self-amp, plus **on cast, instantly heal the FOB by
  10 HP** (`Base.MAX_HP` is 300, so ~3.3 % — a meaningful but not trivializing
  patch). Life answers pressure: the Bloom commander's burst window also
  mends the line.
- **Implementable now?** Needs a small new heal path — `Base.gd` has
  `_current_hp` but only a damage handler. Add **`EventBus.base_healed(amount:
  float)`** and a `Base._on_base_healed` that does
  `_current_hp = minf(MAX_HP, _current_hp + amount)` then `_update_hp_bar()`
  (mirrors `_on_base_damaged`). In `_cast_overdrive`, under the Bloom branch,
  `EventBus.base_healed.emit(10.0)`. One signal, one handler.
- **Files:** `EventBus` (+`base_healed`), `Base.gd` (+handler),
  `AbilityController.gd` (Bloom branch in `_cast_overdrive`).

### 10.6 Mesh Overdrive — "Overclock"

- **Effect:** the neutral self-amp, plus **the next enemy killed during the
  6 s buff window leaks 5 resources to the Mesh** (primary resource, on top of
  the normal kill reward). Even the Mesh's self-buff steals.
- **Implementable now?** Yes, via the existing `EventBus.unit_died` signal.
  On a Mesh Overclock cast, set `_steal_pending = true` and connect a
  one-shot handler to `unit_died` (or check a flag in `_process`); on the
  first kill while the window is open, `EconomyManager.add_resource(
  FactionManager.get_primary_resource(), 5.0)` and clear the flag. Disconnect
  / clear on window expiry so a kill after the buff doesn't pay out.
- **Files:** `AbilityController.gd` (Mesh branch in `_cast_overdrive`,
  `_steal_pending` state, `unit_died` hookup).

### 10.7 Divergence summary

| Ability | Faction add-on | New systems required |
|---|---|---|
| Lance | Architect: 1 s stun (immunity-aware) | `Unit.apply_stun`, `UnitData.status_immune` |
| Lance | Mesh: kills refund 15 charge ea. (cap 60) | none — `take_damage` returns death |
| Suppression Field | Bloom: 8 s biomass hazard (5 dps, 70 % slow) | none — reuses field state + 1 s DoT tick |
| Overdrive | Architect: ×1.05 dmg / 2 s, 3 stacks, 8 s | none — reuses live-read mults |
| Overdrive | Bloom: heal FOB 10 HP on cast | `EventBus.base_healed` + `Base` handler |
| Overdrive | Mesh: next kill in window leaks +5 | none — reuses `unit_died` |

Two genuinely new pieces total: the **unit stun + immunity** pair and the
**`base_healed`** signal. Everything else rides existing plumbing. Build the
two shared pieces first, then the six branches are small and independent.

---

## 11. Slot 4 (R) — Faction Ultimates

The reserved fourth slot opens. **Key: R** (`ability_4`, registered the same
way as Q/W/E in `AbilityController._register_input_actions`; `SLOT_COUNT`
becomes 4 and the `_cooldowns`/`_unlocked` arrays grow to length 4).

**Unlock gate (all three): the Second Milestone.** `EventBus.milestone_reached`
already carries `(faction_id, milestone_index)`; the first milestone
(`milestone_index == 0`) unlocks Overdrive (slot 2). The ultimate unlocks on
`milestone_index == 1` — the Second Milestone defined in
`core/21_late-game-progression.md` (Singularity II / Biosphere II / Mesh
Control II), the point where each faction's philosophy collapses inward. That
is the correct earned moment for a faction's signature button, and it keeps
the ultimate off the table through the entire first session.

All three are **cooldown-only** (consistent with the kit), long cooldowns,
and built from the same group-iteration / timer / EventBus primitives the
existing abilities use. None needs physics or animation.

### 11.1 Architects — "Compile Cascade" (R)

- **Effect:** instantly damages **every enemy on the map** — not just those in
  range — for **`50 + 2 × N`** damage each, where **N is the total enemy
  count** on the map at cast. A 20-enemy wave takes 90 each; a 40-enemy surge
  takes 130 each. The more there is to process, the more efficiently it
  processes. Ignores nothing, scales with scale.
- **Cooldown:** 90 s.
- **Unlock:** Architect Second Milestone (Singularity II).
- **Identity hook:** the literal expression of the compounder thesis and a
  direct callback to the Apex's "Compile Cascade" (`core/17`). The Architect's
  ultimate is *more efficient against larger problems* — the faction's entire
  worldview as one keypress.
- **Implementation sketch:** new `_cast_compile_cascade()` on
  `AbilityController`. Grab `var units = get_tree().get_nodes_in_group("units")`,
  compute `N = units.size()`, then loop applying
  `take_damage((50.0 + 2.0 * N) * dmg_mult)` with no distance check. Reuse the
  cannon-ring VFX scaled map-wide (or a brief full-screen white flash
  `ColorRect`). Pure iteration; ~10 lines. Files: `AbilityController.gd`,
  `project.godot` (ability_4 binding via InputMap, already code-registered).

### 11.2 The Bloom — "Verdant Bulwark" (R)

- **Effect:** for **12 s**, the FOB **regenerates 4 HP/s** (48 total) and every
  enemy within **384 px of the FOB** is slowed **40 %**. A defensive bloom: the
  Bloom doesn't burst the wave, it outlasts it and mires it at the gate.
- **Cooldown:** 120 s.
- **Unlock:** Bloom Second Milestone (Biosphere II).
- **Identity hook:** the Bloom is weakest early, near-unkillable late; its
  ultimate is pure endurance and territory denial, not damage. It buys time —
  the resource the Bloom always wins given enough of.
- **Implementation sketch:** new `_cast_verdant_bulwark()` sets
  `_bulwark_until = now + 12.0` and a 1 s heal-tick timestamp. In `_process`,
  while active: once per second `EventBus.base_healed.emit(4.0)` (reuses the
  §10.5 signal), and every frame find the base via
  `get_tree().get_first_node_in_group("base")`, then `set_debuff(0.6)` on units
  within 384 px of its `global_position` (clearing to `1.0` as they leave or on
  expiry). Optional faint green ring drawn around the FOB. Reuses
  `base_healed` + `set_debuff`; no new systems beyond what §10 already adds.
  Files: `AbilityController.gd`.

### 11.3 The Mesh — "System Seizure" (R)

- **Effect:** on cast, **immediately steal 3 resources per enemy** currently on
  the map (`3 × N` to the primary pool), then for **6 s** every Commander
  primary hit **leaks +1 resource**. A burst raid plus a draining window — the
  Mesh turns a wave into income.
- **Cooldown:** 100 s.
- **Unlock:** Mesh Second Milestone (Mesh Control II).
- **Identity hook:** the Mesh's weakest-passive-economy is designed to steal;
  its ultimate is the steal made total — the wave attacking you becomes the
  thing funding you. No other faction's ultimate touches the economy.
- **Implementation sketch:** new `_cast_system_seizure()`:
  `N = get_tree().get_nodes_in_group("units").size()`, then
  `EconomyManager.add_resource(primary, 3.0 * N)`; set `_seizure_until =
  now + 6.0`. The Commander already calls `add_lance_charge(dmg)` after each
  primary attack — add a sibling call `AbilityController.on_primary_hit()` (or
  fold into the existing one) that, while `now < _seizure_until`, does
  `EconomyManager.add_resource(primary, 1.0)` per hit. Pure economy + a timer;
  hooks the one place primary damage is already reported. Files:
  `AbilityController.gd`, one-line touch in `Commander.gd`'s primary-attack
  path.

### 11.4 Ultimate summary

| Faction | Name | Effect | CD | Role vs. Q/W/E |
|---|---|---|---|---|
| Architect | Compile Cascade | `50 + 2N` to **all** enemies on map | 90 s | Map-wide nuke that scales with enemy count (Lance is in-range, fixed) |
| Bloom | Verdant Bulwark | 12 s: FOB +4 HP/s, 40 % slow near FOB | 120 s | Endurance/zone defense (no base-kit FOB sustain at this scale) |
| Mesh | System Seizure | `3N` instant + 6 s of +1/hit | 100 s | Pure economy raid (no other ability generates resources) |

Each ultimate occupies a tactical space none of the base three touch —
map-wide reach, FOB sustain, and resource generation respectively — so slot 4
is never a bigger version of a slot the player already has. All three are
built from `get_nodes_in_group`, a timestamp, and an EventBus emit; the only
shared dependency is `EventBus.base_healed` (introduced in §10.5 for Bloom
Overdrive and reused by Verdant Bulwark). Implement §10 first; the ultimates
then need no new systems of their own.
