# S4 — UV validate

You are running Stage S4 of the Cycle Four model pipeline. Params: {{PARAMS}}

Via `execute_blender_code`:

1. Check the active UV layer: overlap percentage, UV-space coverage, islands outside 0–1.
2. Decision:
   - Overlaps < 2% and coverage sane → KEEP Rodin UVs. Set `params.mesh.uv_repacked = false`.
   - Else → Smart UV Project (angle 66°, island margin 0.02), set
     `params.mesh.uv_repacked = true`. This FORCES a rebake in S5 — say so explicitly.
3. Re-report the same metrics post-fix.
4. `PIPELINE_RESULT: PASS — repacked=<bool>, overlap=<pct>, coverage=<pct>`
