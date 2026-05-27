## Commander.gd
## The player's on-map representative. Click anywhere on the game world to move.
## As the Commander walks, GROUND cells they step through become CLAIMED territory.
## Approaching an enemy spawn zone activates that spawn for future waves.
##
## Phase D scope:
##   - Click-to-move (direct world-position movement, no AStar -- friendly units
##     are not constrained by the enemy path graph)
##   - Territory claiming: GROUND cells beneath the Commander become CLAIMED
##   - Spawn activation: within ACTIVATION_RADIUS cells of a new spawn, that
##     spawn is registered with MapGrid and added to WaveSpawner's active list
##     via EventBus.spawn_activated
##
## Phase E will add: resource generation from CLAIMED cells, patrol waypoints,
## friendly escort units.
extends Node2D

## How close (Manhattan distance in cells) the Commander must be to a spawn
## cell to trigger its activation. 4 cells ≈ 256 px.
const ACTIVATION_RADIUS    : int   = 4
const MOVE_SPEED           : float = 140.0   ## px/s
## Primary resource income bonus granted per claimed GROUND cell.
## At 0.05/s per cell: 10 cells = +0.5/s (50% bonus on top of base 1.0/s).
const RATE_PER_CLAIMED_CELL : float = 0.05

## All four cardinal spawn positions. SPAWN_W is pre-registered by WaveSpawner;
## the Commander seeds _activated_spawns with it to avoid a redundant signal.
const ALL_SPAWNS : Array = [
	Vector2i(0,  8),   ## SPAWN_W (pre-active)
	Vector2i(15, 0),   ## SPAWN_N
	Vector2i(15, 16),  ## SPAWN_S
	Vector2i(29, 8),   ## SPAWN_E
]

var _map_grid         : Node             = null   ## duck-typed; resolved in _ready
var _target_pos       : Vector2          = Vector2.ZERO
var _moving           : bool             = false
var _activated_spawns : Array[Vector2i]  = []
var _claimed_count    : int              = 0      ## cells claimed so far this session
var _visual           : ColorRect        = null
var _pip              : ColorRect        = null   ## centre indicator

func _ready() -> void:
	add_to_group("commander")
	## Path: WorldMap/CommanderLayer/Commander -> ../../MapGrid
	_map_grid = get_node_or_null("../../MapGrid")
	if _map_grid == null:
		push_error("Commander: could not resolve ../../MapGrid from %s." % get_path())
	_target_pos = global_position
	## SPAWN_W is already registered by WaveSpawner; mark it so we don't re-fire
	_activated_spawns.append(Vector2i(0, 8))
	_build_visual()
	## Check the starting cell; BASE type won't be claimed (guard in _try_claim_cell),
	## but this seeds the correct _map_grid reference path and is cheap.
	_try_claim_cell()

func _process(delta: float) -> void:
	if not _moving:
		return
	var to_target : Vector2 = _target_pos - global_position
	var dist      : float   = to_target.length()
	var step      : float   = MOVE_SPEED * delta
	if dist <= step:
		global_position = _target_pos
		_moving         = false
	else:
		global_position += to_target.normalized() * step
	_try_claim_cell()
	_check_spawn_activation()

## -- Input --

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed or mbe.button_index != MOUSE_BUTTON_LEFT:
		return
	## Respect HUD dead zones: top bar (0-48 px) and bottom bar (last 48 px).
	var vp_h : float = get_viewport().get_visible_rect().size.y
	if mbe.position.y < 48.0 or mbe.position.y > vp_h - 48.0:
		return
	_move_to(get_global_mouse_position())
	get_viewport().set_input_as_handled()

func _move_to(world_pos: Vector2) -> void:
	_target_pos = world_pos
	_moving     = true

## -- Territory claiming --

func _try_claim_cell() -> void:
	if _map_grid == null:
		return
	var cell : Vector2i = _map_grid.world_to_cell(global_position)
	## Only GROUND cells (type 0) can be claimed; PATH/BASE/SPAWN/OBSTACLE are skipped.
	if _map_grid.get_cell(cell.x, cell.y) != 0:   ## Cell.GROUND = 0
		return
	_map_grid.call("claim_cell", cell.x, cell.y)
	_claimed_count += 1
	## Each new cell adds a permanent passive income bonus for the primary resource.
	EconomyManager.add_territory_rate(
		FactionManager.get_primary_resource(),
		RATE_PER_CLAIMED_CELL
	)
	EventBus.territory_claimed.emit(cell)

## -- Spawn activation --

func _check_spawn_activation() -> void:
	if _map_grid == null:
		return
	var commander_cell : Vector2i = _map_grid.world_to_cell(global_position)
	for spawn in ALL_SPAWNS:
		if (spawn as Vector2i) in _activated_spawns:
			continue
		var manhattan : int = (
			abs(commander_cell.x - (spawn as Vector2i).x) +
			abs(commander_cell.y - (spawn as Vector2i).y)
		)
		if manhattan <= ACTIVATION_RADIUS:
			_activated_spawns.append(spawn)
			## Register with MapGrid connectivity validator first so the
			## WaveSpawner handler (connected to the same signal) can safely
			## call get_path_to_base() on the new spawn immediately.
			_map_grid.call("register_active_spawn", spawn)
			EventBus.spawn_activated.emit(spawn as Vector2i)

## -- Visual --

func _build_visual() -> void:
	## 32×32 gold body -- distinct from enemy units (24×24, grey/faction colour)
	_visual          = ColorRect.new()
	_visual.size     = Vector2(32.0, 32.0)
	_visual.position = Vector2(-16.0, -16.0)
	_visual.color    = Color(1.0, 0.82, 0.18, 1.0)   ## bright gold
	add_child(_visual)

	## Small white pip at centre -- a simple "star" marker
	_pip          = ColorRect.new()
	_pip.size     = Vector2(8.0, 8.0)
	_pip.position = Vector2(-4.0, -4.0)
	_pip.color    = Color(1.0, 1.0, 1.0, 0.9)
	add_child(_pip)

	## Dark health-style border outline (two thin edge rects give a frame)
	var top_bar          := ColorRect.new()
	top_bar.size         = Vector2(32.0, 2.0)
	top_bar.position     = Vector2(-16.0, -16.0)
	top_bar.color        = Color(0.2, 0.15, 0.0, 1.0)
	add_child(top_bar)

	var bot_bar          := ColorRect.new()
	bot_bar.size         = Vector2(32.0, 2.0)
	bot_bar.position     = Vector2(-16.0,  14.0)
	bot_bar.color        = Color(0.2, 0.15, 0.0, 1.0)
	add_child(bot_bar)
