# S5 — Texture validate

You are running Stage S5 of the Cycle Four model pipeline. Params: {{PARAMS}}

Via `execute_blender_code`:

1. Inventory bound image textures: diffuse, normal, metallic-roughness, emissive —
   report resolution and color space for each.
2. If `params.mesh.uv_repacked` is true: bake all maps from the original UVs/materials
   to the new layout at `params.budgets.texture_px`; set `params.mesh.rebaked = true`.
3. Resize any map larger than `params.budgets.texture_px` (image.scale) — normals last,
   check for banding in a viewport screenshot.
4. If NO emissive map exists: create a black `texture_px²` emissive and bind it — Godot's
   tint/hit-flash contract requires the emission channel to exist.
5. Mode B reminder: keep albedo near-neutral (white/chrome/grey family) — runtime color
   comes from the Cosmetics channels.
6. Pack/save images into the .blend or alongside it; save the .blend.
7. `PIPELINE_RESULT: PASS — maps=D/N/MR/E @<px>, rebaked=<bool>`
