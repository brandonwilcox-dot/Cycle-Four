## Shared localized lighting for authored faction structures and hero assets.
##
## Emissive textures provide the visible seams/apertures and feed glow + SSIL/SDFGI.
## Small shadowless OmniLight3D nodes at measured high-energy concentrations provide
## dependable direct spill onto nearby armor and ground. A single object-wide fill is
## deliberately avoided: it destroys albedo contrast and makes the whole mesh emissive.
extends RefCounted

const ARCHITECT_BLUE := Color(0.20, 0.82, 1.0)

## Static-model positions are normalized GLB coordinates. Commander positions are body-local
## coordinates normalized against its import scale. Energy/range are game-space units.
const ARCHITECT_GARRISON_LIGHTS := [
	{"name": "PortalFront", "position": Vector3(-0.1745, 0.3446, 0.8805), "normal": Vector3(0.0, 0.0, 1.0), "offset": 4.0, "energy": 2.80, "range": 46.0},
	{"name": "UpperFront", "position": Vector3(-0.0092, 0.7390, 0.7109), "normal": Vector3(0.0, 0.0, 1.0), "offset": 4.0, "energy": 1.40, "range": 34.0},
	{"name": "ApertureFrontRight", "position": Vector3(0.6797, 0.3713, 0.5834), "normal": Vector3(0.76, 0.0, 0.65), "offset": 4.0, "energy": 1.60, "range": 36.0},
	{"name": "PortalRear", "position": Vector3(0.6564, 0.2542, -0.6871), "normal": Vector3(0.69, 0.0, -0.72), "offset": 4.0, "energy": 1.80, "range": 38.0},
	{"name": "ApertureLeft", "position": Vector3(-0.8912, 0.0920, -0.2045), "normal": Vector3(-0.97, 0.0, -0.22), "offset": 4.0, "energy": 1.50, "range": 34.0},
	{"name": "ApertureRight", "position": Vector3(0.7339, 0.1484, 0.2809), "normal": Vector3(0.93, 0.0, 0.36), "offset": 4.0, "energy": 1.50, "range": 34.0},
]

const ARCHITECT_FOB_LIGHTS := [
	{"name": "CoreSpire", "position": Vector3(-0.0016, 1.1367, -0.0265), "normal": Vector3(0.0, 1.0, 0.0), "offset": 8.0, "energy": 2.10, "range": 100.0},
	{"name": "CoreLeft", "position": Vector3(-0.4834, 0.6109, -0.0134), "normal": Vector3(-1.0, 0.0, 0.0), "offset": 8.0, "energy": 1.70, "range": 88.0},
	{"name": "CoreRight", "position": Vector3(0.4827, 0.6206, -0.0081), "normal": Vector3(1.0, 0.0, 0.0), "offset": 8.0, "energy": 1.70, "range": 88.0},
	{"name": "PortalFront", "position": Vector3(0.0, 0.12, 0.95), "normal": Vector3(0.0, 0.0, 1.0), "offset": 6.0, "energy": 3.20, "range": 90.0},
	{"name": "UpperFront", "position": Vector3(-0.0161, 0.7036, 0.4587), "normal": Vector3(0.0, 0.0, 1.0), "offset": 8.0, "energy": 1.70, "range": 85.0},
	{"name": "UpperRear", "position": Vector3(-0.0100, 0.6990, -0.5378), "normal": Vector3(0.0, 0.0, -1.0), "offset": 8.0, "energy": 1.60, "range": 80.0},
]

