# Rodin Recipe — Architect **Regional FOB** (player base, `AssetLoader.FACTION_BASE_MODELS`)

Sequential checklist in Rodin UI order. Companion to `design/docs/Rodin_Recipe_Sheets.md`
(Sheet 3 — Buildings), `design/architect_fob_concepts/README.md` (concept set + prompts), and
`docs/DESIGN-GUIDELINES.md` §2 / §2a.

**Steps marked ⬆ CHANGE differ from Sheet 3 / the README's original handoff block.**
Every change traces to a measured defect on the shipped run. Rationale is in the appendix.

---

> ## ⚠ WHY THIS DOCUMENT EXISTS — the shipped FOB failed on GEOMETRY, 2026-08-09
>
> `assets/models/buildings/architect_fob_hifi.glb` (generated 2026-07-21) was reviewed in
> Blender and rejected: **"melted wax… absolutely no detail."** Confirmed on import —
> 23,024 verts / 40,425 tris, one fused mass, no crisp architectural creases anywhere.
>
> This is the root cause of **three** downstream problems that were each treated as separate
> bugs and separately worked around:
>
> | Downstream symptom | Actually caused by |
> |---|---|
> | Emission mask was 82 % mid-tone mush (rebuilt 2026-07-26) | No real recessed channels to find — the "channels" are painted, not modelled |
> | Front gate baked as a solid glowing arch | The gate is a **flat teal panel in albedo**, not an inset opening |
> | `PortalFront` light (energy 3.20 / range 90) washes the front face flat | Nothing on that face has enough relief to catch a light |
>
> **Do not re-run the settings in `architect_fob_concepts/README.md`.** They are the settings
> that produced this. The README's handoff block is preserved as the historical record; this
> sheet supersedes it.
>
> ### ⚠ But the failure is NOT a poly-budget failure — measured 2026-08-09
>
> The obvious diagnosis was "not enough triangles." **That is wrong**, and it is worth writing
> down before someone spends a generation pass on it. Measured across every shipped Architect
> structure (face dihedral angles + tri density per unit surface area):
>
> | Model | Tris | flat < 2° | mid 5–20° | sharp > 45° | tris / area |
> |---|---|---|---|---|---|
> | **fob** (rejected) | **40,425** | **24.4 %** | 35.3 % | **7.4 %** | **3312** |
> | sentry_spire (accepted) | 18,746 | 22.0 % | 35.3 % | 8.6 % | 2153 |
> | plasma_bastion (accepted) | 18,536 | 19.0 % | 34.1 % | 10.8 % | 1398 |
> | siege_foundry (accepted) | 19,856 | 15.6 % | 35.3 % | 11.8 % | 1886 |
> | garrison_keep (Smart-Poly) | 10,271 | 46.4 % | 39.5 % | **0.0 %** | 609 |
>
> The rejected FOB is the **densest mesh in the set** (3312 tris/area, ~1.5× the Spire) and its
> crease distribution sits inside the accepted band. **No mesh statistic separates it from the
> assets we shipped and liked.** So a crease-percentage acceptance gate does not work, and
> raising Quad from 18000 will not fix this on its own.
>
> ### The actual failure: reconstruction fidelity at high feature density
>
> Put the input beside the output. `Default/rodin_in/front.png` is crisp and disciplined —
> dozens of distinct sub-masses: curtain wall segments, a gatehouse, corner bastions, ranked
> small towers, crenellations, panel insets, thin channels. The mesh Rodin returned is a lumpy
> mass with drippy spires. **Rodin did not run out of triangles; it failed to resolve the
> features and spent its triangles smoothly tessellating a blob.**
>
> Two levers follow, and they matter more than anything in Stage 3:
>
> 1. **The input crops are `508 × 508`.** The six-cell sheet is `1536 × 1024`, so ~512 px per
>    cell — the crops are native resolution, never downsampled. At 508 px a corner bastion is
>    ~30 px and a wall channel is 1–2 px wide. **There is not enough information in the input
>    for Rodin to reconstruct what the concept shows.** Every other Architect asset that came
>    back crisp is a *single simple mass* at the same resolution.
> 2. **The FOB may be too feature-dense for Rodin as one object, at any setting.** This is the
>    same class of limit as Sheet 1a's tentacle rule — where the answer was *body from Rodin,
>    appendages from Blender*. See Stage 1b.

---

## STAGE 0 — Input prep

1. **Choose which concept(s) to generate.** Four complete crop sets exist. Geometry is the
   cheap stage to explore and the expensive one to get wrong — generate more than one.

   | Variant | Form | Notes |
   |---|---|---|
   | **Default** | Curtain walls, gatehouse, bastion towers, recessed hangars, central Nexus spire | The shipped/failed one. Faction baseline; most legible as "a base" |
   | **Cathedral** | Long nave hall, soaring spire, paired transept bastions, swept buttresses | Strongest vertical read; most Seraphim |
   | **Citadel** | Low broad star-fort, three concentric rings, wedge glacis, squat keep | Densest hard edges — **most likely to survive Rodin's smoothing** |
   | **Arcology** | Fortress-city, stepped terraces, stacked bands, central Nexus core | Most surface complexity; also most to lose to fusion |

