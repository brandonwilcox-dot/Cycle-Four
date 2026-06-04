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

## Phase 6: vision radius (Chebyshev/square) in cells. Cells within this radius of
## the Commander become permanently revealed. ON_REVEAL spawns inside the revealed
## region activate via the EventBus.region_revealed → ObjectiveManager path.
const VISION_RADIUS         : int   = 3    ## LoS ring: fog reveal, spawn activation, convoy gating
const SENSOR_RADIUS         : int   = 9    ## Sensor ring: objective detection without activation
const MOVE_BASE_SPEED       : float = 140.0   ## px/s base, modified by rank
## Primary resource income bonus granted per claimed GROUND cell.
## At 0.05/s per cell: 10 cells = +0.5/s (50% bonus on top of base 1.0/s).
const RATE_PER_CLAIMED_CELL : float = 0.05
## Phase 9: rank advances every N cells claimed and scales speed + attack damage.
## Subtle so the unit doesn't blur across the screen at high rank.
const CELLS_PER_RANK        : int   = 25
const SPEED_PER_RANK        : float = 0.05    ## +5% move speed per rank
const DAMAGE_PER_RANK       : float = 0.10    ## +10% attack damage per rank

## Phase 9: combat. Range matches vision (cells within range are also visible) so
## the Commander only attacks what the player can see.
const ATTACK_RANGE_PX       : float = VISION_RADIUS * 64.0
const PRIMARY_INTERVAL      : float = 0.4     ## seconds between rapid-fire shots
const PRIMARY_DAMAGE        : float = 8.0     ## per shot
## Secondary cannon removed — now slot 0 (Lance) in AbilityController.
const SHOT_FLASH_DURATION   : float = 0.08    ## brief Line2D auto-clean

const PRIMARY_LINE_COLOR    : Color = Color(1.00, 0.95, 0.40, 0.85)
const CANNON_RING_COLOR     : Color = Color(1.00, 0.55, 0.18, 0.70)

const CELL_SIZE_PX          : float = 64.0
const LOS_RING_COLOR        : Color = Color(1.00, 1.00, 0.80, 0.35)
const SENSOR_RING_COLOR     : Color = Color(0.40, 0.80, 1.00, 0.18)

const ProgressionBarScript = preload("res://src/ui/ProgressionBar.gd")

var _map_grid       : Node      = null   ## duck-typed; resolved in _ready
var _target_pos     : Vector2   = Vector2.ZERO
var _moving         : bool      = false
var _claimed_count  : int       = 0      ## cells claimed so far this session
var _commander_rank : int       = 0      ## Phase 9 rank derived from _claimed_count
var _rank_bar       : Node2D    = null   ## ProgressionBar instance
var _visual         : ColorRect = null
var _pip            : ColorRect = null   ## centre indicator

## Tracks cells already emitted via region_sensed so we don't re-emit each frame.
var _sensed_cell_set    : Dictionary = {}

## Phase 9: combat + speed.
var _current_move_speed : float = MOVE_BASE_SPEED
var _damage_multiplier  : float = 1.0
var _primary_timer      : float = 0.0

## Untyped: AbilityController class_name isn't registered when Commander.gd parses.
## Same pattern as ConvoyManager/Convoy. Duck-typed access is safe at runtime.
var _ability_controller = null

func _ready() -> void:
	add_to_group("commander")
	## Path: WorldMap/CommanderLayer/Commander -> ../../MapGrid
	_map_grid = get_node_or_null("../../MapGrid")
	if _map_grid == null:
		push_error("Commander: could not resolve ../../MapGrid from %s." % get_path())
	_target_pos = global_position
	_build_visual()
	_ability_controller = get_node_or_null("AbilityController")
	## Check the starting cell; BASE type won't be claimed (guard in _try_claim_cell),
	## but this seeds the correct _map_grid reference path and is cheap.
	_try_claim_cell()
	## Phase 6: do an initial reveal pass from the spawn point so the Commander's
	## starting vicinity is visible regardless of where it was placed in the scene.
	_reveal_around()
	queue_redraw()

func _process(delta: float) -> void:
	## Primary attack timer — interval halved while Overdrive is active.
	_primary_timer -= delta
	if _primary_timer <= 0.0:
		var interval : float = PRIMARY_INTERVAL
		if _ability_controller != null and _ability_controller.is_overdrive_active:
			interval *= _ability_controller.overdrive_interval_mult
		_primary_timer = interval
		_try_primary_attack()

	if not _moving:
		return
	var to_target : Vector2 = _target_pos - global_position
	var dist      : float   = to_target.length()
	var step      : float   = _current_move_speed * delta
	if dist <= step:
		global_position = _target_pos
		_moving         = false
	else:
		global_position += to_target.normalized() * step
	_try_claim_cell()
	_reveal_around()

