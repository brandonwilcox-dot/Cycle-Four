## AssetLoader.gd — load GLTF models (commanders / units) and apply faction materials.
extends RefCounted

const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")

## Enemy/friendly UNIT GLTF models. Populate per-faction to override the procedural
## UnitBodies silhouettes with a hand/AI-generated mesh (kept with its own materials).
const FACTION_MODELS = {
	"architects": "res://assets/models/units/architect_drone_hifi.glb",  ## Rodin hi-fi drone (V6 units)
	"bloom": "res://assets/models/units/bloom_drone_hifi.glb",            ## Rodin organic spore-pod
	"mesh": "res://assets/models/units/mesh_drone_hifi.glb",              ## Rodin angular Cybran drone
}

## Per-faction UNIT import scale (Blender units -> game units) and facing yaw (deg about Y).
## 2026-07-21 playtest: drones read too LARGE next to the Commander (73u) and the FOB —
## scaled ~0.65x so a drone is ~17-19u (Commander ≈ 4 drones tall, fortress dwarfs both).
const FACTION_UNIT_SCALE = {
	"architects": 13.0,   ## ~1.36u tall -> ~18 game units
	"bloom": 12.0,        ## ~1.61u tall -> ~19 game units
	"mesh": 13.0,         ## ~1.32u tall -> ~17 game units
}
const FACTION_UNIT_YAW = {
	"architects": 0.0,   ## VERIFY in play; flip 90/180 if the drone flies sideways/backwards
	"bloom": 0.0,        ## organic pod is roughly radial; facing low-risk
	"mesh": 0.0,         ## VERIFY in play; flip 90/180 if it faces off-axis
}

## How far a GLTF unit's albedo is pulled toward its faction color (0 = pure Rodin texture,
## 1 = flat faction color). Subtle so the model detail survives.
const UNIT_TINT_STRENGTH : float = 0.28

## Duplicate a loaded GLTF model's material so it can be tinted + flashed per-instance
## (shared resources would flash every unit at once). Keeps the Rodin textures, nudges
## albedo toward the faction color, and guarantees an emission channel (white @ 0 energy
## when the model has none) so damage hit-flash is visible. Returns the material, or null.
static func prepare_unit_material(model: Node3D, faction_color: Color) -> StandardMaterial3D:
	var mi := _find_mesh_instance(model)
	if mi == null:
		return null
	var src : Material = mi.get_active_material(0)
	var mat : StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
	mat.albedo_color = mat.albedo_color.lerp(faction_color, UNIT_TINT_STRENGTH)
	if not mat.emission_enabled:
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 0.0   ## invisible at rest; hit-flash raises it
	mi.material_override = mat
	return mat

## Player COMMANDER GLTF models (hand-modeled, rigged, animated in Blender).
## Loaded by CommanderBodyRig; materials from the GLB are kept (chrome / bio / hot glow).
const FACTION_COMMANDER_MODELS = {
	"architects": "res://assets/models/units/architect_commander_hifi.glb",  ## Rodin-generated, rigged
	"bloom": "res://assets/models/units/bloom_commander_hifi.glb",  ## Rodin-generated, rigged (from Bloom Reference MASTER)
	"mesh": "res://assets/models/units/mesh_commander_hifi.glb",  ## Rodin body + procedural scorpion tentacles
}

## Per-faction import scale (Blender units -> game units). The hi-fi Architect mesh is ~1.42
## units tall (normalized) so it needs a bigger factor than the ~3.5-unit primitives.
const FACTION_COMMANDER_SCALE = {
	"architects": 23.0,   ## Cathedral rigged assembly (~3.18u to wing tips -> ~73 game units)
	"bloom": 38.5,        ## hi-fi Rodin mesh (~1.894u tall -> ~73 game units)
	"mesh": 38.6,         ## hi-fi Rodin body (~1.891u tall -> ~73 game units; tentacles extend above)
}

