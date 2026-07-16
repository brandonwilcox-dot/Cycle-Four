#!/usr/bin/env python3
"""Debug version - shows all errors clearly."""
import bpy
import os

print("\n=== DEBUG: Unit Generator ===\n")

try:
    # Test: create and export a simple cube
    print("1. Creating test cube...")
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    test_obj = bpy.context.active_object
    test_obj.name = "test_cube"
    print(f"   [OK] Cube created: {test_obj.name}")

    # Test: set up export directory
    print("\n2. Setting up export directory...")
    export_dir = r"D:\AI\Cycle Four\assets\models\units"
    os.makedirs(export_dir, exist_ok=True)
    test_file = os.path.join(export_dir, "test_cube.glb")
    print(f"   [OK] Directory: {export_dir}")
    print(f"   [OK] File path: {test_file}")

    # Test: export
    print("\n3. Attempting GLTF export...")
    bpy.context.view_layer.objects.active = test_obj
    test_obj.select_set(True)

    bpy.ops.export_scene.gltf(
        filepath=test_file,
        check_existing=False,
        export_format='GLB',
        export_materials=True,
    )
    print(f"   [OK] Export command completed")

    # Verify file exists
    print("\n4. Verifying file...")
    if os.path.exists(test_file):
        size = os.path.getsize(test_file)
        print(f"   [SUCCESS] File exists: {test_file}")
        print(f"   [SIZE] {size} bytes")
    else:
        print(f"   [ERROR] File NOT created: {test_file}")

except Exception as e:
    print(f"\n[FATAL ERROR]")
    print(f"   {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()
