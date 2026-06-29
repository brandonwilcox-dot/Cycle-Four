## Base.gd
## The player's Forward Operating Base. Always-on turret, breach-damage HP, fortification rank,
## sphere of influence, and FOB doctrine. Cannot be moved or sold.
##
## 3D MIGRATION (Stage 2d): now `extends Node3D` (model/view). Static plane position `_p` +
## place_at()/plane_pos(); influence/attack/cell math via World3D. Visual is a 3D fortified bunker
## with a turret + billboard HP bar (was ColorRects). 2D rank bar/chevrons deferred (null-guarded).
extends Node3D

const Combat = preload("res://src/combat/Combat.gd")
const WORLD3D = preload("res://src/core/World3D.gd")

const RANGE        : float = 256.0
const DAMAGE       : float = 18.0
const ATTACK_SPEED : float = 1.5
const MAX_HP : float = 300.0
const CARGO_PER_RANK : float = 10.0

const FOB_SIGHT_RADIUS_BASE : int = 5
const FOB_CLAIM_RADIUS_BASE : int = 2
const FOB_SENSOR_EXTRA      : int = 3
const FOB_RADIUS_PER_RANK   : int = 1
const FOB_MAX_RANK          : int = 10

const DOCTRINE_FIRE_RATE_MULT       : float = 1.6
const DOCTRINE_REGEN_PER_SEC        : float = 4.0
const DOCTRINE_DETECTOR_BONUS_CELLS : int   = 3

var _map_grid : Node = null
var _p        : Vector2 = Vector2.ZERO

var _current_hp        : float  = MAX_HP
var _hp_fill           : MeshInstance3D = null
var _hp_mat            : StandardMaterial3D = null
var _attack_timer      : float  = 0.0
var _is_destroyed      : bool   = false
var _cargo_received    : float  = 0.0
var _fortification_rank : int   = 0
var _doctrine           : String = ""
var _rank_bar          : Node = null   ## deferred (3D overlay polish); logic null-guards
var _rank_chevrons     : Node = null   ## deferred
var _height            : float = 70.0

func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("base")
	add_to_group("detectors")
	position = WORLD3D.to3(_p, 0.0)
	_build_visual()
	EventBus.base_damaged.connect(_on_base_damaged)
	EventBus.base_healed.connect(_on_base_healed)
	EventBus.convoy_arrived.connect(_on_convoy_arrived)
	call_deferred("_apply_influence")

const FOB_DETECTOR_RADIUS_CELLS : int = 6

func get_detector_radius() -> float:
	var cells : int = FOB_DETECTOR_RADIUS_CELLS + (DOCTRINE_DETECTOR_BONUS_CELLS if _doctrine == "mesh" else 0)
	return float(cells * 64)

func _get_map_grid() -> Node:
	if _map_grid == null or not is_instance_valid(_map_grid):
		_map_grid = get_tree().get_first_node_in_group("map_grid")
	return _map_grid

func _apply_influence() -> void:
	var grid : Node = _get_map_grid()
	if grid == null:
		return
	var center : Vector2i = grid.world_to_cell(_p)
	var sight  : int = FOB_SIGHT_RADIUS_BASE + _fortification_rank * FOB_RADIUS_PER_RANK
	var claim  : int = FOB_CLAIM_RADIUS_BASE + _fortification_rank * FOB_RADIUS_PER_RANK
	grid.call("reveal_area", center, sight)
	grid.call("sense_area", center, sight, sight + FOB_SENSOR_EXTRA)
	var claimed = grid.call("claim_area", center, claim)
	if claimed != null:
		for nc in claimed:
			EconomyManager.register_claimed_cell()
			EventBus.territory_claimed.emit(nc)

func _on_convoy_arrived(_convoy_id: StringName, _to_node: StringName, cargo: float) -> void:
	_cargo_received += cargo
	var prev_rank : int = _fortification_rank
	while _cargo_received >= CARGO_PER_RANK and _fortification_rank < FOB_MAX_RANK:
		_cargo_received -= CARGO_PER_RANK
		_fortification_rank += 1
	if _fortification_rank >= FOB_MAX_RANK:
		_cargo_received = 0.0
	_update_rank_bar()
	if _fortification_rank > prev_rank:
		if _rank_chevrons != null:
			_rank_chevrons.call("set_rank", _fortification_rank)
		_apply_influence()

func restore_rank(restored_rank: int) -> void:
	_fortification_rank = clampi(restored_rank, 0, FOB_MAX_RANK)
	_update_rank_bar()
	if _rank_chevrons != null:
		_rank_chevrons.call("set_rank", _fortification_rank)
	_apply_influence()

func _update_rank_bar() -> void:
	if _rank_bar == null:
		return
	_rank_bar.call("set_progress", _cargo_received / CARGO_PER_RANK)

func _process(delta: float) -> void:
	if _is_destroyed:
		return
	if _doctrine == "bloom" and _current_hp < MAX_HP:
		_current_hp = minf(MAX_HP, _current_hp + DOCTRINE_REGEN_PER_SEC * delta)
		_update_hp_bar()
	_attack_timer += delta
	var rate : float = ATTACK_SPEED * (DOCTRINE_FIRE_RATE_MULT if _doctrine == "architects" else 1.0)
	if _attack_timer >= 1.0 / rate:
		_attack_timer = 0.0
		_try_attack()

