## MapGrid.gd
## The game board: a 30×17 cell grid (1920×1088 px at 64 px/cell).
## Owns the AStar2D graph so units can query shortest paths to the base.
## Drawn via _draw(); call queue_redraw() after any state change.
## Design ref: core/17_units-maps-buildings.md (standard map topology)
extends Node2D

enum Cell {
	GROUND   = 0,  ## open land -- not enemy-traversable
	OBSTACLE = 1,  ## idle structure blocking movement (Phase C)
	PATH     = 2,  ## enemy corridor
	BASE     = 3,  ## player FOB; path destination
	SPAWN_W  = 4,  ## western enemy spawn
	SPAWN_N  = 5,  ## northern enemy spawn
	SPAWN_S  = 6,  ## southern enemy spawn
	SPAWN_E  = 7,  ## eastern enemy spawn
	WALL     = 8,  ## impassable terrain (future)
	CLAIMED  = 9,  ## friendly territory (Phase E)
}

const CELL_SIZE : int = 64
const COLS      : int = 30
const ROWS      : int = 17

## Cardinal spawn positions (cell coords)
const BASE_POS     := Vector2i(15, 8)
const SPAWN_W_POS  := Vector2i(0,  8)
const SPAWN_N_POS  := Vector2i(15, 0)
const SPAWN_S_POS  := Vector2i(15, 16)
const SPAWN_E_POS  := Vector2i(29, 8)

var _cells : Array[int] = []
var _astar  : AStar2D   = AStar2D.new()

## Spawn cells whose connectivity is enforced by can_place_at().
## Starts empty; WaveSpawner registers each spawn when it goes active.
## Phase D will add SPAWN_N/S/E here as those directions come online.
var _active_spawns : Array[Vector2i] = []

func register_active_spawn(spawn_cell: Vector2i) -> void:
	if not spawn_cell in _active_spawns:
		_active_spawns.append(spawn_cell)

## Returns true if the cell holds Commander-claimed territory.
## Used by Main to validate production building placement.
func is_claimed(col: int, row: int) -> bool:
	return get_cell(col, row) == Cell.CLAIMED

func _ready() -> void:
	_cells.resize(COLS * ROWS)
	_cells.fill(Cell.GROUND)
	var map_data : MapData = DefaultMapBuilder.create()
	if OS.is_debug_build():
		## Phase 2 parity check: build the reference layout with the old hardcoded method,
		## then load from the resource, and assert they are cell-for-cell identical.
		## Remove this block (or leave it) once parity is confirmed in the editor.
		_build_default_paths()
		var reference : Array[int] = _cells.duplicate()
		load_map_data(map_data)
		_assert_parity(reference)
	else:
		load_map_data(map_data)
	queue_redraw()

## -- Public API --

## Loads a MapData resource into the grid, replacing the current cell layout.
## Overwrites _cells, rebuilds the enemy AStar. Call queue_redraw() afterwards if needed.
## Dimensions must match COLS × ROWS; fires an assert otherwise.
func load_map_data(map_data: MapData) -> void:
	assert(
		map_data.dimensions == Vector2i(COLS, ROWS),
		"MapGrid.load_map_data: dimensions mismatch — expected %s, got %s" % [
			str(Vector2i(COLS, ROWS)), str(map_data.dimensions)
		]
	)
	for i in COLS * ROWS:
		_cells[i] = map_data.cell_types[i] as int
	_rebuild_astar()
	## Phase 3: build the cell→zone reverse index. The index is runtime-only and
	## must be rebuilt on every map load (not serialized with the resource).
	map_data.build_zone_index()

func get_cell(col: int, row: int) -> int:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return Cell.WALL
	return _cells[col + row * COLS]

func set_cell(col: int, row: int, cell_type: int) -> void:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return
	_cells[col + row * COLS] = cell_type
	_rebuild_astar()
	queue_redraw()

## -- Phase C: placement validation & rerouting --

