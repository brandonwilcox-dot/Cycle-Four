## Main.gd
## Root scene controller. Owns top-level scene transitions.
## Flow: FactionSelectScreen -> GameWorld (HUD + idle tick running)
## All autoloads are ready before _ready() fires -- safe to use them here.
extends Node

@onready var faction_select: Control = $FactionSelectScreen
@onready var hud: Control            = $GameWorld/HUD
@onready var unit_path: Path2D       = $GameWorld/WorldMap/UnitPath

func _ready() -> void:
	hud.hide()
	faction_select.selection_confirmed.connect(_on_faction_confirmed)
	_build_default_path()
	if not GameState.current_faction.is_empty():
		_start_game_world()

func _on_faction_confirmed() -> void:
	_start_game_world()

func _start_game_world() -> void:
	faction_select.hide()
	hud.show()

func _build_default_path() -> void:
	## Placeholder S-curve path across the screen.
	## Replace with designed map paths per biome (core/17).
	var curve := Curve2D.new()
	curve.add_point(Vector2(50.0,  300.0))
	curve.add_point(Vector2(400.0, 300.0))
	curve.add_point(Vector2(600.0, 500.0))
	curve.add_point(Vector2(900.0, 500.0))
	curve.add_point(Vector2(1100.0, 250.0))
	curve.add_point(Vector2(1400.0, 250.0))
	curve.add_point(Vector2(1600.0, 540.0))
	curve.add_point(Vector2(1860.0, 540.0))
	unit_path.curve = curve
