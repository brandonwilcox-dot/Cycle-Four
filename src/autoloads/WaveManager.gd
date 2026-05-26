## WaveManager.gd
## Controls the tower defense / endless wave layer.
## Spawns enemies, tracks wave state, handles commander dialogue triggers.
extends Node

enum WaveState { IDLE, COUNTDOWN, ACTIVE, RESULTS }

var state: WaveState = WaveState.IDLE
var current_wave: int = 0
var enemies_remaining: int = 0
var countdown_timer: float = 0.0

const WAVE_COUNTDOWN: float = 5.0   # seconds between waves

signal _spawn_timer_done()

func _ready() -> void:
	EventBus.wave_ended.connect(_on_wave_ended)

func _process(delta: float) -> void:
	if state == WaveState.COUNTDOWN:
		countdown_timer -= delta
		if countdown_timer <= 0.0:
			_start_next_wave()

# -- Public API --

func begin_waves() -> void:
	if state != WaveState.IDLE:
		return
	state = WaveState.COUNTDOWN
	countdown_timer = WAVE_COUNTDOWN

func get_wave_data(wave_number: int) -> Dictionary:
	## Returns spawn list and commander info for a given wave.
	## Delegates to faction-specific wave table.
	return FactionManager.get_wave_data(wave_number)

func report_enemy_killed() -> void:
	enemies_remaining -= 1
	if enemies_remaining <= 0:
		_end_wave(true)

func report_base_breached() -> void:
	_end_wave(false)

# -- Internal --

func _start_next_wave() -> void:
	current_wave += 1
	GameState.wave_number = current_wave
	var data: Dictionary = get_wave_data(current_wave)
	enemies_remaining = data.get("enemy_count", 0)
	state = WaveState.ACTIVE
	EventBus.wave_started.emit(current_wave, data.get("commander", {}))

func _end_wave(victory: bool) -> void:
	state = WaveState.RESULTS
	var result: String = "victory" if victory else "defeat"
	EventBus.wave_ended.emit(current_wave, result)

func _on_wave_ended(_wave_num: int, _result: String) -> void:
	await get_tree().create_timer(3.0).timeout
	state = WaveState.COUNTDOWN
	countdown_timer = WAVE_COUNTDOWN
