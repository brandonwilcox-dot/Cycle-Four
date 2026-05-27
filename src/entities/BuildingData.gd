## BuildingData.gd
## Resource definition for a production building.
## Buildings are placed on CLAIMED territory by the player.
## One .tres file per faction variant.
@tool
extends Resource
class_name BuildingData

## Display
@export var building_name : String = "Building"
@export var faction_id    : String = ""

## Economy
@export var income_rate   : float  = 0.5    ## primary resource per second added to territory_rates
@export var primary_cost  : float  = 30.0   ## cost in faction primary resource to place

## Visual
@export var color_hint    : Color  = Color.WHITE
