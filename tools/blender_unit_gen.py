#!/usr/bin/env python3
"""
Blender 2.93 unit silhouette generator for Cycle Four.
SIMPLIFIED: Uses basic Blender primitives (no bmesh), much more robust.

Procedurally creates faction-specific unit models and exports as GLTF.

Run in Blender console:
  1. Paste this entire script into the Blender Python console
  2. Press Enter to execute
  3. Check assets/models/units/ for .glb exports

Units generated:
  - Architect: wedge drone (sleek, gliding)
  - Bloom: crawler (segmented, organic)
  - Mesh: skitterer (angular, multi-legged)
"""

import bpy
import os

print("\n=== Cycle Four Unit Generator (Simplified) ===\n")

# Configuration
UNIT_HEIGHT = 2.0  # Blender units (will scale in Godot)

def clear_scene():
    """Remove all mesh objects from the scene."""
    try:
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        print("[OK] Scene cleared")
    except Exception as e:
        print(f"[WARN] Clear scene: {e}")

def create_material(name, color):
    """Create a simple material."""
    try:
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.7
        return mat
    except Exception as e:
        print(f"[WARN] Material {name}: {e}")
        return None

def create_architect_drone():
    """Architect wedge drone: sleek, pointed, gliding posture."""
    try:
        print("Creating Architect drone...")
        h = UNIT_HEIGHT

        # Add cone (tip)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.3, radius2=0.0, depth=h*0.6, location=(0, h*0.5, h*0.3))
        tip = bpy.context.active_object
        tip.name = "architect_drone_tip"

        # Add cube (rear fuselage)
        bpy.ops.mesh.primitive_cube_add(size=h*0.5, location=(0, h*0.2, -h*0.2))
        rear = bpy.context.active_object
        rear.name = "architect_drone_rear"
        rear.scale = (1.2, 0.6, 0.8)

        # Add plane wings (scaled flat boxes)
        bpy.ops.mesh.primitive_cube_add(size=0.2, location=(-h*0.6, h*0.3, 0))
        wing_l = bpy.context.active_object
        wing_l.scale = (h*0.4, 0.1, h*0.5)

        bpy.ops.mesh.primitive_cube_add(size=0.2, location=(h*0.6, h*0.3, 0))
        wing_r = bpy.context.active_object
        wing_r.scale = (h*0.4, 0.1, h*0.5)

        # Join all parts
        ctx = bpy.context.copy()
        ctx['object'] = tip
        ctx['selected_editable_objects'] = [tip, rear, wing_l, wing_r]
        bpy.ops.object.join(ctx)

        obj = bpy.context.active_object
        obj.name = "architect_drone"

        # Apply material
        mat = create_material("architect_substrate", (0.9, 0.8, 0.3))
        if mat:
            obj.data.materials.append(mat)

        print(f"[OK] Architect drone created: {obj.name}")
        return obj
    except Exception as e:
        print(f"[ERROR] Architect drone: {e}")
        return None

def create_bloom_crawler():
    """Bloom crawler: organic, segmented body, loping gait."""
    try:
        print("Creating Bloom crawler...")
        h = UNIT_HEIGHT

        # Three UV spheres (head, thorax, abdomen)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=h*0.3, location=(0, h*0.6, h*0.3))
        head = bpy.context.active_object
        head.name = "crawler_head"
        head.scale = (0.8, 1.0, 0.9)

        bpy.ops.mesh.primitive_uv_sphere_add(radius=h*0.4, location=(0, h*0.3, 0))
        thorax = bpy.context.active_object
        thorax.name = "crawler_thorax"
        thorax.scale = (1.0, 0.7, 1.2)

        bpy.ops.mesh.primitive_uv_sphere_add(radius=h*0.3, location=(0, h*0.05, -h*0.3))
        abdomen = bpy.context.active_object
        abdomen.name = "crawler_abdomen"
        abdomen.scale = (0.85, 0.6, 1.0)

        # Join
        ctx = bpy.context.copy()
        ctx['object'] = head
        ctx['selected_editable_objects'] = [head, thorax, abdomen]
        bpy.ops.object.join(ctx)

        obj = bpy.context.active_object
        obj.name = "bloom_crawler"

        mat = create_material("bloom_substrate", (0.1, 0.6, 0.2))
        if mat:
            obj.data.materials.append(mat)

        print(f"[OK] Bloom crawler created: {obj.name}")
        return obj
    except Exception as e:
        print(f"[ERROR] Bloom crawler: {e}")
        return None

def create_mesh_skitterer():
    """Mesh skitterer: angular, spiky, multi-legged."""
    try:
        print("Creating Mesh skitterer...")
        h = UNIT_HEIGHT

        # Chassis (flat box)
        bpy.ops.mesh.primitive_cube_add(size=h*0.5, location=(0, h*0.1, 0))
        chassis = bpy.context.active_object
        chassis.scale = (1.0, 0.4, 1.2)
        chassis.name = "skitterer_chassis"

        # Antenna (tall cylinder)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.1, depth=h*0.8, location=(0, h*0.5, 0.1))
        antenna = bpy.context.active_object
        antenna.name = "skitterer_antenna"

        # Four legs (small cubes)
        legs = []
        for side in [-1, 1]:
            for pair in range(2):
                x = side * h * 0.5
                z = -h * 0.2 + pair * h * 0.3
                bpy.ops.mesh.primitive_cube_add(size=0.15, location=(x, h*-0.05, z))
                leg = bpy.context.active_object
                leg.scale = (0.3, 0.4, 0.5)
                legs.append(leg)

        # Join all
        ctx = bpy.context.copy()
        ctx['object'] = chassis
        ctx['selected_editable_objects'] = [chassis, antenna] + legs
        bpy.ops.object.join(ctx)

        obj = bpy.context.active_object
        obj.name = "mesh_skitterer"

        mat = create_material("mesh_substrate", (0.15, 0.5, 0.9))
        if mat:
            obj.data.materials.append(mat)

        print(f"[OK] Mesh skitterer created: {obj.name}")
        return obj
    except Exception as e:
        print(f"[ERROR] Mesh skitterer: {e}")
        return None

def export_gltf(obj, filename, export_dir):
    """Export a single object as GLTF."""
    try:
        if obj is None:
            print(f"[SKIP] {filename} (object is None)")
            return

        # Select only this object
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj

        filepath = os.path.join(export_dir, filename)
        os.makedirs(export_dir, exist_ok=True)

        # GLTF export
        bpy.ops.export_scene.gltf(
            filepath=filepath,
            check_existing=False,
            export_format='GLB',
            export_materials=True,
            export_colors=True,
            export_normals=True,
        )
        print(f"[OK] Exported: {filepath}")
    except Exception as e:
        print(f"[ERROR] Export {filename}: {e}")

# Main execution
try:
    # Set export directory
    export_dir = r"D:\AI\Cycle Four\assets\models\units"
    print(f"Export directory: {export_dir}\n")

    clear_scene()

    # Generate and export units
    arch_obj = create_architect_drone()
    export_gltf(arch_obj, "architect_drone.glb", export_dir)
    print()

    bloom_obj = create_bloom_crawler()
    export_gltf(bloom_obj, "bloom_crawler.glb", export_dir)
    print()

    mesh_obj = create_mesh_skitterer()
    export_gltf(mesh_obj, "mesh_skitterer.glb", export_dir)
    print()

    print("=== Generation Complete ===")
    print(f"Check: {export_dir}")

except Exception as e:
    print(f"[FATAL] {e}")
    import traceback
    traceback.print_exc()
