## WaveSpawner.gd
## Attached to the WorldMap scene. Reads the active WaveTable and spawns
## Unit instances into UnitLayer using MapGrid-computed waypoints.
## Phase B: units are Node2D with waypoint navigation, not PathFollow2D.
## Listens to WaveManager signals; never drives wave state itself.
extends Node

const UNIT_SCENE          : PackedScene = preload("res://scenes/main/Unit.tscn")
const _WAVE_TABLE_BUILDER = preload("res://src/core/waves/WaveTableBuilder.gd")

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

## Phase B — faction-flavored pathing. Each active spawn caches a small set of distinct
## routes to base (from MapGrid.get_diverse_paths_to_base); per-faction policy then picks
## one per unit: Architects = most direct, Bloom = even sprawl, Mesh = least-defended.
## Caches are keyed by spawn cell and invalidated on wave start/end and path_changed.
const DIVERSE_ROUTE_K    : int   = 3
const MESH_PROBE_CHANCE  : float = 0.25   ## Mesh occasionally probes a non-optimal route
const ROUTE_THREAT_RADIUS : float = 160.0 ## px; a tower within this of a route adds threat
var _route_cache : Dictionary = {}   ## Vector2i spawn cell → Array of routes (Array[Vector2])
var _route_uses  : Dictionary = {}   ## Vector2i spawn cell → Array[int] per-route use counts

## Scripted overrides: wave_number (int) → {secondary_count: int}.
## When the keyed wave starts a secondary (non-primary) active spawn is chosen and
## secondary_count extra units are injected into the spawn queue from that axis.
## If no secondary spawn is active the override is silently skipped.
var scripted_overrides : Dictionary = {}

func _ready() -> void:
	_unit_layer = get_node_or_null("../UnitLayer") as Node2D
	_map_grid   = get_node_or_null("../MapGrid")   as Node2D
	if _unit_layer == null:
		push_error("WaveSpawner: could not find ../UnitLayer in WorldMap.")
	if _map_grid == null:
		push_error("WaveSpawner: could not find ../MapGrid in WorldMap.")

	scripted_overrides = { 3: { secondary_count = 3 } }

	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.path_changed.connect(_on_path_changed)
	EventBus.spawn_activated.connect(_on_spawn_activated)
	EventBus.academy_spawn_requested.connect(_on_academy_spawn)
	EventBus.academy_clear_units.connect(_on_academy_clear)

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

func _on_faction_selected(player_faction: String, _sub_path: String) -> void:
	## Phase A: waves are an ENEMY faction (the other factions contest the same
	## territory), not the player's own units. This engages the damage/armor triangle —
	## the player faces an armor type their signature damage is weak against and must
	## adapt via FOB doctrine / tower branches.
	var enemy : String = _WAVE_TABLE_BUILDER.enemy_of(player_faction)
	var path : String = "res://resources/factions/%s/wave_table.tres" % enemy
	if ResourceLoader.exists(path):
		_wave_table = load(path)
	else:
		_wave_table = _WAVE_TABLE_BUILDER.build(enemy)
	EventBus.notification_pushed.emit("Hostile faction on this front: %s." % enemy.capitalize(), "alert")
	_emit_preview(1)   ## show wave-1 intel as soon as the faction is known

## Computes a wave's composition WITHOUT spawning, for the standby preview.
func _peek_composition(wave_number: int) -> Dictionary:
	if _wave_table != null:
		var wd : Dictionary = _wave_table.get_wave(wave_number)
		var ud = wd.get("unit", null)
		var nm : String = str(ud.unit_name) if ud != null and ud.get("unit_name") != null else "Unknown"
		var ct : int = int(wd.get("count", 5 + wave_number * 2))
		return {"unit_name": nm, "count": ct}
	return {"unit_name": "Remnant", "count": 4 + wave_number * 2}

func _emit_preview(wave_number: int) -> void:
	var comp : Dictionary = _peek_composition(wave_number)
	EventBus.wave_previewed.emit(wave_number, str(comp.unit_name), int(comp.count))

