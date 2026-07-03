# Commander Mech Directions — per-faction build proposal

> Requested 2026-07-02 (round-4 playtest): "Commanders should all be mechs, but there should
> be more distinction between them. Review the Codex and propose some options."
> User seed directions: Architects sleek/slender (Aeon, Supreme Commander); Bloom organic —
> crab or insect; Mesh spider- or octopus-like, many dexterous limbs.
>
> This is a PROPOSAL — nothing here is implemented. The current shared mech
> (legs/pelvis/torso/pauldrons/head/cannon/mast in `Commander.gd _build_visual`) remains the
> fallback until a pick lands. All options are buildable from Godot procedural primitives
> (Box/Sphere/Capsule/Cylinder/Torus), multi-part, sharing the substrate material — same
> technique as the current mech and `UnitBodies.gd`, so tint/substrate/HP-bar mechanics carry
> over unchanged. Sizes target the current envelope (~60–75 px tall; units are ~24).

## The canon lens

- **codex/05 — cultures.** Architects: "patient in the way a long calculation is patient…
  they do not see themselves as conquerors, they see themselves as an expedition." Bloom: "a
  living tide… it does not conquer territory, it *becomes* territory." Mesh: "the network is
  the self… it does not decide, it computes."
- **codex/11.3 — fixed visual identities.** Architect cold precision + white-gold/amber;
  Bloom forest green + bioluminescence; Mesh near-black + electric blue.
