# 3D Model Pipeline — Workplan & Runbook System

**Goal:** a repeatable, parameter-driven pipeline that takes any faction unit design from
concept → in-game signoff, proven first on the **Architects Variation 1 (Seraphic)
baseline Commander**, then batch-applied to every faction/unit/variation.

**Companion docs (the operational half):**
- `tools/pipeline/RUNBOOK.md` — the per-asset, stage-by-stage procedure
- `tools/pipeline/prompts/` — one prompt injector per stage (paste into a Claude session)
- `tools/pipeline/params/` — the parameter file that makes a run repeatable

**Toolchain:** Blender MCP (`execute_blender_code`, Hyper3D/Rodin generation) →
GLTF `.glb` → Godot 4.6.1 (editor import → `AssetLoader.gd` / `Cosmetics.gd`) →
Godot MCP verification runs. See memory: `reference-cycle-four-asset-pipeline`.

---

## 1. Two output modes — decide per asset at intake

| | Mode A — Full-body unit model | Mode B — Cosmetic part |
|---|---|---|
| Destination | `assets/models/units/<faction>_<unit>_hifi.glb` | `assets/models/parts/<faction>/<unit>/<slot>/<part>.glb` |
| Wiring | `AssetLoader` dicts (`FACTION_MODELS`/`FACTION_COMMANDER_MODELS` + `SCALE` + `YAW`) | Auto-discovered by `Cosmetics.gd`; preset wiring in `Cosmetics.VARIATIONS[...].parts` |
| Rig/weights/anim stages | **Required** (Commander: Idle/Walk clips for `CommanderBodyRig`) | **Skipped** — parts are static; the gait pivot / rig animates them |
| Normalization | Per-faction `SCALE`/`YAW` in AssetLoader | ~1 Blender unit around origin (per `assets/models/parts/README.md`); scaled at attach |
| Proven today? | Yes — 3 hifi commanders + 3 drones shipped | **No — this is what the pilot proves** |

**Pilot = Mode B.** The Seraphic variation is a Cosmetics preset; its commander look is a
part set (signature piece = **torso**, which replaces the base body, plus optional
head/extra "fin"). Mode A stages (S7–S9) stay documented for new unit archetypes and
future full-body variation commanders, and fall back into play if torso-replacement
proves insufficient for the Commander silhouette.

## 2. Stage map (the 15 areas → pipeline stages)

| # | Stage | Your area | Tool / owner | Mode |
|---|---|---|---|---|
| S0 | Intake & params | — | Params JSON, human approves | Both |
| S1 | Concept lock | Concept art | Text prompt template w/ faction anchors (Seraphim / Cybran / Aeon+bio); **no 2D pass** — text feeds Rodin directly | Both |
| S2 | Generation | 3D modeling | `generate_hyper3d_model_via_text` → poll → `import_generated_asset` (fallback: `tools/blender_unit_gen.py` procedural) | Both |
| S3 | Mesh cleanup | Topology | Blender code: decimate to budget, non-manifold/loose-geo fix, tri report | Both |
| S4 | UV validate | UV mapping | Blender code: Rodin UVs kept if clean; Smart-UV repack fallback; overlap/texel check | Both |
| S5 | Texture validate | Texturing | Verify Rodin maps (diffuse/normal/MR/emissive), rebake on repack, resize to budget | Both |
| S6 | Material conform | Materials | Principled BSDF, **emission channel guaranteed** (Godot tint/hit-flash contract), export `.glb` | Both |
| S7 | Rigging | Rigging (bones) | Armature (Rodin rig kept if sane; else minimal chain) | A only |
| S8 | Weights | Weight painting | Auto-weights + stray-weight cleanup, ≤4 influences | A only |
| S9 | Animation | Animation | Idle/Walk clips, names exactly as `CommanderBodyRig` expects | A only |
| S10 | Physics check | Physics | Godot-side check: NO physics bodies imported (sim runs on the logical plane); attach/scale behavior only | Both |
| S11 | Engine wiring | Programming | Place `.glb`, **editor-import once** (gotcha!), AssetLoader entries or `VARIATIONS.parts` + `SLOT_ANCHORS` tune, MCP run | Both |
| S12 | Shader contract | Shaders | Verify tint (`prepare_unit_material` 0.28 / `CUSTOM_TINT_STRENGTH` 0.55), hit-flash, hijack cyan, stealth, substrate anim survive | Both |
| S13 | Optimization | Optimization | Budgets (below), late-wave perf run, texture compression | Both |
| S14 | Audio | Audio | **Parallel track, off critical path** — no MCP tooling; checklist + Godot wiring steps only | Both |
| S15 | UI/UX verify | UI/UX | FactionPreview customizer: part cycler shows it, attaches on stage, display name, RTS-zoom readability | Both |

**Budgets (from shipped assets):** units ~23k tris / ≤2 MB / 1K–2K textures; parts
target ≤12k tris / ≤1 MB (multiple parts stack on one unit); Commander full-body up to
~30k. Recorded per-asset in the params file — these are the "correct parameters" the
pipeline locks once proven.

## 3. Critical path & gates

```
S0 → S1 → S2 → S3 → S4 → S5 → S6 ─(Mode A: S7→S8→S9)→ S10 → S11 → S12 → S13 → SIGNOFF
                                                          S14 audio ∥ S15 UI/UX ──┘
```

Human approval gates (everything else automatable):

