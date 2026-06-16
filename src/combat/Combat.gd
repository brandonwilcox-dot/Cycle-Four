## Combat.gd — Pass 2 damage/armor type triangle ("Combat Identity").
## Static helpers + constants only; this script is never instanced. Consumers
## preload it (global class_name registration is unreliable at parse time in
## Godot 4.6 — see project notes), e.g.:
##     const Combat = preload("res://src/combat/Combat.gd")
##     unit.take_damage(dmg, Combat.faction_damage_type(faction))
##
## Faction-flavored rock-paper-scissors (confirmed design 2026-06-16):
##   Kinetic   → strong vs Organic (Bloom),    weak vs Synthetic (Mesh)
##   Energy    → strong vs Plated (Architect), weak vs Organic (Bloom)
##   Corrosive → strong vs Synthetic (Mesh),   weak vs Plated (Architect)
## Each faction's towers/commander/base/abilities deal its signature damage type;
## each faction's units wear its signature armor type.
extends RefCounted

## Enum ordinals MUST match the @export_enum order in TowerData/UnitData.
enum DamageType { KINETIC, ENERGY, CORROSIVE }
enum ArmorType  { PLATED, ORGANIC, SYNTHETIC }

const STRONG  : float = 1.5
const NEUTRAL : float = 1.0
const WEAK    : float = 0.66

## TABLE[damage_type][armor_type] -> multiplier.
## Rows: Kinetic / Energy / Corrosive. Columns: Plated / Organic / Synthetic.
const TABLE : Array = [
	[NEUTRAL, STRONG,  WEAK],     ## Kinetic
	[STRONG,  WEAK,    NEUTRAL],  ## Energy
	[WEAK,    NEUTRAL, STRONG],   ## Corrosive
]

## Faction → the damage type its offensive kit deals.
const FACTION_DAMAGE : Dictionary = {
	"architects": DamageType.KINETIC,
	"bloom":      DamageType.CORROSIVE,
	"mesh":       DamageType.ENERGY,
}

## Faction → the armor type its units wear (for reference / authoring checks).
const FACTION_ARMOR : Dictionary = {
	"architects": ArmorType.PLATED,
	"bloom":      ArmorType.ORGANIC,
	"mesh":       ArmorType.SYNTHETIC,
}

## Effectiveness multiplier of damage_type against armor_type. Out-of-range or
## untyped (-1) inputs return NEUTRAL so legacy/contact damage is unaffected.
static func multiplier(damage_type: int, armor_type: int) -> float:
	if damage_type < 0 or damage_type >= TABLE.size():
		return NEUTRAL
	var row : Array = TABLE[damage_type]
	if armor_type < 0 or armor_type >= row.size():
		return NEUTRAL
	return row[armor_type]

## Signature damage type for a faction id. Defaults to Kinetic for unknown ids.
static func faction_damage_type(faction_id: String) -> int:
	return int(FACTION_DAMAGE.get(faction_id, DamageType.KINETIC))

static func damage_type_name(damage_type: int) -> String:
	match damage_type:
		DamageType.KINETIC:   return "Kinetic"
		DamageType.ENERGY:    return "Energy"
		DamageType.CORROSIVE: return "Corrosive"
	return "—"

static func armor_type_name(armor_type: int) -> String:
	match armor_type:
		ArmorType.PLATED:    return "Plated"
		ArmorType.ORGANIC:   return "Organic"
		ArmorType.SYNTHETIC: return "Synthetic"
	return "—"
