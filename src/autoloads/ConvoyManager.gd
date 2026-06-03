## ConvoyManager.gd
## Phase 8 — owns convoy lifecycle, connectivity maintenance, and the spawn tick.
##
## Responsibilities (Phase 8 scope):
##   - On EventBus.path_discovered → re-derive SupportGraph node connectivity via BFS
##     from each non-FOB node through DISCOVERED edges toward the FOB. Sets
##     BuildingNode.connected_to_fob.
##   - When a depot transitions to connected_to_fob=true for the first time, spawn
##     ONE persistent Convoy that ferries back and forth between depot and FOB
##     (per the IP design: discovered resources move cargo to/from the FOB on a
##     continuous loop, not a steady spawn stream).
##   - Track aggregate cargo delivered for debug visibility.
##
## Phase 8b (deferred): flanker damage to convoys, path-cut detection, map-failure
## threshold UX, real economy hookup. For Phase 8 stub, convoy arrivals print and
## emit signals only.
extends Node

## Preload the Convoy script directly rather than relying on class_name resolution.
## Autoloads can parse before global class_name registrations land, so referencing
## `Convoy` as a type from this file fails with a parser error. preload sidesteps it.
const ConvoyScript = preload("res://src/entities/Convoy.gd")

const DEFAULT_CARGO_AMOUNT : float = 1.0

var _map_data        : MapData = null
var _map_grid        : Node    = null   ## for cell_to_world conversion
var _convoy_counter  : int     = 0      ## monotonic id source for spawned convoys
var _total_delivered : float   = 0.0
## Set of depot ids that already have a persistent convoy ferrying. Prevents
## duplicate spawning when path_discovered fires again (e.g. multi-edge maps).
var _spawned_for_depot : Dictionary = {}

func _ready() -> void:
	EventBus.path_discovered.connect(_on_path_discovered)
	EventBus.convoy_arrived.connect(_on_convoy_arrived)
	EventBus.region_revealed.connect(_on_region_revealed)

## -- Public API --

## Binds the manager to a freshly-loaded MapData. Called by MapGrid.load_map_data
## right after ObjectiveManager.set_map(). Resets per-map state.
func set_map(map_data: MapData, map_grid: Node) -> void:
	_map_data        = map_data
	_map_grid        = map_grid
	_convoy_counter  = 0
	_total_delivered = 0.0
	_spawned_for_depot.clear()
	_recompute_connectivity()
	_spawn_for_newly_connected()

## -- Internal: connectivity --

## Phase 8: bounded BFS from each non-FOB node, traversing only DISCOVERED edges.
## Cost is O(nodes * edges) which is trivial at current scale (≤ a dozen nodes).
## When the SupportGraph grows we can switch to incremental updates per §2.8.
func _recompute_connectivity() -> void:
	if _map_data == null or _map_data.support_graph == null:
		return
	var graph : SupportGraph = _map_data.support_graph
	for id in graph.nodes:
		var node : BuildingNode = graph.nodes[id]
		if node == null:
			continue
		if node.id == graph.fob_node_id:
			node.connected_to_fob = true
			continue
		var was_connected : bool = node.connected_to_fob
		node.connected_to_fob = _has_discovered_path(graph, node.id, graph.fob_node_id)
		if node.connected_to_fob and not was_connected:
			pass   ## hook point for HUD/notification systems (future)

## Returns true if there is a sequence of DISCOVERED edges connecting from_id to to_id.
func _has_discovered_path(graph: SupportGraph, from_id: StringName, to_id: StringName) -> bool:
	if from_id == to_id:
		return true
	var visited : Dictionary = { from_id: true }
	var queue   : Array = [from_id]
	while not queue.is_empty():
		var current : StringName = queue.pop_front()
		for edge in graph.edges:
			if edge == null or not edge.discovered:
				continue
			var next_id : StringName = &""
			if edge.from_node_id == current:
				next_id = edge.to_node_id
			elif edge.to_node_id == current:
				next_id = edge.from_node_id
			else:
				continue
			if visited.has(next_id):
				continue
			if next_id == to_id:
				return true
			visited[next_id] = true
			queue.append(next_id)
	return false

