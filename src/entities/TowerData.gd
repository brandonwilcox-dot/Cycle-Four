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

## Pass 2 combat identity. damage_type feeds the damage triangle (Combat.gd):
## Kinetic=Architect, Energy=Mesh, Corrosive=Bloom. Ordinal must match Combat.DamageType.
@export_enum("Kinetic", "Energy", "Corrosive") var damage_type: int = 0

## Economy
@export var primary_cost: float = 25.0  ## cost in faction primary resource

## Upgrade chain
## upgrade_to == null means this is the max tier.
## Upgrade cost = upgrade_to.primary_cost (what the next tier costs to build fresh).
@export var upgrade_to: TowerData = null

## Visual
@export var color_hint: Color = Color.WHITE