## -- Input --

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed or mbe.button_index != MOUSE_BUTTON_LEFT:
		return
	## During the Academy phase no faction has been selected yet — leave clicks
	## for CadetAvatar to handle. Commander movement resumes after selection.
	if GameState.current_faction.is_empty():
		return
	## Respect HUD dead zones: top bar (0-48 px) and bottom bar (last 48 px).
	var vp_h : float = get_viewport().get_visible_rect().size.y
	if mbe.position.y < 48.0 or mbe.position.y > vp_h - 48.0:
		return
	## Ground-targeting mode: deliver click to AbilityController instead of moving.
	if _ability_controller != null and _ability_controller.targeting_active:
		_ability_controller.deliver_target(get_global_mouse_position())
		get_viewport().set_input_as_handled()
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
	## Phase 9: track rank progression. Bumps speed + attack damage on each rank.
	var prev_rank : int = _commander_rank
	@warning_ignore("integer_division")
	_commander_rank = _claimed_count / CELLS_PER_RANK
	if _commander_rank > prev_rank:
		_recompute_rank_stats()
	_update_rank_bar()
	## Each new cell adds a permanent passive income bonus for the primary resource.
	EconomyManager.add_territory_rate(
		FactionManager.get_primary_resource(),
		RATE_PER_CLAIMED_CELL
	)
	EventBus.territory_claimed.emit(cell)

## -- Spawn activation --

## Phase 6: writes meta.revealed for every cell within VISION_RADIUS of the Commander,
## collects newly-revealed cells, and emits region_revealed. ObjectiveManager subscribes
## to that signal and handles ON_REVEAL spawn activation.
## Performance: bounded by (2*VISION_RADIUS+1)² cells; never scans the full grid.
## LoS ring: reveals cells within VISION_RADIUS (Chebyshev) and emits region_revealed.
## Sensor ring: collects cells within SENSOR_RADIUS but outside the LoS ring that have
## not yet been sensed, and emits region_sensed. ObjectiveManager handles the rest.
func _reveal_around() -> void:
	if _map_grid == null:
		return
	var data : MapData = _map_grid.get("map_data") as MapData
	if data == null:
		return
	var commander_cell : Vector2i = _map_grid.world_to_cell(global_position)

	## LoS pass.
	var newly_revealed : Array[Vector2i] = []
	for dy in range(-VISION_RADIUS, VISION_RADIUS + 1):
		for dx in range(-VISION_RADIUS, VISION_RADIUS + 1):
			var col : int = commander_cell.x + dx
			var row : int = commander_cell.y + dy
			if col < 0 or col >= data.dimensions.x:
				continue
			if row < 0 or row >= data.dimensions.y:
				continue
			var idx : int = col + row * data.dimensions.x
			if data.get_meta_revealed(idx):
				continue
			data.set_meta_revealed(idx, true)
			newly_revealed.append(Vector2i(col, row))
	if not newly_revealed.is_empty():
		EventBus.region_revealed.emit(newly_revealed)
		_map_grid.queue_redraw()

	## Sensor pass: annular region outside LoS but inside SENSOR_RADIUS.
	var newly_sensed : Array[Vector2i] = []
	for dy in range(-SENSOR_RADIUS, SENSOR_RADIUS + 1):
		for dx in range(-SENSOR_RADIUS, SENSOR_RADIUS + 1):
			if absi(dx) <= VISION_RADIUS and absi(dy) <= VISION_RADIUS:
				continue   ## inside LoS ring — already handled above
			var col : int = commander_cell.x + dx
			var row : int = commander_cell.y + dy
			if col < 0 or col >= data.dimensions.x:
				continue
			if row < 0 or row >= data.dimensions.y:
				continue
			var cell : Vector2i = Vector2i(col, row)
			if _sensed_cell_set.has(cell):
				continue
			var idx : int = col + row * data.dimensions.x
			if data.get_meta_revealed(idx):
				continue   ## already revealed; no need to sense
			_sensed_cell_set[cell] = true
			newly_sensed.append(cell)
	if not newly_sensed.is_empty():
		EventBus.region_sensed.emit(newly_sensed)

## -- Visual --

## Public getter used by AbilityController to scale ability damage by rank.
func get_damage_multiplier() -> float:
	return _damage_multiplier

