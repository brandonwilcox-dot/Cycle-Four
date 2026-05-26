## Main.gd
## Root scene controller. Owns top-level scene transitions and tower placement.
## Flow: FactionSelectScreen -> game world (HUD visible, waves + economy running)
extends Node

const TOWER_SCENE: PackedScene = preload("res://scenes/main/Tower.tscn")
const GRID_SIZE: int = 64   ## Pixels per grid cell for tower snapping

@onready var faction_select: Control = $UILayer/FactionSelectScreen
@onready var hud: Control            = $UILayer/HUD
@onready var unit_path: Path2D       = $WorldMap/UnitPath
@onready var tower_layer: Node2D     = $WorldMap/TowerLayer
@onready var world_map: Node2D       = $WorldMap

## Placement state
var _placement_mode: bool     = false
var _pending_tower: Resource  = null   ## TowerData being placed
var _occupied_cells: Dictionary = {}   ## Vector2i -> true; prevents double-placing

func _ready() -> void:
	hud.hide()
	faction_select.selection_confirmed.connect(_on_faction_confirmed)
	EventBus.tower_placement_requested.connect(_on_placement_requested)
	_build_default_path()
	if not GameState.current_faction.is_empty():
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

func _unhandled_input(event: InputEvent) -> void:
	if not _placement_mode:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_try_place_tower(event.position)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				_cancel_placement()
				get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if _placement_mode and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_cancel_placement()

func _try_place_tower(screen_pos: Vector2) -> void:
	## Snap to grid and validate before spending resources
	var cell := Vector2i(
		int(floor(screen_pos.x / GRID_SIZE)),
		int(floor(screen_pos.y / GRID_SIZE))
	)
	if _occupied_cells.has(cell):
		return   ## Cell already occupied
	var cost: Dictionary = {FactionManager.get_primary_resource(): _pending_tower.primary_cost}
	if not EconomyManager.can_afford(cost):
		return   ## Not enough resources
	EconomyManager.spend(cost)
	_place_tower(cell)

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

## -- Map path --

func _build_default_path() -> void:
	## Placeholder S-curve path across the screen.
	## Replace with designed map paths per biome (core/17).
	var points: Array[Vector2] = [
		Vector2(50.0,   300.0),
		Vector2(400.0,  300.0),
		Vector2(600.0,  500.0),
		Vector2(900.0,  500.0),
		Vector2(1100.0, 250.0),
		Vector2(1400.0, 250.0),
		Vector2(1600.0, 540.0),
		Vector2(1860.0, 540.0),
	]
	var curve := Curve2D.new()
	for p in points:
		curve.add_point(p)
	unit_path.curve = curve

	## Draw the path so the player can see where units will walk.
	var line := Line2D.new()
	line.points = curve.tessellate()
	line.width  = 6.0
	line.default_color = Color(0.35, 0.35, 0.50, 0.85)
	world_map.add_child(line)
