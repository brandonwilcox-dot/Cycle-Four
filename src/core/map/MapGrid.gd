## MapGrid.gd
## The game board: a 60×34 cell grid (3840×2176 px at 64 px/cell).
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
const COLS      : int = 60
const ROWS      : int = 34

## Cardinal spawn positions (cell coords)
const BASE_POS     := Vector2i(30, 17)
const SPAWN_W_POS  := Vector2i(0,  17)
const SPAWN_N_POS  := Vector2i(30, 0)
const SPAWN_S_POS  := Vector2i(30, 33)
const SPAWN_E_POS  := Vector2i(59, 17)

var _cells : Array[int] = []
var _astar  : AStar2D   = AStar2D.new()

## Phase 7: friendly-side AStar. Reflects cells the commander and future friendly
## entities can traverse (CLAIMED + GROUND for now). Mutates incrementally on claim
## /unclaim events. Distinct from `_astar` so enemy pathfinding (Constraint #1) is
## never affected. Not yet consumed by Commander movement — kept available for
## convoys (Phase 8) and friendly escorts (later phases).
var _friendly_astar : AStar2D = AStar2D.new()

## The MapData resource currently loaded. Source of truth for spawn points and zones.
## Set by load_map_data(); consumers (Commander, WaveSpawner) may read it directly.
var map_data : MapData = null

## Phase 4: register_active_spawn() / _active_spawns are retired.
## Connectivity validation now derives active spawn cells from map_data.spawn_points
## (see _all_spawns_connected()).

## Returns true if the cell holds Commander-claimed territory.
## Used by Main to validate production building placement.
func is_claimed(col: int, row: int) -> bool:
	return get_cell(col, row) == Cell.CLAIMED

## Returns the total number of GROUND cells on the map.
## Used by MilestoneManager to compute the Bloom 60% coverage condition.
func count_ground_cells() -> int:
	var n : int = 0
	for c in _cells:
		if c == Cell.GROUND or c == Cell.CLAIMED:
			n += 1
	return n

## Returns the number of CLAIMED cells on the map.
func count_claimed_cells() -> int:
	var n : int = 0
	for c in _cells:
		if c == Cell.CLAIMED:
			n += 1
	return n

## Phase 10: preload the generator script directly. class_name resolution
## intermittently fails for freshly-added scripts in Godot 4 until the editor
## rescans; preload avoids the parse-time identifier issue.
const MapGeneratorScript = preload("res://src/core/map/MapGenerator.gd")

func _ready() -> void:
	## Discoverable by entities that need area reveal/claim (FOB, towers, buildings)
	## without hard-coding a relative node path.
	add_to_group("map_grid")
	_cells.resize(COLS * ROWS)
	_cells.fill(Cell.GROUND)
	## Phase 10: procedural generator is the live path. Each session boots a fresh
	## seed; the validation pass inside MapGenerator guarantees the emitted MapData
	## is playable (every spawn reaches BASE; every depot sits on GROUND). The
	## old DefaultMapBuilder remains in the tree as a fallback inside the
	## generator's reroll loop and as a reference for the tutorial map.
	var data : MapData = MapGeneratorScript.generate()
	load_map_data(data)
	queue_redraw()

## -- Public API --

