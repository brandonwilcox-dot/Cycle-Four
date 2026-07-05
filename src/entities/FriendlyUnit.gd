## FriendlyUnit.gd
## Phase C (C1) — a friendly army unit produced by a garrison. Holds/defends near its home garrison
## (leashed), acquires nearby enemies, fires through the triangle, takes attrition, dies.
##
## 3D MIGRATION (Stage 2h): now `extends Node3D` (model/view). Logical plane pos `_p` drives the
## transform via World3D; cross-entity reads via plane_pos()/World3D.node_plane(). Behavior stays in
## update(delta) so the C4 offline sim can fast-forward it. Visual is a 3D box + friendly ground ring
## + billboard health bar (was ColorRects).
extends Node3D

const Combat = preload("res://src/combat/Combat.gd")
const WORLD3D = preload("res://src/core/World3D.gd")
const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")
const UNIT_BODIES = preload("res://src/vfx/UnitBodies.gd")
const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")

const AGGRO_RADIUS    : float = 240.0
const BLOCK_RANGE     : float = 28.0
const ARRIVE_DIST     : float = 4.0
const PATROL_RADIUS        : float = 120.0
const PATROL_ANGULAR_SPEED : float = 0.6

var data       : UnitData = null
var _p          : Vector2  = Vector2.ZERO
var _home       : Vector2  = Vector2.ZERO
var _faction    : String   = ""
## U0: per-faction tether radius (Architect wide / Bloom mid / Mesh short). The garrison
## may re-scale it (U1: Bloom maturity growth) via set_leash().
var _leash      : float    = 220.0
## U1 node-identity dials, driven by the home garrison each production tick (never by the
## player — auras apply automatically in radius, per the anti-micro rules).
var damage_mult : float    = 1.0   ## Bloom maturity/connection buff
var rof_mult    : float    = 1.0   ## Mesh overlap targeting-share (<1.0 = faster fire)
var _current_health : float = 0.0
var _attack_timer   : float = 0.0
var _is_dead        : bool  = false
var _mesh           : MeshInstance3D = null
var _hp_fill        : MeshInstance3D = null
var _garrison       : Node    = null
var _patrolling     : bool    = false
var _patrol_angle   : float   = 0.0
var _has_raid       : bool    = false
var _raid_target    : Vector2 = Vector2.ZERO

func setup(unit_data: UnitData, home_world: Vector2, garrison: Node = null) -> void:
	data      = unit_data
	_home     = home_world
	_garrison = garrison
	_p        = home_world
	_patrol_angle = randf() * TAU
	if data != null:
		_current_health = data.max_health

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("friendly_units")
	if data == null:
		push_error("FriendlyUnit spawned without UnitData -- call setup() first.")
		return
	_faction = FactionManager.active_faction
	_leash   = FACTION_PERKS.tether_radius(_faction)
	## U2: scout roles are stealth detectors (the "detectors" group contract).
	if data.detector_radius > 0.0:
		add_to_group("detectors")
	position = WORLD3D.to3(_p, 0.0)
	_build_visual()

func get_detector_radius() -> float:
	return data.detector_radius if data != null else 0.0

## U1 hook — garrisons re-scale the tether (e.g. Bloom maturity widens it).
func set_leash(radius: float) -> void:
	_leash = radius

## U1 — Bloom node regen aura ("living tech heals").
func heal(amount: float) -> void:
	if _is_dead or data == null or _current_health >= data.max_health:
		return
	_current_health = minf(data.max_health, _current_health + amount)
	_update_health_visual()

## U1 — Mesh reroute-on-loss: when the home garrison dies, surviving units re-tether to
## the nearest Mesh node instead of orphaning ("lose a node, reroute").
func retether(home_world: Vector2, garrison: Node) -> void:
	_home     = home_world
	_garrison = garrison

func _process(delta: float) -> void:
	if _is_dead:
		return
	_animate(delta)   ## V4 gait — driven off actual movement
	update(delta)

## -- V4 motion: per-faction gait (mirrors Unit._animate; rest height is the build Y) --

const _GAIT_REST_Y : float = 10.0
const _GAIT_SETTLE : float = 8.0

var _anim_t      : float = 0.0
var _anim_last_p : Vector2 = Vector2(INF, INF)