| Gate | After | Approve on | Fail → |
|---|---|---|---|
| G1 Concept | S1 | Locked prompt text vs faction anchor | Re-edit prompt |
| G2 Silhouette | S2 | Viewport screenshot, 3 angles | Regenerate (new seed/prompt tweak); 3 strikes → procedural fallback |
| G3 Mesh QA | S3–S5 | PASS/FAIL numbers report | Auto-fix pass, else regenerate |
| G4 Look-dev | S6 (+S9) | Blender turntable screenshots | Material/anim fix |
| G5 In-engine | S11 | FactionPreview + Battle3D screenshots via Godot MCP | Anchor/scale/yaw tune, re-export |
| G6 Contract | S12–S13 | Hit-flash/hijack/tint verified + perf clean | Shader-side fix (never touch energy/texture channels) |
| G7 Signoff | all | Hand playtest → `.\tools\export.ps1` → commit; params file marked `"proven": true` | — |

## 4. Folder structure

```
D:\AI\Cycle Four\
├─ planning\model-pipeline-workplan.md        ← this doc
├─ tools\pipeline\
│  ├─ RUNBOOK.md                              ← per-asset procedure
│  ├─ prompts\                                ← prompt injectors, one per stage (p00–p15, p99)
│  ├─ params\
│  │  ├─ _template.json                       ← copy per asset
│  │  └─ architects\commander_var1.json       ← pilot (Seraphic)
│  └─ blender\                                ← QA scripts (Level-1 automation; specs in RUNBOOK)
├─ art\pipeline\<faction>\<unit>\<variation>\ ← WIP, per asset
│  ├─ concept\   (locked prompt.txt, any refs)
│  ├─ raw\       (Rodin import, untouched)
│  ├─ work\      (.blend working files)
│  ├─ export\    (candidate .glb before placement)
│  └─ review\    (gate screenshots: g2_*.png, g4_*.png, g5_*.png)
└─ assets\models\
   ├─ units\                                  ← Mode A finals
   └─ parts\<faction>\<unit>\<slot>\          ← Mode B finals
```

Git: commit `concept\`, `review\`, params, and finals. Add `art/pipeline/**/raw/` and
`art/pipeline/**/work/` to `.gitignore` (regenerable from params; .blend files bloat the repo).

## 5. Automation ladder

- **L0 (now):** human pastes stage injectors from `tools/pipeline/prompts/` into a Claude
  session; Claude drives Blender/Godot MCP per the RUNBOOK. Every run reads/writes the
  asset's params JSON — that file IS the reproducibility.
- **L1 (during pilot):** freeze the Blender snippets that worked into
  `tools/pipeline/blender/qa_mesh.py`, `conform_material.py`, `export_glb.py` — run via
  `execute_blender_code`, each printing a one-line `PIPELINE_RESULT: {json}` for PASS/FAIL
  parsing. Same for a Godot verify recipe (import → run → grep "No loader found").
- **L2 (post-pilot):** `p99_full_run.md` orchestrator injector — one paste runs S0→S13
  end-to-end from a params file, pausing only at G2/G4/G5 for a screenshot yes/no.
- **L3 (scale-out):** batch p99 across a roster manifest (e.g. all Architects Variation 1
  parts) as an overnight/scheduled run; human reviews the gate screenshot contact sheet
  next morning.

## 6. Phased execution

**Phase P1 — Pilot (next session, Blender+Godot MCP live):** run the RUNBOOK on
`params/architects/commander_var1.json`. Deliverables: `seraphic_torso.glb` (+ optional
`seraphic_fin.glb` in `extra`) in the parts tree, `Cosmetics.VARIATIONS["architects"]`
Variation 1 `parts` dict filled, tuned `SLOT_ANCHORS`/`COSMETIC_PART_SCALE`, all gates
passed, params marked proven. Expect anchor/scale tuning to be the bulk of G5.

**Phase P2 — Harden:** fold pilot learnings back into RUNBOOK + injectors; write the L1
scripts from the exact code that ran; lock budget numbers.

**Phase P3 — Architects scale-out:** remaining Variation 1 slots for Commander, then
line/scout/artillery. First proof that params-only changes suffice.

**Phase P4 — Cross-faction:** Bloom (Verdant) + Mesh (Signal) Variation 1 commanders —
proves the faction anchor swap in S1 is the only creative delta. Then Variations 2–3
(Gilded/Obsidian, Sporefall/Mire, Ember/Ghost) as L2/L3 batches.

**Phase P5 — Mode A refresh (optional):** regenerate hifi commanders/drones through the
formal pipeline for consistency, exercising S7–S9.

## 7. Standing risks / rules

- **Editor-import gotcha:** CLI runs never import new `.glb`; always
  `godot --headless --path . --import` (or open editor) before any MCP verify run, and
  check the log for `No loader found` — don't trust the eyeball (procedural fallback looks similar).
- **Color contract:** cosmetics/tints write albedo + emission **color** only — never
  emission energy or textures — or hit-flash/hijack/substrate animation break.
- **Enemy readability:** pipeline outputs apply to PLAYER units only; enemy `Unit.gd` stays stock.
- **Rodin nondeterminism:** same prompt ≠ same mesh. The approved `.glb` in the parts/units
  tree is canon; params + prompt are for *new* assets, not byte-identical regeneration.
- **Exports:** every signoff ends with `.\tools\export.ps1` — the desktop exes don't auto-update.