## Per-faction facing correction (degrees about Y): model's front -> game forward (+X).
## Primitives face -Z (need -90); Rodin/Blender models authored facing -Y convert to glTF +Z (need +90).
const FACTION_COMMANDER_YAW = {
	"architects": 90.0,   ## Cathedral rigged assembly (Blender -Y front -> glTF +Z -> +X)
	"bloom": 90.0,        ## hi-fi Rodin mesh faces +Z like the Architect (VERIFY in F3 play; flip if striding sideways)
	"mesh": 90.0,         ## hi-fi mesh faces +Z like the other Rodin commanders (VERIFY in F2 play)
}

## Player FOB (base) GLTF models — Rodin regional fortresses. Missing faction -> the
## procedural bunker in Base.gd. Design rule: the Commander (~73 game units) must NOT be
## taller than the fortress's EXTERNAL WALLS, so wall height = norm_wall * scale >= 73.
const FACTION_BASE_MODELS = {
	"architects": "res://assets/models/buildings/architect_fob_hifi.glb",  ## "Default" concept, Rodin
}
## Import scale (Blender units -> game units). Architect model: 1.55u tall, walls at 0.57u.
## x140 -> walls ~80 (> Commander 73), spire ~217, footprint ~266 px (~4 cells). Imposing.
const FACTION_BASE_SCALE = {
	"architects": 140.0,
}
## Facing (deg about Y): gatehouse front. Rodin fronts export as +Z; camera looks from +Z.
const FACTION_BASE_YAW = {
	"architects": 0.0,   ## VERIFY in play; flip 180 if the gate faces away from the camera
}
## Normalized (pre-scale) heights measured from the mesh, for HP-bar / turret placement.
const FACTION_BASE_WALL_NORM = { "architects": 0.57 }
const FACTION_BASE_TOTAL_NORM = { "architects": 1.55 }

## Player GARRISON GLTF models. Missing factions retain Building.gd's procedural body.
## The Architect Rodin keep is ground-aligned and centered: ~1.90u footprint, 1.218u high.
const FACTION_GARRISON_MODELS = {
	"architects": "res://assets/models/buildings/architect_garrison_keep_hifi.glb",
}
## x30 -> ~57 game-unit footprint and ~36.6 game-unit height: broad enough to read as a
## fortified production node while staying inside the existing one-cell building envelope.
const FACTION_GARRISON_SCALE = {
	"architects": 30.0,
}
## Rodin fronts export toward +Z, matching the existing Architect FOB convention.
const FACTION_GARRISON_YAW = {
	"architects": 0.0,
}
const FACTION_GARRISON_TOTAL_NORM = { "architects": 1.218464 }
const FACTION_GARRISON_RADIUS_NORM = { "architects": 0.951016 }

## Bastion muzzle points, NORMALIZED mesh units (x, muzzle_y, z) — MEASURED from the mesh
## (the four tall towers flanking the spire; muzzle sits at the tower-top band so tracers
## visibly leave the towers). Multiplied by FACTION_BASE_SCALE at runtime. NOTE: measured
## in model space — if a faction's FACTION_BASE_YAW is non-zero, rotate these to match.
## The FOUR OUTER-WALL CORNER towers (measured from the mesh — the octagonal bastions at
## the corners of the square footprint, muzzle at the tower crenellation ~0.556 norm).
const FACTION_BASE_BASTIONS = {
	"architects": [
		Vector3(-0.78, 0.556, -0.78),   ## NW corner
		Vector3(0.78, 0.556, -0.78),    ## NE corner
		Vector3(0.78, 0.556, 0.78),     ## SE corner
		Vector3(-0.78, 0.556, 0.78),    ## SW corner
	],
}

## Bastion points in GAME units for the faction's FOB model ([] if no model).
static func base_bastion_points(faction_id: String) -> Array:
	var pts : Array = FACTION_BASE_BASTIONS.get(faction_id, [])
	var s : float = float(FACTION_BASE_SCALE.get(faction_id, 0.0))
	var out : Array = []
	for p : Vector3 in pts:
		out.append(p * s)
	return out

