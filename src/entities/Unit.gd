## Unit.gd
## Enemy unit. Navigates a pre-computed waypoint list from spawn to base.
## Spawned by WaveSpawner via setup(); reports death/arrival through WaveManager/EventBus.
##
## 3D MIGRATION (Stage 2): now `extends Node3D`. Simulation stays on a logical 2D plane —
## `_p` is the authoritative plane position (pixel units, the old Vector2 world coords); the
## Node3D transform is driven from it via World3D (`_set_plane`/`_sync_transform`). Cross-entity
## reads go through `plane_pos()` / `World3D.node_plane()` so 2D and not-yet-converted entities
## interoperate during the migration. Visual is a MeshInstance3D (was a ColorRect).
extends Node3D

const Combat = preload("res://src/combat/Combat.gd")
const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")
const WORLD3D = preload("res://src/core/World3D.gd")

## Injected by WaveSpawner before the node enters the scene tree.
var data : UnitData = null

## Logical plane position (pixel units) — the authoritative position; the 3D transform follows it.
var _p : Vector2 = Vector2.ZERO

## Waypoints on the plane (cell centres). Index 0 is the spawn position.
## Movement begins toward index 1; arrival triggers advance to next index.
var _waypoints     : Array[Vector2] = []
var _wp_index      : int            = 1
const ARRIVE_DIST  : float          = 3.0   ## px -- close enough to snap to waypoint

## C2 — two-way combat. When a friendly army unit blocks our path (within
## MELEE_ENGAGE_RANGE) we stop advancing and grind it down on MELEE_INTERVAL.
const MELEE_ENGAGE_RANGE : float = 40.0
const MELEE_INTERVAL     : float = 1.0
const ENEMY_MELEE_DAMAGE : float = 8.0
var _melee_timer : float = 0.0

const BODY_SIZE  : float = 26.0   ## 3D body cube size (was a 24px square)
const BODY_LIFT  : float = 14.0   ## mesh sits on the ground (half body + a touch)

var _current_health   : float    = 0.0
var _is_dead          : bool     = false
var _mesh             : MeshInstance3D = null
var _mat              : StandardMaterial3D = null
var _hp_fill          : MeshInstance3D = null
var _base_color       : Color    = Color.GRAY   ## faction/flanker colour (health/hijack tint over this)
var _speed_multiplier : float    = 1.0
var _stun_until       : float    = -1.0
var _pollen_until     : float    = -1.0
var _hijacked_until   : float    = -1.0
var _hijacked         : bool     = false

## Stealth detection counterplay.
const DETECT_RECOMPUTE_PERIOD : float = 0.15
var _detect_timer     : float    = 0.0
var _is_detected      : bool     = false

enum RevealTier { HIDDEN, BLIP, FULL }
var _reveal_tier      : RevealTier = RevealTier.HIDDEN
const SENSOR_RADIUS_MULT : float = 1.6

## Phase F -- flanker state.
var _is_flanker    : bool     = false
var _target_cell   : Vector2i = Vector2i(-1, -1)
var _map_grid_ref  : Node     = null
const TERRITORY_RATE_PER_CELL : float = 0.05
const RAID_RESOURCE_PENALTY   : float = 15.0

## Phase 3 — base defender state.
const DEFENDER_AGGRO : float    = 220.0
const DEFENDER_LEASH : float    = 240.0
var _is_defender     : bool     = false
var _guard_home      : Vector2  = Vector2.ZERO

func _ready() -> void:
	add_to_group("units")
	if data == null:
		push_error("Unit spawned without UnitData -- call setup() before adding to tree.")
		return
	_current_health = data.max_health
	_build_visual()
	_sync_transform()
	## Cache MapGrid (for fog) if a flanker didn't already supply it.
	if _map_grid_ref == null:
		_map_grid_ref = get_node_or_null("../../MapGrid")
	_update_fog_visibility()

