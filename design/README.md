# design/ — Cycle Four commander/asset design scratch

Working area for commander (ACU) and unit visual design: references, sketches,
AI-generated concept meshes, the rigging pipeline's renders, and the final rigged
output. **Nothing here is loaded by the game** — shipping models live in
`assets/models/units/`. This folder is reference/scratch only (untracked in git).

## Layout

| Folder | What's in it |
|---|---|
| `Commander_Visual_Backlog.md` | **Active log** — decisions, done/outstanding items, pipeline notes. Start here. |
| `docs/` | Design docs + part-callout diagrams (`V6_3D_Asset_Design.md`, `sketch_handoff_guide.md`, ACU callout .rtf/.png). |
| `reference/` | External style anchors — SupCom faction examples (Aeon, Seraphim, Cybran) + Bloom refs. |
| `sketches/` | The user's hand + digital sketches and their thresholded (`_bw_*`) variants used as image-to-3D input. |
| `concepts/` | AI-generated (Hyper3D Rodin) concept GLBs + their preview `.png` + extracted texture maps. Candidates, not final. |
| `rigged/` | Final rigged output GLB (`architect_rigged.glb`) — this is what gets copied to `assets/models/units/architect_commander_hifi.glb`. |
| `renders/` | Iteration renders from the headless Blender pipeline (`arch_rig2..6_*`, `rig8_*`, `arch_view_*`, detail/lineup/variants shots). |
| `blend/` | Blender working files (`Concept.blend`, `MCP_Test.blend`). |
| `textures/` | Orphaned texture dump auto-extracted by Blender when GLBs were imported. Duplicates of the `*_texture_*` maps in `concepts/`; safe to delete. |

## Pipeline recap (see the backlog for detail)

Colored concept art (`sketches/`) → Hyper3D Rodin image-to-3D → concept GLB
(`concepts/`) → headless Blender rig (`scratchpad/rig_mesh.py`: orient, clean,
nearest-bone rigid skin, bake Walk/Idle) → `rigged/architect_rigged.glb` →
copied into `assets/models/units/`.

## Note for the next session

These assets sit inside the Godot project, so the editor imports all of them
(~130 MB) on open. If that ever matters, this whole folder could be moved outside
the project (it's pure scratch) — but that's a bigger call, deferred for now.
