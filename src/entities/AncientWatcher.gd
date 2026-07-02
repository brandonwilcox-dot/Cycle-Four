## AncientWatcher.gd
## Non-combat Ancient unit that appears at a milestone. Lerps to a target over WALK_DURATION, pushes a
## dialogue notification, then removes itself. Not in "units" — invisible to wave logic and towers.
##
## 3D MIGRATION (Stage 2j): now `extends Node3D` (model/view). Plane pos `_p` drives the transform via
## World3D; visual is a 3D pale cube (was a _draw rect).
extends Node3D

const WORLD3D = preload("res://src/core/World3D.gd")

const WALK_DURATION : float = 4.0
const RECT_SIZE     : float = 32.0
const ANCIENT_COLOR : Color = Color(0.85, 0.80, 0.55, 1.0)

var _p              : Vector2 = Vector2.ZERO
var _target_pos     : Vector2 = Vector2.ZERO
var _start_pos      : Vector2 = Vector2.ZERO
var _dialogue_line  : String  = ""
var _elapsed        : float   = 0.0
var _delivered      : bool    = false

func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

func plane_pos() -> Vector2:
	return _p

## Call immediately after adding to the scene tree (and after place_at).
func setup(target: Vector2, dialogue: String) -> void:
	_target_pos    = target
	_start_pos     = _p
	_dialogue_line = dialogue

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	var body : MeshInstance3D = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(RECT_SIZE, RECT_SIZE, RECT_SIZE)
	body.mesh = bx
	body.position = Vector3(0.0, RECT_SIZE * 0.5, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = ANCIENT_COLOR
	m.emission_enabled = true
	m.emission = ANCIENT_COLOR
	m.emission_energy_multiplier = 0.4
	body.material_override = m
	add_child(body)

func _process(delta: float) -> void:
	if _delivered:
		return
	_elapsed += delta
	var t : float = clampf(_elapsed / WALK_DURATION, 0.0, 1.0)
	_p = _start_pos.lerp(_target_pos, t)
	position = WORLD3D.to3(_p, 0.0)
	if t >= 1.0:
		_delivered = true
		if not _dialogue_line.is_empty():
			EventBus.notification_pushed.emit(_dialogue_line, "info")
		queue_free()