## Returns true if a tower may be placed at (col, row).
## Spawn and base cells are always forbidden.
## PATH cells are allowed only when every spawn retains a route to base after
## the cell is converted to OBSTACLE.
func can_place_at(col: int, row: int) -> bool:
	var ct : int = get_cell(col, row)
	## Protect spawn points and the base from being covered
	if ct in [Cell.BASE, Cell.SPAWN_W, Cell.SPAWN_N, Cell.SPAWN_S, Cell.SPAWN_E]:
		return false
	## Non-traversable cells (GROUND, WALL, OBSTACLE, CLAIMED) never affect enemy
	## routing -- placing a tower there cannot disconnect any spawn from the base.
	if not _is_traversable(ct):
		return true
	## PATH or spawn-adjacent cell: test that blocking it keeps all spawns connected.
	return _test_obstacle_ok(col, row)

## Marks (col, row) as occupied by a tower.
## If the cell was traversable (a PATH cell) it becomes OBSTACLE and the AStar
## graph is rebuilt. Returns true when the path layout changed (caller should
## emit EventBus.path_changed so in-flight units reroute).
func mark_tower_placed(col: int, row: int) -> bool:
	if _is_traversable(get_cell(col, row)):
		set_cell(col, row, Cell.OBSTACLE)   ## triggers _rebuild_astar + queue_redraw
		return true
	return false

## Returns world-space waypoints from from_cell to the nearest accessible CLAIMED cell.
## "Accessible" means the CLAIMED cell has at least one orthogonally adjacent traversable
## (PATH/SPAWN/BASE) cell. The path navigates via AStar to that adjacent cell, then
## appends one final step onto the CLAIMED cell itself.
## Returns empty array when no accessible CLAIMED cells exist.
##
## Algorithm: BFS outward through the traversable (PATH/SPAWN/BASE) cell graph from
## from_cell. Stop at the first traversable cell that borders a CLAIMED cell -- that
## is guaranteed to be the nearest one in graph-hop distance. Then ONE AStar query
## gives the actual world-space path. Complexity: O(traversable_cells) instead of
## O(claimed_cells * traversable_cells) -- critical when the map is mostly claimed.
func get_path_to_nearest_claimed(from_cell: Vector2i) -> Array[Vector2]:
	var from_id : int = _cell_id(from_cell.x, from_cell.y)
	if not _astar.has_point(from_id):
		return []

	## BFS through the traversable graph.
	var visited : Dictionary = {from_cell: true}
	var queue   : Array      = [from_cell]

	while not queue.is_empty():
		var cur : Vector2i = queue.pop_front()

		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb : Vector2i = cur + off
			if nb.x < 0 or nb.x >= COLS or nb.y < 0 or nb.y >= ROWS:
				continue

			var nb_type : int = _cells[nb.x + nb.y * COLS]

			if nb_type == Cell.CLAIMED:
				## cur is the nearest traversable cell adjacent to claimed territory.
				## One AStar query gets the path; then append the claimed cell.
				var to_id    : int               = _cell_id(cur.x, cur.y)
				var cell_pts : PackedVector2Array = _astar.get_point_path(from_id, to_id)
				if cell_pts.is_empty():
					return []
				var result : Array[Vector2] = []
				for cp in cell_pts:
					result.append(cell_to_world(int(cp.x), int(cp.y)))
				result.append(cell_to_world(nb.x, nb.y))   ## step onto the claimed cell
				return result

			## Expand to unvisited traversable neighbors.
			if visited.has(nb) or not _is_traversable(nb_type):
				continue
			visited[nb] = true
			queue.append(nb)

	return []   ## No claimed cells accessible from this position

## Reverts a CLAIMED cell back to GROUND.
## Called by Unit._raid_territory() when a flanker reaches its target cell.
func unclaim_cell(col: int, row: int) -> void:
	if get_cell(col, row) == Cell.CLAIMED:
		_cells[col + row * COLS] = Cell.GROUND
		queue_redraw()   ## No AStar rebuild -- CLAIMED was not in the enemy graph

## Marks a GROUND cell as Commander-claimed territory.
## CLAIMED cells render in a distinct colour and will generate resources (Phase E).
## They do NOT extend the enemy AStar graph, so claiming never shortens enemy routes.
func claim_cell(col: int, row: int) -> void:
	if get_cell(col, row) != Cell.GROUND:
		return
	_cells[col + row * COLS] = Cell.CLAIMED
	queue_redraw()   ## No AStar rebuild needed -- CLAIMED is not enemy-traversable

