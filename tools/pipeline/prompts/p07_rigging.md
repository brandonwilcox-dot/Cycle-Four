# S7 — Rigging (Mode A only)

You are running Stage S7 of the Cycle Four model pipeline. Params: {{PARAMS}}
Skip entirely if `params.mode` is "B" or `params.rig.required` is false —
report `PIPELINE_RESULT: PASS — skipped (Mode B)`.

Via `execute_blender_code`:

1. If the Rodin import has an armature: validate — single root bone at origin,
   bone count ≤ `params.rig.max_bones`, no zero-length bones, hierarchy connected.
   Sane → keep it.
2. Else build a minimal armature: root (origin, ground level) → spine/torso → head;
   limbs only if the silhouette articulates them. Name bones descriptively
   (root/spine/head/arm_l...).
3. Orientation: model faces +X forward (matches AssetLoader YAW convention — check the
   existing `architect_commander_hifi.glb` yaw entry before deciding).
4. Parent mesh to armature WITHOUT weights yet (S8 does weights).
5. Screenshot armature in front + side; save .blend.
6. `PIPELINE_RESULT: PASS — bones=<n>, source=rodin|built`
