## 3D migration Stage 1: an RTS camera rig. The rig node is the pivot (a point on the ground the
## camera looks at); a Camera3D child orbits it. Controls:
##   WASD / arrows ............. pan the pivot (world NSEW)
##   Q / E ..................... rotate (yaw) left / right
##   wheel ..................... zoom (pivot distance)
##   hold MIDDLE + drag ........ rotate — horizontal = yaw, vertical = pitch (angle)
##   hold MIDDLE + wheel ....... adjust pitch (angle), finer than dragging
##   Delete .................... reset rotation to the preferred view
##   Insert .................... lock the current view as the preferred (what Delete restores)
extends Node3D

const DEFAULT_PITCH_DEG : float = 52.0   ## camera tilt — reads structure height at ~45–55°
const PITCH_MIN_DEG     : float = 15.0
const PITCH_MAX_DEG     : float = 80.0
const FOV               : float = 50.0
const DIST_MIN          : float = 350.0
const DIST_MAX          : float = 14000.0   ## allows zooming out into galaxy range
const GALAXY_ZOOM_DIST  : float = 5000.0    ## past this, the galaxy view shows (board shrinks away)
const ZOOM_STEP         : float = 1.12
const PAN_SPEED         : float = 1500.0   ## px/s at keyboard pan
const YAW_KEY_SPEED     : float = 1.4      ## rad/s of yaw while holding Q / E
const YAW_DRAG_SENS     : float = 0.006    ## rad per pixel of horizontal drag
const PITCH_DRAG_SENS   : float = 0.20     ## deg per pixel of vertical drag
const PITCH_WHEEL_STEP  : float = 4.0      ## deg per wheel notch while rotating

## V4 screen shake — a trauma pool that decays; offset ∝ trauma² so small hits barely
## register and big ones land. Quiet over loud: the max offset is deliberately small.
const TRAUMA_DECAY     : float = 1.6    ## trauma/sec
const SHAKE_MAX_OFFSET : float = 10.0   ## px at full trauma (scaled by zoom)

var _dist       : float = 1600.0
var _yaw        : float = 0.0                  ## radians
var _pitch      : float = DEFAULT_PITCH_DEG    ## degrees
var _pref_yaw   : float = 0.0                  ## preferred view (Insert sets, Delete restores)
var _pref_pitch : float = DEFAULT_PITCH_DEG
var _camera     : Camera3D = null
var _rotating   : bool = false
var _trauma     : float = 0.0
var _shake_rng  : RandomNumberGenerator = RandomNumberGenerator.new()

## Feed the shake pool (base breach, base destroyed, Commander down). Clamped; several
## small hits build to a visible shudder rather than each being invisible.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _ready() -> void:
	add_to_group("camera_rig")   ## GalaxyView finds the rig here to gate its visibility
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.far = 40000.0        ## see galaxy nodes far from the board when zoomed out
	add_child(_camera)
	_update_camera()

func get_camera() -> Camera3D:
	return _camera

## True while zoomed out into galaxy range — continuous tactical→galactic zoom (no separate screen).
func is_galaxy_zoom() -> bool:
	return _dist >= GALAXY_ZOOM_DIST

## Page Up — near top-down birds-eye centered on `center`, zoomed to frame `dist`.
func snap_birdseye(center: Vector3, dist: float) -> void:
	position = center
	_yaw = 0.0
	_pitch = PITCH_MAX_DEG
	_dist = clampf(dist, DIST_MIN, DIST_MAX)
	_update_camera()

## Page Down — focus on `center` at the default tactical angle, zoomed to frame `dist`.
func snap_focus(center: Vector3, dist: float) -> void:
	position = center
	_pitch = DEFAULT_PITCH_DEG
	_dist = clampf(dist, DIST_MIN, DIST_MAX)
	_update_camera()

func _update_camera() -> void:
	rotation.y = _yaw
	var pitch : float = deg_to_rad(_pitch)
	## Camera sits up (+Y) and back (+Z) from the pivot, in the rig's (yaw-rotated) local space.
	_camera.position = Vector3(0.0, sin(pitch) * _dist, cos(pitch) * _dist)
	_camera.look_at(global_position, Vector3.UP)   ## global_position == the pivot

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
		## World-axis NSEW pan, scaled by zoom so it feels constant on screen.
		position += pan.normalized() * PAN_SPEED * delta * (_dist / 1600.0)

	## Q / E — hold to rotate (yaw) the view left / right.
	var yaw_in : float = 0.0
	if Input.is_key_pressed(KEY_Q):
		yaw_in += 1.0
	if Input.is_key_pressed(KEY_E):
		yaw_in -= 1.0
	if yaw_in != 0.0:
		_yaw += yaw_in * YAW_KEY_SPEED * delta
		_update_camera()

	## V4 screen shake: reset to the clean pose, then jitter the camera off it. The final
	## frame (trauma reaching 0) ends on _update_camera() — the pose is always left clean.
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * delta)
		_update_camera()
		var s : float = _trauma * _trauma * SHAKE_MAX_OFFSET * (_dist / 1600.0)
		_camera.position += Vector3(
			_shake_rng.randf_range(-s, s),
			_shake_rng.randf_range(-s, s),
			0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb : InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_MIDDLE:
				_rotating = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					if _rotating:
						_set_pitch(_pitch + PITCH_WHEEL_STEP)
					else:
						_dist = clampf(_dist / ZOOM_STEP, DIST_MIN, DIST_MAX)
						_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					if _rotating:
						_set_pitch(_pitch - PITCH_WHEEL_STEP)
					else:
						_dist = clampf(_dist * ZOOM_STEP, DIST_MIN, DIST_MAX)
						_update_camera()
	elif event is InputEventMouseMotion and _rotating:
		var mm : InputEventMouseMotion = event
		_yaw -= mm.relative.x * YAW_DRAG_SENS
		_set_pitch(_pitch + mm.relative.y * PITCH_DRAG_SENS)   ## also refreshes the camera
	elif event is InputEventKey and event.pressed and not event.echo:
		var key : InputEventKey = event
		if key.keycode == KEY_DELETE:
			_yaw = _pref_yaw
			_pitch = _pref_pitch
			_update_camera()
		elif key.keycode == KEY_INSERT:
			_pref_yaw = _yaw
			_pref_pitch = _pitch

func _set_pitch(deg: float) -> void:
	_pitch = clampf(deg, PITCH_MIN_DEG, PITCH_MAX_DEG)
	_update_camera()
