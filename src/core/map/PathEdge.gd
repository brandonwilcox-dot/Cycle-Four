## PathEdge.gd
## A directed edge in the SupportGraph connecting two BuildingNodes via a cell-coordinate path.
class_name PathEdge
extends Resource

enum PathEdgeKind {
	ANCIENT,      ## Pre-placed at map generation. Starts undiscovered (discovered = false).
	PLAYER_BUILT, ## Placed by the player at runtime. Always starts discovered.
}

## Health below this threshold marks the edge invalid (unroutable by convoys).
const HEALTH_THRESHOLD: float = 0.25

@export var id: StringName = &""
@export var from_node_id: StringName = &""
@export var to_node_id: StringName = &""
@export var kind: PathEdgeKind = PathEdgeKind.ANCIENT

## False for ANCIENT edges until the commander's vision radius reveals any cell on this path.
## PLAYER_BUILT edges are always true. Convoys cannot route on undiscovered edges.
## Set by the SupportGraph on path_discovered events (§2.8 of the map architecture handoff).
@export var discovered: bool = false

## Ordered list of cell coordinates this path travels through.
@export var cells: Array[Vector2i] = []

## Current intactness in [0.0, 1.0]. Below HEALTH_THRESHOLD the edge is invalid.
@export var health: float = 1.0
