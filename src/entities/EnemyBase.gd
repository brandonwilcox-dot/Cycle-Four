## EnemyBase.gd
## A destructible enemy stronghold that anchors a wave spawn. Destroyed by the ARMY (Commander +
## friendly units via take_damage); on death emits enemy_base_destroyed(spawn_id). Fields a standing
## guard of its faction's units that chase/grind player forces near it.
##
## 3D MIGRATION (Stage 2f): now `extends Node3D` (model/view). Plane pos _p + place_at()/plane_pos();
## proximity/defender math via World3D. Visual is a crimson 3D block + core + billboard HP bar.
## Conquest keystone — see planning/territory-conquest-plan.md (Phase 1).
extends Node3D

const WORLD3D = preload("res://src/core/World3D.gd")
const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")

const MAX_HEALTH : float = 500.0
const BODY_SIZE   : float = 56.0
const BODY_COLOR  : Color = Color(0.72, 0.12, 0.12, 1.0)
const CORE_COLOR  : Color = Color(1.00, 0.78, 0.20, 1.0)

const UNIT_SCENE      = preload("res://scenes/main/Unit.tscn")
const FRIENDLY_ROSTER = preload("res://src/core/army/FriendlyRoster.gd")

const DEFENDER_MAX             : int   = 3
const DEFENDER_MAX_THREATENED  : int   = 5
const DEFENDER_INTERVAL        : float = 5.0
const DEFENDER_THREAT_INTERVAL : float = 2.0
const DEFENDER_THREAT_RADIUS   : float = 240.0

var spawn_id : StringName = &""
var _p       : Vector2 = Vector2.ZERO

var _max_health     : float = MAX_HEALTH
var _current_health : float = MAX_HEALTH
var _is_dead        : bool  = false
var _hp_fill        : MeshInstance3D = null
var _body_mat       : StandardMaterial3D = null   ## V4: for hit-flash
var _base_mat_emission : float = 0.0   ## V4: for hit-flash
var _hit_flash      : float = 0.0   ## V4: emission spike on damage

var _faction       : String   = ""
var _defender_unit : UnitData = null
var _defenders     : Array    = []
var _produce_timer : float    = 1.0

func setup(p_spawn_id: StringName, faction: String = "") -> void:
	spawn_id = p_spawn_id
	_faction = faction

func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("enemy_bases")
	position = WORLD3D.to3(_p, 0.0)
	_build_visual()
	_defender_unit = FRIENDLY_ROSTER.garrison_unit(_faction)

func take_damage(amount: float, _damage_type: int = -1) -> bool:
	if _is_dead:
		return true
	_current_health = maxf(0.0, _current_health - amount)
	_hit_flash = 1.0   ## V4: visual damage feedback
	_update_health_visual()
	if _current_health <= 0.0:
		_is_dead = true
		_free_defenders()
		EventBus.enemy_base_destroyed.emit(spawn_id)
		queue_free()
		return true
	return false

## -- Phase 3: defender production --

func _process(delta: float) -> void:
	## V4: hit-flash emission on damage
	if _hit_flash > 0.0 and _body_mat != null:
		_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
		_body_mat.emission_energy_multiplier = _base_mat_emission * (1.0 + 2.5 * _hit_flash)
	if _is_dead or _defender_unit == null:
		return
	_defenders = _defenders.filter(func(u): return is_instance_valid(u))
	var threatened : bool = _player_near()
	var cap : int = DEFENDER_MAX_THREATENED if threatened else DEFENDER_MAX
	if _defenders.size() >= cap:
		return
	_produce_timer -= delta
	if _produce_timer > 0.0:
		return
	_produce_timer = DEFENDER_THREAT_INTERVAL if threatened else DEFENDER_INTERVAL
	_spawn_defender()

func _player_near() -> bool:
	for grp in ["commander", "friendly_units"]:
		for t in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(t) and _p.distance_to(WORLD3D.node_plane(t)) <= DEFENDER_THREAT_RADIUS:
				return true
	return false

func _spawn_defender() -> void:
	var layer : Node = get_parent()
	if layer == null:
		return
	var offset : Vector2 = Vector2(randf_range(-28.0, 28.0), randf_range(-28.0, 28.0))
	var d : Node = UNIT_SCENE.instantiate()
	d.call("setup_as_defender", _defender_unit, _p + offset)
	layer.add_child(d)
	_defenders.append(d)

func _free_defenders() -> void:
	for d in _defenders:
		if is_instance_valid(d):
			d.queue_free()
	_defenders.clear()

## -- Visual (3D) --

func _build_visual() -> void:
	## Crimson stronghold block — larger than towers so it reads as a base.
	var body : MeshInstance3D = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(BODY_SIZE, BODY_SIZE, BODY_SIZE)
	body.mesh = bx
	body.position = Vector3(0.0, BODY_SIZE * 0.5, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var bmat : StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = BODY_COLOR
	_SUBSTRATE.apply(bmat, _faction)   ## V3: the base wears its owner faction's substrate
	body.material_override = bmat
	_body_mat = bmat   ## V4: for hit-flash
	_base_mat_emission = bmat.emission_energy_multiplier if bmat.emission_enabled else 0.0   ## V4: for hit-flash
	add_child(body)

	## Bright core pip — marks it as the objective.
	var core : MeshInstance3D = MeshInstance3D.new()
	var sp : SphereMesh = SphereMesh.new()
	sp.radius = 11.0
	sp.height = 22.0
	core.mesh = sp
	core.position = Vector3(0.0, BODY_SIZE + 6.0, 0.0)
	var cmat : StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = CORE_COLOR
	cmat.emission_enabled = true
	cmat.emission = CORE_COLOR
	cmat.emission_energy_multiplier = 1.5
	core.material_override = cmat
	add_child(core)

	## Billboard HP bar above the base.
	var bar_y : float = BODY_SIZE + 24.0
	_make_bar(Color(0.12, 0.12, 0.12), bar_y, BODY_SIZE)
	_hp_fill = _make_bar(Color(0.95, 0.35, 0.30), bar_y + 0.1, BODY_SIZE)

func _make_bar(col: Color, y: float, width: float) -> MeshInstance3D:
	var q : MeshInstance3D = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(width, 6.0)
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
	if _hp_fill == null:
		return
	_hp_fill.scale.x = clampf(_current_health / _max_health, 0.0, 1.0)