## Loads a MapData resource into the grid, replacing the current cell layout.
## Overwrites _cells, rebuilds the enemy AStar, and stores a reference for later
## spawn/zone queries. Dimensions must match COLS × ROWS; fires an assert otherwise.
func load_map_data(data: MapData) -> void:
	assert(
		data.dimensions == Vector2i(COLS, ROWS),
		"MapGrid.load_map_data: dimensions mismatch — expected %s, got %s" % [
			str(Vector2i(COLS, ROWS)), str(data.dimensions)
		]
	)
	map_data = data
	for i in COLS * ROWS:
		_cells[i] = data.cell_types[i] as int
	_rebuild_astar()
	_rebuild_friendly_astar()
	## Phase 3: build the cell→zone reverse index. The index is runtime-only and
	## must be rebuilt on every map load (not serialized with the resource).
	data.build_zone_index()
	## Phase 5: hand the map to the objective subsystem. It resolves the active
	## objective list against FactionManager.active_faction/sub_path and computes
	## the spawn seal_condition_refs from objective.seals. Must run after spawn
	## points exist on the resource.
	ObjectiveManager.set_map(data)
	## Phase 8: hand the map to the convoy subsystem. It needs map_data for graph
	## traversal and map_grid for cell→world conversion when spawning convoys.
	ConvoyManager.set_map(data, self)
	## D-1: give MilestoneManager a grid reference so it can query cell counts
	## for the Bloom coverage condition and the Mesh depot-connectivity count.
	MilestoneManager.set_map_grid(self)

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
	## Reject off-map cells outright. Without this, an out-of-bounds click maps to a
	## WALL cell (non-traversable, so "placeable" below) and the tower is spawned at a
	## world position the camera never shows — placed, but invisible to the player.
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return false
	var ct : int = get_cell(col, row)
	## Protect the base from being covered.
	if ct == Cell.BASE:
		return false
	## Protect spawn point positions (now PATH cells, identified via MapData).
	if map_data != null and map_data.is_spawn_at(Vector2i(col, row)):
		return false
	## Build only where the player has explored — no placing into unrevealed fog.
	if map_data != null and not map_data.get_meta_revealed(col + row * COLS):
		return false
	## Non-traversable cells (GROUND, WALL, OBSTACLE, CLAIMED) never affect enemy
	## routing -- placing a tower there cannot disconnect any spawn from the base.
	if not _is_traversable(ct):
		return true
	## PATH cell: test that blocking it keeps every active spawn connected.
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

## Reverts a sold tower's cell. If the tower had blocked a PATH cell (now OBSTACLE),
## restore it to PATH and rebuild the enemy graph. Returns true if the layout changed
## (caller should emit EventBus.path_changed so in-flight units reroute).
func unmark_tower(col: int, row: int) -> bool:
	if get_cell(col, row) == Cell.OBSTACLE:
		set_cell(col, row, Cell.PATH)   ## triggers _rebuild_astar + queue_redraw
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
## Phase 7: friendly AStar is unchanged because both GROUND and CLAIMED are friendly-
## traversable. If a future cell type splits this assumption (e.g. CLAIMED becomes
## friendly-only while GROUND is shared), incremental friendly AStar maintenance
## belongs here.
func claim_cell(col: int, row: int) -> void:
	if get_cell(col, row) != Cell.GROUND:
		return
	_cells[col + row * COLS] = Cell.CLAIMED
	queue_redraw()   ## No AStar rebuild needed -- CLAIMED is not enemy-traversable

## -- Sphere-of-influence area operations --
## These power the Commander's sight-range claim, the FOB's rank-scaling territory,
## and the sight/sensor spheres every structure projects. Radius is Chebyshev (square).

## Claims every GROUND cell within `radius` of `center`. Returns the list of cells
## newly converted to CLAIMED so the caller can apply economy + emit territory_claimed.
## Already-claimed / non-GROUND cells are skipped, so repeated calls are cheap and idempotent.
## Batches queue_redraw() — single redraw call regardless of cell count to avoid event thrashing.
func claim_area(center: Vector2i, radius: int) -> Array[Vector2i]:
	var newly : Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c : int = center.x + dx
			var r : int = center.y + dy
			if c < 0 or c >= COLS or r < 0 or r >= ROWS:
				continue
			if _cells[c + r * COLS] != Cell.GROUND:
				continue
			_cells[c + r * COLS] = Cell.CLAIMED
			newly.append(Vector2i(c, r))
	if not newly.is_empty():
		queue_redraw()   ## Single call; don't emit one per cell
	return newly

## -- Per-territory persistence (claims) --

## Flat indices (col + row*COLS) of all CLAIMED cells — captured into a territory's saved
## development so a Continue can restore the player's claimed ground. JSON-safe (plain ints).
func get_claimed_indices() -> Array:
	var out : Array = []
	for i in COLS * ROWS:
		if _cells[i] == Cell.CLAIMED:
			out.append(i)
	return out

