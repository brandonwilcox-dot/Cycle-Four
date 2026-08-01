# Siege Foundry (Architect T3, `architects_t3.tres`) — import notes, 2026-07-27

Imported as `assets/models/buildings/architect_siege_foundry_hifi.glb`. Battle3D boot log empty.
Follows the pipeline in `../Sentry_Spire/RODIN_RECIPE_Sentry_Spire.md`; only the deltas are here.

## Shipped

| | Value |
|---|---|
| Source | `base_basic_pbr (2).glb` (.glb ✅, 19,856 tris ✅) |
| Bounds | 1.886 × 1.221 × 1.760 — squat and wide, ground-aligned (min y 0.000) |
| Split seam | **y = 0.85** (collar waist: maxR 0.242 vs 0.31 below / 0.53 above) → `foundry_base` 16,489 tris / `foundry_crown` 3,367 tris |
| Scale | **48** → ~90u footprint / ~59u tall. Widest of the three (T1 52u, T2 75u) so the T3 dominates; the crown's cannons reach a further 0.88u forward. |
| Yaw | 0.0 (+Z front, confirmed: crown zmax +0.881 vs zmin −0.561) |
| Turret pivot | **(0, 0, −0.105)** — see below |
| Muzzles | (±0.100, 1.008, 0.881) — the two bore centres on the forward face |
| Roughness | remapped p50 **0.945 → 0.517** |

## The pivot is real here (unlike the Sentry Spire)

The collar's z-centre reads **−0.105 consistently** across every dense slice (n=149, 74, 71, 42),
with x pinned at +0.0001. That is the **rear-balanced turret** the concept brief specifies — the
pivot sits behind the cannons so the long barrels counterweight. Contrast the Sentry Spire, whose
apparent +0.052 was slice noise and was reverted to zero.

This makes the Siege Foundry the first model to actually exercise the pivot path, including the
`_add_cluster_lights` pivot argument added after the Spire's detached-muzzle-light bug.

## No barrel surgery needed

Unlike the Spire, the twin siege cannons share **one housing block** rather than protruding as two
tubes — cross-sections hold a constant 0.24 width from z 0.20 to 0.92, with a bore dip at centre.
The two bores were measured as x clusters −0.120..−0.081 and 0.081..0.120 and registered as muzzle
points directly. `--barrel-z` was deliberately not used.

## ⚠ OPEN — no emission mask

**This export has no emissive map, and its diffuse cannot produce one.** Shipped with emission
OFF (`tune_masked_emission(..., null)`); the six-light cluster is currently the only cyan the
tower has, running slightly hotter than the Spire's to compensate.

Evidence the diffuse is unusable:

| | Siege Foundry | Sentry Spire (known-good) |
|---|---|---|
| b−r p50 | 0.035 | 0.039 |
| b−r p90 | 0.047 | 0.071 |
| **b−r p99** | **0.059** | **0.275** |
| frac > 0.085 | 0.34 % | 6.38 % |

The distribution is a **global blue cast**, not channels: 3.2M pixels sit in a 0.020–0.051 band and
then it falls off a cliff. There is no stable operating point — `--blue-dominance 0.055` yields
0.51 % coverage, 0.045 yields 8.78 %, a 17× jump across a 0.01 change. At 0.045 the "lit" set is
also *darker* than the rest (luminance 0.156 vs 0.280), i.e. it is selecting shadow, not emission.
Rendering the 0.070 mask confirms it: a dozen scattered fragments, no channel network.

Shipping that would repeat the `architect_garrison_keep_hifi` mistake (a colour-derived mask that
is verifiably noise).

### Ruled out: the Shaded export is NOT the emissive

`base_basic_shaded.glb` is the model's **lit albedo baked into an emissive slot** so it renders
fullbright — a full-colour atlas (mean luminance 0.315, only 5.5 % black). The Spire's
`texture_emissive.png` is a genuine emission map (mean luminance 0.009, **97.8 % black**).
Different artifacts. Structurally: Rodin wrote the Spire's emissive as a **4th loose map beside**
the PBR glb, while the Siege Foundry's PBR pack has only three. The emissive is a property of the
material GENERATION, not of an export checkbox.

Tested the shaded map as a mask source anyway. It behaves better than the diffuse — a gradual
0.20 → 0.93 → 2.14 → 2.82 % curve instead of the diffuse's 0.51 → 8.78 % cliff — and
`--blue-dominance 0.060` lands at **2.14 %, inside the target band**. But the content is scattered
wispy outlines across the whole atlas (faint bluish shading on panel edges), not the coherent bars
and lozenges the Spire's mask has. Numerically in-band, verifiably noise — the Garrison Keep trap.
**Do not ship it.**

