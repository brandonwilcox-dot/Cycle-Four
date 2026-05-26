## Tower.gd
## A placed defense tower. Scans for the nearest unit in range each attack cycle
## and calls take_damage() on it. No projectiles -- instant hit for MVP.
## Visual is a colored square with a darker border and center pip.
extends Node2D

const TowerDataClass = preload("res://src/entities/TowerData.gd")

var data: Resource = null   ## TowerData instance
var _attack_timer: float = 0.0

## Called by Main before adding to scene tree
func setup(tower_data: Resource) -> void:
	data = tower_data

func _ready() -> void:
	add_to_group("towers")
	if data == null:
		push_error("Tower: no TowerData -- call setup() before adding to tree.")
		return
	_build_visual()

func _process(delta: float) -> void:
	if data == null:
		return
	_attack_timer += delta
	if _attack_timer >= 1.0 / data.attack_speed:
		_attack_timer = 0.0
		_try_attack()

## -- Combat --

func _try_attack() -> void:
	var nearest: Node = null
	var nearest_dist: float = data.range
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var dist: float = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	if nearest != null and nearest.has_method("take_damage"):
		nearest.take_damage(data.damage)

## -- Visual --

func _build_visual() -> void:
	var col: Color = data.color_hint
	## Darker border so towers read as distinct from units
	var border := ColorRect.new()
	border.size     = Vector2(52.0, 52.0)
	border.position = Vector2(-26.0, -26.0)
	border.color    = col.darkened(0.5)
	add_child(border)
	## Main body
	var body := ColorRect.new()
	body.size     = Vector2(48.0, 48.0)
	body.position = Vector2(-24.0, -24.0)
	body.color    = col
	add_child(body)
	## Center pip -- visual shorthand for "barrel"
	var pip := ColorRect.new()
	pip.size     = Vector2(14.0, 14.0)
	pip.position = Vector2(-7.0, -7.0)
	pip.color    = col.darkened(0.65)
	add_child(pip)