func _process(delta: float) -> void:
	if _is_dead:
		return
	## Phase 4B Mesh hijack: revert on expiry; while active, fight former allies and skip enemy logic.
	if _hijacked and Time.get_ticks_msec() / 1000.0 >= _hijacked_until:
		_end_hijack()
	if _hijacked:
		_hijack_update(delta)
		return
	if _waypoints.is_empty() and not _is_defender:
		return
	## Stealth: refresh the live reveal tier on a throttle.
	if data != null and data.stealth:
		_detect_timer -= delta
		if _detect_timer <= 0.0:
			_detect_timer = DETECT_RECOMPUTE_PERIOD
			_reveal_tier = _compute_reveal_tier()
			_is_detected = _reveal_tier == RevealTier.FULL
	_update_fog_visibility()
	## Stun: freeze movement for the duration.
	if _stun_until > 0.0 and Time.get_ticks_msec() / 1000.0 < _stun_until:
		return
	## C2: a friendly army unit blocking us → stop and fight it.
	var foe : Node = _engaged_friendly()
	if foe != null:
		_melee_timer += delta
		if _melee_timer >= MELEE_INTERVAL:
			_melee_timer = 0.0
			if not _pollen_active() and foe.has_method("take_damage"):
				foe.call("take_damage", _melee_damage(), Combat.faction_damage_type(data.faction_id))
		return
	## Phase 3: base defenders guard their stronghold.
	if _is_defender:
		_defender_update(delta)
		return
	## Flankers: re-target if our claimed cell was already raided.
	if _is_flanker and _target_cell != Vector2i(-1, -1) and _map_grid_ref != null:
		if _map_grid_ref.get_cell(_target_cell.x, _target_cell.y) != 9:   ## no longer CLAIMED
			_retarget_flanker()
	if _wp_index >= _waypoints.size():
		if _is_flanker:
			_raid_territory()
		else:
			_reach_base()
		return
	## Move toward the current waypoint (all on the logical plane).
	var target    : Vector2 = _waypoints[_wp_index]
	var to_target : Vector2 = target - _p
	var dist      : float   = to_target.length()
	var step      : float   = data.move_speed * _speed_multiplier * _pollen_slow() * delta
	if dist <= step or dist <= ARRIVE_DIST:
		_set_plane(target)
		_wp_index += 1
	else:
		_set_plane(_p + to_target.normalized() * step)

## The cross-entity contract: this unit's logical plane position.
func plane_pos() -> Vector2:
	return _p

## Set the plane position, sync the 3D transform, and face the movement direction.
func _set_plane(p: Vector2) -> void:
	var delta : Vector2 = p - _p
	_p = p
	global_position = WORLD3D.to3(_p, 0.0)
	if delta.length_squared() > 0.0001:
		rotation.y = -atan2(delta.y, delta.x)   ## face travel direction (plane Y → 3D Z)

func _sync_transform() -> void:
	global_position = WORLD3D.to3(_p, 0.0)

## Phase 6/8: toggle visibility based on the occupied cell (fog).
func _update_fog_visibility() -> void:
	if _map_grid_ref == null:
		return
	var map_data : MapData = _map_grid_ref.get("map_data") as MapData
	if map_data == null:
		return
	var cell : Vector2i = _map_grid_ref.world_to_cell(_p)
	if cell.x < 0 or cell.x >= map_data.dimensions.x or cell.y < 0 or cell.y >= map_data.dimensions.y:
		return
	var idx : int = cell.x + cell.y * map_data.dimensions.x
	if data != null and data.stealth:
		visible = _reveal_tier != RevealTier.HIDDEN
		_apply_reveal_visual(_reveal_tier == RevealTier.FULL)
	else:
		visible = map_data.get_meta_revealed(idx)

## Called by WaveSpawner before adding the unit to the scene tree.
func setup(unit_data: UnitData, waypoints: Array) -> void:
	data       = unit_data
	_wp_index  = 1
	_waypoints.assign(waypoints)
	if not _waypoints.is_empty():
		_p = _waypoints[0]

func setup_as_flanker(unit_data: UnitData, waypoints: Array,
		target_cell: Vector2i, map_grid: Node) -> void:
	setup(unit_data, waypoints)
	_is_flanker   = true
	_target_cell  = target_cell
	_map_grid_ref = map_grid