func _on_wave_started(wave_number: int, _commander_data: Dictionary) -> void:
	_clear_route_cache()   ## Phase B: rebuild faction routes against the current map/towers.
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
	_apply_scripted_override(wave_number)
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
	_clear_route_cache()
	## Free any units still alive (e.g. defeat before all spawned)
	if _unit_layer != null:
		for child in _unit_layer.get_children():
			child.queue_free()
	## Preview the next wave during the standby/grace period.
	_emit_preview(WaveManager.current_wave + 1)

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

	## Normal base-rusher — Phase B picks a route per the enemy faction's movement norm.
	var wp_array : Array = _faction_path(chosen_spawn)
	if wp_array.is_empty():
		push_error("WaveSpawner: no path from spawn %s -- check MapGrid path connectivity." % chosen_spawn)
		return
	var unit : Node2D = UNIT_SCENE.instantiate()
	unit.call("setup", _current_unit_data, wp_array)
	_unit_layer.add_child(unit)
	_emit_unit_spawned()

## -- Phase B: faction-flavored pathing --

## Returns the waypoint route this unit should take, chosen by the enemy faction's
## movement norm (codex §05). Falls back to the plain shortest path for unknown factions
## or when the map offers no route set.
func _faction_path(spawn_cell: Vector2i) -> Array:
	var routes : Array = _routes_for(spawn_cell)
	if routes.is_empty():
		return _map_grid.get_path_to_base(spawn_cell)
	var faction : String = ""
	if _current_unit_data != null and _current_unit_data.get("faction_id") != null:
		faction = str(_current_unit_data.faction_id)
	var idx : int = 0
	match faction:
		"architects":
			idx = 0                                          ## direct: efficiency, shortest route
		"bloom":
			idx = _least_used_route_idx(spawn_cell)          ## sprawl: even spread across all routes
		"mesh":
			idx = _weakpoint_route_idx(spawn_cell, routes)   ## raider: seek the soft route, then commit
		_:
			idx = 0
	idx = clampi(idx, 0, routes.size() - 1)
	(_route_uses[spawn_cell] as Array)[idx] += 1
	return routes[idx]

## Lazily builds and caches the diverse route set (and a use-count tally) for a spawn cell.
func _routes_for(spawn_cell: Vector2i) -> Array:
	if not _route_cache.has(spawn_cell):
		var routes : Array = _map_grid.call("get_diverse_paths_to_base", spawn_cell, DIVERSE_ROUTE_K)
		_route_cache[spawn_cell] = routes
		var uses : Array[int] = []
		uses.resize(routes.size())
		uses.fill(0)
		_route_uses[spawn_cell] = uses
	return _route_cache[spawn_cell]

## Bloom sprawl: pick the route used least so far, so units fan out evenly across every
## available corridor instead of forming a single conga line.
func _least_used_route_idx(spawn_cell: Vector2i) -> int:
	var uses : Array = _route_uses[spawn_cell]
	var best : int = 0
	for i in range(uses.size()):
		if uses[i] < uses[best]:
			best = i
	return best

## Mesh weak-point seek: mostly commit down the least-defended route, occasionally probe
## another to find new gaps. "Defended" = towers within ROUTE_THREAT_RADIUS of the route.
func _weakpoint_route_idx(_spawn_cell: Vector2i, routes: Array) -> int:
	if routes.size() > 1 and randf() < MESH_PROBE_CHANCE:
		return randi() % routes.size()
	var best        : int   = 0
	var best_threat : float = INF
	for i in range(routes.size()):
		var t : float = _route_threat(routes[i])
		if t < best_threat:
			best_threat = t
			best        = i
	return best

## Counts defensive presence along a route: each tower within ROUTE_THREAT_RADIUS of any
## waypoint adds 1. Higher = better defended (Mesh avoids); used only for route selection.
func _route_threat(path: Array) -> float:
	var threat : float = 0.0
	for d in get_tree().get_nodes_in_group("towers"):
		if not (d is Node2D) or not is_instance_valid(d):
			continue
		var dp : Vector2 = (d as Node2D).global_position
		for wp in path:
			if dp.distance_to(wp) <= ROUTE_THREAT_RADIUS:
				threat += 1.0
				break
	return threat

