## Main.gd
## Root scene controller. Owns top-level scene transitions.
## Flow: FactionSelectScreen -> GameWorld (HUD + idle tick running)
## All autoloads are ready before _ready() fires -- safe to use them here.
extends Node

@onready var faction_select: Control = $FactionSelectScreen
@onready var hud: Control            = $GameWorld/HUD

func _ready() -> void:
	# HUD hidden until a faction is confirmed
	hud.hide()
	faction_select.selection_confirmed.connect(_on_faction_confirmed)

	# If a save already has a faction chosen, skip the select screen
	if not GameState.current_faction.is_empty():
		_start_game_world()

func _on_faction_confirmed() -> void:
	_start_game_world()

func _start_game_world() -> void:
	faction_select.hide()
	hud.show()
