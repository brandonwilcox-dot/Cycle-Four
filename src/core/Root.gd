## Root.gd -- the boot scene (run/main_scene). Its only job is to hand off to the
## SceneManager, which owns the active screen from here on. No game logic lives here.
## Part of the architecture-north-star migration (Stage 1).
extends Node

const TITLE_SCENE : String = "res://scenes/ui/TitleScreen.tscn"

func _ready() -> void:
	SceneManager.change_to(TITLE_SCENE)
