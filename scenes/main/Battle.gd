## Battle.gd
## The gameplay screen controller (the unified Battle⇄Galaxy space). Owns the live
## board: tower/building placement + upgrades, the galaxy deploy/capture loop, and
## the first-run Academy director. Top-level screen swaps are owned by SceneManager.
extends Node

const TOWER_SCENE           : PackedScene = preload("res://scenes/main/Tower.tscn")
const BUILDING_SCENE        : PackedScene = preload("res://scenes/main/Building.tscn")
const ANCIENT_WATCHER_SCENE : PackedScene = preload("res://scenes/main/AncientWatcher.tscn")
const GALAXY_VIEW_SCRIPT    = preload("res://src/ui/GalaxyView.gd")
const MAP_GENERATOR_SCRIPT  = preload("res://src/core/map/MapGenerator.gd")
const GRID_SIZE             : int = 64
## World centre of the tactical board (COLS/2 × ROWS/2 cells) — the galaxy view recentres here.
const BOARD_CENTER          : Vector2 = Vector2(1920.0, 1088.0)
## Hit radii in SCREEN pixels (converted to world via camera zoom) so selection stays
## forgiving at any zoom — generous when zoomed out, precise when zoomed in.
const STRUCTURE_HIT_SCREEN_PX    : float = 30.0
## Generous so clicking near (not pixel-perfect on) the Commander still selects it.
## At default zoom this is ~140 world-units (~2.2 cells) — see the user feedback that
## the old 38px (~93 world) hit box felt too small to click reliably.
const COMMANDER_SELECT_SCREEN_PX : float = 58.0
const FOB_DOCTRINE_COST       : float = 80.0   ## primary-resource cost to set/switch an FOB doctrine

## Sight/sensor sphere every placed structure (tower, building) projects. Structures
## grant vision, not territory — only the Commander and FOB claim cells.
const STRUCTURE_SIGHT_RADIUS : int = 3
const STRUCTURE_SENSOR_EXTRA : int = 2

## Fraction of a structure's current-tier cost refunded when sold.
const SELL_REFUND_FRACTION : float = 0.5

const WASH_FADE_IN  : float = 0.4
const WASH_HOLD     : float = 0.3
const WASH_FADE_OUT : float = 0.4
const WASH_ALPHA    : float = 0.6

## Placement-preview ghost tints. Green = the hovered cell will accept the
## tower/building; red = it will be rejected.
const PREVIEW_VALID   : Color = Color(0.30, 0.95, 0.40, 0.28)
const PREVIEW_INVALID : Color = Color(0.95, 0.25, 0.20, 0.28)

@onready var academy   : Node2D    = $UILayer/Academy
@onready var hud              : Control   = $UILayer/HUD
@onready var tower_layer      : Node2D    = $WorldMap/TowerLayer
@onready var building_layer   : Node2D    = $WorldMap/BuildingLayer
@onready var _map_grid        : Node2D    = $WorldMap/MapGrid
@onready var _milestone_wash  : ColorRect = $WashLayer/MilestoneWash

## Tower placement state
var _placement_mode  : bool     = false
var _pending_tower   : Resource = null
## Vector2i -> Node2D (Tower); used for double-place guard and upgrade clicks.
var _occupied_cells  : Dictionary = {}

## Building placement state
var _build_mode       : bool     = false
var _pending_building : Resource = null
## Vector2i -> Node2D (Building); used for double-place guard and raid destruction.
var _building_cells   : Dictionary = {}

## Inspection state -- tracks which cell is currently open in the inspection panel.
var _inspected_cell   : Vector2i  = Vector2i(-1, -1)

## Placement-preview ghost (UX): a cell-sized highlight that follows the cursor
## while in tower/build mode so the player can see exactly where, and whether,
## the next placement will land. _preview_cell caches the last hovered cell so
## can_place_at() (which runs a pathfinding test on PATH cells) is only evaluated
## when the cursor crosses a cell boundary, not every frame.
var _placement_preview : ColorRect = null
var _preview_cell      : Vector2i  = Vector2i(-9999, -9999)

## Phase D: the galaxy graph overlay (zoom out to see it).
var _galaxy_view : Node2D = null

## True only during the Academy's live scenarios (chapter 1), where the player commands the real
## Commander (the chamber cadet is hidden). Lets _unhandled_input accept world clicks during scenarios.
var _academy_scenarios_active : bool = false

func _ready() -> void:
	add_to_group("main_controller")
	hud.hide()
	academy.selection_confirmed.connect(_on_faction_confirmed)
	EventBus.tower_placement_requested.connect(_on_placement_requested)
	EventBus.building_placement_requested.connect(_on_build_requested)
	EventBus.territory_raided.connect(_on_territory_raided)
	EventBus.panel_upgrade_requested.connect(_on_panel_upgrade_requested)
	EventBus.panel_sell_requested.connect(_on_panel_sell_requested)
	EventBus.fob_doctrine_requested.connect(_on_fob_doctrine_requested)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	EventBus.offline_catch_up.connect(_on_offline_catch_up)
	EventBus.game_saving.connect(_capture_territory_development)
	EventBus.academy_phase_started.connect(_on_academy_phase_started)
	EventBus.academy_phase_ended.connect(_on_academy_phase_ended)
	_build_placement_preview()
	if not GameState.current_faction.is_empty() and GameState.academy_completed:
		FactionManager.restore_faction(GameState.current_faction, GameState.current_sub_path)
		_start_game_world(true)

func _on_faction_confirmed() -> void:
	_start_game_world()

