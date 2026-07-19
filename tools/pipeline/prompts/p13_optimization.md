# S13 — Optimization

You are running Stage S13 of the Cycle Four model pipeline. Params: {{PARAMS}}

1. Static budget check: `.glb` file size ≤ `params.budgets.file_mb`; final tris
   (`params.mesh.final_tris`) ≤ budget; textures ≤ `params.budgets.texture_px`.
2. Editor import check: confirm texture VRAM compression on the imported asset
   (default import is fine; flag if anything imported lossless at full size).
3. Perf run: Battle3D via MCP, drive toward the 48-unit live cap (late waves or
   dev-spawn), with the new asset on-field on player units. Compare frame pacing vs a
   run without it (or the standing baseline). Watch for the known [P1][MONITOR] hang class.
4. Over budget or perf regression → return to S3 (decimate harder) or S5 (smaller
   textures) with tightened params; note the round-trip in `params.notes`.
5. `PIPELINE_RESULT: PASS — <size>MB, <tris> tris, perf stable at cap`