## Invalidates the cached route sets (call when wave boundaries change or a tower
## reshapes the path graph, so routes are recomputed against the current map).
func _clear_route_cache() -> void:
	_route_cache.clear()
	_route_uses.clear()

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
	## Re-verify hook (BUG[P1] "enemies from one spawn only"): log active-spawn count and
	## per-spawn distribution at every wave start so a playtest confirms multi-direction
	## emission. Debug-gated; remove once the multi-spawn fix is confirmed in play.
	if OS.is_debug_build():
		var dist : PackedStringArray = []
		for sid in _spawn_queue:
			dist.append("%s=%d" % [str(sid), int(_spawn_queue[sid].count)])
		print("[WaveSpawner] wave distribution — active spawns=%d: %s" % [k, ", ".join(dist)])

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

## Injects extra units from a non-primary axis when a scripted override exists for this wave.
func _apply_scripted_override(wave_number: int) -> void:
	if not scripted_overrides.has(wave_number):
		return
	var override     : Dictionary = scripted_overrides[wave_number]
	var secondary_pos : Vector2i  = _pick_secondary_spawn_pos()
	if secondary_pos == Vector2i(-1, -1):
		return
	var secondary_id  : StringName = _get_spawn_id_at(secondary_pos)
	if secondary_id == &"":
		return
	var extra : int = int(override.get("secondary_count", 3))
	if _spawn_queue.has(secondary_id):
		_spawn_queue[secondary_id].count += extra
	else:
		_spawn_queue[secondary_id] = { count = extra, position = secondary_pos }
	_units_to_spawn             += extra
	WaveManager.enemies_remaining = _units_to_spawn
	EventBus.enemy_count_changed.emit(_units_to_spawn)
	EventBus.wave_flank_triggered.emit(wave_number)

## Returns the position of an active spawn that is NOT the primary (highest-count) axis.
## Returns Vector2i(-1, -1) if no secondary spawn is available.
func _pick_secondary_spawn_pos() -> Vector2i:
	var primary_id  : StringName = &""
	var max_count   : int        = -1
	for spawn_id in _spawn_queue:
		if _spawn_queue[spawn_id].count > max_count:
			max_count  = _spawn_queue[spawn_id].count
			primary_id = spawn_id
	var data : MapData = _map_grid.get("map_data") as MapData
	if data == null:
		return Vector2i(-1, -1)
	for sp : SpawnPoint in data.get_active_spawn_points():
		if sp.id != primary_id:
			return sp.position
	return Vector2i(-1, -1)

## Looks up the SpawnPoint id for a given map cell position.
func _get_spawn_id_at(pos: Vector2i) -> StringName:
	var data : MapData = _map_grid.get("map_data") as MapData
	if data == null:
		return &""
	var sp : SpawnPoint = data.get_spawn_at(pos)
	return sp.id if sp != null else &""

func _on_path_changed() -> void:
	## A tower was placed on a PATH cell mid-wave. Tell every in-flight unit
	## to recalculate its route via the updated AStar graph.
	if _unit_layer == null or _map_grid == null:
		return
	_clear_route_cache()   ## Phase B: the graph changed — recompute faction routes for new spawns.
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

## -- Academy spawning --

## Spawns one enemy unit at the map spawn point identified by spawn_idx.
## Uses all spawn_points from MapData regardless of activation state.
## Wraps idx if fewer spawn points than requested.
func _on_academy_spawn(spawn_idx: int, count: int) -> void:
	if _unit_layer == null or _map_grid == null or count <= 0:
		return
	var data : MapData = _map_grid.get("map_data") as MapData
	if data == null or data.spawn_points.is_empty():
		return
	var idx : int = spawn_idx % data.spawn_points.size()
	var sp  : SpawnPoint = data.spawn_points[idx]
	var unit_res : Resource = load("res://resources/units/architect_t1.tres")
	if unit_res == null:
		push_error("WaveSpawner: academy unit resource missing.")
		return
	for _i in count:
		var wp_array : Array = _map_grid.get_path_to_base(sp.position)
		if wp_array.is_empty():
			continue
		var unit : Node2D = UNIT_SCENE.instantiate()
		unit.call("setup", unit_res, wp_array)
		_unit_layer.add_child(unit)

## Frees all units in the unit layer. Called between Academy scenarios.
func _on_academy_clear() -> void:
	if _unit_layer == null:
		return
	for child in _unit_layer.get_children():
		if is_instance_valid(child):
			child.queue_free()
