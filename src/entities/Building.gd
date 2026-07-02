## Building.gd
## A production building / GARRISON placed on CLAIMED territory. Contributes passive income,
## produces friendly defenders, patrols, runs standing-order raids, and levels up.
##
## 3D MIGRATION (Stage 2c): now `extends Node3D` (model/view). Static plane position `_p` +
## place_at()/plane_pos(); all distance/cell math goes through World3D. Visual is a 3D box garrison
## with a raised cross identity (was a ColorRect square + plus). Defender production reuses the
## shared unit layer once FriendlyUnit is 3D-converted; it no-ops safely until then.
extends Node3D

const FriendlyUnitScript = preload("res://src/entities/FriendlyUnit.gd")
const FriendlyRosterScript = preload("res://src/core/army/FriendlyRoster.gd")
const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")
const WORLD3D = preload("res://src/core/World3D.gd")

const DETECT_RADIUS : float = 160.0

const GARRISON_BASE_MAX         : int   = 3
const GARRISON_PRODUCE_INTERVAL : float = 5.0
const GARRISON_PATROL_THRESHOLD : int   = 2
const GARRISON_XP_PER_LEVEL     : int   = 4

const RAID_MIN_SQUAD     : int   = 3
const RAID_RANGE_CELLS   : int   = 10
const RAID_CLAIM_RADIUS  : int   = 1
const RAID_THREAT_RADIUS : float = 260.0
const RAID_REACH_DIST    : float = 44.0

const MAX_HEALTH   : float = 120.0
const START_HEALTH : float = 10.0

var data : Resource = null   ## BuildingData instance
var _p   : Vector2 = Vector2.ZERO
var _income_active : bool = false
var _restored      : bool = false

## Construction state.
var _max_health : float = MAX_HEALTH
var _health     : float = MAX_HEALTH
var _built      : bool  = true

## Garrison state.
var _garrison_unit  : UnitData = null
var _unit_layer     : Node     = null
var _map_grid       : Node     = null
var _produce_timer  : float    = GARRISON_PRODUCE_INTERVAL
var _my_units       : Array    = []
var _level          : int      = 1
var _kills          : int      = 0

## Raid state.
var _raiding           : bool    = false
var _raid_target_cell  : Vector2i = Vector2i(-1, -1)
var _raid_target_world : Vector2  = Vector2.ZERO

## 3D visual.
var _body_mats : Array[StandardMaterial3D] = []
var _build_bar : MeshInstance3D = null
var _height    : float = 50.0

func setup(building_data: Resource, restored: bool = false) -> void:
	data = building_data
	_restored = restored

## Fix the garrison's plane position (and 3D transform).
func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

func plane_pos() -> Vector2:
	return _p

## -- Construction / engineering (Phase 2B) --

func is_built() -> bool:
	return _built

func needs_engineering() -> bool:
	return _health < _max_health

func receive_engineering(amount: float) -> bool:
	if _health >= _max_health:
		return false
	_health = minf(_max_health, _health + amount)
	if not _built and _health >= _max_health:
		_complete_build()
	_refresh_build_visual()
	return true

func _complete_build() -> void:
	_built = true
	if not _income_active:
		_income_active = true
		EconomyManager.add_territory_rate(FactionManager.get_primary_resource(), float(data.get("income_rate")))
	var nm : String = str(data.get("building_name")) if data.get("building_name") != null else "Garrison"
	EventBus.notification_pushed.emit("%s online." % nm, "positive")

## Ghosts the garrison (material alpha) while under construction and drives the build bar.
func _refresh_build_visual() -> void:
	var frac : float = clampf(_health / _max_health, 0.0, 1.0)
	if _build_bar != null:
		_build_bar.visible = _health < _max_health
		_build_bar.scale.x = frac
	var a : float = 1.0 if _built else 0.5
	for m in _body_mats:
		if m == null:
			continue
		m.albedo_color.a = a
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if _built else BaseMaterial3D.TRANSPARENCY_ALPHA

func get_detector_radius() -> float:
	return DETECT_RADIUS

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("detectors")
	if data == null:
		push_error("Building: no BuildingData -- call setup() before adding to tree.")
		return
	position = WORLD3D.to3(_p, 0.0)
	_max_health = MAX_HEALTH * FACTION_PERKS.health_mult(FactionManager.active_faction)
	_built  = _restored
	_health = _max_health if _built else START_HEALTH
	if _restored:
		_income_active = true
	_build_visual()
	_unit_layer    = get_node_or_null("../../UnitLayer")
	_map_grid      = get_tree().get_first_node_in_group("map_grid")
	_garrison_unit = FriendlyRosterScript.garrison_unit(FactionManager.active_faction)

func _process(delta: float) -> void:
	if not _built:
		return
	## Resolve the friendly-unit layer lazily: the hardcoded ../../UnitLayer path doesn't hold in the
	## 3D scene layout, so fall back to the "unit_layer" group once it exists.
	if _unit_layer == null:
		_unit_layer = get_node_or_null("../../UnitLayer")
		if _unit_layer == null:
			_unit_layer = get_tree().get_first_node_in_group("unit_layer")
	if _garrison_unit == null or _unit_layer == null:
		return
	_produce_timer -= delta
	if _produce_timer > 0.0:
		return
	_produce_timer = _produce_interval()
	_my_units = _my_units.filter(func(u): return is_instance_valid(u))
	_update_raid()
	var patrolling : bool = (not _raiding) and _my_units.size() >= GARRISON_PATROL_THRESHOLD
	for u in _my_units:
		if u.has_method("set_patrol"):
			u.call("set_patrol", patrolling)
	if _my_units.size() < _max_units():
		_spawn_defender()