## Returns the nearest traversable cell to world_pos via BFS.
## Used by Unit.reroute() to find a valid start for a fresh AStar query
## after the path changes mid-wave.
func get_nearest_path_cell(world_pos: Vector2) -> Vector2i:
	var origin : Vector2i = world_to_cell(world_pos)
	if _is_traversable(get_cell(origin.x, origin.y)):
		return origin
	## BFS outward until a traversable cell is found
	var visited : Dictionary = {}
	var queue   : Array      = [origin]   ## untyped so pop_front stays simple
	visited[origin] = true
	while not queue.is_empty():
		var cur : Vector2i = queue.pop_front()
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt : Vector2i = cur + off
			if visited.has(nxt):
				continue
			if nxt.x < 0 or nxt.x >= COLS or nxt.y < 0 or nxt.y >= ROWS:
				continue
			visited[nxt] = true
			if _is_traversable(get_cell(nxt.x, nxt.y)):
				return nxt
			queue.append(nxt)
	return BASE_POS   ## fallback -- shouldn't be reached in a valid game state

## -- Private validation --

## Temporarily marks (col, row) as OBSTACLE, rebuilds AStar, checks that
## every defined spawn still has a path to base, then restores the cell.
func _test_obstacle_ok(col: int, row: int) -> bool:
	var prev : int = _cells[col + row * COLS]
	_cells[col + row * COLS] = Cell.OBSTACLE
	_rebuild_astar()
	var ok : bool = _all_spawns_connected()
	_cells[col + row * COLS] = prev
	_rebuild_astar()
	return ok

## Phase 2 parity check. Compares the current _cells against a reference array built
## by the old _build_default_paths(). Prints OK or pushes per-cell error messages.
## Called only in debug builds from _ready(); safe to remove after Phase 2 is confirmed.
func _assert_parity(reference: Array[int]) -> void:
	var mismatches : int = 0
	for i in COLS * ROWS:
		if _cells[i] != reference[i]:
			var col : int = i % COLS
			var row : int = i / COLS
			push_error("MapGrid parity FAIL at (%d,%d): loaded=%d  reference=%d" % [
				col, row, _cells[i], reference[i]
			])
			mismatches += 1
	if mismatches == 0:
		print("MapGrid Phase 2 parity OK -- load_map_data matches _build_default_paths().")
	else:
		push_error("MapGrid Phase 2 parity FAILED: %d mismatch(es). See errors above." % mismatches)

## Returns true when every ACTIVE spawn still has at least one path to base.
## Only registered spawns are checked; inactive spawn paths may be freely blocked.
func _all_spawns_connected() -> bool:
	if _active_spawns.is_empty():
		return true   ## Nothing active yet -- all placements allowed
	var to_id : int = _cell_id(BASE_POS.x, BASE_POS.y)
	if not _astar.has_point(to_id):
		return false
	for spawn in _active_spawns:
		var from_id : int = _cell_id(spawn.x, spawn.y)
		if not _astar.has_point(from_id):
			continue
		if _astar.get_id_path(from_id, to_id).is_empty():
			return false
	return true

## Returns world-space waypoints (cell centres) leading from spawn_cell to base.
## Index 0 is the spawn cell itself -- units skip it (they start there).
## Returns empty array if no path exists.
func get_path_to_base(spawn_cell: Vector2i) -> Array[Vector2]:
	var from_id : int = _cell_id(spawn_cell.x, spawn_cell.y)
	var to_id   : int = _cell_id(BASE_POS.x,   BASE_POS.y)
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		push_error("MapGrid: spawn %s or base not in AStar graph." % spawn_cell)
		return []
	var cell_pts : PackedVector2Array = _astar.get_point_path(from_id, to_id)
	if cell_pts.is_empty():
		push_error("MapGrid: no path from %s to base -- check path connectivity." % spawn_cell)
		return []
	var result : Array[Vector2] = []
	for cp in cell_pts:
		result.append(cell_to_world(int(cp.x), int(cp.y)))
	return result

