## WaveSpawner.gd
## Attached to the WorldMap scene. Reads the active WaveTable and spawns
## Unit instances onto the Path2D at the correct intervals.
## Listens to WaveManager signals; never drives the wave state itself.
extends Node

const WaveTableClass = preload("res://src/core/waves/WaveTable.gd")

## Assigned in the WorldMap scene inspector
@export var unit_path: Path2D = null
@export var unit_scene: PackedScene = null

## Active wave table -- loaded when faction is confirmed
var _wave_table: Resource = null   ## WaveTable instance; typed as Resource to avoid load-order issues
var _spawn_timer: float = 0.0
var _units_to_spawn: int = 0
var _current_unit_data: UnitData = null
var _spawn_interval: float = 1.0
var _spawning: bool = false

func _ready() -> void:
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)

func _process(delta: float) -> void:
	if not _spawning or _units_to_spawn <= 0:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_unit()
		_units_to_spawn -= 1
		_spawn_timer = _spawn_interval
		if _units_to_spawn <= 0:
			_spawning = false

## -- Signal handlers --

func _on_faction_selected(faction_id: String, _sub_path: String) -> void:
	var path: String = "res://resources/factions/%s/wave_table.tres" % faction_id
	if ResourceLoader.exists(path):
		_wave_table = load(path)
	else:
		_wave_table = null  ## Procedural fallback handled by WaveManager

func _on_wave_started(wave_number: int, _commander_data: Dictionary) -> void:
	if _wave_table == null:
		_start_procedural_wave(wave_number)
		return
	var wave_def: Dictionary = _wave_table.get_wave(wave_number)
	_current_unit_data = wave_def.get("unit", null)
	_units_to_spawn    = int(wave_def.get("count", 5 + wave_number * 2))
	_spawn_interval    = float(wave_def.get("interval", 1.2))
	_spawn_timer       = 0.0
	_spawning          = true

func _on_wave_ended(_wave_number: int, _result: String) -> void:
	_spawning = false
	_units_to_spawn = 0

## -- Spawn logic --

func _spawn_unit() -> void:
	if unit_path == null or unit_scene == null:
		push_error("WaveSpawner: unit_path or unit_scene not set.")
		return
	var unit: PathFollow2D = unit_scene.instantiate()
	if unit.has_method("setup") and _current_unit_data != null:
		unit.call("setup", _current_unit_data)
	unit_path.add_child(unit)
	unit.progress = 0.0
	EventBus.unit_spawned.emit({
		"unit": _current_unit_data.unit_name if _current_unit_data else "unknown",
		"wave": WaveManager.current_wave,
	})

func _start_procedural_wave(wave_number: int) -> void:
	## No wave table: synthesise a minimal UnitData so units are visible and move.
	var fallback := UnitData.new()
	fallback.unit_name        = "Remnant"
	fallback.faction_id       = "unknown"
	fallback.tier             = 1
	fallback.max_health       = 40.0 + wave_number * 10.0
	fallback.move_speed       = 80.0
	fallback.damage_on_arrival = 1.0
	fallback.armor            = 0.0
	fallback.resource_reward  = 1.0
	fallback.color_hint       = Color(0.6, 0.6, 0.6, 1.0)
	_current_unit_data = fallback
	_units_to_spawn    = 5 + wave_number * 2
	_spawn_interval    = 1.2
	_spawn_timer       = 0.0
	_spawning          = true