## The Academy's live scenarios begin (chapter 1): hand world control to the real Commander — pre-select
## it so right-click moves immediately — and let _unhandled_input accept world clicks for this phase.
func _on_academy_phase_started() -> void:
	_academy_scenarios_active = true
	var cmd : Node = _commander()
	if cmd != null:
		cmd.call("set_selected", true)

## Scenarios end (sorting begins): world clicks are gated again (chamber UI / sigil buttons).
func _on_academy_phase_ended() -> void:
	_academy_scenarios_active = false

func _start_game_world(is_restore: bool = false) -> void:
	## [Persistence Step 2] On a Continue/restore, the live map is MapGrid._ready's fresh RANDOM map.
	## Swap it for the saved active territory (regenerated from its persisted seed) and re-apply the
	## saved CLAIMED cells, so the player returns to the ground they held. Reuses the deploy load path.
	if is_restore and not GalaxyManager.active_node.is_empty() and GalaxyManager.star_systems.has(GalaxyManager.active_node):
		_load_territory_map(GalaxyManager.active_node)
		_restore_territory_development(GalaxyManager.star_systems[GalaxyManager.active_node].get("development", {}))
	## Fully retire the Academy: free the whole subtree so nothing leaks into the live
	## game. hide() on the Academy *Node2D* does NOT hide its CanvasLayer children
	## (TextLayer / SortingLayer with their Buttons) — those stay visible and keep
	## intercepting left-clicks over the map (a Button consumes left-clicks but lets
	## right-clicks fall through, which is exactly why move worked but select didn't).
	## The CadetAvatar's _unhandled_input goes away with it too. Freeing covers the
	## normal-completion, F1-skip, and save-restore entry paths.
	if is_instance_valid(academy):
		academy.hide()
		academy.process_mode = Node.PROCESS_MODE_DISABLED
		academy.queue_free()
	EventBus.academy_clear_units.emit()
	hud.show()
	## Pre-activate every spawn point so waves work immediately on first launch.
	## The Commander's exploration normally activates them; this ensures the first
	## session always has enemies regardless of where the player wandered during
	## the Academy scenarios.
	_activate_all_spawns()
	## Start with the Commander selected so the move controls are immediately usable.
	var cmd : Node = _commander()
	if cmd != null:
		cmd.call("set_selected", true)
	EventBus.notification_pushed.emit(
		"Commander selected — right-click to move it. Place towers, then Begin Waves.", "info"
	)
	## Phase D: ensure the galaxy graph exists and mount the zoom-out galaxy view. Capturing a
	## territory triggers on map_completed (all its objectives done).
	GalaxyManager.ensure_galaxy(FactionManager.active_faction)
	_build_galaxy_view()
	if not EventBus.map_completed.is_connected(_on_map_completed):
		EventBus.map_completed.connect(_on_map_completed)
	## Per-territory persistence (Step 1): on a FRESH start, pin the active (home) node's seed to the
	## map the player is actually on, so a later Continue regenerates THIS map. The initial map used a
	## random (time-based) seed at MapGrid._ready; capture it onto the node. On a restore we keep the
	## saved seed (the restore path reloads from it). See planning/persistence-design.md.
	if not is_restore and not GalaxyManager.active_node.is_empty():
		var md = _map_grid.get("map_data")
		if md != null and GalaxyManager.star_systems.has(GalaxyManager.active_node):
			GalaxyManager.star_systems[GalaxyManager.active_node]["seed"] = int(md.map_seed)
			SaveManager.mark_dirty()

## -- Phase D: galaxy view + campaign loop --

func _build_galaxy_view() -> void:
	if _galaxy_view != null and is_instance_valid(_galaxy_view):
		_galaxy_view.call("setup", BOARD_CENTER)
		return
	_galaxy_view = GALAXY_VIEW_SCRIPT.new()
	$WorldMap.add_child(_galaxy_view)
	_galaxy_view.call("setup", BOARD_CENTER)

## True while the camera is zoomed out into the galaxy (left-clicks pick territories, not units).
func _in_galaxy_zoom() -> bool:
	var cam : Node = get_node_or_null("WorldMap/Camera")
	return cam != null and cam.has_method("is_galaxy_zoom") and bool(cam.call("is_galaxy_zoom"))

## A left-click while zoomed out: deploy to a frontier territory under the cursor.
func _handle_galaxy_click(screen_pos: Vector2) -> void:
	if _galaxy_view == null:
		return
	var world : Vector2 = _screen_to_world(screen_pos)
	var id : String = str(_galaxy_view.call("node_at", world))
	if id.is_empty():
		return
	if GalaxyManager.is_frontier(id, FactionManager.active_faction):
		_deploy_to_node(id)
	elif GalaxyManager.star_systems.get(id, {}).get("owner") == FactionManager.active_faction \
			and id != GalaxyManager.active_node:
		_deploy_to_node(id)   ## return to a held territory
	else:
		EventBus.notification_pushed.emit("That territory isn't on your frontier.", "warning")

