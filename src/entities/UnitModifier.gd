## UnitModifier.gd
## U0 (units-land-plan) — one modifier a unit can carry in a modifier slot.
## First-class Resource so heretic modifiers are authored as .tres files, never one-offs.
## Ref: docs/codex/Units_Land.md §4 — sub-paths gate which modifiers a slot may hold;
## the heretic paths (spiritual_tech / assimilator / dreamer) each unlock ONE borrowed
## mechanic (terrain-bond / wreckage-absorb / dream-stabilize). Behavior lands in U4;
## this file is the schema every phase shares.
@tool
extends Resource
class_name UnitModifier

## Scripted-behavior kinds. STAT modifiers are pure dial changes; the three named kinds
## are the heretic mechanics and get their behavior in U4 (Unit/FriendlyUnit read `kind`).
## Ordinals are saved into .tres files — append, never reorder.
enum Kind { STAT, TERRAIN_BOND, WRECKAGE_ABSORB, DREAM_STABILIZE }

@export var id: String = ""                  ## stable identifier ("terrain_bond", "vet_armor"...)
@export var display_name: String = ""        ## player-facing name (one legible idea per unit)
@export var kind: Kind = Kind.STAT

## Sub-paths that may equip this modifier. Empty = any sub-path (orthodox stat mods).
## Heretic modifiers list exactly their heresy: ["spiritual_tech"] / ["assimilator"] / ["dreamer"].
## Ids must match FactionManager.SUB_PATHS.
@export var eligible_sub_paths: Array[String] = []

## Stat dials (applied multiplicatively / additively by consumers; 1.0 / 0.0 = no change).
@export var health_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var armor_bonus: float = 0.0         ## flat, stacks with UnitData.armor
@export var cost_mult: float = 1.0           ## production/upkeep dial (dream-stabilize < 1.0)

## Kind-specific tuning (meaning depends on `kind`; documented per authored .tres):
##   TERRAIN_BOND     — radius (px) within which favored terrain grants the stat dials
##   WRECKAGE_ABSORB  — radius (px) to consume a husk
##   DREAM_STABILIZE  — unused (the dials carry it)
@export var effect_radius: float = 0.0

func is_eligible(sub_path: String) -> bool:
	return eligible_sub_paths.is_empty() or sub_path in eligible_sub_paths
