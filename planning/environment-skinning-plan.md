# Environment Skinning Plan (2026-07-19)

User directive: shift from unit modeling (Cathedral commander shipped; further part
generation is a long-running user task) to environment detail: lighting, terrain,
weather, flora & fauna, obstacles, ruins. All four areas approved; sequence below.
Readability rules (core/22) hold everywhere: paths/claims stay legible, fog tiers
respected (no props visible in unexplored fog), quiet-over-loud.

## Phases

- **E1 — Terrain + Lighting foundation (FIRST)**
  - Biome palettes: territory seed → 1 of 4 biomes (Verdant / Ashen / Crystal / Rust);
    ground tint, water level+color, relief amplitude, sparkle — new ground-shader
    uniforms driven from MapGrid. Atmosphere (key light color/energy, ambient, fog
    color) grades per biome via `BattleAtmosphere.set_biome`.
  - Close-up detail noise (fades in with the grid), shoreline foam band on water edges.
  - Rock outcrops: `src/vfx/TerrainProps.gd` MultiMesh scatter on high-ground cells,
    seeded per territory, fog-gated (zero-scale when unrevealed), never on
    paths/spawns/base/claimed.
  - Volumetric fog + light shafts (conservative density; perf dial documented).
- **E2 — Obstacles & Ruins**: seeded prop placement tiers (blocking obstacles need F1
  gameplay-terrain decision); Ancient ruin fragments with canon low-albedo treatment;
  Rodin pipeline prop sets (static GLBs, no rigging) — user can generate "Cathedral
  ruins" style packs when convenient.
- **E3 — Flora + Weather**: MultiMesh biome growth (crystal spires / spore pods /
  grass analogs) with wind sway; cloud shadows (projected noise on the key light via
  a scrolling cookie or ground-shader term), gusts syncing flora, distant lightning;
  per-territory weather from seed.
- **E4 — Fauna**: ambient critter flocks (MultiMesh), scatter from units, cosmetic only.

## Status

- E1: SHIPPED 2026-07-19. Tuning dials: `MapGrid._BIOMES`, `BattleAtmosphere.BIOME_LIGHT`,
  `TerrainProps.COUNT/SIZE`. ⚠ Volumetric density is extinction-per-unit — keep ~0.0001.
- E1b (photoreal ground): SHIPPED 2026-07-19 — 3-layer PolyHaven PBR splat
  (soil/rock/grass by height+slope), normal/roughness maps, anti-tiling, grid toggle
  via `settings.cfg [display] show_grid` (`grid_strength` uniform).
  TODO: expose the checkbox in Title-screen Options.
- E3 flora: PARTIALLY SHIPPED early (ChatGPT, commit f3da693) — grass/bush/tree
  MultiMesh layers per biome (`FLORA_STYLES`), wind shader `biome_flora.gdshader`,
  fog-gated; props persist on claimed ground. Weather portion still pending.
- E2 (obstacles/ruins) + E4 (fauna): pending. Prop collision/blocking rides on the F1
  gameplay-terrain decision (Commander currently clips through props — user flagged).
