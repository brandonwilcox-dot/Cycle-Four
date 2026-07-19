# S0 — Intake

You are running Stage S0 (Intake) of the Cycle Four model pipeline
(`tools/pipeline/RUNBOOK.md`).

Asset params file: {{PARAMS}}

1. If the params file doesn't exist, copy `tools/pipeline/params/_template.json` to that
   path and fill it from what I tell you next: mode (A full-body / B cosmetic part),
   faction, unit, variation, slot, display name, budgets. Ask me only for fields you
   cannot infer.
2. Derive `output_file`, `destination`, and `wip_dir` from the naming rules in the
   template and `assets/models/parts/README.md`.
3. Create the WIP folders: `<wip_dir>/{concept,raw,work,export,review}`.
4. Show me the completed params for approval (Gate G1a). Do not proceed to S1 until I
   approve.
5. On approval, set no gate fields yet; report `PIPELINE_RESULT: PASS — intake complete`.
