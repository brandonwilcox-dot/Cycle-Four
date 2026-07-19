# S14 — Audio (parallel track — does NOT block model signoff)

You are running Stage S14 of the Cycle Four model pipeline. Params: {{PARAMS}}

No audio MCP tooling exists in the stack; this is a checklist + wiring track.

1. Define the cue sheet for this unit/part: fire, impact, death, movement loop,
   (Commander: ability casts). One line each: feel, length, faction voice
   (architects = clean/tonal/chime-like; bloom = wet/organic/chitinous;
   mesh = glitchy/electric/static).
2. Sourcing is manual/external (record, library, or a future audio tool). Files land in
   `assets/audio/units/<faction>/<unit>/` as .ogg, loudness-normalized ≈ −16 LUFS.
3. Godot wiring (when files exist): AudioStreamPlayer3D on the entity, hooked to the
   existing events (attack in `_try_attack`, death in `_die`, movement off `is_moving()`).
   Follow "quiet over loud" — the board is the subject.
4. Track status in `params.notes` under "audio:". This stage never gates G7.
`PIPELINE_RESULT: PASS — cue sheet written, sourcing pending`
