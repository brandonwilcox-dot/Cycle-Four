## A cosmetic tracer bolt: travels from a start point to a target point over a
## short lifetime, drawing a bright head plus a tapering trail, then spawns an
## impact spark burst and frees itself. Never applies damage (damage is dealt
## instantly by the firing tower; this is decoration only).
extends Node2D

const SPEED     : float = 1400.0   ## px/s — sets lifetime from distance
const MIN_LIFE  : float = 0.04
const MAX_LIFE  : float = 0.18
const TRAIL_LEN : float = 26.0

var _from  : Vector2
var _to    : Vector2
var _color : Color   = Color.WHITE
var _dir   : Vector2 = Vector2.RIGHT
var _life  : float   = 0.1
var _age   : float   = 0.0
var _done  : bool    = false

func setup(from: Vector2, to: Vector2, color: Color) -> void:
	_from = from
	_to = to
	_color = color
	position = from
	z_index = 55
	var dist : float = from.distance_to(to)
	_life = clamp(dist / SPEED, MIN_LIFE, MAX_LIFE)
	_dir = (to - from).normalized() if dist > 0.01 else Vector2.RIGHT

func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var t : float = clamp(_age / _life, 0.0, 1.0)
	position = _from.lerp(_to, t)
	queue_redraw()
	if _age >= _life:
		_done = true
		Vfx.spark_burst(_to, _color, 8, 140.0)
		queue_free()

func _draw() -> void:
	## Trail behind the head (head sits at local origin).
	var tail : Vector2 = -_dir * TRAIL_LEN
	draw_line(tail, Vector2.ZERO, Color(_color.r, _color.g, _color.b, 0.30), 3.0)
	draw_line(tail * 0.5, Vector2.ZERO, Color(_color.r, _color.g, _color.b, 0.65), 2.0)
	## Bright head.
	draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.95))
	draw_circle(Vector2.ZERO, 6.5, Color(_color.r, _color.g, _color.b, 0.55))