## Loads the selected territory's seeded battle map and zooms back in. Capturing it happens on
## map_completed (see _on_map_completed). Clears the previous battle's transient entities.
func _deploy_to_node(node_id: String) -> void:
	## [Persistence Step 5] Snapshot the territory we're leaving (active_node still points to it) so its
	## development persists independently, then switch and restore any development the destination already
	## had (returning to a held node). Cross-territory income stays approximate — a per-territory economy
	## recompute is a separate galaxy-campaign follow-up.
	_capture_territory_development()
	## Invading = frontier (neutral/enemy) node; returning = owned node. The distinction controls
	## whether a map_completed triggers capture_system — owned nodes don't need to be recaptured.
	var is_owned : bool = GalaxyManager.star_systems.get(node_id, {}).get("owner", "") == FactionManager.active_faction
	GalaxyManager.invading_node = "" if is_owned else node_id
	GalaxyManager.active_node   = node_id
	_load_territory_map(node_id)
	_restore_territory_development(GalaxyManager.star_systems.get(node_id, {}).get("development", {}))
	hud.call("refresh_objectives")   ## repopulate panel with this territory's objectives
	var cam : Node = get_node_or_null("WorldMap/Camera")
	if cam != null and cam.has_method("board_min_zoom"):
		var z : float = float(cam.call("board_min_zoom"))
		cam.set("zoom", Vector2(z, z))
		cam.set("position", BOARD_CENTER)
	if _galaxy_view != null:
		_galaxy_view.call("setup", BOARD_CENTER)   ## recenter on the new active node + redraw
	var msg : String = "Returning to held territory." if is_owned else \
		"Deploying to contested territory — claim %d sectors to capture it." % ObjectiveManager.TERRITORY_CLAIM_TARGET
	EventBus.notification_pushed.emit(msg, "info")

## Clears the current battle's transient entities (towers/buildings/units) and loads node_id's
## seeded battle map. Shared by _deploy_to_node (galaxy deploy) and the Continue restore path.
func _load_territory_map(node_id: String) -> void:
	for layer in [tower_layer, building_layer, get_node_or_null("WorldMap/UnitLayer")]:
		if layer != null:
			for c in layer.get_children():
				c.queue_free()
	_occupied_cells.clear()
	_building_cells.clear()
	_inspected_cell = Vector2i(-1, -1)
	_map_grid.load_map_data(MAP_GENERATOR_SCRIPT.generate(GalaxyManager.node_seed(node_id)))
	_activate_all_spawns()

## [Persistence] Snapshots the current battle's per-territory development (Step 2: claimed cells)
## into the active node's saved state. Connected to EventBus.game_saving so it runs just before each
## save. No-ops until a real territory is active (post-Academy).
func _capture_territory_development() -> void:
	var node_id : String = GalaxyManager.active_node
	if node_id.is_empty() or not GalaxyManager.star_systems.has(node_id):
		return
	var dev : Dictionary = GalaxyManager.star_systems[node_id].get("development", {})
	dev["claimed"] = _map_grid.call("get_claimed_indices")
	dev["buildings"] = _capture_buildings()
	dev["towers"] = _capture_towers()
	dev["fob"] = _capture_fob()
	GalaxyManager.star_systems[node_id]["development"] = dev

## [Persistence Step 3] Snapshots placed garrisons as [{id, cell, level}] for save/restore.
func _capture_buildings() -> Array:
	var out : Array = []
	for cell in _building_cells:
		var b = _building_cells[cell]
		if not is_instance_valid(b):
			continue
		var bd = b.get("data")
		if bd == null or String(bd.resource_path).is_empty():
			continue
		out.append({"id": String(bd.resource_path), "cell": [int(cell.x), int(cell.y)], "level": int(b.get("_level"))})
	return out

## [Persistence Step 3] Re-instantiates a territory's saved garrisons after its map + claims load.
func _restore_buildings(dev: Dictionary) -> void:
	for brec in dev.get("buildings", []):
		if typeof(brec) != TYPE_DICTIONARY:
			continue
		var bid : String = String(brec.get("id", ""))
		var bcell : Array = brec.get("cell", [])
		if bid.is_empty() or bcell.size() != 2:
			continue
		var bdata : Resource = load(bid)
		if bdata != null:
			_restore_building(bdata, Vector2i(int(bcell[0]), int(bcell[1])), int(brec.get("level", 1)))

## Places a building from explicit data/cell/level (no cost, no income re-add, no build-mode) —
## the restore counterpart to _place_building. Income is already in the restored territory_rates.
func _restore_building(bdata: Resource, cell: Vector2i, level: int) -> void:
	var building : Node2D = BUILDING_SCENE.instantiate()
	building.call("setup", bdata, true)
	building_layer.add_child(building)
	building.position = _cell_to_world(cell)
	if level > 1:
		building.set("_level", level)
	_building_cells[cell] = building
	_apply_structure_influence(cell)

## [Persistence Step 4] Snapshots placed towers as [{id, cell, level}]. The current-tier .tres (id)
## already encodes the upgrade branch, so restore re-instantiates at that tier directly.
func _capture_towers() -> Array:
	var out : Array = []
	for cell in _occupied_cells:
		var t = _occupied_cells[cell]
		if not is_instance_valid(t):
			continue
		var td = t.get("data")
		if td == null or String(td.resource_path).is_empty():
			continue
		out.append({"id": String(td.resource_path), "cell": [int(cell.x), int(cell.y)], "level": int(t.get("level"))})
	return out

## [Persistence Step 4] Snapshots the FOB's fortification rank.
func _capture_fob() -> Dictionary:
	var base : Node = get_node_or_null("WorldMap/Base")
	if base == null:
		return {}
	return {"rank": int(base.get("_fortification_rank"))}

