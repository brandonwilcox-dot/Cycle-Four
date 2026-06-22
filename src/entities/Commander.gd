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

const Combat = preload("res://src/combat/Combat.gd")

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
## Veterancy cap: rank stops here, bounding speed/damage AND the sight/sensor growth
## below (rank 15 → ×2.08 speed, ×4.18 dmg, LoS 3→6, sensor 9→14).
const RANK_CAP             : int   = 15
## Sight/sensor grow with rank: +1 LoS cell per 5 ranks (max +3), +1 sensor per 3
## ranks (max +5). Since the Commander claims its LoS, leveling widens territory too.
const LOS_RANKS_PER_STEP   : int   = 5
const LOS_BONUS_MAX        : int   = 3
const SENSOR_RANKS_PER_STEP : int  = 3
const SENSOR_BONUS_MAX     : int   = 5

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

## RTS selection + move-order visuals (right-click to move, shift to chain).
const SELECT_RING_COLOR  : Color = Color(0.40, 1.00, 0.55, 0.90)
const MOVE_PATH_COLOR    : Color = Color(0.55, 0.85, 1.00, 0.85)
const SELECT_RING_RADIUS : float = 44.0

const ProgressionBarScript = preload("res://src/ui/ProgressionBar.gd")
const RankChevronsScript   = preload("res://src/ui/RankChevrons.gd")

var _map_grid       : Node      = null   ## duck-typed; resolved in _ready
var _move_queue     : Array[Vector2] = []   ## queued move waypoints (world space); RTS chaining
var _selected       : bool      = false     ## true when the player has the Commander selected
## SupCom-style: the queued move path is hidden during normal movement and only drawn
## while Shift is held, so the player can preview + chain waypoints on demand.
var _shift_held     : bool      = false
var _claimed_count  : int       = 0      ## cells claimed so far this session
var _commander_rank : int       = 0      ## Phase 9 rank derived from _claimed_count
var _rank_bar       : Node2D    = null   ## ProgressionBar instance
var _rank_chevrons  : Node2D    = null   ## RankChevrons instance
var _visual         : ColorRect = null
var _pip            : ColorRect = null   ## centre indicator

## Tracks cells already emitted via region_sensed so we don't re-emit each frame.
var _sensed_cell_set    : Dictionary = {}

## Phase 9: combat + speed.
var _current_move_speed : float = MOVE_BASE_SPEED
var _damage_multiplier  : float = 1.0
var _primary_timer      : float = 0.0
var _cannon_ring_t      : float = 0.0   ## seconds remaining to draw the Lance/cannon AOE ring

## Untyped: AbilityController class_name isn't registered when Commander.gd parses.
## Same pattern as ConvoyManager/Convoy. Duck-typed access is safe at runtime.
var _ability_controller = null

func _ready() -> void:
	add_to_group("commander")
	add_to_group("detectors")   ## the Commander is a mobile stealth detector (line of sight)
	## Path: WorldMap/CommanderLayer/Commander -> ../../MapGrid
	_map_grid = get_node_or_null("../../MapGrid")
	if _map_grid == null:
		push_error("Commander: could not resolve ../../MapGrid from %s." % get_path())
	_build_visual()
	_ability_controller = get_node_or_null("AbilityController")
	## Claim the Commander's starting sight ring (BASE/PATH cells are skipped inside
	## claim_area), seeding initial territory around the FOB.
	_claim_around()
	## Phase 6: do an initial reveal pass from the spawn point so the Commander's
	## starting vicinity is visible regardless of where it was placed in the scene.
	_reveal_around()
	queue_redraw()

