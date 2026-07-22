# Late-Game Balance Pass — Stat Lines, Cost Curves, Signature Matchups

> Session 14 output. Turns the design rulings of `core/23` into concrete
> numbers. `core/23` settled *what* each late-game system does; this doc
> settles *how much* — HP, DPS, resource cost, and the derived combat math
> for every unit from Tier 1 through Tier 6, plus the six signature units.
>
> Every number here is a **ship default**: a concrete value the build can
> be made and tested against today. Where `core/23` tagged an item
> PLAYTEST, this doc supplies the default and names the metric to
> instrument. Nothing here overrides a Hard Constraint from an existing
> core doc; cooldowns, cohort sizes, and caps are inherited as fixed.

---

## 0. Design Premise

The corpus has a complete roster (`core/17`, `core/21`) and a complete set
of design rulings (`core/23`), but no numbers. A builder cannot prototype
combat without HP and DPS values, cannot prototype the economy without
unit costs, and cannot prototype the signature matchup without stat lines
for the Apex and the Bio-Titan. This doc closes that gap.

It closes five items from the `core/23` Forward Queue outright by setting
ship defaults:

| `core/23` item | Closed here by |
|---|---|
| Tier 4 / Tier 5 unit costs | §2 cost curve + §5, §6 stat tables |
| Tier 6 unit costs | §2 cost curve + §8 stat table |
| Cross-sub-path absorption values | §9 |
| Bio-Titan vs. Apex stat lines | §7 |
| Second Milestone "submit" friction | §10 |

It does **not** touch the four non-combat PLAYTEST items (first-milestone
pacing, token-offering brightness, inheritance-equivalent thresholds) —
those are not unit balance and stay where `core/23` left them.

Five principles frame the pass:

1. **Numbers serve identity.** A balanced roster is not one where every
   faction has the same combat value. It is one where each faction's
   numbers *express* its loop identity from `core/10 §1`. The Architects
   are brittle in the stat line, not just the lore. The Mesh is
   under-budget in raw combat value because it pays for that value in
   theft and tempo.
2. **One normalized currency.** Each faction names its resource
   differently (alloy, biomass, bandwidth). For balance, all costs are
   stated in **Resource Units (RU)** — a normalized currency where one RU
   is one RU of economic effort regardless of faction. §3 maps RU back to
   each faction's real income rate.
3. **Cooldowns are fixed; cost and stats are the levers.** The cooldown
   ladder is a Hard Constraint from `core/21 §1`. This pass never touches
   it. Cost and stat lines are the only things tuned.
4. **Ship default, not final value.** Every number is built to be
   *playable and testable*, not *proven*. The doc names, per system, the
   metric that decides whether the default survives contact with playtest
   data.
5. **The curve must keep low tiers alive.** A higher tier must never make
   a lower tier pointless. The curve achieves this through cooldown
   gating, not through making low tiers cost-efficient — see §2.

---

## 1. The Balance Model

### The combat-value metric

Every unit is reduced, for comparison, to a single scalar:

> **Combat Value (CV) = (HP ÷ 1000) × DPS**

CV is a proxy for *lifetime damage* — how much damage a unit deals across
its whole life in a sustained fight. A unit with double the HP lives twice
as long; a unit with double the DPS deals twice as much per second; doing
both makes it worth four times as much in an attrition fight. CV being the
*product* of HP and DPS is therefore correct, not a quirk — it is why CV
grows faster than cost as tiers rise, and why the curve must be gated by
time (§2).

For cohort units (Bloom Sporelings), CV uses **cohort totals** — five
bodies' combined HP and DPS — because the cohort is the unit.

For units with no direct attack (Tier 4 support units, most of Tier 5),
raw CV is zero or near-zero. These are scored on **effective CV** — the CV
they *add* to a reference formation through their aura or utility. §5
states the reference formation and the modelled uplift.

### What "balanced" means here

A tier is balanced when:

- **CV per RU rises smoothly with tier** — higher tiers are better
  investments per RU, which is correct for an idle game.
- **CV per cooldown-minute also rises** — but is gated, so a high tier
  cannot be spammed.
- **No faction's same-tier CV deviates more than ±25%** from the tier
  budget *unless* the shortfall is paid back in named utility (theft,
  terraforming, aura) that the doc accounts for explicitly.

### Survivability classes

Raw HP understates a ranged unit and overstates an immobile one. Effective
HP (EHP) applies a survivability multiplier by engagement class:

| Class | Multiplier | Rationale |
|---|---|---|
| Melee | 1.00 | Must cross the map into fire. |
| Mid-range | 1.30 | Engages from partial safety. |
| Long-range | 1.70 | Engages before most return fire. |
| Immobile | 0.85 | Cannot reposition out of a bad matchup. |
| Phase (Echo-Walker) | 3.00 | Only 1 of 3 positions is real. |
| Two-pool (Remembered) | 1.00 | HP stat sums both 6,000 pools; the two-pool design *is* the survivability and is already counted in the 12,000 figure. |