### CLOSED (2026-07-28): no emissive is obtainable from Rodin for this model

Everything controllable was tried and ruled out, in this order:

| Hypothesis | Test | Result |
|---|---|---|
| Companion file simply not downloaded | listed the download folder | no emissive present |
| The "Shaded" checkbox produces it | analysed `base_basic_shaded.glb` | it is the LIT ALBEDO baked into an emissive slot (mean lum 0.315, 5.5 % black) vs a real emission map (0.009, 97.8 % black). Baked it anyway: 2.14 % coverage but scattered edge noise. |
| The material prompt was too weak | re-ran with an explicitly self-illuminated prompt | hot cores improved (max b−r 0.302 → **0.431**, p99.9 0.188 → 0.322) and the bake became stable, but p99 stayed **byte-identical at 0.0588**. Still no emissive map. |
| **The .glb format drops it; use OBJ** | downloaded the OBJ pack of the same run | **DISPROVEN.** OBJ pack ships 5 textures, no emissive. Diffuse md5 `78c92f43…` identical to the .glb run, so same generation, same atlas — the format is not the variable. |
| The concept art lacks cyan | measured the input crops | **DISPROVEN.** Siege Foundry crops carry **12.89 %** of pixels above b−r 0.10 vs the Spire's **6.80 %** — nearly double. The input is richer, not poorer. |

**Conclusion: `texture_emissive.png` is a lottery of Rodin's material generation.** The Spire won
it twice; the Siege Foundry lost it across two prompts and two formats with better input art.
Recorded in the universal rules of `design/docs/Rodin_Recipe_Sheets.md`.

**The salvage mask was also rejected.** Baking run 3's improved diffuse at `--blue-dominance 0.070`
gives 0.29 % coverage / 17 components with no noise speckles — genuine signal, unlike the Garrison
Keep's. But UV-clustering it onto the mesh lights only **46 of 19,856 triangles**, in asymmetric
one-off positions ((−0.704, 0.133, −0.467), (+0.214, 0.107, +0.624), (+0.309, 0.608, −0.308)).
A symmetric model's real emissive features appear in **mirrored pairs** — the Spire's did. These
are incidental hot texels, so shipping them would put four random glowing spots on the tower.
**Emission stays OFF; the six-light cluster carries the cyan.**

**Remaining path: author the channels as a second emissive material in Blender** — the same
conclusion `architect_garrison_keep_hifi` reached. Queued, not blocking.

### Material re-run prompt (2026-07-27) — superseded by the above, kept for reference

Material stage ONLY — geometry stays confirmed, so nothing in this document needs re-measuring.
De-light **ON**, PBR Temperature **5**.

> Pristine polished silver-white ceramic armor plates with near-mirror highlights and deep
> charcoal gunmetal recesses. Narrow channels are cut deep into the plates, and every channel is
> filled with a BRIGHT SELF-ILLUMINATED cyan-blue light — these channels are light sources, not
> painted lines: they glow far brighter than the surrounding armor and cast light onto the plate
> edges beside them. Dense thin glowing channels run up every stepped tier of the base. The two
> siege cannon bores on the front of the turret are the brightest points on the entire model:
> deep dark barrel throats with intensely glowing cyan-blue cores. The deployment gate at the
> front of the base is a deep recessed opening with a dark interior and a brilliant glowing
> cyan-blue rim. The fabrication vaults on each flank glow from within. Maximum contrast between
> the bright neutral armor and the saturated self-luminous cyan-blue light. No grime, no wear,
> no visible seams.

Load-bearing phrasings, and why:

- **"SELF-ILLUMINATED" / "light sources, not painted lines"** — the previous prompt described the
  channels as COLOUR, so Rodin painted them into the diffuse and authored no emissive channel.
- **"cast light onto the plate edges beside them"** — a consequence only a light can have.
- **"deep dark barrel throats with intensely glowing cores"** — pairs dark against bright at one
  feature, maximising blue-dominance headroom so the bake still has signal after De-light.
- **"the brightest points on the entire model"** — an explicit intensity ranking survives De-light
  better than an unranked description.

**If a second material pass still returns no emissive**, the failure is in the generation rather
than the prompt: author the channels as a second emissive material in Blender (the Garrison Keep
conclusion). Do not keep re-rolling.

