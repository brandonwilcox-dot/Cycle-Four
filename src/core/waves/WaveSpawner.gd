## WaveSpawner.gd
## Attached to the WorldMap scene. Reads the active WaveTable and spawns
## Unit instances into UnitLayer using MapGrid-computed waypoints.
## Phase B: units are Node2D with waypoint navigation, not PathFollow2D.
## Listens to WaveManager signals; never drives wave state itself.
extends Node

const UNIT_SCENE : PackedScene = preload("res://scenes/main/Unit.tscn")

## Loaded when faction is confirmed.
var _wave_table        : Resource = null   ## WaveTable; typed Resource to avoid load-order issues

## Resolved in _ready() from sibling nodes in WorldMap.
var _unit_layer        : Node2D   = null
var _map_grid          : Node2D   = null   ## MapGrid instance; methods called via duck typing

var _spawn_timer       : float    = 0.0
var _units_to_spawn    : int      = 0
var _current_unit_data : UnitData = null
var _spawn_interval    : float    = 1.2
var _spawning          : bool     = false

## Active spawn point this wave. Defaults to west; Phase D adds others.
## Vector2i matching MapGrid spawn constants.
var _spawn_cell : Vector2i = Vector2i(0, 8)   ## SPAWN_W_POS

func _ready() -> void:
	_unit_layer = get_node_or_null("../UnitLayer") as Node2D
	_map_grid   = get_node_or_null("../MapGrid")   as Node2D
	if _unit_layer == null:
		push_error("WaveSpawner: could not find ../UnitLayer in WorldMap.")
	if _map_grid == null:
		push_error("WaveSpawner: could not find ../MapGrid in WorldMap.")
	else:
		## Tell MapGrid which spawn is active so the connectivity validator
		## only protects routes that are actually sending enemies.
		## Phase D will call register_active_spawn() for N/S/E when those go live.
		_map_grid.call("register_active_spawn", _spawn_cell)

	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.path_changed.connect(_on_path_changed)

func _process(delta: float) -> void:
	if not _spawning or _units_to_spawn <= 0:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_unit()
		_units_to_spawn -= 1
		_spawn_timer = _spawn_interval
		if _units_to_spawn <= 0:
			_spawning = false

## -- Signal handlers --

func _on_faction_selected(faction_id: String, _sub_path: String) -> void:
	var path : String = "res://resources/factions/%s/wave_table.tres" % faction_id
	if ResourceLoader.exists(path):
		_wave_table = load(path)
	else:
		_wave_table = null   ## Procedural fallback

func _on_wave_started(wave_number: int, _commander_data: Dictionary) -> void:
	if _wave_table == null:
		_start_procedural_wave(wave_number)
	else:
		var wave_def : Dictionary = _wave_table.get_wave(wave_number)
		_current_unit_data = wave_def.get("unit", null)
		_units_to_spawn    = int(wave_def.get("count",    5 + wave_number * 2))
		_spawn_interval    = float(wave_def.get("interval", 1.2))
		_spawn_timer       = 0.0
		_spawning          = true
	## Sync WaveManager to the actual unit count we will spawn
	WaveManager.enemies_remaining = _units_to_spawn

func _on_wave_ended(_wave_number: int, _result: String) -> void:
	_spawning       = false
	_units_to_spawn = 0
	## Free any units still alive (e.g. defeat before all spawned)
	if _unit_layer != null:
		for child in _unit_layer.get_children():
			child.queue_free()

## -- Spawn logic --

func _spawn_unit() -> void:
	if _unit_layer == null or _map_grid == null:
		push_error("WaveSpawner: missing UnitLayer or MapGrid -- cannot spawn.")
		return
	## Get world-space waypoints from the map grid (returned as Array[Vector2])
	var wp_array : Array = _map_grid.get_path_to_base(_spawn_cell)
	if wp_array.is_empty():
		push_error("WaveSpawner: no path from spawn %s -- check MapGrid path connectivity." % _spawn_cell)
		return
	var unit : Node2D = UNIT_SCENE.instantiate()
	unit.call("setup", _current_unit_data, wp_array)
	_unit_layer.add_child(unit)
	EventBus.unit_spawned.emit({
		"unit": _current_unit_data.unit_name if _current_unit_data else "unknown",
		"wave": WaveManager.current_wave,
	})

func _on_path_changed() -> void:
	## A tower was placed on a PATH cell mid-wave. Tell every in-flight unit
	## to recalculate its route via the updated AStar graph.
	if _unit_layer == null or _map_grid == null:
		return
	for child in _unit_layer.get_children():
		if is_instance_valid(child) and child.has_method("reroute"):
			child.call("reroute", _map_grid)

func _start_procedural_wave(wave_number: int) -> void:
	## No wave table: synthesise UnitData scaled to the wave number.
	##
	## Balance targets (Phase A):
	##   Wave 1 : 6 units, 45 HP, 80 px/s  -- FOB solos it comfortably
	##   Wave 2 : 8 units, 55 HP, 85 px/s  -- needs 1 tower to be safe
	##   Wave 3 : 10 units, 65 HP, 90 px/s -- needs 2 towers; tight but winnable
	##   Wave 4+: continues scaling; challenge grows meaningfully each wave
	##
	## DPS check: FOB (27 DPS) + two T1 towers (~20 DPS each) = 67 DPS.
	## Wave 3 kill rate: 67 / 65 ≈ 1.03 kills/s vs 0.83 spawns/s -- clears with margin.
	var w : int = wave_number
	var fallback               := UnitData.new()
	fallback.unit_name         = "Remnant"
	fallback.faction_id        = "unknown"
	fallback.tier              = 1
	fallback.max_health        = 35.0 + w * 10.0          ## 45 / 55 / 65 / 75 ...
	fallback.move_speed        = clampf(75.0 + w * 5.0, 75.0, 160.0)  ## 80 / 85 / 90 ... cap 160
	fallback.damage_on_arrival = 1.0
	fallback.armor             = maxf(0.0, (w - 4) * 1.0) ## armor appears at wave 5+
	fallback.resource_reward   = w * 2.0                  ## 2 / 4 / 6 ... rewards escalate
	fallback.color_hint        = Color(0.6, 0.6, 0.6, 1.0)
	_current_unit_data = fallback
	_units_to_spawn    = 4 + w * 2                        ## 6 / 8 / 10 / 12 ...
	_spawn_interval    = clampf(1.6 - w * 0.08, 0.7, 1.6) ## 1.52 / 1.44 / 1.36 ... floor 0.7
	_spawn_timer       = 0.0
	_spawning          = true
