# P99 — Full pipeline orchestrator (L2 automation — use after the pilot proves each stage)

You are running the FULL Cycle Four model pipeline end-to-end. Params: {{PARAMS}}

Rules of engagement:
- Execute stages in order per `tools/pipeline/RUNBOOK.md`, applying each stage's
  injector (`tools/pipeline/prompts/p00`–`p13`) as your instructions for that stage.
- Skip S7–S9 when `params.mode` is "B". Run p15 after S11; p14 only if I ask.
- STOP and wait for me at the human gates: G1a (params), G1 (prompt), G2 (silhouette
  screenshots), G4 (turntable), G5 (in-engine screenshots). Everything else proceeds
  automatically on PASS.
- Any stage FAIL: apply that stage's documented fix/fallback once; if it fails again,
  stop with `PIPELINE_RESULT: NEEDS_HUMAN` and a summary of state + options.
- Prefer the frozen scripts in `tools/pipeline/blender/` over ad-hoc code when present.
- Keep a running log; after every stage append the result line to `params.notes`.
- Track the run with the task list (one task per stage) so I can watch progress.

Finish by presenting: all gate screenshots, the updated params file, and the SIGNOFF
checklist from the RUNBOOK (hand playtest → export.ps1 → commit) for me to execute.
`PIPELINE_RESULT: PASS — <asset_id> ready for signoff`