func setup_as_defender(unit_data: UnitData, home_world: Vector2) -> void:
	data         = unit_data
	_is_defender = true
	_guard_home  = home_world
	_p           = home_world

## Reroute on EventBus.path_changed (mid-wave block).
func reroute(map_grid: Node) -> void:
	if _is_dead or _waypoints.is_empty():
		return
	var nearest_cell : Vector2i = map_grid.get_nearest_path_cell(_p)
	if _is_flanker:
		var flank_path : Array = map_grid.call("get_path_to_nearest_claimed", nearest_cell)
		if not flank_path.is_empty():
			_waypoints.assign(flank_path)
			_wp_index    = 1
			_target_cell = map_grid.call("world_to_cell", _waypoints[_waypoints.size() - 1])
			return
		_is_flanker  = false
		_target_cell = Vector2i(-1, -1)
	var new_path : Array = map_grid.get_path_to_base(nearest_cell)
	if new_path.is_empty():
		return
	_waypoints.assign(new_path)
	_wp_index = 1

func set_debuff(speed_mult: float) -> void:
	if data != null and data.status_immune:
		return
	_speed_multiplier = speed_mult

func apply_stun(duration: float) -> void:
	if data != null and data.status_immune:
		return
	_stun_until = Time.get_ticks_msec() / 1000.0 + duration

## Phase 4B Bloom pollen: slowed + blinded (can't attack) while active.
func apply_pollen(duration: float) -> void:
	if data != null and data.status_immune:
		return
	_pollen_until = Time.get_ticks_msec() / 1000.0 + duration

func _pollen_active() -> bool:
	return _pollen_until > 0.0 and Time.get_ticks_msec() / 1000.0 < _pollen_until

func _pollen_slow() -> float:
	return FACTION_PERKS.BLOOM_POLLEN_SLOW if _pollen_active() else 1.0

## -- Phase 4B Mesh hijack --

func apply_hijack(duration: float) -> void:
	if data != null and data.status_immune:
		return
	if not _hijacked:
		_hijacked = true
		remove_from_group("units")
		add_to_group("friendly_units")
		_set_tint(Color(0.35, 0.85, 1.0, 1.0))   ## cyan — converted
	_hijacked_until = Time.get_ticks_msec() / 1000.0 + duration

func _is_hijacked() -> bool:
	return _hijacked

func _end_hijack() -> void:
	_hijacked = false
	_hijacked_until = -1.0
	remove_from_group("friendly_units")
	add_to_group("units")
	_update_health_visual()   ## restore the health-based tint

## While hijacked: close on the nearest remaining enemy and grind it.
func _hijack_update(delta: float) -> void:
	var target : Node = _nearest_enemy_unit()
	if target == null:
		return
	var tpos : Vector2 = WORLD3D.node_plane(target)
	var d : float = _p.distance_to(tpos)
	if d > MELEE_ENGAGE_RANGE:
		var step : float = data.move_speed * _speed_multiplier * delta
		var dir  : Vector2 = tpos - _p
		_set_plane(_p + dir.normalized() * minf(step, dir.length()))
	else:
		_melee_timer += delta
		if _melee_timer >= MELEE_INTERVAL:
			_melee_timer = 0.0
			if target.has_method("take_damage"):
				target.call("take_damage", _melee_damage(), Combat.faction_damage_type(data.faction_id))

func _nearest_enemy_unit() -> Node:
	var best : Node = null
	var best_d : float = 1.0e20
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or not is_instance_valid(u):
			continue
		var d : float = _p.distance_to(WORLD3D.node_plane(u))
		if d < best_d:
			best_d = d
			best = u
	return best

func is_detectable() -> bool:
	if data == null or not data.stealth:
		return true
	return _is_detected

