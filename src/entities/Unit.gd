## Unit.gd
## A single enemy unit. Follows the map's Path2D from spawn to base.
## Spawned by WaveSpawner; reports death/arrival back through EventBus.
extends PathFollow2D

## Set by WaveSpawner immediately after instantiation
var data: UnitData = null

var _current_health: float = 0.0
var _is_dead: bool = false
var _visual: ColorRect = null   ## placeholder until sprites exist

func _ready() -> void:
	if data == null:
		push_error("Unit spawned without UnitData -- call setup() before adding to tree.")
		return
	_current_health = data.max_health
	_build_placeholder_visual()

func _process(delta: float) -> void:
	if _is_dead:
		return
	# PathFollow2D.progress moves the node along the Path2D parent
	progress += data.move_speed * delta
	# progress_ratio reaches 1.0 when the unit hits the end of the path
	if progress_ratio >= 1.0:
		_reach_base()

## Called by WaveSpawner to inject data before adding to scene tree
func setup(unit_data: UnitData) -> void:
	data = unit_data

## Apply incoming damage; returns true if unit died
func take_damage(amount: float) -> bool:
	if _is_dead:
		return true
	var effective: float = max(0.0, amount - data.armor)
	_current_health -= effective
	_update_health_visual()
	if _current_health <= 0.0:
		_die()
		return true
	# Bloom evolution check
	if data.evolve_threshold > 0.0:
		var hp_ratio: float = _current_health / data.max_health
		if hp_ratio <= data.evolve_threshold and data.evolved_unit != null:
			_evolve()
	return false

## -- Internal --

func _reach_base() -> void:
	_is_dead = true
	WaveManager.report_base_breached()
	EventBus.base_damaged.emit(data.damage_on_arrival, {"unit": data.unit_name})
	# Give partial resource reward even on breach (unit "spent" effort)
	EconomyManager.add_resource(FactionManager.get_primary_resource(), data.resource_reward * 0.5)
	queue_free()

func _die() -> void:
	_is_dead = true
	WaveManager.report_enemy_killed()
	EconomyManager.add_resource(FactionManager.get_primary_resource(), data.resource_reward)
	EventBus.unit_died.emit({"unit": data.unit_name, "faction": data.faction_id})
	queue_free()

func _evolve() -> void:
	## Swap to evolved unit type in place -- health carries over proportionally
	var hp_ratio: float = _current_health / data.max_health
	data = data.evolved_unit
	_current_health = data.max_health * hp_ratio
	_visual.color = data.color_hint
	_update_health_visual()

func _build_placeholder_visual() -> void:
	## Simple colored rect until sprites are ready.
	## 24x24 square, offset so it centers on the path node.
	_visual = ColorRect.new()
	_visual.size = Vector2(24.0, 24.0)
	_visual.position = Vector2(-12.0, -12.0)
	_visual.color = data.color_hint if data else Color.GRAY
	add_child(_visual)
	## Health bar (thin rect above unit)
	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(24.0, 3.0)
	bar_bg.position = Vector2(-12.0, -18.0)
	bar_bg.color = Color(0.2, 0.2, 0.2)
	add_child(bar_bg)
	var bar_fg := ColorRect.new()
	bar_fg.name = "HealthBar"
	bar_fg.size = Vector2(24.0, 3.0)
	bar_fg.position = Vector2(-12.0, -18.0)
	bar_fg.color = Color(0.2, 0.9, 0.2)
	add_child(bar_fg)

func _update_health_visual() -> void:
	var bar: ColorRect = get_node_or_null("HealthBar")
	if bar and data:
		bar.size.x = 24.0 * (_current_health / data.max_health)