- **codex/08 — the three substrates** (the Mark's circles): crystalline lattice / biological
  fiber weave / conductive mesh. The Commander is each faction's *hand on the battlefield* —
  it should be the purest expression of its substrate on the field.
- **Gameplay identity carried by the silhouette:** the Commander is an *engineer-leader*
  (builds/repairs with a beam, claims ground by walking, mortal). Each design below gives the
  engineering fantasy a faction-true body.

---

## ARCHITECTS — sleek, slender, precise (Aeon-inspired)

The Aeon reference translates well to canon: smooth symmetric curves, minimal seams, floating
elements, an impression of effortlessness — engineering so refined it no longer shows its
work (codex/05: "disciplined technological refinement"). Nothing stomps; everything glides.

### A1 — "The Needle" (hovering spire) ★ RECOMMENDED
- **Silhouette:** a tall, slender, legless spire that hovers above the ground — a polished
  white-gold monolith tapering upward, with a thin floating halo ring near its crown and two
  slim wing-blades hovering detached at its sides. The marble-obelisk construction motif,
  walking among its works.
- **Canon:** the expedition's instrument, not a soldier (05); cold precision, minimal seams
  (11.3); a crystalline lattice given a body (08). Pairs with the glide gait and the new
  polished substrate.
- **Parts (9):** body = CylinderMesh (top_radius 6, bottom_radius 13, height 56) or stacked
  tapered cylinders; crown = SphereMesh r7; halo = TorusMesh (inner 14/outer 17) floating at
  crown height; 2 wing-blades = thin BoxMesh (4×34×12) hovering ±22 px, swept back 15°;
  underside glow disc = CylinderMesh (r 12, h 2) with emissive amber, unshaded; sensor pip.
- **Animation hooks:** idle = slow 3-px hover bob + halo counter-rotation; movement = body
  tilts ~6° into travel, wing-blades lag 0.1 s behind (floating-element feel); build = halo
  drops to the workpiece height and spins faster (the carve ring's sibling).
- **Effort: LOW** — no leg animation at all; the hover reads as intentional elegance.

### A2 — "The Cathedral Strider" (slender biped)
- **Silhouette:** impossibly thin, tall biped — stilt legs, narrow waist, swept shoulder
  fins, a small head under a floating halo. Reads as a walking cathedral spire.
- **Parts (11):** 2 legs = 2-segment thin CapsuleMesh chains (r 3, len 24 each segment);
  pelvis wedge; slim torso (Box 14×26×16); 2 swept fins (thin boxes, 25°); head sphere; halo
  torus; chest gem (emissive amber).
- **Animation hooks:** walk = slow, long-period leg swings (dignity, not haste); idle = halo
  breathing. Build = kneels slightly toward the workpiece.
- **Effort: MEDIUM** — 2-segment leg articulation with phase-offset sines; more code than A1
  for a similar payoff.

### A3 — "The Attended Monolith" (obelisk + drones)
- **Silhouette:** a floating rectangular marble slab (the construction obelisk itself,
  mobile), attended by three tiny orbiting service drones that do its physical work.
- **Parts (6):** slab = BoxMesh (18×54×26, polished substrate); 3 drones = the Mesh
  construction-drone build re-tinted amber; glow disc.
- **Animation hooks:** drones orbit; during build they fly to the structure (reuses
  ConstructionRig logic).
- **Effort: LOW**, but **risk:** overlaps the *Mesh* drone language — weakens faction
  distinction, which is the whole brief. Included for completeness, not recommended.

---

## BLOOM — organic, biological (crab / insect)

The Bloom Commander shouldn't look *manufactured* at all — it is a grown thing the colony
sent (codex/05: "it does not negotiate so much as it commits"). Asymmetry is allowed —
nothing alive is perfectly symmetric — and the bioluminescent substrate does the talking.

### B1 — "The Broodmother" (crab) ★ RECOMMENDED
- **Silhouette:** a wide, low crab — a broad domed carapace on six stepping legs, one
  oversized crusher claw and one slender manipulator claw (the engineering limb!), with a
  cluster of spore polyps on its back that breathe with the V4 pulse.
- **Canon:** the living tide's landholder — low, wide, planted (05: "fragile when young,
  nearly unkillable when mature"); biological fiber weave (08); forest green +
  bioluminescence (11.3). The asymmetric claws give it instant recognizability at RTS zoom.
- **Parts (~14):** carapace = SphereMesh (r 26, height 30, squashed); 6 legs = 2-segment
  CapsuleMesh (r 3.5) splayed at 50°-spaced yaws; crusher claw = Box 16×10×14 + jaw wedge;
  manipulator = thin capsule chain; 3–4 polyps = SphereMesh r 4–6 on the shell (emissive
  green, registered for the breathe tick); eye stalks = 2 thin capsules + spheres.
- **Animation hooks:** walk = tripod leg-stepping (two sine groups in anti-phase — the lope
  gait grown up); idle = carapace breathing (scale 1±0.02), polyps pulsing; build = the
  manipulator claw extends toward the structure and the beam originates from it.
- **Effort: MEDIUM** — leg phase groups are ~15 lines; everything else is placement.

### B2 — "The Mantis Cultivator" (upright insect)
- **Silhouette:** an upright mantis — raised thorax, folded engineering forelimbs held like
  a monk's hands, four walking legs, long antennae. The gardener of the tide.
- **Parts (~13):** thorax capsule, abdomen sphere, 2 folded forelimbs (2-segment capsules),
  4 legs, head wedge + antennae (thin capsules), back polyps.
- **Animation hooks:** forelimbs unfold to build (strong fantasy moment); antennae sway.
- **Effort: MEDIUM-HIGH** — the folded-forelimb pose needs careful part rotations to read.

### B3 — "The Tide Beetle" (domed walker)
- **Silhouette:** a heavy beetle whose shell splits open when building, venting spores.
- **Parts (~10):** dome shell in 2 halves (rotatable), 6 stub legs, polyps inside the shell.
- **Animation hooks:** shell opens during build (rotate halves ±25°); simplest gait.
- **Effort: LOW-MEDIUM**, but less distinct from a garrison building when stationary.

---

## MESH — many dexterous limbs (spider / octopus)

The Mesh Commander should be *mostly limbs* — the body is just a node; the reach is the
point (codex/05: "the network is the self… when a node is lost it reroutes"). Near-black
chassis, electric-blue signal light at every joint (11.3), conductive mesh made ambulatory
(08).

### M1 — "The Weaver" (spider) ★ RECOMMENDED
- **Silhouette:** a compact near-black core body slung low between EIGHT thin, angular,
  two-segment legs, each joint marked by a small electric-blue emissive node; one sensor
  stalk raised like an antenna mast. At rest it crouches; moving, it flows.
- **Canon:** dexterous, fast, everything-is-reach (05); conductive mesh substrate — the legs
  ARE the network diagram (08); near-black + electric blue (11.3). The skitter gait scaled up.
- **Parts (~21, mostly repeated):** core = Box 20×12×16 + underslung Box 14×8×12; 8 legs =
  2 thin boxes each (3×22×3 upper at 40° out-down, 3×26×3 lower at 70° down) with a joint
  node sphere (r 2.5, emissive blue) at each knee; sensor stalk = thin box + emissive tip;
  8 foot tips optional.
- **Animation hooks:** walk = alternating tetrapod groups (legs 1,3,5,7 vs 2,4,6,8 on
  anti-phase sines — same technique as B1, more legs); idle = individual leg micro-twitches
  (the skitter DNA) + joint nodes pulsing in sequence AROUND the body (signal traveling the
  network — very cheap, very canon); build = two front legs raise and "type" toward the
  structure while drones… no drones needed; the legs are the builders.
- **Effort: MEDIUM** — one leg-builder function stamped 8×; the gait function is shared math
  with B1.

### M2 — "The Signal Kraken" (hovering octopus)
- **Silhouette:** a levitating dark bell/core with 6–8 dangling articulated tentacles
  (chains of 3–4 small capsules each) that writhe continuously and reach toward whatever it
  works on. Blue light runs DOWN each tentacle in sequence.
- **Canon:** the purest "it computes" body — nothing about it walks; it is suspended in its
  own field, all reach and no posture (05, 08).
- **Parts (~30):** bell = SphereMesh squashed + skirt cylinder; 8 tentacles × 3–4 capsule
  segments with per-segment sine offsets; per-segment emissive nodes.
- **Animation hooks:** tentacle writhe = per-segment phase-offset sines (mesmerizing,
  ~20 lines); build = tentacles converge on the workpiece.
- **Effort: MEDIUM-HIGH** — most parts and the most per-frame transforms of any option;
  also the most striking. The aspirational pick.

### M3 — "The Marionette" (detached limbs)
- **Silhouette:** a floating core with limb segments that are NOT physically attached —
  leg pieces hover in formation, connected only by thin emissive energy lines. Unsettling,
  maximum-canon ("the network is the self" — the body is a *diagram*).
- **Parts (~16):** core + 6 floating limb segments + energy lines (thin unshaded emissive
  boxes stretched between joints, updated per-frame).
- **Animation hooks:** segments drift/settle with lag; lines re-stretch each frame.
- **Effort: HIGH** (per-frame line math) and readability risk at distance. Future flourish.

---

## Comparison & recommendation

| Option | Effort | Distinction | Canon fit | Risk |
|---|---|---|---|---|
| A1 Needle | LOW | ★★★ (only hovering unit) | ★★★ | barely-a-mech? (user said "mech" — confirm hover is acceptable) |
| A2 Strider | MED | ★★★ | ★★★ | thin legs may shimmer at distance |
| B1 Broodmother | MED | ★★★ (only wide unit) | ★★★ | 6-leg gait tuning |
| B2 Mantis | MED-HIGH | ★★ | ★★★ | pose readability |
| M1 Weaver | MED | ★★★ | ★★★ | leg clutter at min zoom |
| M2 Kraken | MED-HIGH | ★★★ | ★★★ | perf trivial, effort real |

**Recommended first picks: A1 Needle + B1 Broodmother + M1 Weaver.**
Three completely different silhouettes (tall hover / wide crawler / low many-legged), three
different motion languages (glide / tripod-step / tetrapod-flow), each the purest field
expression of its substrate — and all three land in one session using the existing multi-part
+ shared-substrate-material technique. A2 and M2 are natural second-pass upgrades if any
first pick underwhelms in play. If "mech" strictly means *legs* for the Architects, swap
A1 → A2.

**Implementation notes for whichever picks land:**
- Build as `_build_visual` variants keyed on `FactionManager.active_faction` (or a shared
  `CommanderBodies.gd` mirroring `UnitBodies.gd`).
- Keep `_body` as the root MeshInstance3D (HP bar, pip, selection ring, BODY_LIFT math all
  survive); gaits get a small `_animate(delta)` mirroring Unit's, driven by real movement.
- The engineer beam origin should move to each design's "working limb" (halo / manipulator
  claw / front legs) — one position constant per design, big fantasy payoff.
