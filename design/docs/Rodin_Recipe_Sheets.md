# Rodin Generation Recipe Sheets — Cycle Four Assets

Line-by-line settings for generating every Cycle Four asset class on Hyper3D Rodin (web, basic plan).
Companion to the memory recipe (input prep + export ticket). One sheet per asset class; faction
material prompts at the bottom. **Record the SEED of every accepted run in this file.**

Universal rules (all sheets):
- Input = clean per-view crops on plain background (front + back + left + right when available).
  NEVER a full reference sheet. Multi-image mode = **concat / "multi-view of one object"**.
- **VERIFY EVERY CROP INDIVIDUALLY before upload.** Sheet figures overhang their panel gutters,
  so a neighbor's arm can ride along in a crop — Rodin models it as floating geometry (this
  caused the Bloom floating-arm, 2026-07-11). Where no cut line separates figures, paint the
  contaminated strip with the background color instead of cropping tighter.
- Bounding box / Voxel / Point cloud: **leave EMPTY** — the view crops carry shape + proportion.
- Mode: **Faithful** (Creative is for concept-forge exploration only).
- Negative prompt (same for every asset): `multiple objects, duplicate figures, floating parts,
  disconnected pieces, base, pedestal, stand, ground plane, text, labels, watermark, UI panels,
  blurry, low quality`
- Export ticket (all assets): Quad Mesh 18000 (commanders/heroes) or 8000 (units/props) —
  see per-sheet; baked normal ON; Pack = Base Model only; .glb; PBR checked / Shaded unchecked;
  2K; De-light ON; PBR Temperature 7 (drop to 5 if over-shiny).
- **Don't redo a good body over a small flaw.** Floating/disconnected pieces (stray arm, debris
  island) are trivially removed in cleanup (keep-largest-connected-component); a redo re-rolls
  the seed and risks losing a good generation. Redo only if the MAIN body is wrong.

---

## SHEET 1 — COMMANDERS (hero characters: Architect / Bloom / Mesh ACU)
Sequential checklist in UI order. Validated on the Bloom Commander 2026-07-11.

**Stage 0 — Input prep**
1. Crop each orthographic view (front/back/left/right) from the sheet — one figure per image, plain bg, no labels
2. Verify EACH crop individually — no neighbor limbs (paint overhang with bg color if no clean cut)
3. Upload all four; multi-view of ONE object (concat) if asked

**Stage 1 — Geometry**
4. Model: Gen-2.5 | Quality: **High**
5. T/A Pose: **ON**
6. Mode: **Faithful**
7. Symmetry: **Symmetric with per-faction WEIGHT** — Bloom: **Low** (chassis aligned, but organic
   growth + the right-arm engineering-tool asymmetry must survive); Architect: **High** (machine-
   precise, full mirror on-theme); Mesh: **Medium**. Symmetric mirrors the vertical axis — high
   weight makes sides IDENTICAL, erasing designed asymmetry. If a preview shows cloned arms or
   duplicated growth patterns, drop to asymmetric/auto.
8. Style tags: **game-ready + character**
9. Bounding box: empty | 10. Voxel: empty | 11. Point cloud: empty
12. Seed: **−1** (record the resolved seed after generation if the UI shows it)
13. Detail: **+3** (scale −5..+5, default 0)
14. Cfg: **11** (scale 1–15, default 10)
15. Step: **50** (default; scale 10–100)
16. Negative prompt: universal (above)
17. Generate → inspect preview from several angles → redo ONLY if the main body is wrong → Confirm

**Stage 2 — Material generation (unlocks after geometry confirm)**
18. Material prompt: faction block (below)
19. De-light: **ON**
20. PBR Temperature: **7** (5 only if over-shiny)
21. 8K/HD add-on: skip

