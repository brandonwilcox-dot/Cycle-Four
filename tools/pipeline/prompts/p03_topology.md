# S3 — Topology

You are running Stage S3 of the Cycle Four model pipeline. Params: {{PARAMS}}
Work on the approved S2 mesh in the open Blender scene.

Via `mcp__blender__execute_blender_code` (use `tools/pipeline/blender/qa_mesh.py` if it
exists; otherwise write equivalent code and propose saving it there afterward):

1. Report: object count, tri count per object, material count, non-manifold edge count,
   loose vert/edge count.
2. Fix: join into one mesh; delete loose geometry; merge by distance (0.0001);
   fix non-manifold where safe; recalculate normals outside.
3. If tris > `params.budgets.tris`: Decimate (collapse) to the budget, preserving UV
   seams where possible. Re-report.
4. Apply all transforms; set origin to base-center (Mode A) or geometric center
   (Mode B — the anchor positions it).
5. Save .blend; write `params.mesh.final_tris`.
6. `PIPELINE_RESULT: PASS|FAIL — tris=<n>/<budget>, nonmanifold=<n>, objects=1`
   (FAIL if any check can't be brought within limits — then summarize options: retopo,
   higher budget, or regenerate).
