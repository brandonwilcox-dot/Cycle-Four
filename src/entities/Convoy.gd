## Convoy.gd
## Phase 8 — a persistent logistics convoy that ferries back and forth between
## a depot and the FOB along the discovered ancient path.
##
## Lifecycle: spawned ONCE per discovered depot by ConvoyManager. Loops forever:
##   depot -> FOB (loaded with cargo)
##   pause at FOB to unload (fires convoy_arrived, cargo credited)
##   FOB -> depot (returning empty)
##   pause at depot to load
##   repeat
##
## Phase 8b will add HP / destruction by flankers. For Phase 8 stub, convoys are
## invulnerable and never queue_free — they ferry indefinitely.
class_name Convoy
extends Node2D

const ProgressionBarScript = preload("res://src/ui/ProgressionBar.gd")

const CONVOY_BASE_SPEED    : float = 90.0    ## px/s base, scales with rank
const SPEED_PER_RANK       : float = 0.05    ## +5% per rank, matches Commander
const LOAD_UNLOAD_TIME     : float = 1.5     ## seconds paused at each endpoint
const VISUAL_SIZE          : float = 18.0
const VISUAL_COLOR_HINT    : Color = Color(0.30, 0.65, 0.95, 1.0)  ## light blue — distinct from gold commander
const VISUAL_COLOR_EMPTY   : Color = Color(0.55, 0.55, 0.60, 0.85) ## grey while returning empty
const VISUAL_OUTLINE_COLOR : Color = Color(0.05, 0.20, 0.40, 1.0)
const DEFAULT_CARGO_AMOUNT : float = 1.0

## Phase 9: proficiency. Continuous multiplier on output, grows logarithmically per
## delivery — diminishing returns mean the first ~30 deliveries matter most. Death
## resets to 1.0 per handoff §8.2 ("death is a setback"); Phase 8b will wire the
## actual reset when flanker damage lands.
const PROFICIENCY_BASE     : float = 1.0
const PROFICIENCY_GROWTH   : float = 0.5     ## controls curve steepness
const DELIVERIES_PER_RANK  : int   = 10      ## rank up display milestone (visual only)

@export var convoy_id    : StringName = &""
@export var from_node_id : StringName = &""   ## the depot (loop endpoint A)
@export var to_node_id   : StringName = &""   ## the FOB (loop endpoint B)
@export var cargo_amount : float      = DEFAULT_CARGO_AMOUNT

## World-space waypoints from depot (index 0) to FOB (last index). Set by ConvoyManager.
var route_world : Array[Vector2] = []

## State machine. +1 = depot→FOB (loaded), -1 = FOB→depot (empty).
## When _pause_timer > 0 the convoy is unloading (at FOB) or loading (at depot).
var _waypoint_index : int   = 0
var _direction      : int   = 1
var _pause_timer    : float = 0.0

## Phase 9 progression.
var proficiency      : float = PROFICIENCY_BASE
var _deliveries_made : int   = 0
var _current_speed   : float = CONVOY_BASE_SPEED

var _visual     : ColorRect = null
var _rank_bar   : Node2D    = null   ## ProgressionBar instance
var _convoy_rank : int      = 0
var _map_grid   : Node      = null   ## cached parent; used for fog visibility lookups

func _ready() -> void:
	add_to_group("convoys")
	_build_visual()
	if route_world.size() < 2:
		push_error("Convoy: route too short (%d waypoints) — destroying." % route_world.size())
		queue_free()
		return
	## Convoy is parented to MapGrid; route_world is in MapGrid's local space.
	_map_grid = get_parent()
	position = route_world[0]
	_waypoint_index = 1   ## first target
	## Phase 9 polish: apply fog visibility immediately at spawn — depots live in fog,
	## so without this the convoy flashes for one frame before _process hides it.
	_update_fog_visibility()

func _process(delta: float) -> void:
	if _pause_timer > 0.0:
		_pause_timer -= delta
		_update_fog_visibility()   ## still respect fog while idling at endpoints
		return
	var target : Vector2 = route_world[_waypoint_index]
	var to_target : Vector2 = target - position
	var dist : float = to_target.length()
	var step : float = _current_speed * delta
	if dist <= step:
		position = target
		_on_waypoint_reached()
	else:
		position += to_target.normalized() * step
	_update_fog_visibility()

