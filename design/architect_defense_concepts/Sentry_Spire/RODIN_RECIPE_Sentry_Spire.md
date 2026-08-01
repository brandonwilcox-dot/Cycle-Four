# Rodin Recipe — Architect **Sentry Spire** (T1 tower, `architects_t1.tres`)

Sequential checklist in Rodin UI order. Companion to `design/docs/Rodin_Recipe_Sheets.md`
(Sheet 3 — Buildings/Towers) and `docs/DESIGN-GUIDELINES.md` §2 / §2a.
**Steps marked ⬆ CHANGE differ from Sheet 3.** Rationale for all of them is in the appendix.

Concept role (README): light nearest-threat auto-rifle tower + Drone source. Tall economical
silhouette, sealed drone bay, compact twin-barrel crown on a broad rotation collar.

> ## FIX 2026-07-27 — detached muzzle lights (playtest report: "firing angles are off").
> The crown, aim math and muzzle registration were all correct. The fault was that the turret
> LIGHT cluster was placed from raw normalized coords while the crown mesh and muzzles both
> carried a turret-pivot correction — leaving two cyan omnis **4.65u in front of the barrels**,
> sweeping with the turret as detached glows. Two changes: `_add_cluster_lights` now takes the
> pivot, and the Sentry Spire's pivot is set to **ZERO** because the +0.052 Z it was given was a
> measurement artifact (a bbox over a sparse collar band tracks its extremes, not its axis —
> per-slice z-centers oscillate -0.042..+0.064 while x holds at +0.0011; the densest slice
> reads +0.002). Verified by probe: muzzle-to-light gap is now exactly the intended 3.00
> outward offset, and the crown front sits dead centre between the two muzzles at every yaw.
> **Measure a DENSE slice when deriving a pivot.**
>
> ## IMPORTED 2026-07-27 — awaiting hand playtest.
> Shipped as `assets/models/buildings/architect_sentry_spire_hifi.glb` (18,746 tris) +
> `..._emission_mask.png` (2.12 % coverage, 100 % full-value). Editor-imported, Battle3D boot
> log **empty**. Blender-equivalent work was done in Python: `tools/split_tower_glb.py`
> (crown split + twin-barrel reconstruction + roughness remap). Not yet verified on screen —
> that is the playtest. Exes NOT re-exported.
>
> ## Status — **V2 is CANONICAL. No further Rodin runs planned.**
> `V2/base_basic_pbr.glb` — .glb ✅, 17,790 tris ✅, collar intact ✅, emissive present ✅.
> Stage 5 is measured from **V2**. Two things are finished in Blender rather than in Rodin:
> **(1)** the twin auto-rifle barrels fused into one central barrel at Quad 8000 — split them
> (step 37); **(2)** roughness came back at p50 0.941 across two runs — remap on import
> (step 41). Both are decided; do not re-roll for either. Full history in Stage 7.

---

## STAGE 0 — Input prep

1. Use the five existing `508×508` crops in this folder: `front`, `back`, `left`, `right`, `top`.
   **Never the sheet.**
2. Verify EACH crop individually — no neighbour geometry riding in the gutter.
3. Upload **front + back + left + right**. Multi-image mode = **concat / "multi-view of one
   object"**. Hold `top` back unless the crown reads wrong.

---

## STAGE 1 — Geometry

4. Model: **Gen-2.5** | Quality: **Medium**
5. T/A Pose: **OFF**
6. Mode: **Faithful**
7. Symmetry: **Symmetric, weight High**
8. Style tags: **edges + game-ready**
9. Bounding box: **empty** | 10. Voxel: **empty** | 11. Point cloud: **empty**
12. Seed: **−1** — ⚠ **record the resolved seed.** Neither run recorded it, which is why V1's
    measurements could not be carried into V2 and everything had to be re-measured.
