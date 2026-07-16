#!/usr/bin/env python3
"""
Standalone Blender unit generator script.
Run from Blender's scripting console or command line.

Designed for Blender 2.93+
"""

import bpy
import os
import sys

def log(msg):
    print(f"[BLENDER] {msg}")

def clear_all():
    """Delete all objects in the scene."""
    for obj in bpy.data.objects:
        bpy.data.objects.remove(obj, do_unlink=True)

def create_simple_unit(name, color_rgb, shape="cube"):
    """Create a simple unit using primitives."""
    if shape == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.3, radius2=0.0, depth=1.2)
    elif shape == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5)
    else:  # cube
        bpy.ops.mesh.primitive_cube_add(size=1.0)

    obj = bpy.context.active_object
    obj.name = name

    # Create material
    mat = bpy.data.materials.new(name=f"{name}_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color_rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.7

    obj.data.materials.append(mat)
    return obj

def export_unit(obj, filename, export_dir):
    """Export object as GLTF."""
    filepath = os.path.join(export_dir, filename)

    # Select object
    bpy.context.view_layer.objects.active = obj
    for o in bpy.data.objects:
        o.select_set(o == obj)

    log(f"Exporting: {filename}")
    try:
        bpy.ops.export_scene.gltf(
            filepath=filepath,
            export_format='GLB',
        )
        if os.path.exists(filepath):
            size = os.path.getsize(filepath)
            log(f"  SUCCESS: {size} bytes")
            return True
        else:
            log(f"  FAILED: File not created")
            return False
    except Exception as e:
        log(f"  ERROR: {e}")
        return False

def main():
    log("=== Unit Generator ===")

    # Setup
    export_dir = r"D:\AI\Cycle Four\assets\models\units"
    os.makedirs(export_dir, exist_ok=True)
    log(f"Export dir: {export_dir}")

    clear_all()
    log("Cleared scene")

    # Generate units
    units = [
        ("architect_drone", (0.9, 0.8, 0.3), "cone"),
        ("bloom_crawler", (0.1, 0.6, 0.2), "sphere"),
        ("mesh_skitterer", (0.15, 0.5, 0.9), "cube"),
    ]

    success_count = 0
    for unit_name, color, shape in units:
        log(f"Creating: {unit_name}")
        obj = create_simple_unit(unit_name, color, shape)
        if export_unit(obj, f"{unit_name}.glb", export_dir):
            success_count += 1
        clear_all()

    log(f"Complete: {success_count}/{len(units)} units exported")
    return success_count == len(units)

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except Exception as e:
        log(f"FATAL: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
