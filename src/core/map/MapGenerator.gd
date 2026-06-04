## MapGenerator.gd
## Phase 10 — procedural MapData generator. Replaces the hand-authored
## DefaultMapBuilder for fresh runs while preserving the default's structural
## intent: a 60×34 grid, BASE in the centre, 2–4 cardinal-axis spawn points,
## 1 ancient PathEdge from a discovered depot to the FOB, stub objectives per
## (faction, sub_path), and an initial safe zone revealed around the FOB.
##
## Reroll-on-failure: every emitted MapData is run through _validate() and
## regenerated with a bumped seed if any check fails (every spawn must reach
## BASE via enemy-traversable cells; every BuildingNode must sit on GROUND).
##
## Phase 11+ (content): richer topology templates (single vs dual ruins, bridge
## maps, etc.), biome-driven cell modifiers, ruins/zone placement, generator
## inputs from SystemData. For now: one topology, one biome shape, random
## variations within those.
class_name MapGenerator
extends RefCounted

const _COLS : int = 60
const _ROWS : int = 34

## Local mirrors of MapGrid.Cell enum values.
const _GROUND   : int = 0
const _PATH     : int = 2
const _BASE     : int = 3

const _BASE_POS         : Vector2i = Vector2i(30, 17)
const _SAFE_ZONE_RADIUS : int      = 3
const _MAX_ATTEMPTS     : int      = 16

## The four cardinal axis termini. Procgen picks a subset of size 2..4.
const _CARDINAL_SPAWNS : Array = [
	{ "pos": Vector2i(0,  17), "id": &"spawn_w" },
	{ "pos": Vector2i(30, 0),  "id": &"spawn_n" },
	{ "pos": Vector2i(59, 17), "id": &"spawn_e" },
	{ "pos": Vector2i(30, 33), "id": &"spawn_s" },
]

## Entry point. seed = 0 picks a time-based seed. biome and topology_template are
## recorded on the resource; biome doesn't affect cell layout in Phase 10 (rendering
## differentiation is content work).
static func generate(seed_value: int = 0, biome: StringName = &"temperate",
		topology_template: StringName = &"cardinal_branching") -> MapData:
	var actual_seed : int = seed_value if seed_value != 0 else int(Time.get_ticks_msec())
	var rng := RandomNumberGenerator.new()

	for attempt in _MAX_ATTEMPTS:
		rng.seed = actual_seed + attempt
		var data : MapData = _try_generate(rng, biome, topology_template)
		if _validate(data):
			return data

	push_error("MapGenerator: validation failed after %d attempts. Falling back to default." % _MAX_ATTEMPTS)
	return DefaultMapBuilder.create()

## -- Single attempt --

static func _try_generate(rng: RandomNumberGenerator, biome: StringName,
		topology_template: StringName) -> MapData:
	var data := MapData.new()
	data.map_id            = StringName("procgen_%d" % rng.seed)
	data.dimensions        = Vector2i(_COLS, _ROWS)
	data.biome             = biome
	data.topology_template = topology_template
	data.init_arrays()

	## Pick 2–4 cardinal spawns this run.
	var picks : Array = _CARDINAL_SPAWNS.duplicate()
	picks.shuffle()
	var spawn_count : int = rng.randi_range(2, 4)
	var chosen : Array = picks.slice(0, spawn_count)

	## Draw a winding multi-segment path from each chosen spawn to the FOB. 1-3
	## intermediate waypoints per path produce twists and turns instead of a
	## single L-shape. Each segment uses a random L orientation.
	for entry in chosen:
		_carve_winding_path(data, rng, entry["pos"] as Vector2i, _BASE_POS)

	## Stamp BASE last so it overrides any PATH that ran through (15, 8).
	data.cell_types[_BASE_POS.x + _BASE_POS.y * _COLS] = _BASE

	## Build SpawnPoint resources. The first chosen spawn is the ALWAYS_ON primary;
	## the rest are DORMANT and reveal-activated, matching the DefaultMapBuilder pattern.
	_build_spawn_points(data, chosen)

	## SupportGraph: FOB root + one randomly-placed depot, ancient PathEdge between them.
	_build_support_graph(data, rng)

	## Stub objective per (faction, sub_path), sealing the first non-primary spawn.
	_build_objectives(data, chosen)

	## Initial safe zone reveal around the FOB.
	_reveal_safe_zone(data)

	return data

