## RankChevrons.gd
## Small row of chevrons drawn above a unit to show its veterancy rank/level at a
## glance (StarCraft/C&C style). Add as a child of any entity and call set_rank(n)
## whenever the rank changes. Visibility cascades from the parent, so fog hiding works.
class_name RankChevrons
extends Node2D

const CHEVRON_W : float = 7.0
const CHEVRON_H : float = 5.0
const GAP       : float = 2.0
const MAX_SHOWN : int   = 6     ## past this, chevrons turn gold→cyan and restart the count
const COLOR_LOW : Color = Color(1.00, 0.85, 0.30, 0.95)   ## gold (ranks 1–MAX_SHOWN)
const COLOR_HI  : Color = Color(0.45, 0.85, 1.00, 0.95)   ## cyan (ranks beyond MAX_SHOWN)
const OUTLINE   : Color = Color(0.12, 0.09, 0.00, 0.90)

var _rank : int = 0

func set_rank(r: int) -> void:
	if r == _rank:
		return
	_rank = r
	queue_redraw()

func _draw() -> void:
	if _rank <= 0:
		return
	## Wrap every MAX_SHOWN: ranks 1–6 show 1–6 gold chevrons; 7–12 show 1–6 cyan; etc.
	@warning_ignore("integer_division")
	var tier  : int   = (_rank - 1) / MAX_SHOWN
	var shown : int   = _rank - tier * MAX_SHOWN
	var col   : Color = COLOR_HI if tier % 2 == 1 else COLOR_LOW
	var total_w : float = shown * CHEVRON_W + (shown - 1) * GAP
	var x0 : float = -total_w * 0.5
	for i in shown:
		_draw_chevron(x0 + i * (CHEVRON_W + GAP), col)

func _draw_chevron(cx: float, col: Color) -> void:
	## Upward-pointing filled triangle with a dark outline.
	var p := PackedVector2Array([
		Vector2(cx, 0.0),
		Vector2(cx + CHEVRON_W * 0.5, -CHEVRON_H),
		Vector2(cx + CHEVRON_W, 0.0),
	])
	draw_colored_polygon(p, col)
	draw_polyline(PackedVector2Array([p[0], p[1], p[2], p[0]]), OUTLINE, 1.0)
