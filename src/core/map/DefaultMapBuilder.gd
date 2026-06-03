## DefaultMapBuilder.gd
## Constructs the hand-authored default MapData (30×17) that replicates the layout
## from MapGrid._build_default_paths(). This is the Phase 2 bridge resource.
## Phase 10 (procedural generator) will replace this for all maps except the tutorial.
class_name DefaultMapBuilder
extends RefCounted

## Local mirror of MapGrid.Cell enum values.
## Must stay in sync with MapGrid.Cell if those values ever change.
const _GROUND  : int = 0
const _PATH    : int = 2
const _BASE    : int = 3
## SPAWN_* (4-7) intentionally NOT mirrored here. Phase 4 retired spawn cell types
## in favour of MapData.spawn_points. Spawn cells are now PATH (already passable from
## the _fill_h calls during path construction). Identity is on the SpawnPoint, not the cell.

const _COLS : int = 30
const _ROWS : int = 17

const _BASE_POS    := Vector2i(15, 8)
const _SPAWN_W_POS := Vector2i(0,  8)
const _SPAWN_N_POS := Vector2i(15, 0)
const _SPAWN_S_POS := Vector2i(15, 16)
const _SPAWN_E_POS := Vector2i(29, 8)

## Phase 6: initial safe-zone reveal radius around the FOB. Chebyshev (square) distance.
## Per core/17 §8 the FOB has 3 resource nodes reachable; a radius of 3 covers that ring.
const _SAFE_ZONE_RADIUS : int = 3

## Phase 7: stub depot position (top-left ground area, well outside the safe zone).
## Used as the far endpoint of the default map's one ancient PathEdge.
const _STUB_DEPOT_POS : Vector2i = Vector2i(4, 1)

## Returns a fully initialised MapData matching the hardcoded default layout.
static func create() -> MapData:
	var data := MapData.new()
	data.map_id            = &"default"
	data.dimensions        = Vector2i(_COLS, _ROWS)
	data.biome             = &"temperate"
	data.topology_template = &"default_30x17"
	data.init_arrays()
	_build_paths(data)
	_build_default_spawn_points(data)
	_build_default_objectives(data)
	_build_default_support_graph(data)
	_reveal_safe_zone(data)
	return data

## Phase 7 stub: populates the SupportGraph with a FOB node, a stub depot, and one
## ancient PathEdge connecting them. Auto-flags ANCIENT_PATH_CROSSING zones at any
## cell along the edge that overlaps an enemy PATH cell.
##
## Edge geometry: from depot at (4, 1) east along row 1 (all GROUND) to col 15,
## then south down col 15 to the FOB. The col-15 leg crosses the north enemy
## corridor at rows 1/2/3 — three crossings, perfect for verification.
static func _build_default_support_graph(data: MapData) -> void:
	var graph := SupportGraph.new()
	graph.fob_node_id = &"fob"

	## Root: FOB.
	var fob_node := BuildingNode.new()
	fob_node.id            = &"fob"
	fob_node.position      = _BASE_POS
	fob_node.building_type = &"fob"
	fob_node.current_hp    = 300
	fob_node.connected_to_fob = true
	graph.nodes[fob_node.id] = fob_node

	## Stub depot — represents "the kind of support building the player would erect
	## in the top-left ground area". Phase 8 will populate these from real building
	## placement; for now it's hand-authored so the discovery mechanic has something
	## to discover.
	var depot_node := BuildingNode.new()
	depot_node.id            = &"depot_nw"
	depot_node.position      = _STUB_DEPOT_POS
	depot_node.building_type = &"depot_stub"
	depot_node.current_hp    = 100
	depot_node.connected_to_fob = false
	graph.nodes[depot_node.id] = depot_node

	## Ancient path: L-shape from depot east along row 1, then south down col 15.
	var edge := PathEdge.new()
	edge.id           = &"ancient_nw_to_fob"
	edge.from_node_id = depot_node.id
	edge.to_node_id   = fob_node.id
	edge.kind         = PathEdge.PathEdgeKind.ANCIENT
	edge.discovered   = false
	edge.health       = 1.0
	var cells : Array[Vector2i] = []
	for col in range(_STUB_DEPOT_POS.x, _BASE_POS.x + 1):     ## east leg: row 1
		cells.append(Vector2i(col, _STUB_DEPOT_POS.y))
	for row in range(_STUB_DEPOT_POS.y + 1, _BASE_POS.y + 1): ## south leg: col 15
		cells.append(Vector2i(_BASE_POS.x, row))
	edge.cells = cells
	graph.edges.append(edge)

	data.support_graph = graph

	## Auto-detect crossings: any edge cell that's a PATH in cell_types gets an
	## ANCIENT_PATH_CROSSING zone. These zones are immutable at runtime per §2.6.
	_build_ancient_path_crossings(data, edge)

