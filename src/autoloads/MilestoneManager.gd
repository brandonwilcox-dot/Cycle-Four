## MilestoneManager.gd
## Tracks per-faction first-milestone conditions and fires milestone_reached(faction, 0).
## Idempotent — fires exactly once per run; resets on faction_selected.
##
## Real conditions (core/16 Chapter 6, core/21):
##   Architects — 5 research stages purchased (costs: 50/100/200/400/800 schematics)
##                Triggered via the Research button in ActionBar.
##   Bloom      — CLAIMED cells >= 60% of total (GROUND + CLAIMED) cells on the map.
##   Mesh       — 5 or more non-FOB SupportGraph nodes with connected_to_fob = true
##                simultaneously (i.e. 5 active depot routes at once).
extends Node

## Architect research stage costs (schematics).
const RESEARCH_COSTS : Array[float] = [50.0, 100.0, 200.0, 400.0, 800.0]
const RESEARCH_STAGES : int = 5

## Bloom coverage threshold (fraction of all ground-type cells).
const BLOOM_COVERAGE_THRESHOLD : float = 0.60

## Mesh: number of simultaneously connected depots required.
const MESH_DEPOT_TARGET : int = 5

## Second Milestone (unlocks the faction Ultimate / slot R). v1 proxy: reaching this
## wave after the first milestone has fired. The core/21 designs (Singularity II /
## Biosphere II / Mesh Control II) replace this with faction-specific conditions;
## the wave gate keeps the Ultimate reachable in the meantime.
const SECOND_MILESTONE_WAVE : int = 20

## -- Runtime state --
var _milestone_fired    : bool   = false
var _milestone2_fired   : bool   = false
var _active_faction     : String = ""

## Architect-specific
var _research_stage    : int    = 0   ## stages completed (0–5)

## Shared progress for HUD (meaningful per-faction)
var _progress          : int    = 0
var _target            : int    = 1

## MapGrid reference — set when the map loads (via set_map_grid).
var _map_grid          : Node   = null

func _ready() -> void:
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.territory_claimed.connect(_on_territory_claimed)
	EventBus.territory_raided.connect(_on_territory_raided)
	EventBus.path_discovered.connect(_on_path_discovered)
	EventBus.research_stage_purchased.connect(_on_research_stage_purchased)
	EventBus.wave_started.connect(_on_wave_started)

## Called by MapGrid.load_map_data so MilestoneManager can query cell counts.
func set_map_grid(grid: Node) -> void:
	_map_grid = grid

## -- Public API --

## Returns true if the first milestone has already fired this run.
func is_milestone_fired() -> bool:
	return _milestone_fired

## Attempt to purchase the next Architect research stage.
## Returns true and deducts cost if affordable; returns false otherwise.
## Called by HUD's Research button (Architects only).
func try_purchase_research() -> bool:
	if _active_faction != "architects":
		return false
	if _research_stage >= RESEARCH_STAGES:
		return false
	var cost : float = RESEARCH_COSTS[_research_stage]
	var secondary : String = FactionManager.get_secondary_resource()
	if not EconomyManager.can_afford({secondary: cost}):
		EventBus.notification_pushed.emit(
			"Need %d %s for Research Stage %d." % [int(cost), secondary, _research_stage + 1],
			"warning"
		)
		return false
	EconomyManager.spend({secondary: cost})
	EventBus.research_stage_purchased.emit(_research_stage + 1, cost)
	return true

## -- Event handlers --

func _on_faction_selected(faction_id: String, _sub_path: String) -> void:
	_milestone_fired  = false
	_milestone2_fired = false
	_research_stage   = 0
	_active_faction   = faction_id
	_progress        = 0
	match faction_id:
		"architects": _target = RESEARCH_STAGES
		"bloom":      _target = 100   ## placeholder; updated to real % on first territory event
		"mesh":       _target = MESH_DEPOT_TARGET
		_:            _target = 1
	_emit_progress()

