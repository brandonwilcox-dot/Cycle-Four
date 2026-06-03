## AcademyScenario.gd — one Academy sorting scenario.
## Data-driven so scenarios are tunable without touching code.
class_name AcademyScenario
extends Resource

@export var id           : StringName = &""
@export var prompt       : String     = ""       ## unattributed line shown on entry
@export var duration     : float      = 75.0     ## seconds before auto-timeout
@export var timeout_vote : StringName = &"bloom" ## faction credited if player never acts

## Three response zones. Each zone is a Dictionary:
##   { "pos": Vector2, "label": String, "faction": StringName, "weight": float }
## pos  = offset from chamber center in world units
## label = faint hint text shown as the cadet approaches (not a menu button)
## weight = vote multiplier; v1 always 1.0
@export var zones : Array[Dictionary] = []