13. Detail: **+2** ⬆ **CHANGE** (Sheet 3 says +1)
14. Cfg: **11** ⬆ **CHANGE** (Sheet 3 says 10)
15. Step: **50** (default)
16. Geometry prompt — **OPTIONAL insurance line**, not required: ⬇ **DOWNGRADED**

    > The weapon crown sits on a narrow, deeply undercut rotation collar clearly separated
    > from the spire shaft.

    Neither run used this line and **both produced an unmistakable collar** (V1 maxR 0.202,
    V2 0.236, against 0.30–0.37 below and 0.58 above). The concept art's collar carries it
    alone. Keep as cheap insurance if re-rolling anyway; never re-run a good body to add it.

17. **Negative prompt** — universal set **plus three additions**: ⬆ **CHANGE**

    ```
    multiple objects, duplicate figures, floating parts, disconnected pieces, base, pedestal,
    stand, ground plane, text, labels, watermark, UI panels, blurry, low quality,
    flat painted panel, glowing decal, smooth featureless wall
    ```

18. Generate → inspect from several angles. Check the collar reads as an undercut waist, the
    buttress channels read as **cut recesses**, and — learned the hard way — **the twin barrels
    are two separate barrels**, not one fused block (step 37).
19. Redo ONLY if the main body is wrong. → **Confirm geometry.**

---

## STAGE 2 — Material (unlocks after geometry confirm)

20. Material prompt — use **this**, not the generic Architect block: ⬆ **CHANGE**

    > Pristine polished silver-white ceramic armor plates with near-mirror highlights and
    > charcoal dark-gunmetal recesses; deeply inset narrow channels cut into the plates, each
    > channel filled with a bright saturated cyan-blue emissive light, strongly brighter than
    > the surrounding armor; the drone aperture at the front of the base is a deep recessed
    > opening with a dark interior and a bright cyan-blue glowing rim; bright emissive
    > cyan-blue cores in the crown sensor and both weapon muzzles; minimal seams, no grime,
    > no wear.

21. De-light: **ON**
22. PBR Temperature: **5** ⬆ **CHANGE** (Sheet 3 says 7) — *but expect it not to be enough.*

    Measured across both runs: roughness p50 **0.973 → 0.941**, glossy fraction 0.68 % → 1.11 %.
    Essentially unmoved. The Plasma Bastion sits at 0.950 too. **Three Architect structures now
    show the same chalk surface, so this is a Rodin characteristic, not a bad roll.** Set 5 and
    move on — the fix is the import remap in step 41, not another material pass.

23. 8K/HD add-on: **skip**
24. → **Confirm material.**

---

## STAGE 3 — Export (unlocks after material confirm)

25. Geometry: **Quad 8000**

    > ⚠ V1 was set to 18000 → 37,714 tris, Bastion-class on a T1. V2 at 8000 → **17,790 tris** ✅.
    > Budget matters here more than on any other structure: the Sentry Spire caps at **8**
    > (+2 per enemy base destroyed), so V1 would have been ~300k tris of towers alone.
    > **Known cost of 8000:** it is also what fused the twin barrels (step 37).

26. Baked normal: **ON**
27. Pack: **Base Model only**
28. Material checkboxes: PBR **checked** | Shaded **unchecked** | **2K**
29. Format: **.glb**

    > ⚠ V1 exported **OBJ** — no `.mtl`, no `usemtl`, no scene graph, no node names, so nothing
    > for `_find_child_named(model, "crown")` to find and no PackedScene for
    > `AssetLoader.load_tower_model()`. V2 is correct .glb ✅.

30. Download → `design/architect_defense_concepts/Sentry_Spire/V<n>/`

---

## STAGE 4 — Acceptance gate — run before you close the Rodin tab

### 31. Emissive first — does the export include `texture_emissive.png`?

**YES** (both runs did): the De-light risk is moot. An authored emissive is a better region
source than inferring channels from colour — authored intent instead of a guess. Go to step 32.

**NO:** go to step 34.