func _on_territory_claimed(_cell: Vector2i) -> void:
	if _active_faction == "bloom":
		_evaluate_bloom()

func _on_territory_raided(_cell: Vector2i) -> void:
	if _active_faction == "bloom":
		_emit_bloom_progress()   ## re-sync display; can't un-fire milestone

func _on_path_discovered(_edge_id: StringName) -> void:
	if _active_faction == "mesh":
		_evaluate_mesh()

## Second Milestone gate (unlocks the faction Ultimate). Fires once, only after the
## first milestone, when the player reaches SECOND_MILESTONE_WAVE.
func _on_wave_started(wave_number: int, _commander_data: Dictionary) -> void:
	if _milestone2_fired or not _milestone_fired:
		return
	if _active_faction.is_empty():
		return
	if wave_number >= SECOND_MILESTONE_WAVE:
		_milestone2_fired = true
		EventBus.milestone_reached.emit(_active_faction, 1)
		EventBus.notification_pushed.emit("Second milestone reached — Ultimate unlocked!", "positive")

func _on_research_stage_purchased(stage: int, _cost: float) -> void:
	if _active_faction != "architects":
		return
	_research_stage = stage
	_progress       = stage
	_emit_progress()
	if _research_stage >= RESEARCH_STAGES:
		_fire_milestone()

## -- Per-faction evaluation --

func _evaluate_bloom() -> void:
	if _milestone_fired:
		return
	_emit_bloom_progress()
	if _map_grid == null:
		return
	var total   : int   = _map_grid.count_ground_cells()
	var claimed : int   = _map_grid.count_claimed_cells()
	if total > 0 and float(claimed) / float(total) >= BLOOM_COVERAGE_THRESHOLD:
		_fire_milestone()

func _emit_bloom_progress() -> void:
	if _map_grid == null:
		return
	var total   : int   = _map_grid.count_ground_cells()
	var claimed : int   = _map_grid.count_claimed_cells()
	_progress = claimed
	_target   = total
	var pct   : int = int(float(claimed) / float(total) * 100.0) if total > 0 else 0
	var label : String = "Coverage: %d%% / 60%%" % pct
	EventBus.milestone_progress_changed.emit(_progress, _target, label)

func _evaluate_mesh() -> void:
	if _milestone_fired:
		return
	var connected : int = _count_connected_depots()
	_progress = connected
	_target   = MESH_DEPOT_TARGET
	var label : String = "Routes: %d/%d" % [connected, MESH_DEPOT_TARGET]
	EventBus.milestone_progress_changed.emit(_progress, _target, label)
	if connected >= MESH_DEPOT_TARGET:
		_fire_milestone()

func _count_connected_depots() -> int:
	if _map_grid == null or _map_grid.map_data == null:
		return 0
	var graph : SupportGraph = _map_grid.map_data.support_graph
	if graph == null:
		return 0
	var count : int = 0
	for id in graph.nodes:
		var node : BuildingNode = graph.nodes[id]
		if node == null:
			continue
		if node.id == graph.fob_node_id:
			continue
		if node.connected_to_fob:
			count += 1
	return count

## -- Shared helpers --

func _fire_milestone() -> void:
	if _milestone_fired:
		return
	_milestone_fired = true
	EventBus.milestone_reached.emit(_active_faction, 0)
	EventBus.notification_pushed.emit("First milestone reached!", "positive")

func _emit_progress() -> void:
	var label : String
	match _active_faction:
		"architects":
			label = "Research: %d/%d" % [_progress, _target]
		"bloom":
			label = "Coverage: 0%% / 60%%"   ## updated when territory changes
		"mesh":
			label = "Routes: %d/%d" % [_progress, _target]
		_:
			label = "%d/%d" % [_progress, _target]
	EventBus.milestone_progress_changed.emit(_progress, _target, label)
