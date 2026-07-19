# S6 — Material conform + export

You are running Stage S6 of the Cycle Four model pipeline. Params: {{PARAMS}}

Via `execute_blender_code`:

1. Collapse to ONE material with one Principled BSDF. Sockets: diffuse→Base Color,
   normal (Non-Color)→Normal Map node→Normal, MR (Non-Color)→Metallic+Roughness via
   Separate Color, emissive→Emission Color (strength 1.0).
2. Faction feel check (report values, don't over-art): architects lean polished
   (roughness ~0.15–0.3, some metallic); bloom matte organic (~0.8+); mesh dark
   conductive (metallic ~0.6).
3. Normalization:
   - Mode B: uniform-scale the object so its largest dimension ≈ 1.0 Blender unit,
     centered on origin (parts README rule). Apply scale.
   - Mode A: keep authored scale; note the height in `params` notes for AssetLoader SCALE.
4. Export glTF Binary to `<wip_dir>/export/<output_file>`: selected object only, +Y up,
   apply modifiers, tangents ON, no cameras/lights/animations (Mode B) — Mode A keeps
   animations/armature.
5. Turntable: 4 viewport screenshots at 90° steps → `<wip_dir>/review/g4_*.png`; show me.
6. Gate G4 — on my approval set `gates.g4_lookdev`; on rejection take my notes and fix.
   `PIPELINE_RESULT: PASS — exported <output_file>, <size> MB`
