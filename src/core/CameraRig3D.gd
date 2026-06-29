## 3D migration Stage 1: an RTS camera rig. The rig node is the pivot (a point on the ground the
## camera looks at); a Camera3D child sits back+up at a fixed pitch. Wheel zooms (pivot distance),
## arrow/WASD or middle-drag pans the pivot on the XZ plane. Replaces the 2D CameraController.
## Yaw is fixed for now (free orbit is a later polish item).
extends Node3D

const PITCH_DEG : float = 52.0     ## camera tilt — reads structure height at ~45–55°
const FOV       : float = 50.0
const DIST_MIN  : float = 350.0
const DIST_MAX  : float = 3200.0
const ZOOM_STEP : float = 1.12
const PAN_SPEED : float = 1500.0   ## px/s at keyboard pan

var _dist   : float = 1600.0
var _camera : Camera3D = null
var _panning : bool = false

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = FOV
	add_child(_camera)
	_update_camera()

func get_camera() -> Camera3D:
	return _camera

func _update_camera() -> void:
	var pitch : float = deg_to_rad(PITCH_DEG)
	## Camera sits up (+Y) and back (+Z) from the pivot, looking down at it.
	_camera.position = Vector3(0.0, sin(pitch) * _dist, cos(pitch) * _dist)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

func _process(delta: float) -> void:
	var pan : Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.z += 1.0
	if pan != Vector3.ZERO:
		position += pan.normalized() * PAN_SPEED * delta * (_dist / 1600.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb : InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = clampf(_dist / ZOOM_STEP, DIST_MIN, DIST_MAX)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = clampf(_dist * ZOOM_STEP, DIST_MIN, DIST_MAX)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
	elif event is InputEventMouseMotion and _panning:
		var mm : InputEventMouseMotion = event
		position += Vector3(-mm.relative.x, 0.0, -mm.relative.y) * (_dist / 1600.0)
