## ZoneRegion.gd
## An authored strategic region on a map. Immutable at runtime after generation.
## Stored as Array[ZoneRegion] on MapData.zones; queried via the cell→zone reverse index.
class_name ZoneRegion
extends Resource

enum ZoneKind {
	MINERAL_VEIN,
	HAZARD,
	LEY_CLUSTER,
	CONTROL_POINT,
	TERTIARY_INCURSION,
	BIOMASS_PROHIBITED,    ## Sterile terrain — Bloom cannot convert these cells.
	RELAY_REQUIRED,        ## Mesh Cold-Sink zones; relay coverage required for production.
	ANCIENT_PATH_CROSSING, ## Cell(s) where an ancient convoy route and an enemy traversal
	                       ## path overlap or are immediately adjacent. Placed at map
	                       ## generation. Natural chokepoints — holding one protects both
	                       ## the convoy line and the enemy advance corridor simultaneously.
}

## Flag bits for ZoneRegion.flags.
const FLAG_FACTION_BONUS_ARCHITECTS : int = 1 << 0
const FLAG_FACTION_BONUS_BLOOM      : int = 1 << 1
const FLAG_FACTION_BONUS_MESH       : int = 1 << 2
const FLAG_BUILD_PERMITTED          : int = 1 << 3
## +50% construction cost on tertiary incursion points (core/23 §2 / core/17 Q5).
const FLAG_CONSTRUCTION_COST_MOD    : int = 1 << 4
const FLAG_COMMANDER_CLAIM_COST_MOD : int = 1 << 5

@export var id: StringName = &""
@export var kind: ZoneKind = ZoneKind.MINERAL_VEIN

## Use shape_rect for axis-aligned rectangular zones (preferred).
## Set use_rect = false and populate shape_cells for irregular polygonal zones.
@export var use_rect: bool = true
@export var shape_rect: Rect2i = Rect2i()
@export var shape_cells: Array[Vector2i] = []

## Generic numeric modifier; meaning depends on kind.
## Examples: income multiplier for MINERAL_VEIN, damage-per-wave for HAZARD.
@export var modifier: float = 1.0

## Bitfield of FLAG_* constants above.
@export var flags: int = 0

## For LEY_CLUSTER zones: the Ruins site this zone clusters near.
## Ley node density is proportional to the linked Ruins' importance (core/17 §8).
@export var linked_ruins_id: StringName = &""