2. ⬆ **CHANGE — RE-RENDER THE VIEWS LARGER BEFORE UPLOADING. Highest-value step in this sheet.**

   The existing crops are **`508 × 508`**, native (the six-cell sheet is `1536 × 1024`). At that
   size a corner bastion is ~30 px and a wall channel is 1–2 px. Re-render each orthographic
   view as its **own full-resolution image at 1024² or 2048²** — one view per generation, not a
   six-cell sheet — using the variant's prompt from `README.md` plus:

   > Render this single view only, filling the frame, at maximum detail. Keep every panel
   > inset, wall channel, crenellation and tower edge sharply defined and individually
   > readable. Plain white background, zero perspective, no text.

   Upscaling the existing 508 px crops is **not** a substitute — it invents no detail and Rodin
   has nothing new to reconstruct from. Re-generate at size.

2a. ⬆ **CRITICAL — RENDER ALL VIEWS IN ONE GENERATION, THEN CROP.**
   *Added 2026-08-09 after the first re-render attempt failed exactly here.*

   Generating each view as an **independent** image is how you get five different buildings.
   Image models do not remember the object between calls; "the same fortress from the left"
   produces *a* fortress from the left. Consistency has to be structural, not requested:

   - **Best — one sheet, one call.** Render the five views as a single multi-cell sheet at the
     maximum resolution the tool allows, then crop the cells. All views come from one denoise,
     so tower counts, heights and gate design agree by construction. This is why the original
     `1536 × 1024` sheet was internally consistent despite being low-res. **Target ≥ 1024 px
     per cell** — a 3072 × 2048 sheet gives ~1024² cells.
   - **Second — chain image-to-image.** Render FRONT at full resolution first, then generate
     each remaining view **conditioned on that image**: *"the exact same structure rotated 90°
     to show its left side — identical tower count, identical total height, identical gate and
     spire design."* Verify each against the front before continuing.
   - **Never** render five views from the text prompt alone. Measured result below: 36 % height
     disagreement, worse than the 508 px set it replaced.

3. **Consistency gate — a real pass/fail, unlike the crease gate.** For true orthographic views
   of one object, silhouette **height must be identical** in front/back/left/right, front/back
   **widths** must match each other, and left/right widths must match each other.

   ```bash
   python3 -c "
   from PIL import Image; import numpy as np, glob
   Image.MAX_IMAGE_PIXELS=None
   hs={}
   for v in ['front','back','left','right']:
       a=np.asarray(Image.open(glob.glob('*_%s_*.png'%v)[0]).convert('RGB'),dtype=np.uint8)
       bg=(a>242).all(axis=2); ys,xs=np.where(~bg); hs[v]=(xs.max()-xs.min(), ys.max()-ys.min())
       print('%-6s w %4d  h %4d'%(v,)+()) if False else print('%-6s w %4d  h %4d'%(v,hs[v][0],hs[v][1]))
   H=[v[1] for v in hs.values()]
   print('height spread %.1f%% of mean  (PASS < 3%%)'%(100*(max(H)-min(H))/np.mean(H)))
   print('front/back width delta %.1f%%'%(100*abs(hs['front'][0]-hs['back'][0])/np.mean([hs['front'][0],hs['back'][0]])))
   print('left/right width delta %.1f%%'%(100*abs(hs['left'][0]-hs['right'][0])/np.mean([hs['left'][0],hs['right'][0]])))
   "
   ```

   | Height spread | Verdict |
   |---|---|
   | **< 3 %** | **PASS** — consistent framing; proceed |
   | 3–10 % | One view is usually the sole outlier. Check whether it is a **design** mismatch or only a **framing** one — open it beside the front. Framing-only: rescale it, or just **drop it**. Rodin does not need four views, and on a symmetric structure with Symmetry weight High, `back` is the least informative |
   | **> 10 %** | **FAIL — different objects.** Re-render as one sheet. Do not upload |

   ⚠ **Also verify the sheet was generated natively at size, not upscaled.** A large sheet that
   is a 2× upscale of a small one carries no extra information, and cell count divides whatever
   native resolution you actually got. Check before trusting a resolution number:

   ```bash
   python3 -c "
   from PIL import Image; import numpy as np
   Image.MAX_IMAGE_PIXELS=None
   big=Image.open('SHEET_BIG.png').convert('L'); nat=Image.open('SHEET_NATIVE.png').convert('L')
   up=nat.resize(big.size, Image.LANCZOS)
   a=np.asarray(big,np.float32); b=np.asarray(up,np.float32)
   print('mean|diff| %.3f   (< ~2 means BIG is just an upscale)'%np.abs(a-b).mean())
   "
   ```

4. **Camera must be elevation 0°, zero perspective.** If you can see the top surfaces of the
   walls, a receding entry ramp, or converging edges, it is a 3/4 perspective view, not an
   orthographic elevation. Rodin triangulates from these — a perspective view puts the geometry
   in the wrong place. `top` is the only view rendered looking down.