> ⚠ **The emissive ships as a LOOSE PNG beside the .glb — it is NOT bound into the GLB
> material.** V2's material declares `emissiveFactor: null`, `emissiveTexture: null`, and embeds
> only normal / diffuse / metallic-roughness. This is the same situation as the Plasma Bastion
> and is handled: `tune_masked_emission` was widened on 2026-07-25 so an explicit mask enables
> emission on a non-emissive import (step 40). Just don't expect the glow to appear on import.

### 32. Emissive quality check

```bash
python3 -c "
from PIL import Image; import numpy as np
Image.MAX_IMAGE_PIXELS=None
e=np.asarray(Image.open('texture_emissive.png').convert('RGB'),dtype=np.float32)/255
lum=e.max(axis=2); lit=lum[lum>0.05]
print('coverage %.2f%%'%(100*lit.size/lum.size))
print('of lit: hot(>0.75) %.1f%%  mid(0.15-0.75) %.1f%%'%(100*(lit>0.75).mean(),100*((lit>=0.15)&(lit<=0.75)).mean()))
"
```

| Result | Verdict |
|---|---|
| coverage 1.5–2.5 % **and** mid-tone < 25 % | **PASS** — use as-is |
| coverage in band, mid-tone > 25 % | **HARDEN** — regions right, values soft. Step 38. |
| coverage far out of band | Investigate before baking |

**V2: coverage 2.18 % ✅ (in band), mid-tone 69.8 %, hot cores 12.3 % → HARDEN.**
(V1 was 1.92 % / 72.4 % / 12.9 % — the two runs are effectively identical here, so this is how
Rodin authors emissives, not a bad roll.) For reference the FOB sat at 82 % mid-tone before its
2026-07-26 rebuild; this is the *"cyan close-up, gone at gameplay distance"* row in the
guidelines failure table — thin dim regions average away in the lower mips.

### 33. Roughness check

```bash
python3 -c "
from PIL import Image; import numpy as np
Image.MAX_IMAGE_PIXELS=None
r=np.asarray(Image.open('texture_roughness.png').convert('L'),dtype=np.float32)/255
print('p50 %.3f  p90 %.3f  glossy(<0.35) %.2f%%'%(np.percentile(r,50),np.percentile(r,90),100*(r<0.35).mean()))
"
```

Want p50 ≤ 0.75. **V2: p50 0.941, p90 0.965, glossy 1.11 % → fail → remap on import (step 41).**
On a GLB, roughness is the **G channel** of the packed metallic-roughness texture.

### 34. Diffuse gate — **only if there is no authored emissive**

```bash
python3 -c "
from PIL import Image; import numpy as np
Image.MAX_IMAGE_PIXELS=None
a=np.asarray(Image.open('texture_diffuse.png').convert('RGB'),dtype=np.float32)/255
b=a[:,:,2]-a[:,:,0]
print('max %.3f  p99 %.3f  frac>0.085 %.2f%%'%(b.max(),np.percentile(b,99),100*(b>0.085).mean()))
"
```

| Result | Verdict |
|---|---|
| p99 ≥ 0.12 **and** frac 2–8 % | **PASS** — colour-bake per §2a |
| p99 0.05–0.12 | Marginal — `--blue-dominance 0.070`, inspect |
| p99 < 0.05, max < 0.15 | **FAIL — achromatic.** Step 35. Never ship a colour-derived mask (Garrison Keep state). |

V1 diffuse: max 0.714, p99 **0.275**, frac **6.38 %** → would have passed comfortably. Both paths
are available on this model; the emissive is simply better.

### 35. On diffuse FAIL only

Re-run material on the **same confirmed geometry** with **De-light OFF**. Ship the De-light-**ON**
albedo/normal/MR; bake from the De-light-**OFF** diffuse. Two textures, one mesh, zero re-rolls.

---

## STAGE 5 — Claude post-pipeline (Godot) — **measured from V2**

> ⚠ V1 and V2 are **different meshes** (10,065 vs 18,863 verts; bounds differ). Because no seed
> was recorded, nothing transferred. Everything below is re-measured from **V2** and is only
> valid for V2.