## [Persistence Step 4] Re-instantiates saved towers (at their current tier) after the map loads.
func _restore_towers(dev: Dictionary) -> void:
	for trec in dev.get("towers", []):
		if typeof(trec) != TYPE_DICTIONARY:
			continue
		var tid : String = String(trec.get("id", ""))
		var tcell : Array = trec.get("cell", [])
		if tid.is_empty() or tcell.size() != 2:
			continue
		var tdata : Resource = load(tid)
		if tdata != null:
			_restore_tower(tdata, Vector2i(int(tcell[0]), int(tcell[1])), int(trec.get("level", 1)))

## Places a tower from explicit data/cell/level (the restore counterpart to _place_tower): marks the
## cell for enemy pathing and restores veterancy level. No cost, no build-mode.
func _restore_tower(tdata: Resource, cell: Vector2i, level: int) -> void:
	var tower : Node2D = TOWER_SCENE.instantiate()
	tower.call("setup", tdata)
	tower_layer.add_child(tower)
	tower.position = _cell_to_world(cell)
	_occupied_cells[cell] = tower
	_map_grid.mark_tower_placed(cell.x, cell.y)
	_apply_structure_influence(cell)
	if level > 1:
		tower.call("restore_level", level)

## [Persistence Step 4] Restores the FOB's fortification rank (+ its rank-scaled sphere).
func _restore_fob(dev: Dictionary) -> void:
	var fob : Dictionary = dev.get("fob", {})
	var rank : int = int(fob.get("rank", 0))
	if rank <= 0:
		return
	var base : Node = get_node_or_null("WorldMap/Base")
	if base != null and base.has_method("restore_rank"):
		base.call("restore_rank", rank)

## [Persistence] Re-applies a territory's saved development (claims, garrisons, towers, FOB rank) onto
## the freshly-loaded map. Shared by the Continue restore and deploy-return (Step 5).
func _restore_territory_development(dev: Dictionary) -> void:
	var saved_claims : Array = dev.get("claimed", [])
	if not saved_claims.is_empty():
		_map_grid.call("apply_claimed_indices", saved_claims)
	_restore_buildings(dev)
	_restore_towers(dev)
	_restore_fob(dev)

## Territory won (all objectives complete) → capture the node being invaded, opening new frontier.
func _on_map_completed() -> void:
	if GalaxyManager.invading_node.is_empty():
		return
	var node_id : String = GalaxyManager.invading_node
	GalaxyManager.capture_system(node_id, FactionManager.active_faction)
	GalaxyManager.invading_node = ""
	EventBus.notification_pushed.emit("Territory captured: %s. New frontier opened." % node_id, "info")
	if _galaxy_view != null and is_instance_valid(_galaxy_view):
		_galaxy_view.call("queue_redraw")

## -- C4: offline army resolution --

## Fires when a save is loaded after time away (EconomyManager.apply_offline_time). Garrisons
## that existed offline expand the player's territory. (Buildings/claims aren't persisted yet —
## see the galactic-map persistence note — so on a real Continue there are no garrisons to run;
## this is correctly wired for when that lands, and exercisable now via the F4 dev key.)
func _on_offline_catch_up(seconds_elapsed: float) -> void:
	_resolve_offline_army(seconds_elapsed)

## Fast-forwards every garrison's standing-order raids over the elapsed time and reports a single
## summary. Each garrison runs its real raid rules against the live map (see
## Building.simulate_offline_raids), so territory grows exactly as it would have online.
func _resolve_offline_army(seconds_elapsed: float) -> void:
	var total : int = 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.has_method("simulate_offline_raids"):
			total += int(b.call("simulate_offline_raids", seconds_elapsed))
	if total > 0:
		var mins : int = int(seconds_elapsed / 60.0)
		EventBus.notification_pushed.emit(
			"While you were away (%d min), your garrisons claimed %d cells of territory." % [mins, total],
			"info"
		)

## Transitions all DORMANT spawn points to ACTIVE. Safe to call on already-active
## or sealed spawns — activate_spawn_by_id only transitions DORMANT → ACTIVE.
func _activate_all_spawns() -> void:
	var data = _map_grid.get("map_data")
	if data == null:
		return
	for sp in data.spawn_points:
		if sp == null:
			continue
		if data.activate_spawn_by_id(sp.id):
			EventBus.spawn_activated.emit(sp.id)

## -- Input --