5. **No ground plinth.** A dark base slab under the fortress violates the universal negative
   prompt (`base, pedestal, stand, ground plane`), gets modelled as geometry, and breaks the
   `min y = 0` ground alignment Stage 5 requires. Crop it off or re-render without it.
6. Verify EACH view individually — no neighbouring geometry riding in the gutter.
7. Upload **front + back + left + right**. Multi-image mode = **concat / "multi-view of one
   object"**. Hold `top` back unless the spire or roof masses read wrong.

> **Fallback when a consistent set is hard to get: upload fewer views.** Rodin reconstructs
> better from **two agreeing views than five disagreeing ones** — disagreement is what it
> averages into a blob. Front + top (the top is orthographic and reliable) beats a full set
> that fails step 3.

---

## STAGE 1 — Geometry

5. Model: **Gen-2.5** | Quality: **High** — the FOB is the most-looked-at object in the game.
6. T/A Pose: **OFF**
7. Mode: **Faithful**
8. Symmetry: **Symmetric, weight High** (machine-precise fortress; full mirror is on-theme)
9. Style tags: **edges + game-ready**
10. Bounding box: **empty** | 11. Voxel: **empty** | 12. Point cloud: **empty**
13. Seed: **−1** — ⚠ **RECORD THE RESOLVED SEED IN STAGE 7.** No Architect structure has ever
    recorded one, which is why the Sentry Spire had to re-measure everything between V1 and V2.
14. Detail: **+3** ⬆ **CHANGE** (README used **+1**)
15. Cfg: **12** ⬆ **CHANGE** (README used **10**)
16. Step: **75** ⬆ **CHANGE** (README used 50) — ⚠ *the one lever here that is untested; see appendix*
17. **Geometry prompt — REQUIRED on this asset.** ⬆ **CHANGE** (Sheet 3 has none; the Spire
    made its optional). Not optional here: the flat gate is a twice-observed defect on this
    exact model.

    > The main gate is a deep recessed opening cut into the gatehouse mass, with visible
    > jamb thickness and a dark interior — not a flat panel on the wall face. Wall channels,
    > hangar mouths and vents are cut recesses with sharp square edges and visible depth.
    > Keep crisp architectural creases, flat faceted plate faces and hard corners between
    > masses; walls, bastions and spire read as separate stacked volumes.

18. **Negative prompt** — universal set **plus six additions** ⬆ **CHANGE** (the Spire added
    three; three more target the melt):

    ```
    multiple objects, duplicate figures, floating parts, disconnected pieces, base, pedestal,
    stand, ground plane, text, labels, watermark, UI panels, blurry, low quality,
    flat painted panel, glowing decal, smooth featureless wall,
    melted, rounded edges, soft blobby forms
    ```

19. Generate → inspect the preview from several angles. **Acceptance is a geometry judgement,
    not a texture judgement — the preview is shaded grey for a reason.** Check:
    - the gate is a **hole with depth**, not a panel
    - wall channels read as **cut grooves**, not painted lines
    - bastions, curtain wall and spire read as **separate stacked masses** with hard joins
    - edges are **creased**, not fillet-rounded everywhere
20. Redo if the main body is wrong. **On this asset, "mushy" IS the main body being wrong** —
    the usual "don't re-roll a good body over a small flaw" rule does not protect a soft mesh.
21. → **Confirm geometry.** Everything after this point is free to re-roll without losing the mesh.

---

## STAGE 1b — If a whole-fortress run is still soft: **generate it in parts** ⬆ **NEW**

Do not keep re-rolling the whole fortress. Sheet 1a already established the precedent for
Rodin's reconstruction limits — *body from Rodin, appendages from Blender* — when it could not
resolve the Mesh Commander's tentacles at any setting. A fortress with thirty sub-masses is the
same problem in a different shape.

Decompose the concept into **3–4 independent Rodin runs**, each a single simple mass at full
input resolution — the condition under which every crisp Architect asset was produced:

| Run | Content | Notes |
|---|---|---|
| A | Central Nexus spire + keep | The focal mass; give it the highest budget |
| B | One curtain-wall segment + gate section | Instanced/mirrored around the perimeter in Blender |
| C | One corner bastion tower | Instanced ×4 — this is what `FACTION_BASE_BASTIONS` already assumes |
| D | *(optional)* hangar / service-bay module | |

Assemble in Blender, weld, and export as one GLB. **The symmetry the concept already has makes
this cheap** — the four bastions are identical and the curtain wall repeats, so three good runs
reconstruct the whole fortress at roughly 3× the per-feature resolution of one whole-object run.

Cost: one Blender assembly pass. It also lands, for free, the two things currently blocked on
Blender anyway — the **recessed gate inset** and clean separable masses for lighting.

⚠ This route changes the model's origin and bounds, so all of Stage 5's measurements are taken
after assembly, not from any individual run.

---

## STAGE 2 — Material — **run this stage TWICE** ⬆ **CHANGE**