## Load the FOB fortress model for `faction_id` with scale + yaw applied, or null.
static func load_base_model(faction_id: String) -> Node3D:
	var path : String = FACTION_BASE_MODELS.get(faction_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource = ResourceLoader.load(path)
	if resource == null:
		push_error("AssetLoader: Failed to load %s" % path)
		return null
	var model = resource.instantiate() as Node3D
	if model == null:
		return null
	var s : float = float(FACTION_BASE_SCALE.get(faction_id, 100.0))
	model.scale = Vector3(s, s, s)
	model.rotation_degrees = Vector3(0.0, float(FACTION_BASE_YAW.get(faction_id, 0.0)), 0.0)
	return model

## External-wall / total height of the faction's FOB model in GAME units (0 if no model).
static func base_wall_height(faction_id: String) -> float:
	return float(FACTION_BASE_WALL_NORM.get(faction_id, 0.0)) * float(FACTION_BASE_SCALE.get(faction_id, 0.0))

static func base_total_height(faction_id: String) -> float:
	return float(FACTION_BASE_TOTAL_NORM.get(faction_id, 0.0)) * float(FACTION_BASE_SCALE.get(faction_id, 0.0))

## Load a faction Garrison model with scale + yaw applied, or null for procedural fallback.
static func load_garrison_model(faction_id: String) -> Node3D:
	var path : String = FACTION_GARRISON_MODELS.get(faction_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource = ResourceLoader.load(path)
	if resource == null:
		push_error("AssetLoader: Failed to load %s" % path)
		return null
	var model = resource.instantiate() as Node3D
	if model == null:
		push_error("AssetLoader: Garrison GLTF scene is not Node3D: %s" % path)
		return null
	var s : float = float(FACTION_GARRISON_SCALE.get(faction_id, 30.0))
	model.scale = Vector3(s, s, s)
	model.rotation_degrees = Vector3(0.0, float(FACTION_GARRISON_YAW.get(faction_id, 0.0)), 0.0)
	return model

## Imported Garrison dimensions in GAME units (0 when no authored model exists).
static func garrison_total_height(faction_id: String) -> float:
	return float(FACTION_GARRISON_TOTAL_NORM.get(faction_id, 0.0)) * float(FACTION_GARRISON_SCALE.get(faction_id, 0.0))

static func garrison_radius(faction_id: String) -> float:
	return float(FACTION_GARRISON_RADIUS_NORM.get(faction_id, 0.0)) * float(FACTION_GARRISON_SCALE.get(faction_id, 0.0))

## Load a rigged COMMANDER scene for `faction_id`, preserving its own materials
## and its AnimationPlayer. Returns the instanced Node3D, or null if unavailable.
static func load_commander_model(faction_id: String) -> Node3D:
	var path : String = FACTION_COMMANDER_MODELS.get(faction_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource = ResourceLoader.load(path)
	if resource == null:
		return null
	return resource.instantiate() as Node3D

## Load a GLTF UNIT model for the given faction and apply a faction material.
static func load_unit_model(faction_id: String, base_color: Color, apply_substrate: bool = true) -> Node3D:
	var model_path : String = FACTION_MODELS.get(faction_id, "")
	if model_path.is_empty():
		return null

	var resource = ResourceLoader.load(model_path)
	if resource == null:
		push_error("AssetLoader: Failed to load %s" % model_path)
		return null

	var model = resource.instantiate() as Node3D
	if model == null:
		push_error("AssetLoader: GLTF scene is not Node3D: %s" % model_path)
		return null

	var s : float = float(FACTION_UNIT_SCALE.get(faction_id, 12.0))
	model.scale = Vector3(s, s, s)
	model.rotation_degrees = Vector3(0.0, float(FACTION_UNIT_YAW.get(faction_id, 0.0)), 0.0)

	## Keep the model's own (Rodin) materials for close-zoom detail. Only flatten to a
	## faction substrate tint when explicitly asked (apply_substrate = true).
	if apply_substrate:
		var mesh_inst = _find_mesh_instance(model)
		if mesh_inst != null:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = base_color
			_SUBSTRATE.apply(mat, faction_id, false)
			mesh_inst.material_override = mat
	return model

## Find the first AnimationPlayer in a loaded scene (or null).
static func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result = find_animation_player(child)
		if result != null:
			return result
	return null

## Recursively find the first MeshInstance3D (public).
static func find_mesh_instance(node: Node) -> MeshInstance3D:
	return _find_mesh_instance(node)

## Recursively find the first MeshInstance3D.
static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result != null:
			return result
	return null