func _spawn_defender() -> void:
	var offset : Vector2 = Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
	var unit : Node = FriendlyUnitScript.new()
	unit.call("setup", _garrison_unit, _p + offset, self)
	_unit_layer.add_child(unit)
	_my_units.append(unit)

func report_kill() -> void:
	_kills += 1
	if _kills >= GARRISON_XP_PER_LEVEL * _level:
		_kills = 0
		_level += 1
		EventBus.notification_pushed.emit("Garrison advanced to level %d." % _level, "normal")

func _max_units() -> int:
	return GARRISON_BASE_MAX + (_level - 1)

func _produce_interval() -> float:
	return maxf(2.0, GARRISON_PRODUCE_INTERVAL - 0.5 * float(_level - 1))

## -- C3: standing-order raids --

func _update_raid() -> void:
	if _map_grid == null:
		return
	var threatened : bool = _enemy_within(RAID_THREAT_RADIUS)
	if _raiding:
		if threatened:
			_abort_raid()
			return
		for u in _my_units:
			if is_instance_valid(u) and WORLD3D.node_plane(u).distance_to(_raid_target_world) <= RAID_REACH_DIST:
				_complete_raid()
				return
		return
	if threatened or _my_units.size() < RAID_MIN_SQUAD:
		return
	var gcell  : Vector2i = _map_grid.world_to_cell(_p)
	var target : Vector2i = _map_grid.call("get_raid_target", gcell, RAID_RANGE_CELLS)
	if target == Vector2i(-1, -1):
		return
	_raiding           = true
	_raid_target_cell  = target
	_raid_target_world = _map_grid.cell_to_world(target.x, target.y)
	for u in _my_units:
		if u.has_method("set_raid_target"):
			u.call("set_raid_target", _raid_target_world)

func _complete_raid() -> void:
	var newly : Array = _map_grid.call("claim_area", _raid_target_cell, RAID_CLAIM_RADIUS)
	if newly != null and not newly.is_empty():
		for nc in newly:
			EconomyManager.register_claimed_cell()
		for nc in newly:
			EventBus.territory_claimed.emit(nc)
		EventBus.notification_pushed.emit("Raiding party claimed %d cells of territory." % newly.size(), "normal")
	_abort_raid()

func _abort_raid() -> void:
	_raiding          = false
	_raid_target_cell = Vector2i(-1, -1)
	for u in _my_units:
		if is_instance_valid(u) and u.has_method("clear_raid"):
			u.call("clear_raid")

func _enemy_within(radius: float) -> bool:
	for e in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(e) and _p.distance_to(WORLD3D.node_plane(e)) <= radius:
			return true
	return false

## -- C4: offline resolution --

const OFFLINE_RAID_CYCLE : float = 30.0
const OFFLINE_MAX_RAIDS  : int   = 20

func simulate_offline_raids(seconds: float) -> int:
	if _map_grid == null or _garrison_unit == null:
		return 0
	var raids   : int = clampi(int(seconds / OFFLINE_RAID_CYCLE), 0, OFFLINE_MAX_RAIDS)
	var claimed : int = 0
	var gcell   : Vector2i = _map_grid.world_to_cell(_p)
	for _i in raids:
		var target : Vector2i = _map_grid.call("get_raid_target", gcell, RAID_RANGE_CELLS)
		if target == Vector2i(-1, -1):
			break
		var newly : Array = _map_grid.call("claim_area", target, RAID_CLAIM_RADIUS)
		if newly == null or newly.is_empty():
			break
		for nc in newly:
			EconomyManager.register_claimed_cell()
			EventBus.territory_claimed.emit(nc)
		claimed += newly.size()
	return claimed

func destroy() -> void:
	if _income_active:
		_income_active = false
		EconomyManager.add_territory_rate(
			FactionManager.get_primary_resource(),
			-float(data.get("income_rate"))
		)
	queue_free()

## -- Visual (3D) --

func _build_visual() -> void:
	_body_mats.clear()
	var col : Color = data.get("color_hint") if data.get("color_hint") else Color.WHITE

	## Garrison body — a squat block.
	var body : MeshInstance3D = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(46.0, _height, 46.0)
	body.mesh = bx
	body.position = Vector3(0.0, _height * 0.5, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.material_override = _mat(col)
	add_child(body)

	## Raised cross/plus on top — the building identity (distinct from towers/units).
	var cross_col : Color = col.darkened(0.5)
	var hbar : MeshInstance3D = MeshInstance3D.new()
	var hb : BoxMesh = BoxMesh.new()
	hb.size = Vector3(34.0, 8.0, 10.0)
	hbar.mesh = hb
	hbar.position = Vector3(0.0, _height + 5.0, 0.0)
	hbar.material_override = _mat(cross_col)
	add_child(hbar)
	var vbar : MeshInstance3D = MeshInstance3D.new()
	var vb : BoxMesh = BoxMesh.new()
	vb.size = Vector3(10.0, 8.0, 34.0)
	vbar.mesh = vb
	vbar.position = Vector3(0.0, _height + 5.0, 0.0)
	vbar.material_override = _mat(cross_col)
	add_child(vbar)

	## Construction/repair bar — billboarded above; shown while building/damaged.
	_build_bar = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(48.0, 5.0)
	_build_bar.mesh = qm
	_build_bar.position = Vector3(0.0, _height + 18.0, 0.0)
	var bmat : StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.45, 1.0, 0.7)
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_build_bar.material_override = bmat
	_build_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_build_bar)

	_refresh_build_visual()

const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")

## V3: garrison bodies carry the player faction's substrate.
func _mat(col: Color) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	_SUBSTRATE.apply(m, FactionManager.active_faction)
	_body_mats.append(m)
	return m