## Carves a winding path made of 2-4 L-shape segments. Generates 1-3 intermediate
## waypoints between `from` and `to` (offset perpendicular to the spawn-base axis
## so the route bends meaningfully rather than running in a straight line), then
## connects each consecutive pair with a randomly-oriented L. End-to-end reachability
## is guaranteed because every segment is a 4-connected L.
static func _carve_winding_path(data: MapData, rng: RandomNumberGenerator,
		from: Vector2i, to: Vector2i) -> void:
	var waypoint_count : int = rng.randi_range(1, 3)
	var points : Array[Vector2i] = [from]
	for i in waypoint_count:
		var t       : float = float(i + 1) / float(waypoint_count + 1)
		var base_x  : float = lerpf(float(from.x), float(to.x), t)
		var base_y  : float = lerpf(float(from.y), float(to.y), t)
		## Perpendicular offset keeps the bend visually distinct from a straight line.
		## Offsets scaled for 60×34 (roughly 2× the old 30×17 values).
		var off_x   : int = rng.randi_range(-10, 10)
		var off_y   : int = rng.randi_range(-6, 6)
		var wp_x    : int = clampi(int(base_x) + off_x, 1, _COLS - 2)
		var wp_y    : int = clampi(int(base_y) + off_y, 1, _ROWS - 2)
		points.append(Vector2i(wp_x, wp_y))
	points.append(to)
	for i in points.size() - 1:
		_carve_l_segment(data, rng, points[i], points[i + 1])

## Single L-shape between two points. Used as the segment primitive of winding paths.
static func _carve_l_segment(data: MapData, rng: RandomNumberGenerator,
		from: Vector2i, to: Vector2i) -> void:
	var horizontal_first : bool = rng.randf() < 0.5
	if horizontal_first:
		_fill_h(data, from.y, from.x, to.x)
		_fill_v(data, to.x,   from.y, to.y)
	else:
		_fill_v(data, from.x, from.y, to.y)
		_fill_h(data, to.y,   from.x, to.x)

static func _build_spawn_points(data: MapData, chosen: Array) -> void:
	for i in chosen.size():
		var entry : Dictionary = chosen[i]
		var sp := SpawnPoint.new()
		sp.id        = entry["id"]
		sp.position  = entry["pos"]
		sp.axis      = SpawnPoint.SpawnAxis.PRIMARY
		if i == 0:
			sp.activation_trigger = SpawnPoint.ActivationTrigger.ALWAYS_ON
			sp.state              = SpawnPoint.SpawnState.ACTIVE
		else:
			sp.activation_trigger = SpawnPoint.ActivationTrigger.ON_REVEAL
			sp.state              = SpawnPoint.SpawnState.DORMANT
		data.spawn_points.append(sp)

static func _build_support_graph(data: MapData, rng: RandomNumberGenerator) -> void:
	var graph := SupportGraph.new()
	graph.fob_node_id = &"fob"

	var fob_node := BuildingNode.new()
	fob_node.id                = &"fob"
	fob_node.position          = _BASE_POS
	fob_node.building_type     = &"fob"
	fob_node.current_hp        = 300
	fob_node.connected_to_fob  = true
	graph.nodes[fob_node.id] = fob_node

	## Place a depot on any random GROUND cell — reroll until we get a valid spot.
	var depot_pos : Vector2i = _find_random_ground(data, rng)
	if depot_pos == Vector2i(-1, -1):
		data.support_graph = graph
		return   ## no room for a depot; map still valid, just no convoy loop

	var depot_node := BuildingNode.new()
	depot_node.id                = &"depot_procgen"
	depot_node.position          = depot_pos
	depot_node.building_type     = &"depot_stub"
	depot_node.current_hp        = 100
	depot_node.connected_to_fob  = false
	graph.nodes[depot_node.id] = depot_node

	var edge := PathEdge.new()
	edge.id           = &"ancient_procgen"
	edge.from_node_id = depot_node.id
	edge.to_node_id   = fob_node.id
	edge.kind         = PathEdge.PathEdgeKind.ANCIENT
	edge.discovered   = false
	edge.health       = 1.0
	edge.cells        = _carve_ancient_cells(rng, depot_pos, _BASE_POS)
	graph.edges.append(edge)

	data.support_graph = graph

	## Auto-detect ANCIENT_PATH_CROSSING zones at intersection cells.
	_build_ancient_crossings(data, edge)

