# Commander (ACU) Visual Backlog

Tracking for the three faction commander mechs. Concept: all bipedal ACUs.
- **Architect** = Seraphim-style biped (blue energy) — `architect_commander.glb`
- **Bloom** = "Groot" woody biped (green sap glow) — `bloom_commander.glb`
- **Mesh** = "Doc Ock" biped w/ 4 back tentacles (red glow, Cybran-angular) — `mesh_commander.glb`

Build scripts (headless Blender): scratchpad `architect_mech.py` (Architect),
`biped_commanders.py` (Bloom + Mesh). Lineup render: `lineup_mockup.py`.
References: `design/Seraphim example*.jpg`, `Aeon Example*.jpg`, `Cybran Example*.jpg`.
Color scheme is LOCKED: Architect blue / Bloom green / Mesh red.

## SILHOUETTES LOCKED (2026-07-06, ref-driven — see design/*.jpg)
- All three bipeds on the shared rig (Walk + Idle, rigid skin weights). Colors: Architect blue / Bloom green / Mesh red.
- Architect (Seraphim): swept-back shoulder wing-blades, bladed head crest, glowing thruster-feet, chest/shin energy lines.
- Bloom (Groot): reworked to a HULKING giant woven from thick bark tendril-bundles (mech mass, woody character).
  Head = continuous bark trunk with a FLAT jagged tree-stump crown; face carved-in (no mask, no nose); illuminated
  green sap eyes. (History: went bed-head crest → onion → tiki-mask → this. Refs: Bloom Example.jpg, Bloom Example 2.jpg.)
- Mesh (Doc Ock): faceted/angular (bevels killed), red chest plate + shoulder trim + red glow, angular wedge pauldrons,
  big sharp swept devil-horns, four weaving back tentacles.
- Verify renders: design/commander_lineup.png (3/4 trio) + design/bloom_head.png (Groot head closeup).

## SURFACE-DETAIL PASS 1 — DONE (2026-07-06, geometry+material, NOT baked textures)
Chose geometry greebling + emissive channels + material accents over baked normal/albedo maps
(reads better at RTS zoom, exports natively, no UV/bake fragility).
- Architect: base darkened to near-black Seraphim plate (was bright chrome) so the blue energy-channel
  network pops; channels on torso/limbs/blades + core frame + glowing feet.
- Mesh: seam lines, red chest plate, red tech-channels, shoulder greeble vents, red knee/wrist nodes.
- Bloom: bark ridges + trunk crack + moss-tint patches. (Moss patches read a bit blobby — candidate
  for refinement.) Renders: design/architect_detail.png, mesh_detail.png, bloom_detail.png.

## VARIANT PICKS + ARCHITECT REFINE — DONE (2026-07-06)
User reviewed A/B/C variant sheets (design/variants_*.png) and chose:
- Groot moss = **dots** (current, kept). Mesh red = **tech** (most red + channels). Architect channels = **dense**.
- Architect structural changes: **squared** pelvis/waist/chest (boxes, no subsurf) + **squared** box shoulders;
  **arms symmetric** (removed the forward arm-cannon; both hang with boxy forearms/fists); **shoulder fins
  rooted into the shoulder** (base moved onto the pauldron + a tie-in wedge). Defaults baked into the scripts
  (ARCH_CHAN=dense, MESH_RED=tech). Variant env hooks still available for future exploration.

## ROUND 2 TWEAKS — DONE (2026-07-06)
- Architect: BOTH arms are forward cannons now (symmetric; earlier I wrongly removed it entirely).
- Groot: moss coverage tripled (clustered dots across shoulders/torso-crevices/arms/thighs/shins/pelvis).
- Mesh: BOTH arms are forward cannons (in addition to the 4 tentacles) + 4 construction-style nano-drones
  hovering around the ACU (small angular bots w/ red emitter-eyes, parented to Root).

