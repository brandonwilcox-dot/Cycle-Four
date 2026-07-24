# Cycle Four World Lighting Review - 2026-07-22

## Outcome

Cycle Four now has one coherent Forward+ lighting stack targeted at the current development
PC and 1920x1080 internal viewport. Asset emission is selective and motivated; global
exposure remains centralized. The review covered world lights, biome changes, shadows, glow,
SSAO, SSIL, SDFGI, volumetric and exponential fog, tonemapping, imported emissive materials,
structure and commander lights, gameplay telegraphs, particles, and renderer project settings.

## Hardware and Renderer Target

- GPU: NVIDIA GeForce GTX 1080 Ti, 11 GB VRAM.
- CPU: Intel Core i7-8700K, 6 cores / 12 threads.
- Memory: 32 GB.
- Internal viewport: 1920x1080.
- Renderer: Godot 4.6.1 Forward+.

This system supports the high profile below. It does not have hardware ray tracing, so the
stack uses SDFGI, SSIL, SSAO, clustered direct lights, and shadow maps.

## Findings

### Critical - SSAO and SSIL were fading before the tactical camera

Godot defaults both effects to fade from 50 to 300 world units. Cycle Four uses pixel-scale
world units and a tactical camera distance around 1600. The effects were therefore effectively
absent in normal gameplay even though they were enabled in `BattleAtmosphere.gd`.

Resolution: SSAO now fades from 1600 to 3400; SSIL from 1600 to 3600. Both remain active
through tactical play and naturally disappear before galaxy zoom.

### High - No explicit image-quality profile

The project used renderer defaults: no 3D MSAA, no screen-space AA, no debanding, default
anisotropic filtering, and half-resolution screen-space lighting. This left silhouettes,
thin emissive seams, fog gradients, and oblique ground textures below the hardware target.

Resolution: 2x MSAA plus SMAA, debanding, 16x anisotropic filtering, high full-resolution
SSAO/SSIL, bicubic glow upscale, and filtered 96-slice-width volumetrics.

### High - Per-object broad lights changed world exposure

The old FOB used a 520-unit omni and all commanders used a 190-unit mid-hull wash. Those
lights flattened PBR contrast and made scene brightness depend on which object was present.

Resolution: Architect FOB, garrison, and commander use compact outward-offset light clusters.
Bloom and Mesh retain their existing commander reactor light until they receive their own
faction-specific authored emission pass.

### High - Emission behavior was inconsistent

Additive material emission could brighten black mask regions, while thin authored masks could
average below the HDR glow threshold at RTS-distance mip levels.

Resolution: authored asset emission is multiply-gated. The garrison and FOB use reinforced
mip-safe masks; the commander retains its per-part authored maps at a higher mobile-asset
energy. Per-instance duplication protects shared GLB resources and animation/gameplay states.

### Medium - Shadow quality did not match the huge world scale

A single 4096 directional shadow atlas covered a 6000-unit distance, and the sun had a hard
zero-angular-size shadow. Close structure shadows therefore spent too little resolution and
lacked a natural penumbra.

Resolution: an 8192 atlas, explicit four cascades with near-biased splits, blended transitions,
and a 0.35-degree sun angular size. Only the key casts shadows.

### Medium - Dynamic light cost lacked bounds

Multiple six-light structure clusters remain well below Forward+ clustered limits, but future
garrisons and towers could accumulate and continue rendering at galaxy zoom.

Resolution: all authored clusters fade after 2200 units and cull by 3200. Static structures
use static GI bake mode; the moving/pulsing commander uses dynamic mode. Local lights do not
inject into volumetric fog and use reduced indirect energy.

## High Presentation Profile

### Antialiasing and texture clarity

- 3D MSAA: 2x.
- Screen-space AA: SMAA.
- TAA: disabled to avoid ghosting on skinned units, particles, and dense moving foliage.
- Debanding: enabled for dark sky and fog gradients.
- Anisotropic filtering: 16x for oblique terrain and authored PBR assets.

### World lighting

- Key: warm 1.5 energy, one shadow-casting directional light.
- Fill: cool 0.42 energy, no shadows, low specular/indirect/fog contribution.
- Ambient: 0.48 baseline, biome-colored.
- AgX tonemapping with the existing restrained split-tone LUT.
- Glow: HDR threshold 1.0; selective emission must cross it without body-wide bloom.

### Indirect light and contact

- SSAO: high quality, full resolution, 24-unit radius, 1.5 intensity.
- SSIL: high quality, full resolution, 96-unit radius, 1.6 intensity.
- SDFGI: full resolution, four cascades, 24-unit minimum cell, 16 rays per convergence frame,
  30-frame convergence, dynamic-light updates distributed over eight frames.
- SDFGI Y scale: 50 percent, appropriate to the predominantly planar battlefield and useful
  for vertical detail around thin ground/structure transitions.

### Atmosphere and shadows

- Directional shadow atlas: 8192, high soft-shadow filtering, four blended cascades.
- Volumetric fog: filtered 96 base resolution by 64 depth slices, 4000-unit reach.
- Exponential and volumetric fog both fade to zero during galaxy zoom.

## Performance Fallback Order

Keep selective emissive textures and compact direct lights intact; they are the faction
readability baseline. If a representative late-wave battle cannot hold the target frame rate:

1. Enable half-resolution SDFGI.
2. Return SSIL to half resolution.
3. Return SSAO to half resolution.
4. Reduce volumetric fog size from 96 to 64.
5. Reduce directional shadow atlas from 8192 to 4096.
6. Reduce SDFGI probe-ray setting from 2 (16 rays) to 1 (8 rays).
7. Disable SDFGI only as the final large fallback; keep SSIL and local direct lights.

Do not reduce global exposure or add per-object floodlights as a performance workaround.

## Acceptance Checks

- Compare FOB, garrison, and commander beside the approved concepts.
- Inspect close, tactical, and RTS distances on lit and shadow sides.
- Confirm cyan maps remain selective and local lights touch nearby armor/ground.
- Confirm galaxy zoom contains no lingering local structure lights or tactical fog.
- Test a representative late wave with dense flora, maximum common unit count, projectiles,
  several garrisons, and the commander moving/charging.
- Record GPU frame time, CPU frame time, draw calls, visible lights, and FPS before lowering
  any quality setting.
- Re-test Bloom and Mesh scenes: central world changes apply to them even though their
  authored commander/structure recipes remain future faction-specific passes.

## Official Godot References

- Environment and post-processing:
  https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html
- 3D lights and clustered limits:
  https://docs.godotengine.org/en/4.6/tutorials/3d/lights_and_shadows.html
- Project rendering settings:
  https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html
- Directional light cascades:
  https://docs.godotengine.org/en/4.6/classes/class_directionallight3d.html
- Rendering quality runtime controls:
  https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html
