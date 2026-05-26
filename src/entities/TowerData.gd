## TowerData.gd
## Resource definition for a single tower type.
## One .tres file per tower variant. Loaded by FactionManager at placement time.
## Ref: core/17_units-maps-buildings.md for stat philosophy.
@tool
extends Resource
class_name TowerData

## Display
@export var tower_name: String = "Tower"
@export var faction_id: String = ""    ## "architects" | "bloom" | "mesh"
@export var tier: int = 1

## Combat
@export var damage: float = 10.0       ## damage per attack
@export var range: float = 150.0       ## attack radius in pixels
@export var attack_speed: float = 1.0  ## attacks per second

## Economy
@export var primary_cost: float = 25.0 ## cost in faction primary resource

## Visual
@export var color_hint: Color = Color.WHITE
