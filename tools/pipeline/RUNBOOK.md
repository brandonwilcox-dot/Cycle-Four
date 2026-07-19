# Model Pipeline RUNBOOK — one asset, concept → signoff

Repeatable procedure for producing one unit model (Mode A) or one cosmetic part
(Mode B). Strategy/phasing: `planning/model-pipeline-workplan.md`. Stage prompts:
`tools/pipeline/prompts/` (paste the matching injector into a Claude session with the
Blender + Godot MCPs live; each injector reads the same params file).

**Preconditions (every run):**
1. Blender open with the MCP addon listening (localhost:9876); `mcp__blender__get_scene_info` responds.
2. Godot MCP responds (`get_godot_version`).
3. Params file exists: `tools/pipeline/params/<faction>/<asset>.json` (copy `_template.json`).
4. WIP folders exist: `art/pipeline/<faction>/<unit>/<variation>/{concept,raw,work,export,review}`.

Legend: 🟢 automatable now · 🟡 automatable after L1 scripts · 🔴 human gate.

---

## S0 — Intake 🔴 (inject `p00_intake.md`)
Fill the params file: mode (A/B), faction, unit, variation, slot (B), budgets, faction
anchor, silhouette notes. **Gate G1a:** human confirms the params before anything runs.
- Exit: params committed; folders created.

## S1 — Concept lock 🔴 (inject `p01_concept.md`)
Compose the Rodin text prompt from the template: faction anchor + unit role + variation
adjectives + negative terms. No 2D art pass — text feeds Rodin directly.
- Write final prompt to `concept/prompt.txt` AND `params.concept.prompt`.
- **Gate G1:** human approves the prompt text.

## S2 — Generation 🟢→🔴 (inject `p02_generate.md`)
1. `generate_hyper3d_model_via_text` with the locked prompt.
2. Poll `poll_rodin_job_status` until done; `import_generated_asset` into Blender.
3. Save untouched copy: export `.glb` → `raw/`; save `work/<asset>_v1.blend`.
4. `get_viewport_screenshot` front / ¾ / side → `review/g2_*.png`.
- **Gate G2:** human approves silhouette. Reject → tweak prompt (log every attempt in
  `params.generation.attempts`), max 3, then fall back to procedural
  (`tools/blender_unit_gen.py`) or manual sculpt.

## S3 — Topology 🟡 (inject `p03_topology.md`)
Via `execute_blender_code`: report tris/objects/materials; join stray objects; delete
loose geometry; fix non-manifold; **Decimate (collapse)** to `params.budgets.tris`;
apply transforms, origin to base-center. Print `PIPELINE_RESULT` JSON.
- Exit: tris ≤ budget, 1 object, 0 non-manifold edges.

## S4 — UV 🟡 (inject `p04_uv.md`)
Keep Rodin UVs if decimation kept them clean (overlap check < 2%); else Smart UV
Project (margin 0.02) — **which forces S5 rebake**. Report UV area coverage + overlaps.

## S5 — Texturing 🟡 (inject `p05_texture.md`)
Verify the four maps exist and are bound: diffuse / normal / metallic-roughness /
emissive. If repacked in S4: bake old→new UVs. Resize to `params.budgets.texture_px`.
Missing emissive → create a black emissive so the Godot emission channel exists.

## S6 — Materials + export 🟡 (inject `p06_materials.md`)
One Principled BSDF; maps in correct sockets (Non-Color on normal/MR); metallic/rough
values sane for faction (Architects polished ~0.2 rough / others per anchor). Export:
- **Mode B:** normalize ~1 Blender unit around origin (parts README rule), then glTF
  export → `export/<part_name>.glb` (name = display name: `seraphic_torso.glb` → "Seraphic Torso").
- **Mode A:** keep authored scale (AssetLoader `SCALE` handles it) → `export/<faction>_<unit>_hifi.glb`.
- Export settings: glTF Binary, +Y up, apply modifiers, tangents ON, no cameras/lights/physics.
- **Gate G4:** turntable screenshots → `review/g4_*.png`; human approves look.

## S7 — Rigging (Mode A only) 🟡 (inject `p07_rigging.md`)
Keep Rodin armature if bone count sane (≤60) and hierarchy rooted; else build minimal
chain (root → torso → head; limbs as needed). Root at origin, +X forward to match
AssetLoader `YAW` convention.

## S8 — Weights (Mode A only) 🟡 (inject `p08_weights.md`)
Automatic weights → normalize, limit 4 influences, clean stray islands (weight < 0.05
prune). Pose-test extremes via code; screenshot deformation.

