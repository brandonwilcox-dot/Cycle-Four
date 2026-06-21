## Unit.gd
## Enemy unit. Navigates a pre-computed world-space waypoint list from spawn to base.
## Spawned by WaveSpawner via setup(); reports death/arrival through WaveManager/EventBus.
## Phase B: uses Node2D + waypoint movement instead of PathFollow2D.
## Phase F: flanker variant targets CLAIMED territory instead of the base.
extends Node2D

const Combat = preload("res://src/combat/Combat.gd")

## Injected by WaveSpawner before the node enters the scene tree.
var data : UnitData = null

## Waypoints in world space (cell centres). Index 0 is the spawn position.
## Movement begins toward index 1; arrival triggers advance to next index.
var _waypoints     : Array[Vector2] = []
var _wp_index      : int            = 1
const ARRIVE_DIST  : float          = 3.0   ## px -- close enough to snap to waypoint

## C2 — two-way combat. When a friendly army unit blocks our path (within
## MELEE_ENGAGE_RANGE) we stop advancing and grind it down on MELEE_INTERVAL. Damage uses
## our faction's signature type vs the friendly's armor (the one triangle). ENEMY_MELEE_DAMAGE
## is a fallback for roster units whose .tres hasn't authored attack_damage yet.
const MELEE_ENGAGE_RANGE : float = 40.0
const MELEE_INTERVAL     : float = 1.0
const ENEMY_MELEE_DAMAGE : float = 8.0
var _melee_timer : float = 0.0

var _current_health   : float    = 0.0
var _is_dead          : bool     = false
var _visual           : ColorRect = null   ## placeholder until sprites exist
var _speed_multiplier : float    = 1.0    ## set by AbilityController (Suppression Field)
var _stun_until       : float    = -1.0   ## timestamp; movement skipped while now < _stun_until

## Stealth detection counterplay: recomputed on a throttle; true while this unit is
## inside an active detector's radius (FOB / Commander / detector tower).
const DETECT_RECOMPUTE_PERIOD : float = 0.15
var _detect_timer     : float    = 0.0
var _is_detected      : bool     = false

## Item 4 — tiered reveal for stealth units. Inside a detector's SIGHT radius (get_detector_radius)
## = FULL (drawn fully, targetable). Inside its larger SENSOR radius (get_sensor_radius, or a default
## multiple) = BLIP (a dim position marker, health bar hidden, NOT targetable). Outside both = HIDDEN.
## Non-stealth units ignore this entirely and use plain fog (revealed cell).
enum RevealTier { HIDDEN, BLIP, FULL }
var _reveal_tier      : RevealTier = RevealTier.HIDDEN
## Default sensor (blip) ring = this × a detector's sight radius, for detectors that don't expose their
## own get_sensor_radius() (towers, garrisons, FOB). The Commander overrides with its drawn sensor ring.
const SENSOR_RADIUS_MULT : float = 1.6

## Phase F -- flanker state.
## Flankers target a CLAIMED cell instead of the base.
## _target_cell = Vector2i(-1,-1) means "not a flanker / target already gone".
var _is_flanker    : bool     = false
var _target_cell   : Vector2i = Vector2i(-1, -1)
var _map_grid_ref  : Node     = null
## Must match Commander.RATE_PER_CLAIMED_CELL (0.05). Kept here to avoid coupling.
const TERRITORY_RATE_PER_CELL : float = 0.05
const RAID_RESOURCE_PENALTY   : float = 15.0   ## primary resources stolen on a successful raid

func _ready() -> void:
	add_to_group("units")
	if data == null:
		push_error("Unit spawned without UnitData -- call setup() before adding to tree.")
		return
	_current_health = data.max_health
	_build_placeholder_visual()
	## Phase 6/8: cache MapGrid reference so we can hide ourselves in unrevealed cells.
	## Flankers already have _map_grid_ref set via setup_as_flanker; for normal units
	## resolve it from the scene tree (UnitLayer/Unit → ../../MapGrid).
	if _map_grid_ref == null:
		_map_grid_ref = get_node_or_null("../../MapGrid")
	## Phase 9 polish: apply fog visibility immediately at spawn so units don't flash
	## for one frame before _process runs.
	_update_fog_visibility()