## Plasma Bastion (Architect tier-2 tower). Measured from the mesh: twin plasma emitters and
## crown core on the turret crown, the hexagonal core and deployment portal on the front face.
## Ranges are scaled to a tower-sized asset (model scale 40 → ~76u footprint, ~58u tall).
## Split base/turret: the crown ROTATES to track targets, so its emitter + core lights must be
## parented to the turret node and spin with it. The base lights stay on the static hull.
## Re-measured 2026-07-29 against the re-imported Quad-8000 pack — the earlier mesh had a
## different UV atlas AND different bounds, so every position here moved. Emitters and the
## flank capacitors were derived by sampling the baked mask at each triangle's UV centroid and
## clustering the lit triangles in 3D; the front core/portal come from the centreline face
## profile (z 0.778 at y 0.4-0.5, 0.718 at y 0.1-0.2).
const ARCHITECT_PLASMA_BASTION_TURRET_LIGHTS := [
	{"name": "EmitterLeft", "position": Vector3(-0.343, 1.223, 0.634), "normal": Vector3(0.0, 0.1, 1.0), "offset": 4.0, "energy": 2.60, "range": 44.0},
	{"name": "EmitterRight", "position": Vector3(0.343, 1.223, 0.634), "normal": Vector3(0.0, 0.1, 1.0), "offset": 4.0, "energy": 2.60, "range": 44.0},
	{"name": "CrownCore", "position": Vector3(0.0, 1.300, 0.150), "normal": Vector3(0.0, 1.0, 0.0), "offset": 4.0, "energy": 2.00, "range": 46.0},
]
const ARCHITECT_PLASMA_BASTION_BASE_LIGHTS := [
	{"name": "CoreFront", "position": Vector3(0.0, 0.470, 0.778), "normal": Vector3(0.0, 0.0, 1.0), "offset": 4.0, "energy": 2.20, "range": 42.0},
	{"name": "PortalFront", "position": Vector3(0.0, 0.150, 0.718), "normal": Vector3(0.0, 0.0, 1.0), "offset": 4.0, "energy": 2.40, "range": 40.0},
	{"name": "CapacitorLeft", "position": Vector3(-0.548, 0.567, 0.227), "normal": Vector3(-0.92, 0.0, 0.39), "offset": 4.0, "energy": 1.80, "range": 38.0},
	{"name": "CapacitorRight", "position": Vector3(0.548, 0.567, 0.227), "normal": Vector3(0.92, 0.0, 0.39), "offset": 4.0, "energy": 1.80, "range": 38.0},
]

## Sentry Spire (Architect tier-1 tower). Positions were DERIVED, not eyeballed: each triangle's
## UV centroid was sampled against the baked emission mask, and the lit triangles k-means
## clustered in model space — so every light sits on an actual emission concentration.
## Split base/turret like the bastion: the crown rotates, so the muzzle + sensor lights ride it.
##
## Deliberately kept to SIX lights total. This is the most numerous structure the player builds
## (tower cap 8, +2 per enemy base destroyed), so a bastion-style cluster would put ~50 omnis on
## the field from towers alone. Ranges are ~20% tighter than the bastion's 40-46 because the
## spire is slender — a wide light washes the whole shaft flat, which is the defect still open on
## ARCHITECT_FOB_LIGHTS.PortalFront (energy 3.20 / range 90).
const ARCHITECT_SENTRY_SPIRE_TURRET_LIGHTS := [
	{"name": "MuzzleLeft", "position": Vector3(-0.235, 1.729, 0.584), "normal": Vector3(0.0, 0.1, 1.0), "offset": 3.0, "energy": 2.40, "range": 34.0},
	{"name": "MuzzleRight", "position": Vector3(0.235, 1.729, 0.584), "normal": Vector3(0.0, 0.1, 1.0), "offset": 3.0, "energy": 2.40, "range": 34.0},
	{"name": "CrownSensor", "position": Vector3(0.018, 1.863, 0.180), "normal": Vector3(0.0, 1.0, 0.0), "offset": 3.0, "energy": 1.90, "range": 32.0},
]
const ARCHITECT_SENTRY_SPIRE_BASE_LIGHTS := [
	{"name": "DroneAperture", "position": Vector3(0.0, 0.148, 0.545), "normal": Vector3(0.0, 0.0, 1.0), "offset": 3.0, "energy": 2.40, "range": 38.0},
	{"name": "SpineFrontLeft", "position": Vector3(-0.249, 0.549, 0.273), "normal": Vector3(-0.4, 0.0, 0.9), "offset": 3.0, "energy": 1.60, "range": 30.0},
	{"name": "SpineFrontRight", "position": Vector3(0.249, 0.549, 0.273), "normal": Vector3(0.4, 0.0, 0.9), "offset": 3.0, "energy": 1.60, "range": 30.0},
]

