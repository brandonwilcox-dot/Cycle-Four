## SupportGraph.gd
## The logistics graph: support buildings as nodes, paths as edges.
## Two edge kinds: ANCIENT (pre-placed at generation, discovered by commander vision)
## and PLAYER_BUILT (placed at runtime, always discovered).
## Connectivity is maintained incrementally via BFS on graph-change events — never
## rescanned per frame. See §2.8 of the map architecture handoff.
class_name SupportGraph
extends Resource

@export var fob_node_id: StringName = &""

## Keyed by BuildingNode.id (StringName) -> BuildingNode.
## Not typed as Dictionary[StringName, BuildingNode] — GDScript 4 does not support
## typed dictionary declarations; enforce the type convention in code.
@export var nodes: Dictionary = {}

@export var edges: Array[PathEdge] = []