### 36. Reference measurements

| Quantity | V2 value |
|---|---|
| Verts / tris | 10,065 / **17,790** |
| Bounds (W × H × D) | **1.6121 × 1.8939 × 1.3858** |
| Ground alignment | min y = **0.000** ✅ |
| **Seam (collar waist)** | **y = 1.52** — maxR 0.236 vs 0.30–0.37 below / 0.582 above |
| Split at seam | crown **3,614** tris / base **14,176** tris |
| Crown y-range | 1.514 → 1.894, maxR 0.585 |
| Collar x-center | **+0.0011** ✅ spins true |
| **Collar z-center** | **+0.0519** ⚠ |
| Front facing | **+Z** (crown zmax +0.584 vs zmin −0.273) → `TOWER_MODEL_YAW = 0.0` ✅ |

⚠ **Apply a −0.052 Z correction when reparenting the crown**, or it orbits off-axis
(~1.7 game units at scale 32 — small, free to fix, annoying to diagnose later).

### 37. **Split the fused barrel into twin barrels** ⬆ **NEW — decided 2026-07-27**

Quad 8000 fused the concept's twin auto-rifles into **one central barrel**. Measured:

| | V1 (Quad 18000) | V2 (Quad 8000) |
|---|---|---|
| Muzzle-region X distribution | two clusters, **clean gap x −0.175 → +0.175** | **one cluster x −0.075 → +0.075** |
| Barrel centers | **x ≈ ±0.235** ✅ concept-correct | x ≈ 0 (single) ❌ |
| Muzzle z / y | 0.513 / 1.700 | 0.584 / 1.657–1.806 |

**Decision: split V2's barrel in Blender rather than re-roll.** Cut the single barrel assembly
and separate the halves to **x ≈ ±0.235**, matching V1 and the concept sheet. The crown housing
reaches maxR 0.585, so ±0.235 sits comfortably inside it. Keep the muzzle face at **z 0.584**.

Resulting muzzle points to author (model space):

```
left   Vector3(-0.235, 1.723, 0.584)
right  Vector3( 0.235, 1.723, 0.584)
```

Do this in the same Blender pass as the crown split — one trip, not two.

### 38. Build the mask by HARDENING the authored emissive — **not** by colour-baking ⬆ **CHANGE**

Do **not** run the standard `bake_emission_mask.py` colour path here. Its classifier flags **28
components as PANEL** (half-width > 9 px) holding **78 % of the lit area** — but most are
authored lozenge emitter inserts *meant* to read as solid glowing capsules. Blanket
rim-conversion would gut the design.

Wanted instead is an emissive-input mode that skips blue-dominance and only hardens:

- drop components under `MIN_AREA` — V2 has **18** noise specks under 14 px
- drive core values to full so the mask survives mipmapping; target mid-tone share ≈ 0 %
  (the FOB went 82 % → 0 %)
- keep edges crisp; **no blur, no dilate**, per §2a
- rim **selectively** — the drone aperture if it came back as a fill, never the lozenges

Coverage target **1.5–2.5 %**; V2's 2.18 % is already in band, so hardening should preserve
coverage and only redistribute the value histogram.

### 39. Import settings

Godot first-imports a mask as `compress/mode=0, mipmaps=false, detect_3d=1`, violating the
guidelines. Hand-set **`mode=2` / `mipmaps=true` / `detect_3d/compress_to=0`** and re-import, or
pass `--write-import` to the bake script.

### 40. AssetLoader — five entries keyed on `res://resources/towers/architects_t1.tres`

```gdscript
FACTION_TOWER_MODELS    -> "res://assets/models/buildings/architect_sentry_spire_hifi.glb"
TOWER_MODEL_SCALE       -> 32.0        ## 51.6u footprint / 60.6u tall
TOWER_MODEL_YAW         -> 0.0         ## confirmed: front is +Z
TOWER_MODEL_HEIGHT_NORM -> 1.894
TOWER_MODEL_MUZZLES     -> [ Vector3(-0.235, 1.723, 0.584),
                             Vector3( 0.235, 1.723, 0.584) ]   ## post-split (step 37)
```

