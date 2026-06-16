## UnitData.gd
## Resource definition for a single unit type.
## One .tres file per unit. Loaded by wave tables at spawn time.
## Ref: core/17_units-maps-buildings.md for stat philosophy.
@tool
extends Resource
class_name UnitData

## Display
@export var unit_name: String = ""
@export var faction_id: String = ""         ## "architects" | "bloom" | "mesh"
@export var tier: int = 1                   ## Production tier 1-6

## Combat stats
@export var max_health: float = 100.0
@export var move_speed: float = 80.0        ## pixels per second along path
@export var damage_on_arrival: float = 10.0 ## damage dealt to base when unit reaches end
@export var armor: float = 0.0              ## flat damage reduction (applied after type multiplier)

## Pass 2 combat identity. armor_type feeds the damage triangle (Combat.gd):
## Plated=Architect, Organic=Bloom, Synthetic=Mesh. Ordinal must match Combat.ArmorType.
@export_enum("Plated", "Organic", "Synthetic") var armor_type: int = 0
## Stealth units render and can be targeted only inside a sensor sphere (sensed cells).
@export var stealth: bool = false

## Economy
@export var resource_reward: float = 5.0   ## primary resource dropped on death
@export var spawn_cost: Dictionary = {}     ## cost to produce (unit production layer)
@export var cooldown: float = 8.0          ## seconds between spawns (active layer)

## Visual hint (texture assigned in editor; placeholder until art exists)
@export var color_hint: Color = Color.WHITE ## faction color shown on placeholder rect

## Bloom-specific: evolve on damage
@export var evolve_threshold: float = 0.0  ## 0 = no evolution; >0 = HP% that triggers adapt
@export var evolved_unit: UnitData = null  ## unit type to replace this one after evolving

## Mesh-specific: hacks nearby buildings on death
@export var hacks_on_death: bool = false
@export var hack_radius: float = 0.0

## Ability system: units flagged true ignore stun and slow from ability effects.
## Set on heavy/lore-immune chassis (Mire-Beast, Bio-Titan, etc.).
@export var status_immune: bool = false
