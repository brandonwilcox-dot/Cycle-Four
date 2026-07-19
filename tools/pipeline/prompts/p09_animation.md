# S9 — Animation (Mode A only)

You are running Stage S9 of the Cycle Four model pipeline. Params: {{PARAMS}}
Skip if Mode B: `PIPELINE_RESULT: PASS — skipped (Mode B)`.

1. FIRST read `src/vfx/CommanderBodyRig.gd` `_try_build_gltf()` (and `AssetLoader.gd`)
   to confirm the exact clip names the engine looks up. Use those names —
   `params.rig.clip_names` is the expectation, the code is the truth.
2. Via `execute_blender_code`, author or adapt the clips (typically `Idle`, `Walk`):
   - Idle: subtle 2–4s loop (breath/hover bob per faction motion language:
     architects glide/hover, bloom heavy lope, mesh twitchy skitter).
   - Walk: stride loop matching the faction gait; root stays at origin
     (engine moves the node — no root motion).
3. Loop hygiene: first frame == last frame on every animated channel; each clip in its
   own Action, pushed to NLA or marked for glTF export as separate animations.
4. Playblast/screenshot key poses; show me (part of Gate G4).
5. Re-export the glb (S6 settings, animations ON) over `<wip_dir>/export/<output_file>`.
6. `PIPELINE_RESULT: PASS — clips=<names>, looped clean`
