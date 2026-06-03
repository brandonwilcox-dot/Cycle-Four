## ObjectiveManager.gd
## Phase 5 — the objective evaluator.
## Owns the active objective list for the current run, listens for world events,
## tracks per-objective progress, fires lifecycle signals, and applies the spawn
## sealing rules from the map architecture handoff §4.3 / §6.
##
## Sealing rules (handoff §4.3):
##   Pre-completion: SEALED is conditional. Completing an objective seals the
##   referenced spawns (ACTIVE → SEALED, DORMANT → SEALED). Lapsing the objective
##   reverses the seal (SEALED → ACTIVE).
##   Post map_completed: every SEALED spawn becomes PERMANENTLY_SEALED. Future
##   lapses cannot reopen it.
extends Node

var _map_data            : MapData               = null
var _active_objectives   : Array[ObjectiveData]  = []
var _map_already_done    : bool                  = false   ## true after map_completed fires; locks all seals

func _ready() -> void:
	EventBus.territory_claimed.connect(_on_territory_claimed)
	EventBus.territory_raided.connect(_on_territory_raided)
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.region_revealed.connect(_on_region_revealed)
	EventBus.region_sensed.connect(_on_region_sensed)

## -- Public API --

## Binds the manager to a freshly-loaded MapData. Resolves the objective list if
## FactionManager already has a selection; otherwise defers until faction_selected fires.
## Call after MapGrid.load_map_data(). Idempotent: safe to call again after a map switch.
func set_map(map_data: MapData) -> void:
	_map_data = map_data
	_map_already_done = false
	_resolve_for_current_faction()

## -- Internal: resolution --

## Triggered both by set_map() and by EventBus.faction_selected. Whichever event
## happens second is the one that finalises the active objective list.
func _resolve_for_current_faction() -> void:
	if _map_data == null:
		return
	if FactionManager.active_faction == "":
		return   ## No faction yet — wait for faction_selected
	_active_objectives = _map_data.get_objectives_for(
		FactionManager.active_faction,
		FactionManager.active_sub_path,
	)
	_map_data.resolve_spawn_seal_refs(_active_objectives)

func _on_faction_selected(_faction_id: String, _sub_path: String) -> void:
	_resolve_for_current_faction()

## Phase 6: fog reveal → spawn activation.
## Phase 7: fog reveal → ancient path discovery (any reveal-overlap-with-edge-cells).
## When a region is revealed, any DORMANT spawn with activation_trigger == ON_REVEAL
## whose position falls inside the revealed cells transitions to ACTIVE. Any undiscovered
## ancient PathEdge that shares one or more cells with the revealed region transitions
## to discovered=true.
## Note: this scope mixes objective-driven, reveal-driven, and discovery state — future
## refactor may split out a dedicated SpawnManager and a PathDiscoveryManager, but for
## now keeping it here means all map-state mutation lives in one auditable file.
func _on_region_revealed(cells: Array[Vector2i]) -> void:
	if _map_data == null or cells.is_empty():
		return
	## Build a Dictionary set for O(1) membership lookups against the revealed cells.
	var revealed_set : Dictionary = {}
	for c in cells:
		revealed_set[c] = true

	## Spawn activation pass.
	for sp in _map_data.spawn_points:
		if sp == null:
			continue
		if sp.state != SpawnPoint.SpawnState.DORMANT:
			continue
		if sp.activation_trigger != SpawnPoint.ActivationTrigger.ON_REVEAL:
			continue
		if not revealed_set.has(sp.position):
			continue
		if _map_data.activate_spawn_by_id(sp.id):
			EventBus.spawn_activated.emit(sp.id)

	## Ancient path discovery pass.
	for edge in _map_data.get_undiscovered_ancient_edges():
		for cell in edge.cells:
			if revealed_set.has(cell):
				edge.discovered = true
				EventBus.path_discovered.emit(edge.id)
				break   ## one match per edge is enough; move on

## Sensor ring: mark objectives sensed when the Commander's sensor ring covers a spawn
## that is conditionally sealed by those objectives. Shows "DETECTED" in the panel.
func _on_region_sensed(cells: Array[Vector2i]) -> void:
	if _map_data == null or cells.is_empty():
		return
	var sensed_set : Dictionary = {}
	for c in cells:
		sensed_set[c] = true
	for sp in _map_data.spawn_points:
		if sp == null or not sensed_set.has(sp.position):
			continue
		for ref_id in sp.seal_condition_refs:
			var obj : ObjectiveData = _find_objective(ref_id)
			if obj == null or obj.sensed:
				continue
			obj.sensed = true
			EventBus.objective_sensed.emit(obj.objective_id)

