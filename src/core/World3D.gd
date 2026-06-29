## Stage 0 of the 3D migration (planning/3d-migration-plan.md): the single source of truth for
## 2D⇄3D coordinate mapping. Gameplay stays on a logical plane in PIXEL units (MapGrid CELL_SIZE
## 64). 3D maps the old 2D Y onto 3D Z, with +Y up: world3 = (x2d, height, y2d). Picking projects
## a screen ray onto the Y-plane.
##
## Per project convention (global class_name resolution is unreliable in Godot 4.6), callers
## PRELOAD this script and call the statics on the const, e.g.
##   const WORLD3D = preload("res://src/core/World3D.gd")
##   WORLD3D.to3(pos)
extends RefCounted

## Logical 2D (pixels) → 3D world. height lifts along +Y.
static func to3(v2: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(v2.x, height, v2.y)

## 3D world → logical 2D (drops the Y/height component).
static func to2(v3: Vector3) -> Vector2:
	return Vector2(v3.x, v3.z)

## Screen point → the logical-2D point where the camera ray meets the ground plane (Y = plane_y).
## Returns Vector2(NAN, NAN) if the ray is parallel to, or points away from, the plane.
static func ground_point(camera: Camera3D, screen_pos: Vector2, plane_y: float = 0.0) -> Vector2:
	if camera == null:
		return Vector2(NAN, NAN)
	var origin : Vector3 = camera.project_ray_origin(screen_pos)
	var dir    : Vector3 = camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.00001:
		return Vector2(NAN, NAN)
	var t : float = (plane_y - origin.y) / dir.y
	if t < 0.0:
		return Vector2(NAN, NAN)
	var hit : Vector3 = origin + dir * t
	return Vector2(hit.x, hit.z)

static func is_valid(v2: Vector2) -> bool:
	return not (is_nan(v2.x) or is_nan(v2.y))

## Read a node's logical-2D (plane) position, bridging the mixed migration period:
## a converted 3D entity exposes plane_pos(); a Node3D maps via to2(); a legacy Node2D
## returns its global_position directly. Used by cross-entity distance checks.
static func node_plane(n: Node) -> Vector2:
	if n == null:
		return Vector2.ZERO
	if n.has_method("plane_pos"):
		return n.call("plane_pos")
	if n is Node3D:
		return to2((n as Node3D).global_position)
	if n is Node2D:
		return (n as Node2D).global_position
	return Vector2.ZERO