EHP = HP × class multiplier. EHP is the survivability number used in the
spreadsheet; HP is the raw value used for CV (so CV stays a pure stat
comparison and is not double-counting positioning).

---

## 2. The Cost Curve

### The cooldown ladder (inherited, fixed)

| Tier | Cooldown | Source |
|---|---|---|
| T1 | 30 s | `core/17 §1` |
| T2 | 90 s | `core/17 §1` |
| T3 | 240 s (4 min) | `core/17 §1` |
| T4 | 420 s (7 min) | `core/21 §1` |
| T5 | 660 s (11 min) | `core/21 §1` |
| Milestone | 900 s (15 min) | `core/17 §1` |
| T6 | 480 s (8 min) | `core/21 §1` |

### The cost ladder

`core/23` set the curve shape: T4 ≈ 2× T3, T5 ≈ 4× T3, T6 priced against
the post-milestone economy. This doc fixes Tier 3 as the **baseline B**
and expresses every tier as a multiple of it.

> **B = 1,200 RU** (the normalized Tier 3 unit cost)

| Tier | Cost multiple | Normalized cost | RU / cooldown-minute |
|---|---|---|---|
| T1 | 0.083 B | 100 RU | 200 |
| T2 | 0.30 B | 360 RU | 240 |
| T3 | 1.00 B | 1,200 RU | 300 |
| T4 | 2.00 B | 2,400 RU | 343 |
| T5 | 4.00 B | 4,800 RU | 436 |
| T6 | 3.00 B | 3,600 RU | 450 |
| Milestone | 7.50 B | 9,000 RU | 600 |

Per-faction unit costs deviate from the normalized cost by up to ±10% for
faction texture (Mesh units run cheap, Architect units run dear). The
deviations are in the §4–§8 tables.

### Why Tier 6 costs *less* than Tier 5

`core/23` ruling: a Tier 6 unit should feel "as routine, relative to
economy size at that stage, as a Tier 3 unit is pre-milestone." Tier 6 is
3.00 B in absolute RU — but it is only ever produced *after* the milestone,
when the economy is roughly 3× its pre-milestone size (§3). Divide
3.00 B by the 3× economy and a Tier 6 unit costs the same *share of
income* as a 1.00 B Tier 3 did before the milestone. The absolute number
is higher; the felt cost is identical. This is the resolution of
`core/21` Open Question 2, made numeric.

### Why the curve keeps low tiers alive

CV per RU rises ~40× from T1 to Milestone (§11 has the table). On RU
efficiency alone, nobody would ever build a Tier 1 unit. Two things stop
that:

- **Cooldown gating.** A Sentry Spire produces a Drone every 30 s; a
  Nexus Core produces an Apex every 15 min. Across an hour the T1 line
  delivers 120 cycles to the Milestone line's 4. Low tiers are the only
  source of *sub-minute-cadence* pressure, and the secondary axis
  (`core/17 §8`) demands exactly that.
- **The RU/min tax is nearly flat.** Reading the right-hand column above:
  a full production stack costs 200 + 240 + 300 + 343 + 436 + 450 + 600
  = **2,569 RU/min** to keep every line cycling. Low tiers are a small,
  cheap, constant contribution — never a trap, never obsolete.

This is the §1 principle "keep low tiers alive" delivered by structure
rather than by flattening the efficiency curve.

---

## 3. The Economy Anchor

A cost curve is meaningless without an income curve to measure it against.
This section fixes the income side so "2,400 RU" has a felt meaning.

### Resource income by phase

Income is stated as RU/min for a competently-played Standard Architect —
the 100% reference faction. `core/10 §9b`: production is funded mainly by
surviving waves, topped up by idle income.

| Phase | Wave tiers | Income (RU/min) | What it must cover |
|---|---|---|---|
| Early | 1–10 | ~250 | T1 + T2 lines, first buildings |
| Mid | 11–25 | ~900 | T1–T3 lines, R1–R3 research |
| Late (pre-milestone) | 26–40 | ~2,600 | T1–T5 lines + milestone push |
| Post-milestone | 41+ | ~7,800 | full T1–T6 + Milestone stack, pacification, losses |

The pre-milestone-late figure (2,600) sits just above the full-stack tax
(2,569 minus the Milestone and T6 lines, which are not yet available =
1,519 RU/min) with healthy margin for between-wave construction. The
post-milestone figure is **3.0× the pre-milestone-late economy** — the
multiplier the Tier 6 costing in §2 depends on. It is driven by the Nexus
Core's +50% production broadcast (`core/17 §3`), the doubled wave rewards
that follow the milestone (`core/10 §3`), and a base that is simply larger.