func _process(delta: float) -> void:
	## Toggle the move-path overlay with the Shift key (SupCom-style waypoint preview).
	## Only redraw on a state change, and only when selected — the path is meaningless otherwise.
	var shift_now : bool = Input.is_key_pressed(KEY_SHIFT)
	if shift_now != _shift_held:
		_shift_held = shift_now
		if _selected:
			queue_redraw()

	## Primary attack timer — interval halved while Overdrive is active.
	_primary_timer -= delta
	if _primary_timer <= 0.0:
		var interval : float = PRIMARY_INTERVAL
		if _ability_controller != null and _ability_controller.is_overdrive_active:
			interval *= _ability_controller.overdrive_interval_mult
		_primary_timer = interval
		_try_primary_attack()

	## Fade the Lance/cannon AOE ring (drawn in _draw); keep redrawing while it shows.
	if _cannon_ring_t > 0.0:
		_cannon_ring_t -= delta
		queue_redraw()

	## Queue-driven movement: walk toward the first waypoint, pop it on arrival, and
	## continue down any chained waypoints (shift-queued). Idle when the queue is empty.
	if _move_queue.is_empty():
		return
	var target    : Vector2 = _move_queue[0]
	var to_target : Vector2 = target - global_position
	var dist      : float   = to_target.length()
	var step      : float   = _current_move_speed * delta
	if dist <= step:
		global_position = target
		_move_queue.pop_front()
		queue_redraw()   ## the drawn path just got shorter
	else:
		global_position += to_target.normalized() * step
	## While the path overlay is showing, redraw each frame so its origin stays anchored
	## to the moving Commander (the line is drawn relative to global_position).
	if _shift_held and _selected:
		queue_redraw()
	_claim_around()
	_reveal_around()

## -- Input --

## The Commander no longer moves on left-click. Selection (left-click) and move orders
## (right-click, shift to chain) are routed by Main. This handler only delivers a
## ground-targeted ability cast (e.g. Suppression Field) to the AbilityController.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed or mbe.button_index != MOUSE_BUTTON_LEFT:
		return
	if _ability_controller != null and _ability_controller.targeting_active:
		_ability_controller.deliver_target(get_global_mouse_position())
		get_viewport().set_input_as_handled()

## -- Selection + move orders (called by Main) --

func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	queue_redraw()

func is_selected() -> bool:
	return _selected

## Issues a move order to world_pos. append=true (shift) chains it after existing
## waypoints; append=false replaces the queue with a single destination.
func move_command(world_pos: Vector2, append: bool) -> void:
	if not append:
		_move_queue.clear()
	_move_queue.append(world_pos)
	queue_redraw()

## -- Territory claiming --

func _claim_around() -> void:
	if _map_grid == null:
		return
	var cell : Vector2i = _map_grid.world_to_cell(global_position)
	## Claim every GROUND cell within the Commander's line-of-sight ring, not just the
	## one underfoot — territory flows from sight range as the Commander explores. As
	## rank raises LoS, the claimed swath widens too.
	var newly = _map_grid.call("claim_area", cell, _los_radius())
	if newly == null or newly.is_empty():
		return
	for nc in newly:
		EconomyManager.register_claimed_cell()
		EventBus.territory_claimed.emit(nc)
	_claimed_count += newly.size()
	## Phase 9: rank progression bumps speed + attack damage as territory grows.
	## Capped at RANK_CAP so a maxed Commander has bounded stats and sight.
	var prev_rank : int = _commander_rank
	@warning_ignore("integer_division")
	_commander_rank = mini(_claimed_count / CELLS_PER_RANK, RANK_CAP)
	if _commander_rank > prev_rank:
		_recompute_rank_stats()
		if _rank_chevrons != null:
			_rank_chevrons.call("set_rank", _commander_rank)
	_update_rank_bar()

## Current line-of-sight radius (cells), growing with veterancy rank up to the cap.
func _los_radius() -> int:
	@warning_ignore("integer_division")
	return VISION_RADIUS + mini(_commander_rank / LOS_RANKS_PER_STEP, LOS_BONUS_MAX)

