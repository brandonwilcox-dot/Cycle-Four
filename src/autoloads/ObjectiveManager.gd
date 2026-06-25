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

## Cells the player must claim to win a territory with no authored objectives.
const TERRITORY_CLAIM_TARGET : int = 200

var _map_data            : MapData               = null
var _active_objectives   : Array[ObjectiveData]  = []
var _map_already_done    : bool                  = false   ## true after map_completed fires; locks all seals

func _ready() -> void:
	EventBus.territory_claimed.connect(_on_territory_claimed)
	EventBus.territory_raided.connect(_on_territory_raided)
	EventBus.enemy_base_destroyed.connect(_on_enemy_base_destroyed)
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
	if _active_objectives.is_empty():
		_active_objectives = [_make_bases_objective()]
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

## [Persistence] On Continue/return, set the DESTROY_BASES objective progress to the number of bases
## already destroyed (Battle restores the sealed spawns; this restores the matching progress) so the
## win still completes when the remaining bases fall. Does not fire completion — a fully-conquered
## territory is already owned, and the objective was resolved against the full spawn count at map load.
func restore_bases_progress(n: int) -> void:
	for obj in _active_objectives:
		if obj != null and obj.kind == ObjectiveData.ObjectiveKind.DESTROY_BASES:
			obj.progress = clampi(n, 0, obj.target)
			EventBus.objective_progressed.emit(obj.objective_id, 0, obj.progress)

## -- Event handlers --

func _on_territory_claimed(_cell: Vector2i) -> void:
	if _map_data == null:
		return
	## Only CLAIM_TERRITORY objectives advance on a claim (authored maps may use them).
	## The default procgen win condition is now DESTROY_BASES — see _on_enemy_base_destroyed.
	for obj in _active_objectives:
		if obj != null and obj.kind == ObjectiveData.ObjectiveKind.CLAIM_TERRITORY:
			_apply_progress_delta(obj, 1)

## Conquest: each destroyed enemy base advances the DESTROY_BASES objective. When the last
## base falls, progress hits target → map_completed (handled in _apply_progress_delta) → capture.
func _on_enemy_base_destroyed(_spawn_id: StringName) -> void:
	if _map_data == null:
		return
	for obj in _active_objectives:
		if obj != null and obj.kind == ObjectiveData.ObjectiveKind.DESTROY_BASES:
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

## Builds the default conquest objective for procgen maps that have no authored objectives:
## destroy the enemy base anchoring each active spawn. Target = active-spawn count (one base
## each, placed by Battle). Faction-voiced; progress is driven by enemy_base_destroyed events.
func _make_bases_objective() -> ObjectiveData:
	var obj := ObjectiveData.new()
	obj.objective_id = &"destroy_bases"
	obj.kind         = ObjectiveData.ObjectiveKind.DESTROY_BASES
	var n : int = 0
	if _map_data != null:
		n = _map_data.get_active_spawn_points().size()
	obj.target = maxi(1, n)
	match FactionManager.active_faction:
		"architects":
			obj.description = "Dismantle the enemy strongholds anchoring each spawn (%d)." % obj.target
		"bloom":
			obj.description = "Overrun the enemy strongholds anchoring each spawn (%d)." % obj.target
		"mesh":
			obj.description = "Sever the enemy strongholds anchoring each spawn (%d)." % obj.target
		_:
			obj.description = "Destroy the enemy strongholds anchoring each spawn (%d)." % obj.target
	return obj

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
