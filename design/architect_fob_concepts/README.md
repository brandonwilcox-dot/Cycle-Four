# Architect FOB Concept Art

Four massive regional-fortress concepts for the Architects faction, generated as colored orthographic references for Hyper3D Rodin and later Godot import.

## Deliverables

Each design folder contains:

- one `1536x1024` six-cell sheet
- five clean `508x508` face crops: `front`, `back`, `left`, `right`, and `top`

The sheet order is:

| Front | Back | Top |
|---|---|---|
| Left | Right | Blank |

Upload the individual crops to Rodin. Do not upload the full sheet.

## Codex basis

The common faction language comes from:

- `docs/codex/05_the-three-factions.md`: disciplined technological refinement, efficiency, patient monumental construction
- `design/docs/Architect_Commander_Model_Reference.md`: crystalline precision, polished silver-white plate, charcoal recesses, thin dense cyan channels, minimal seams, pristine finish
- `docs/core/17_units-maps-buildings.md`: fortified production chain, gatehouses, bastions, towers, Nexus Core, and regional-base readability
- `design/docs/Rodin_Recipe_Sheets.md`: clean colored views, plain background, high symmetry, connected geometry, and separate per-view input crops

## Final prompt set

Common specification used for all four designs:

> Create one original Architects massive regional fortress combining advanced alien architecture with a military fortified castle. Use disciplined technological refinement, cold precision, crystalline-lattice motifs, elegant swept fins, faceted hexagonal forms, smooth transitions, extremely high symmetry, minimal seams, and broad connected Rodin-friendly masses. Materials are pristine polished silver-white armor, charcoal/dark-gunmetal recesses, near-mirror highlights, and dense very thin cyan-blue emissive channels. Render the exact same object as strict FRONT, BACK, TOP, LEFT, and RIGHT orthographic views on a plain white six-cell sheet. Use zero perspective, no environment, no text, no people, no floating parts, no thin cables or antennae, no grime, no organic growth, and no copied franchise geometry.

Design deltas:

- **Default:** broad layered curtain walls, fortified gatehouse, bastion towers, recessed hangars, and a tall central Nexus command spire; the general-use faction baseline.
- **Cathedral:** long nave-like armored command hall, soaring Nexus spire, paired transept bastions, shielded courtyards, and swept buttress-like power conduits; ceremonial scale without religious symbols.
- **Citadel:** low, broad, dense octagonal/star-fort footprint with three concentric wall rings, projecting bastions, interlocking firing galleries, wedge glacis armor, and a squat central keep. The final pass explicitly corrected all four side panels to camera elevation `0°` with no visible roof surfaces.
- **Arcology:** a self-contained fortress-city with a fortified perimeter, dense stepped inhabited/industrial terraces, stacked protected bands, production vaults, medium energy towers, and a strong central Nexus core.

The images were generated with Codex's built-in image-generation workflow.

## Rodin settings from the project recipe

- Multi-image mode: concat / multi-view of one object
- T/A Pose: OFF
- Symmetry: High / symmetric
- Quality: High for FOBs
- Style tags: edges + game-ready
- Mode: Faithful
- Detail: +1
- CFG: 10
- Steps: 50
- Export: Quad 18000, baked normal ON, PBR, 2K, De-light ON, temperature 7
- Universal negative prompt: `multiple objects, duplicate figures, floating parts, disconnected pieces, base, pedestal, stand, ground plane, text, labels, watermark, UI panels, blurry, low quality`