**The fix is cheap and proven:** the Sentry Spire's V2 export **did** include a loose
`texture_emissive.png`, so Rodin will emit one for these towers. Re-run the Siege Foundry's
**material stage only** — geometry is already confirmed, so this costs no geometry re-roll — and
grab the emissive. Then bake with `tools/bake_emission_mask.py --from-emissive` and wire the mask
into `Tower.gd`'s `architects_t3` branch (currently passing `null` with a comment marking the spot).

## Playtest round 1 (2026-07-28) — three fixes

**Reported:** T3 reads unlit; the firing emission bends at the barrel tip because the barrel
stays horizontal while the round descends onto a close target.

**Measured** (probe, since removed) — depression needed to hit a target at y=16 from the T3's
48.4u muzzle: **22.0° at range 80**, 12.2° at 150, **7.2° at 256 (current max)**, 4.6° at 400.
So extending range only helps the far shots; enemies close to the tower are where the kink is
worst, and range is a balance lever for a cosmetic problem. Elevation fixes it at every range.

Also confirmed the lights were never broken: all six exist, visible, correct energies. The T3
simply had **1 of 5 surfaces with emission enabled vs the T1's 3 of 5** — no luminous surface
for the eye to catch, so the omnis alone vanish under the warm key light.

1. **Barrel elevation** (`Tower._aim_pitch_to` + `_update_aim`). Node3D's default YXZ euler
   order means assigning `rotation.x` and `.y` together composes as yaw-then-pitch in the
   turret's frame — a ring + trunnion, not a tumbled basis. Clamped −12°..+42°. Applies to
   every authored crown (T1/T2/T3); procedural towers stay flat, since tilting a box barrel on
   an +X axis reads as broken.
2. **Ballistic lob for the T3** (`VfxBolt` `arc` parameter + `launch_tangent()`). The shell
   rides `lerp(from,to,t) + UP·arc·4t(1−t)` and noses along its own tangent. The barrel elevates
   onto the **launch tangent**, not the chord, so the round leaves the bore collinear and *then*
   arcs — which is the whole point. `_arc_lob = 0.22` of range; lobbed rounds use the ROCKET
   body + trail rather than the flat tracer.
3. **Procedural emissive inserts** (`add_architect_siege_foundry_inserts`). Same remedy as the
   FOB's gate: additive glow discs seated in the two measured cannon bores (turret-parented, so
   they sweep) and the deployment gate. Gives the T3 real cyan cores without a mask.

Boot log empty after all three.

## Playtest round 2 (2026-07-28) — crown decoupling + trajectory rework

**Reported:** the crown lifts off its collar after firing; the whole crown pitches instead of the
barrels; the shell arcs high independently of the barrel.

**Both crown faults were one root cause.** Elevation was applied to `_turret`, which carries the
entire crown, and recoil (`_turret.position = _turret_origin − fwd × 5 × recoil`) took `fwd` from
the now-pitched barrel — so `fwd` had a vertical component and firing physically lifted the crown
out of its socket. Flat barrels had hidden it, since `fwd` used to be horizontal.

**Fix — third mesh split at the trunnion.** `tools/split_tower_glb.py --trunnion-z 0.10`, measured
where the barrels step out of the housing (width 0.41 → 0.24, height 0.26 → 0.16). Yields
`foundry_crown` 1,792 tris (housing, yaw only, stays seated) and `foundry_barrels` 1,575 tris
(pitch + recoil, sliding back INTO the housing). `TOWER_MODEL_TRUNNION` = (0, 1.006, 0.100).
Models with no barrel group keep the fused behaviour but recoil now runs along the **horizontal**
barrel line only, so a fused crown can't lift either.

**The trajectory detachment was a clamp bug, not an arc bug.** The fixed-apex model demanded a
**+37°** launch at max range while `AIM_PITCH_MIN` clamped the barrel to **12°** — a 25° divergence
between the bore and the round. Any trajectory model must be *self-consistent*: the barrel angle
has to BE the launch angle.

**Replaced with a true ballistic solve** (option A of five compared with the user). Muzzle speed
700, gravity 1400 (`TOWER_BALLISTICS`), taking the LOW root of
`tan θ = (v² − √(v⁴ − g(g·d² + 2·rise·v²))) / (g·d)`. Gives **−15.7° at range 80** (barrel down,
near-direct), **flat at 150**, **+14.8° at 256**, and self-limits reach near 300. `VfxBolt` now
flies real gravity — horizontal at constant speed, vertical integrated — and derives its flight
time from the same numbers, so the visual arc and the firing solution cannot disagree. Clamps
widened to −55°/+50° so a real solution is never clipped again.

