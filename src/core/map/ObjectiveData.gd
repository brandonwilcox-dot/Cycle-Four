## ObjectiveData.gd
## A single map or system-level objective, keyed by faction and sub-path.
## Drives spawn sealing, map completion, and HUD state.
## ObjectiveData.seals is the authoritative side of the spawn-seal relationship.
class_name ObjectiveData
extends Resource

enum ObjectiveKind {
	SURVEY_RUINS,
	ESTABLISH_BIOMASS_COVERAGE,
	PLACE_RELAY_COVERAGE,
	ELIMINATE_SPAWN,
	HOLD_CONTROL_POINT,
	## Additional kinds require a schema bump — do not add ad-hoc variants.
}

@export var objective_id: StringName = &""
@export var description: String = ""
@export var kind: ObjectiveKind = ObjectiveKind.SURVEY_RUINS
@export var target: int = 1

## Runtime progress. Updated by the objective evaluator on tracked-state-changed events.
## Persisted in the MapData snapshot.
@export var progress: int = 0

## Derived: true when progress >= target. Read-only; not serialized.
var complete: bool:
	get:
		return progress >= target

## Spawn point ids that this objective's completion conditionally seals.
## THIS IS THE AUTHORITATIVE SIDE of the objective↔spawn relationship.
## SpawnPoint.seal_condition_refs is derived from this field at map load — never author
## seal_condition_refs directly; add spawn ids here instead.
@export var seals: Array[StringName] = []

## Set to true by ObjectiveManager when the Commander's sensor ring detects a spawn
## linked to this objective. Cleared on map reset. Not persisted.
var sensed: bool = false

## References to the map state this objective reads from (zone ids, spawn ids, cell sets).
## Populated at run start by the objective evaluator. Untyped — content varies by kind.
var tracked_refs: Array = []