## Adds an ANCIENT_PATH_CROSSING ZoneRegion for every cell on the given edge that
## already holds an enemy PATH. Each crossing is its own single-cell rect-zone with
## a unique id so the reverse index treats them as distinct lookups.
static func _build_ancient_path_crossings(data: MapData, edge: PathEdge) -> void:
	var crossing_index : int = 0
	for cell in edge.cells:
		if cell.x < 0 or cell.x >= _COLS or cell.y < 0 or cell.y >= _ROWS:
			continue
		if data.cell_types[cell.x + cell.y * _COLS] != _PATH:
			continue
		var zone := ZoneRegion.new()
		zone.id        = StringName("crossing_%s_%d" % [str(edge.id), crossing_index])
		zone.kind      = ZoneRegion.ZoneKind.ANCIENT_PATH_CROSSING
		zone.use_rect  = true
		zone.shape_rect = Rect2i(cell.x, cell.y, 1, 1)
		zone.modifier  = 1.0
		data.zones.append(zone)
		crossing_index += 1

## Marks the safe zone around the FOB as initially-revealed.
## Everything else starts hidden by the fog-of-war.
static func _reveal_safe_zone(data: MapData) -> void:
	for dy in range(-_SAFE_ZONE_RADIUS, _SAFE_ZONE_RADIUS + 1):
		for dx in range(-_SAFE_ZONE_RADIUS, _SAFE_ZONE_RADIUS + 1):
			var col : int = _BASE_POS.x + dx
			var row : int = _BASE_POS.y + dy
			if col < 0 or col >= _COLS or row < 0 or row >= _ROWS:
				continue
			data.set_meta_revealed(col + row * _COLS, true)

## Ports every fill and stamp call from MapGrid._build_default_paths() into MapData.cell_types.
## Keep this function a 1-for-1 mirror of that function — if one changes, the other must too.
static func _build_paths(data: MapData) -> void:
	## West path: two-branch network between junction (4,8) and exit (13,8).
	_fill_h(data, 8,   0,  4,  _PATH)   ## entry: row 8 spawn to junction
	_fill_v(data, 4,   4,  12, _PATH)   ## junction vertical: col 4 rows 4-12
	_fill_h(data, 4,   4,  9,  _PATH)   ## branch A north: row 4 east
	_fill_v(data, 9,   4,  8,  _PATH)   ## branch A: col 9 south to exit row
	_fill_h(data, 8,   9,  13, _PATH)   ## branch A exit: row 8 east to (13,8)
	_fill_h(data, 12,  4,  13, _PATH)   ## branch B south: row 12 east
	_fill_v(data, 13,  8,  12, _PATH)   ## branch B: col 13 north to (13,8)
	_fill_h(data, 8,  13,  15, _PATH)   ## final approach: (13,8) to base

	## North path: jog from SPAWN_N down to row 8, merges into west branch A exit.
	_fill_v(data, 15,  0,  3,  _PATH)
	_fill_h(data, 3,  11,  15, _PATH)
	_fill_v(data, 11,  3,  8,  _PATH)
	_fill_h(data, 8,  11,  13, _PATH)   ## overlaps west branch A exit (same cells)

	## East path: two-branch mirror of west between junction (25,8) and exit (16,8).
	_fill_h(data, 8,  25,  29, _PATH)   ## entry: row 8 spawn to junction
	_fill_v(data, 25,  4,  12, _PATH)   ## junction vertical: col 25 rows 4-12
	_fill_h(data, 4,  20,  25, _PATH)   ## branch A north (mirror): row 4 west
	_fill_v(data, 20,  4,  8,  _PATH)   ## branch A: col 20 south to exit row
	_fill_h(data, 8,  16,  20, _PATH)   ## branch A exit: row 8 west to (16,8)
	_fill_h(data, 12, 16,  25, _PATH)   ## branch B south (mirror): row 12 west
	_fill_v(data, 16,  8,  12, _PATH)   ## branch B: col 16 north to (16,8)
	_fill_h(data, 8,  15,  16, _PATH)   ## east final approach to base

	## South path: jog from SPAWN_S up to row 8, merges into east exit corridor.
	_fill_v(data, 15, 13,  16, _PATH)
	_fill_h(data, 13, 15,  19, _PATH)
	_fill_v(data, 19,  8,  13, _PATH)
	_fill_h(data, 8,  15,  19, _PATH)

	## Stamp the base marker last. Spawn positions remain PATH cells (already filled
	## by _fill_h above); spawn identity lives on SpawnPoint resources, populated
	## by _build_default_spawn_points().
	_set_raw(data, _BASE_POS.x, _BASE_POS.y, _BASE)