Boot log empty.

## Playtest round 3 (2026-07-28) — range + drag trajectory

Crown decoupling confirmed fixed. Two changes:

**Range 256 → 384. The "engages late" complaint was a genuine balance bug, not feel:** the
Architect tower ranges were T1 192, T2 224, **T2b 320**, T3 **256** — the terminal tower was
out-ranged by a tier-2 branch. 384 restores the tier order with clear headroom.

**Trajectory swapped from pure ballistic (A) to a DRAG model (E).** A plain parabola holds its
horizontal speed, so its descent can only mirror its climb — it can never read as "losing
velocity". Added horizontal drag:

    x(s) = vx0·(1 − e^(−k·s)) / k        y(s) = vy0·s − ½·g·s²

Both invert in closed form, so the flight time and vertical launch speed are solved directly —
no numerical search. `TOWER_BALLISTICS` is now `Vector3(vx0, k, g)` = **(900, 2.0, 600)**,
reaching `vx0/k` = 450 asymptotically. Behaviour across range:

| Range | Launch | Flight | Impact angle | Forward speed |
|---|---|---|---|---|
| 100 | −13.7° | 0.13 s | −22.9° | 900 → 700 |
| 200 | −1.4° | 0.29 s | −21.6° | 900 → 500 |
| 300 | +6.7° | 0.55 s | −36.7° | 900 → 300 |
| 360 | +12.6° | 0.80 s | −57.4° | 900 → 180 |

The shell leaves flat and fast, sheds 80 % of its forward speed, and tips into a −57° terminal
plunge. `_shot_solution` caches the solve that set the barrel elevation and hands the same
numbers to `VfxBolt`, so the visual trajectory and the firing solution structurally cannot
diverge — the failure mode of the first two attempts.

**Tuning knobs:** raise `k` for a harder late plunge and shorter reach; raise `g` for more
elevation and a rounder arc; `vx0/k` is the hard maximum range and must stay above the tower's
`range` or shots at the edge fall short.

Boot log empty.

## Playtest round 4 (2026-07-28) — T3 unlit, T2 splotchy

**T3 unlit — the inserts existed but were being depth-killed.** They sat 0.003 model units proud
of the surface they occupy (bores 0.884 vs a barrel tip of 0.881; gate 0.674 vs a face at 0.671)
= about **0.14 game units**, inside z-fighting range. Moved out to a measured **+1.3** (bores) and
**+2.0** (gate) game units of clearance, and enlarged (bore radius 0.052 → 0.075, gate 0.085 →
0.090 but narrowed to the centreline). ⚠ The gate cannot simply be pushed forward: the base
**flares at its lowest step**, so a wide disc there is swallowed by geometry either side of the
doorway while a centreline one sits in the recess. Clearance must be measured across the disc's
OWN footprint, not the model's global front.

**T2 splotchy — component count, not blur.** All three shipped masks are already 100 % full-value,
so this was not the old blur defect. The tell was fragmentation: **Sentry Spire 81 components / 2
tiny, Plasma Bastion 476 / 121 tiny.** The Spire's mask is baked from an AUTHORED emissive
(coherent architecture); the Bastion's is inferred from colour, and its channels are dark navy
insets that return as short disconnected fragments. Re-baked at `min_area 140, epsilon 2.5` →
**122 components, zero speckles, 1.59 % coverage** (still in band). Preset recorded.

⚠ **The Bastion's real fix is the same as the Spire's: an emissive map.** Its design folder has
only a `.glb` and three textures — no `texture_emissive.png` — so it has never had one. Pulling
the **OBJ pack** of its run (per the universal rule in `Rodin_Recipe_Sheets.md`) would let it be
baked with `--from-emissive` and reach the Spire's cleanliness. Tuning `min_area` is mitigation.

## Playtest checklist

- T2 → T3 upgrade rebuilds cleanly (GLB → GLB is a first; T1/T2 were GLB → GLB only via T1→T2)
- Crown tracks targets and **spins in place** — the −0.105 pivot is unverified in play
- Both bores muzzle-flash and tracers leave the real bore positions
- T3 reads as the biggest tower beside a T1 spire and T2 bastion
- Cyan is currently light-only — expect it to look under-lit until the emissive lands