## -- Internal: spawn dispatch --

## For each connected non-FOB node that does NOT already have a persistent convoy
## assigned, spawn one. Each depot gets exactly one ferrying convoy for its lifetime.
func _spawn_for_newly_connected() -> void:
	if _map_data == null or _map_data.support_graph == null or _map_grid == null:
		return
	var graph : SupportGraph = _map_data.support_graph
	for id in graph.nodes:
		var node : BuildingNode = graph.nodes[id]
		if node == null or node.id == graph.fob_node_id:
			continue
		if not node.connected_to_fob:
			continue
		if _spawned_for_depot.get(node.id, false):
			continue   ## this depot already has its ferry
		## Guard: only spawn once the depot cell itself is revealed. path_discovered fires
		## when ANY edge cell enters the Commander's LoS — the far endpoint may still be
		## in fog. Re-check runs on every region_revealed so the convoy spawns the moment
		## the player walks close enough to see the depot.
		var depot_idx : int = node.position.x + node.position.y * _map_data.dimensions.x
		if not _map_data.get_meta_revealed(depot_idx):
			continue
		var edge : PathEdge = _find_discovered_edge_to_fob(graph, node.id)
		if edge == null:
			continue
		_spawn_convoy(node, edge)
		_spawned_for_depot[node.id] = true

func _find_discovered_edge_to_fob(graph: SupportGraph, from_node: StringName) -> PathEdge:
	for edge in graph.edges:
		if edge == null or not edge.discovered:
			continue
		if edge.from_node_id == from_node and edge.to_node_id == graph.fob_node_id:
			return edge
		if edge.to_node_id == from_node and edge.from_node_id == graph.fob_node_id:
			return edge
	return null

func _spawn_convoy(from_node: BuildingNode, edge: PathEdge) -> void:
	if _map_grid == null:
		return
	_convoy_counter += 1
	var convoy_id : StringName = StringName("convoy_%d" % _convoy_counter)

	## Build the world-coord route. If the edge runs from FOB → depot in spec but
	## we're shipping depot → FOB, reverse the cell list so the convoy starts at
	## the depot and ends at the FOB.
	var cells : Array[Vector2i] = edge.cells.duplicate()
	if cells.size() >= 2 and cells[0] != from_node.position:
		cells.reverse()
	var route_world : Array[Vector2] = []
	for c in cells:
		route_world.append(_map_grid.cell_to_world(c.x, c.y))

	## Untyped intentionally: ConvoyScript is a preloaded Script, so the parser
	## can't see Convoy's named members through a Node2D type annotation. Duck-typed
	## member access works fine at runtime since the instance carries the properties.
	var convoy = ConvoyScript.new()
	convoy.convoy_id    = convoy_id
	convoy.from_node_id = from_node.id
	convoy.to_node_id   = _map_data.support_graph.fob_node_id
	convoy.cargo_amount = DEFAULT_CARGO_AMOUNT
	convoy.route_world  = route_world
	## Parent the convoy to MapGrid (not to this autoload). MapGrid lives inside the
	## active WorldMap scene and owns the cell→world coordinate frame; rendering as
	## its child puts the convoy in the same canvas layer as everything else and
	## above MapGrid's own _draw output. Parenting to /root/ConvoyManager makes them
	## logically alive but visually invisible.
	_map_grid.add_child(convoy)
	EventBus.convoy_spawned.emit(convoy_id, from_node.id, convoy.to_node_id)

## -- Event handlers --

func _on_path_discovered(_edge_id: StringName) -> void:
	_recompute_connectivity()
	_spawn_for_newly_connected()

func _on_region_revealed(_cells: Array[Vector2i]) -> void:
	## Re-run spawn check each time new cells are revealed. A depot that was connected
	## but not yet revealed will now pass the revealed guard if its cell was just uncovered.
	_spawn_for_newly_connected()

func _on_convoy_arrived(_convoy_id: StringName, _to_node: StringName, cargo_amount: float) -> void:
	_total_delivered += cargo_amount   ## Phase 9 will route this into the EconomyManager