func _process(delta: float) -> void:
	if _is_dead or _waypoints.is_empty():
		return
	## Stealth: refresh the live reveal tier on a throttle (scans the detectors group).
	if data != null and data.stealth:
		_detect_timer -= delta
		if _detect_timer <= 0.0:
			_detect_timer = DETECT_RECOMPUTE_PERIOD
			_reveal_tier = _compute_reveal_tier()
			_is_detected = _reveal_tier == RevealTier.FULL
	## Phase 6/8: hide while inside unrevealed cells. Enemies emerging from the fog
	## should only appear once their cell enters the Commander's vision.
	_update_fog_visibility()
	## Stun check: freeze movement for the duration. Status-immune units skip this.
	if _stun_until > 0.0 and Time.get_ticks_msec() / 1000.0 < _stun_until:
		return
	## C2: if a friendly army unit is blocking us, stop advancing and fight it. This is what
	## lets the player's garrisons hold a line instead of being walked past.
	var foe : Node2D = _engaged_friendly()
	if foe != null:
		_melee_timer += delta
		if _melee_timer >= MELEE_INTERVAL:
			_melee_timer = 0.0
			if foe.has_method("take_damage"):
				foe.call("take_damage", _melee_damage(), Combat.faction_damage_type(data.faction_id))
		return
	## Flankers: if our target was already raided by another unit, grab the next one.
	## get_cell() is an O(1) array lookup -- safe to call every frame.
	if _is_flanker and _target_cell != Vector2i(-1, -1) and _map_grid_ref != null:
		if _map_grid_ref.get_cell(_target_cell.x, _target_cell.y) != 9:   ## no longer CLAIMED
			_retarget_flanker()
	if _wp_index >= _waypoints.size():
		if _is_flanker:
			_raid_territory()
		else:
			_reach_base()
		return
	## Move toward the current waypoint
	var target     : Vector2 = _waypoints[_wp_index]
	var to_target  : Vector2 = target - global_position
	var dist       : float   = to_target.length()
	var step       : float   = data.move_speed * _speed_multiplier * delta
	if dist <= step or dist <= ARRIVE_DIST:
		global_position = target
		_wp_index += 1
	else:
		global_position += to_target.normalized() * step

## Phase 6/8: toggles self.visible based on the cell the unit currently occupies.
## Revealed → visible. Unrevealed → hidden. Cheap: one cell→idx math + one byte read.
## Once revealed cells are permanent within a session, this naturally fades units
## into view as the Commander explores.
func _update_fog_visibility() -> void:
	if _map_grid_ref == null:
		return
	var map_data : MapData = _map_grid_ref.get("map_data") as MapData
	if map_data == null:
		return
	var cell : Vector2i = _map_grid_ref.world_to_cell(global_position)
	if cell.x < 0 or cell.x >= map_data.dimensions.x or cell.y < 0 or cell.y >= map_data.dimensions.y:
		return
	var idx : int = cell.x + cell.y * map_data.dimensions.x
	## Stealth units use the tiered reveal: FULL = drawn fully, BLIP = dim position marker
	## (health bar hidden), HIDDEN = invisible. Normal units use sight/fog (revealed cell).
	if data != null and data.stealth:
		visible = _reveal_tier != RevealTier.HIDDEN
		_apply_reveal_visual(_reveal_tier == RevealTier.FULL)
	else:
		visible = map_data.get_meta_revealed(idx)

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

## Variant of setup() for flanker units (Phase F).
## Waypoints lead to the adjacent PATH cell; the final element is the CLAIMED cell itself.
## Flankers render with a red tint so the player can tell them apart at a glance.
func setup_as_flanker(unit_data: UnitData, waypoints: Array,
		target_cell: Vector2i, map_grid: Node) -> void:
	setup(unit_data, waypoints)
	_is_flanker   = true
	_target_cell  = target_cell
	_map_grid_ref = map_grid