## Cell ↔ world conversions.
func cell_to_world(col: int, row: int) -> Vector2:
	return Vector2(col * CELL_SIZE + CELL_SIZE * 0.5,
				   row * CELL_SIZE + CELL_SIZE * 0.5)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(clamp(floor(world_pos.x / CELL_SIZE), 0, COLS - 1)),
		int(clamp(floor(world_pos.y / CELL_SIZE), 0, ROWS - 1))
	)

## -- Drawing --

func _draw() -> void:
	var path_col  := Color(0.20, 0.20, 0.32, 1.0)
	var spawn_col := Color(0.42, 0.10, 0.10, 1.0)
	var base_col  := Color(0.52, 0.42, 0.06, 1.0)
	var obs_col   := Color(0.30, 0.22, 0.12, 1.0)
	var claim_col := Color(0.10, 0.30, 0.16, 1.0)   ## dark green: Commander territory
	var line_col  := Color(0.15, 0.15, 0.22, 0.30)

	for row in ROWS:
		for col in COLS:
			var rect := Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			match _cells[col + row * COLS]:
				Cell.PATH:
					draw_rect(rect, path_col)
				Cell.BASE:
					draw_rect(rect, base_col)
				Cell.SPAWN_W, Cell.SPAWN_N, Cell.SPAWN_S, Cell.SPAWN_E:
					draw_rect(rect, spawn_col)
				Cell.OBSTACLE:
					draw_rect(rect, obs_col)
				Cell.CLAIMED:
					draw_rect(rect, claim_col)

	## Subtle grid overlay across the whole board
	for r in ROWS + 1:
		draw_line(Vector2(0, r * CELL_SIZE), Vector2(COLS * CELL_SIZE, r * CELL_SIZE), line_col)
	for c in COLS + 1:
		draw_line(Vector2(c * CELL_SIZE, 0), Vector2(c * CELL_SIZE, ROWS * CELL_SIZE), line_col)

## -- Path building --

## DEPRECATED — no longer called from _ready(). Kept as the parity reference for
## Phase 2 validation and as documentation of the default topology.
## DefaultMapBuilder._build_paths() is the live mirror of this function.
## Both must be kept in sync until Phase 10 (procedural generator) lands.
func _build_default_paths() -> void:
	## West path: TWO-BRANCH network between junction (4,8) and exit (13,8).
	## Blocking most cells forces the other branch; only the short entry corridor
	## and the final two cells before base are critical (single-route chokepoints).
	##
	##   SPAWN_W ──── entry ──── [4,8] ──── Branch A (north loop) ──── [13,8] ──── BASE
	##                                └──── Branch B (south loop) ────┘
	##
	_fill_h(8,   0,  4,  Cell.PATH)   ## entry: row 8 from spawn to junction (4,8)
	_fill_v(4,   4,  12, Cell.PATH)   ## junction vertical: col 4 rows 4-12 (both branches)
	## Branch A -- north loop
	_fill_h(4,   4,  9,  Cell.PATH)   ## row 4 east
	_fill_v(9,   4,  8,  Cell.PATH)   ## col 9 south to exit row
	_fill_h(8,   9,  13, Cell.PATH)   ## row 8 east to exit junction (13,8)
	## Branch B -- south loop
	_fill_h(12,  4,  13, Cell.PATH)   ## row 12 east
	_fill_v(13,  8,  12, Cell.PATH)   ## col 13 north; meets Branch A at (13,8)
	## Final approach (only two cells -- critical, cannot be blocked)
	_fill_h(8,  13,  15, Cell.PATH)

	## North path: jog from SPAWN_N down to row 8, merges into Branch A exit
	_fill_v(15,  0,  3,  Cell.PATH)
	_fill_h(3,  11,  15, Cell.PATH)
	_fill_v(11,  3,  8,  Cell.PATH)
	_fill_h(8,  11,  13, Cell.PATH)   ## overlaps Branch A exit (same cells, fine)

	## East path: two-branch mirror of west between junction (25,8) and exit (16,8)
	_fill_h(8,  25,  29, Cell.PATH)   ## entry: row 8 from spawn to junction (25,8)
	_fill_v(25,  4,  12, Cell.PATH)   ## junction vertical: col 25 rows 4-12
	## Branch A -- north loop (mirror)
	_fill_h(4,  20,  25, Cell.PATH)   ## row 4 west
	_fill_v(20,  4,  8,  Cell.PATH)   ## col 20 south to exit row
	_fill_h(8,  16,  20, Cell.PATH)   ## row 8 west to exit junction (16,8)
	## Branch B -- south loop (mirror)
	_fill_h(12, 16,  25, Cell.PATH)   ## row 12 west
	_fill_v(16,  8,  12, Cell.PATH)   ## col 16 north; meets Branch A at (16,8)
	## East final approach
	_fill_h(8,  15,  16, Cell.PATH)

	## South path: jog from SPAWN_S up to row 8, merges into east exit corridor
	_fill_v(15, 13,  16, Cell.PATH)
	_fill_h(13, 15,  19, Cell.PATH)
	_fill_v(19,  8,  13, Cell.PATH)
	_fill_h(8,  15,  19, Cell.PATH)

	## Stamp spawn and base markers last (override PATH)
	_set_raw(SPAWN_W_POS.x, SPAWN_W_POS.y, Cell.SPAWN_W)
	_set_raw(SPAWN_N_POS.x, SPAWN_N_POS.y, Cell.SPAWN_N)
	_set_raw(SPAWN_S_POS.x, SPAWN_S_POS.y, Cell.SPAWN_S)
	_set_raw(SPAWN_E_POS.x, SPAWN_E_POS.y, Cell.SPAWN_E)
	_set_raw(BASE_POS.x,    BASE_POS.y,    Cell.BASE)

