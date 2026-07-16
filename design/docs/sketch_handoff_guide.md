# Sketch Handoff Guide — feeding hand-drawn references into the commander pipeline

How to hand off design sketches so they translate well into the procedural Blender models
(parts placed by X/Y/Z coordinate + a biped bone rig; renders at RTS zoom).

## Most useful, in priority order
1. **Front + side orthographic views** (a turnaround). Front = width/height (X/Z); side = depth (Y/Z).
   These two flat views beat one dramatic 3/4 shot every time. Back + 3/4 are bonuses.
2. **Same height across views** so proportions read. Grid paper or a few guide lines help
   (top of head / shoulder / waist / hip / knee / foot).
3. **Shape language per part** — mark boxy/angular vs round/tapered. Maps straight to my
   primitives: box, cylinder, sphere, cone, tapered prism.
4. **Joint/pivot dots** — shoulders, elbows, hips, knees, ankles. That's where bones go
   (makes the rig + walk cycle match your intent).
5. **Feature + glow callouts** — arrows labeling weapons, fins, sensors, and where glow goes + color.
6. **Material zones** — rough labels: "dark metal", "red plate", "bark", "moss". Don't render finely.

## How to present
- Label parts with short callouts (arrows + words); mark the symmetry axis.
- Note what MOVES: "fins fixed", "tentacles articulate", "drones orbit".
- Photograph/scan into `D:\AI\Cycle Four\design\` with clear names: `groot_front.jpg`, `groot_side.jpg`, etc.
- One line on scale/stance (how tall, how wide the stance) — these are colossal ACUs.

## Honest caveat
Sketches nail SILHOUETTE, PROPORTION, PART BREAKDOWN, FEATURE/GLOW PLACEMENT, SHAPE LANGUAGE — all buildable.
They do NOT overcome the procedural-primitive fidelity ceiling (fine surface texture / organic sculpt →
still stylized low-poly until we move to a sculpted or licensed-asset pipeline). Lean sketches toward bold
readable shapes + placement, not fine surface rendering.

## IP note
Aim for original archetype/vibe, not 1:1 clones of Groot / Doc Ock / Seraphim etc. (shippable-game IP risk).
