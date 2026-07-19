# S10 — Physics check

You are running Stage S10 of the Cycle Four model pipeline. Params: {{PARAMS}}

Cycle Four's sim runs on a logical plane — combat/movement/collision are code-side
(radii, groups). Models must contribute ZERO physics. This stage verifies, not authors.

1. Via `execute_blender_code`: confirm the export object has no rigid body, collision
   modifier, constraint, or force field; no hidden extra objects will export.
2. Inspect the exported `.glb` (gltf JSON via python) — confirm no extensions or nodes
   implying physics/lights/cameras.
3. Pivot check: Mode B — origin at geometric center (anchor positions it);
   Mode A — origin at base-center ground level.
4. `PIPELINE_RESULT: PASS — physics-free, pivot ok`