The Garrison Keep proved (2026-08-02) that De-light is a pure texture post-process: the ON and
OFF jobs returned **byte-identical mesh and UVs** (`base.obj` md5 matched; GLB POSITION and
TEXCOORD_0 accessors hashed the same). So both variants drop onto the same mesh, and running
both costs one extra material pass and zero geometry risk.

22. Material prompt — use **this**, not the generic Architect block in the recipe sheets
    (that block says *"near-black armor"*, which is the **unit/commander** palette; Architect
    **structures** are polished silver-white):

    > Pristine polished silver-white ceramic armour plates with near-mirror highlights and
    > charcoal dark-gunmetal recesses; deeply inset narrow channels cut into the plates, each
    > channel filled with a bright saturated cyan-blue emissive light, strongly brighter than
    > the surrounding armour; the main gate is a deep recessed opening with a dark interior
    > and a bright cyan-blue glowing rim — never a flat filled panel; bright emissive cyan-blue
    > cores in the central Nexus spire, the bastion crowns and the hangar mouths; minimal
    > seams, no grime, no wear.

23. **Pass A — De-light ON.** This is the shipping albedo / MR / normal set.
24. **Pass B — De-light OFF, same confirmed geometry.** This is the emissive + cyan source.
    Ships a real `texture_emissive.png` and restores the cyan the De-lit pass drains
    (Garrison Keep: diffuse p99 **0.051 → 0.624**).
25. PBR Temperature: **5** ⬆ **CHANGE** (Sheet 3 says 7) — *but expect it not to be enough.*
    Measured across four Architect structures: roughness p50 **0.941 – 0.973**, glossy fraction
    under ~1.1 %. Temp 5 barely moves it. Set 5, move on; the real fix is the import remap
    (step 42), not another material pass.
26. 8K/HD add-on: **skip**.
27. → **Confirm material** (both passes).

---

## STAGE 3 — Export — **take everything** ⬆ **CHANGE**

