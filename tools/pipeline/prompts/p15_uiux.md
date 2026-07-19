# S15 — UI/UX verify (parallel; converges before signoff)

You are running Stage S15 of the Cycle Four model pipeline. Params: {{PARAMS}}

In a FactionPreview (customizer) MCP run + one Battle3D run:

1. Display name renders correctly from the filename (`seraphic_torso.glb` → "Seraphic Torso").
2. Part cycler: the part appears, ◀ ▶ order is sane, "Stock" still selectable.
3. Variation preset: applying the variation (e.g. Seraphic) equips this part + its colors.
4. Reset This Unit clears it; restart the game → selection persisted
   (`user://cosmetics.json` survives).
5. Readability (screenshot judgments, RTS zoom in Battle3D):
   - Unit still reads as its faction + role in under a second.
   - HP bar / selection ring / status effects not occluded by the part.
   - Enemy stock units remain instantly distinguishable from customized player units.
6. Report any misses with screenshots; UI-side fixes route to FactionPreview.gd,
   readability fixes route back to S6 (silhouette/value contrast).
`PIPELINE_RESULT: PASS — customizer + readability verified`