The earlier phases are not run as a full continuous stack. In the early
game only the Tier 1 line cycles non-stop; Tier 2 and above are *pulsed*
from wave rewards, not banked from idle income (`core/10 §9b`). The
**continuous-line tax** that each phase must clear is therefore T1 alone
(early ≈ 200 RU/min), T1–T3 (mid ≈ 740), T1–T5 (late ≈ 1,519), and the
full stack (post-milestone ≈ 2,569). Against the income curve above,
every phase clears its continuous-line tax with a positive surplus — the
affordability check passes at all four phases, not only the late one. The
`Economy Anchor` sheet of `core/24_balance-model.xlsx` carries the live
version of this check.

### Faction economy multipliers

The factions do not earn RU at the same rate. This is identity, not
imbalance — `core/10 §1` and `core/17 §10` are explicit.

| Faction | Passive economy | Notes |
|---|---|---|
| Architects | 100% (reference) | Multiplicative; strongest idle loop. |
| Bloom | 60% early → 140% late | Scales with biomass coverage. Weak first, dominant last. |
| Mesh | 70% passive | `core/17 §7`. Designed to reach ~110% effective with active raiding; collapses toward 70% if hacking is denied. |

The unit costs in this doc are the **same RU number for every faction**.
A faction with a weaker economy is not given cheaper units — it is given a
different *income curve*. This keeps the cost tables readable and pushes
all faction asymmetry into the economy layer and the stat lines, where it
belongs.

---

## 4. Tier 1–3 Baseline Stat Grid

The anchor grid. Tier 4–6 and the signatures are all tuned relative to
these numbers, so these are settled first.

### Tier budgets (the notional average unit)

| Tier | HP | DPS | CV | Cost |
|---|---|---|---|---|
| T1 | 120 | 12 | 1.44 | 100 |
| T2 | 420 | 32 | 13.4 | 360 |
| T3 | 1,500 | 90 | 135 | 1,200 |

Each faction's unit sits on this budget in CV but splits HP and DPS
according to its identity: Architects DPS-lean and fragile, Bloom HP-lean
and durable, Mesh glass-cannon and under-budget (paying the gap in theft
and tempo).

### Tier 1 — Light / fodder (CD 30 s)

| Unit | Faction (shared) | HP | DPS | Cohort | Cohort HP | Cohort DPS | CV | Cost | Class |
|---|---|---|---|---|---|---|---|---|---|
| Drone | Architect | 80 | 14 | 1 | 80 | 14 | 1.12 | 90 | Mid |
| Sporeling | Bloom | 35 | 3 | 5 | 175 | 15 | 2.63 | 110 | Melee |
| Probe | Mesh | 55 | 18 | 1 | 55 | 18 | 0.99 | 80 | Melee (fast) |

The Bloom Sporeling cohort carries the highest raw CV at the tier — and is
still the weakest Tier 1 in practice. Its CV is delivered as **five
35-HP melee bodies**: the most AoE-fragile, most tower-exposed delivery
the game can produce. This is the numeric form of the `core/10 §1` "Bloom
is genuinely fragile for the first 5–8 waves" identity. The early weakness
is structural (range, per-body fragility, AoE vulnerability), not a
stat-line shortfall — exactly as `core/17 §10` describes it.

### Tier 2 — Mid generalist (CD 90 s)

| Unit | Faction | HP | DPS | CV | Cost | Class | Sub-path note |
|---|---|---|---|---|---|---|---|
| Auger-Walker | Architect | 340 | 42 | 14.3 | 360 | Mid | Standard +armor → 380 HP; Spiritual-Tech terrain pylon |
| Bramble-Walker | Bloom | 620 | 26 | 16.1 | 360 | Melee | Cellular Regen 2%/s stationary |
| Spike | Mesh | 240 | 46 | 11.0 | 320 | Mid | Hack Pulse — 5 s structure disable |

Tier 2 is the sub-path commit point (`core/17 §1`). The numbers above are
the shared chassis; the sub-path modifiers do not change the base stat
line, they add the conditional effects already specified in `core/17 §2,
§4, §6`.

### Tier 3 — Heavy anchor (CD 240 s)

| Unit | Faction | HP | DPS | CV | Cost | Class | Signature trait |
|---|---|---|---|---|---|---|---|
| Compiler | Architect | 1,150 | 135 | 155 | 1,300 | Long-range | Must deploy to fire; refunds 4% wave reward on kill |
| Mire-Beast | Bloom | 2,700 | 70 | 189 | 1,250 | Melee | Immune to slow/stun/hack; terraforms |
| Carver | Mesh | 720 | 110 | 79 | 1,100 | Mid | Data Siphon (4 s channel → Hacked Node) |

