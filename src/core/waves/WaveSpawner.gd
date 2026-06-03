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

## Pre-committed spawn distribution for the current wave.
## Maps spawn_id (StringName) → {count: int, position: Vector2i}.
## Built at wave_started, consumed by _spawn_unit, cleared at wave_ended.
## Emitted to EventBus as wave_axis_committed so the WavePanel can display axis pressure.
var _spawn_queue : Dictionary = {}

func _ready() -> void:
	_unit_layer = get_node_or_null("../UnitLayer") as Node2D
	_map_grid   = get_node_or_null("../MapGrid")   as Node2D
	if _unit_layer == null:
		push_error("WaveSpawner: could not find ../UnitLayer in WorldMap.")
	if _map_grid == null:
		push_error("WaveSpawner: could not find ../MapGrid in WorldMap.")

	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.path_changed.connect(_on_path_changed)
	EventBus.spawn_activated.connect(_on_spawn_activated)

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
	## Sync WaveManager to the actual unit count we will spawn, then tell the
	## HUD so the enemy counter shows the corrected number from the first frame.
	WaveManager.enemies_remaining = _units_to_spawn
	EventBus.enemy_count_changed.emit(_units_to_spawn)
	## Pre-commit spawn distribution and broadcast for the wave panel axis diagram.
	_build_spawn_queue(_units_to_spawn)
	var axis_weights : Dictionary = {}
	for spawn_id in _spawn_queue:
		axis_weights[spawn_id] = _spawn_queue[spawn_id].count
	EventBus.wave_axis_committed.emit(axis_weights)
	## Emit unit composition so WavePanel can show it when expanded.
	var unit_name : String = "Unknown"
	if _current_unit_data != null and _current_unit_data.get("unit_name") != null:
		unit_name = str(_current_unit_data.unit_name)
	EventBus.wave_composition_committed.emit(unit_name, _units_to_spawn)

func _on_wave_ended(_wave_number: int, _result: String) -> void:
	_spawning       = false
	_units_to_spawn = 0
	_spawn_queue.clear()
	## Free any units still alive (e.g. defeat before all spawned)
	if _unit_layer != null:
		for child in _unit_layer.get_children():
			child.queue_free()

## -- Spawn logic --

func _spawn_unit() -> void:
	if _unit_layer == null or _map_grid == null:
		push_error("WaveSpawner: missing UnitLayer or MapGrid -- cannot spawn.")
		return
	## Draw from the pre-committed queue; fall back to random active cells if queue
	## is empty (e.g. a new spawn activated mid-wave after queue was built).
	var chosen_spawn : Vector2i = _draw_from_queue()
	if chosen_spawn == Vector2i(-1, -1):
		var active : Array[Vector2i] = _get_active_spawn_cells()
		if active.is_empty():
			push_error("WaveSpawner: no active spawn points -- cannot spawn.")
			return
		chosen_spawn = active[randi() % active.size()]

	## Phase F: waves 6+ have an escalating chance to produce a flanker that
	## targets claimed territory instead of the base.
	var ratio : float = _flanker_ratio(WaveManager.current_wave)
	if ratio > 0.0 and randf() < ratio:
		var flank_path : Array = _map_grid.call("get_path_to_nearest_claimed", chosen_spawn)
		if not flank_path.is_empty():
			var target_world : Vector2   = flank_path[flank_path.size() - 1]
			var target_cell  : Vector2i  = _map_grid.call("world_to_cell", target_world)
			var flanker      : Node2D    = UNIT_SCENE.instantiate()
			flanker.call("setup_as_flanker", _current_unit_data, flank_path, target_cell, _map_grid)
			_unit_layer.add_child(flanker)
			_emit_unit_spawned()
			return
		## No accessible claimed cells -- fall through and spawn a normal base-rusher.

	## Normal base-rusher
	var wp_array : Array = _map_grid.get_path_to_base(chosen_spawn)
	if wp_array.is_empty():
		push_error("WaveSpawner: no path from spawn %s -- check MapGrid path connectivity." % chosen_spawn)
		return
	var unit : Node2D = UNIT_SCENE.instantiate()
	unit.call("setup", _current_unit_data, wp_array)
	_unit_layer.add_child(unit)
	_emit_unit_spawned()

## Fraction of units that are flankers for a given wave.
## 0 for waves 1-5; ramps 10% per wave from wave 6, capped at 50%.
## Wave 6=10%, wave 7=20%, wave 8=30%, wave 9=40%, wave 10+=50%.
func _flanker_ratio(wave_number: int) -> float:
	if wave_number < 6:
		return 0.0
	return clampf((wave_number - 5) * 0.10, 0.0, 0.50)

func _emit_unit_spawned() -> void:
	EventBus.unit_spawned.emit({
		"unit": _current_unit_data.unit_name if _current_unit_data else "unknown",
		"wave": WaveManager.current_wave,
	})

## Phase 4: spawn_activated now carries a spawn_id (StringName), and the activation
## itself is performed by MapData.activate_spawn_by_id() inside Commander BEFORE the
## signal fires. We don't need to maintain a local cache — _get_active_spawn_cells()
## reads fresh from MapData. This handler is a hook for future UI/notification work.
func _on_spawn_activated(_spawn_id: StringName) -> void:
	pass

## Builds _spawn_queue by distributing total_units across active spawns.
## Equal split; remainder units go to the first spawns in list order.
## Each entry: { count: int, position: Vector2i }
func _build_spawn_queue(total_units: int) -> void:
	_spawn_queue.clear()
	if _map_grid == null:
		return
	var data : MapData = _map_grid.get("map_data") as MapData
	if data == null:
		return
	var active_spawns : Array[SpawnPoint] = data.get_active_spawn_points()
	if active_spawns.is_empty():
		return
	var k          : int = active_spawns.size()
	@warning_ignore("integer_division")
	var base_share : int = total_units / k
	var remainder  : int = total_units % k
	for i in range(k):
		var sp    : SpawnPoint = active_spawns[i]
		var share : int        = base_share + (1 if i < remainder else 0)
		_spawn_queue[sp.id] = { count = share, position = sp.position }

## Picks a spawn from the pre-committed queue (weighted by remaining count),
## decrements its counter, and returns its map position.
## Reads position BEFORE erasing to avoid key-missing errors.
## Returns Vector2i(-1, -1) when the queue is exhausted.
func _draw_from_queue() -> Vector2i:
	var pool : Array[StringName] = []
	for spawn_id in _spawn_queue:
		var entry : Dictionary = _spawn_queue[spawn_id]
		for _i in range(entry.count):
			pool.append(spawn_id)
	if pool.is_empty():
		return Vector2i(-1, -1)
	var chosen_id  : StringName = pool[randi() % pool.size()]
	var position   : Vector2i   = _spawn_queue[chosen_id].position
	_spawn_queue[chosen_id].count -= 1
	if _spawn_queue[chosen_id].count <= 0:
		_spawn_queue.erase(chosen_id)
	return position

## Returns the currently-active spawn cells, queried from MapData via MapGrid.
## Returns an empty array if either reference is missing.
func _get_active_spawn_cells() -> Array[Vector2i]:
	if _map_grid == null:
		return ([] as Array[Vector2i])
	var data : MapData = _map_grid.get("map_data") as MapData
	if data == null:
		return ([] as Array[Vector2i])
	return data.get_active_spawn_cells()

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