## C2: nearest meleeable friendly (or commander/built wall) within range, or null.
func _engaged_friendly() -> Node:
	var best   : Node  = null
	var best_d : float = MELEE_ENGAGE_RANGE
	for f in get_tree().get_nodes_in_group("friendly_units"):
		if not is_instance_valid(f):
			continue
		var d : float = _p.distance_to(WORLD3D.node_plane(f))
		if d <= best_d:
			best   = f
			best_d = d
	for c in get_tree().get_nodes_in_group("commander"):
		if not is_instance_valid(c):
			continue
		var d : float = _p.distance_to(WORLD3D.node_plane(c))
		if d <= best_d:
			best   = c
			best_d = d
	for w in get_tree().get_nodes_in_group("walls"):
		if not is_instance_valid(w):
			continue
		if w.has_method("is_built") and not bool(w.call("is_built")):
			continue
		var d : float = _p.distance_to(WORLD3D.node_plane(w))
		if d <= best_d:
			best   = w
			best_d = d
	return best

func _defender_update(delta: float) -> void:
	var target : Node = _nearest_player_target()
	if target != null:
		_move_toward_guard(WORLD3D.node_plane(target), delta)
	elif _p.distance_to(_guard_home) > ARRIVE_DIST:
		_move_toward_guard(_guard_home, delta)

func _nearest_player_target() -> Node:
	var best : Node = null
	var best_d : float = 1.0e20
	for grp in ["commander", "friendly_units"]:
		for t in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(t):
				continue
			var tpos : Vector2 = WORLD3D.node_plane(t)
			if tpos.distance_to(_guard_home) > DEFENDER_AGGRO:
				continue
			var d : float = _p.distance_to(tpos)
			if d < best_d:
				best_d = d
				best = t
	return best

func _move_toward_guard(point: Vector2, delta: float) -> void:
	var step : float = data.move_speed * _speed_multiplier * _pollen_slow() * delta
	var dir  : Vector2 = point - _p
	var np   : Vector2
	if dir.length() <= step:
		np = point
	else:
		np = _p + dir.normalized() * step
	var from_home : Vector2 = np - _guard_home
	if from_home.length() > DEFENDER_LEASH:
		np = _guard_home + from_home.normalized() * DEFENDER_LEASH
	_set_plane(np)

func _melee_damage() -> float:
	return maxf(data.attack_damage, ENEMY_MELEE_DAMAGE)

func _compute_reveal_tier() -> RevealTier:
	var best : RevealTier = RevealTier.HIDDEN
	for d in get_tree().get_nodes_in_group("detectors"):
		if not is_instance_valid(d):
			continue
		if not d.has_method("get_detector_radius"):
			continue
		var sight : float = float(d.call("get_detector_radius"))
		if sight <= 0.0:
			continue
		var dist : float = _p.distance_to(WORLD3D.node_plane(d))
		if dist <= sight:
			return RevealTier.FULL
		var sensor : float = float(d.call("get_sensor_radius")) if d.has_method("get_sensor_radius") else sight * SENSOR_RADIUS_MULT
		if dist <= sensor:
			best = RevealTier.BLIP
	return best

## Apply incoming damage. Returns true if the unit died.
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
	if data.evolve_threshold > 0.0:
		var hp_ratio : float = _current_health / data.max_health
		if hp_ratio <= data.evolve_threshold and data.evolved_unit != null:
			_evolve()
	return false

## -- Internal --

func _retarget_flanker() -> void:
	var nearest_cell : Vector2i = _map_grid_ref.get_nearest_path_cell(_p)
	var flank_path   : Array    = _map_grid_ref.call("get_path_to_nearest_claimed", nearest_cell)
	if not flank_path.is_empty():
		_waypoints.assign(flank_path)
		_wp_index = 1
		var last_wp  : Vector2  = _waypoints[_waypoints.size() - 1]
		_target_cell = Vector2i(int(last_wp.x / 64.0), int(last_wp.y / 64.0))
	else:
		_is_flanker  = false
		_target_cell = Vector2i(-1, -1)
		var base_path : Array = _map_grid_ref.get_path_to_base(nearest_cell)
		if not base_path.is_empty():
			_waypoints.assign(base_path)
			_wp_index = 1

