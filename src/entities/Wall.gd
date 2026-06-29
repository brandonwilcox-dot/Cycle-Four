## Wall.gd
## Phase 4B — the Architect passive barrier. A destructible, cell-occupying blocker. NOT added to the
## enemy AStar, so enemies path into it and must DESTROY it to pass. The Commander builds it like any
## structure; enemies grind it in melee (Unit._engaged_friendly includes built walls).
##
## 3D MIGRATION (Stage 2g): now `extends Node3D` (model/view). Static plane pos _p + place_at()/
## plane_pos(); visual is a 3D steel block with seams; ghosts via material alpha while unbuilt.
extends Node3D

const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")
const WORLD3D = preload("res://src/core/World3D.gd")

const MAX_HEALTH   : float = 160.0
const START_HEALTH : float = 10.0
const BODY_SIZE    : float = 50.0
const BODY_COLOR   : Color = Color(0.55, 0.58, 0.62, 1.0)

var _p          : Vector2 = Vector2.ZERO
var _max_health : float   = MAX_HEALTH
var _health     : float   = START_HEALTH
var _built      : bool    = false
var _is_dead    : bool    = false
var _body_mats  : Array[StandardMaterial3D] = []
var _build_bar  : MeshInstance3D = null

func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("walls")
	position = WORLD3D.to3(_p, 0.0)
	_max_health = MAX_HEALTH * FACTION_PERKS.health_mult(FactionManager.active_faction)
	_health     = START_HEALTH
	_built      = false
	_build_visual()
	_refresh_build_visual()

func is_built() -> bool:
	return _built

func mark_built() -> void:
	_health = _max_health
	_built  = true
	_refresh_build_visual()

func needs_engineering() -> bool:
	return _health < _max_health

func receive_engineering(amount: float) -> bool:
	if _health >= _max_health:
		return false
	_health = minf(_max_health, _health + amount)
	if not _built and _health >= _max_health:
		_built = true
		EventBus.notification_pushed.emit("Wall raised.", "positive")
	_refresh_build_visual()
	return true

func take_damage(amount: float, _damage_type: int = -1) -> bool:
	if _is_dead:
		return true
	_health = maxf(0.0, _health - amount)
	_refresh_build_visual()
	if _health <= 0.0:
		_is_dead = true
		queue_free()
		return true
	return false

## -- Visual (3D) --

func _build_visual() -> void:
	_body_mats.clear()
	## Steel barrier block.
	var body : MeshInstance3D = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(BODY_SIZE, 44.0, BODY_SIZE)
	body.mesh = bx
	body.position = Vector3(0.0, 22.0, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.material_override = _mat(BODY_COLOR)
	add_child(body)

	## Horizontal seams so it reads as a blast wall, not a flat block.
	for sy in [14.0, 32.0]:
		var seam : MeshInstance3D = MeshInstance3D.new()
		var sm : BoxMesh = BoxMesh.new()
		sm.size = Vector3(BODY_SIZE + 2.0, 4.0, BODY_SIZE + 2.0)
		seam.mesh = sm
		seam.position = Vector3(0.0, sy, 0.0)
		seam.material_override = _mat(BODY_COLOR.darkened(0.4))
		add_child(seam)

	## Construction/damage bar — billboarded above.
	_build_bar = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(BODY_SIZE, 5.0)
	_build_bar.mesh = qm
	_build_bar.position = Vector3(0.0, 54.0, 0.0)
	var bmat : StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.45, 1.0, 0.7)
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_build_bar.material_override = bmat
	_build_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_build_bar)

func _mat(col: Color) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	_body_mats.append(m)
	return m

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