func _unhandled_input(event: InputEvent) -> void:
	## ESC cancels placement/build mode, or collapses panels to glance state.
	## Using _unhandled_input so GUI controls (InspectionPanel Upgrade button,
	## action bar buttons) consume their clicks before this handler sees them.
	if event is InputEventKey and event.pressed:
		## DEV: F1/F2/F3 skip the Academy and start as Architects / Mesh / Bloom. Gated on
		## OS.is_debug_build() so they are compiled out of release exports and can never
		## ship, while staying available in editor/debug runs. F2/F3 added to playtest
		## faction-flavored enemy pathing (each player faction faces a different enemy).
		if OS.is_debug_build() and not GameState.academy_completed:
			var dev_faction  : String = ""
			var dev_sub_path : String = ""
			match event.keycode:
				KEY_F1: dev_faction = "architects"; dev_sub_path = "standard"
				KEY_F2: dev_faction = "mesh";       dev_sub_path = "networked"
				KEY_F3: dev_faction = "bloom";      dev_sub_path = "purist"
			if not dev_faction.is_empty():
				FactionManager.select_faction(dev_faction, dev_sub_path)
				GameState.academy_completed = true
				academy.hide()
				## The Academy may have already emitted academy_phase_started (which hides the
				## Begin Waves button). Skipping bypasses academy_phase_ended, so restore the
				## HUD explicitly or the wave button stays hidden after the skip.
				EventBus.academy_phase_ended.emit()
				_start_game_world()
				get_viewport().set_input_as_handled()
				return
		## DEV: F4 simulates 1 hour of offline army resolution on the live session (so C4
		## can be exercised before building/territory persistence lands). Gated on debug build.
		if OS.is_debug_build() and GameState.academy_completed and event.keycode == KEY_F4:
			_resolve_offline_army(3600.0)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if _placement_mode:
				_cancel_placement()
			elif _build_mode:
				_cancel_build()
			else:
				hud.enter_glance_state()
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton and event.pressed):
		return

	## Ignore HUD zones (top / bottom 48 px).
	var y      : float = event.position.y
	var height : float = get_viewport().get_visible_rect().size.y
	if y < 48.0 or y > height - 48.0:
		return
	## Academy CHAMBER (chapters 0/2): world clicks belong to the CadetAvatar. Live SCENARIOS (chapter 1):
	## the player commands the real Commander, so accept world input during the scenario phase only.
	if not GameState.academy_completed and not _academy_scenarios_active:
		return

	## Controls: LEFT = select (Commander / tower / building / FOB), RIGHT = move the
	## selected Commander (Shift chains waypoints). Left never moves, so the player can
	## click freely without ordering a move.
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if _placement_mode:
				_try_place_tower(event.position)
				get_viewport().set_input_as_handled()
			elif _build_mode:
				_try_place_building(event.position)
				get_viewport().set_input_as_handled()
			elif _in_galaxy_zoom():
				_handle_galaxy_click(event.position)
				get_viewport().set_input_as_handled()
			else:
				_handle_select_click(event.position)
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			if _placement_mode:
				_cancel_placement()
				get_viewport().set_input_as_handled()
			elif _build_mode:
				_cancel_build()
				get_viewport().set_input_as_handled()
			else:
				_handle_move_click(event.position, event.shift_pressed)
				get_viewport().set_input_as_handled()

## -- Placement preview ghost --

func _process(_delta: float) -> void:
	if not (_placement_mode or _build_mode):
		if _placement_preview.visible:
			_placement_preview.visible = false
		return
	_update_placement_preview()

## Creates the cursor-follow highlight once and parents it under WorldMap so it
## shares the map transform (camera pan/zoom) and draws on top of the map layers.
func _build_placement_preview() -> void:
	_placement_preview = ColorRect.new()
	_placement_preview.size         = Vector2(GRID_SIZE, GRID_SIZE)
	_placement_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placement_preview.visible      = false
	$WorldMap.add_child(_placement_preview)

## Moves the ghost to the hovered cell and recolours it on cell change. Hidden in
## the HUD dead-zone so it matches where clicks are actually accepted.
func _update_placement_preview() -> void:
	var mouse  : Vector2 = get_viewport().get_mouse_position()
	var height : float   = get_viewport().get_visible_rect().size.y
	if mouse.y < 48.0 or mouse.y > height - 48.0:
		_placement_preview.visible = false
		return
	var cell : Vector2i = _screen_to_cell(mouse)
	_placement_preview.visible  = true
	_placement_preview.position = Vector2(cell.x * GRID_SIZE, cell.y * GRID_SIZE)
	if cell != _preview_cell:
		_preview_cell = cell
		_placement_preview.color = PREVIEW_VALID if _is_cell_placeable(cell) else PREVIEW_INVALID

## True when the next placement at `cell` would succeed. Mirrors the guards in
## _try_place_tower / _try_place_building (minus the affordability check, which the
## action buttons already gate). Off-map cells are rejected so the ghost reads red
## past the map edge.
func _is_cell_placeable(cell: Vector2i) -> bool:
	var data = _map_grid.get("map_data")
	if data != null:
		if cell.x < 0 or cell.y < 0 or cell.x >= data.dimensions.x or cell.y >= data.dimensions.y:
			return false
	if _build_mode:
		return not _building_cells.has(cell) and bool(_map_grid.call("is_claimed", cell.x, cell.y))
	return not _occupied_cells.has(cell) and _map_grid.can_place_at(cell.x, cell.y)

## -- Tower placement --

func _on_placement_requested(tower_data: Resource) -> void:
	_cancel_build()          ## Exit build mode if active
	hud.close_inspection()   ## Dismiss inspection panel when entering placement
	_pending_tower  = tower_data
	_placement_mode = true
	GameState.placement_active = true   ## Commander yields world clicks while placing
	_preview_cell   = Vector2i(-9999, -9999)   ## force a recolor on the next frame

func _try_place_tower(screen_pos: Vector2) -> void:
	var cell : Vector2i = _screen_to_cell(screen_pos)
	if _occupied_cells.has(cell):
		EventBus.notification_pushed.emit("Cell already occupied.", "warning")
		return
	if not _map_grid.can_place_at(cell.x, cell.y):
		EventBus.notification_pushed.emit(
			"Can't place here — click open ground away from the enemy path.", "warning"
		)
		return
	var cost : Dictionary = {FactionManager.get_primary_resource(): _pending_tower.primary_cost}
	if not EconomyManager.can_afford(cost):
		_cancel_placement()
		return
	EconomyManager.spend(cost)
	var route_changed : bool = _map_grid.mark_tower_placed(cell.x, cell.y)
	_place_tower(cell)
	EventBus.notification_pushed.emit("Tower placed.", "positive")
	if route_changed:
		EventBus.path_changed.emit()

