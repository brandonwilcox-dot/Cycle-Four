## Base.gd
## The player's Forward Operating Base. Militarised starting position --
## an always-on turret provides early-wave defense. Cannot be moved or sold.
## HP tracks cumulative breach damage; reaching zero emits base_destroyed.
## Design ref: core/17_units-maps-buildings.md (FOB concept)
extends Node2D

## Turret stats -- strong enough to carry early waves solo, challenged past wave 5.
const RANGE        : float = 256.0   ## pixels -- covers ~4 grid cells
const DAMAGE       : float = 18.0    ## per shot
const ATTACK_SPEED : float = 1.5     ## shots per second

## HP -- 300 means 30 breaches at default unit damage (10.0). Tune in balance pass.
const MAX_HP : float = 300.0

var _current_hp    : float     = MAX_HP
var _hp_bar        : ColorRect = null   ## tracked for live updates
var _attack_timer  : float     = 0.0
var _is_destroyed  : bool      = false

func _ready() -> void:
	add_to_group("base")
	_build_visual()
	EventBus.base_damaged.connect(_on_base_damaged)

func _process(delta: float) -> void:
	if _is_destroyed:
		return
	_attack_timer += delta
	if _attack_timer >= 1.0 / ATTACK_SPEED:
		_attack_timer = 0.0
		_try_attack()

## -- Combat --

func _on_base_damaged(amount: float, _attacker_data: Dictionary) -> void:
	if _is_destroyed:
		return
	_current_hp = maxf(0.0, _current_hp - amount)
	_update_hp_bar()
	if _current_hp <= 0.0:
		_is_destroyed = true
		EventBus.base_destroyed.emit()

func _try_attack() -> void:
	var nearest      : Node  = null
	var nearest_dist : float = RANGE
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var dist : float = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest      = unit
	if nearest != null and nearest.has_method("take_damage"):
		nearest.take_damage(DAMAGE)

## -- Visual --

func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.size.x = 80.0 * (_current_hp / MAX_HP)
	var ratio : float = _current_hp / MAX_HP
	if ratio > 0.5:
		_hp_bar.color = Color(0.20, 0.90, 0.20)
	elif ratio > 0.25:
		_hp_bar.color = Color(0.90, 0.70, 0.10)
	else:
		_hp_bar.color = Color(0.90, 0.20, 0.10)

func _build_visual() -> void:
	## Sandbag / concrete outer ring
	var ring := ColorRect.new()
	ring.size     = Vector2(100.0, 100.0)
	ring.position = Vector2(-50.0, -50.0)
	ring.color    = Color(0.30, 0.27, 0.20, 1.0)
	add_child(ring)

	## Main fortified body -- military olive drab
	var body := ColorRect.new()
	body.size     = Vector2(80.0, 80.0)
	body.position = Vector2(-40.0, -40.0)
	body.color    = Color(0.22, 0.32, 0.17, 1.0)
	add_child(body)

	## Corner reinforcement marks (four small squares)
	for corner in [Vector2(-40,-40), Vector2(28,-40), Vector2(-40,28), Vector2(28,28)]:
		var c := ColorRect.new()
		c.size     = Vector2(12.0, 12.0)
		c.position = corner
		c.color    = Color(0.18, 0.18, 0.14, 1.0)
		add_child(c)

	## Turret base -- gun metal
	var turret_base := ColorRect.new()
	turret_base.size     = Vector2(32.0, 32.0)
	turret_base.position = Vector2(-16.0, -16.0)
	turret_base.color    = Color(0.14, 0.14, 0.14, 1.0)
	add_child(turret_base)

	## Turret barrel indicator
	var barrel := ColorRect.new()
	barrel.size     = Vector2(8.0, 22.0)
	barrel.position = Vector2(-4.0, -30.0)
	barrel.color    = Color(0.10, 0.10, 0.10, 1.0)
	add_child(barrel)

	## FOB label
	var label := Label.new()
	label.text     = "FOB"
	label.position = Vector2(-18.0, 34.0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.55, 1.0))
	add_child(label)

	## HP bar background
	var bar_bg := ColorRect.new()
	bar_bg.size     = Vector2(80.0, 6.0)
	bar_bg.position = Vector2(-40.0, 52.0)
	bar_bg.color    = Color(0.20, 0.20, 0.20)
	add_child(bar_bg)

	## HP bar foreground (tracked for live updates)
	_hp_bar          = ColorRect.new()
	_hp_bar.size     = Vector2(80.0, 6.0)
	_hp_bar.position = Vector2(-40.0, 52.0)
	_hp_bar.color    = Color(0.20, 0.90, 0.20)
	add_child(_hp_bar)
