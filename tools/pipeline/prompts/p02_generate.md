# S2 — Generation (Hyper3D/Rodin via Blender MCP)

You are running Stage S2 of the Cycle Four model pipeline. Params: {{PARAMS}}

Precheck: `mcp__blender__get_scene_info` responds and `get_hyper3d_status` shows the
service enabled. If not, stop and tell me.

1. Clear/ignore unrelated scene objects (work in a fresh collection named the asset_id).
2. Call `generate_hyper3d_model_via_text` with `params.concept.prompt`
   (if `concept.reference_images` is non-empty, use `generate_hyper3d_model_via_images`
   instead).
3. Poll `poll_rodin_job_status` until complete; then `import_generated_asset`.
4. Log the attempt (timestamp, job id, prompt used) into `params.generation.attempts`.
5. Export the untouched import as `<wip_dir>/raw/<asset_id>_attempt<N>.glb`; save the
   .blend to `<wip_dir>/work/`.
6. Take `get_viewport_screenshot` from front, three-quarter, and side; save to
   `<wip_dir>/review/g2_<N>_{front,three_quarter,side}.png` and show them to me.
7. Gate G2 — wait for my verdict:
   - APPROVE → set `generation.approved_attempt`, `gates.g2_silhouette` = date.
     `PIPELINE_RESULT: PASS — silhouette approved`.
   - REJECT → ask what to change, adjust the prompt (do NOT overwrite the locked
     original; append variant to attempts), and rerun. After 3 rejected attempts,
     recommend the fallback (procedural `tools/blender_unit_gen.py` or reference
     images) and stop: `PIPELINE_RESULT: NEEDS_HUMAN — 3 strikes, choose fallback`.
