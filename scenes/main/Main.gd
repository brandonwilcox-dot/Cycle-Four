## Main.gd
## Root scene controller. Owns scene transitions, tower placement/upgrades,
## and production building placement/destruction.
extends Node

const TOWER_SCENE           : PackedScene = preload("res://scenes/main/Tower.tscn")
const BUILDING_SCENE        : PackedScene = preload("res://scenes/main/Building.tscn")
const ANCIENT_WATCHER_SCENE : PackedScene = preload("res://scenes/main/AncientWatcher.tscn")
const GRID_SIZE             : int = 64

const WASH_FADE_IN  : float = 0.4
const WASH_HOLD     : float = 0.3
const WASH_FADE_OUT : float = 0.4
const WASH_ALPHA    : float = 0.6

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

func _ready() -> void:
	hud.hide()
	faction_select.selection_confirmed.connect(_on_faction_confirmed)
	EventBus.tower_placement_requested.connect(_on_placement_requested)
	EventBus.building_placement_requested.connect(_on_build_requested)
	EventBus.territory_raided.connect(_on_territory_raided)
	EventBus.panel_upgrade_requested.connect(_on_panel_upgrade_requested)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	if not GameState.current_faction.is_empty() and GameState.academy_completed:
		FactionManager.restore_faction(GameState.current_faction, GameState.current_sub_path)
		_start_game_world()

func _on_faction_confirmed() -> void:
	_start_game_world()

func _start_game_world() -> void:
	faction_select.hide()
	hud.show()

## -- Input --

func _input(event: InputEvent) -> void:
	## ESC cancels placement/build mode, or collapses panels to glance state.
	if event is InputEventKey and event.pressed:
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

## -- Tower placement --

func _on_placement_requested(tower_data: Resource) -> void:
	_cancel_build()          ## Exit build mode if active
	hud.close_inspection()   ## Dismiss inspection panel when entering placement
	_pending_tower  = tower_data
	_placement_mode = true

func _try_place_tower(screen_pos: Vector2) -> void:
	var cell : Vector2i = _screen_to_cell(screen_pos)
	if _occupied_cells.has(cell):
		return
	if not _map_grid.can_place_at(cell.x, cell.y):
		return
	var cost : Dictionary = {FactionManager.get_primary_resource(): _pending_tower.primary_cost}
	if not EconomyManager.can_afford(cost):
		_cancel_placement()
		return
	EconomyManager.spend(cost)
	var route_changed : bool = _map_grid.mark_tower_placed(cell.x, cell.y)
	_place_tower(cell)
	if route_changed:
		EventBus.path_changed.emit()

func _place_tower(cell: Vector2i) -> void:
	var tower : Node2D = TOWER_SCENE.instantiate()
	tower.call("setup", _pending_tower)
	tower_layer.add_child(tower)
	tower.position = _cell_to_world(cell)
	_occupied_cells[cell] = tower
	EventBus.tower_placed.emit(_pending_tower, cell)
	## Stay in placement mode while the player can still afford another tower.
	if not EconomyManager.can_afford({FactionManager.get_primary_resource(): _pending_tower.primary_cost}):
		_cancel_placement()

func _cancel_placement() -> void:
	_placement_mode = false
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
	EventBus.tower_placed.emit(next_data, cell)

## -- Building placement --

func _on_build_requested(building_data: Resource) -> void:
	_cancel_placement()       ## Exit tower mode if active
	hud.close_inspection()    ## Dismiss inspection panel when entering build mode
	_pending_building = building_data
	_build_mode       = true

func _try_place_building(screen_pos: Vector2) -> void:
	var cell : Vector2i = _screen_to_cell(screen_pos)
	## Buildings only go on CLAIMED territory.
	if not _map_grid.call("is_claimed", cell.x, cell.y):
		return
	## One building per cell.
	if _building_cells.has(cell):
		return
	var cost : Dictionary = {FactionManager.get_primary_resource(): float(_pending_building.get("primary_cost"))}
	if not EconomyManager.can_afford(cost):
		_cancel_build()
		return
	EconomyManager.spend(cost)
	_place_building(cell)

func _place_building(cell: Vector2i) -> void:
	var building : Node2D = BUILDING_SCENE.instantiate()
	building.call("setup", _pending_building)
	building_layer.add_child(building)
	building.position = _cell_to_world(cell)
	_building_cells[cell] = building
	EventBus.building_placed.emit(_pending_building, cell)
	## Stay in build mode while the player can still afford another building.
	if not EconomyManager.can_afford({FactionManager.get_primary_resource(): float(_pending_building.get("primary_cost"))}):
		_cancel_build()

func _cancel_build() -> void:
	_build_mode       = false
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