**Scale 32**, top of the original 28–32 estimate: the Bastion at 40 is 76u footprint / 58u tall,
so 32 gives the Sentry Spire a **narrower footprint and slightly greater height** — a spire beside
a squat heavy, tier read obvious. Confirm against the Commander (~73u) in the tactical camera.

Muzzle points are **model space**; after the crown split re-express them **turret-local**
(subtract the pivot) so `to_global` returns rotated emitter positions.

### 41. Material — emission **and** the roughness remap

```gdscript
tune_masked_emission(model, 3.0, MASK)   ## EMISSION_OP_MULTIPLY only; ADD is forbidden
```

⬆ **Also remap roughness on import.** Three Architect structures now arrive at p50 ≈ 0.94–0.97
with under ~1 % glossy surface — flat chalk, when the concept and the shared Architect lighting
language both call for near-mirror polished ceramic. A chalk surface additionally starves the
localized cyan spill in step 42: there is nothing for the light to catch.

Remap the packed MR texture's **G channel** into roughly a **0.18 → 0.55** range (preserving
relative variation, not flattening it) so plates read polished while recesses stay matte. Match
the response the Commander's authored model gets. Duplicate the material per instance before
modifying — never mutate a shared GLB material resource at runtime (§5).

### 42. Light cluster

New `ARCHITECT_SENTRY_SPIRE_*_LIGHTS` in `StructureEmissionLighting.gd`, split turret vs base so
muzzle lights sweep with the barrels:

```gdscript
## TURRET (parented to the rotating crown)
MuzzleLeft   pos (-0.235, 1.723, 0.584)  normal (0, 0.1, 1)  energy 2.40  range 34
MuzzleRight  pos ( 0.235, 1.723, 0.584)  normal (0, 0.1, 1)  energy 2.40  range 34
CrownSensor  normal (0, 1, 0)                                 energy 1.90  range 32

## BASE (static hull)
DroneAperture  normal (0, 0, 1)   energy 2.40   range 38
SpineUpper     normal (0, 0, 1)   energy 1.60   range 30
SpineLower     normal (0, 0, 1)   energy 1.60   range 30
```

Ranges pulled ~20 % in from the Bastion's 40–46 ⬆ — a 44-range light on a slender spire washes
the shaft flat (the defect open on `ARCHITECT_FOB_LIGHTS.PortalFront`, energy 3.20 / range 90).
Positions in **normalized model coords**, placed just **outside** the emitting surface along its
outward normal. Base positions to be measured on import; muzzles are measured above.

---

## STAGE 6 — Validation before declaring the import complete

43. Emissive passed step 32; roughness remapped to p50 ≤ 0.75 (step 41).
44. Mask coverage 1.5–2.5 %; **mid-tone share of lit pixels ≈ 0 %**.
45. Mask preview: discrete hard-edged bars along the buttresses, lozenge inserts intact. No
    speckles. No glowing slab over the drone bay.
46. **Twin barrels read as two barrels** at tactical distance (step 37).
47. Emission **off** → armor and PBR read correctly, plates look polished not chalky.
48. Emission **on** → only channels, aperture, crown sensor and muzzles glow.
49. In-engine: place T1 → Commander builds it → crown tracks a target through a full sweep →
    **both** muzzles flash and tracers leave the real emitter positions.
50. Tri budget: place the tower cap (8) and check late-wave frame time.
51. Boot log empty. Close / tactical / RTS distances checked. Lit **and** shadow-facing sides
    checked.
52. Re-export both exes (`.\tools\export.ps1`) — standing flag since 2026-07-25.

---

## STAGE 7 — Run log