The Carver is deliberately ~40% under the tier CV budget. Its value is the
Siphon — economic warfare, not combat — and the doc accounts for the gap
rather than hiding it. A Carver that lands one Siphon has converted an
enemy structure's whole income stream; that is worth far more than the
56 CV it gives up. This is the `core/17 §10` "Mesh wins on tempo and
theft" identity expressed as a deliberate, documented CV shortfall.

---

## 5. Tier 4 — Sub-Path Specialists (CD 420 s, cost 2,400 RU)

Tier 4 is where the sub-path commit pays off. Five of the six Tier 4 units
have **no direct attack** — they are force-multipliers. They are scored on
*effective CV*: the CV they add to a reference formation.

> **Reference formation:** six mixed Tier 2–3 units in aura range, totalling
> ~600 raw CV. A +X% damage aura therefore adds ~6X effective CV.

| Unit | Faction / path | HP | DPS | Cost | Effect | Effective CV |
|---|---|---|---|---|---|---|
| Optimizer | Architect / Standard | 900 | 0 | 2,400 | +15% DMG, +10% accuracy aura | ~115 (15% of 600 DMG + accuracy) |
| Ley-Reader | Architect / Spiritual-Tech | 1,100 | 0 | 2,400 | Converts tiles to Ley-Tuned (+10% adjacency) | Compounds over hours; ~90 at 1 h, unbounded |
| Pollinator | Bloom / Purist | 1,400 | 0 | 2,400 | Catalyst cloud — per-death adaptation | ~120 (accelerated resistance stacking) |
| Composer | Bloom / Assimilator | 1,300 | 0 | 2,400 | Imprints absorbed weapons onto non-Chimera units, 60 s | ~130 (temporary roster-wide DPS) |
| Cascade-Node | Mesh / Networked | 600 | — | 2,200 | Suicide: 1,800 AoE + 4 s hack pulse on detonation | ~95 amortized per detonation |
| Echo-Walker | Mesh / Dreamer | 850 | 95 | 2,400 | Three positions, one real; EHP ×3 = 2,550 | 80.8 raw; survivability is the value |

Tier 4 effective CV (~95–130) is well under the §11 tier budget of 448 —
**by design**. A force-multiplier is not bought for its own combat value;
it is bought because its effect *scales with everything else on the
field*. The Optimizer's +15% aura is worth 115 CV over a 600-CV
formation, but 460 CV over a 2,400-CV late-game army. Effective CV is
stated at the reference formation; the spreadsheet lets the formation size
be tuned to see the aura scale.

The Echo-Walker is the one Tier 4 unit that fights directly. Its raw CV is
low; its **EHP of 2,550** (HP 850 × phase class 3.0) is the point — it is
a survivable harasser, not a damage dealer.

---

## 6. Tier 5 — Research-Gated Heavy Specialists (CD 660 s, cost 4,800 RU)

Tier 5 units are gated behind R5 research (`core/21 §4`) and are mostly
infrastructure — stationary, expensive, network-defining. They are scored
on a mix of raw and effective CV depending on whether they fight.

| Unit | Faction / path | HP | EHP | DPS | Cost | Role |
|---|---|---|---|---|---|---|
| Catalyst | Architect / Standard | 1,500 | 1,275 | — | 4,600 | Suicide buff — doubles a building's production 60 s |
| Convocation | Architect / Spiritual-Tech | 3,500 | 2,975 | 0 | 4,800 | +50% Warden Ley Field range, networks Wardens |
| Heartwood | Bloom / Purist | 6,000 | 5,100 | 40 | 4,800 | Deploys into a permanent map feature; spawns Sporelings |
| Vivarium | Bloom / Assimilator | 4,200 | 4,200 | 60 | 4,900 | Mobile unit factory — 1 lineage unit / 90 s |
| Routing-Spine | Mesh / Networked | 5,000 | 4,250 | 0 | 4,800 | +200% Sub-Router range for nearby structures |
| Anchor-Memory | Mesh / Dreamer | 3,800 | 3,230 | 70 | 4,700 | Fragment resonance; adjacent units +20% vs Ancients |

Tier 5 is the tier most distorted by the CV metric, and that is fine: a
Routing-Spine has zero DPS and zero CV, but a Mesh network without Spines
cannot reach across the map to hack. These units are **build-defining
infrastructure**. The spreadsheet flags them as `INFRA` and excludes them
from the per-tier CV-budget check — comparing a Routing-Spine's CV to an
Apex's would be a category error. What Tier 5 must satisfy instead is the
cost check: 4.00 B, gated behind R5, on an 11-minute cooldown. It does.

The Catalyst is priced slightly under tier (4,600 vs 4,800) because it is
*consumed on use* — `core/21` is explicit that the Catalyst "exists to be
spent." A consumable should not cost a full durable Tier 5.