## Called by WaveSpawner when EventBus.path_changed fires mid-wave.
## Finds the nearest traversable cell to current position and gets a fresh
## path to base from there. No-ops if the unit is dead or has no waypoints.
func reroute(map_grid: Node) -> void:
	if _is_dead or _waypoints.is_empty():
		return
	var nearest_cell : Vector2i = map_grid.get_nearest_path_cell(global_position)
	if _is_flanker:
		## Flankers re-find the nearest accessible claimed cell from their current position.
		var flank_path : Array = map_grid.call("get_path_to_nearest_claimed", nearest_cell)
		if not flank_path.is_empty():
			_waypoints.assign(flank_path)
			_wp_index    = 1
			## Update target to the last waypoint (the CLAIMED cell world position)
			_target_cell = map_grid.call("world_to_cell", _waypoints[_waypoints.size() - 1])
			return
		## No accessible claimed cells left -- demote to a base-rusher
		_is_flanker  = false
		_target_cell = Vector2i(-1, -1)
	var new_path : Array = map_grid.get_path_to_base(nearest_cell)
	if new_path.is_empty():
		return
	_waypoints.assign(new_path)
	_wp_index = 1

## Sets a speed multiplier applied by the Suppression Field. Call with 1.0 to clear.
## Status-immune units ignore the slow but the call is safe to make unconditionally.
func set_debuff(speed_mult: float) -> void:
	if data != null and data.status_immune:
		return
	_speed_multiplier = speed_mult

## Freezes movement for duration seconds. No-op on status-immune units.
func apply_stun(duration: float) -> void:
	if data != null and data.status_immune:
		return
	_stun_until = Time.get_ticks_msec() / 1000.0 + duration

## Stealth gating (Pass 2): non-stealth units are always detectable. Stealth units
## are only visible/targetable while standing in a sensed cell (a sensor sphere).
## Attackers call this before locking on; AoE abilities ignore it.
func is_detectable() -> bool:
	if data == null or not data.stealth:
		return true
	return _is_detected

## C2: nearest friendly army unit within melee range, or null. Drives blocking + retaliation.
func _engaged_friendly() -> Node2D:
	var best   : Node2D = null
	var best_d : float  = MELEE_ENGAGE_RANGE
	for f in get_tree().get_nodes_in_group("friendly_units"):
		if not is_instance_valid(f) or not (f is Node2D):
			continue
		var d : float = global_position.distance_to((f as Node2D).global_position)
		if d <= best_d:
			best   = f
			best_d = d
	return best

## Melee damage we deal to a blocking friendly. Falls back to a constant when the roster
## resource hasn't authored attack_damage (it's tuned as a marching wave unit).
func _melee_damage() -> float:
	return maxf(data.attack_damage, ENEMY_MELEE_DAMAGE)

## Strongest reveal tier any active detector (FOB, Commander, tower, garrison) grants us this scan.
## Inside a detector's sight radius → FULL; inside its larger sensor radius → BLIP; else HIDDEN.
## Returns early on the first FULL (the best possible); otherwise tracks the best tier seen.
func _compute_reveal_tier() -> RevealTier:
	var best : RevealTier = RevealTier.HIDDEN
	for d in get_tree().get_nodes_in_group("detectors"):
		if not (d is Node2D) or not is_instance_valid(d):
			continue
		if not d.has_method("get_detector_radius"):
			continue
		var sight : float = float(d.call("get_detector_radius"))
		if sight <= 0.0:
			continue
		var dist : float = global_position.distance_to((d as Node2D).global_position)
		if dist <= sight:
			return RevealTier.FULL
		var sensor : float = float(d.call("get_sensor_radius")) if d.has_method("get_sensor_radius") else sight * SENSOR_RADIUS_MULT
		if dist <= sensor:
			best = RevealTier.BLIP
	return best

## Apply incoming damage. damage_type (Combat.DamageType, -1 = untyped contact damage)
## scales the hit against this unit's armor_type before flat armor is subtracted.
## Returns true if the unit died.
func take_damage(amount: float, damage_type: int = -1) -> bool:
	if _is_dead:
		return true
	var mult : float = Combat.multiplier(damage_type, data.armor_type) if damage_type >= 0 else 1.0
	var effective : float = max(0.0, amount * mult - data.armor)
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