## -- AStar --

func _rebuild_astar() -> void:
	_astar.clear()
	## Register all traversable cells as points (position = cell coords, not world coords)
	for row in ROWS:
		for col in COLS:
			if _is_traversable(_cells[col + row * COLS]):
				_astar.add_point(_cell_id(col, row), Vector2(col, row))
	## Connect orthogonally adjacent traversable cells
	for row in ROWS:
		for col in COLS:
			if not _is_traversable(_cells[col + row * COLS]):
				continue
			var id : int = _cell_id(col, row)
			for off in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var nc : int = col + off.x
				var nr : int = row + off.y
				if nc < 0 or nc >= COLS or nr < 0 or nr >= ROWS:
					continue
				if not _is_traversable(_cells[nc + nr * COLS]):
					continue
				var nid : int = _cell_id(nc, nr)
				if not _astar.are_points_connected(id, nid):
					_astar.connect_points(id, nid)

func _is_traversable(cell_type: int) -> bool:
	## CLAIMED is intentionally excluded -- enemy AStar never walks through
	## friendly territory; it only affects the Commander's footprint visually.
	return cell_type in [
		Cell.PATH, Cell.BASE,
		Cell.SPAWN_W, Cell.SPAWN_N, Cell.SPAWN_S, Cell.SPAWN_E,
	]

func _cell_id(col: int, row: int) -> int:
	return col + row * COLS

## -- Helpers --

func _set_raw(col: int, row: int, ctype: int) -> void:
	if col >= 0 and col < COLS and row >= 0 and row < ROWS:
		_cells[col + row * COLS] = ctype

## Fill a horizontal segment: all cells in `row` from col_a to col_b inclusive.
func _fill_h(row: int, col_a: int, col_b: int, ctype: int) -> void:
	var lo : int = min(col_a, col_b)
	var hi : int = max(col_a, col_b)
	for col in range(lo, hi + 1):
		_set_raw(col, row, ctype)

## Fill a vertical segment: all cells in `col` from row_a to row_b inclusive.
func _fill_v(col: int, row_a: int, row_b: int, ctype: int) -> void:
	var lo : int = min(row_a, row_b)
	var hi : int = max(row_a, row_b)
	for row in range(lo, hi + 1):
		_set_raw(col, row, ctype)