## Draws LoS ring, sensor ring, and active Suppression Field in local space.
func _draw() -> void:
	var los_r    : float = (VISION_RADIUS  + 0.5) * CELL_SIZE_PX
	var sensor_r : float = (SENSOR_RADIUS  + 0.5) * CELL_SIZE_PX
	draw_arc(Vector2.ZERO, sensor_r, 0.0, TAU, 64, SENSOR_RING_COLOR, 1.5, true)
	draw_arc(Vector2.ZERO, los_r,    0.0, TAU, 32, LOS_RING_COLOR,    2.0, true)
	if _ability_controller != null and _ability_controller.field_active:
		var field_local : Vector2 = _ability_controller.field_center - global_position
		var field_r     : float   = _ability_controller.FIELD_RADIUS_PX
		draw_circle(field_local, field_r, Color(0.40, 0.80, 1.00, 0.12))
		draw_arc(field_local, field_r, 0.0, TAU, 48, Color(0.40, 0.80, 1.00, 0.65), 2.0)
	## Bloom biomass hazard: dim green disc after field expires.
	if _ability_controller != null and _ability_controller.hazard_active:
		var hazard_local : Vector2 = _ability_controller.hazard_center - global_position
		var hazard_r     : float   = _ability_controller.FIELD_RADIUS_PX
		draw_circle(hazard_local, hazard_r, Color(0.20, 0.55, 0.15, 0.18))
		draw_arc(hazard_local, hazard_r, 0.0, TAU, 48, Color(0.25, 0.70, 0.20, 0.55), 2.0)

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

	## Phase 9: rank progression bar above the Commander.
	_rank_bar = ProgressionBarScript.new()
	_rank_bar.position = Vector2(0.0, -24.0)
	add_child(_rank_bar)
	_update_rank_bar()

func _update_rank_bar() -> void:
	if _rank_bar == null:
		return
	var into_rank : int = _claimed_count % CELLS_PER_RANK
	_rank_bar.set_progress(float(into_rank) / float(CELLS_PER_RANK))

## Phase 9: rank advances apply subtle multiplicative bonuses to speed and damage.
## Called from _try_claim_cell() whenever _commander_rank increments.
func _recompute_rank_stats() -> void:
	_current_move_speed = MOVE_BASE_SPEED * pow(1.0 + SPEED_PER_RANK, float(_commander_rank))
	_damage_multiplier  = pow(1.0 + DAMAGE_PER_RANK, float(_commander_rank))

## -- Phase 9 combat --

## Rapid-fire single-target hit on the nearest enemy in range.
## Damage is boosted while Overdrive is active.
func _try_primary_attack() -> void:
	var target : Node2D = _find_nearest_unit_in_range()
	if target == null:
		return
	var dmg : float = PRIMARY_DAMAGE * _damage_multiplier
	if _ability_controller != null and _ability_controller.is_overdrive_active:
		dmg *= _ability_controller.overdrive_damage_mult
	target.take_damage(dmg)
	EventBus.commander_attacked.emit()
	_spawn_shot_line(target.global_position, PRIMARY_LINE_COLOR, 2.0)
	if _ability_controller != null:
		_ability_controller.add_lance_charge(dmg)
		_ability_controller.on_primary_hit()

func _find_nearest_unit_in_range() -> Node2D:
	var best : Node2D  = null
	var best_dist : float = ATTACK_RANGE_PX
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var dist : float = global_position.distance_to(unit.global_position)
		if dist < best_dist:
			best_dist = dist
			best      = unit
	return best

## Brief yellow Line2D from Commander to target, auto-frees after SHOT_FLASH_DURATION.
func _spawn_shot_line(target_world: Vector2, col: Color, width: float) -> void:
	var line := Line2D.new()
	line.add_point(Vector2.ZERO)
	line.add_point(target_world - global_position)
	line.width         = width
	line.default_color = col
	add_child(line)
	get_tree().create_timer(SHOT_FLASH_DURATION).timeout.connect(line.queue_free)

## Brief orange ring centred on the Commander, marking the cannon AOE.
func _spawn_cannon_ring() -> void:
	var ring := ColorRect.new()
	var size : float = ATTACK_RANGE_PX * 2.0
	ring.size     = Vector2(size, size)
	ring.position = Vector2(-size * 0.5, -size * 0.5)
	ring.color    = CANNON_RING_COLOR
	add_child(ring)
	get_tree().create_timer(SHOT_FLASH_DURATION * 2.0).timeout.connect(ring.queue_free)
