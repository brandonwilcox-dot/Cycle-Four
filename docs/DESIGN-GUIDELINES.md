# Cycle Four - Design Guidelines

> Canonical implementation-facing art direction for the Godot build.
> Read this file before importing, replacing, or materially restyling a visual asset.
> World truth and faction identity defer to `docs/codex/`; mechanical rules defer
> to `docs/core/`. This file governs how those designs are presented in-engine.

---

## Permanent Asset-Import Rule

**A new asset is not finished when its mesh loads. It is finished when its silhouette,
materials, emissive language, local light spill, scale, and tactical-distance readability
faithfully reproduce the approved concept inside the shared world-lighting stack.**

Every imported structure, commander, unit, prop, and VFX-bearing model must complete the
recipe below. Never solve a dim asset with a structure-wide floodlight, and never solve a
masked emission texture with additive emission across the whole material.

## The Import and Presentation Recipe

### 1. Preserve the authored object

- Keep the approved concept/reference beside the design source and record which image/model
  is authoritative.
- Preserve source albedo, normal, and metal/roughness maps. Tuning may neutralize a cast or
  improve response, but must not flatten surface detail into faction-colored plastic.
- Ground-align, center, orient, and scale the mesh against gameplay peers. Confirm it in the
  tactical camera, not only in an isolated viewer.
- Rigged assets keep their skeleton, animation names, per-part materials, and attachment nodes.

### 2. Build selective emission

- Use the authored emissive texture when one exists. Otherwise derive a separate grayscale
  mask only from concept-approved seams, apertures, portals, cores, lenses, and edges.
- Black in the mask means no emission. Never use albedo brightness as body-wide emission.
- Masks must survive mipmapping at RTS distance: preserve bright cores, a compact shoulder,
  and a restrained halo without creating large soft fields over armor.
- Import emission masks with mipmaps and 3D texture compression enabled.
- Godot materials must use `BaseMaterial3D.EMISSION_OP_MULTIPLY`. `EMISSION_OP_ADD` is
  forbidden for masked asset emission because it can add the emission color to black regions
  and make the entire model bright.
- Architect energy uses the shared cyan family. Start large structures near 2.4 emission
  energy and small/mobile assets near 3.0, then tune against the shared HDR glow threshold.
  Concentrated cores may be brighter than seams.

#### 2a. Baking a mask — use `tools/bake_emission_mask.py` (canonical since 2026-07-26)

Do NOT hand-roll a "find bright cyan, dilate, blur" mask. That recipe was replaced after it
shipped three visible defects (splotchy noise dots, a solid glowing slab where the FOB's
front gate should be a recessed opening, and soft mush — 82% of the FOB's lit mask pixels
were mid-tone). The script's shape-aware pass fixes all three:

- Threshold on **blue-dominance (b − r) gated by saturation**, never on brightness/hue.
  De-light leaves some channels as dark navy insets that a hue test cannot see.
- **No blur, no dilate.** Crisp edges are the point; mip-safety comes from full-value cores.
- Classify each connected component by **shape**: noise is dropped by area; a component
  fatter than ~9px half-width is a filled PANEL and becomes a glowing RIM (an opening reads
  as a lit outline, not a slab); everything thinner is a real channel and stays solid.
- Facet every outline with `approxPolyDP` so organic wobble becomes straight segments and
  hard corners — the "solid angles" the Architect language calls for.

Target 1.5–2.5% final coverage. The blue-dominance cut is **per model** (De-light drains the
cyan by different amounts per generation) — add each new structure to the script's `PRESETS`
table once tuned. Preserve the existing `.import` file when re-baking an existing mask so the
UID is stable; only write a fresh one for a brand-new mask.

**Known limit:** if a Rodin export comes back fully achromatic (max b − r below ~0.15), the
cyan is gone and NO image-processing recipe can recover it — a black-hat recess pass just
returns surface cracks. Re-export with De-light off, or author the channels as a second
emissive material in Blender. Shipping a colour-derived mask for such a model produces pure
noise.

**The De-light OFF re-export is the fix, and it is cheap** (proven on
`architect_garrison_keep_hifi`, 2026-08-02). Re-generating the same Rodin job with De-light
disabled ships a real `texture_emissive.png` and restores the cyan (p99 0.051 → 0.624). The
mesh and UVs came back **byte-identical** between the ON and OFF jobs — `base.obj` md5 matched
and the GLB POSITION/TEXCOORD\_0 accessors hashed the same — so De-light is purely a texture
post-process. Take the albedo/MR/normal from the **De-lit** export and the emissive from the
**OFF** export; they drop onto the same UVs.

**But an authored emissive is not automatically a good mask.** Rodin paints much of it onto
FLAT PLATING rather than into channels. On the Keep, 31 components fatter than 9px half-width
carried **71% of the lit area** and read as splotches on the armour. Two consequences:

- `--from-emissive` disables PANEL→RIM by default. For a Rodin emissive that default is wrong —
  re-enable the fatness cut and DROP the fat components rather than rimming them, or you get
  glowing outlines sitting on plating.
