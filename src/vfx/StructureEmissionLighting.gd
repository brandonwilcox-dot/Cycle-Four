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
				if source != null and source.emission_enabled and \
						(source.emission_texture != null or emission_texture_override != null):
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

static func _add_cluster_lights(parent: Node3D, specs: Array, model_scale: float,
		prefix: String) -> Array[OmniLight3D]:
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
		light.position = normalized_position * model_scale + outward_normal.normalized() * float(spec["offset"])
		parent.add_child(light)
		lights.append(light)
	return lights
