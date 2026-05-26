## EconomyManager.gd
## Handles idle production, offline catch-up, and resource flow.
## Three-layer economy: passive idle, active unit production, tower income.
## All resource reads/writes go through here -- nothing touches resources directly.
extends Node

# Tick rate for idle production (seconds)
const IDLE_TICK_RATE: float = 1.0

# Resource pools -- keyed by resource id (e.g. "energy", "biomass", "signal")
var resources: Dictionary = {}
var production_rates: Dictionary = {}   # per-second rates
var storage_caps: Dictionary = {}       # max storage per resource

var _tick_accumulator: float = 0.0
var _last_save_timestamp: int = 0

func _ready() -> void:
	_initialize_resources()

func _process(delta: float) -> void:
	if GameState.is_paused:
		return
	_tick_accumulator += delta
	if _tick_accumulator >= IDLE_TICK_RATE:
		_tick_accumulator -= IDLE_TICK_RATE
		_do_idle_tick(IDLE_TICK_RATE)

# -- Public API --

func get_resource(resource_id: String) -> float:
	return resources.get(resource_id, 0.0)

func get_rate(resource_id: String) -> float:
	return production_rates.get(resource_id, 0.0)

func can_afford(costs: Dictionary) -> bool:
	for resource_id in costs:
		if get_resource(resource_id) < costs[resource_id]:
			return false
	return true

func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for resource_id in costs:
		_modify_resource(resource_id, -costs[resource_id])
	return true

func add_resource(resource_id: String, amount: float) -> void:
	_modify_resource(resource_id, amount)

func set_production_rate(resource_id: String, rate: float) -> void:
	production_rates[resource_id] = rate

# -- Offline catch-up --

func apply_offline_time(seconds_elapsed: float) -> void:
	# Cap offline production at 8 hours to prevent runaway accumulation
	var capped: float = min(seconds_elapsed, 8.0 * 3600.0)
	for resource_id in production_rates:
		var gained: float = production_rates[resource_id] * capped
		_modify_resource(resource_id, gained)
	EventBus.offline_catch_up.emit(capped)

# -- Internal --

func _initialize_resources() -> void:
	# Seeded by FactionManager once faction is chosen
	pass

func _do_idle_tick(delta: float) -> void:
	for resource_id in production_rates:
		var gained: float = production_rates[resource_id] * delta
		_modify_resource(resource_id, gained)
	EventBus.idle_tick.emit(delta)

func _modify_resource(resource_id: String, delta_amount: float) -> void:
	var current: float = resources.get(resource_id, 0.0)
	var cap: float = storage_caps.get(resource_id, INF)
	var new_value: float = clamp(current + delta_amount, 0.0, cap)
	resources[resource_id] = new_value
	EventBus.resource_changed.emit(GameState.current_faction, resource_id, new_value)
