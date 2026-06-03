## ChamberFloor.gd — chamber floor disc with subsonic pulse.
extends Node2D

const FLOOR_RADIUS : float = 380.0
const PULSE_PERIOD : float = 6.0

var _t : float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse_alpha : float = 0.10 + 0.04 * sin(_t * TAU / PULSE_PERIOD)
	draw_circle(Vector2.ZERO, FLOOR_RADIUS, Color(0.15, 0.18, 0.22, pulse_alpha))