func _raid_territory() -> void:
	_is_dead = true
	if _map_grid_ref != null and _target_cell != Vector2i(-1, -1):
		if _map_grid_ref.get_cell(_target_cell.x, _target_cell.y) == 9:   ## Cell.CLAIMED
			_map_grid_ref.call("unclaim_cell", _target_cell.x, _target_cell.y)
			var primary : String = FactionManager.get_primary_resource()
			EconomyManager.add_resource(primary, -RAID_RESOURCE_PENALTY)
			EconomyManager.add_territory_rate(primary, -TERRITORY_RATE_PER_CELL)
			EventBus.territory_raided.emit(_target_cell)
	WaveManager.report_enemy_killed()
	queue_free()

func _reach_base() -> void:
	_is_dead = true
	WaveManager.report_base_breached()
	EventBus.base_damaged.emit(data.damage_on_arrival, {"unit": data.unit_name})
	EconomyManager.add_resource(FactionManager.get_primary_resource(), data.resource_reward * 0.5)
	queue_free()

func _die() -> void:
	_is_dead = true
	if not _is_defender:
		WaveManager.report_enemy_killed()
	EconomyManager.add_resource(FactionManager.get_primary_resource(), data.resource_reward)
	EventBus.unit_died.emit({"unit": data.unit_name, "faction": data.faction_id})
	## NOTE: 3D death VFX arrives in migration Stage 4; the 2D Vfx no-ops outside the 2D world.
	Vfx.death(_p, Vfx.faction_color(data.faction_id), 22.0)
	queue_free()

func _evolve() -> void:
	var hp_ratio : float = _current_health / data.max_health
	data            = data.evolved_unit
	_current_health = data.max_health * hp_ratio
	_base_color     = data.color_hint
	_update_health_visual()

## -- Visual (3D) --

func _build_visual() -> void:
	_base_color = Color(1.0, 0.35, 0.1) if _is_flanker else (data.color_hint if data else Color.GRAY)

	_mesh = MeshInstance3D.new()
	var box : BoxMesh = BoxMesh.new()
	box.size = Vector3(BODY_SIZE, BODY_SIZE, BODY_SIZE)
	_mesh.mesh = box
	_mesh.position = Vector3(0.0, BODY_LIFT, 0.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	if data != null and data.stealth:
		_mat.albedo_color.a = 0.85
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = _mat
	add_child(_mesh)

	## Billboarded health bar (bg + fill) above the body.
	var bar_y : float = BODY_LIFT + BODY_SIZE * 0.7
	_make_hp_quad(Color(0.15, 0.15, 0.15), bar_y, 1.0)          ## background
	_hp_fill = _make_hp_quad(Color(0.2, 0.9, 0.2), bar_y + 0.1, 1.0)   ## fill (slightly in front)

func _make_hp_quad(col: Color, y: float, frac: float) -> MeshInstance3D:
	var q : MeshInstance3D = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(BODY_SIZE, 4.0)
	q.mesh = qm
	q.position = Vector3(0.0, y, 0.0)
	q.scale.x = frac
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	return q

func _update_health_visual() -> void:
	if data == null:
		return
	var frac : float = clampf(_current_health / data.max_health, 0.0, 1.0)
	if _hp_fill != null:
		_hp_fill.scale.x = frac
	## Tint the body toward dark red as health drops (a clear damage read in 3D).
	if _mat != null and not _hijacked:
		_mat.albedo_color = _base_color.lerp(Color(0.5, 0.05, 0.05), 1.0 - frac)

func _set_tint(c: Color) -> void:
	if _mat != null:
		_mat.albedo_color = c

func _apply_reveal_visual(full: bool) -> void:
	if _mat != null:
		_mat.albedo_color.a = 1.0 if full else 0.4
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if _hp_fill != null:
		_hp_fill.visible = full

## Minimap reveal tier (unchanged logic, plane-based).
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
	var cell : Vector2i = _map_grid_ref.world_to_cell(_p)
	if cell.x < 0 or cell.x >= md.dimensions.x or cell.y < 0 or cell.y >= md.dimensions.y:
		return 0
	var idx : int = cell.x + cell.y * md.dimensions.x
	return 2 if md.get_meta_revealed(idx) else 0
