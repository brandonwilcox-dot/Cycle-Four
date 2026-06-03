## CameraController.gd
## Attaches to Camera2D in WorldMap. Provides pan and zoom for the game map.
##
## Controls:
##   Middle-mouse drag  -- pan
##   Scroll wheel up    -- zoom in  (world point under cursor stays fixed)
##   Scroll wheel down  -- zoom out (world point under cursor stays fixed)
##
## Boundary rules:
##   min_zoom is computed from map dimensions so the map always fills the screen.
##   Camera position is clamped so the viewport never shows outside the map.
##   Both rules update automatically when the map changes size (future 60x34 maps).
extends Camera2D

const ZOOM_MAX  : float = 3.0   ## Maximum zoom-in factor (3x)
const ZOOM_STEP : float = 0.1   ## Proportional step per scroll click (10% of current zoom)

var _map_width  : float = 1920.0
var _map_height : float = 1088.0
var _zoom_min   : float = 1.0

var _dragging   : bool    = false
var _drag_start : Vector2 = Vector2.ZERO  ## Screen position where drag began
var _cam_start  : Vector2 = Vector2.ZERO  ## Camera world position when drag began

func _ready() -> void:
	_read_map_size()
	_update_zoom_min()
	zoom     = Vector2(_zoom_min, _zoom_min)
	position = Vector2(_map_width * 0.5, _map_height * 0.5)
	_clamp_position()

## Reads COLS / ROWS / CELL_SIZE from the sibling MapGrid node.
func _read_map_size() -> void:
	var map_grid : Node = get_parent().get_node_or_null("MapGrid")
	if map_grid == null:
		return
	var cols : int = map_grid.get("COLS")      if map_grid.get("COLS")      != null else 30
	var rows : int = map_grid.get("ROWS")      if map_grid.get("ROWS")      != null else 17
	var cell : int = map_grid.get("CELL_SIZE") if map_grid.get("CELL_SIZE") != null else 64
	_map_width  = float(cols * cell)
	_map_height = float(rows * cell)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb : InputEventMouseButton = event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_MIDDLE:
				_dragging   = mb.pressed
				_drag_start = mb.position
				_cam_start  = position
			MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(1.0, mb.position)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(-1.0, mb.position)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var motion : InputEventMouseMotion = event as InputEventMouseMotion
		## Drag right = camera moves right = world scrolls left, so delta is inverted.
		var delta : Vector2 = (_drag_start - motion.position) / zoom
		position = _cam_start + delta
		_clamp_position()
		get_viewport().set_input_as_handled()

## Applies a proportional zoom step and adjusts camera position so the world
## point under screen_pos stays fixed (zoom-to-cursor).
## direction: +1.0 = zoom in, -1.0 = zoom out.
func _apply_zoom(direction: float, screen_pos: Vector2) -> void:
	var old_zoom : float  = zoom.x
	var new_zoom : float  = clampf(old_zoom * (1.0 + direction * ZOOM_STEP), _zoom_min, ZOOM_MAX)
	if is_equal_approx(new_zoom, old_zoom):
		return
	## Zoom to cursor: keep the world point under screen_pos stationary.
	var vp_center    : Vector2 = get_viewport().get_visible_rect().size * 0.5
	var world_before : Vector2 = position + (screen_pos - vp_center) / old_zoom
	zoom = Vector2(new_zoom, new_zoom)
	var world_after  : Vector2 = position + (screen_pos - vp_center) / new_zoom
	position += world_before - world_after
	_clamp_position()

## Clamps camera position so the viewport never shows outside the map.
func _clamp_position() -> void:
	var vp     : Vector2 = get_viewport().get_visible_rect().size
	var half_w : float   = vp.x / (2.0 * zoom.x)
	var half_h : float   = vp.y / (2.0 * zoom.y)
	## If the visible half exceeds the map half, center on the map axis.
	if half_w >= _map_width * 0.5:
		position.x = _map_width * 0.5
	else:
		position.x = clampf(position.x, half_w, _map_width - half_w)
	if half_h >= _map_height * 0.5:
		position.y = _map_height * 0.5
	else:
		position.y = clampf(position.y, half_h, _map_height - half_h)

## Recomputes minimum zoom from current map dimensions and viewport size.
## min_zoom ensures the map always fills the screen (no black bars).
func _update_zoom_min() -> void:
	var vp : Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0 or _map_width <= 0.0 or _map_height <= 0.0:
		_zoom_min = 1.0
		return
	_zoom_min = maxf(vp.x / _map_width, vp.y / _map_height)
