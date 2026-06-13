## Main.gd
## Root scene controller. Owns scene transitions, tower placement/upgrades,
## and production building placement/destruction.
extends Node

const TOWER_SCENE           : PackedScene = preload("res://scenes/main/Tower.tscn")
const BUILDING_SCENE        : PackedScene = preload("res://scenes/main/Building.tscn")
const ANCIENT_WATCHER_SCENE : PackedScene = preload("res://scenes/main/AncientWatcher.tscn")
const GRID_SIZE             : int = 64

## Sight/sensor sphere every placed structure (tower, building) projects. Structures
## grant vision, not territory — only the Commander and FOB claim cells.
const STRUCTURE_SIGHT_RADIUS : int = 3
const STRUCTURE_SENSOR_EXTRA : int = 2

const WASH_FADE_IN  : float = 0.4
const WASH_HOLD     : float = 0.3
const WASH_FADE_OUT : float = 0.4
const WASH_ALPHA    : float = 0.6

## Placement-preview ghost tints. Green = the hovered cell will accept the
## tower/building; red = it will be rejected.
const PREVIEW_VALID   : Color = Color(0.30, 0.95, 0.40, 0.28)
const PREVIEW_INVALID : Color = Color(0.95, 0.25, 0.20, 0.28)

@onready var faction_select   : Node2D    = $UILayer/Academy
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

func _ready() -> void:
	add_to_group("main_controller")
	hud.hide()
	faction_select.selection_confirmed.connect(_on_faction_confirmed)
	EventBus.tower_placement_requested.connect(_on_placement_requested)
	EventBus.building_placement_requested.connect(_on_build_requested)
	EventBus.territory_raided.connect(_on_territory_raided)
	EventBus.panel_upgrade_requested.connect(_on_panel_upgrade_requested)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	_build_placement_preview()
	if not GameState.current_faction.is_empty() and GameState.academy_completed:
		FactionManager.restore_faction(GameState.current_faction, GameState.current_sub_path)
		_start_game_world()

func _on_faction_confirmed() -> void:
	_start_game_world()

func _start_game_world() -> void:
	faction_select.hide()
	## Fully retire the Academy: stop its processing/input (cadet included) and clear
	## any scenario enemies it spawned, so nothing leaks into the live game. Covers the
	## normal-completion, F1-skip, and save-restore entry paths.
	faction_select.process_mode = Node.PROCESS_MODE_DISABLED
	EventBus.academy_clear_units.emit()
	hud.show()
	## Pre-activate every spawn point so waves work immediately on first launch.
	## The Commander's exploration normally activates them; this ensures the first
	## session always has enemies regardless of where the player wandered during
	## the Academy scenarios.
	_activate_all_spawns()
	EventBus.notification_pushed.emit(
		"Place towers on open ground, then press Begin Waves.", "info"
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
		## DEV: F1 skips Academy → architects. Gated on OS.is_debug_build() so it is
		## compiled out of release exports and can never ship, while staying available
		## in editor/debug runs.
		if event.keycode == KEY_F1 and OS.is_debug_build() and not GameState.academy_completed:
			FactionManager.select_faction("architects", "standard")
			GameState.academy_completed = true
			faction_select.hide()
			## The Academy may have already emitted academy_phase_started (which hides the
			## Begin Waves button). Skipping bypasses academy_phase_ended, so restore the
			## HUD explicitly or the wave button stays hidden after the F1 skip.
			EventBus.academy_phase_ended.emit()
			_start_game_world()
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

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if _placement_mode:
				_try_place_tower(event.position)
				get_viewport().set_input_as_handled()
			elif _build_mode:
				_try_place_building(event.position)
				get_viewport().set_input_as_handled()
			else:
				## Occupied tower/building cell → open inspection panel.
				## Empty cell → close inspection (player looked away), let Commander move.
				var cell := _screen_to_cell(event.position)
				if _occupied_cells.has(cell):
					_open_tower_inspection(cell)
					get_viewport().set_input_as_handled()
				elif _building_cells.has(cell):
					_open_building_inspection(cell)
					get_viewport().set_input_as_handled()
				else:
					hud.close_inspection()
		MOUSE_BUTTON_RIGHT:
			if _placement_mode:
				_cancel_placement()
				get_viewport().set_input_as_handled()
			elif _build_mode:
				_cancel_build()
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
	## Stay in placement mode while the player can still afford another tower.
	if not EconomyManager.can_afford({FactionManager.get_primary_resource(): _pending_tower.primary_cost}):
		_cancel_placement()

func _cancel_placement() -> void:
	_placement_mode = false
	GameState.placement_active = false
	_pending_tower  = null
	hud.end_placement_mode()

## -- Tower upgrades --

func _try_upgrade_tower(cell: Vector2i) -> void:
	var tower = _occupied_cells.get(cell)
	if tower == null or not is_instance_valid(tower):
		_occupied_cells.erase(cell)
		return
	var current_data = tower.get("data")
	if current_data == null:
		return
	var next_data = current_data.get("upgrade_to")
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
	## Stay in build mode while the player can still afford another building.
	if not EconomyManager.can_afford({FactionManager.get_primary_resource(): float(_pending_building.get("primary_cost"))}):
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

func _on_panel_upgrade_requested() -> void:
	if _inspected_cell == Vector2i(-1, -1):
		return
	_try_upgrade_tower(_inspected_cell)
	_inspected_cell = Vector2i(-1, -1)

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
	return _occupied_cells.has(cell) or _building_cells.has(cell)

## Converts a screen-space click position to a map cell, accounting for Camera2D
## zoom and pan. Falls back to a 1:1 mapping if no camera is present.
func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var camera : Camera2D = get_node_or_null("WorldMap/Camera") as Camera2D
	var world_pos : Vector2
	if camera != null:
		var vp_center : Vector2 = get_viewport().get_visible_rect().size * 0.5
		world_pos = camera.global_position + (screen_pos - vp_center) / camera.zoom
	else:
		world_pos = screen_pos
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