func _place_tower(cell: Vector2i) -> void:
	var tower : Node2D = TOWER_SCENE.instantiate()
	tower.call("setup", _pending_tower)
	tower_layer.add_child(tower)
	tower.position = _cell_to_world(cell)
	_occupied_cells[cell] = tower
	_apply_structure_influence(cell)
	EventBus.tower_placed.emit(_pending_tower, cell)
	## Single-shot placement: exit placement mode after each tower so the player can
	## immediately click a tower to inspect/sell/retarget. Re-press Place Tower to add more.
	_cancel_placement()

func _cancel_placement() -> void:
	_placement_mode = false
	GameState.placement_active = false
	_pending_tower  = null
	hud.end_placement_mode()

## -- Tower upgrades --

func _try_upgrade_tower(cell: Vector2i, branch: int = 0) -> void:
	var tower = _occupied_cells.get(cell)
	if tower == null or not is_instance_valid(tower):
		_occupied_cells.erase(cell)
		return
	var current_data = tower.get("data")
	if current_data == null:
		return
	## Branch 1 = B specialization (if any); branch 0 = the primary upgrade.
	var next_data = current_data.get("upgrade_to_b") if branch == 1 else current_data.get("upgrade_to")
	if next_data == null:
		EventBus.notification_pushed.emit("Already at max tier.", "info")
		return
	var cost := {FactionManager.get_primary_resource(): float(next_data.get("primary_cost"))}
	if not EconomyManager.can_afford(cost):
		EventBus.notification_pushed.emit(
			"Not enough %s to upgrade. (need %d)" % [
				FactionManager.get_primary_resource(),
				int(next_data.get("primary_cost"))
			], "warning"
		)
		return
	EconomyManager.spend(cost)
	tower.call("upgrade", next_data)
	EventBus.notification_pushed.emit(
		"%s upgraded to Tier %d." % [
			str(next_data.get("tower_name")),
			int(next_data.get("tier"))
		], "positive"
	)
	EventBus.tower_upgraded.emit(next_data, cell)

## -- Building placement --

func _on_build_requested(building_data: Resource) -> void:
	_cancel_placement()       ## Exit tower mode if active
	hud.close_inspection()    ## Dismiss inspection panel when entering build mode
	_pending_building = building_data
	_build_mode       = true
	GameState.placement_active = true   ## Commander yields world clicks while placing
	_preview_cell     = Vector2i(-9999, -9999)   ## force a recolor on the next frame

func _try_place_building(screen_pos: Vector2) -> void:
	var cell : Vector2i = _screen_to_cell(screen_pos)
	## Buildings only go on CLAIMED territory.
	var claimed : bool = _map_grid.call("is_claimed", cell.x, cell.y)
	if not claimed:
		EventBus.notification_pushed.emit(
			"Buildings go on claimed ground — walk your Commander there first.", "warning"
		)
		return
	## One building per cell.
	if _building_cells.has(cell):
		EventBus.notification_pushed.emit("Cell already has a building.", "warning")
		return
	var primary_res : String = FactionManager.get_primary_resource()
	var cost_val    : float  = float(_pending_building.get("primary_cost"))
	var cost : Dictionary = {primary_res: cost_val}
	if not EconomyManager.can_afford(cost):
		EventBus.notification_pushed.emit(
			"Not enough %s to place a building." % FactionManager.get_primary_resource(), "warning"
		)
		_cancel_build()
		return
	EconomyManager.spend(cost)
	_place_building(cell)
	EventBus.notification_pushed.emit("Building placed.", "positive")

func _place_building(cell: Vector2i) -> void:
	var building : Node2D = BUILDING_SCENE.instantiate()
	building.call("setup", _pending_building)
	building_layer.add_child(building)
	building.position = _cell_to_world(cell)
	_building_cells[cell] = building
	_apply_structure_influence(cell)
	EventBus.building_placed.emit(_pending_building, cell)
	## Single-shot placement (matches towers). Re-press Place Building to add more.
	_cancel_build()

func _cancel_build() -> void:
	_build_mode       = false
	GameState.placement_active = false
	_pending_building = null
	hud.end_build_mode()

## -- Territory raids (building destruction) --

func _on_territory_raided(cell: Vector2i) -> void:
	if not _building_cells.has(cell):
		return
	var building = _building_cells.get(cell)
	var bdata    = building.get("data") if is_instance_valid(building) else null
	if is_instance_valid(building):
		building.call("destroy")
	_building_cells.erase(cell)
	if bdata != null:
		EventBus.building_destroyed.emit(bdata, cell)
		EventBus.notification_pushed.emit(
			"%s destroyed by raiders!" % str(bdata.get("building_name")),
			"alert"
		)

## -- Inspection panel --

func _open_tower_inspection(cell: Vector2i) -> void:
	var tower = _occupied_cells.get(cell)
	if tower == null or not is_instance_valid(tower):
		_occupied_cells.erase(cell)
		return
	_inspected_cell = cell
	var d           = tower.get("data")
	var next        = d.get("upgrade_to") if d != null else null
	var can_afford  : bool = false
	if next != null:
		var cost : float = float(next.get("primary_cost") if next.get("primary_cost") != null else 0.0)
		can_afford = EconomyManager.can_afford({FactionManager.get_primary_resource(): cost})
	hud.open_tower_inspection(tower, can_afford)

func _open_building_inspection(cell: Vector2i) -> void:
	var building = _building_cells.get(cell)
	if building == null or not is_instance_valid(building):
		_building_cells.erase(cell)
		return
	_inspected_cell = cell
	hud.open_building_inspection(building)