## Re-applies saved CLAIMED indices onto the current (freshly-loaded, identical-seed) map.
## Only GROUND → CLAIMED, mirroring claim_cell; economy/territory rates are restored separately
## from the save, so this touches map state only (no re-registration, no AStar rebuild).
func apply_claimed_indices(indices: Array) -> void:
	var changed : bool = false
	for v in indices:
		var i : int = int(v)
		if i >= 0 and i < COLS * ROWS and _cells[i] == Cell.GROUND:
			_cells[i] = Cell.CLAIMED
			changed = true
	if changed:
		queue_redraw()

## C3 (raids): the nearest GROUND cell on the CLAIMED frontier — a GROUND cell orthogonally
## adjacent to a CLAIMED or BASE cell — within `max_radius` (Chebyshev) of `from_cell`. A
## garrison raids this so the player's territory grows outward contiguously. (-1,-1) if none.
func get_raid_target(from_cell: Vector2i, max_radius: int) -> Vector2i:
	var best   : Vector2i = Vector2i(-1, -1)
	var best_d : int      = 0x7fffffff
	for dy in range(-max_radius, max_radius + 1):
		for dx in range(-max_radius, max_radius + 1):
			var c : int = from_cell.x + dx
			var r : int = from_cell.y + dy
			if c < 0 or c >= COLS or r < 0 or r >= ROWS:
				continue
			if _cells[c + r * COLS] != Cell.GROUND:
				continue
			if not _has_claimed_neighbor(c, r):
				continue
			var d : int = absi(dx) + absi(dy)
			if d < best_d:
				best_d = d
				best   = Vector2i(c, r)
	return best

func _has_claimed_neighbor(col: int, row: int) -> bool:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc : int = col + off.x
		var nr : int = row + off.y
		if nc < 0 or nc >= COLS or nr < 0 or nr >= ROWS:
			continue
		var t : int = _cells[nc + nr * COLS]
		if t == Cell.CLAIMED or t == Cell.BASE:
			return true
	return false

## Reveals fog for every in-bounds cell within `radius` of `center`. Emits
## EventBus.region_revealed with the newly-revealed cells (drives spawn activation /
## redraw). Returns the count revealed.
func reveal_area(center: Vector2i, radius: int) -> int:
	if map_data == null:
		return 0
	var newly : Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c : int = center.x + dx
			var r : int = center.y + dy
			if c < 0 or c >= COLS or r < 0 or r >= ROWS:
				continue
			var idx : int = c + r * COLS
			if map_data.get_meta_revealed(idx):
				continue
			map_data.set_meta_revealed(idx, true)
			newly.append(Vector2i(c, r))
	if not newly.is_empty():
		queue_redraw()
		EventBus.region_revealed.emit(newly)
	return newly.size()

## Sensor sweep: the annulus between `inner_radius` (exclusive) and `outer_radius`
## (inclusive) of `center`. Detects (but does not reveal) still-fogged cells and emits
## EventBus.region_sensed so objectives in the outer band show as DETECTED.
func sense_area(center: Vector2i, inner_radius: int, outer_radius: int) -> void:
	if map_data == null:
		return
	## Stealth detection (Pass 2): the FULL sensor disk (inner sight + outer band) flags
	## the persistent `sensed` bit, so stealth units are visible/targetable anywhere a
	## detector's sensor reaches. The region_sensed EVENT still fires only for fogged
	## cells in the outer annulus (objective DETECTED telegraphy — unchanged).
	var sensed_event : Array[Vector2i] = []
	for dy in range(-outer_radius, outer_radius + 1):
		for dx in range(-outer_radius, outer_radius + 1):
			var c : int = center.x + dx
			var r : int = center.y + dy
			if c < 0 or c >= COLS or r < 0 or r >= ROWS:
				continue
			var idx : int = c + r * COLS
			map_data.set_meta_sensed(idx, true)
			if absi(dx) <= inner_radius and absi(dy) <= inner_radius:
				continue
			if map_data.get_meta_revealed(idx):
				continue
			sensed_event.append(Vector2i(c, r))
	if not sensed_event.is_empty():
		EventBus.region_sensed.emit(sensed_event)

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
			@warning_ignore("integer_division")
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
## Active spawns are derived from map_data.spawn_points (state == ACTIVE).
## DORMANT/SEALED spawn paths may be freely blocked.
func _all_spawns_connected() -> bool:
	if map_data == null:
		return true   ## No map loaded -- allow (only matters at startup edge cases)
	var active : Array[Vector2i] = map_data.get_active_spawn_cells()
	if active.is_empty():
		return true   ## Nothing active -- all placements allowed
	var to_id : int = _cell_id(BASE_POS.x, BASE_POS.y)
	if not _astar.has_point(to_id):
		return false
	for spawn in active:
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

