## UnitBodies.gd — V6-lite unit silhouette overhaul ("tired of cubes attacking each other").
## Composes a per-faction multi-part body on a unit's root MeshInstance3D. Every part SHARES
## the caller's material instance, so tint/damage-fade/hijack/stealth/hit-flash (which all
## write that one material) apply to the whole body for free. Forward is +X (units yaw to
## face travel). Still zero-asset procedural — real model packs remain the V6 decision.
##
## Silhouette language (matches the gaits): Architects = engineered craft that GLIDES;
## Bloom = organic crawler that LOPES; Mesh = low skitterer on legs.
extends RefCounted

## Build the body for `faction_id` at scale `s` (the old cube edge length) onto `root`.
static func compose(root: MeshInstance3D, faction_id: String, s: float, mat: Material) -> void:
	match faction_id:
		"architects":
			## Wedge drone: slim hull, raised sensor canopy, swept-back wings.
			var hull := BoxMesh.new()
			hull.size = Vector3(s * 1.25, s * 0.35, s * 0.60)
			root.mesh = hull
			_part(root, _sphere(s * 0.22), Vector3(s * 0.25, s * 0.26, 0.0), mat)
			_part(root, _box(s * 0.55, s * 0.10, s * 0.38), Vector3(-s * 0.25, 0.0, s * 0.42), mat, 28.0)
			_part(root, _box(s * 0.55, s * 0.10, s * 0.38), Vector3(-s * 0.25, 0.0, -s * 0.42), mat, -28.0)
		"bloom":
			## Organic crawler: squashed body, forward head, trailing pods.
			var hull := SphereMesh.new()
			hull.radius = s * 0.52
			hull.height = s * 0.75
			root.mesh = hull
			_part(root, _sphere(s * 0.30), Vector3(s * 0.42, s * 0.06, 0.0), mat)
			_part(root, _sphere(s * 0.20), Vector3(-s * 0.32, -s * 0.08, s * 0.34), mat)
			_part(root, _sphere(s * 0.20), Vector3(-s * 0.32, -s * 0.08, -s * 0.34), mat)
		"mesh":
			## Skitterer: low flat chassis on four legs, one antenna.
			var hull := BoxMesh.new()
			hull.size = Vector3(s * 0.85, s * 0.30, s * 0.58)
			root.mesh = hull
			for lx in [-1.0, 1.0]:
				for lz in [-1.0, 1.0]:
					_part(root, _box(s * 0.12, s * 0.50, s * 0.12),
						Vector3(lx * s * 0.30, -s * 0.24, lz * s * 0.30), mat)
			_part(root, _box(s * 0.06, s * 0.48, s * 0.06), Vector3(s * 0.22, s * 0.36, 0.0), mat)
		_:
			var bx := BoxMesh.new()
			bx.size = Vector3(s, s, s)
			root.mesh = bx

static func _part(root: MeshInstance3D, mesh: Mesh, pos: Vector3, mat: Material, yaw_deg: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	if yaw_deg != 0.0:
		mi.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func _sphere(r: float) -> SphereMesh:
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.0
	return sp