func _animate(delta: float) -> void:
	if _mesh == null:
		return
	var moved : bool = _anim_last_p.is_finite() and _p.distance_squared_to(_anim_last_p) > 0.02
	_anim_last_p = _p
	if moved:
		match data.faction_id if data != null else "":
			"architects":
				_anim_t += delta * 2.0
				_mesh.position.y = _GAIT_REST_Y + 1.2 + sin(_anim_t * TAU * 0.5) * 0.8
			"bloom":
				_anim_t += delta * 3.6
				_mesh.position.y = _GAIT_REST_Y + absf(sin(_anim_t * TAU * 0.5)) * 5.5
				_mesh.rotation.z = sin(_anim_t * TAU * 0.5) * 0.16
				_mesh.rotation.y = sin(_anim_t * TAU * 0.25) * 0.09
			"mesh":
				_anim_t += delta * 11.0
				_mesh.position.y = _GAIT_REST_Y + absf(sin(_anim_t * TAU * 0.5)) * 2.6
				_mesh.rotation.z = sin(_anim_t * TAU) * 0.07
				_mesh.position.z = sin(_anim_t * TAU * 0.7) * 1.5
	else:
		_mesh.position.y = lerpf(_mesh.position.y, _GAIT_REST_Y, minf(1.0, delta * _GAIT_SETTLE))
		_mesh.position.z = lerpf(_mesh.position.z, 0.0, minf(1.0, delta * _GAIT_SETTLE))
		_mesh.rotation.z = lerpf(_mesh.rotation.z, 0.0, minf(1.0, delta * _GAIT_SETTLE))
		_mesh.rotation.y = lerpf(_mesh.rotation.y, 0.0, minf(1.0, delta * _GAIT_SETTLE))

func update(delta: float) -> void:
	if data == null:
		return
	_attack_timer += delta
	## U2: non-combatants (pure scouts) never chase — they patrol and sense.
	var target : Node = _acquire_target() if data.attack_damage > 0.0 else null
	if target != null:
		var tpos : Vector2 = WORLD3D.node_plane(target)
		var dist : float = _p.distance_to(tpos)
		if dist > BLOCK_RANGE:
			_move_toward(tpos, delta)
		if dist <= data.attack_range and _attack_timer >= data.attack_interval * rof_mult:
			_attack_timer = 0.0
			_fire(target)
	elif _has_raid:
		_move_toward(_raid_target, delta, false)
	elif _patrolling:
		_patrol(delta)
	elif _p.distance_to(_home) > ARRIVE_DIST:
		_move_toward(_home, delta)

func _acquire_target() -> Node:
	var best      : Node = null
	## U2: artillery outranges the default aggro bubble — acquisition reaches to attack range.
	var best_dist : float  = maxf(AGGRO_RADIUS, data.attack_range)
	for enemy in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_detectable") and not enemy.call("is_detectable"):
			continue
		var epos : Vector2 = WORLD3D.node_plane(enemy)
		var d : float = _p.distance_to(epos)
		## The leash constrains MOVEMENT, not fire: a target is eligible inside the node's
		## radius, or already inside this unit's own weapon range.
		if epos.distance_to(_home) > _leash and d > data.attack_range:
			continue
		## U2 Mesh direct-fire: no shooting past walls.
		if data.requires_los and not _has_los(epos):
			continue
		if d <= best_dist:
			best      = enemy
			best_dist = d
	for base in get_tree().get_nodes_in_group("enemy_bases"):
		if not is_instance_valid(base):
			continue
		var bpos : Vector2 = WORLD3D.node_plane(base)
		var bd : float = _p.distance_to(bpos)
		if bpos.distance_to(_home) > _leash and bd > data.attack_range:
			continue
		if data.requires_los and not _has_los(bpos):
			continue
		if bd <= best_dist:
			best      = base
			best_dist = bd
	return best

## U2 — direct-fire LOS: the shot line must clear every wall (F1 will add terrain).
const _LOS_BLOCK_RADIUS : float = 24.0
func _has_los(tpos: Vector2) -> bool:
	for w in get_tree().get_nodes_in_group("walls"):
		if not is_instance_valid(w):
			continue
		var wpos : Vector2 = WORLD3D.node_plane(w)
		if Geometry2D.get_closest_point_to_segment(wpos, _p, tpos).distance_to(wpos) < _LOS_BLOCK_RADIUS:
			return false
	return true