---

## 7. The Signature Units & the Bio-Titan vs. Apex Matchup

The six Milestone signatures, then the matchup `core/23 §2` (`core/17`
Q3) flagged as "the question that determines whether the late game has
counterplay or attrition."

### Signature stat lines (CD 900 s)

| Unit | Faction / path | HP | DPS | CV | Cost | Defining mechanic |
|---|---|---|---|---|---|---|
| Apex | Architect / Standard | 9,000 | 600 (uncapped) | 5,400 → ∞ | 9,000 | Recursive Optimization: +1% base DMG / 10 s, no cap |
| Warden | Architect / Spiritual-Tech | 14,000 | 380 (→760 on terrain) | 5,320 → 10,640 | 9,000 | Immobile; Ley Field +25% DMG to all friendlies in radius |
| Bio-Titan | Bloom / Purist | 38,000 | 280 vs units / 1,400 vs structures | 10,640 / 53,200 | 9,500 | Cannot be hacked; self-spawns Sporeling cohorts |
| Chimera | Bloom / Assimilator | 16,000 | 350–650 (loadout) | 5,600–10,400 | 9,200 | Component Digestion — 3 absorbed-weapon slots |
| Hydra-Daemon | Mesh / Networked | 5,500 | 900 | 4,950 | 8,500 | Network Jump — teleport between Hacked Nodes / 8 s |
| The Remembered | Mesh / Dreamer | 6,000 + 6,000 | 520 | 6,240 (12k EHP) | 8,800 | Two HP pools, both must deplete; surfaces a Fragment / wave |

Cross-checks against the corpus:

- **Hydra-Daemon has the lowest HP at its tier** (5,500) — `core/17 §6`
  Hard Constraint, satisfied.
- **Hydra-Daemon has the highest DPS in the Mesh roster** (900) —
  `core/17 §6`, satisfied.
- The Hydra-Daemon's CV (4,950) is the lowest of the six signatures. It
  pays that gap for instant map-wide repositioning — the same
  CV-for-mobility trade the Carver makes at Tier 3.
- The Apex's CV is *base* 5,400 and unbounded; the table shows its
  scaling below.

### Apex scaling over time

Recursive Optimization adds 1% of *base* DMG every 10 seconds, uncapped.
HP never changes — the Apex gets sharper, never tougher.

| Time active | DPS | CV (HP fixed 9,000) |
|---|---|---|
| 0 min | 600 | 5,400 |
| 5 min | 780 | 7,020 |
| 10 min | 960 | 8,640 |
| 13 min | 1,068 | 9,612 |
| 20 min | 1,320 | 11,880 |
| 30 min | 1,680 | 15,120 |

### The matchup (resolving `core/23` — `core/17` Q3)

The ruling: the two units are **deliberately non-mirror and do not duel
cleanly**. The numbers must make the matchup decided by *map position and
timing*, not by a stat race. They do:

