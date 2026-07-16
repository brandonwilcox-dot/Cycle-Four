## Convoy.gd
## Phase 8 — a persistent logistics convoy ferrying between a depot and the FOB along the discovered
## ancient path. Spawned once per depot by ConvoyManager; loops depot↔FOB, crediting cargo on arrival.
##
## 3D MIGRATION (Stage 2i): now `extends Node3D` (model/view). Logical plane pos `_p` drives the
## transform via World3D; route_world stays plane-space waypoints. Visual is a small 3D box (blue
## loaded / grey empty); 2D rank bar/chevrons deferred (null-guarded).
class_name Convoy
extends Node3D

const WORLD3D = preload("res://src/core/World3D.gd")
const BALANCE = preload("res://src/core/Balance.gd")

const CONVOY_BASE_SPEED    : float = 90.0
const SPEED_PER_RANK       : float = 0.05
const LOAD_UNLOAD_TIME     : float = 1.5
const VISUAL_SIZE          : float = 20.0
const VISUAL_COLOR_HINT    : Color = Color(0.30, 0.65, 0.95, 1.0)
const VISUAL_COLOR_EMPTY   : Color = Color(0.55, 0.55, 0.60, 0.85)
const DEFAULT_CARGO_AMOUNT : float = 1.0

const PROFICIENCY_BASE     : float = 1.0
const PROFICIENCY_GROWTH   : float = 0.5
const DELIVERIES_PER_RANK  : int   = 10

const CONVOY_MAX_RANK        : int = 6
const CONVOY_SIGHT_BASE      : int = 2
const CONVOY_SIGHT_PER_STEP  : int = 2
const CONVOY_SIGHT_BONUS_MAX : int = 3

@export var convoy_id    : StringName = &""
@export var from_node_id : StringName = &""
@export var to_node_id   : StringName = &""
@export var cargo_amount : float      = DEFAULT_CARGO_AMOUNT

var route_world : Array[Vector2] = []
var _p          : Vector2 = Vector2.ZERO

var _waypoint_index : int   = 0
var _direction      : int   = 1
var _pause_timer    : float = 0.0

var proficiency      : float = PROFICIENCY_BASE
var _deliveries_made : int   = 0
var _current_speed   : float = CONVOY_BASE_SPEED

var _mesh       : MeshInstance3D = null
var _mat        : StandardMaterial3D = null
var _rank_bar   : Node = null   ## deferred; null-guarded
var _rank_chevrons : Node = null
var _convoy_rank : int  = 0
var _map_grid   : Node  = null

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("convoys")
	_build_visual()
	if route_world.size() < 2:
		push_error("Convoy: route too short (%d waypoints) — destroying." % route_world.size())
		queue_free()
		return
	_map_grid = get_parent()
	_p = route_world[0]
	position = WORLD3D.to3(_p, 0.0)
	_waypoint_index = 1
	_update_fog_visibility()

func _process(delta: float) -> void:
	_apply_sight()
	if _pause_timer > 0.0:
		_pause_timer -= delta
		_update_fog_visibility()
		return
	var target : Vector2 = route_world[_waypoint_index]
	var to_target : Vector2 = target - _p
	var dist : float = to_target.length()
	var step : float = _current_speed * BALANCE.MOVE_SCALE * delta
	if dist <= step:
		_set_plane(target)
		_on_waypoint_reached()
	else:
		_set_plane(_p + to_target.normalized() * step)
	_update_fog_visibility()

func _set_plane(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

func _apply_sight() -> void:
	if _map_grid == null or CONVOY_SIGHT_BASE <= 0 or not _map_grid.has_method("world_to_cell"):
		return
	var cell : Vector2i = _map_grid.world_to_cell(_p)
	@warning_ignore("integer_division")
	var sight : int = CONVOY_SIGHT_BASE + mini(_convoy_rank / CONVOY_SIGHT_PER_STEP, CONVOY_SIGHT_BONUS_MAX)
	_map_grid.call("reveal_area", cell, sight)

func _update_fog_visibility() -> void:
	if _map_grid == null or not _map_grid.has_method("world_to_cell"):
		return
	var map_data : MapData = _map_grid.get("map_data") as MapData
	if map_data == null:
		return
	var cell : Vector2i = _map_grid.world_to_cell(_p)
	if cell.x < 0 or cell.x >= map_data.dimensions.x or cell.y < 0 or cell.y >= map_data.dimensions.y:
		return
	var idx : int = cell.x + cell.y * map_data.dimensions.x
	visible = map_data.get_meta_revealed(idx)

func _on_waypoint_reached() -> void:
	var last_idx : int = route_world.size() - 1
	if _direction == 1 and _waypoint_index == last_idx:
		var delivered : float = cargo_amount * proficiency
		EventBus.convoy_arrived.emit(convoy_id, to_node_id, delivered)
		_deliveries_made += 1
		var new_prof : float = PROFICIENCY_BASE + PROFICIENCY_GROWTH * (
			log(1.0 + float(_deliveries_made)) / log(10.0)
		)
		if not is_equal_approx(new_prof, proficiency):
			proficiency = new_prof
			EventBus.convoy_proficiency_changed.emit(convoy_id, proficiency)
		var prev_rank : int = _convoy_rank
		@warning_ignore("integer_division")
		_convoy_rank = mini(_deliveries_made / DELIVERIES_PER_RANK, CONVOY_MAX_RANK)
		if _convoy_rank > prev_rank:
			_current_speed = CONVOY_BASE_SPEED * pow(1.0 + SPEED_PER_RANK, float(_convoy_rank))
			if _rank_chevrons != null:
				_rank_chevrons.call("set_rank", _convoy_rank)
		_update_rank_bar()
		_pause_timer    = LOAD_UNLOAD_TIME
		_direction      = -1
		_waypoint_index = last_idx - 1
		_set_visual_color(VISUAL_COLOR_EMPTY)
	elif _direction == -1 and _waypoint_index == 0:
		_pause_timer    = LOAD_UNLOAD_TIME
		_direction      = 1
		_waypoint_index = 1
		_set_visual_color(VISUAL_COLOR_HINT)
	else:
		_waypoint_index += _direction

func _update_rank_bar() -> void:
	if _rank_bar == null:
		return
	var into_rank : int = _deliveries_made % DELIVERIES_PER_RANK
	_rank_bar.call("set_progress", float(into_rank) / float(DELIVERIES_PER_RANK))

func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(VISUAL_SIZE, VISUAL_SIZE * 0.8, VISUAL_SIZE)
	_mesh.mesh = bx
	_mesh.position = Vector3(0.0, VISUAL_SIZE * 0.4, 0.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = VISUAL_COLOR_HINT
	_mesh.material_override = _mat
	add_child(_mesh)

func _set_visual_color(c: Color) -> void:
	if _mat != null:
		_mat.albedo_color = c