static func _carve_ancient_cells(rng: RandomNumberGenerator,
		from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	var horizontal_first : bool = rng.randf() < 0.5
	if horizontal_first:
		for col in range(min(from.x, to.x), max(from.x, to.x) + 1):
			cells.append(Vector2i(col, from.y))
		var step : int = signi(to.y - from.y)
		var y : int = from.y
		while y != to.y:
			y += step
			cells.append(Vector2i(to.x, y))
	else:
		for row in range(min(from.y, to.y), max(from.y, to.y) + 1):
			cells.append(Vector2i(from.x, row))
		var step : int = signi(to.x - from.x)
		var x : int = from.x
		while x != to.x:
			x += step
			cells.append(Vector2i(x, to.y))
	return cells

static func _build_ancient_crossings(data: MapData, edge: PathEdge) -> void:
	var idx : int = 0
	for cell in edge.cells:
		if cell.x < 0 or cell.x >= _COLS or cell.y < 0 or cell.y >= _ROWS:
			continue
		if data.cell_types[cell.x + cell.y * _COLS] != _PATH:
			continue
		var zone := ZoneRegion.new()
		zone.id         = StringName("procgen_crossing_%d" % idx)
		zone.kind       = ZoneRegion.ZoneKind.ANCIENT_PATH_CROSSING
		zone.use_rect   = true
		zone.shape_rect = Rect2i(cell.x, cell.y, 1, 1)
		zone.modifier   = 1.0
		data.zones.append(zone)
		idx += 1

static func _build_objectives(data: MapData, chosen: Array) -> void:
	## Pick a non-primary spawn as the seal target. If only one spawn exists, the
	## stub objective seals the primary itself (gameplay-edge but architecturally fine).
	var seal_target : StringName = chosen[0]["id"] if chosen.size() == 1 else chosen[1]["id"]
	var combos : Array = [
		"architects:standard", "architects:spiritual_tech",
		"bloom:purist",        "bloom:assimilator",
		"mesh:networked",      "mesh:dreamer",
	]
	for combo in combos:
		var obj := ObjectiveData.new()
		obj.objective_id = &"claim_territory_basic"
		obj.description  = "Claim 10 cells of territory."
		obj.kind         = ObjectiveData.ObjectiveKind.HOLD_CONTROL_POINT
		obj.target       = 10
		obj.progress     = 0
		obj.seals        = [seal_target] as Array[StringName]
		var list : Array[ObjectiveData] = [obj]
		data.objectives_by_faction_subpath[combo] = list

static func _reveal_safe_zone(data: MapData) -> void:
	for dy in range(-_SAFE_ZONE_RADIUS, _SAFE_ZONE_RADIUS + 1):
		for dx in range(-_SAFE_ZONE_RADIUS, _SAFE_ZONE_RADIUS + 1):
			var col : int = _BASE_POS.x + dx
			var row : int = _BASE_POS.y + dy
			if col < 0 or col >= _COLS or row < 0 or row >= _ROWS:
				continue
			data.set_meta_revealed(col + row * _COLS, true)

## -- Validation --

## Reachability + structural checks. Returns true if the map is playable.
static func _validate(data: MapData) -> bool:
	if data.spawn_points.is_empty():
		return false

	## BASE must be present and be the BASE type.
	if data.cell_types[_BASE_POS.x + _BASE_POS.y * _COLS] != _BASE:
		return false

	## Every spawn cell must be PATH (enemies traverse it).
	for sp in data.spawn_points:
		if sp == null:
			continue
		var sp_ct : int = data.cell_types[sp.position.x + sp.position.y * _COLS]
		if sp_ct != _PATH:
			return false

	## Every spawn must reach BASE via enemy-traversable cells (PATH + BASE).
	for sp in data.spawn_points:
		if sp == null:
			continue
		if not _is_reachable(data, sp.position, _BASE_POS):
			return false

	## Every non-FOB BuildingNode must sit on GROUND (depots can't be on enemy paths).
	if data.support_graph != null:
		for id in data.support_graph.nodes:
			var node : BuildingNode = data.support_graph.nodes[id]
			if node == null or node.id == data.support_graph.fob_node_id:
				continue
			var ct : int = data.cell_types[node.position.x + node.position.y * _COLS]
			if ct != _GROUND:
				return false

	return true

static func _is_reachable(data: MapData, from: Vector2i, to: Vector2i) -> bool:
	var visited : Dictionary = { from: true }
	var queue   : Array      = [from]
	while not queue.is_empty():
		var cur : Vector2i = queue.pop_front()
		if cur == to:
			return true
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb : Vector2i = cur + off
			if nb.x < 0 or nb.x >= _COLS or nb.y < 0 or nb.y >= _ROWS:
				continue
			if visited.has(nb):
				continue
			var ct : int = data.cell_types[nb.x + nb.y * _COLS]
			if ct != _PATH and ct != _BASE:
				continue
			visited[nb] = true
			queue.append(nb)
	return false

## -- Helpers --

## Returns a random GROUND cell at least 4 cells from BASE, or (-1,-1) if no
## ground cells exist (which shouldn't happen on a valid map).
static func _find_random_ground(data: MapData, rng: RandomNumberGenerator) -> Vector2i:
	var candidates : Array[Vector2i] = []
	for row in _ROWS:
		for col in _COLS:
			if data.cell_types[col + row * _COLS] != _GROUND:
				continue
			var d : int = abs(col - _BASE_POS.x) + abs(row - _BASE_POS.y)
			if d < 4:
				continue   ## too close to FOB
			candidates.append(Vector2i(col, row))
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[rng.randi_range(0, candidates.size() - 1)]

static func _fill_h(data: MapData, row: int, col_a: int, col_b: int) -> void:
	var lo : int = min(col_a, col_b)
	var hi : int = max(col_a, col_b)
	for col in range(lo, hi + 1):
		if col < 0 or col >= _COLS or row < 0 or row >= _ROWS:
			continue
		data.cell_types[col + row * _COLS] = _PATH

static func _fill_v(data: MapData, col: int, row_a: int, row_b: int) -> void:
	var lo : int = min(row_a, row_b)
	var hi : int = max(row_a, row_b)
	for row in range(lo, hi + 1):
		if col < 0 or col >= _COLS or row < 0 or row >= _ROWS:
			continue
		data.cell_types[col + row * _COLS] = _PATH