## Phase B (faction-flavored pathing): returns up to `k` DISTINCT world-space routes
## from spawn_cell to base, ordered shortest-first. Uses the penalty method — find the
## shortest path, temporarily inflate the weight_scale of its interior cells, re-query
## for a detour, repeat — then restore all weights. Where the map offers no alternate
## corridor the routes collapse to one (the array is shorter than k). Callers map the
## set to faction behavior: Architects take route[0] (most direct), Bloom spread evenly
## across the set (sprawl), Mesh pick the least-defended (weak-point seek).
## Each element is an Array[Vector2] of cell-centre waypoints; index 0 is the spawn cell.
func get_diverse_paths_to_base(spawn_cell: Vector2i, k: int = 3) -> Array:
	var from_id : int = _cell_id(spawn_cell.x, spawn_cell.y)
	var to_id   : int = _cell_id(BASE_POS.x,   BASE_POS.y)
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return []
	const PENALTY : float = 3.0
	var routes        : Array         = []
	var seen_sigs     : Array[String] = []
	var penalized_ids : Array[int]    = []
	for _i in range(maxi(1, k)):
		var pts : PackedVector2Array = _astar.get_point_path(from_id, to_id)
		if pts.is_empty():
			break
		## Signature of the cell sequence — detect when no new alternative exists.
		var sig : String = ""
		for p in pts:
			sig += "%d,%d;" % [int(p.x), int(p.y)]
		if sig in seen_sigs:
			break
		seen_sigs.append(sig)
		var world_path : Array[Vector2] = []
		for p in pts:
			world_path.append(cell_to_world(int(p.x), int(p.y)))
		routes.append(world_path)
		## Penalize this route's INTERIOR cells (skip the unavoidable entry/approach
		## chokepoints) so the next query is pushed onto a parallel corridor if one exists.
		for i in range(2, pts.size() - 2):
			var pid : int = _cell_id(int(pts[i].x), int(pts[i].y))
			_astar.set_point_weight_scale(pid, _astar.get_point_weight_scale(pid) * PENALTY)
			penalized_ids.append(pid)
	## Restore every weight we touched so other AStar queries are unaffected.
	for pid in penalized_ids:
		_astar.set_point_weight_scale(pid, 1.0)
	return routes

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
			var idx : int = col + row * COLS
			## Phase 6 fog-of-war: unrevealed cells render as background (no fill).
			## The dark default_clear_color shows through, which IS the fog.
			if map_data != null and not map_data.get_meta_revealed(idx):
				continue
			var rect := Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			match _cells[idx]:
				Cell.PATH:
					draw_rect(rect, path_col)
				Cell.BASE:
					draw_rect(rect, base_col)
				Cell.OBSTACLE:
					draw_rect(rect, obs_col)
				Cell.CLAIMED:
					draw_rect(rect, claim_col)
	## Phase 4: spawn cells are PATH underneath; overlay them in the spawn colour by
	## walking map_data.spawn_points. Dormant spawns are drawn in a dimmer hue.
	## Phase 6: spawns that are NOT yet revealed by fog are hidden entirely — drawing
	## a dormant spawn before reveal would leak its position to the player.
	if map_data != null:
		var spawn_dim := Color(spawn_col.r * 0.55, spawn_col.g * 0.55, spawn_col.b * 0.55, 1.0)
		for sp in map_data.spawn_points:
			if sp == null:
				continue
			var sp_idx : int = sp.position.x + sp.position.y * COLS
			if not map_data.get_meta_revealed(sp_idx):
				continue
			var rect := Rect2(sp.position.x * CELL_SIZE, sp.position.y * CELL_SIZE,
							  CELL_SIZE, CELL_SIZE)
			if sp.state == SpawnPoint.SpawnState.ACTIVE:
				draw_rect(rect, spawn_col)
			else:
				draw_rect(rect, spawn_dim)

	## Phase 8: render SupportGraph BuildingNode markers (depots and other non-FOB
	## infrastructure) as a warm amber inset square so the player can spot important
	## off-FOB spots. Gated by fog reveal like everything else — depot in the dark
	## stays invisible until the Commander explores its cell. The FOB itself has its
	## own scene visual (Base.tscn), so skip it.
	if map_data != null and map_data.support_graph != null:
		var depot_fill := Color(1.00, 0.55, 0.20, 1.0)   ## warm amber
		var depot_edge := Color(0.40, 0.20, 0.05, 1.0)   ## dark amber outline
		var inset      : float = 12.0
		for node_id in map_data.support_graph.nodes:
			var node : BuildingNode = map_data.support_graph.nodes[node_id]
			if node == null or node_id == map_data.support_graph.fob_node_id:
				continue
			var d_idx : int = node.position.x + node.position.y * COLS
			if not map_data.get_meta_revealed(d_idx):
				continue
			var inner := Rect2(
				node.position.x * CELL_SIZE + inset,
				node.position.y * CELL_SIZE + inset,
				CELL_SIZE - inset * 2.0,
				CELL_SIZE - inset * 2.0
			)
			draw_rect(inner, depot_fill)
			draw_rect(inner, depot_edge, false, 2.0)

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

	## Stamp the base marker last. Phase 4: spawn positions are no longer special cells —
	## they remain PATH (already written by _fill_h above). Identity lives on the
	## SpawnPoint resource list in MapData.
	_set_raw(BASE_POS.x, BASE_POS.y, Cell.BASE)

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

