# Blender Unit Generator — Setup & Run Guide

## What This Does

Generates three faction unit models procedurally in Blender:
- **Architect drone** — wedge-shaped, sleek, gliding silhouette
- **Bloom crawler** — segmented organic body, loping stance
- **Mesh skitterer** — angular, multi-legged, antenna

Exports as GLTF 2.0 (`.glb`) for import into Godot.

---

## Prerequisites

- **Blender 2.93.6** ✓
- A Godot project directory set up (or just run it; it creates directories)

---

## Steps to Run

### 1. Open Blender
```
blender
```
Create or open a new project (doesn't matter; the script will generate units in a new scene).

### 2. Switch to Scripting Workspace
- Top menu: **Scripting**
- Or: **+** tab → Scripting

### 3. Load the Script
- **Text editor** panel (left side)
- **Open** → navigate to `tools/blender_unit_gen.py`
- Or: copy-paste the script into a new text block

### 4. Adjust Export Path (IMPORTANT)
Edit line near the bottom of the script:
```python
export_dir = os.path.join(base_path, "assets", "models", "units")
```

Options:
- **A (Recommended):** Save Blender project file at `D:\AI\Cycle Four\`, then use `//` (default — means Blender project root)
- **B (Manual):** Replace `base_path` with absolute path:
  ```python
  export_dir = r"D:\AI\Cycle Four\assets\models\units"
  ```

### 5. Run the Script
- **Alt+P** (in the text editor)
- Or: **▶ Run Script** button

### 6. Check Output
Console (bottom of Blender):
```
=== Cycle Four Unit Generator ===
Export directory: D:\AI\Cycle Four\assets\models\units
Generating Architect drone...
Exported: .../architect_drone.glb
Generating Bloom crawler...
Exported: .../bloom_crawler.glb
Generating Mesh skitterer...
Exported: .../mesh_skitterer.glb
=== Generation complete ===
```

### 7. Verify Files
Check `D:\AI\Cycle Four\assets\models\units\`:
- `architect_drone.glb` ✓
- `bloom_crawler.glb` ✓
- `mesh_skitterer.glb` ✓

---

## Next: Godot Integration

Once exported, Claude will write:
1. **Unit loaders** — swap `UnitBodies.gd` procedural meshes → imported GLTF models
2. **Material bridge** — apply V3 faction substrates to the imported geometry
3. **Scaling/pivot fixes** — ensure models match 64px cell RTS perspective
4. **Playtest script** — verify tints, performance, silhouettes

---

## Troubleshooting

**"Export failed: permission denied"**
- Check that `assets/models/units/` directory is writable
- Create directories manually if needed

**"Export directory not found"**
- Manually create: `D:\AI\Cycle Four\assets\models\units\`
- Or change export path in script

**"Script won't run (syntax error)"**
- Blender 2.93.6 should work
- Check that no lines are cut off (paste full script)

**Models look weird in Blender**
- That's OK; they're procedural + minimal
- Godot will render them with materials and scale them correctly

---

## What's Next?

Once you have the `.glb` files:
1. Let Claude know they're exported ✓
2. Claude writes Godot integration code
3. Import `architect_drone.glb`, etc. into scenes
4. Playtest to verify visuals + performance

Go ahead and run the script. Report back when the `.glb` files are generated.
