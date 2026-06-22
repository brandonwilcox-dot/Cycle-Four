## Minimap.gd
## Tactical minimap for the 60×34 board: fog, territory, the FOB, the Commander, and
## enemy blips at a glance. Built programmatically and added by HUD.gd (no .tscn edits).
## Reads MapGrid (resolved from the "map_grid" group) and entity groups; throttled redraw.
extends Control

const CELL_PX        : float = 3.0    ## minimap pixels per map cell
const BORDER         : float = 2.0
const REDRAW_PERIOD  : float = 0.2    ## seconds between redraws (cheap, not per-frame)

## MapGrid.Cell values (kept local to avoid a hard dependency on the enum).
const C_OBSTACLE : int = 1
const C_PATH     : int = 2
const C_BASE     : int = 3
const C_CLAIMED  : int = 9

const COL_BG       : Color = Color(0.04, 0.04, 0.06, 0.90)
const COL_BORDER   : Color = Color(0.45, 0.50, 0.60, 0.80)
const COL_FOG      : Color = Color(0.08, 0.08, 0.11, 1.0)
const COL_GROUND   : Color = Color(0.16, 0.17, 0.22, 1.0)
const COL_PATH     : Color = Color(0.26, 0.26, 0.40, 1.0)
const COL_OBSTACLE : Color = Color(0.38, 0.28, 0.16, 1.0)
const COL_CLAIMED  : Color = Color(0.18, 0.55, 0.28, 1.0)
const COL_BASE     : Color = Color(0.95, 0.80, 0.20, 1.0)
const COL_COMMANDER: Color = Color(1.00, 0.82, 0.18, 1.0)
const COL_ENEMY    : Color = Color(0.95, 0.25, 0.20, 1.0)
const COL_ENEMY_DIM: Color = Color(0.95, 0.25, 0.20, 0.45)   ## sensor-range blip (item 5)
const COL_CONVOY   : Color = Color(0.35, 0.65, 0.95, 1.0)

var _grid     : Node     = null
var _map_data : Resource = null
var _cols     : int      = 0
var _rows     : int      = 0
var _redraw_t : float    = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_grid()

func _process(delta: float) -> void:
	if _grid == null:
		_resolve_grid()
		return
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = REDRAW_PERIOD
		queue_redraw()

func _resolve_grid() -> void:
	_grid = get_tree().get_first_node_in_group("map_grid")
	if _grid == null:
		return
	_map_data = _grid.get("map_data")
	if _map_data != null:
		var dims : Vector2i = _map_data.dimensions
		_cols = dims.x
		_rows = dims.y
		custom_minimum_size = Vector2(_cols * CELL_PX + BORDER * 2.0, _rows * CELL_PX + BORDER * 2.0)
		size = custom_minimum_size
		## Anchor to the bottom-center of the screen (the action/ability grid lives in
		## the bottom-left corner, the selection panel in the bottom-right).
		var vp : Vector2 = get_viewport_rect().size
		position = Vector2((vp.x - size.x) * 0.5, vp.y - size.y - 8.0)

func _draw() -> void:
	if _grid == null or _map_data == null or _cols == 0:
		return
	## Frame.
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)
	draw_rect(Rect2(Vector2.ZERO, size), COL_BORDER, false, 1.0)

	## Cells — fog-gated. Unrevealed cells render as fog; revealed by type.
	for r in _rows:
		for c in _cols:
			var px := Vector2(BORDER + c * CELL_PX, BORDER + r * CELL_PX)
			var rect := Rect2(px, Vector2(CELL_PX, CELL_PX))
			if not _map_data.get_meta_revealed(c + r * _cols):
				draw_rect(rect, COL_FOG)
				continue
			draw_rect(rect, _cell_color(int(_grid.call("get_cell", c, r))))

	## Enemy blips — gated by each unit's own reveal state (item 5): 0 = hidden (skip), 1 = dim
	## blip (sensor range), 2 = full marker. The unit already decided, so no extra fog gate here.
	for unit in get_tree().get_nodes_in_group("units"):
		var tier : int = int(unit.call("minimap_reveal")) if unit.has_method("minimap_reveal") else 2
		if tier <= 0:
			continue
		_draw_blip(unit, COL_ENEMY if tier >= 2 else COL_ENEMY_DIM, 2.0, false)
	## Convoy blips.
	for convoy in get_tree().get_nodes_in_group("convoys"):
		_draw_blip(convoy, COL_CONVOY, 2.0, true)
	## Commander (always shown — it's the player's anchor).
	var cmd : Node = get_tree().get_first_node_in_group("commander")
	if cmd != null:
		_draw_blip(cmd, COL_COMMANDER, 3.0, false)

func _cell_color(cell_type: int) -> Color:
	match cell_type:
		C_PATH:     return COL_PATH
		C_BASE:     return COL_BASE
		C_OBSTACLE: return COL_OBSTACLE
		C_CLAIMED:  return COL_CLAIMED
		_:          return COL_GROUND

## Draws a node's position as a blip. When fog_gated, the blip is hidden if its cell
## isn't revealed (so enemies in the dark don't show).
func _draw_blip(node: Node, col: Color, radius: float, fog_gated: bool) -> void:
	if not (node is Node2D) or not is_instance_valid(node):
		return
	var cell : Vector2i = _grid.call("world_to_cell", (node as Node2D).global_position)
	if cell.x < 0 or cell.x >= _cols or cell.y < 0 or cell.y >= _rows:
		return
	if fog_gated and not _map_data.get_meta_revealed(cell.x + cell.y * _cols):
		return
	var center := Vector2(BORDER + (cell.x + 0.5) * CELL_PX, BORDER + (cell.y + 0.5) * CELL_PX)
	draw_circle(center, radius, col)