28. Geometry: **Quad 18000.** Keep it — do **not** raise it hoping to fix softness.

    > ⚠ **Corrected 2026-08-09.** The first draft of this sheet argued for the highest budget
    > available on the grounds that the FOB is a singleton and 40k tris spread thin across a
    > whole fortress. The measurement in the header disproves it: the rejected FOB is already
    > the **densest** Architect mesh we have (3312 tris/area vs the Spire's 2153). It is not
    > tri-starved. More triangles buy a smoother blob, not a sharper fortress.
    >
    > The singleton argument still holds for *budget headroom* — one FOB per map means 18000 is
    > affordable where towers capped at 8 are not — it just is not the lever for this defect.
    > The levers are input resolution (step 2), CFG/Detail (steps 14–15) and decomposition
    > (Stage 1b).

29. Also export **Smart-Poly v1** as a second pack. The Garrison Keep shipped through
    Smart-Poly rather than Quad; there is no head-to-head measurement yet, and export re-runs
    do not re-roll geometry. Cheap comparison, keep both.
30. Baked normal: **ON**
31. Pack: **Base Model only** (no LOD, no High-poly)
32. Material checkboxes: PBR **checked** | Shaded **unchecked** | **2K**

    > "Shaded" is NOT an emissive. It bakes the lit albedo into an emissive slot — a full-colour
    > atlas ~5 % black rather than an emission map ~98 % black. Useful preview, useless as a mask.

33. Format: **.glb primary — but download every format offered** (`.glb`, `.obj`, `.fbx`).

    > ⚠ Not paranoia: the loose `texture_emissive.png` **is not bound into the GLB material**
    > (the Bastion, Spire and Keep all declare `emissiveFactor: null`), and which loose maps
    > appear varies by pack. The Garrison Keep folder holds five progressive re-downloads for
    > exactly this reason. `.obj` was also what stranded Sentry Spire V1 when taken *alone* —
    > no scene graph, no node names — so `.glb` must be among them, not instead of them.

34. Download → `design/architect_fob_concepts/<Variant>/V<n>/{DelightON,DelightOFF}/`

---

## STAGE 4 — Acceptance gate — run before you close the Rodin tab

### 35. Geometry acceptance — **this one is a HUMAN gate. There is no numeric substitute.**

⚠ **A numeric crease gate was proposed here and then killed by its own baseline** (2026-08-09,
table in the header). Face-dihedral percentages and tri density put the rejected FOB *inside*
the band of every asset we accepted — it is denser than all of them. **Do not re-derive this
metric; it has been tested and it does not discriminate.** Recorded so the next person does not
spend the afternoon re-discovering it.

Run the stats anyway as a **regression check**, not a pass/fail — a result far outside this
table means something structurally odd (see the Garrison Keep row, 0.0 % sharp edges, which is
what Smart-Poly's smoothing produces):

```bash
python3 -c "
import trimesh, numpy as np, warnings; warnings.filterwarnings('ignore')
m = trimesh.load('base_basic_pbr.glb', force='mesh')
a = np.degrees(m.face_adjacency_angles); ext = m.bounds[1]-m.bounds[0]
print('tris %d  verts %d  bounds %s' % (len(m.faces), len(m.vertices), np.round(ext,4)))
print('flat<2 %.1f%%  mid5-20 %.1f%%  sharp>45 %.1f%%  tris/area %.0f'
      % (100*(a<2).mean(), 100*((a>=5)&(a<=20)).mean(), 100*(a>45).mean(), len(m.faces)/m.area))
"
```

**The real gate is the side-by-side.** Open the preview next to `rodin_in/front.png` at the same
scale and answer three questions:

1. Can you **count the same number of distinct masses** in both — bastions, wall segments,
   ranked towers?
2. Is the **gate a hole with visible jamb depth**, or a panel?
3. Do wall channels read as **cut grooves**, or as surface paint?

Any "no" is a geometry failure. Re-roll, or go to Stage 1b — but do not carry it into texture
work. Every hour spent on the rejected build's mask, lights and bake was spent downstream of a
"no" that nobody had asked out loud.

### 36. Emissive — does the **De-light OFF** export include `texture_emissive.png`?

**YES** → step 37. **NO** → re-roll the material pass only (geometry stays confirmed, so this
costs no re-measuring). If a second roll also comes back empty, author the channels as a second
emissive material in Blender — the Garrison Keep rig is the reference (`Garrison.blend`:
`EMISSION_MASK` image → Mix Shader Fac, Emission `(0, 0.7, 1.0)` strength 0.85).

> ⚠ `texture_emissive.png` is a **lottery of the material generation** (established 2026-07-28).
> Nothing you control reliably forces it — not format, not prompt, not input art. The Siege
> Foundry produced none across two material prompts × two export formats despite carrying
> *twice* the Spire's cyan.

### 37. Emissive quality check

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
| coverage in band, mid-tone > 25 % | **HARDEN** via `--from-emissive` (step 41) |
| coverage far out of band | Investigate before baking |

For reference: the rejected FOB mask sat at **82 % mid-tone** before its 2026-07-26 rebuild —
the *"cyan close-up, gone at gameplay distance"* row in the guidelines failure table.

### 38. Roughness check

```bash
python3 -c "
from PIL import Image; import numpy as np
Image.MAX_IMAGE_PIXELS=None
r=np.asarray(Image.open('texture_roughness.png').convert('L'),dtype=np.float32)/255
print('p50 %.3f  p90 %.3f  glossy(<0.35) %.2f%%'%(np.percentile(r,50),np.percentile(r,90),100*(r<0.35).mean()))
"
```

Want p50 ≤ 0.75. Expect ~0.94 and plan on the import remap (step 42). On a GLB, roughness is
the **G channel** of the packed metallic-roughness texture.

### 39. Diffuse gate — on the **De-light OFF** diffuse

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
| p99 ≥ 0.12 **and** frac 2–8 % | **PASS** — colour bake available as fallback |
| p99 0.05–0.12 | Marginal — `--blue-dominance 0.070`, inspect |
| p99 < 0.05 | **Achromatic** — colour path is dead; the OFF emissive is the only source |

The shipped FOB tuned to `blue_dominance 0.100` → 1.61 % coverage (`bake_emission_mask.py`
`PRESETS`). Re-tune per generation — De-light drains the cyan differently every run.

---

## STAGE 5 — Post-pipeline (Godot)

### 40. Re-measure everything. Nothing below transfers.

The current `AssetLoader` values are **for the rejected mesh only** and are listed purely as a
sanity reference for the new numbers:

| Key | Rejected-build value |
|---|---|
| `FACTION_BASE_SCALE.architects` | `140.0` |
| `FACTION_BASE_WALL_NORM` | `0.57` (walls ~80u) |
| `FACTION_BASE_TOTAL_NORM` | `1.55` (spire ~217u) |
| `FACTION_BASE_YAW` | `0.0` (front is +Z) |
| `FACTION_BASE_BASTIONS` | 4 corner muzzles at `(±0.78, 0.556, ±0.78)` |

**Hard design rule, re-verify every time:** the Commander is ~73 game units. **The external
walls must be taller than the Commander.** Set scale so wall-norm × scale > 73, then check the
spire does not crowd the 60×34 board (the rejected build's ~266 px footprint ≈ 4.2 cells was
judged correct — keep near that).

Re-measure: bounds, ground alignment (`min y = 0`), wall-top normalized height, total height,
front facing, and the four bastion muzzle points from the new mesh.

### 41. Bake the mask

- **From the OFF emissive** (`--from-emissive`) when step 36 passed. ⚠ Re-enable the fatness
  cut and **DROP** fat components rather than rimming them — Rodin paints much of its emissive
  onto flat plating (Garrison Keep: 31 components > 9 px half-width carried **71 %** of the lit
  area and read as splotches).
- **From colour** (§2a shape-aware path) only as fallback. Never blur, never dilate.
- Target **1.5–2.5 % coverage, mid-tone share ≈ 0 %**.
- **Do not attempt cavity/AO gating.** Tested and dead: mean AO under the lit texels was
  **0.948 vs 0.605** elsewhere — the glow sits on the most *exposed* surfaces because the
  channels are painted, not modelled. (If Stage 1 finally delivers real recesses, this becomes
  worth re-testing — note the result either way.)
- Godot first-imports a mask as `compress/mode=0, mipmaps=false, detect_3d=1`. Hand-set
  **`mode=2` / `mipmaps=true` / `detect_3d/compress_to=0`**, or pass `--write-import`.
  Preserve the existing `.import` file when re-baking so the UID stays stable.

### 42. Material — emission and the roughness remap

```gdscript
tune_masked_emission(model, 3.0, MASK)   ## EMISSION_OP_MULTIPLY only; ADD is forbidden
```

Remap the packed MR texture's **G channel** into roughly a **0.18 → 0.55** range, preserving
relative variation rather than flattening it, so plates read polished and recesses stay matte.
Duplicate the material per instance before modifying — never mutate a shared GLB material at
runtime (§5).

### 43. Light cluster — **retune `ARCHITECT_FOB_LIGHTS` from scratch**

Current values are a standing defect, deliberately left unfixed so the 2026-07-26 mask rebuild
could be judged on its own variable:

```gdscript
PortalFront  energy 3.20  range 90.0   ## ⚠ washes the whole front face flat
```

Every other Architect structure sits at range **30–46**. Pull the FOB's ranges in hard and
size each light to its emitting feature. Place each just **outside** its surface along the
outward normal. Broad per-object fill is forbidden (§3).

---

## STAGE 6 — Validation before declaring the import complete

44. Crease gate passed (step 35) — **the mesh has edges**.
45. Mask coverage 1.5–2.5 %, mid-tone share ≈ 0 %.
46. Mask preview: discrete hard-edged bars along the walls and buttresses. **No glowing slab
    over the gate.** No speckles.
47. Roughness remapped to p50 ≤ 0.75 — plates read polished, not chalky.
48. Emission **off** → albedo and PBR read correctly on their own.
49. Emission **on** → only channels, gate rim, spire core, bastion crowns and hangar mouths glow.
50. Walls measurably taller than the Commander, side by side in the tactical camera.
51. Bastion tracers leave the four real corner towers and descend onto targets.
52. Close / tactical / RTS distances checked. Lit **and** shadow-facing sides checked.
53. Readable with SDFGI disabled. Spawning it does not change world exposure.
54. Godot import clean, Battle3D boot log **empty**.
55. Re-export both exes (`.\tools\export.ps1`) — standing flag since 2026-07-25.

---

## STAGE 7 — Run log

| Run | Date | Variant | Input px | Seed | Detail/CFG/Step | Quad | Tris | Emissive | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| V1 | 2026-07-21 | Default | 508² | ⚠ unrecorded | +1 / 10 / 50 | 18000 | 40,425 | ❌ none | **REJECTED 2026-08-09** — features unresolved. Not tri-starved (densest mesh in the set); input resolution + feature density are the suspects |
| V2 | 2026-08-09 | Default | 1024² *(512² native)*, **consistent** | ⚠ unrecorded | — | — | 41,410 | ✅ **1.72 %** | **REJECTED — melted wax again.** Consistency fixed, mesh unchanged. Textures excellent |

### V2 — the consistency experiment, and its answer

**Consistency was not the cause.** V2 was generated from `rodin_in_consistent` (front/left/right
spread **0.7 %**, verified same building in every view) and returned a mesh that is, if anything,
softer than V1. Clay renders: `Default/_qa_front.png`, `Default/_qa_threequarter.png`. Drippy
candle-wax masses, no flat plate faces, no hard corners, panel insets absent, gate a soft rounded
recess with no jamb.

| | V1 | V2 |
|---|---|---|
| Input consistency | 26.1 % spread | **0.7 %** ✅ |
| Tris / verts | 40,425 / 23,024 | 41,410 / 23,420 |
| Bounds (W×H×D) | 1.9017 × 1.5498 × 1.855 | 1.9014 × **1.7673** × 1.7106 |
| flat<2 / mid5-20 / **sharp>45** | 24.4 / 35.3 / **7.4 %** | 22.0 / 35.8 / **8.4 %** |
| tris/area | 3312 | 3319 |
| Verdict | melted | **melted** |

⚠ **The numeric gate is now doubly disproven.** V2 scores **8.4 % sharp edges — level with the
accepted Sentry Spire's 8.6 %** — and looks like a candle. Do not resurrect it.

**Ruled out by measurement, in order:** poly budget (V1 was the densest mesh we own) → view
consistency (V2 fixed it, nothing changed). **Remaining:** native input resolution (still 512 %²
at V2) and Rodin's reconstruction ceiling at this feature density.

> ### The pattern nobody had lined up until now — 4 for 4 vs 0 for 2
>
> | Asset | Form | Result |
> |---|---|---|
> | Sentry Spire | one tapered shaft | ✅ crisp |
> | Plasma Bastion | one squat mass | ✅ crisp |
> | Siege Foundry | one mass + barrels | ✅ crisp |
> | Garrison Keep | one octagonal keep | ✅ crisp |
> | **FOB V1** | ~30 sub-masses | ❌ melted |
> | **FOB V2** | ~30 sub-masses | ❌ melted |
>
> **Every Architect asset Rodin has rendered well is a single simple mass. Every multi-mass
> structure has failed.** Stage 1b is not a fallback — it is a description of what already
> works. A bastion tower, a wall segment and the spire keep are each the same complexity class
> as a Sentry Spire.

**✅ The texture side is solved and carries forward.** V2 returned `texture_emissive.png` at
**1.72 % coverage — in band** (mid-tone 59.7 %, hardens via `--from-emissive`), and the diffuse
passes the colour gate outright (**p99 0.329, frac 4.97 %**), so *both* mask paths are live and
the Garrison-Keep achromatic failure is off the table. Roughness is the usual chalk (p50 0.961 →
import remap). None of this depends on the geometry — the material prompt in Stage 2 is proven
and should be reused verbatim on whatever mesh replaces this one.

**Next, cheapest first:** one more whole-object run at genuine **≥1024² native** input (a 2-cell
sheet, or a low-denoise img2img detail pass over the existing consistent cells) — one art pass,
one Rodin run, and it closes the last untested variable. If that is still soft, the answer is
Stage 1b and the evidence for it will be complete.

### Input-set log

| Set | Date | Px | Height spread | Ortho? | Plinth? | Verdict |
|---|---|---|---|---|---|---|
| `rodin_in/` | 2026-07-21 | 508² | **26.1 %** | ~yes | no | Used for V1. Low-res, but front/back and left/right paired cleanly (0.921/0.917 and 0.709/0.709) because all cells came from **one sheet generation** |
| `rodin_in_clean/` | 2026-08-09 | 2048² | **36.1 %** | ❌ no — 3/4 elevated | ❌ yes | ⚠ **DO NOT UPLOAD.** Resolution and gate detail are a large improvement, but the five views are five different buildings, rendered per-view. Consistency got *worse* than the set it replaced |
| `rodin_in_consistent/cells/` | 2026-08-09 | 1024² *(512² native)* | **8.7 %** all four — **0.7 % dropping `back`** | ~yes, mild elevation | ⚠ yes, ~3 % of height | ✅ **USE THIS — upload `front` + `left` + `right` (+ `top`).** Same building in every view. `back` is the same design but framed larger (h 905 vs 831–837, w 853 vs 963) — a framing mismatch, not a design one |

**The sheet fixed consistency and cost resolution.** The `3072 × 2048` sheet is an **upscale** of a
native `1536 × 1024` generation — mean |diff| against the upscaled native is **1.09/255**, and
laplacian variance is 138.8 vs 118.7, i.e. no new high-frequency content. A 6-cell 1536×1024
sheet is **512² native per cell — exactly V1's resolution.** The 1024² cells carry 2× the pixels
and 1× the information.

> ### ⚠ This makes the next run a clean experiment — take it before adding art effort.
>
> V1's input set was *both* low-res **and** 26 % inconsistent. Nobody knows which mattered.
> `rodin_in_consistent` holds native resolution constant at 512² and fixes only consistency, so
> **running it now isolates the variable at zero extra cost.**
>
> - Good mesh → consistency was the whole problem; the resolution work was never needed.
> - Still soft → resolution is independently implicated, and the detail pass below is justified.
>
> Either result is worth more than another round of art. **Record it in Stage 7.**

**If resolution does turn out to be needed, get both** — do not go back to per-view rendering:

- **Preferred: a low-denoise img2img detail pass** (~0.2–0.3) over each *already consistent*
  cell at 1024–2048. It adds real high-frequency detail while preserving composition, and
  cross-view consistency survives because every view starts from an agreeing image.
- **Or fewer cells per sheet:** two cells in a 1536×1024 sheet is 768×1024 native each. Render
  front+left as sheet 1, then right+back as sheet 2 **conditioned on sheet 1**.

> The `rodin_in_clean` **top** view is genuinely excellent — true orthographic, crisp, 4-fold
> symmetric, square plan with four octagonal corner bastions (which matches
> `FACTION_BASE_BASTIONS`). Keep it as the plan-form reference; it is the one usable file in
> that batch, though it must be re-rendered alongside the elevations to agree with them.

Copy the accepted row into the seeds log in `design/docs/Rodin_Recipe_Sheets.md`.

**Findings to record for V2 regardless of outcome** — each is currently an inference, not a
measurement, and the next person deserves the answer:

- Did **re-rendered 1024²/2048² inputs** (step 2) visibly improve feature resolution?
- Did **Step 75** (step 16) change anything versus the default 50?
- Did **Detail +3 / CFG 12** help, or push into surface speckle?
- If a whole-object run was still soft: did **Stage 1b decomposition** resolve it?

---

## Appendix — why each ⬆ CHANGE exists

**Steps 14/15 (Detail +3, CFG 12).** The README ran **+1 / 10** — Sheet 3's default, which is
tuned for *towers*, where a simple silhouette carries the read. The FOB is the opposite case:
its silhouette is a compound of walls, gatehouse, bastions and spire, and everything that makes
it Architect is surface articulation. The Sentry Spire already stepped to +2 / 11 for the same
reason and its appendix sets the ceiling at **+3 / 12**. This asset is the one that justifies
the ceiling. Do not exceed it — past that, surface noise becomes speckle in the bake.

**Step 16 (Step 75).** ⚠ **The one lever in this document with no measurement behind it.**
Every recorded Architect run used the default 50. More diffusion steps buys convergence on fine
detail, which is exactly the failure mode — but it is inference, not evidence. Treat it as the
first thing to vary if V2 is still soft, and **record the result in Stage 7 either way**, so
the next person knows whether it mattered. (The Spire's collar line is the precedent for
writing down a lever that turned out not to matter — that finding was worth as much as the
reverse.)

**Step 17 (geometry prompt now required).** Rodin paints an opening as a flat teal **fill**,
which bakes as a solid glowing slab reading as a decal rather than a recess. That is not a
hypothetical here — it is the FOB's front gate, an open follow-up since 2026-07-26 that
currently needs a manual Blender inset to fix. Blocking it at the prompt is free; fixing it
in Blender is the one job on this asset that genuinely requires Blender.

**Step 18 (three more negative terms).** `melted, rounded edges, soft blobby forms` names the
observed defect directly. Cheap, and nothing else in the pipeline is defending against it.

**Stage 2 (two material passes).** The Garrison Keep spent a week stranded — its De-lit export
is achromatic (max b−r 0.090, p99 0.051), so no colour-derived mask works and its ChatGPT-era
mask was verifiably noise (lit-vs-unlit b−r delta +0.014). The fix turned out to be trivial: a
De-light **OFF** re-generation restores the cyan and ships a real emissive, onto byte-identical
UVs. Running both passes up front converts that week into one extra click. **This is the single
most valuable change in this document.**

**Step 25 (Temp 5).** Measured, not guessed, across four structures: p50 0.941–0.973, glossy
under 1.1 %. Rodin will not deliver near-mirror Architect ceramic. Set 5 so the input is right,
and stop spending generation passes on it — the remap at step 42 is the actual fix.

**Step 2a (one sheet, one generation).** Learned immediately, and expensively: the first
re-render attempt raised the inputs to 2048² — the right fix — but generated each view as a
separate call, and produced five different fortresses. Measured height spread **36.1 %**, worse
than the 508 px set's 26.1 %. Resolution and consistency are *both* necessary, and consistency
is the one you cannot ask for politely; it has to come from rendering the views in a single
pass. The original low-res sheet got this right by accident — its cells paired to within 0.4 %
because they shared one denoise.

**Step 2 (re-render the inputs).** The highest-value change here, and the one that was nearly
missed because the poly-count explanation was more obvious. Every Architect asset that came
back crisp is a *single simple mass* rendered at ~508 px; the FOB is thirty sub-masses at the
same 508 px. The concept art is excellent — `rodin_in/front.png` is disciplined and detailed —
so the information loss is at the crop resolution, not in the design. Rodin cannot reconstruct
a 1–2 px channel.

**Stage 1b (decomposition).** Held in reserve rather than made the default, because it costs a
Blender assembly pass and the input-resolution fix may be sufficient on its own. If it is
needed, it is not a workaround: it is the same rule Sheet 1a already reached for the Mesh
Commander's tentacles, and the fortress's symmetry makes it unusually cheap here.

**Step 28 (Quad 18000, NOT higher).** ⚠ **This entry originally argued the opposite** — that
the FOB is a singleton and should take the highest budget offered, because 40k tris spread
across a whole fortress gives each feature less resolution than a plain spire gets. The
measurement killed it: the rejected FOB is the densest Architect mesh we have. The reasoning
was plausible and wrong, which is exactly why it is worth leaving on the page.

**Steps 29/33 (take every pack and every format).** Purely operational, learned the hard way
twice: Sentry Spire V1 was stranded because OBJ alone has no scene graph or node names, and the
loose emissive PNG's presence varies by pack. Downloading everything costs nothing and does not
re-roll the seed.

**Step 35 (human gate, not a numeric one).** A dihedral-angle crease gate was drafted here and
baselined the same day against four accepted assets plus the rejected one. It failed: the
rejected FOB scored *inside* the accepted band on every statistic and was the densest mesh in
the set. Mesh geometry statistics cannot tell "40k tris of crisp fortress" from "40k tris of
well-tessellated blob," because the blob is genuinely well-tessellated. What sank V1 was that
nobody put the preview beside the concept art and counted masses — a thirty-second check that
would have saved a texture pipeline, a mask rebuild and a lighting workaround. That check is
now the gate, and it is deliberately a human one.

**Step 43 (retune the lights).** `PortalFront` at energy 3.20 / range 90 is more than double
every other Architect structure's range and is a recorded defect, kept only so the mask rebuild
could be judged in isolation. That reason expires the moment a new mesh lands.
