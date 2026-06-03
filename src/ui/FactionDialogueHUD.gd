## FactionDialogueHUD.gd
## Listens for key game events and pushes a faction-voiced one-liner notification toast.
## Each event fires at most once per run (guarded by _fired dictionary).
## Attach as a Node child of Main; requires FactionManager autoload.
extends Node

const _FACTION_DIALOGUE = preload("res://src/core/FactionDialogue.gd")

## Guards each event key so each one-liner fires only once per run.
var _fired : Dictionary = {}

func _ready() -> void:
	EventBus.convoy_arrived.connect(_on_convoy_arrived)
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.wave_flank_triggered.connect(_on_wave_flank_triggered)
	EventBus.subpath_committed.connect(_on_subpath_committed)

func _push(event_key: StringName) -> void:
	if _fired.get(event_key, false):
		return
	var line : String = _FACTION_DIALOGUE.get_line(event_key, FactionManager.active_faction)
	if line.is_empty():
		return
	_fired[event_key] = true
	EventBus.notification_pushed.emit(line, "info")

func _on_convoy_arrived(_convoy_id: StringName, _to_node: StringName, _cargo: float) -> void:
	_push(&"convoy_arrived")

func _on_unit_died(_unit_data: Dictionary) -> void:
	_push(&"unit_died")

func _on_wave_flank_triggered(_wave_number: int) -> void:
	_push(&"wave_flank")

func _on_subpath_committed(_sub_path: String) -> void:
	_push(&"subpath_committed")
