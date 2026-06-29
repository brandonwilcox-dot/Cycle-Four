# Playtest Backlog — 2026-06-28 (VFX playtest session)

> **Status: CAPTURED, NOT SCHEDULED.** These came out of the 2026-06-28 combat-VFX
> playtest. They are design intent / future work — **do not start implementing any
> item without picking it with the user first.** This is a holding doc, not a plan.

The VFX pass itself (tracers, muzzle, impact sparks, death poofs) was confirmed
working in this playtest. Everything below is follow-up.

---

## A. Visual track follow-ups

- **A1 — Upgraded tower visuals.** Upgraded/branched towers currently render
  identically to tier 1 — no visual difference between tiers or mastery branches.
  Each tier (and ideally each branch) needs a distinct look. Direct follow-on to the
  juice pass.

## B. Base-assault redesign — progression-gated, phased

- **B1 — Build exclusion zone too large.** The no-build DMZ pushes garrisons too far
  outside the enemy base's range to press an attack, so the player still ends up using
  the Commander to solo the base. Tune the DMZ radius vs. garrison assault reach so an
  army can actually engage the base.
- **B2 — Gate the assault behind waves.** The player must complete N waves (e.g. 5)
  before assault **phase 1** can be initiated against a base.
- **B3 — 4-phase attack sequence with a boss finale.** Destroying a base becomes a
  4-phase sequence; the **final phase is a "boss" attack**: a harder boss wave that may
  spawn an **enemy commander** and requires a **mixed strategy**, including **micro
  control of the player Commander**. (Ties to B1/B2 — this is the payoff structure.)

## C. Garrison / friendly army tactics

- **C1 — Advance when idle, but never abandon the FOB.** Idle (not currently defending)
  garrison units should advance toward enemy structures and attack if in range.
  **HARD CONSTRAINT:** they must NOT neglect FOB defense to chase the base — "don't
  leave the Shire for Mordor." Defense always takes priority; advancing is only a lull
  behavior. (Refines the existing C3 standing-order raid behavior.)
- **C2 — Formations + staging, not a conveyor.** When idle from defending, units should
  **pause, form a military formation, enter a "preparation mode," then press the attack
  as a coordinated group** — not a single-file trickle of units. The player should see
  *groups* of units make an effective combined press.

## D. Enemy tactics (mirror of C)

- **D1 — Enemies attack in groups/columns.** The formation/staging change (C2) should
  also update **enemy** tactics — want to see groups of enemy units, not a conveyor.
  This may require letting units **flow around the path more loosely** so they can form
  **columns**. If so, update the pathing/flow model accordingly. (Couples with F2 —
  looser, terrain-following paths give room for columns.)

## E. Convoy

- **E1 — Organic movement + real pathing + visuals.** The convoy currently doesn't
  really seek a path, **occasionally fails to make it back to the FOB**, and **clips
  through walls**. Give it proper pathfinding (respect walls/terrain), more organic
  movement, and a visual improvement. (Overlaps the known convoy item in the standing
  backlog.)

## F. Terrain & map texture

- **F1 — Map terrain.** Add terrain texture and features: **water flow, jungle /
  forest, and geological features (sinkholes, quicksand, valleys, etc.).** Intended as
  both a visual upgrade AND gameplay-affecting terrain. (Bigger than the proposed
  cosmetic "environment backdrop" pass — this is real terrain.)
- **F2 — Organic, terrain-following paths.** Paths from enemy spawns to the FOB should
  be more organic and **follow the terrain** rather than reading as carved corridors.

## G. Dynamic enemy pathing (territory pressure)

- **G1 — New paths from un-addressed conquered territory.** If the player can't reclaim
  a conquered (enemy-held) territory within **5–10 waves**, the enemy gets the option to
  begin **pressing a new path to the FOB**. These new paths are **temporary**: the
  player can push them back **within 5 turns of construction**; after that they
  **entrench** and become much harder to remove.
- **G2 — Flanker ("orange") AI overhaul.** The orange enemies that reclaim territory
  should be the ones that attempt the new paths (G1). Improve their AI so they **stop
  clustering pointlessly around their own base** ("building a Costco parking lot") and
  instead **seek a better path to the FOB within the map's geographic limits.**

---

---

# Addendum — 2026-06-28 (2), A1 tower-visuals playtest

A1 confirmed working (tiers + branches visually distinct; antenna/detector/halo confirmed). The
**barrel-aiming "locked" bug was fixed in-session** (turret now continuously tracks its target, not
only on fire). New items surfaced:

- **H1 — Bloom corrosive feel (early game).** Enemies die in ~2 shots before any corrosive
  secondary/DoT is visible; the effect only reads clearly past ~wave 10. Either give corrosive a
  faster/visible tell early or adjust early time-to-kill. Feel/balance.
- **H2 — Tower won't fire on a point-blank enemy (Bloom playtest).** An enemy nearly on top of a
  Bloom tower wasn't targeted (pollen still slowed it). Most likely the **spawn DMZ no-fire buffer**
  (`Tower._select_target` skips units where `MapGrid.is_in_spawn_dmz(pos)`), and/or stealth
  detection. Pre-existing targeting/detection issue (NOT caused by A1). Investigate DMZ radius vs
  tower placement near spawns; consider firing on in-DMZ enemies once they're adjacent to a tower.
- **H3 — Mesh hijack too strong (user: "works too well").** Tone down conversion — frequency,
  duration, and/or simultaneous-conversion cap (`FactionPerks.MESH_HIJACK_*`). Explicit backlog ask.
- **H4 — Power curve too steep / wave scaling too shallow.** By ~wave 5 all towers are maxed and a
  single Tier 3 tower holds the entire advance. Rebalance tower power curve and/or wave difficulty
  scaling so defense doesn't trivialize. Couples with the B assault-gating arc.
- **H5 — Faction-distinct tower silhouettes (A1 follow-on).** Towers are readable per tier/branch but
  should eventually differ more by *faction*, not just color — distinct structural language per faction.
- **H6 — [MAJOR / STRATEGIC] 3D or 2.5D rendering.** User wants units/structures in 3D with a default
  ~45° camera so structure *height* reads; the game is currently fully 2D top-down (`_draw`-based).
  This is a large strategic pivot, not a quick item — needs an explicit decision and scoping (true 3D
  rewrite vs. a 2.5D presentation layer over the existing 2D logic). See the 3D-decision note.

## Cross-links (for whoever schedules these)

- **F1/F2 enable G1/G2** — organic, terrain-following paths are the substrate dynamic
  pathing carves through.
- **C2 + D1 share one system** — a formation/staging + looser-flow model applied to both
  friendly and enemy units.
- **B1 → B2 → B3** are one arc — the assault redesign; B1 is the immediate feel fix,
  B2/B3 the structure on top.
- **A1** is the only pure-visual item; it belongs with the ongoing juice track.
