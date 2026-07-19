# S11 — Engine wiring (Godot)

You are running Stage S11 of the Cycle Four model pipeline. Params: {{PARAMS}}
Read RUNBOOK S11 and the failure playbook first.

1. Copy `<wip_dir>/export/<output_file>` to `params.destination`.
2. **Import before any run** (the standing gotcha): run
   `godot --headless --path . --import` from the project root (or
   `mcp__godot__launch_editor` once). CLI runs do NOT import new assets.
3. Wire per mode:
   - **Mode B:** discovery is automatic from the folder path — verify the path segments
     exactly match `assets/models/parts/<faction>/<unit>/<slot>/`. Then edit
     `src/core/cosmetics/Cosmetics.gd`: fill the `parts` dict per
     `params.engine.variations_parts_entry`.
   - **Mode A:** edit `src/core/AssetLoader.gd` — add/adjust the
     `FACTION_MODELS`/`FACTION_COMMANDER_MODELS` path plus `SCALE` and `YAW` entries.
4. Verify in FactionPreview: `mcp__godot__run_project`, then `get_debug_output` —
   FAIL immediately if the log contains `No loader found`. Confirm the part appears in
   the cycler / the model renders. Screenshot → `<wip_dir>/review/g5_preview.png`.
5. Verify in Battle3D: run, spawn/observe the unit wearing the part (or the model),
   screenshot → `<wip_dir>/review/g5_battle.png`. Zero SCRIPT ERRORs required.
6. Show me both screenshots (Gate G5). If placement/scale is off: tune
   `Cosmetics.SLOT_ANCHORS` / `COSMETIC_PART_SCALE` (Mode B) or SCALE/YAW (Mode A),
   record the final values in `params.engine`, and repeat from step 4.
7. On approval set `gates.g5_in_engine`.
   `PIPELINE_RESULT: PASS — wired, anchors=<values>`
