## An expanding, fading ring (with an optional filled core) used for muzzle
## flashes and death poofs. Self-frees when its lifetime elapses. Cosmetic only.
extends Node2D

var _color  : Color = Color.WHITE
var _max_r  : float = 16.0
var _life   : float = 0.3
var _filled : bool  = false
var _age    : float = 0.0

func setup(at: Vector2, color: Color, max_radius: float, life: float, filled: bool) -> void:
	position = at
	_color = color
	_max_r = max_radius
	_life = max(0.01, life)
	_filled = filled
	z_index = 60

func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t : float = clamp(_age / _life, 0.0, 1.0)
	var r : float = _max_r * t
	var a : float = 1.0 - t
	if _filled:
		draw_circle(Vector2.ZERO, r * 0.7, Color(_color.r, _color.g, _color.b, a * 0.45))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(_color.r, _color.g, _color.b, a), 2.0 + 2.0 * (1.0 - t), true)