func _open_fob_inspection() -> void:
	var base : Node = get_node_or_null("WorldMap/Base")
	if base == null:
		return
	_inspected_cell = Vector2i(-1, -1)
	hud.open_fob_inspection(base)

## Applies an FOB doctrine (RPS upgrade) after spending its cost, then refreshes the panel.
func _on_fob_doctrine_requested(doctrine_id: String) -> void:
	var base : Node = get_node_or_null("WorldMap/Base")
	if base == null:
		return
	var primary : String = FactionManager.get_primary_resource()
	var cost : Dictionary = {primary: FOB_DOCTRINE_COST}
	if not EconomyManager.can_afford(cost):
		EventBus.notification_pushed.emit(
			"Not enough %s for an FOB doctrine. (need %d)" % [primary, int(FOB_DOCTRINE_COST)], "warning"
		)
		return
	EconomyManager.spend(cost)
	base.call("set_doctrine", doctrine_id)
	EventBus.notification_pushed.emit("FOB doctrine set: %s." % doctrine_id.capitalize(), "positive")
	hud.open_fob_inspection(base)   ## refresh the panel to show the new doctrine

# -- Selection + move orders (left = select, right = move) --------------------

## Resolves the Commander node (WorldMap/CommanderLayer/Commander).
func _commander() -> Node:
	return get_node_or_null("WorldMap/CommanderLayer/Commander")

## Converts a screen-pixel radius to world units using the current camera zoom.
func _world_radius(screen_px: float) -> float:
	var cam : Camera2D = get_node_or_null("WorldMap/Camera") as Camera2D
	var zoom : float = cam.zoom.x if cam != null else 1.0
	return screen_px / maxf(zoom, 0.01)

## Left-click: select the Commander (generous radius), else inspect a structure under the
## click, else clear selection + close the panel.
func _handle_select_click(screen_pos: Vector2) -> void:
	var world : Vector2 = _screen_to_world(screen_pos)
	var cmd : Node = _commander()
	if cmd != null and (cmd as Node2D).global_position.distance_to(world) <= _world_radius(COMMANDER_SELECT_SCREEN_PX):
		var was_selected : bool = bool(cmd.call("is_selected"))
		cmd.call("set_selected", true)
		hud.close_inspection()
		if not was_selected:
			EventBus.notification_pushed.emit(
				"Commander selected — right-click to move (Shift-click to chain).", "info"
			)
		return
	var hit : Dictionary = _structure_at_world(world)
	match str(hit.get("kind", "")):
		"tower":    _open_tower_inspection(hit["cell"])
		"building": _open_building_inspection(hit["cell"])
		"fob":      _open_fob_inspection()
		_:          hud.close_inspection()
	if cmd != null:
		cmd.call("set_selected", false)

## Right-click: order the selected Commander to move (append=Shift chains waypoints).
func _handle_move_click(screen_pos: Vector2, append: bool) -> void:
	var cmd : Node = _commander()
	if cmd == null or not cmd.has_method("is_selected") or not cmd.call("is_selected"):
		return
	cmd.call("move_command", _screen_to_world(screen_pos), append)

## Finds the structure whose centre is nearest the world point, within
## STRUCTURE_HIT_RADIUS. Returns {"kind": "tower"|"building"|"fob"|"", "cell": Vector2i}.
func _structure_at_world(world: Vector2) -> Dictionary:
	var best_kind : String  = ""
	var best_cell : Vector2i = Vector2i(-9999, -9999)
	var best_dist : float   = _world_radius(STRUCTURE_HIT_SCREEN_PX)
	for cell in _occupied_cells:
		var dt : float = world.distance_to(_cell_to_world(cell))
		if dt <= best_dist:
			best_dist = dt
			best_kind = "tower"
			best_cell = cell
	for cell in _building_cells:
		var db : float = world.distance_to(_cell_to_world(cell))
		if db <= best_dist:
			best_dist = db
			best_kind = "building"
			best_cell = cell
	var fc : Vector2i = _fob_cell()
	if fc != Vector2i(-9999, -9999):
		var df : float = world.distance_to(_cell_to_world(fc))
		if df <= best_dist:
			best_dist = df
			best_kind = "fob"
			best_cell = fc
	return {"kind": best_kind, "cell": best_cell}

func _on_panel_upgrade_requested(branch: int) -> void:
	if _inspected_cell == Vector2i(-1, -1):
		return
	_try_upgrade_tower(_inspected_cell, branch)
	_inspected_cell = Vector2i(-1, -1)

## -- Sell / refund --

func _on_panel_sell_requested() -> void:
	if _inspected_cell == Vector2i(-1, -1):
		return
	if _occupied_cells.has(_inspected_cell):
		_sell_tower(_inspected_cell)
	elif _building_cells.has(_inspected_cell):
		_sell_building(_inspected_cell)
	_inspected_cell = Vector2i(-1, -1)
	hud.close_inspection()

func _sell_tower(cell: Vector2i) -> void:
	var tower = _occupied_cells.get(cell)
	if tower == null or not is_instance_valid(tower):
		_occupied_cells.erase(cell)
		return
	var d = tower.get("data")
	var refund : float = floorf(float(d.get("primary_cost")) * SELL_REFUND_FRACTION) if d != null else 0.0
	EconomyManager.add_resource(FactionManager.get_primary_resource(), refund)
	## Restore a path-blocking tower's cell so enemies can route through again.
	var route_changed : bool = bool(_map_grid.call("unmark_tower", cell.x, cell.y))
	tower.queue_free()
	_occupied_cells.erase(cell)
	EventBus.notification_pushed.emit(
		"Tower sold — refunded %d %s." % [int(refund), FactionManager.get_primary_resource()], "positive"
	)
	if route_changed:
		EventBus.path_changed.emit()