func set_doctrine(doctrine_id: String) -> void:
	_doctrine = doctrine_id

func get_doctrine() -> String:
	return _doctrine

func _turret_damage_type() -> int:
	var fid : String = _doctrine if _doctrine != "" else FactionManager.active_faction
	return Combat.faction_damage_type(fid)

## -- Combat --

func _on_base_damaged(amount: float, _attacker_data: Dictionary) -> void:
	if _is_destroyed:
		return
	_current_hp = maxf(0.0, _current_hp - amount)
	_update_hp_bar()
	if _current_hp <= 0.0:
		_is_destroyed = true
		EventBus.base_destroyed.emit()

func _on_base_healed(amount: float) -> void:
	if _is_destroyed:
		return
	_current_hp = minf(MAX_HP, _current_hp + amount)
	_update_hp_bar()

func _try_attack() -> void:
	var nearest      : Node  = null
	var nearest_dist : float = RANGE
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.has_method("is_detectable") and not unit.call("is_detectable"):
			continue
		var dist : float = _p.distance_to(WORLD3D.node_plane(unit))
		if dist < nearest_dist:
			nearest_dist = dist
			nearest      = unit
	if nearest != null and nearest.has_method("take_damage"):
		var dt : int = _turret_damage_type()
		Vfx.muzzle(_p, dt)
		Vfx.bolt(_p, WORLD3D.node_plane(nearest), dt)
		nearest.take_damage(DAMAGE, dt)

## -- Visual (3D) --

func _update_hp_bar() -> void:
	if _hp_fill == null:
		return
	var ratio : float = _current_hp / MAX_HP
	_hp_fill.scale.x = clampf(ratio, 0.0, 1.0)
	if _hp_mat != null:
		if ratio > 0.5:
			_hp_mat.albedo_color = Color(0.20, 0.90, 0.20)
		elif ratio > 0.25:
			_hp_mat.albedo_color = Color(0.90, 0.70, 0.10)
		else:
			_hp_mat.albedo_color = Color(0.90, 0.20, 0.10)

func _build_visual() -> void:
	## Concrete apron (wide, low).
	var apron : MeshInstance3D = MeshInstance3D.new()
	var ab : BoxMesh = BoxMesh.new()
	ab.size = Vector3(108.0, 18.0, 108.0)
	apron.mesh = ab
	apron.position = Vector3(0.0, 9.0, 0.0)
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	apron.material_override = _solid(Color(0.30, 0.27, 0.20))
	add_child(apron)

	## Fortified body — olive drab.
	var body : MeshInstance3D = MeshInstance3D.new()
	var bb : BoxMesh = BoxMesh.new()
	bb.size = Vector3(84.0, _height, 84.0)
	body.mesh = bb
	body.position = Vector3(0.0, _height * 0.5 + 18.0, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.material_override = _solid(Color(0.22, 0.32, 0.17))
	add_child(body)

	## Corner reinforcements.
	for cx in [-36.0, 36.0]:
		for cz in [-36.0, 36.0]:
			var c : MeshInstance3D = MeshInstance3D.new()
			var cm : BoxMesh = BoxMesh.new()
			cm.size = Vector3(16.0, _height + 8.0, 16.0)
			c.mesh = cm
			c.position = Vector3(cx, (_height + 8.0) * 0.5 + 18.0, cz)
			c.material_override = _solid(Color(0.18, 0.18, 0.14))
			add_child(c)

	## Turret — gun-metal drum + barrel.
	var turret_base : MeshInstance3D = MeshInstance3D.new()
	var tc : CylinderMesh = CylinderMesh.new()
	tc.top_radius = 22.0
	tc.bottom_radius = 24.0
	tc.height = 20.0
	turret_base.mesh = tc
	turret_base.position = Vector3(0.0, _height + 28.0, 0.0)
	turret_base.material_override = _solid(Color(0.14, 0.14, 0.14))
	add_child(turret_base)
	var barrel : MeshInstance3D = MeshInstance3D.new()
	var brm : BoxMesh = BoxMesh.new()
	brm.size = Vector3(34.0, 7.0, 7.0)
	barrel.mesh = brm
	barrel.position = Vector3(20.0, _height + 30.0, 0.0)
	barrel.material_override = _solid(Color(0.10, 0.10, 0.10))
	add_child(barrel)

	## HP bar — billboarded above the FOB.
	var bar_y : float = _height + 56.0
	_make_bar(Color(0.15, 0.15, 0.15), bar_y, 90.0)            ## bg
	_hp_fill = _make_bar(Color(0.20, 0.90, 0.20), bar_y + 0.1, 90.0)   ## fill
	_hp_mat = _hp_fill.material_override as StandardMaterial3D

func _solid(col: Color) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	return m

func _make_bar(col: Color, y: float, width: float) -> MeshInstance3D:
	var q : MeshInstance3D = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(width, 7.0)
	q.mesh = qm
	q.position = Vector3(0.0, y, 0.0)
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	return q