**A straight melee duel — the Bio-Titan wins, until very late.**
Bio-Titan DPS vs units is 280; against the Apex's 9,000 HP that is a
32-second kill. The Apex firing back at 600 DPS (base) needs 63 seconds to
chew through 38,000 HP, and still 40 seconds at 10 minutes of scaling.
**For its whole realistic life the Apex dies first in contact.** The duel
only turns Apex-favoured past the ~16-minute scaling crossover (at 20
minutes the Apex's 1,320 DPS is a 29-second kill) — and keeping a brittle
9,000-HP unit alive that long while a Bio-Titan closes *is itself the
positional win*. This is the numeric form of "Apex is brittle, Bio-Titan
is near-unkillable." The Apex must never be in early melee.

**A positional fight — the Apex wins before contact.** The Bio-Titan is
*very slow* and the standard primary axis is 4–5 minutes of travel
(`core/17 §8`). An Apex with long-range support fires the entire approach.
Four minutes at an average ~672 DPS is ~161,000 damage — over four times
(4.2×) the Bio-Titan's HP. **With range and time, the Apex shreds the
Bio-Titan before it arrives.**

**The decider is therefore distance, not stats.** A Bio-Titan that spawns
or breaks through close to the Apex's production base reaches it — and at
1,400 structure DPS, "Architect bases fall in seconds" (`core/17 §4`) is
literally true: a 4,000-HP Reactor is gone in under three seconds. An Apex
that holds range and buys time wins the economy war through Cascade
Optimization refunds before the Bio-Titan closes.

**The Sporeling answer is AoE, not a damage race.** The Bio-Titan
self-spawns a Sporeling cohort every 60 seconds. The Architect answer is
the Apex's **Compile Cascade** — one AoE strike down the whole primary
axis, clearing the chaff — *not* trying to out-DPS the Titan itself. The
Cascade costs the Apex 30% of current HP, which is survivable only if the
Apex is not also taking direct fire: it reinforces "hold range."

This is counterplay, not attrition. Neither unit has a stat that beats the
other; the player who controls **map position and engagement timing**
wins. Exact stat tuning remains a PLAYTEST item — the metric to instrument
is *win rate of the Bio-Titan as a function of spawn distance to the
enemy base*. The target curve: Bio-Titan favoured inside ~90 seconds of
the base, Apex favoured beyond it.

---

## 8. Tier 6 — Post-Milestone Lines (CD 480 s, cost 3,600 RU)

`core/21 §5`: only the Architects get a true Tier 6 *unit* line. The Bloom
and Mesh "Tier 6" are structural unlocks, not production units.

### Architect Hyper-Specialists

| Unit | HP | DPS | DPS in niche | CV | Cost | Niche |
|---|---|---|---|---|---|---|
| Arbiter | 3,200 | 280 | 700 vs organic / biomass (×2.5) | 896 (2,240 in niche) | 3,600 | Anti-Bloom |
| Splice-Counter | 3,400 | 230 | full vs Hacked Nodes; hack-immune | 782 | 3,600 | Anti-Mesh |
| Auditor | 4,000 | 180 | only Architect unit that engages Ancient observers | 720 | 3,800 | Anti-Ancient |

Hard Constraint check (`core/21 §8`): a Tier 6 unit "cannot exceed
signature stat lines" except in its niche. The Arbiter's general DPS (280)
is far below the Apex's base (600); its *anti-Bloom* DPS (700) exceeds the
Apex's per-shot output against Bloom — which is exactly the
`core/21 §5` example ("an Arbiter does more damage to Bloom than an Apex
does per shot"). Niche-exceeds, general-trails: constraint satisfied for
all three.

The low raw CV (720–896, against the §11 Tier 6 budget of 828) is
correct. These are *situational answers*, produced when the threat
appears, on a short 8-minute cooldown. Their value is conditional and
spikes hard when their niche is on the board.

### Bloom & Mesh "Tier 6" — structural, not a unit line

- **Bloom (post-Biosphere):** adaptation slots rise from 1 to 3 per unit
  type, and environmental hazards (Toxic Bloom Tiles, Root-Quakes) unlock.
  No production unit, no per-unit cost. Costed instead as a one-time
  **research/milestone unlock** — see the spreadsheet `Structural` sheet.
- **Mesh (post-Mesh-Control):** the Network Cascade ability and
  Daemon-Pack concurrency (up to 3 Hydra-Daemons / 2 Remembered at once).
  Again no new unit — it raises the *concurrency cap* on existing
  signature production. Costed as a milestone unlock.

The §2 Tier 6 cost (3,600 RU) therefore applies in full only to the three
Architect units. This is a real asymmetry and it is on-identity: the
Architects' answer to a post-milestone world is *more specialised units*;
the Bloom's answer is *the world itself becoming hostile*; the Mesh's
answer is *more of its apex predators at once*.

---

## 9. Cross-Sub-Path Absorption Values

Resolving `core/23` (`core/17` Q1): cross-sub-path absorption "works and
is embraced," granting the **baseline effect but not the sub-path synergy
bonuses**. This section makes "baseline" numeric.

**The rule:** an absorbed component delivers **100% of its baseline
magnitude** and **0% of any synergy, chaining, or stacking multiplier**.

The two systems that absorb:

- **Chimera Component Digestion** (`core/17 §4`) — 3 weapon slots.
- **Composer imprint** (`core/21 §3`) — temporary, 60 s, onto non-Chimera
  Bloom units.

Worked example, the one `core/23` named — a Chimera absorbing a
Spiritual-Tech Warden's terrain-coupling pylon:

| Component | Baseline (Chimera gets this) | Synergy (Chimera does NOT get this) |
|---|---|---|
| Terrain-coupling pylon | +10% DMG while on a natural-terrain tile | Chaining the buff through Convocations; the Ley Field network multiplier |
| Absorbed plasma carbine (Architect) | The carbine's base DPS contribution to one slot | Architect Self-Calibration regen near production buildings |
| Absorbed data-fang (Mesh) | The fang's base DPS + base 1% Data Drain | Hacked-Node network routing of the drained resources |
| Absorbed whip-tendril (Bloom) | The tendril's base DPS | Cohort Memory adaptation stacking |

Numeric ship defaults:

- Absorbed **weapon DPS**: 100% of the source unit's listed DPS, capped
  at the Chimera's own slot ceiling of **220 DPS per slot** (3 slots →
  the 350–650 DPS range in §7).
- Absorbed **passive % buffs** (terrain coupling, drain, regen): 100% of
  the *baseline* percentage, 0% of any per-instance stacking. A buff that
  reads "+10% per adjacent X" delivers a flat **+10%, once**.
- Absorbed **on-kill / on-event effects** (refunds, adaptation triggers):
  fire at **50% of source magnitude** — they were tuned around their
  faction's whole economy and would over-reward out of context.

This is the seam of Option B made playable: a Chimera *can* wear another
faction's technology, and it works — but it never works as *well* as it
does for the faction that grew up around it. The synergy is the
birthright; the baseline is what can be borrowed.

---

## 10. Second Milestone Friction Tuning

Resolving `core/23` (`core/21` Q3): submitting to a Second Milestone "is
not easy mode" — the target feeling is *unsettling*, not *relaxing*. This
section sets the friction numbers that enforce that.

The common principle: **submit trades authorship for efficiency, and the
efficiency is real but always slightly worse than what an attentive player
would have chosen.** The autonomous system optimises for its *own* metric,
not for surviving the next wave.

### Architect — Singularity II

| Friction | Ship default |
|---|---|
| Buildings auto-converted without consent | 20% of production buildings (inherited, `core/21 §6`) |
| Combat-effectiveness penalty while submitted | **−10%** — the autonomous unit mix is meter-optimal, not threat-optimal |
| Manual override cost (Resist path) | 4% of the building's current production value, **+1% per repeat override on the same building**, capping at 15% |

The −10% is the key new number. Submitting *looks* like a power-up
(efficiency is up, manual work is down) but the faction is now slightly
worse in the fight that matters. That gap is the unease.

### Bloom — Biosphere II

| Friction | Ship default |
|---|---|
| Surplus Biomass the player cannot direct | **12%** of total biomass income is spent autonomously |
| Pruning cost during the event (Assimilator) | 5× normal (inherited, `core/21 §6`) |
| Autonomous structures that conflict with player strategy | ~1 in 3 autonomous builds is placed somewhere the player would not have chosen |

### Mesh — Mesh Control II

| Friction | Ship default |
|---|---|
| Hacked Nodes flipping to Network-Controlled | 25% of player-controlled nodes per real-time hour |
| Output of a Network-Controlled node | 60% of normal (inherited, `core/21 §6`) |
| Reclaim cost | one Tier 3 unit's RU per node (inherited) |

**Steady-state math.** Network-Controlled nodes do not flip back on their
own — the only way back is Reclaim, which destroys the node. So absent
player effort, the network trends fully Network-Controlled. Effective
hacked-node income decays toward a floor:

> Each hour, 25% of still-player-controlled nodes flip; each flipped node
> drops to 60% output. After 1 h: ~90% of original income. After 2 h:
> ~83%. Asymptote (no Reclaim churn): **60% of original hacked-node
> income** — the network still runs, but at a permanent ~40% haircut on
> its stolen economy.

That 40% haircut is the cost of submitting. It is survivable — the Mesh
"continues to function" — but it is a standing tax the player feels every
hour, which is exactly the intended unsettling tone.

**The validation metric (PLAYTEST):** post-event player sentiment plus
session length after a Second Milestone fires. If "submit" players play
*longer and report relief*, the friction is too low — raise the penalties
until submitted sessions read as tense. If submit players quit, the
friction is too high.

---

## 11. Faction Asymmetry Check

Does the grid honour the loop identities? The CV-efficiency curve first:

| Tier | CV | Cost | CV per RU | CV per cooldown-min |
|---|---|---|---|---|
| T1 | 1.44 | 100 | 0.0144 | 2.9 |
| T2 | 13.4 | 360 | 0.0372 | 8.9 |
| T3 | 135 | 1,200 | 0.1125 | 33.8 |
| T4 | 448* | 2,400 | 0.187 | 64.0 |
| T5 | 1,560* | 4,800 | 0.325 | 142 |
| Milestone | 5,720 | 9,000 | 0.636 | 381 |
| T6 | 828 | 3,600 | 0.230 | 104 |

\* T4/T5 budgets are notional; most real units at those tiers are
infrastructure scored on effective CV (§5, §6).

CV per RU rises monotonically and smoothly; CV per cooldown-minute rises
monotonically and is gated. The curve is sound.

The identity check:

| `core/10` identity claim | Where the numbers honour it |
|---|---|
| Architects are DPS-strong and brittle | Drone 80 HP / 14 DPS; Compiler 1,150 HP carries the highest T3 DPS (135); Apex 9,000 HP — lowest signature HP bar the Hydra-Daemon, and no regen |
| Architects' weakness is burst raid | Apex dies in 32 s of melee contact (§7); Compiler must deploy and is the priciest pre-milestone target |
| Bloom is slow, then unstoppable | Sporeling delivered as 5×35-HP melee bodies (weakest start); Bio-Titan 38,000 HP, the highest in the game |
| Bloom's economy inverts over a run | Economy multiplier 60% early → 140% late (§3) |
| Mesh has the weakest passive economy | 70% passive multiplier (§3); every Mesh unit sits under its tier CV budget |
| Mesh wins on tempo and theft | Carver 40% under-CV, pays it back in the Siphon; Hydra-Daemon lowest signature CV, pays it back in teleportation; Probe steals wave reward |
| Heresy paths trade ceiling for resilience | Warden 14,000 HP (immobile, tanky) vs Apex 9,000 (mobile, fragile); same cost, opposite survivability profile |

Every weakness in the table is a number, not a flavour line. The grid
honours the corpus.

---

## 12. Hard Constraints (Implementation Checklist)

- **The cooldown ladder is untouched.** 30 s / 90 s / 240 s / 420 s /
  660 s / 900 s / 480 s. This doc tunes cost and stats only.
- **Cost curve is fixed to B = 1,200 RU.** T1 0.083B / T2 0.30B /
  T3 1.00B / T4 2.00B / T5 4.00B / T6 3.00B / Milestone 7.50B.
  Per-faction deviation is capped at ±10%.
- **Unit cost is the same RU figure for every faction.** Faction economic
  asymmetry lives in the income curve (§3), never in discounted units.
- **CV = (HP ÷ 1000) × DPS**, cohort totals for cohort units. It is a
  comparison metric, not a balance target to equalise.
- **Infrastructure units are exempt from the per-tier CV-budget check.**
  Routing-Spine, Convocation, Heartwood, and the like are checked on cost
  and cooldown only.
- **No Tier 6 unit exceeds a signature stat line except in its niche.**
  Verified in §8 for all three Architect hyper-specialists.
- **Absorbed components deliver 100% baseline, 0% synergy** (§9).
  On-kill/on-event absorbed effects fire at 50% magnitude.
- **Second Milestone "submit" carries a real, standing penalty** —
  −10% combat effectiveness (Architect), 12% undirected income (Bloom),
  ~40% asymptotic hacked-income haircut (Mesh). Submit is never a power-up.
- **Every number in this doc is a ship default.** It is built to be
  prototyped and instrumented, not treated as final. §13 lists what the
  data decides.

---

## 13. Open Questions / What Playtest Decides

The design is settled. These numbers need data before they are final:

1. **Bio-Titan vs. Apex spawn-distance curve.** Instrument Bio-Titan win
   rate as a function of spawn distance to the enemy base. Target:
   Bio-Titan favoured inside ~90 s of travel, Apex favoured beyond.
   Tune the Bio-Titan's move speed and the Apex's base DPS against that
   curve — not the HP values, which carry the identity.
2. **The CV-per-RU slope.** The curve rises ~44× from T1 to Milestone. If
   playtest shows players abandoning T1–T2 production entirely once T4+
   is online, the cooldown gating is not enough — flatten the slope by
   raising high-tier costs, never by buffing low-tier stats.
3. **Tier 4 effective-CV at scale.** The aura units are tuned against a
   600-CV reference formation. If late-game formations routinely exceed
   2,500 CV, the auras may overperform — instrument average formation CV
   in aura range at wave tier 40+.
4. **Second Milestone submit sentiment.** The §10 friction values are a
   feel target. Instrument post-event session length and sentiment;
   raise friction if "submit" reads as relief, lower it if players quit.
5. **Absorbed on-kill effects at 50%.** The half-magnitude rule for
   absorbed refund/adaptation effects is a guess at "enough to be worth
   it, not enough to be degenerate." Watch Chimera/Composer pick rates.

---

## 14. Amendments This Pass Implies

The numbers here are new; the originating docs should carry pointers so
the corpus stays self-consistent. None changes a Hard Constraint.

- **`core/17`** — the Tier 1–3 stat grid (§4) is new canon. The roster
  doc should reference `core/24 §4` wherever it describes a unit's
  combat role.
- **`core/21`** — Open Questions 1 and 2 (Tier 4/5 and Tier 6 costs) are
  now closed by `core/24 §2`; the stat lines for Tier 4–6 units live in
  `core/24 §5, §6, §8`. Open Question 3 (submit balance) is closed by
  `core/24 §10`.
- **`core/23`** — five Forward-Queue PLAYTEST items now have ship
  defaults (see §0). The `core/23` Playtest backlog should be annotated:
  these items move from "default named" to "default specified, instrument
  to confirm."
- **New supporting artifact** — `core/24_balance-model.xlsx`, the live
  tuning spreadsheet. Every number in this doc is a cell there; the doc
  is the rationale, the spreadsheet is the working model. When a number
  changes in playtest, it changes in the spreadsheet first and this doc
  is re-derived from it.