## Phase 6/8: convoys obey the same fog rule as enemy units — visible only in
## revealed cells. Without this the convoy looks like it "leaves the map" when it
## returns to its depot in unexplored territory.
func _update_fog_visibility() -> void:
	if _map_grid == null:
		return
	var map_data : MapData = _map_grid.get("map_data") as MapData
	if map_data == null:
		return
	var cell : Vector2i = _map_grid.world_to_cell(position)
	if cell.x < 0 or cell.x >= map_data.dimensions.x or cell.y < 0 or cell.y >= map_data.dimensions.y:
		return
	var idx : int = cell.x + cell.y * map_data.dimensions.x
	visible = map_data.get_meta_revealed(idx)

## Called when we arrive at the cell at route_world[_waypoint_index].
## Decides whether to advance, reverse (at an endpoint), or pause.
func _on_waypoint_reached() -> void:
	var last_idx : int = route_world.size() - 1
	if _direction == 1 and _waypoint_index == last_idx:
		## Arrived at FOB loaded — deliver cargo (scaled by proficiency), pause,
		## then head back. Phase 9: proficiency grows logarithmically per delivery
		## with diminishing returns.
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
		_convoy_rank = _deliveries_made / DELIVERIES_PER_RANK
		if _convoy_rank > prev_rank:
			_current_speed = CONVOY_BASE_SPEED * pow(1.0 + SPEED_PER_RANK, float(_convoy_rank))
		_update_rank_bar()
		_pause_timer    = LOAD_UNLOAD_TIME
		_direction      = -1
		_waypoint_index = last_idx - 1
		_set_visual_color(VISUAL_COLOR_EMPTY)
	elif _direction == -1 and _waypoint_index == 0:
		## Arrived back at depot empty — pause to load, then head forward again.
		_pause_timer    = LOAD_UNLOAD_TIME
		_direction      = 1
		_waypoint_index = 1
		_set_visual_color(VISUAL_COLOR_HINT)
	else:
		_waypoint_index += _direction

## -- Visual --

## Phase 9: bar fills 0–100% per DELIVERIES_PER_RANK deliveries, then resets when
## the rank advances. Visual signal of accumulated proficiency.
func _update_rank_bar() -> void:
	if _rank_bar == null:
		return
	var into_rank : int = _deliveries_made % DELIVERIES_PER_RANK
	_rank_bar.set_progress(float(into_rank) / float(DELIVERIES_PER_RANK))

func _build_visual() -> void:
	## A small blue square (loaded) / grey (empty) with darker outline. Distinct
	## from gold Commander and grey/faction enemies so glance-reading the world
	## tells the player which entity is which.
	_visual          = ColorRect.new()
	_visual.size     = Vector2(VISUAL_SIZE, VISUAL_SIZE)
	_visual.position = Vector2(-VISUAL_SIZE * 0.5, -VISUAL_SIZE * 0.5)
	_visual.color    = VISUAL_COLOR_HINT
	add_child(_visual)
	var outline_top := ColorRect.new()
	outline_top.size     = Vector2(VISUAL_SIZE, 1.5)
	outline_top.position = Vector2(-VISUAL_SIZE * 0.5, -VISUAL_SIZE * 0.5)
	outline_top.color    = VISUAL_OUTLINE_COLOR
	add_child(outline_top)
	var outline_bottom := ColorRect.new()
	outline_bottom.size     = Vector2(VISUAL_SIZE, 1.5)
	outline_bottom.position = Vector2(-VISUAL_SIZE * 0.5,  VISUAL_SIZE * 0.5 - 1.5)
	outline_bottom.color    = VISUAL_OUTLINE_COLOR
	add_child(outline_bottom)
	## Phase 9: rank progression bar above the convoy.
	_rank_bar = ProgressionBarScript.new()
	_rank_bar.position = Vector2(0.0, -VISUAL_SIZE * 0.5 - 8.0)
	add_child(_rank_bar)
	_update_rank_bar()

func _set_visual_color(c: Color) -> void:
	if _visual != null:
		_visual.color = c
