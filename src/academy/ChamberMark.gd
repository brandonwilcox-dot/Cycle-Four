## ChamberMark.gd — the three-circle trefoil Mark beneath the aperture.
## Each arc is tinted for its faction substrate at low saturation.
extends Node2D

const CIRCLE_RADIUS : float = 52.0
const OFFSET        : float = 38.0

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
		draw_circle(positions[i], CIRCLE_RADIUS, colors[i])
	# Shared centre pip so they read as one symbol.
	draw_circle(Vector2.ZERO, 10.0, Color(0.4, 0.4, 0.45, 0.18))