## Siege Foundry (Architect tier-3 tower). ⚠ This model shipped with NO emissive map and its
## diffuse cannot yield one (De-light drained it: p99 b-r 0.059 vs the Sentry Spire's 0.275,
## and the threshold has no stable operating point — 0.055 gives 0.51% coverage, 0.045 gives
## 8.78%). Until a material re-export with an emissive lands, these lights are the ONLY cyan
## the tower has, so they run slightly hotter than the spire's to compensate. Positions are
## measured from the mesh, not the mask, for the same reason.
## Turret lights carry the -0.105 Z pivot via _add_cluster_lights so they stay on the barrels.
const ARCHITECT_SIEGE_FOUNDRY_TURRET_LIGHTS := [
	{"name": "CannonLeft", "position": Vector3(-0.100, 1.008, 0.881), "normal": Vector3(0.0, 0.0, 1.0), "offset": 4.0, "energy": 2.60, "range": 44.0},
	{"name": "CannonRight", "position": Vector3(0.100, 1.008, 0.881), "normal": Vector3(0.0, 0.0, 1.0), "offset": 4.0, "energy": 2.60, "range": 44.0},
	{"name": "Breech", "position": Vector3(0.0, 1.150, -0.300), "normal": Vector3(0.0, 1.0, 0.0), "offset": 4.0, "energy": 2.00, "range": 38.0},
]
const ARCHITECT_SIEGE_FOUNDRY_BASE_LIGHTS := [
	{"name": "DeploymentGate", "position": Vector3(0.0, 0.100, 0.671), "normal": Vector3(0.0, 0.0, 1.0), "offset": 4.0, "energy": 2.60, "range": 46.0},
	{"name": "VaultLeft", "position": Vector3(-0.801, 0.369, 0.017), "normal": Vector3(-1.0, 0.0, 0.0), "offset": 4.0, "energy": 1.80, "range": 38.0},
	{"name": "VaultRight", "position": Vector3(0.801, 0.369, 0.017), "normal": Vector3(1.0, 0.0, 0.0), "offset": 4.0, "energy": 1.80, "range": 38.0},
]

const ARCHITECT_COMMANDER_LIGHTS := [
	{"name": "ReactorChest", "position": Vector3(0.31, 1.72, 0.0), "normal": Vector3(1.0, 0.0, 0.0), "offset": 2.5, "energy": 2.60, "range": 44.0},
	{"name": "CrownCore", "position": Vector3(0.0, 2.55, 0.0), "normal": Vector3(0.0, 1.0, 0.0), "offset": 2.5, "energy": 1.55, "range": 38.0},
	{"name": "FinLeft", "position": Vector3(-0.05, 2.05, 0.62), "normal": Vector3(0.0, 0.2, 1.0), "offset": 2.0, "energy": 1.35, "range": 34.0},
	{"name": "FinRight", "position": Vector3(-0.05, 2.05, -0.62), "normal": Vector3(0.0, 0.2, -1.0), "offset": 2.0, "energy": 1.35, "range": 34.0},
	{"name": "CannonLeft", "position": Vector3(0.58, 1.35, 0.55), "normal": Vector3(0.8, 0.0, 0.6), "offset": 2.5, "energy": 1.50, "range": 34.0},
	{"name": "CannonRight", "position": Vector3(0.58, 1.35, -0.55), "normal": Vector3(0.8, 0.0, -0.6), "offset": 2.5, "energy": 1.50, "range": 34.0},
]

static func add_architect_garrison_lights(parent: Node3D, model_scale: float) -> void:
	_add_cluster_lights(parent, ARCHITECT_GARRISON_LIGHTS, model_scale, "Garrison")

static func add_architect_fob_lights(parent: Node3D, model_scale: float) -> void:
	_add_cluster_lights(parent, ARCHITECT_FOB_LIGHTS, model_scale, "FOB")

## Turret lights go on the ROTATING crown node; base lights on the static hull.
static func add_architect_plasma_bastion_turret_lights(parent: Node3D, model_scale: float,
		pivot: Vector3 = Vector3.ZERO) -> void:
	_add_cluster_lights(parent, ARCHITECT_PLASMA_BASTION_TURRET_LIGHTS, model_scale, "PlasmaBastionTurret", pivot)

static func add_architect_plasma_bastion_base_lights(parent: Node3D, model_scale: float) -> void:
	_add_cluster_lights(parent, ARCHITECT_PLASMA_BASTION_BASE_LIGHTS, model_scale, "PlasmaBastion")

static func add_architect_sentry_spire_turret_lights(parent: Node3D, model_scale: float,
		pivot: Vector3 = Vector3.ZERO) -> void:
	_add_cluster_lights(parent, ARCHITECT_SENTRY_SPIRE_TURRET_LIGHTS, model_scale, "SentrySpireTurret", pivot)

static func add_architect_sentry_spire_base_lights(parent: Node3D, model_scale: float) -> void:
	_add_cluster_lights(parent, ARCHITECT_SENTRY_SPIRE_BASE_LIGHTS, model_scale, "SentrySpire")

static func add_architect_siege_foundry_turret_lights(parent: Node3D, model_scale: float,
		pivot: Vector3 = Vector3.ZERO) -> void:
	_add_cluster_lights(parent, ARCHITECT_SIEGE_FOUNDRY_TURRET_LIGHTS, model_scale, "SiegeFoundryTurret", pivot)

