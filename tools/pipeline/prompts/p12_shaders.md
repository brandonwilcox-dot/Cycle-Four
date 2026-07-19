# S12 — Shader / material contract

You are running Stage S12 of the Cycle Four model pipeline. Params: {{PARAMS}}

The engine contract: runtime effects write **albedo and emission COLOR only** — never
emission energy or textures. `AssetLoader.prepare_unit_material` guarantees the emission
channel; tints are 0.28 (stock faction) / 0.55 (custom color).

In a Battle3D MCP run with the new asset live, verify each and screenshot evidence:

1. Faction tint reads on the model (subtle, textures preserved).
2. Custom color from the customizer drives a visibly stronger tint (0.55).
3. Hit-flash: damage flares emission and decays (~0.25s) — take damage, screenshot.
4. Mesh-tower hijack on a nearby enemy still tints cyan (regression check — enemy path
   untouched, but confirm no shared-material leak from the new asset).
5. Stealth/cloak alpha still applies if the unit can be cloaked.
6. Substrate/glow animation (SubstrateMaterials.tick) unaffected.

Any failure: fix ONLY within the contract (S5/S6 emissive channel, per-instance material
via prepare_unit_material) — never patch by swapping materials in Godot.
Set `gates.g6_contract` when all pass.
`PIPELINE_RESULT: PASS — tint/flash/hijack/stealth/substrate verified`
