# Plasma Bastion (Architect T2, `architects_t2.tres`) — re-import 2026-07-29

Re-imported from the OBJ-pack download after playtest flagged the T2 as "splotchy" beside the T1.
Probe-verified; see `../Sentry_Spire/RODIN_RECIPE_Sentry_Spire.md` for the pipeline.

## Why it was re-imported rather than patched

The download carried a real `texture_emissive.png` — **98.8 % black, mean luminance 0.004**, i.e.
genuine authored emission, structurally the same as the Sentry Spire's (97.8 % black). But it
belonged to a **different generation** than the mesh in the project:

| | tris | bounds | normal md5 |
|---|---|---|---|
| Previously shipped | 31,282 (split from 39,417) | 1.888 × 1.450 × 1.778 | `9b7b1aa3` |
| **New pack** | **18,536** | 1.894 × 1.456 × **1.836** | `7226995f` |

Different Quad setting, different bounds, **different UV atlas**. Grafting the emissive onto the
old mesh would have smeared it — the hazard called out in the universal rules. The only correct
use was to re-import the whole model, which also cut the tri count nearly in half and brought the
T2 in line with the T1 (17,790) and T3 (19,856) instead of carrying almost double.

(The five `eca92e7f-…` folders are duplicate downloads of one pack — identical emissive and
normal md5s throughout. Only one is needed.)

## Result

| | before (colour-derived) | after (authored emissive) |
|---|---|---|
| Mask components | 476 → 122 after `min_area 140` | **47** |
| Speckles (<14 px) | 168 → 0 | 5 |
| Mid-tone share | 0 % | 0 % |
| Coverage | 1.59 % | 1.18 % |

Coverage is lower because it is the model's *actual* channel area rather than an inferred
approximation. Compare the Spire at 2.12 % / 81 components — same character, finally.

## Measurements (all re-derived; nothing carried over)

| Quantity | Value |
|---|---|
| Split seam | **y = 1.04** — maxR 0.203–0.246 vs 0.412 below / 0.540 above |
| Split | base 14,799 tris / crown 3,737 tris |
| Turret pivot | **ZERO** — collar x/z centre reads 0.000 on every dense row (n=40/47/86) |
| Scale / height norm | 40 / **1.456** |
| Muzzles | **(±0.343, 1.223, 0.634)** |
| Roughness | remapped p50 0.973 → 0.532 |

**Twin emitters arrived already separated** — x clusters −0.433..−0.252 and 0.252..0.432 with a
clean gap either side of centre — so unlike the Sentry Spire this pack needed no barrel surgery.

Light cluster re-derived by sampling the baked mask at each triangle's UV centroid and clustering
lit triangles in 3D; front core/portal from the centreline face profile (z 0.778 at y 0.4–0.5,
0.718 at y 0.1–0.2). Flank capacitors added as a symmetric pair at (±0.548, 0.567, 0.227).
Every previous position was invalid — the atlas AND the bounds both moved.

## Probe result

    crown mesh yes · muzzles 2, swinging with yaw · emissive surfaces 3 · omni lights 7

## Follow-ups

- ⚠ Exes not re-exported since this change.
- The Garrison Keep is still stranded on the same problem this solved. Its folder has only a
  `.glb`; pulling its **OBJ pack** would very likely yield an emissive and unblock it.