**Stage 3 — Export (unlocks after material confirm)**
22. Geometry: **Quad Mesh 18000**
23. Baked normal: **ON**
24. Pack: **Base Model only** (no LOD / no High-poly)
25. Material checkboxes: PBR **checked** | Shaded **unchecked** | **2K** (skip 4K)
26. Format: **.glb**
27. Download → `D:\AI\Cycle Four\design\concepts\`

**Stage 4 — Claude post-pipeline**
28. Inspect (orientation/single-body/channels) → island cleanup → faction rig script (nearest-bone,
Walk+Idle, LARGE gait) → `assets/models/units/<faction>_commander_hifi.glb` → scale = 73 / mesh
height → yaw +90 (verify in play) → Godot boot check → F1/F2/F3 playtest.

### SHEET 1a — MESH COMMANDER specifics (tentacled designs generally)
Rodin CANNOT reconstruct long thin overlapping appendages (tentacles/tendrils/cables) — they fuse
into arms, terminate early, sprout orphans, and invent random tips (observed 2026-07-11 on the Mesh
ACU). No setting fixes this; it's a fundamental multi-view-reconstruction weakness.
- **Hybrid rule: body from Rodin, appendages from Blender.** Prefer tentacle-less concept views;
  if the views have tentacles, generate anyway → **Bang to Parts** (worked well 2026-07-11) → keep
  body parts, discard tentacle fragments.
- Mesh deltas from Sheet 1: Symmetry weight **Medium**; material prompt = Mesh block (below).
- Post-pipeline: rig body on the standard biped skeleton, then add 4 procedural tentacle chains
  (segment styled to the Rodin body, instanced down curves rooted at the back plate, per-chain
  bone runs + traveling-wave weave — reuse the `biped_commanders.py` approach). Deploy as
  `mesh_commander_hifi.glb`, F2 playtest.
- Applies beyond Mesh: Bloom tendrils on buildings, cables, vines — any thin trailing geometry.

## SHEET 2 — STANDARD UNITS (T1–T6 rosters, friendly + enemy)

| Control | Setting |
|---|---|
| Images | front + side minimum (back too if drawn), concat |
| T/A Pose | ON for bipeds; **OFF** for crawlers/vehicles/drones (it forces humanoid) |
| Symmetry | Symmetric — weight Low (Bloom organics) / High (Architect) / Medium (Mesh); asymmetric/auto if the unit design is deliberately lopsided |
| Quality tier | **Medium** (units are small on screen + many on screen) |
| Style tags | bipeds: **character + game-ready**; vehicles/crawlers/mechanical: **edges + game-ready**; Bloom organics: **soft + game-ready** |
| Mode | Faithful |
| Detail | **+1** (scale −5..+5) — silhouette matters more than surface at unit size |
| CFG | **10** (default) |
| Step | **50** (default) |
| Seed | record accepted |
| Negative prompt | universal |
| Export | Quad **8000** + baked normal, PBR, 2K, De-light ON, Temp 7 — units are ~26 game units and numerous; 18k is wasted |

Post: rig only if animated (walkers); static-pose units can ship unrigged. Unit scale ≈ 26 game units
(`AssetLoader.FACTION_MODELS` — currently empty; populating it switches units off procedural bodies).

## SHEET 3 — BUILDINGS / TOWERS / WALLS / ENEMY BASES

| Control | Setting |
|---|---|
| Images | front + 3/4 view (buildings read from one angle in-game), concat |
| T/A Pose | **OFF** |
| Symmetry | Symmetric for towers/bases; **auto** for sprawling Bloom growth-structures |
| Quality tier | Medium (High for the FOB/enemy bases — they're focal) |
| Style tags | **edges + game-ready** (Architect/Mesh); **soft + complex** (Bloom growth buildings) |
| Mode | Faithful |
| Detail | **+1** (scale −5..+5) |
| CFG | **10** (default) |
| Step | **50** (default) |
| Seed | record accepted |
| Negative prompt | universal |
| Export | Quad **8000** (18000 for bases/FOB) + baked normal, PBR, 2K, De-light ON, Temp 7 |

Post: no rig. Orient ground-plane at z=0. Towers need the turret separable if they should track
targets — either generate turret + base as TWO runs, or accept a fixed sculptural tower (current
Tower.gd builds its own turret; decide per building before generating).

## SHEET 4 — SMALL PROPS (drones, convoy vehicles, pickups, ruins fragments)

| Control | Setting |
|---|---|
| Images | 1–2 views is enough at this size, concat |
| T/A Pose | OFF |
| Symmetry | Symmetric (vehicles/drones) / auto (ruins, debris) |
| Quality tier | Medium |
| Style tags | **simple + game-ready** — props must not out-detail the units next to them |
| Mode | Faithful |
| Detail | **0** (default) |
| CFG | **10** (default) |
| Step | **50** (default) |
| Seed | record accepted |
| Negative prompt | universal |
| Export | Quad **4000** + baked normal, PBR, 2K, De-light ON, Temp 7 |

---

## FACTION MATERIAL PROMPTS (paste into Material prompt, adjust nouns per asset)

**Architects (blue / Seraphim-sleek — NO grids/seams):**
> Sleek polished near-black armor plates with smooth chrome highlights; thin glowing cyan-blue
> energy channels tracing the panel flow; minimal seams, refined surfaces; bright emissive
> cyan-blue glow in the eyes, core, and vents.

**Bloom (green / armor + biology breaching):**
> Battle-worn mech armor: matte gunmetal-blue steel plates with scratched edges and panel seams;
> dark mechanical inner structure at joints; rough organic bark and twisted wood growth breaching
> the armor seams; patches of green moss and lichen on upper surfaces; bright emissive sap-green
> bioluminescent glow on the eyes, chest nodes, and cannon vents.

**Mesh (red / Cybran-angular):**
> Angular faceted near-black armor with exposed mechanical frame sections; sharp creased panels
> and vents; hot red tech-channels and node lights along the limbs; bright emissive red glow in
> the eyes, sensors, and joints.

---

## ACCEPTED SEEDS LOG

| Asset | Date | Seed | Notes |
|---|---|---|---|
| Bloom Commander | 2026-07-11 | (record on accept) | 4-view rodin_in crops, re-run after sheet fiasco |
