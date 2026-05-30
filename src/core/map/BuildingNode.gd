## BuildingNode.gd
## A node in the SupportGraph representing one support or research building.
class_name BuildingNode
extends Resource

@export var id: StringName = &""
@export var position: Vector2i = Vector2i.ZERO
@export var building_type: StringName = &""
@export var current_hp: int = 0

## Derived from SupportGraph BFS — do not set directly.
## Updated by the SupportGraph connectivity maintainer on graph-change events.
var connected_to_fob: bool = false
