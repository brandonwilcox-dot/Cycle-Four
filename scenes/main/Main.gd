## Main.gd
## Root scene controller. Owns top-level scene transitions and tower placement.
## Flow: FactionSelectScreen -> game world (HUD visible, waves + economy running)
extends Node

const TOWER_SCENE: PackedScene = preload("res://scenes/main/Tower.tscn")
const GRID_SIZE: int = 64   ## Pixels per grid cell for tower snapping

@onready var faction_select: Control = $UILayer/FactionSelectScreen
@onready var hud: Control            = $UILayer/HUD
@onready var tower_layer: Node2D     = $WorldMap/TowerLayer
@onready var world_map: Node2D       = $WorldMap
@onready var _map_grid: Node2D       = $WorldMap/MapGrid

## Placement state
var _placement_mode: bool     = false
var _pending_tower: Resource  = null   ## TowerData being placed
var _occupied_cells: Dictionary = {}   ## Vector2i -> true; prevents double-placing

func _ready() -> void:
	hud.hide()
	faction_select.selection_confirmed.connect(_on_faction_confirmed)
	EventBus.tower_placement_requested.connect(_on_placement_requested)
	if not GameState.current_faction.is_empty():
		## Restore FactionManager state from save so HUD and tower button initialise
		## correctly without resetting the economy (SaveManager already did that).
		FactionManager.restore_faction(GameState.current_faction, GameState.current_sub_path)
		_start_game_world()

func _on_faction_confirmed() -> void:
	_start_game_world()

func _start_game_world() -> void:
	faction_select.hide()
	hud.show()

## -- Tower placement --

func _on_placement_requested(tower_data: Resource) -> void:
	_pending_tower  = tower_data
	_placement_mode = true

func _input(event: InputEvent) -> void:
	if not _placement_mode:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_placement()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	## Ignore clicks inside the HUD bars so buttons still work normally.
	## TopBar occupies the top 48px; BottomBar the bottom 48px.
	var y: float    = event.position.y
	var height: float = get_viewport().get_visible_rect().size.y
	if y < 48.0 or y > height - 48.0:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_try_place_tower(event.position)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			_cancel_placement()
			get_viewport().set_input_as_handled()

func _try_place_tower(screen_pos: Vector2) -> void:
	## Snap click position to the nearest grid cell
	var cell := Vector2i(
		int(floor(screen_pos.x / GRID_SIZE)),
		int(floor(screen_pos.y / GRID_SIZE))
	)
	if _occupied_cells.has(cell):
		return   ## Cell already has a tower

	## Phase C: reject placement that would disconnect any spawn from the base.
	## Also blocks placement directly on spawn or base cells.
	if not _map_grid.can_place_at(cell.x, cell.y):
		return

	var cost: Dictionary = {FactionManager.get_primary_resource(): _pending_tower.primary_cost}
	if not EconomyManager.can_afford(cost):
		return
	EconomyManager.spend(cost)

	## Commit path change BEFORE placing the tower node so rerouted units
	## get valid waypoints on the same frame the tower appears.
	var route_changed : bool = _map_grid.mark_tower_placed(cell.x, cell.y)
	_place_tower(cell)
	if route_changed:
		EventBus.path_changed.emit()

func _place_tower(cell: Vector2i) -> void:
	_occupied_cells[cell] = true
	var tower: Node2D = TOWER_SCENE.instantiate()
	tower.call("setup", _pending_tower)
	tower_layer.add_child(tower)
	tower.position = Vector2(
		cell.x * GRID_SIZE + GRID_SIZE * 0.5,
		cell.y * GRID_SIZE + GRID_SIZE * 0.5
	)
	EventBus.tower_placed.emit(_pending_tower, cell)
	_cancel_placement()   ## Return to normal mode after each placement

func _cancel_placement() -> void:
	_placement_mode = false
	_pending_tower  = null
	hud.end_placement_mode()

## Map path is now owned by MapGrid (res://src/core/map/MapGrid.gd).
## Main.gd no longer builds or holds a Path2D reference.
