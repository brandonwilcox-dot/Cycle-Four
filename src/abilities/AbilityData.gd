## AbilityData.gd
## Data resource defining one Commander ability slot.
## Mechanics are faction-neutral. display_name and color are the per-faction
## presentation layer — set by FactionManager lookup in a later track.
class_name AbilityData
extends Resource

## Targeting constants — int rather than enum to avoid preload type-mismatch warnings
## when AbilityController accesses them via a preloaded script reference.
const TARGETING_NONE   : int = 0   ## self or instant; cast fires immediately on key press
const TARGETING_GROUND : int = 1   ## player left-clicks a world position after key press

@export var id           : StringName = &""
@export var display_name : String     = ""
@export var key_action   : StringName = &""   ## InputMap action name
@export var cooldown     : float      = 6.0   ## seconds
@export var targeting    : int        = 0     ## use TARGETING_* constants
@export var color        : Color      = Color(1.0, 0.9, 0.3, 1.0)

## Mechanic parameters — keys vary by ability:
##   lance:      damage (float)
##   field:      slow_mult (float), duration (float), radius_px (float)
##   overdrive:  interval_mult (float), damage_mult (float), duration (float)
@export var params : Dictionary = {}
