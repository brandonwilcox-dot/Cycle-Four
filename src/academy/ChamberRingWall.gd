## ChamberRingWall.gd — caldera rim ring around the chamber floor.
extends Node2D

const INNER_RADIUS : float = 390.0
const OUTER_RADIUS : float = 460.0
const SEGMENTS     : int   = 64

func _draw() -> void:
	var ring_color : Color = Color(0.10, 0.12, 0.14, 1.0)
	var step : float = TAU / float(SEGMENTS)
	for i in SEGMENTS:
		var a0 : float = i * step
		var a1 : float = (i + 1) * step
		var pts : PackedVector2Array = PackedVector2Array([
			Vector2(cos(a0), sin(a0)) * INNER_RADIUS,
			Vector2(cos(a1), sin(a1)) * INNER_RADIUS,
			Vector2(cos(a1), sin(a1)) * OUTER_RADIUS,
			Vector2(cos(a0), sin(a0)) * OUTER_RADIUS,
		])
		draw_colored_polygon(pts, ring_color)
