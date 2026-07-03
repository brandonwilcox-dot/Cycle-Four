## ChamberMark.gd — the three-circle trefoil Mark beneath the aperture.
## Each arc is tinted for its faction substrate at low saturation.
## V5.0: the Mark BREATHES — a slow, out-of-phase glow per circle, as if each substrate
## remembers on its own rhythm. Subtle; the symbol must stay understated (earned, not shown).
extends Node2D

const CIRCLE_RADIUS : float = 52.0
const OFFSET        : float = 38.0
const BREATH_PERIOD : float = 9.0    ## seconds per glow cycle — patient, subsonic

var _t : float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var positions : Array[Vector2] = [
		Vector2(-OFFSET, OFFSET * 0.6),   # Architect amber
		Vector2(OFFSET,  OFFSET * 0.6),   # Bloom green
		Vector2(0.0,    -OFFSET * 0.9),   # Mesh blue
	]
	var colors : Array[Color] = [
		Color(0.45, 0.32, 0.12, 0.25),    # amber, very low sat
		Color(0.22, 0.38, 0.18, 0.25),    # green, very low sat
		Color(0.15, 0.28, 0.40, 0.25),    # blue, very low sat
	]
	for i in 3:
		## Each circle breathes on its own phase; alpha swells ~±40% around the base.
		var breath : float = 1.0 + 0.4 * sin(_t * TAU / BREATH_PERIOD + float(i) * TAU / 3.0)
		var col : Color = colors[i]
		col.a *= breath
		draw_circle(positions[i], CIRCLE_RADIUS, col)
		## Faint halo — the glow escaping the circle at the top of its breath.
		var halo : Color = Color(col.r, col.g, col.b, col.a * 0.35 * maxf(0.0, breath - 1.0) * 2.5)
		if halo.a > 0.003:
			draw_arc(positions[i], CIRCLE_RADIUS + 6.0, 0.0, TAU, 48, halo, 4.0, true)
	# Shared centre pip so they read as one symbol.
	draw_circle(Vector2.ZERO, 10.0, Color(0.4, 0.4, 0.45, 0.18))