## SKETCH-DRIVEN ARCHITECT REBUILD — 2026-07-06
User hand-sketched the Architect (design/`Architect ACU Sketch.jpg`, front/side/arm/leg/torso/head views).
Rebuilt to match: angular helmet + top spike + visor eyes; faceted hex chest w/ round core + 3 vent lines +
side panels + tapered abdomen; curved shoulder HORNS (was flat plates); both forward cannon arms; digitigrade
legs w/ CLAWED TALON feet. Sketch workflow validated — flat views + labeled parts translate well.

## QUEUE — remaining detail / polish
1. Mesh drones are static — could add an orbit/bob animation (needs drone bones + keyframes).
2. Optional baked normal maps for close-up fidelity IF the game ever needs it (not for RTS zoom).
3. Per-faction markings / paint. Architect head still a round sphere (square it if it bugs later).

## NOTE — fidelity vs the reference images (IP + tooling)
User asked if something prevents matching the examples closely. TWO real factors:
1) IP: Groot & Doc Ock are Marvel characters; Seraphim/Aeon/Cybran are SupCom-owned. For a shippable game we
   build "inspired-by" archetypes (silhouette/vibe), NOT 1:1 clones — deliberate, to avoid copyright/trademark risk.
2) Fidelity: these are PROCEDURAL PRIMITIVE assemblies (boxes/spheres/cylinders via script) → always read stylized/
   low-poly, not film-detail. Closing that gap needs hand-sculpted models or licensed/marketplace assets, not more script.

## AI-GEN PIPELINE FINDINGS (2026-07-08, Blender MCP + Hyper3D Rodin free trial)
MCP works now (execute_blender_code, viewport screenshot, Rodin gen). Findings:
- **Text-to-3D (Rodin)**: ~23k-poly textured meshes, EXCELLENT fidelity, but WEAK pose/silhouette control —
  prompts for "neutral symmetric T-pose mech" produced hunched raptor-creatures with tail-blades. Good for
  concept/hero assets, not spec'd units. Renders: design/architect_rodin.png, architect_rodin_v2.png.
- **Image-to-3D (Rodin) from hand-sketch photos**: FAILED — treats pencil lineart as texture on flat slabs
  (design/architect_fromsketch.png). Needs clean photo/render of a real subject on plain bg, not sketches.
- **Image-to-3D from CLEANED black-on-white lineart** (threshold_img.py @0.10): still FAILED — coherent solid
  mesh but a lumpy abstract blob, cannons→slabs, legs→plates (design/architect_sketch_bw.png). Line art gives
  Rodin too little to infer structure; it needs SHADED/painted concept art or a photo, not line drawings.
  CONCLUSION: sketch→3D via Rodin is not a path. AI-gen is a concept/hero tool, not a spec'd-unit pipeline.
- All Rodin output is a SINGLE FUSED UNRIGGED mesh, normalized size → needs rig + scale before in-game animation
  (much harder than the primitive part-assembly rig). MCP Rodin toggle drops to disabled on connection reset.
- Reliable in-game path remains the primitive pipeline (rigged, animated). AI-gen = concept/hero tool for now.
- Cropped sketch inputs: design/sketch_front.png, sketch_side.png. render_glb.py renders any GLB framed.