func get_active_objectives() -> Array[ObjectiveData]:
	return _active_objectives

## -- Event handlers --

func _on_territory_claimed(_cell: Vector2i) -> void:
	if _map_data == null:
		return
	## For Phase 5 stub: every objective increments by 1 per claim.
	## Phase 5+ refinements will key on objective.kind / tracked_refs.
	for obj in _active_objectives:
		if obj == null:
			continue
		_apply_progress_delta(obj, 1)

func _on_territory_raided(_cell: Vector2i) -> void:
	if _map_data == null:
		return
	## Stub lapse path: each raid decrements progress. Used to verify the
	## SEALED→ACTIVE reversal in the Phase 5 validation chain.
	for obj in _active_objectives:
		if obj == null:
			continue
		_apply_progress_delta(obj, -1)

## -- Progress + lifecycle --

## Applies a progress delta to one objective and fires the appropriate lifecycle
## signals. Centralised so completion and lapse semantics live in one place.
func _apply_progress_delta(obj: ObjectiveData, delta: int) -> void:
	var was_complete : bool = obj.progress >= obj.target
	var old_progress : int  = obj.progress
	obj.progress = clampi(obj.progress + delta, 0, obj.target * 2)
	if obj.progress == old_progress:
		return
	EventBus.objective_progressed.emit(obj.objective_id, old_progress, obj.progress)
	var is_complete : bool = obj.progress >= obj.target
	if not was_complete and is_complete:
		EventBus.objective_completed.emit(obj.objective_id)
		_apply_sealing_for(obj)
		_maybe_emit_map_completed()
	elif was_complete and not is_complete:
		EventBus.objective_lapsed.emit(obj.objective_id)
		_apply_unsealing_for(obj)

## On objective completion: every spawn that lists this objective as a seal
## condition transitions to SEALED, provided ALL of its seal_condition_refs are
## currently complete. Skips PERMANENTLY_SEALED spawns.
func _apply_sealing_for(completed_obj: ObjectiveData) -> void:
	if _map_data == null:
		return
	for spawn_id in completed_obj.seals:
		var sp : SpawnPoint = _map_data.get_spawn_by_id(spawn_id)
		if sp == null or sp.state == SpawnPoint.SpawnState.PERMANENTLY_SEALED:
			continue
		if _all_seal_refs_complete(sp):
			sp.state = SpawnPoint.SpawnState.SEALED

## On objective lapse: every spawn that lists this objective as a seal condition
## reverts from SEALED to ACTIVE (because the conditional seal is no longer met).
## PERMANENTLY_SEALED spawns are not affected.
func _apply_unsealing_for(lapsed_obj: ObjectiveData) -> void:
	if _map_data == null:
		return
	for spawn_id in lapsed_obj.seals:
		var sp : SpawnPoint = _map_data.get_spawn_by_id(spawn_id)
		if sp == null:
			continue
		if sp.state == SpawnPoint.SpawnState.SEALED:
			sp.state = SpawnPoint.SpawnState.ACTIVE

## Returns true if every objective referenced by the spawn's seal_condition_refs is
## currently complete. Empty seal_condition_refs means "never seals" (a Forever spawn).
func _all_seal_refs_complete(sp: SpawnPoint) -> bool:
	if sp.seal_condition_refs.is_empty():
		return false   ## Forever spawn — explicitly never seals
	for ref_id in sp.seal_condition_refs:
		var obj : ObjectiveData = _find_objective(ref_id)
		if obj == null or not obj.complete:
			return false
	return true

func _find_objective(id: StringName) -> ObjectiveData:
	for obj in _active_objectives:
		if obj != null and obj.objective_id == id:
			return obj
	return null

## Fires map_completed once all active objectives are complete, then promotes every
## SEALED spawn to PERMANENTLY_SEALED. Idempotent — subsequent calls are no-ops once
## the map has been completed once.
func _maybe_emit_map_completed() -> void:
	if _map_already_done or _map_data == null:
		return
	for obj in _active_objectives:
		if obj == null or not obj.complete:
			return
	_map_already_done = true
	EventBus.map_completed.emit()
	for sp in _map_data.spawn_points:
		if sp != null and sp.state == SpawnPoint.SpawnState.SEALED:
			sp.state = SpawnPoint.SpawnState.PERMANENTLY_SEALED