## Creates the four cardinal SpawnPoint resources for the default map.
## West is the previously-active spawn — ALWAYS_ON / ACTIVE from wave 1.
## N/S/E are DORMANT with activation_trigger = ON_REVEAL (Phase 6 fog-of-war will
## drive activation). Until then, Commander proximity acts as a Phase 4 stub for
## the future reveal mechanic.
static func _build_default_spawn_points(data: MapData) -> void:
	var west := SpawnPoint.new()
	west.id                 = &"spawn_w"
	west.position           = _SPAWN_W_POS
	west.axis               = SpawnPoint.SpawnAxis.PRIMARY
	west.activation_trigger = SpawnPoint.ActivationTrigger.ALWAYS_ON
	west.state              = SpawnPoint.SpawnState.ACTIVE
	data.spawn_points.append(west)

	var dormant_entries : Array = [
		{ "id": &"spawn_n", "pos": _SPAWN_N_POS },
		{ "id": &"spawn_s", "pos": _SPAWN_S_POS },
		{ "id": &"spawn_e", "pos": _SPAWN_E_POS },
	]
	for entry in dormant_entries:
		var sp := SpawnPoint.new()
		sp.id                 = entry["id"]
		sp.position           = entry["pos"]
		sp.axis               = SpawnPoint.SpawnAxis.PRIMARY
		sp.activation_trigger = SpawnPoint.ActivationTrigger.ON_REVEAL
		sp.state              = SpawnPoint.SpawnState.DORMANT
		data.spawn_points.append(sp)

## Phase 5 stub: every (faction, sub_path) combination gets one "claim 10 cells"
## objective that seals spawn_s. This is enough to validate the lifecycle pipeline.
## Phase 9+ will replace with real, kind-differentiated objective sets per faction.
static func _build_default_objectives(data: MapData) -> void:
	var combos : Array = [
		"architects:standard", "architects:spiritual_tech",
		"bloom:purist",        "bloom:assimilator",
		"mesh:networked",      "mesh:dreamer",
	]
	for combo in combos:
		var obj := ObjectiveData.new()
		obj.objective_id = &"claim_territory_basic"
		obj.description  = "Claim 10 cells of territory."
		## HOLD_CONTROL_POINT is the closest existing kind; new "CLAIM_TERRITORY"
		## kind would require a schema bump (per ObjectiveKind canonical enum).
		obj.kind         = ObjectiveData.ObjectiveKind.HOLD_CONTROL_POINT
		obj.target       = 10
		obj.progress     = 0
		obj.seals        = [&"spawn_s"] as Array[StringName]
		var list : Array[ObjectiveData] = [obj]
		data.objectives_by_faction_subpath[combo] = list

static func _set_raw(data: MapData, col: int, row: int, ctype: int) -> void:
	if col >= 0 and col < _COLS and row >= 0 and row < _ROWS:
		data.cell_types[col + row * _COLS] = ctype

static func _fill_h(data: MapData, row: int, col_a: int, col_b: int, ctype: int) -> void:
	var lo : int = min(col_a, col_b)
	var hi : int = max(col_a, col_b)
	for col in range(lo, hi + 1):
		_set_raw(data, col, row, ctype)

static func _fill_v(data: MapData, col: int, row_a: int, row_b: int, ctype: int) -> void:
	var lo : int = min(row_a, row_b)
	var hi : int = max(row_a, row_b)
	for row in range(lo, hi + 1):
		_set_raw(data, col, row, ctype)
