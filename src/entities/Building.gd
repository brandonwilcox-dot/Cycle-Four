## Building.gd
## A production building placed on CLAIMED territory by the player.
## Contributes a passive income rate to EconomyManager when alive.
## Destroyed by flanker raids (Main listens to territory_raided and calls destroy()).
##
## Visual identity: 40×40 square body with a cross/plus overlay.
## Distinct from towers (square + pips) and units (small square + health bar).
extends Node2D

var data : Resource = null   ## BuildingData instance
var _income_active : bool = false

## Called by Main before adding to the scene tree.
func setup(building_data: Resource) -> void:
	data = building_data

func _ready() -> void:
	add_to_group("buildings")
	if data == null:
		push_error("Building: no BuildingData -- call setup() before adding to tree.")
		return
	## Start contributing income as soon as the building enters the tree.
	_income_active = true
	EconomyManager.add_territory_rate(
		FactionManager.get_primary_resource(),
		float(data.get("income_rate"))
	)
	_build_visual()

## Called by Main._on_territory_raided() when a flanker destroys the cell.
## Removes the income contribution then frees the node.
func destroy() -> void:
	if _income_active:
		_income_active = false
		EconomyManager.add_territory_rate(
			FactionManager.get_primary_resource(),
			-float(data.get("income_rate"))
		)
	queue_free()

## -- Visual --

func _build_visual() -> void:
	var col : Color = data.get("color_hint") if data.get("color_hint") else Color.WHITE

	## Outer border (44×44)
	var border := ColorRect.new()
	border.size     = Vector2(44.0, 44.0)
	border.position = Vector2(-22.0, -22.0)
	border.color    = col.darkened(0.45)
	add_child(border)

	## Main body (40×40)
	var body := ColorRect.new()
	body.size     = Vector2(40.0, 40.0)
	body.position = Vector2(-20.0, -20.0)
	body.color    = col
	add_child(body)

	## Cross / plus symbol -- distinguishes buildings from towers and units.
	## Horizontal bar
	var h_bar := ColorRect.new()
	h_bar.size     = Vector2(26.0, 7.0)
	h_bar.position = Vector2(-13.0, -3.5)
	h_bar.color    = col.darkened(0.55)
	add_child(h_bar)

	## Vertical bar
	var v_bar := ColorRect.new()
	v_bar.size     = Vector2(7.0, 26.0)
	v_bar.position = Vector2(-3.5, -13.0)
	v_bar.color    = col.darkened(0.55)
	add_child(v_bar)
