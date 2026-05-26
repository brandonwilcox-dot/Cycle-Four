## Unit.gd
## Enemy unit. Navigates a pre-computed world-space waypoint list from spawn to base.
## Spawned by WaveSpawner via setup(); reports death/arrival through WaveManager/EventBus.
## Phase B: uses Node2D + waypoint movement instead of PathFollow2D.
extends Node2D

## Injected by WaveSpawner before the node enters the scene tree.
var data : UnitData = null

## Waypoints in world space (cell centres). Index 0 is the spawn position.
## Movement begins toward index 1; arrival triggers advance to next index.
var _waypoints     : Array[Vector2] = []
var _wp_index      : int            = 1
const ARRIVE_DIST  : float          = 3.0   ## px -- close enough to snap to waypoint

var _current_health : float = 0.0
var _is_dead        : bool  = false
var _visual         : ColorRect = null   ## placeholder until sprites exist

func _ready() -> void:
	add_to_group("units")
	if data == null:
		push_error("Unit spawned without UnitData -- call setup() before adding to tree.")
		return
	_current_health = data.max_health
	_build_placeholder_visual()

func _process(delta: float) -> void:
	if _is_dead or _waypoints.is_empty():
		return
	if _wp_index >= _waypoints.size():
		_reach_base()
		return
	## Move toward the current waypoint
	var target     : Vector2 = _waypoints[_wp_index]
	var to_target  : Vector2 = target - global_position
	var dist       : float   = to_target.length()
	var step       : float   = data.move_speed * delta
	if dist <= step or dist <= ARRIVE_DIST:
		global_position = target
		_wp_index += 1
	else:
		global_position += to_target.normalized() * step

## Called by WaveSpawner before adding the unit to the scene tree.
## waypoints[0] is the spawn world position; unit starts there.
func setup(unit_data: UnitData, waypoints: Array) -> void:
	data       = unit_data
	_wp_index  = 1
	_waypoints.assign(waypoints)
	## Use position (local), not global_position: node isn't in the tree yet.
	## UnitLayer sits at (0,0) in world space so local == world here.
	if not _waypoints.is_empty():
		position = _waypoints[0]

## Called by WaveSpawner when EventBus.path_changed fires mid-wave.
## Finds the nearest traversable cell to current position and gets a fresh
## path to base from there. No-ops if the unit is dead or has no waypoints.
func reroute(map_grid: Node) -> void:
	if _is_dead or _waypoints.is_empty():
		return
	var nearest_cell : Vector2i = map_grid.get_nearest_path_cell(global_position)
	var new_path     : Array    = map_grid.get_path_to_base(nearest_cell)
	if new_path.is_empty():
		return   ## No alternative exists; unit continues on stale waypoints toward base
	_waypoints.assign(new_path)
	_wp_index = 1   ## Index 0 is the nearest cell; move toward index 1

## Apply incoming damage. Returns true if the unit died.
func take_damage(amount: float) -> bool:
	if _is_dead:
		return true
	var effective : float = max(0.0, amount - data.armor)
	_current_health -= effective
	_update_health_visual()
	if _current_health <= 0.0:
		_die()
		return true
	## Bloom evolution check
	if data.evolve_threshold > 0.0:
		var hp_ratio : float = _current_health / data.max_health
		if hp_ratio <= data.evolve_threshold and data.evolved_unit != null:
			_evolve()
	return false

## -- Internal --

func _reach_base() -> void:
	_is_dead = true
	WaveManager.report_base_breached()
	EventBus.base_damaged.emit(data.damage_on_arrival, {"unit": data.unit_name})
	## Partial reward even on breach
	EconomyManager.add_resource(FactionManager.get_primary_resource(), data.resource_reward * 0.5)
	queue_free()

func _die() -> void:
	_is_dead = true
	WaveManager.report_enemy_killed()
	EconomyManager.add_resource(FactionManager.get_primary_resource(), data.resource_reward)
	EventBus.unit_died.emit({"unit": data.unit_name, "faction": data.faction_id})
	queue_free()

func _evolve() -> void:
	var hp_ratio : float = _current_health / data.max_health
	data            = data.evolved_unit
	_current_health = data.max_health * hp_ratio
	_visual.color   = data.color_hint
	_update_health_visual()

func _build_placeholder_visual() -> void:
	## 24×24 square centred on the node
	_visual          = ColorRect.new()
	_visual.size     = Vector2(24.0, 24.0)
	_visual.position = Vector2(-12.0, -12.0)
	_visual.color    = data.color_hint if data else Color.GRAY
	add_child(_visual)
	## Dark health-bar background
	var bar_bg          := ColorRect.new()
	bar_bg.size         = Vector2(24.0, 3.0)
	bar_bg.position     = Vector2(-12.0, -18.0)
	bar_bg.color        = Color(0.2, 0.2, 0.2)
	add_child(bar_bg)
	## Foreground fill (tracked by name)
	var bar_fg          := ColorRect.new()
	bar_fg.name         = "HealthBar"
	bar_fg.size         = Vector2(24.0, 3.0)
	bar_fg.position     = Vector2(-12.0, -18.0)
	bar_fg.color        = Color(0.2, 0.9, 0.2)
	add_child(bar_fg)

func _update_health_visual() -> void:
	var bar : ColorRect = get_node_or_null("HealthBar")
	if bar and data:
		bar.size.x = 24.0 * (_current_health / data.max_health)
