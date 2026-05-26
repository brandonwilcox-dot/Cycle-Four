## WaveManager.gd
## Controls the tower defense / endless wave layer.
## Tracks wave state; WaveSpawner handles actual spawning.
extends Node

enum WaveState { IDLE, COUNTDOWN, ACTIVE, RESULTS }

var state: WaveState = WaveState.IDLE
var current_wave: int = 0
var enemies_remaining: int = 0  ## Units still alive or in transit this wave
var countdown_timer: float = 0.0

var _breaches: int = 0          ## Units that reached the base this wave

const WAVE_COUNTDOWN: float = 1.0   ## Seconds between waves (keep short during dev)

func _ready() -> void:
	EventBus.wave_ended.connect(_on_wave_ended)

func _process(delta: float) -> void:
	if state == WaveState.COUNTDOWN:
		countdown_timer -= delta
		if countdown_timer <= 0.0:
			_start_next_wave()

# -- Public API --

func begin_waves() -> void:
	## Accept both IDLE and RESULTS so a player press during the post-wave
	## grace period isn't silently dropped and doesn't soft-lock the HUD button.
	## The _on_wave_ended await will find state != RESULTS and do nothing.
	if state not in [WaveState.IDLE, WaveState.RESULTS]:
		return
	state = WaveState.COUNTDOWN
	countdown_timer = WAVE_COUNTDOWN

## Called by Unit when it reaches the end of the path.
func report_base_breached() -> void:
	_breaches += 1
	enemies_remaining -= 1
	_check_wave_complete()

## Called by Unit when it is killed (health reaches zero).
func report_enemy_killed() -> void:
	enemies_remaining -= 1
	_check_wave_complete()

func get_wave_data(wave_number: int) -> Dictionary:
	return FactionManager.get_wave_data(wave_number)

# -- Internal --

func _check_wave_complete() -> void:
	## End the wave only when every spawned unit is accounted for.
	if state != WaveState.ACTIVE:
		return
	if enemies_remaining <= 0:
		_end_wave(_breaches == 0)

func _start_next_wave() -> void:
	current_wave += 1
	_breaches = 0
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
	## Wait briefly then return to IDLE so the player must press Begin Waves again.
	## Auto-advancing waves will be a toggle once difficulty tuning is in place.
	await get_tree().create_timer(3.0).timeout
	if state == WaveState.RESULTS:
		state = WaveState.IDLE