## Phase 7: rebuilds the friendly AStar from scratch. Points = every GROUND, CLAIMED,
## or BASE cell (the surfaces a friendly entity can walk). Called on map load; later
## phases will call incremental add/remove on claim/unclaim instead of full rebuilds.
func _rebuild_friendly_astar() -> void:
	_friendly_astar.clear()
	for row in ROWS:
		for col in COLS:
			if _is_friendly_traversable(_cells[col + row * COLS]):
				_friendly_astar.add_point(_cell_id(col, row), Vector2(col, row))
	for row in ROWS:
		for col in COLS:
			if not _is_friendly_traversable(_cells[col + row * COLS]):
				continue
			var id : int = _cell_id(col, row)
			for off in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var nc : int = col + off.x
				var nr : int = row + off.y
				if nc < 0 or nc >= COLS or nr < 0 or nr >= ROWS:
					continue
				if not _is_friendly_traversable(_cells[nc + nr * COLS]):
					continue
				var nid : int = _cell_id(nc, nr)
				if not _friendly_astar.are_points_connected(id, nid):
					_friendly_astar.connect_points(id, nid)

## What cells the commander and friendly entities can walk on. PATH cells are
## intentionally excluded — those are enemy corridors. CLAIMED, GROUND, and BASE
## form the friendly traversal surface.
func _is_friendly_traversable(cell_type: int) -> bool:
	return cell_type == Cell.GROUND or cell_type == Cell.CLAIMED or cell_type == Cell.BASE

func _is_traversable(cell_type: int) -> bool:
	## CLAIMED is intentionally excluded -- enemy AStar never walks through
	## friendly territory; it only affects the Commander's footprint visually.
	## Phase 4: SPAWN_* removed from this set — spawn cells are now PATH (which is
	## already traversable). The Cell.SPAWN_* enum values remain for backwards
	## reference but no cell in the array uses them after Phase 4.
	return cell_type == Cell.PATH or cell_type == Cell.BASE

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