## Current sensor radius (cells), growing with veterancy rank up to the cap.
func _sensor_radius() -> int:
	@warning_ignore("integer_division")
	return SENSOR_RADIUS + mini(_commander_rank / SENSOR_RANKS_PER_STEP, SENSOR_BONUS_MAX)

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
	var los    : int = _los_radius()
	var sensor : int = _sensor_radius()

	## LoS pass.
	var newly_revealed : Array[Vector2i] = []
	for dy in range(-los, los + 1):
		for dx in range(-los, los + 1):
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

	## Sensor pass: annular region outside LoS but inside the sensor radius.
	var newly_sensed : Array[Vector2i] = []
	for dy in range(-sensor, sensor + 1):
		for dx in range(-sensor, sensor + 1):
			if absi(dx) <= los and absi(dy) <= los:
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
	var los_r    : float = (_los_radius()    + 0.5) * CELL_SIZE_PX
	var sensor_r : float = (_sensor_radius() + 0.5) * CELL_SIZE_PX
	draw_arc(Vector2.ZERO, sensor_r, 0.0, TAU, 64, SENSOR_RING_COLOR, 1.5, true)
	draw_arc(Vector2.ZERO, los_r,    0.0, TAU, 32, LOS_RING_COLOR,    2.0, true)
	## Selection ring is always shown while selected. A faint outer halo + a thick bright
	## ring make the selected state obvious even at the zoomed-out default. The queued move
	## path is drawn only while Shift is held (SupCom-style) — hidden during normal movement.
	if _selected:
		var halo : Color = Color(SELECT_RING_COLOR.r, SELECT_RING_COLOR.g, SELECT_RING_COLOR.b, 0.30)
		draw_arc(Vector2.ZERO, SELECT_RING_RADIUS + 7.0, 0.0, TAU, 40, halo, 2.0, true)
		draw_arc(Vector2.ZERO, SELECT_RING_RADIUS, 0.0, TAU, 40, SELECT_RING_COLOR, 4.0, true)
		if _shift_held and not _move_queue.is_empty():
			var pts : PackedVector2Array = PackedVector2Array()
			pts.append(Vector2.ZERO)
			for wp in _move_queue:
				pts.append(wp - global_position)
			draw_polyline(pts, MOVE_PATH_COLOR, 2.0, true)
			for wp in _move_queue:
				draw_circle(wp - global_position, 4.0, MOVE_PATH_COLOR)
	## Lance / cannon AOE — a circle at attack range, kept inside the sightline boundary.
	if _cannon_ring_t > 0.0:
		draw_circle(Vector2.ZERO, ATTACK_RANGE_PX, Color(CANNON_RING_COLOR.r, CANNON_RING_COLOR.g, CANNON_RING_COLOR.b, 0.16))
		draw_arc(Vector2.ZERO, ATTACK_RANGE_PX, 0.0, TAU, 48, CANNON_RING_COLOR, 2.5, true)
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
	_rank_bar.z_index = 20
	add_child(_rank_bar)
	_update_rank_bar()
	## Veterancy chevrons above the rank bar. High z_index so the moving Commander's
	## sight/sensor rings (drawn in _draw) never visually swallow them.
	_rank_chevrons = RankChevronsScript.new()
	_rank_chevrons.position = Vector2(0.0, -30.0)
	_rank_chevrons.z_index = 20
	add_child(_rank_chevrons)

	## CRITICAL: the gold body is a ColorRect (a Control) — by default MOUSE_FILTER_STOP, so it
	## consumes left-clicks in _gui_input before they reach _unhandled_input, i.e. clicking
	## directly ON the Commander failed to select it. Make all visual Controls click-through.
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	target.take_damage(dmg, Combat.faction_damage_type(FactionManager.active_faction))
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
		## Stealth: the Commander's auto-attack can't lock an undetected unit.
		if unit.has_method("is_detectable") and not unit.call("is_detectable"):
			continue
		var dist : float = global_position.distance_to(unit.global_position)
		if dist < best_dist:
			best_dist = dist
			best      = unit
	return best

## Stealth detection (px): the Commander FULLY reveals stealth within its drawn LoS ring (item 2 —
## tracks the live sight ring, which grows with rank). Matches the on-screen ring so "inside the ring
## = revealed" holds. The larger sensor ring gives a position-only blip (item 4, get_sensor_radius).
func get_detector_radius() -> float:
	return (float(_los_radius()) + 0.5) * CELL_SIZE_PX

## Sensor (blip) radius (px): matches the drawn sensor ring. A stealth unit between the LoS ring and
## this shows as a dim position-only blip (no full info / not targetable) rather than a full reveal.
func get_sensor_radius() -> float:
	return (float(_sensor_radius()) + 0.5) * CELL_SIZE_PX

## Brief yellow Line2D from Commander to target, auto-frees after SHOT_FLASH_DURATION.
func _spawn_shot_line(target_world: Vector2, col: Color, width: float) -> void:
	var line := Line2D.new()
	line.add_point(Vector2.ZERO)
	line.add_point(target_world - global_position)
	line.width         = width
	line.default_color = col
	add_child(line)
	get_tree().create_timer(SHOT_FLASH_DURATION).timeout.connect(line.queue_free)

## Flashes the Lance/cannon AOE as a circle (drawn in _draw) for a brief moment.
func _spawn_cannon_ring() -> void:
	_cannon_ring_t = SHOT_FLASH_DURATION * 6.0
	queue_redraw()