func _fire(target: Node) -> void:
	if not target.has_method("take_damage"):
		return
	var dt : int = Combat.faction_damage_type(_faction)
	Vfx.bolt(_p, WORLD3D.node_plane(target), dt)
	var killed : bool = bool(target.call("take_damage", data.attack_damage * damage_mult, dt))
	if killed and is_instance_valid(_garrison) and _garrison.has_method("report_kill"):
		_garrison.call("report_kill")

func _patrol(delta: float) -> void:
	_patrol_angle += PATROL_ANGULAR_SPEED * delta
	var point : Vector2 = _home + Vector2(cos(_patrol_angle), sin(_patrol_angle)) * PATROL_RADIUS
	_move_toward(point, delta)

func set_patrol(value: bool) -> void:
	_patrolling = value

func set_raid_target(world: Vector2) -> void:
	_raid_target = world
	_has_raid    = true

func clear_raid() -> void:
	_has_raid = false

func _move_toward(point: Vector2, delta: float, clamp_leash: bool = true) -> void:
	var step : float = data.move_speed * delta
	var dir  : Vector2 = point - _p
	var np   : Vector2
	if dir.length() <= step:
		np = point
	else:
		np = _p + dir.normalized() * step
	if clamp_leash:
		var from_home : Vector2 = np - _home
		if from_home.length() > _leash:
			np = _home + from_home.normalized() * _leash
	_set_plane(np)

func _set_plane(p: Vector2) -> void:
	var d : Vector2 = p - _p
	_p = p
	position = WORLD3D.to3(_p, 0.0)
	if d.length_squared() > 0.0001:
		rotation.y = -atan2(d.y, d.x)

func take_damage(amount: float, damage_type: int = -1) -> bool:
	var mult : float = Combat.multiplier(damage_type, data.armor_type) if damage_type >= 0 else 1.0
	_apply_damage(max(0.0, amount * mult - data.armor))
	return _is_dead

func _apply_damage(flat: float) -> void:
	if _is_dead:
		return
	_current_health -= flat
	_update_health_visual()
	if _current_health <= 0.0:
		_is_dead = true
		## U1: the Architect compound punish — losing a tethered unit costs the node its ramp.
		if is_instance_valid(_garrison) and _garrison.has_method("report_unit_lost"):
			_garrison.call("report_unit_lost")
		queue_free()

## -- Visual (3D) --

func _build_visual() -> void:
	## Friendly ground ring — marks it as ours at a glance.
	var ring : MeshInstance3D = MeshInstance3D.new()
	var tm : TorusMesh = TorusMesh.new()
	tm.inner_radius = 13.0
	tm.outer_radius = 16.0
	ring.mesh = tm
	ring.position = Vector3(0.0, 1.0, 0.0)
	ring.material_override = _unlit(Color(0.85, 0.95, 1.0, 0.9))
	add_child(ring)

	## Body — small faction-colored box.
	_mesh = MeshInstance3D.new()
	_mesh.position = Vector3(0.0, 10.0, 0.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = data.color_hint if data != null else Color.CYAN
	if data != null:
		## V3: army wears its faction's substrate (animate=false: small moving bodies
		## don't need the shared breathe/scroll — their gait carries the life).
		_SUBSTRATE.apply(m, data.faction_id, false)
	_mesh.material_override = m
	## V6-lite: per-faction composed silhouette (parts share the material → tints apply).
	UNIT_BODIES.compose(_mesh, data.faction_id if data != null else "", 18.0, m)
	add_child(_mesh)

	## Billboard health bar.
	_make_bar(Color(0.15, 0.15, 0.15), 26.0, 20.0)
	_hp_fill = _make_bar(Color(0.45, 0.85, 1.0), 26.1, 20.0)

func _unlit(col: Color) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _make_bar(col: Color, y: float, width: float) -> MeshInstance3D:
	var q : MeshInstance3D = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(width, 3.5)
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

func _update_health_visual() -> void:
	if _hp_fill != null and data != null and data.max_health > 0.0:
		_hp_fill.scale.x = clampf(_current_health / data.max_health, 0.0, 1.0)