static func add_architect_siege_foundry_base_lights(parent: Node3D, model_scale: float) -> void:
	_add_cluster_lights(parent, ARCHITECT_SIEGE_FOUNDRY_BASE_LIGHTS, model_scale, "SiegeFoundry")

## The Rodin FOB's main gate is a true recessed opening, but its authored emissive atlas
## contains no luminous portal surface behind it. A depth-tested quad sits inside the
## doorway so the existing architecture masks it to the exact portal silhouette.
static func add_architect_fob_portal_interior(parent: Node3D, model_scale: float) -> void:
	var portal := MeshInstance3D.new()
	portal.name = "ArchitectFOBPortalInterior"
	var radius := 0.075 * model_scale
	var shoulder_y := 0.125 * model_scale
	var total_y := 0.20 * model_scale
	var outline := PackedVector2Array([
		Vector2(-radius, 0.0),
		Vector2(radius, 0.0),
		Vector2(radius, shoulder_y),
	])
	for i in range(1, 9):
		var angle := float(i) * PI / 8.0
		outline.append(Vector2(cos(angle) * radius, shoulder_y + sin(angle) * radius))
	var vertices := PackedVector3Array([Vector3(0.0, total_y * 0.48, 0.0)])
	var uvs := PackedVector2Array([Vector2(0.5, 0.48)])
	for point in outline:
		vertices.append(Vector3(point.x, point.y, 0.0))
		uvs.append(Vector2((point.x + radius) / (radius * 2.0), point.y / total_y))
	var indices := PackedInt32Array()
	for i in outline.size():
		indices.append(0)
		indices.append(i + 1)
		indices.append(((i + 1) % outline.size()) + 1)
	var arrays : Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	vec2 p = UV - vec2(0.5, 0.43);
	float core = 1.0 - smoothstep(0.0, 0.48, length(p * vec2(1.25, 0.95)));
	float spine = 1.0 - smoothstep(0.0, 0.055, abs(UV.x - 0.5));
	float threshold = 1.0 - smoothstep(0.0, 0.12, abs(UV.y - 0.10));
	ALBEDO = vec3(0.01, 0.09, 0.14);
	EMISSION = vec3(0.20, 0.82, 1.0) * (5.0 + core * 8.0 + spine * 3.0 + threshold * 2.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.surface_set_material(0, material)
	portal.mesh = mesh
	## Slightly in front of the imported dark gate panel; the arch geometry prevents spill
	## across the ivory frame while the depth buffer retains normal structure occlusion.
	portal.position = Vector3(0.0, 0.0, 0.90) * model_scale
	parent.add_child(portal)
## Siege Foundry emissive inserts. Rodin's material pass authored NO emissive map for this model
## (see design/architect_defense_concepts/Siege_Foundry/IMPORT_NOTES) and its diffuse cannot yield
## one, so there is no luminous surface anywhere on the mesh — the light cluster alone reads as
## unlit at tactical range. Same remedy as the FOB's gate: small emissive discs seated in the
## measured apertures, so the tower has the cyan cores the concept calls for without a mask.
## Replace with a real baked mask if a Blender emissive-material pass ever lands.
static func add_architect_siege_foundry_inserts(turret: Node3D, hull: Node3D,
		model_scale: float, pivot: Vector3 = Vector3.ZERO) -> void:
	## ⚠ CLEARANCE MATTERS. The first pass seated these 0.003 model units proud of the surface
	## they sit in (bores at z 0.884 against a barrel tip of 0.881; gate at 0.674 against a face
	## at 0.671) — about 0.14 GAME units at this scale, which is inside z-fighting range, so the
	## depth test simply ate them and the tower read as unlit. Keep ~1-2 game units of daylight.
	## Twin cannon bores — ride the gun group so they sweep and elevate with the barrels.
	for spec in [{"n": "BoreLeft", "x": -0.100}, {"n": "BoreRight", "x": 0.100}]:
		var bore := _glow_disc("ArchitectSiegeFoundry" + str(spec["n"]),
			0.075 * model_scale, 11.0, true)
		bore.position = Vector3(float(spec["x"]), 1.008, 0.905) * model_scale - pivot
		turret.add_child(bore)
	## Deployment gate on the static hull, standing upright in the doorway. Kept narrow (±0.09)
	## and on the centreline: the base flares forward at its lowest step, so a wider disc at
	## this height would be swallowed by geometry either side of the doorway. Across the disc's
	## own footprint the recessed face sits at 0.583, so 0.625 stands ~2 units proud — enough
	## to clear the depth test without floating off the building.
	var gate := _glow_disc("ArchitectSiegeFoundryGate", 0.090 * model_scale, 8.0, false)
	gate.position = Vector3(0.0, 0.100, 0.625) * model_scale
	hull.add_child(gate)

## A small unshaded emissive disc facing +Z, hottest at its centre. `tight` gives the harder
## falloff a gun bore wants; the softer profile suits a doorway.
static func _glow_disc(node_name: String, radius: float, energy: float,
		tight: bool) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = node_name
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	disc.mesh = quad
	## Additive so the quad's square edge disappears on its own — black contributes nothing, and
	## the disc reads as a round glow seated in the aperture. (The ADD ban in DESIGN-GUIDELINES
	## is about emission on the HULL material, where it washes albedo flat; this is a separate
	## light-emitting insert, the same role the FOB's portal quad plays.)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float energy = 6.0;
uniform float falloff = 0.5;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float core = 1.0 - smoothstep(0.0, falloff, d);
	float rim = 1.0 - smoothstep(falloff, 1.0, d);
	ALBEDO = vec3(0.0);
	EMISSION = vec3(0.20, 0.82, 1.0) * (energy * core + energy * 0.30 * rim) * step(d, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("energy", energy)
	material.set_shader_parameter("falloff", 0.34 if tight else 0.62)
	material.render_priority = 1
	disc.material_override = material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc

static func add_architect_commander_lights(parent: Node3D, model_scale: float) -> Array[OmniLight3D]:
	return _add_cluster_lights(parent, ARCHITECT_COMMANDER_LIGHTS, model_scale, "Commander")

## Explicitly protect future re-exports from reverting to additive washout.
static func enforce_masked_emission(node: Node) -> void:
	tune_masked_emission(node, 0.0)

## Strengthen authored masks without replacing PBR textures. The optional override is used
## when a source mask needs mip-safe cores; multi-material models retain per-part masks.
static func tune_masked_emission(node: Node, minimum_energy: float,
		emission_texture_override: Texture2D = null) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
				## Authored emissive asset (FOB/garrison/commander) OR an explicit mask override.
				## The override path also covers models exported with NO emissive at all (Rodin's
				## De-light leaves the cyan channels as dark insets) — the baked mask supplies them.
				var has_authored : bool = source != null and source.emission_enabled and source.emission_texture != null
				if source != null and (has_authored or emission_texture_override != null):
					var mat := source.duplicate() as StandardMaterial3D
					mat.emission_enabled = true
					mat.emission = ARCHITECT_BLUE
					if emission_texture_override != null:
						mat.emission_texture = emission_texture_override
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					mat.emission_energy_multiplier = maxf(mat.emission_energy_multiplier, minimum_energy)
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					mesh_instance.set_surface_override_material(surface_index, mat)
	for child in node.get_children():
		tune_masked_emission(child, minimum_energy, emission_texture_override)

## `pivot` (GAME units) must match the turret pivot the crown mesh was reparented with. A
## rotating crown is offset by -pivot inside the turret so it spins about the collar rather
## than the model origin; a light placed from raw normalized coords therefore lands `pivot`
## away from the surface it is meant to be lighting, and sweeps as a detached glow. Static
## clusters pass Vector3.ZERO.
static func _add_cluster_lights(parent: Node3D, specs: Array, model_scale: float,
		prefix: String, pivot: Vector3 = Vector3.ZERO) -> Array[OmniLight3D]:
	var lights : Array[OmniLight3D] = []
	for spec in specs:
		var light := OmniLight3D.new()
		light.name = "Architect%s%sLight" % [prefix, str(spec["name"])]
		light.light_color = ARCHITECT_BLUE
		light.light_energy = float(spec["energy"])
		light.light_specular = 0.45
		light.omni_range = float(spec["range"])
		light.omni_attenuation = 1.60
		light.shadow_enabled = false
		light.light_indirect_energy = 0.35 if prefix == "Commander" else 0.55
		light.light_bake_mode = Light3D.BAKE_DYNAMIC if prefix == "Commander" else Light3D.BAKE_STATIC
		light.light_volumetric_fog_energy = 0.0
		## Tactical camera sits roughly 1600 units from the board; fade only after that band,
		## then cull completely before galaxy zoom to keep clustered-light cost bounded.
		light.distance_fade_enabled = true
		light.distance_fade_begin = 2200.0
		light.distance_fade_length = 1000.0
		light.set_meta("architect_base_energy", float(spec["energy"]))
		var normalized_position : Vector3 = spec["position"]
		var outward_normal : Vector3 = spec["normal"]
		light.position = normalized_position * model_scale - pivot + outward_normal.normalized() * float(spec["offset"])
		parent.add_child(light)
		lights.append(light)
	return lights
