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

## HUD bars overlay the top header strip and the bottom command/minimap area. The map
## is framed within the band BETWEEN them so spawns/units near the edges are never hidden
## under opaque UI. Values are in the fixed 1920×1080 canvas (stretch = keep), matching
## the HUD offsets in HUD.tscn (header bottom ≈ 66; bottom minimap top ≈ 966).
const HUD_TOP_INSET    : float = 72.0
const HUD_BOTTOM_INSET : float = 120.0

## Preload MapGrid to read its constants directly.
## node.get() cannot access GDScript consts — only exported vars.
const _MAP_GRID_SCRIPT = preload("res://src/core/map/MapGrid.gd")

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

## Reads COLS / ROWS / CELL_SIZE from the MapGrid script constants.
## Uses preload rather than node.get() — GDScript const members are not
## accessible via duck-typed get() calls; only exported vars are.
func _read_map_size() -> void:
	_map_width  = float(_MAP_GRID_SCRIPT.COLS * _MAP_GRID_SCRIPT.CELL_SIZE)
	_map_height = float(_MAP_GRID_SCRIPT.ROWS * _MAP_GRID_SCRIPT.CELL_SIZE)

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

## Clamps camera position so the map never shows outside the playable band.
## Horizontal: the viewport spans full width, clamped to the map as usual.
## Vertical: the map is framed within the band [HUD_TOP_INSET, vp.y - HUD_BOTTOM_INSET]
## so its edges stay clear of the top header and bottom HUD. `position` is the world
## point shown at the viewport centre (no Camera2D.offset), so screen↔world math used
## elsewhere (clicks, zoom-to-cursor) is unaffected.
func _clamp_position() -> void:
	var vp     : Vector2 = get_viewport().get_visible_rect().size
	var half_w : float   = vp.x / (2.0 * zoom.x)
	if half_w >= _map_width * 0.5:
		position.x = _map_width * 0.5
	else:
		position.x = clampf(position.x, half_w, _map_width - half_w)

	var vp_center_y  : float = vp.y * 0.5
	var band_h_world : float = (vp.y - HUD_TOP_INSET - HUD_BOTTOM_INSET) / zoom.y
	if band_h_world >= _map_height:
		## Whole map fits the band: centre the map within the band (not the screen).
		var shift_px_y : float = (HUD_TOP_INSET - HUD_BOTTOM_INSET) * 0.5
		position.y = _map_height * 0.5 - shift_px_y / zoom.y
	else:
		## Map taller than the band: keep the band's top/bottom inside the map.
		var top_world    : float = (HUD_TOP_INSET - vp_center_y) / zoom.y
		var bottom_world : float = ((vp.y - HUD_BOTTOM_INSET) - vp_center_y) / zoom.y
		position.y = clampf(position.y, -top_world, _map_height - bottom_world)

## Recomputes minimum zoom from current map dimensions and viewport size.
## min_zoom CONTAINS the whole map within the playable band (full width × the band
## height), so the entire board is visible and framed clear of the HUD bars. The map
## is narrower than 16:9, so this leaves dark side margins — intentional framing.
func _update_zoom_min() -> void:
	var vp : Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0 or _map_width <= 0.0 or _map_height <= 0.0:
		_zoom_min = 1.0
		return
	var band_h : float = maxf(1.0, vp.y - HUD_TOP_INSET - HUD_BOTTOM_INSET)
	_zoom_min = minf(vp.x / _map_width, band_h / _map_height)
