# Customizable unit parts

Drop authored GLTF part files here; the customizer (Title → Faction Preview / Customize)
discovers them automatically at:

```
assets/models/parts/<faction>/<unit>/<slot>/<part_name>.glb
```

- `<faction>`: `architects` | `bloom` | `mesh`
- `<unit>`: `commander` | `line` | `scout` | `artillery`
- `<slot>`: `head` | `torso` | `arm_l` | `arm_r` | `legs` | `extra`
  - `extra` is the faction slot: Fins (Architects), Flora (Bloom), Tentacles (Mesh)

Rules:
- File name becomes the display name (`spiral_fin.glb` → "Spiral Fin").
- A non-stock **torso** REPLACES the base body; all other slots attach at their anchor
  (`Cosmetics.SLOT_ANCHORS` — tune there as parts land).
- Author parts normalized around origin at ~1 Blender unit; they are scaled by the unit's
  body scale at attach time.
- After adding a `.glb`, open the Godot editor once (or `godot --headless --path . --import`)
  so the import artifacts exist — CLI runs do NOT import new assets.