func _sell_building(cell: Vector2i) -> void:
	var building = _building_cells.get(cell)
	if building == null or not is_instance_valid(building):
		_building_cells.erase(cell)
		return
	var d = building.get("data")
	var refund : float = floorf(float(d.get("primary_cost")) * SELL_REFUND_FRACTION) if d != null else 0.0
	EconomyManager.add_resource(FactionManager.get_primary_resource(), refund)
	if building.has_method("destroy"):
		building.call("destroy")   ## removes its income contribution + frees the node
	else:
		building.queue_free()
	_building_cells.erase(cell)
	EventBus.notification_pushed.emit(
		"Building sold — refunded %d %s." % [int(refund), FactionManager.get_primary_resource()], "positive"
	)

## -- Helpers --

## Projects a placed structure's sphere of influence: reveals fog within its sight
## radius and senses the ring just beyond. Vision only — towers/buildings don't claim.
func _apply_structure_influence(cell: Vector2i) -> void:
	if _map_grid == null:
		return
	_map_grid.call("reveal_area", cell, STRUCTURE_SIGHT_RADIUS)
	_map_grid.call("sense_area", cell, STRUCTURE_SIGHT_RADIUS, STRUCTURE_SIGHT_RADIUS + STRUCTURE_SENSOR_EXTRA)

## True when a tower or building occupies the cell under `screen_pos`. The Commander
## calls this to yield structure-clicks to Main (which opens the inspection panel)
## instead of consuming the click as a move order.
func structure_at_screen(screen_pos: Vector2) -> bool:
	var cell : Vector2i = _screen_to_cell(screen_pos)
	return _occupied_cells.has(cell) or _building_cells.has(cell) or cell == _fob_cell()

## The map cell the FOB occupies (for click-to-inspect). Computed from the Base node.
func _fob_cell() -> Vector2i:
	var base : Node = get_node_or_null("WorldMap/Base")
	if base == null or _map_grid == null:
		return Vector2i(-9999, -9999)
	return _map_grid.call("world_to_cell", (base as Node2D).global_position)

## Converts a screen-space position to a world position, accounting for Camera2D
## zoom and pan. Falls back to a 1:1 mapping if no camera is present.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var camera : Camera2D = get_node_or_null("WorldMap/Camera") as Camera2D
	if camera == null:
		return screen_pos
	var vp_center : Vector2 = get_viewport().get_visible_rect().size * 0.5
	return camera.global_position + (screen_pos - vp_center) / camera.zoom

## Converts a screen-space click position to a map cell.
func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var world_pos : Vector2 = _screen_to_world(screen_pos)
	return Vector2i(
		int(floor(world_pos.x / float(GRID_SIZE))),
		int(floor(world_pos.y / float(GRID_SIZE)))
	)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * GRID_SIZE + GRID_SIZE * 0.5,
		cell.y * GRID_SIZE + GRID_SIZE * 0.5
	)

## -- Milestone visuals --

func _on_milestone_reached(faction_id: String, _milestone_index: int) -> void:
	_play_milestone_wash(faction_id)

func _play_milestone_wash(faction_id: String) -> void:
	var tween : Tween = create_tween()
	tween.tween_property(_milestone_wash, "color:a", WASH_ALPHA, WASH_FADE_IN)
	tween.tween_interval(WASH_HOLD)
	tween.tween_property(_milestone_wash, "color:a", 0.0, WASH_FADE_OUT)
	tween.tween_callback(_spawn_ancient_watcher.bind(faction_id))

func _spawn_ancient_watcher(faction_id: String) -> void:
	var ruins_cell : Vector2i = _find_ruins_cell()
	if ruins_cell == Vector2i(-1, -1):
		return
	var dialogue : String = _ancient_dialogue(faction_id)
	var watcher  : Node2D = ANCIENT_WATCHER_SCENE.instantiate() as Node2D
	get_node("WorldMap").add_child(watcher)
	var start_world  : Vector2 = _cell_to_world(ruins_cell)
	var target_world : Vector2 = _cell_to_world(ruins_cell + Vector2i(1, 0))
	watcher.global_position = start_world
	watcher.call("setup", target_world, dialogue)

## Returns the center cell of the first ANCIENT_PATH_CROSSING zone, or (-1,-1).
func _find_ruins_cell() -> Vector2i:
	var data : MapData = _map_grid.get("map_data") as MapData
	if data == null:
		return Vector2i(-1, -1)
	for zone : ZoneRegion in data.zones:
		if zone == null:
			continue
		if zone.kind == ZoneRegion.ZoneKind.ANCIENT_PATH_CROSSING:
			if zone.use_rect:
				var r : Rect2i = zone.shape_rect
				return r.position + Vector2i(r.size.x >> 1, r.size.y >> 1)
			elif not zone.shape_cells.is_empty():
				return zone.shape_cells[zone.shape_cells.size() >> 1]
	return Vector2i(-1, -1)

func _ancient_dialogue(faction_id: String) -> String:
	match faction_id:
		"architects":
			return "You have optimized past the first threshold. We have been watching."
		"bloom":
			return "The territory remembers. You are no longer a visitor."
		"mesh":
			return "The routes hold. The network has reached critical mass."
	return ""
