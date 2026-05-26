## Base.gd
## The player's Forward Operating Base. Militarised starting position --
## an always-on turret provides early-wave defense. Cannot be moved or sold.
## Damage tracking and upgrade paths deferred until HP / upgrade systems land.
## Design ref: core/17_units-maps-buildings.md (FOB concept)
extends Node2D

## Turret stats -- strong enough to handle early waves solo, not trivial past wave 5.
const RANGE: float        = 200.0  ## pixels
const DAMAGE: float       = 14.0   ## per shot
const ATTACK_SPEED: float = 1.2    ## shots per second

var _attack_timer: float = 0.0

func _ready() -> void:
	add_to_group("base")
	_build_visual()

func _process(delta: float) -> void:
	_attack_timer += delta
	if _attack_timer >= 1.0 / ATTACK_SPEED:
		_attack_timer = 0.0
		_try_attack()

## -- Combat --

func _try_attack() -> void:
	var nearest: Node    = null
	var nearest_dist: float = RANGE
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var dist: float = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest      = unit
	if nearest != null and nearest.has_method("take_damage"):
		nearest.take_damage(DAMAGE)

## -- Visual --

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
