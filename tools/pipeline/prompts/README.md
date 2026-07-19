# Prompt injectors

One file per pipeline stage. Usage: open a Claude session with Blender MCP + Godot MCP
live, paste the injector body, replace `{{PARAMS}}` with the asset's params path
(e.g. `tools/pipeline/params/architects/commander_var1.json`).

Every injector follows the same contract:
- Reads `{{PARAMS}}` and `tools/pipeline/RUNBOOK.md` (its stage section) first.
- Writes results back into `{{PARAMS}}` (attempts, measurements, gate outcomes).
- Ends with a one-line `PIPELINE_RESULT: PASS|FAIL|NEEDS_HUMAN — <summary>`.
- Never advances past a 🔴 human gate without explicit approval in-chat.

Order: p00 → p01 → p02 → p03 → p04 → p05 → p06 → (Mode A: p07 → p08 → p09) → p10 →
p11 → p12 → p13 → signoff. p14/p15 run parallel. `p99_full_run.md` chains everything (L2).
