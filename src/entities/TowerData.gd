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
@warning_ignore("shadowed_global_identifier")
@export var range: float = 150.0       ## attack radius in pixels (name shadows range(); intentional)
@export var attack_speed: float = 1.0  ## attacks per second

## Pass 2 combat identity. damage_type feeds the damage triangle (Combat.gd):
## Kinetic=Architect, Energy=Mesh, Corrosive=Bloom. Ordinal must match Combat.DamageType.
@export_enum("Kinetic", "Energy", "Corrosive") var damage_type: int = 0

## Economy
@export var primary_cost: float = 25.0  ## cost in faction primary resource

## Upgrade chain (Pass 3 branching).
## upgrade_to == null means this is the max tier. When both upgrade_to and
## upgrade_to_b are set the player picks one specialization (branch A or B); the
## branches typically reconverge on a shared higher tier. Upgrade cost = the chosen
## branch's primary_cost (what that tower costs to build fresh).
@export var upgrade_to: TowerData = null
@export var upgrade_to_b: TowerData = null

## Pass 3 support/aura. A tower with aura_radius > 0 buffs the damage of friendly
## towers within aura_radius px by aura_damage_bonus (fraction, e.g. 0.15 = +15%).
## Max-level towers also gain a veteran aura even without these set (see Tower.gd).
@export var aura_radius: float = 0.0
@export var aura_damage_bonus: float = 0.0

## Detection counterplay. A tower with detector_radius > 0 reveals stealth units
## within this radius (px) while they are inside it — live, not permanent.
@export var detector_radius: float = 0.0

## Visual
@export var color_hint: Color = Color.WHITE