- **Cavity/AO gating does not work as a filter.** Tested at 0.02/0.05/0.12 and global: mean AO
  under the lit texels was **0.948 vs 0.605** elsewhere, i.e. the glow sits on the most EXPOSED
  surfaces. The channels are painted, not modelled, so there is no geometric signal to gate on.
  Do not spend time on this again unless the channels are authored as real recesses.

Where the channels matter, hand-authoring beats derivation. The Keep's shipped mask was painted
in Blender Texture Paint over a fat-dropped base, then hardened through the script's
`--from-emissive` path: **2.20% coverage, 0% mid-tone, 77 components at a 795px median run**,
versus 232 components at 76px for the purely algorithmic attempt.

### 3. Add physical-looking local spill

- Emissive pixels provide visible glow; compact `OmniLight3D` sources provide dependable
  illumination on adjacent armor and ground.
- Place each light just outside its emitting surface along the outward normal. A light on or
  inside a mesh often reaches the exterior from behind the surface normal and appears inert.
- Use multiple feature-scale lights at portals, cores, apertures, fins, and weapon emitters.
  Keep them shadowless unless a hero shot specifically requires shadows; the world key owns
  primary shadows.
- Store positions with the asset recipe: normalized coordinates for static models and
  rig/body-local coordinates for animated characters. Scale range to the emitting feature.
- Broad per-object fill lights are forbidden. They flatten albedo and make world exposure
  depend on whether that object exists.

### 4. Keep world lighting centralized

- `BattleAtmosphere.gd` owns key, fill, ambient, glow, tonemapping, fog, SSIL, and SDFGI.
- Imported assets add only localized motivated lights. They must not compensate for world
  exposure, biome balance, camera exposure, or missing global fill.
- Tune the world across bright and dark armor, vegetation, terrain, water, units, structures,
  selection rings, particles, and UI-adjacent effects.
- Expensive features require a quality/performance gate. SDFGI is the first world-lighting
  feature to reduce or disable when late-wave frame time exceeds budget. Selective emission
  and compact direct lights must remain readable without it.

### 5. Preserve instance safety and gameplay states

- Duplicate imported materials per instance before changing emission or damage-flash values.
  Never mutate a shared GLB material resource at runtime.
- Construction, damage flash, charge, scan, stealth, cosmetics, and faction tint multiply or
  modulate the approved base emission; they never replace its mask.
- Animated emitters follow the narrowest stable parent: bone or mesh when practical, otherwise
  the character body in local space.
- Apply the same rule to completed, constructing, restored, preview, and spawned instances.

### 6. Validate before declaring an import complete

1. Compare the approved concept beside the in-game asset.
2. Inspect close, tactical, and RTS camera distances.
3. Inspect both lit and shadow-facing sides.
4. With emission disabled, albedo and PBR surfaces must still read correctly.
5. With emission enabled, only approved features may glow.
6. Local spill must reach nearby surfaces without whitening the whole object.
7. The asset must remain readable with SDFGI disabled.
8. Spawning or despawning the asset must not change unrelated world exposure.
9. Built, construction, damage, and animation states must retain the material rule.
10. Godot import and a normal project boot must complete without new errors.

## Shared Architect Lighting Language

- Armor: neutral ivory ceramic with readable roughness, recess contrast, and metal accents.
- Energy: saturated cyan-blue, brightest at portals, reactors, and weapon cores; thinner on seams.
- Spill: local cyan edge wash on nearby armor plus a compact pool on the ground.
- Hierarchy: portal/reactor core > major aperture > structural seam > decorative pinlight.
- Consistency: FOB, garrisons, towers, commander, and future Architect assets share the same
  color family, multiply-gated masks, mip-safe cores, and localized-light method.

## Known Failure Modes

| Symptom | Cause | Required correction |
|---|---|---|
| Entire model becomes white/bright | Additive emission bypasses black mask pixels | Use multiply-gated emission |
| Cyan exists close-up but vanishes at gameplay distance | Thin/dim mask averages away in lower mips | Add bright cores/compact shoulders and retune energy |
| Emitter glows but casts no nearby light | Light is inside/on the surface or GI is unavailable | Offset a compact direct light outward |
| Scene brightness changes when a structure appears | Asset carries a broad fill light | Remove it and correct central world exposure |
| Armor loses texture/color | Emission or tint is body-wide | Restore PBR maps and use a selective mask |
| Every instance changes together | Shared imported material was mutated | Duplicate per instance before modulation |

## Current Implementation Anchors

- World stack: `src/core/BattleAtmosphere.gd`
- Full system review: `docs/planning/world-lighting-review-2026-07-22.md`
- Shared authored-asset emission and lights: `src/vfx/StructureEmissionLighting.gd`
- Architect FOB: `src/entities/Base.gd`
- Architect garrison: `src/entities/Building.gd`
- Commander authored model: `src/vfx/CommanderBodyRig.gd`
- Model registry and transforms: `src/core/AssetLoader.gd`

Last updated: 2026-07-22.