## DECISION 2026-07-08 — text-to-3D as CONCEPT FORGE (option #1)
Use Rodin text-to-3D for concept inspiration only; translate chosen silhouettes into the rigged PRIMITIVE
commanders (the shippable/animated pipeline). User separately pursuing #3 (shaded concept art for image-to-3D);
NOT buying marketplace assets (#2) yet. Rigged primitives stay the in-game units.
First Architect concept spread (design/): Concept_A_Sleek (winged blade-warrior), Concept_B_Heavy (hulking
juggernaut), Concept_C_Insectoid (predatory beast).

## FACTION DIRECTION from concept spread (user, 2026-07-08) — OVERALL: piloted mechs (robot w/ influence), NOT creatures
- **Bloom** = Concept C insect styling (claws, horns, aggressive stance) + Concept B bulk, BUT as a MECH driven by
  a human — a robot with BIOLOGICAL influence, not a pure creature.
- **Architect** = more ROBOTIC and STREAMLINED. Concept B's width/thickness is about right, but LESS bulk. Not a brawler.
- **Mesh** = none of A/B/C fit — needs its own concept direction (tentacled tech-raider / Doc Ock–Cybran vibe).
- User delivered CLEAN COLORED digital concept art for the Architect: design/sketch_front_bw_0.1.png +
  sketch_side_bw_0.1.png (silver body, charcoal accents, cyan glow, black swept horns, digitigrade talon legs,
  forward arm units). Overwrote the old threshold files. This is proper image-to-3D input (colored, on white).

## BREAKTHROUGH 2026-07-08 — image-to-3D WORKS from CLEAN COLORED concept art
Fed the user's colored front+side Architect concept (sketch_front/side_bw_0.1.png) to Rodin image-to-3D →
design/architect_concept_art.glb / .png: an ON-DESIGN, high-fidelity Architect (white streamlined body, cyan
core+vents, 3 horns, forward arm units, digitigrade talon legs). This is the winning pipeline:
  USER makes clean COLORED concept art (front+side, plain white bg) -> Rodin image-to-3D -> on-design mesh.
Line-art and text prompts do NOT work; COLORED flat concept art DOES.
Still fused/unrigged (~23k polys) -> rigging remains the step before in-game animation.
NEXT: user can make the same colored concept art for Bloom (bulky insect-mech w/ bio influence) and Mesh
(tentacled tech-raider); then generate those. Separately: solve rigging for a generated mesh.

## HI-FI ARCHITECT RIGGED + WIRED IN (2026-07-08)
- Cleaned the concept-art mesh: trimmed the "popsicle stick" (over-projecting arm) via spatial clip
  (scratchpad clean_stick.py -> architect_clean.glb). Ragged cut ends (fragmented shell). Back talon has
  MISSING geometry (mesh gen quirk; user to add symmetric front/back to a future sketch for a clean regen).
- Rigging approach: NOT voxel-remesh (would kill materials). Instead NEAREST-BONE RIGID SKINNING on the
  original detailed mesh (scratchpad rig_mesh.py): biped armature + each vertex -> closest bone @1.0, keeps
  all detail + white/cyan materials. Baked Walk + Idle. -> architect_rigged.glb.
  Deformation WORKS (legs stride, talons articulate) but shows JOINT TEARING at hips/knees/feet up close
  (fragments splitting) — expected on a fragmented AI shell; should read fine at RTS zoom.
- WIRED INTO GAME: architect_commander_hifi.glb (primitive backed up as architect_commander_primitive.glb).
  AssetLoader: architects -> hifi path, FACTION_COMMANDER_SCALE architects=51 (mesh ~1.42u->~73u),
  new FACTION_COMMANDER_YAW dict (architects=+90, bloom/mesh=-90); CommanderBodyRig._try_build_gltf uses it.
  Compiles clean. PLAYTEST-CONFIRMED in-engine (user screenshots): scale/facing/walk all good, joint tearing
  fine at zoom. Revert = point architects back to architect_commander.glb.
- FIXES (rig_mesh.py, iterated): (1) torso front/back "popsicle stick" bar — clip |Y|>0.20 in z[0.38,0.60]H.
  (2) FEET: the AI feet were messy/back-heavy/asymmetric. Final fix = DELETE the AI feet (z<0.16H) and BUILD
  clean primitive talon-feet to the user's `\__|__/` spec: flat white sole pad + centered leg-post + dark
  up-swept front & back claws (cones). Feet auto-attach at each leg's detected lowest point (ankle_of(sx)) so
  no gap; ankle centered on pad. Feet use their own white/dark mats (body keeps its Rodin texture).
  rig_mesh.py pipeline: import concept_art -> orient/center -> clip torso bar + delete AI feet -> build talon
  feet -> nearest-bone rig -> Walk/Idle -> export. ARCHITECT DONE (user-confirmed in-engine; foot re-playtest pending).
  Remaining optional: joint-tearing at zoom (needs retopo/clean base), fine polish.

## PER-CANNON MUZZLE ORIGINS — DONE 2026-07-10 (compile-verified, playtest pending)
Blasts/tracers were spawning from center mass. Now each cannon fires its own muzzle flash + tracer:
- **Towers** (`src/entities/Tower.gd`): `_muzzles` stores each barrel tip in TURRET-local space
  (`Vector3(body_r*0.5+blen, 0, off)`), rebuilt in `_build_visual`. `_try_attack` loops them,
  `_turret.to_global(tip)` -> `WORLD3D.to2` -> Vfx.muzzle+bolt per barrel (folds in turret yaw/recoil).
  Upgraded 2-cannon towers now fire from BOTH barrels. Falls back to `_p` if no turret/muzzles.
- **Commander** (`CommanderBodyRig.gd` + `Commander.gd`): rig exposes `muzzles` (Array[Vector3], COMMANDER-local,
  +X fwd / ±Z lateral). `_compute_muzzles()` derives two symmetric arm-cannon origins from the built body's
  Commander-local AABB (`_local_aabb_of`) — works for the GLB biped now and procedural bodies later.
  `Commander._try_primary_attack` reads them via `_body_rig.get("muzzles")` (rig stored as Node3D), and
  `to_global(m)` folds in the Commander's facing so both arm cannons fire. Falls back to center mass.
- NOTE: tracer FLY-height still fixed at Vfx.BOLT_Y (24) — only the horizontal (plane) origin moved to the
  cannons. If cannon-HEIGHT origin is wanted too, extend Vfx.bolt/muzzle to take a from-Y. Playtest first.

## DECISION — PATH A (2026-07-08): ship the current rigged hi-fi Architect as-is
Remesh path abandoned: raw remesh = clean but keeps stick/front-feet; clean-THEN-remesh = shredded/holey
(open boundaries from clipping voxel-remesh badly — see design/arch_rc_34.png). Voxel remesh is NOT a clean
win on this AI mesh. So: keep the current non-remeshed nearest-bone rigged hi-fi in-game (stick already
removed + symmetric `\__|__/` feet), ACCEPT the minor holes/open-cannon ends (barely visible at RTS zoom),
and only do the TRACTABLE fixes. User will tighten the model in Blender manually later.
Godot "errors after revisions" were TRANSIENT (reimport/cache) — cleared on their own; Architect loads+walks fine.

### PATH A polish — DONE 2026-07-10 (rig8, in-game as architect_commander_hifi.glb, import verified clean):
- [x] Feet enlarged — pad 0.11x0.22 -> 0.16x0.40, claws 0.06/0.20 -> 0.075/0.28 at ay±0.28. No more stilts;
      reads as a proper long symmetric `\__|__/` anchor (see design/rig8_side.png).
- [x] Idle SWAY killed — Idle root now flat (0,0,0) both keys, no z-bob. Dead-still planted stance.
- [x] Weights tightened:
      * Legs now tied to the DETECTED ankle per side (ANK[sx]) instead of fixed fractions — the old ankle bone sat
        at 0.10H, well below the real leg bottom (~0.16H abs / az=0.23), so the Thigh/Shin split was off and the shin
        slid. Thigh=hip->knee(forward), Shin=knee->ankle(detected), Foot=ankle->toe. Legs bend cleanly at the knee now.
      * Arm bones constrained: after nearest-bone, any vert assigned to UpperArm/ForeArm but inboard of the shoulder
        cylinder (|x|<0.24) is reassigned to Spine — shoulder rotation no longer drags a chest slab.
- Script: scratchpad rig_mesh.py (INP design/architect_concept_art.glb -> OUT design/architect_rigged.glb -> copy to
  assets/models/units/architect_commander_hifi.glb). Renders rig8_rest/side/walkpose.png.
- (Accepted, NOT fixed: mesh holes / open cannon ends / shell fragment-tearing — needs retopo, user doing in Blender.)
- STILL PENDING: in-engine hand playtest (F1) to confirm feet/idle/walk read right at game zoom under V1 bloom.

## HI-FI BLOOM RIGGED + WIRED IN (2026-07-11)
Same winning pipeline as the Architect, driven by the user's new `design/reference/Bloom Reference MASTER.png`
(a full model sheet: front/back/L/R/top/bottom + separated sections + material guide).
- **Input prep:** cropped the sheet's clean FRONT/BACK/LEFT/RIGHT orthographic panels to
  `design/reference/rodin_in/crop_*.png` (PIL; the labels/UI/parts-row would confuse Rodin).
- **Rodin image-to-3D** (Blender MCP, MAIN_SITE free trial) from the 4-view turnaround ->
  ~23.3k-poly textured mesh, STRONG match: bulky insectoid biped, horned bladed crest, bark/root
  overgrowth breaking through armor at the legs, clawed hands, planted root feet, right-arm bio-cannon.
  Checkpoint: `design/concepts/bloom_rodin.glb`. New file: `design/blend/BloomCommander.blend`.
- **Rig:** scratchpad `rig_bloom.py` (adapted from `rig_mesh.py`). KEY DIFFERENCE vs Architect: NO
  torso-bar clip, NO AI-feet deletion/talon rebuild — Bloom's root/claw feet ARE the design, kept whole.
  Widened biped skeleton for Bloom's broad stance (W/H=0.73): shoulders x±0.42, arms x±0.52, legs on the
  DETECTED ankles (±0.40). Nearest-bone rigid skin + shoulder-inner->Spine reassign (0.30). LARGE-amplitude
  lumbering Walk + dead-still Idle. -> `design/rigged/bloom_rigged.glb`. Rest turnaround is clean from all
  4 angles (no missing chunks); walk shows minor lifted-leg joint-tearing = accepted AI-shell artifact (RTS zoom).
  Renders: `design/renders/bloom_rigrest_turn.png`, `bloom_rig_check.png`.
- **WIRED IN:** `assets/models/units/bloom_commander_hifi.glb`. AssetLoader bloom -> hifi path;
  FACTION_COMMANDER_SCALE bloom=38.5 (mesh 1.894u -> ~73u); FACTION_COMMANDER_YAW bloom=90 (Rodin mesh
  faces +Z like the Architect). Boots clean via Godot MCP (import + parse OK, no new errors).
- **STILL PENDING:** in-engine F3 hand-playtest — confirm scale/facing/walk read right at game zoom under V1
  bloom (FLIP yaw sign if it strides sideways). Optional: emissive sap-green glow (Rodin baked it into diffuse,
  no separate emission mask — same deferral as the Architect); joint-tearing retopo if it bugs at zoom.

## BLOOM V2 — WEB-RODIN QUAD EXPORT REPLACES V1 (2026-07-11, same day)
User bought a Hyper3D basic account (web UI, no API) and re-generated from the FIXED 4-view crops
(first web attempt modeled the whole reference sheet — 5 figures + parts — because the full sheet was
uploaded; second had a floating arm from a contaminated crop; crops now verified-clean + painted).
Settings per `design/docs/Rodin_Recipe_Sheets.md` (Sheet 1): T/A Pose ON, Symmetric, Faithful,
game-ready+character, Detail +3, Cfg 11, Step 50, Quad 18000 + baked normal, PBR 2K De-light ON Temp 7.
- Export folder `design/concepts/7183ef09-...`: `base_basic_pbr.glb` (35.2k tris, upright Z, feet@0,
  H=1.896) + **`texture_emissive.png` — the material prompt's "emissive sap-green" ask WORKED this time.**
- rig_bloom.py updated: (1) wires the separate emissive PNG into the material (Emission Color + strength
  2.5, Blender 5.x "Emission Color" rename guard); (2) detects ARM SPAN from geometry (A-pose flares wider:
  arm_reach 0.822 -> AX 0.674) instead of fixed fractions; (3) exports with `use_selection=True`.
- v2 rest turnaround clean; walk shows the usual accepted knee-stretch. Deployed over the same path
  `assets/models/units/bloom_commander_hifi.glb` — **AssetLoader unchanged** (H 1.896≈1.894 -> scale 38.5
  holds; same facing -> yaw +90 holds). Boot-verified clean. `design/blend/BloomCommander.blend` = final
  rigged v2 (model + BloomArmature + Idle/Walk).
- **GOTCHA logged:** phantom "Icosphere" objects in inspections came from the BLENDER STARTUP FILE
  (hidden objects survive select_all+delete — they are NOT in the GLBs; verified by parsing GLB JSON).
  Inspect scripts should purge via `bpy.data.objects.remove` (data-level), not selection delete.
- STILL PENDING: same F3 in-engine playtest (scale/facing/walk/emissive glow under V1 bloom).

## MESH COMMANDER HI-FI — RODIN BODY + PROCEDURAL SCORPION TENTACLES (2026-07-11)
The hybrid pipeline's first full run (per Sheet 1a): Rodin CANNOT reconstruct tentacles (fused
into arms / early termination / orphan segments / random tips), so: **body from Rodin, tentacles
procedural.** User ran Bang to Parts on the site (worked well) + exported OBJ + full texture set
(diffuse/metallic/roughness/normal/**emissive**) to `design/concepts/Mesh_Commander_Rodin/`.
- **Parts triage (live Blender MCP):** root.0.refined=body (12.8k verts), root.1/2=tentacle bundles
  (DELETED), root.3/4=HEAD HORNS (verified by hide-test render; joined back onto the head — Bang to
  Parts keeps world positions, so no repositioning). PBR material hand-wired from the texture files
  (OBJ ships no .mtl); emissive at strength 2.5. -> `design/blend/MeshCommander.blend`.
- **Tentacles + rig (headless `meshc_rig.py`):** 4 long scorpion chains (user choice) — upper pair
  11 segs arcing over the shoulders, lower pair 9 segs sweeping wide; tapered box segments, red
  emissive sensor nodes every 3rd seg, bladed cone tip + red eye; iterative curl (fixed side-axis
  rotation/seg) roots them at the back plate. Per-segment bones (Tent{k}.{i:02d}) parented into Spine;
  body rigid-skinned on the standard biped (detected ankles ±0.30, arm span 0.663); tentacle vgroups
  assigned per segment BEFORE join. Walk (LARGE gait + fast aggressive weave amp 0.22) and Idle
  (dead-still body + slow menacing weave amp 0.10) — weave = traveling wave, phase per segment+chain,
  amplitude growing tipward.
- **SPACE GOTCHA (cost one bad run):** the OBJ importer stores orientation on the OBJECT transform;
  raw `v.co` reads were lying down (H=0.714) -> skeleton/tentacles landed in nonsense space, and the
  blend saved with the bad join. Recovered by deleting Tent*-grouped verts (exact 13,046-vert body
  restored) + `transform_apply`. **Rig scripts must transform_apply FIRST** — guard now in meshc_rig.py.
- **DEPLOYED:** `assets/models/units/mesh_commander_hifi.glb` (10.3MB); AssetLoader mesh -> hifi,
  SCALE=38.6 (body 1.891u->73u), YAW=90 (faces +Z like the other Rodin commanders). Boot-verified clean.
- **Attachment fix (same day, user-spotted):** lower chains floated — fixed roots (y=0.08) sat off the
  real back surface (y≈0.02/-0.02 at that height). Now `back_at(x,z)` DERIVES each root from measured
  geometry (max-y in a neighborhood, inset 0.03) + an armored socket block (Spine-weighted) embeds each
  chain into the back plate. Rebuild verified: all 4 chains rooted. Rule: attach procedural appendages
  to MEASURED surfaces, never fixed coords.
- **Forward-pointing pass (same day, user direction):** tips must aim FORWARD (-Y facing). Chains now
  take a per-chain curl AXIS: upper pair = sagittal curl about world X (+14 deg/seg — rise up-back, curl
  forward OVER the shoulder, tips level-forward); lower pair = horizontal sweep about world Z (sign per
  side, -+16 deg/seg — wrap the flanks, tips forward at waist height like grasping arms). Classic Doc Ock
  posture confirmed in renders; redeployed + boot-verified.
- **STILL PENDING:** F2 in-engine playtest (scale/facing/walk/weave/emissive; flip yaw if sideways).
  All 3 ACUs now hi-fi. Bloom deformation polish (Corrective Smooth + weight blur) queued next per user.

## ARCHITECT V2 — RODIN QUAD REGENERATION REPLACES THE TRIAL HI-FI (2026-07-11)
Third commander through the web recipe (Sheet 1 + Architect deltas: Symmetric HIGH, anti-grid
negative-prompt guards, "seamless refined surfaces" material prompt). Export:
`design/concepts/Architect_Commander_Rodin/` (GLB + separate texture_emissive — cyan channels).
- Generation is a striking Seraphim machine: sleek chrome plates, thin cyan energy channels,
  cyclopean core (no head), 3 swept wing-blade fins, long blade-arms, DIGITIGRADE raptor legs
  with clean talon feet. NO grid patterns (negative prompt held). 37.3k tris, H=1.889, single body.
- Rigged via the generic `rig_bloom.py` (native feet KEPT — unlike the old trial mesh, no talon
  rebuild needed; Head bone owns the fin crown, static = correct for a machine). Emissive wired 2.5.
- **DEPLOYED over `architect_commander_hifi.glb`** (old hand-polished rig8 version backed up to
  `design/rigged/architect_hifi_v1_backup.glb`). AssetLoader architects SCALE 51 -> **38.6**
  (1.889u), YAW stays 90. Boot-verified clean. Blend: `design/blend/ArchitectCommander.blend`.
- STILL PENDING: F1 playtest (scale/facing/digitigrade walk read/emissive). The standard walk keys
  animate the reverse-knee legs with forward-knee rotations — acceptable at RTS zoom, revisit with
  the deformation-polish pass if it reads wrong in play.

## DEFORMATION-POLISH ROUND — ALL 3 COMMANDERS (2026-07-11, post-playtest)
User playtest PASSED for all three hi-fi commanders (import/scale/facing good); remaining complaint
was mesh deformation during animation. Fix shipped: **weight smoothing in the rig scripts** —
`vertex_group_smooth(BONE_DEFORM, factor 0.5, repeat 4, expand 0.4)` + `limit_total(4)` +
`normalize_all` right after the Armature modifier. Converts rigid 1.0/0.0 nearest-bone boundaries
into blended gradients (glTF carries 4 influences/vert) so joints bend instead of tearing.
- **KEY FACT: a Corrective Smooth modifier does NOT survive glTF export** (modifiers don't export;
  only weights do). Corrective Smooth stays a Blender-side hand-editing trick, never a pipeline fix.
- Result: Bloom's striding-leg smear GONE (biggest win — before/after in
  `design/renders/deform_polish_compare.png`); Architect/Mesh joints subtler improvement; Mesh
  tentacle chains bend organically instead of faceting.
- All three re-rigged + redeployed (bloom/architect_rigged_v3.glb; mesh re-run), blends synced,
  boot-verified clean. Old walkpose renders kept for comparison.
- **NEXT (user-queued): FULL ANIMATION SESSION for all units** — user will prompt explicitly.
  Items: digitigrade Architect walk, per-faction cadence, weave tuning, IK foot-lock, unit anims.

## GAMEPLAY (non-visual) — QUEUED
- **Commander gets too fast at high rank** ("supersonic" gliding while exploring). Cause: rank speed
  scaling compounds — `Commander.gd` `_current_move_speed = MOVE_BASE_SPEED * pow(1.0+SPEED_PER_RANK, rank)`
  (SPEED_PER_RANK=0.05, RANK_CAP=15 → ~2.08x at cap), on top of MOVE_BASE_SPEED 140 * Balance.MOVE_SCALE 0.6.
  Fix later: lower SPEED_PER_RANK, cap the multiplier, or use diminishing returns. Playtest-confirmed fine at low rank.

## OPEN / possible follow-ups (not yet requested)
- Per-faction walk cadence (WALK_SPEED_SCALE is currently shared).
- IK foot-lock to remove minor foot-slide during walk.
- Faction substrate materials on the GLBs (currently GLB Principled materials only).
- Literal torso-lead-before-legs turn tell (deeper anim-layer work).
