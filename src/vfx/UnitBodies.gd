## UnitBodies.gd — per-faction unit silhouettes. Composes a multi-part body on a unit's root
## MeshInstance3D. Every STRUCTURAL part shares the caller's material instance, so tint/
## damage-fade/hijack/stealth/hit-flash apply body-wide; tiny glow accents get their own
## emissive materials. Forward is +X (units yaw to face travel). Zero-asset procedural.
##
## Aesthetic anchors (playtest 2026-07-03, Supreme Commander: Forged Alliance):
##   Architects = SERAPHIM  — smooth, elegant, chrome-like, few jagged angles; a thin
##                            light-channel as the technological underscore. Glides.
##   Bloom      = AEON + BIO — sleek rounded hover-saucer forms grown over with biology:
##                            trailing tendrils/roots with budding tips. Lopes.
##   Mesh       = CYBRAN    — angular, spiky, insectoid; exposed frame, mandible prongs,
##                            splayed spike legs, a single hot sensor eye. Skitters.
extends RefCounted

## Build the body for `faction_id` at scale `s` (the old cube edge length) onto `root`.
static func compose(root: MeshInstance3D, faction_id: String, s: float, mat: Material) -> void:
	match faction_id:
		"architects":
			## SERAPHIM: one flowing chrome form — a smooth core with a long sleek fuselage,
			## canopy blister, swept dorsal fin, and a thin warm light-channel underneath.
			var core := SphereMesh.new()
			core.radius = s * 0.30
			core.height = s * 0.40
			root.mesh = core
			var fuselage := CapsuleMesh.new()
			fuselage.radius = s * 0.20
			fuselage.height = s * 1.20
			_part(root, fuselage, Vector3.ZERO, mat, Vector3(0.0, 0.0, 90.0))
			_part(root, _sphere(s * 0.16), Vector3(s * 0.14, s * 0.20, 0.0), mat)
			_part(root, _box(s * 0.50, s * 0.26, s * 0.05), Vector3(-s * 0.34, s * 0.22, 0.0), mat,
				Vector3(0.0, 0.0, -32.0))
			_glow_part(root, _box(s * 0.70, s * 0.04, s * 0.07), Vector3(s * 0.05, -s * 0.16, 0.0),
				Color(1.00, 0.92, 0.75), 1.2)
		"bloom":
			## AEON + BIO: a rounded saucer with a dome, overgrown — three root-tendrils trail
			## beneath and behind, each ending in a softly glowing bud.
			var saucer := SphereMesh.new()
			saucer.radius = s * 0.55
			saucer.height = s * 0.40
			root.mesh = saucer
			_part(root, _sphere(s * 0.24, s * 0.30), Vector3(0.0, s * 0.16, 0.0), mat)
			for i in 3:
				var yaw : float = 145.0 + 35.0 * float(i)   ## trailing arc behind (-X)
				var dir : Vector3 = Vector3(cos(deg_to_rad(yaw)), 0.0, sin(deg_to_rad(yaw)))
				var tendril := CapsuleMesh.new()
				tendril.radius = s * 0.06
				tendril.height = s * 0.62
				_part(root, tendril, dir * s * 0.42 + Vector3(0.0, -s * 0.18, 0.0), mat,
					Vector3(dir.z * 55.0, 0.0, -dir.x * 55.0))
				_glow_part(root, _sphere(s * 0.08), dir * s * 0.62 + Vector3(0.0, -s * 0.34, 0.0),
					Color(0.45, 1.00, 0.50), 1.0)
		"mesh":
			## CYBRAN: angular exposed frame — chassis + narrow upper deck, forward mandible
			## prongs, four splayed spike legs, rear spikes, one hot sensor eye.
			var chassis := BoxMesh.new()
			chassis.size = Vector3(s * 0.75, s * 0.28, s * 0.55)
			root.mesh = chassis
			_part(root, _box(s * 0.45, s * 0.20, s * 0.36), Vector3(-s * 0.05, s * 0.22, 0.0), mat)
			for lz in [-1.0, 1.0]:
				_part(root, _box(s * 0.42, s * 0.06, s * 0.06),
					Vector3(s * 0.48, -s * 0.04, lz * s * 0.16), mat, Vector3(0.0, lz * -16.0, 0.0))
			for lx in [-1.0, 1.0]:
				for lz in [-1.0, 1.0]:
					_part(root, _box(s * 0.08, s * 0.58, s * 0.08),
						Vector3(lx * s * 0.28, -s * 0.26, lz * s * 0.30), mat,
						Vector3(lz * 18.0, 0.0, lx * -20.0))
			for lz in [-1.0, 1.0]:
				_part(root, _box(s * 0.34, s * 0.05, s * 0.05),
					Vector3(-s * 0.42, s * 0.16, lz * s * 0.12), mat, Vector3(0.0, lz * 14.0, -18.0))
			_glow_part(root, _sphere(s * 0.08), Vector3(s * 0.22, s * 0.34, 0.0),
				Color(0.35, 0.75, 1.00), 1.6)
		_:
			var bx := BoxMesh.new()
			bx.size = Vector3(s, s, s)
			root.mesh = bx

static func _part(root: MeshInstance3D, mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)

## Small emissive accent with its own material (not tinted by gameplay effects — decor only).
static func _glow_part(root: MeshInstance3D, mesh: Mesh, pos: Vector3, col: Color, energy: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func _sphere(r: float, h: float = -1.0) -> SphereMesh:
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = h if h > 0.0 else r * 2.0
	return sp
