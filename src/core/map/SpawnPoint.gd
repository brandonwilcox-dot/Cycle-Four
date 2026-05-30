## SpawnPoint.gd
## An enemy spawn location. Replaces the legacy SPAWN_W/N/S/E cell-type approach.
## Multiple spawns may exist per direction; geography, climate, and structures determine
## which are active on any given map.
class_name SpawnPoint
extends Resource

enum SpawnAxis {
	PRIMARY,
	SECONDARY,
	TERTIARY,
}

enum ActivationTrigger {
	ALWAYS_ON,             ## Active from wave 1 (used for the starting primary-axis spawn).
	ON_REVEAL,             ## Activates when commander reveals this cell or nearby vicinity.
	ON_BUILD_THRESHOLD,    ## Activates when the player economy crosses a configured value.
	ON_OBJECTIVE_PROGRESS, ## Activates in response to an objective milestone.
	ON_TIMER,              ## Fallback: activates after a fixed elapsed time.
}

enum SpawnState {
	DORMANT,
	ACTIVE,
	## Conditional seal: all referenced objectives currently complete. Can revert to ACTIVE
	## if any objective lapses (e.g. a captured control point is retaken). This state is
	## valid until map_completed fires.
	SEALED,
	## Terminal seal: set by map_completed broadcast (§6.3 of the map architecture handoff).
	## Cannot be reversed by objective lapse. One-way transition only.
	PERMANENTLY_SEALED,
}

@export var id: StringName = &""
@export var position: Vector2i = Vector2i.ZERO
@export var axis: SpawnAxis = SpawnAxis.PRIMARY
@export var activation_trigger: ActivationTrigger = ActivationTrigger.ON_REVEAL

## DERIVED — do not set directly. Computed by the spawn manager from objective state.
## SEALED is conditional; PERMANENTLY_SEALED is terminal (set by map_completed signal).
## See §2.5 and §4.3 of the map architecture handoff.
var state: SpawnState = SpawnState.DORMANT

## DERIVED — do not author directly. Populated at map load by scanning ObjectiveData.seals
## for any objective whose seals array contains this spawn's id.
## ObjectiveData.seals is the authoritative side of this relationship.
var seal_condition_refs: Array[StringName] = []
