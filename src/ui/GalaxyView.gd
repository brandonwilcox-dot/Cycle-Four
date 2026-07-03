## GalaxyView.gd
## Phase D — the galaxy graph, recentred so the ACTIVE node sits at the board centre ("you are here"
## = the tactical board). Lives in the same world space but spans far larger radii, so zooming the
## Camera3D out shrinks the board to the home node and reveals the rings — continuous tactical→
## galactic zoom, no separate screen.
##
## 3D MIGRATION (Stage 5): now `extends Node3D`. The graph renders as 3D meshes (system spheres +
## edge bars + active/frontier rings) floating just above the plane, rebuilt on change. Visible only
## while the camera rig reports is_galaxy_zoom(). queue_redraw() is repurposed as a dirty-flag so
## Battle's deploy/capture refresh calls keep working.
extends Node3D

const NODE_RADIUS : float = 150.0
const NODE_Y      : float = 120.0     ## float the graph above the plane so it reads when zoomed out
const EDGE_WIDTH  : float = 18.0

const WORLD3D = preload("res://src/core/World3D.gd")

var board_center : Vector2 = Vector2(1920.0, 1088.0)   ## world centre of the tactical board
var _dirty       : bool    = true
var _rig         : Node    = null

func setup(center: Vector2) -> void:
	board_center = center
	_dirty = true

## Repurposed: marks the graph for rebuild (Node3D has no CanvasItem redraw).
func queue_redraw() -> void:
	_dirty = true

## Only render while the camera rig is zoomed into galaxy range; rebuild meshes when shown/dirty.
func _process(_delta: float) -> void:
	if _rig == null or not is_instance_valid(_rig):
		_rig = get_tree().get_first_node_in_group("camera_rig")
	var want : bool = _rig != null and _rig.has_method("is_galaxy_zoom") and bool(_rig.call("is_galaxy_zoom"))
	if want != visible:
		visible = want
	if want and _dirty:
		_rebuild()

## World position (plane) of a node: board centre + its offset from the active ("home") node.
func world_of(id: String) -> Vector2:
	return board_center + (GalaxyManager.node_pos(id) - GalaxyManager.node_pos(GalaxyManager.active_node))

## Rebuilds the 3D graph (spheres + edges + rings). Cheap — a few dozen nodes.
func _rebuild() -> void:
	_dirty = false
	for c in get_children():
		c.queue_free()
	if GalaxyManager.star_systems.is_empty():
		return
	var faction  : String = FactionManager.active_faction
	var frontier : Array  = GalaxyManager.frontier(faction)

	## Adjacency bars (once per undirected edge).
	var drawn : Dictionary = {}
	for id in GalaxyManager.star_systems:
		var a : Vector3 = WORLD3D.to3(world_of(id), NODE_Y)
		for nb in GalaxyManager.star_systems[id].get("adj", []):
			var key : String = (id + "|" + nb) if id < nb else (nb + "|" + id)
			if drawn.has(key):
				continue
			drawn[key] = true
			_add_edge(a, WORLD3D.to3(world_of(nb), NODE_Y))

	## System spheres, colored by owner; rings for active + capturable frontier.
	## V5.1: the CORE renders as an absence — light-absorbing, wrong (codex/04) — while
	## every other system glows and blooms under the V1 environment.
	for id in GalaxyManager.star_systems:
		var p : Vector3 = WORLD3D.to3(world_of(id), NODE_Y)
		var owner_id : String = str(GalaxyManager.star_systems[id].get("owner", "neutral"))
		if owner_id == "core":
			_add_core(p)
		else:
			_add_node(p, _owner_color(owner_id, faction), 1.2 if owner_id != "neutral" else 0.45)
		if id == GalaxyManager.active_node:
			_add_ring(p, Color(1, 1, 1, 0.95))
		elif id in frontier:
			_add_ring(p, Color(1.0, 0.85, 0.2, 0.95))

func _add_node(p: Vector3, col: Color, energy: float = 0.6) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = NODE_RADIUS
	sp.height = NODE_RADIUS * 2.0
	mi.mesh = sp
	mi.position = p
	mi.material_override = _emissive(col, energy)
	add_child(mi)

## The Neutral Core: a sphere DARKER than the space around it — it absorbs light rather than
## catching it — larger than any system, circled by one thin deep-amber ring (the only hint).
func _add_core(p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = NODE_RADIUS * 1.6
	sp.height = NODE_RADIUS * 3.2
	mi.mesh = sp
	mi.position = p
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.012, 0.014, 0.02)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	mi.material_override = m
	add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = NODE_RADIUS * 1.6 + 20.0
	tm.outer_radius = NODE_RADIUS * 1.6 + 30.0
	ring.mesh = tm
	ring.position = p
	ring.material_override = _emissive(Color(0.55, 0.38, 0.10), 0.7)
	add_child(ring)

func _add_ring(p: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = NODE_RADIUS + 24.0
	tm.outer_radius = NODE_RADIUS + 40.0
	mi.mesh = tm
	mi.position = p
	mi.material_override = _emissive(col, 1.0)
	add_child(mi)

func _add_edge(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	var edge_len : float = a.distance_to(b)
	bx.size = Vector3(EDGE_WIDTH, EDGE_WIDTH, edge_len)
	mi.mesh = bx
	mi.position = (a + b) * 0.5
	if edge_len > 0.01:
		mi.look_at(b, Vector3.UP)
	mi.material_override = _emissive(Color(0.30, 0.36, 0.52), 0.18)   ## V5.1: dim lanes, bright systems
	add_child(mi)

func _emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _owner_color(owner_id: String, faction: String) -> Color:
	if owner_id == "core":
		return Color(0.95, 0.80, 0.25)        ## the galactic core (uncapturable)
	if owner_id == faction:
		return Color(0.30, 0.85, 0.50)        ## yours
	if owner_id == "neutral":
		return Color(0.45, 0.45, 0.52)        ## unclaimed
	return Color(0.85, 0.30, 0.25)            ## a rival faction's

## Nearest node to a world (plane) point within a generous pick radius, or "" if none.
func node_at(world: Vector2) -> String:
	var best   : String = ""
	var best_d : float  = NODE_RADIUS * 1.8
	for id in GalaxyManager.star_systems:
		var d : float = world.distance_to(world_of(id))
		if d <= best_d:
			best_d = d
			best   = id
	return best
