# Architect Defensive Structure Concepts

Orthographic concept art for the Architect defensive and land-production structure line.

## Deliverables

Each structure folder contains:

- one `1536x1024` six-cell sheet
- five `508x508` Rodin-ready crops: `front`, `back`, `left`, `right`, and `top`

Sheet order:

| Front | Back | Top |
|---|---|---|
| Left | Right | Blank |

Upload the separate face crops to Rodin rather than the full sheet.

## Concept set

- **Sentry Spire (T1):** light nearest-threat auto-rifle tower and Drone source. Tall, economical silhouette with a sealed Drone bay and compact twin-barrel crown.
- **Plasma Bastion (T2):** heavy anti-armor plasma tower and Auger-Walker source. Squat armored bastion with capacitor chambers, a bright plasma core, and twin heavy emitters.
- **Siege Foundry (T3):** long-range anti-structure battery and Compiler source. Monumental industrial base with fabrication vaults, deployment gate, and long twin siege cannons. The accepted sheet includes a correction pass that makes the turret direction agree across all five views.
- **Garrison Keep:** standard land-unit production and tether node. A fortified octagonal keep whose nested energy bands and central crystalline core express the Architect compound timer. It has no large turret.

## Codex basis

- `docs/core/17_units-maps-buildings.md`: tower names, target roles, produced units, and cooldown tiers
- `docs/codex/Units_Land.md`: Garrisons as the unit source; wide stable Architect tether; efficiency compounds while the node remains undamaged
- `design/docs/Architect_Commander_Model_Reference.md`: polished silver-white plate, charcoal recesses, thin dense cyan channels, crystalline precision, pristine finish
- `design/docs/Rodin_Recipe_Sheets.md`: separate colored face crops, connected geometry, plain background, and post-generation turret separation guidance

## Final prompt set

Common specification:

> Create one original Architect defensive or production building using disciplined technological refinement, crystalline-lattice motifs, swept fins, faceted hexagonal forms, smooth transitions, high symmetry, minimal seams, and broad connected Rodin-friendly geometry. Use pristine polished silver-white armor, charcoal/dark-gunmetal recesses, near-mirror highlights, and dense very thin cyan-blue emissive channels. Render the exact same object as strict FRONT, BACK, TOP, LEFT, and RIGHT orthographic views on a plain white six-cell sheet. Use zero perspective, no environment, no text, no people, no floating parts, no thin cables or antennae, no grime, and no copied franchise geometry.

Asset-specific additions:

- **Sentry Spire:** compact hexagonal base, slender spire, Drone fabrication aperture, sensors, and a compact twin auto-rifle crown on a broad rotation collar.
- **Plasma Bastion:** octagonal armored base, Walker deployment portal, capacitor chambers, central plasma core, and twin reinforced plasma cannon housings.
- **Siege Foundry:** twelve-sided industrial base, Compiler assembly portal, fabrication vaults, deep reactor, rear-balanced turret, and two long reinforced accelerator cannons. Barrels point over the front gate in every view.
- **Garrison Keep:** octagonal production keep, large front deployment gate, protected crystalline core, four integrated shield/tether pylons, concentric compounding bands, service bays, and no large turret.

The images were generated with Codex's built-in image-generation workflow.

## Rodin handoff

- Multi-image mode: concat / multi-view of one object
- T/A Pose: OFF
- Symmetry: High / symmetric
- Quality: Medium for towers; High is reasonable for a focal Garrison
- Style tags: edges + game-ready
- Mode: Faithful
- Detail: +1
- CFG: 10
- Steps: 50
- Export: Quad 8000 for towers; consider Quad 18000 for the Garrison; baked normal ON, PBR, 2K, De-light ON, temperature 7
- Universal negative prompt: `multiple objects, duplicate figures, floating parts, disconnected pieces, base, pedestal, stand, ground plane, text, labels, watermark, UI panels, blurry, low quality`

The three weapon towers intentionally use a broad connected rotation collar. Generate the structure as one connected body, then split the turret assembly from the base in Blender if it needs to track targets. `Tower.gd` can also continue to provide its own gameplay turret if the concept is used only as the static body.
