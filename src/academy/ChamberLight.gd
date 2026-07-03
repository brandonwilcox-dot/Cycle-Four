## ChamberLight.gd — V5.0: the celestial aperture's light, slowly crossing the chamber
## floor (the canon closing image, codex/11 — "the aperture's light slowly moving across
## it"). A soft warm pool on a patient elliptical drift. Purely decorative; no input.
extends Node2D

const DRIFT_PERIOD : float = 48.0   ## seconds per full crossing — patient
const POOL_RADIUS  : float = 150.0

var _t : float = 0.0

func _process(delta: float) -> void:
	_t += delta
	var a : float = _t * TAU / DRIFT_PERIOD
	position = Vector2(cos(a) * 210.0, sin(a * 0.5) * 130.0)
	queue_redraw()

func _draw() -> void:
	## Concentric falloff — warm, like the light on a work surface no one can place.
	for i in 5:
		var r : float = POOL_RADIUS * (1.0 - float(i) * 0.18)
		draw_circle(Vector2.ZERO, r, Color(0.85, 0.78, 0.60, 0.016))
