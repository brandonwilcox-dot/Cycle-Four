## GameOverScreen.gd
## Full-screen overlay shown when the FOB's HP reaches zero.
## Listens for base_destroyed on EventBus -- shows itself, no external calls needed.
## Two options: Try Again (same faction, economy reset) or Return to Menu.
extends Control

@onready var wave_label    : Label  = $Panel/WaveLabel
@onready var try_again_btn : Button = $Panel/TryAgainBtn
@onready var menu_btn      : Button = $Panel/MenuBtn

func _ready() -> void:
	EventBus.base_destroyed.connect(_on_base_destroyed)
	try_again_btn.pressed.connect(_on_try_again_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _on_base_destroyed() -> void:
	wave_label.text = "Wave %d Reached" % WaveManager.current_wave
	show()

func _on_try_again_pressed() -> void:
	## Reset economy to starting values for this faction, clear wave progress,
	## then reload the scene. Main._ready() will skip faction select because
	## GameState.current_faction is still set.
	FactionManager.select_faction(FactionManager.active_faction, FactionManager.active_sub_path)
	WaveManager.reset()
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	## Clear faction so Main._ready() shows the faction select screen.
	GameState.current_faction  = ""
	GameState.current_sub_path = ""
	FactionManager.active_faction  = ""
	FactionManager.active_sub_path = ""
	WaveManager.reset()
	get_tree().reload_current_scene()