## S9 — Animation (Mode A only) 🔴 (inject `p09_animation.md`)
Author/keep `Idle` and `Walk` clips — **names must match what `CommanderBodyRig`
looks up** (check `_try_build_gltf()` before authoring; drives clips off `is_moving()`).
Loop-clean first/last frames. Gate G4 includes anim playblast.

## S10 — Physics check 🟢 (inject `p10_physics.md`)
Cycle Four's sim is on a logical plane — **models must import zero physics**. Confirm
export has no rigid bodies/colliders/constraints; part pivots are where the anchor
expects. This stage is a check, not authoring.

## S11 — Engine wiring 🟢→🔴 (inject `p11_programming.md`)
1. Copy `.glb` from `export/` to destination (parts tree or `assets/models/units/`).
2. **`godot --headless --path . --import`** (the gotcha — CLI runs don't import).
3. Wire:
   - Mode B: nothing to code for discovery; fill `Cosmetics.VARIATIONS[faction][var].parts`
     with the part name; tune `SLOT_ANCHORS` offset + `COSMETIC_PART_SCALE` if placement is off.
   - Mode A: add/adjust `AssetLoader` `FACTION_MODELS`/`FACTION_COMMANDER_MODELS`,
     `*_SCALE`, `*_YAW`.
4. `mcp__godot__run_project` FactionPreview → debug log MUST NOT contain "No loader found";
   part cycler shows the part; screenshot → `review/g5_preview.png`.
5. Run Battle3D; screenshot unit in combat → `review/g5_battle.png`.
- **Gate G5:** human approves placement/scale in both screenshots.

## S12 — Shader contract 🟢 (inject `p12_shaders.md`)
In a Battle3D run verify, on the new model: faction/custom tint reads (0.28 stock /
0.55 custom); hit-flash flares on damage; hijacked enemy still tints cyan; stealth alpha
works; substrate emission animation unaffected. Rule: fixes touch albedo/emission-color
only — never energy/texture.

## S13 — Optimization 🟢 (inject `p13_optimization.md`)
File size ≤ budget; late-wave perf run (48-unit cap) — frame time stable vs baseline;
texture import compression (VRAM) confirmed in editor. Over budget → return to S3/S5
with tightened params.

## S14 — Audio ∥ (inject `p14_audio.md`) — parallel, non-blocking
Manual/external track: source or record fire/death/move stingers; place under
`assets/audio/units/`; wire AudioStreamPlayer3D hooks when the audio pass lands.
Does NOT block model signoff.

## S15 — UI/UX verify ∥ (inject `p15_uiux.md`)
FactionPreview: display name correct, cycler order sane, variation preset applies the
part, Reset This Unit works, choice persists across restart (`user://cosmetics.json`).
Readability: at RTS zoom the unit reads as its faction + role in <1s; enemy stock units
still distinguishable.

## SIGNOFF — Gate G7 🔴
1. Hand playtest per the customizer checklist (CLAUDE.md session 2026-07-18).
2. `.\tools\export.ps1` (both exes).
3. Commit: final `.glb`, params (set `"proven": true`, record final budgets/anchors),
   `review/` screenshots, any `Cosmetics.gd`/`AssetLoader.gd` edits.
4. Update the variation's entry in `Cosmetics.VARIATIONS` docs/comments if slots remain.

---

## Failure playbook

| Symptom | Cause | Fix |
|---|---|---|
| "No loader found for resource ...glb" | Skipped editor import | S11 step 2; re-run |
| Part invisible in preview | Wrong folder path/casing | Check `assets/models/parts/<faction>/<unit>/<slot>/`; re-import |
| Part floats/clips/wrong size | Anchor/scale | Tune `SLOT_ANCHORS` / `COSMETIC_PART_SCALE`; re-run S11.4 |
| Model black/no tint response | No emission channel or texture-locked material | S5 emissive fix; `prepare_unit_material` path |
| Hit-flash dead | Material replaced instead of configured | Re-run S6; never new material in Godot, configure existing |
| Rodin mesh garbage ×3 | Prompt too abstract | Procedural fallback (`blender_unit_gen.py`) or supply reference images → `generate_hyper3d_model_via_images` |
| MCP class-cache errors after new script | New `class_name` | `godot --headless --path . --import` once |

## L1 automation targets (write during pilot, from the code that actually ran)
- `blender/qa_mesh.py` — S3+S4 checks/fixes, prints `PIPELINE_RESULT`
- `blender/conform_material.py` — S5+S6 material/map conformance
- `blender/export_glb.py` — S6 export with locked settings, mode-aware normalization
- `blender/turntable.py` — G2/G4 screenshot set
- Godot verify recipe — import → run → log-grep, single injector block