## Called when our target CLAIMED cell was taken by another flanker while en route.
## Finds the nearest remaining CLAIMED cell and re-routes to it.
## Falls back to base-rushing if no claimed cells remain.
func _retarget_flanker() -> void:
	var nearest_cell : Vector2i = _map_grid_ref.get_nearest_path_cell(global_position)
	var flank_path   : Array    = _map_grid_ref.call("get_path_to_nearest_claimed", nearest_cell)
	if not flank_path.is_empty():
		_waypoints.assign(flank_path)
		_wp_index = 1
		## Derive target cell from the last waypoint (world-space centre of CLAIMED cell).
		var last_wp  : Vector2  = _waypoints[_waypoints.size() - 1]
		_target_cell = Vector2i(int(last_wp.x) / 64, int(last_wp.y) / 64)
	else:
		## No claimed territory left -- demote to a base-rusher.
		_is_flanker  = false
		_target_cell = Vector2i(-1, -1)
		var base_path : Array = _map_grid_ref.get_path_to_base(nearest_cell)
		if not base_path.is_empty():
			_waypoints.assign(base_path)
			_wp_index = 1

## Flanker arrived at its target CLAIMED cell.
## Unclaims it, penalises the economy, and counts as cleared for wave tracking.
func _raid_territory() -> void:
	_is_dead = true
	if _map_grid_ref != null and _target_cell != Vector2i(-1, -1):
		## Guard: another flanker may have raided this cell first (race condition).
		if _map_grid_ref.get_cell(_target_cell.x, _target_cell.y) == 9:   ## Cell.CLAIMED
			_map_grid_ref.call("unclaim_cell", _target_cell.x, _target_cell.y)
			var primary : String = FactionManager.get_primary_resource()
			## Steal resources and remove this cell's passive income contribution.
			EconomyManager.add_resource(primary, -RAID_RESOURCE_PENALTY)
			EconomyManager.add_territory_rate(primary, -TERRITORY_RATE_PER_CELL)
			EventBus.territory_raided.emit(_target_cell)
	## Count as cleared so the wave can end normally.
	WaveManager.report_enemy_killed()
	queue_free()

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
	## 24×24 square centred on the node.
	## Flankers get a red-orange tint so the player can read intent at a glance.
	_visual          = ColorRect.new()
	_visual.size     = Vector2(24.0, 24.0)
	_visual.position = Vector2(-12.0, -12.0)
	_visual.color    = Color(1.0, 0.35, 0.1) if _is_flanker else (data.color_hint if data else Color.GRAY)
	## Stealth units read as cloaked (translucent cyan shimmer) when a detector reveals them.
	if data != null and data.stealth:
		_visual.modulate = Color(0.6, 0.85, 1.0, 0.85)
	add_child(_visual)
	## Dark health-bar background (named so the BLIP tier can hide it — item 4)
	var bar_bg          := ColorRect.new()
	bar_bg.name         = "HealthBarBG"
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

	## Decorative Controls must not eat world clicks (default MOUSE_FILTER_STOP
	## would consume LMB before it reaches selection/placement handlers).
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_health_visual() -> void:
	var bar : ColorRect = get_node_or_null("HealthBar")
	if bar and data:
		bar.size.x = 24.0 * (_current_health / data.max_health)

## Item 4: applies the reveal visual for a stealth unit. full=true → normal render + health bar;
## full=false (BLIP) → the node is dimmed and the health bar hidden, so it reads as a position-only
## marker with no full info. Called every fog update while the unit is a detected stealth unit.
func _apply_reveal_visual(full: bool) -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0) if full else Color(1.0, 1.0, 1.0, 0.4)
	var hb  : CanvasItem = get_node_or_null("HealthBar")   as CanvasItem
	var hbg : CanvasItem = get_node_or_null("HealthBarBG") as CanvasItem
	if hb != null:
		hb.visible = full
	if hbg != null:
		hbg.visible = full

## Item 5: how this enemy should appear on the minimap — 0 = off the minimap, 1 = dim blip,
## 2 = full marker. Stealth units mirror their world reveal tier (so an undetected stealth unit
## never shows, even in a revealed cell); normal units show only inside a revealed cell.
func minimap_reveal() -> int:
	if data != null and data.stealth:
		match _reveal_tier:
			RevealTier.FULL:
				return 2
			RevealTier.BLIP:
				return 1
			_:
				return 0
	if _map_grid_ref == null:
		return 2
	var md : MapData = _map_grid_ref.get("map_data") as MapData
	if md == null:
		return 2
	var cell : Vector2i = _map_grid_ref.world_to_cell(global_position)
	if cell.x < 0 or cell.x >= md.dimensions.x or cell.y < 0 or cell.y >= md.dimensions.y:
		return 0
	var idx : int = cell.x + cell.y * md.dimensions.x
	return 2 if md.get_meta_revealed(idx) else 0
