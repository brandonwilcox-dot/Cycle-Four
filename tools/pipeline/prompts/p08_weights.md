# S8 — Weight painting (Mode A only)

You are running Stage S8 of the Cycle Four model pipeline. Params: {{PARAMS}}
Skip if Mode B: `PIPELINE_RESULT: PASS — skipped (Mode B)`.

Via `execute_blender_code`:

1. Automatic weights (parent with automatic weights, or re-run if S7 parented empty).
2. Cleanup: normalize all; limit total influences to 4; remove weights < 0.05;
   check for verts with zero total weight (report count — must be 0).
3. Pose test: rotate each major bone ±30° via code, screenshot the worst-case
   deformation front + side, restore rest pose.
4. Show me the screenshots; fix candy-wrapper/stray-island issues I flag by targeted
   weight edits (gradient smooth on the affected vertex groups).
5. Save .blend.
6. `PIPELINE_RESULT: PASS — zero-weight verts=0, max influences=4`
