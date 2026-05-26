## Main.gd
## Root scene controller. Owns top-level scene transitions.
## Flow: FactionSelectScreen -> GameWorld (HUD + idle tick running)
## All autoloads are ready before _ready() fires -- safe to use them here.
extends Node

@onready var faction_select: Control = $FactionSelectScreen
@onready var game_world: Node        = $GameWorld
@onready var hud: Control            = $GameWorld/HUD

func _ready() -> void:
	# Start in faction-select; hide game world until selection is confirmed
	game_world.visible = false
	faction_select.selection_confirmed.connect(_on_faction_confirmed)

	# If a save exists the faction is already chosen -- skip selection
	if not GameState.current_faction.is_empty():
		_start_game_world()

func _on_faction_confirmed() -> void:
	_start_game_world()

func _start_game_world() -> void:
	faction_select.visible = false
	game_world.visible     = true
