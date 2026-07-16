## AssetLoader.gd — load GLTF models (commanders / units) and apply faction materials.
extends RefCounted

const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")

## Enemy/friendly UNIT GLTF models. Empty by default so units render via the
## verified procedural UnitBodies silhouettes; populate per-faction to override.
const FACTION_MODELS = {}

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
	"architects": 38.6,   ## hi-fi Rodin v2 quad mesh (~1.889u tall -> ~73 game units)
	"bloom": 38.5,        ## hi-fi Rodin mesh (~1.894u tall -> ~73 game units)
	"mesh": 38.6,         ## hi-fi Rodin body (~1.891u tall -> ~73 game units; tentacles extend above)
}

## Per-faction facing correction (degrees about Y): model's front -> game forward (+X).
## Primitives face -Z (need -90); the hi-fi Architect faces +Z (needs +90). VERIFY in play.
const FACTION_COMMANDER_YAW = {
	"architects": 90.0,
	"bloom": 90.0,        ## hi-fi Rodin mesh faces +Z like the Architect (VERIFY in F3 play; flip if striding sideways)
	"mesh": 90.0,         ## hi-fi mesh faces +Z like the other Rodin commanders (VERIFY in F2 play)
}

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

	var mesh_inst = _find_mesh_instance(model)
	if mesh_inst != null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = base_color
		if apply_substrate:
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
