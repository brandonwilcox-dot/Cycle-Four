## GalaxyView.gd
## Phase D — draws the galaxy graph in world space, recentred so the ACTIVE node sits at the
## board centre (i.e. "you are here" = the battle board). Because it lives in the same world
## space as the tactical board but spans far larger radii, zooming the camera out shrinks the
## board to the home node and reveals the rings of territories around it — continuous
## tactical→galactic zoom, no separate screen.
##
## Static unless ownership/active changes; Main calls queue_redraw() after deploy/capture.
extends Node2D

const NODE_RADIUS : float = 150.0
const EDGE_WIDTH  : float = 10.0

var board_center : Vector2 = Vector2(1920.0, 1088.0)   ## world centre of the tactical board

func setup(center: Vector2) -> void:
	board_center = center
	z_index = 50
	queue_redraw()

## Only render while the camera is zoomed out into galaxy range, so the graph never obscures
## the tactical board during normal play.
func _process(_delta: float) -> void:
	var cam : Camera2D = get_viewport().get_camera_2d()
	var want : bool = cam != null and cam.has_method("is_galaxy_zoom") and bool(cam.call("is_galaxy_zoom"))
	if want != visible:
		visible = want
		if want:
			queue_redraw()

## World position of a node: board centre + its offset from the active ("home") node, so the
## active node renders exactly where the board is.
func world_of(id: String) -> Vector2:
	return board_center + (GalaxyManager.node_pos(id) - GalaxyManager.node_pos(GalaxyManager.active_node))

func _draw() -> void:
	if GalaxyManager.star_systems.is_empty():
		return
	var faction  : String = FactionManager.active_faction
	var frontier : Array  = GalaxyManager.frontier(faction)

	## Adjacency lines (drawn once per undirected edge).
	var drawn : Dictionary = {}
	for id in GalaxyManager.star_systems:
		var a : Vector2 = world_of(id)
		for nb in GalaxyManager.star_systems[id].get("adj", []):
			var key : String = (id + "|" + nb) if id < nb else (nb + "|" + id)
			if drawn.has(key):
				continue
			drawn[key] = true
			draw_line(a, world_of(nb), Color(0.30, 0.36, 0.52, 0.55), EDGE_WIDTH)

	## Nodes, coloured by owner; rings for the active node and capturable frontier.
	for id in GalaxyManager.star_systems:
		var p : Vector2 = world_of(id)
		draw_circle(p, NODE_RADIUS, _owner_color(str(GalaxyManager.star_systems[id].get("owner", "neutral")), faction))
		if id == GalaxyManager.active_node:
			draw_arc(p, NODE_RADIUS + 30.0, 0.0, TAU, 48, Color(1, 1, 1, 0.95), 9.0)
		elif id in frontier:
			draw_arc(p, NODE_RADIUS + 30.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.2, 0.95), 9.0)

func _owner_color(owner_id: String, faction: String) -> Color:
	if owner_id == "core":
		return Color(0.95, 0.80, 0.25)        ## the galactic core (uncapturable)
	if owner_id == faction:
		return Color(0.30, 0.85, 0.50)        ## yours
	if owner_id == "neutral":
		return Color(0.45, 0.45, 0.52)        ## unclaimed
	return Color(0.85, 0.30, 0.25)            ## a rival faction's

## Nearest node to a world point within a generous pick radius, or "" if none.
func node_at(world: Vector2) -> String:
	var best   : String = ""
	var best_d : float  = NODE_RADIUS * 1.8
	for id in GalaxyManager.star_systems:
		var d : float = world.distance_to(world_of(id))
		if d <= best_d:
			best_d = d
			best   = id
	return best