| Run | Date | Seed | Format | Quad | Tris | Emissive | Diffuse p99 | Rough p50 | Barrels | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| V1 | 2026-07-27 | ⚠ unrecorded | ⚠ OBJ | ⚠ 18000 | 37,714 | ✅ 1.92 % | 0.275 ✅ | ⚠ 0.973 | ✅ twin ±0.235 | Superseded |
| **V2** | 2026-07-27 | ⚠ unrecorded | ✅ .glb | ✅ 8000 | **17,790** | ✅ 2.18 % | — | ⚠ 0.941 | ⚠ fused | **CANONICAL** — finish in Blender |

**V2 keepers:** seam y 1.52, scale 32, height norm 1.894, yaw 0, collar z-offset +0.0519,
muzzle z 0.584 / y 1.723. Valid for V2 only.

**Carried from V1:** barrel X separation **±0.235** (step 37) — V1's is the concept-correct
figure and the target for the Blender split.

Copy the accepted row into the seeds log in `design/docs/Rodin_Recipe_Sheets.md`.

---

## Appendix — why each ⬆ CHANGE exists

**Steps 13/14 (Detail +2, CFG 11).** On a squat form like the Plasma Bastion the silhouette
carries the read and +1/10 is right. Here the silhouette is a plain tapered spire — everything
that makes it an *Architect* tower is the channel network. Do not exceed +3 / 12; at Quad 8000
surface noise becomes speckle in the bake. Note Detail +2 did **not** save the twin barrels at
8000 — feature separation is a poly-budget problem, not a detail-slider problem.

**Step 16 (collar line — downgraded).** Originally specified as required. Two runs omitted it
and both produced a textbook waist, so the concept art alone suffices. Recorded because "we
thought this mattered and it didn't" is worth as much as the reverse.

**Step 17 (negative prompt additions).** Rodin paints an opening as a flat teal FILL, which bakes
as a solid glowing slab reading as a decal rather than a recess — that is the Architect FOB front
gate, still an open follow-up needing a Blender inset. Blocking it at the prompt is free.

**Step 20 (material prompt).** The generic Architect block in `Rodin_Recipe_Sheets.md` says
*"near-black armor plates"* — that is the **unit/commander** palette. Shipped Architect
**structures** and this concept sheet are polished silver-white with charcoal recesses.

**Step 22 + 41 (roughness).** Measured, not guessed. V1 p50 0.973 → V2 0.941 barely moved, and
the Bastion is 0.950. Three structures, same symptom: Rodin will not deliver near-mirror Architect
ceramic, so the remap moves to import and stops costing generation passes.

**Stage 4 restructure (emissive-first).** The original gate assumed no authored emissive and went
straight to blue-dominance on the diffuse. Both runs returned a real `texture_emissive.png`,
which is strictly better — authored intent instead of an inference. The diffuse gate survives as
fallback, and step 35's two-variant De-light trick remains the last resort for the Garrison-Keep
failure mode.

**Step 25 (Quad 8000).** Not style — budget. Highest-count structure the player builds;
37,714 tris × a cap of 8 is ~300k tris of towers alone. The barrel fusion is the accepted cost.

**Step 37 (split the barrel, don't re-roll).** Re-rolling trades a known-good mesh for an unknown
one with no seed to return to, and 12000 was not guaranteed to keep the barrels apart. Splitting
is deterministic, happens in the Blender pass the crown split already requires, and V1 supplies
the concept-correct target of ±0.235.

**Step 38 (harden, don't colour-bake).** The §2a script assumes it is *inferring* channels from
colour, so its PANEL→RIM rule defends against Rodin's painted-slab habit. Against an authored
emissive that assumption inverts: fat components are usually deliberate. Hardening keeps the
mip-safety benefit without overriding the artist.

**Steps 40/42 (scale and light ranges).** Both are "don't repeat a known defect": a T1 at the
Bastion's scale 40 loses the tier read, and Bastion-sized light ranges on a slender spire flatten
the shaft exactly the way `PortalFront` currently flattens the FOB's front face.
