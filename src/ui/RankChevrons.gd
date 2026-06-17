## RankChevrons.gd
## Compact veterancy insignia drawn above a unit. Low ranks show small chevrons;
## every PER_STAR ranks collapse into a single "star" pip so high ranks stay compact
## (rank 9 = 3 stars, not 9 triangles). Colour escalates gold → cyan past STARS_PER_COLOR.
## Add as a child of any entity and call set_rank(n) when the rank changes. Visibility
## cascades from the parent, so fog hiding works.
class_name RankChevrons
extends Node2D

const CHEVRON_W : float = 7.0
const CHEVRON_H : float = 5.0
const STAR_R    : float = 4.0    ## half-size of a "star" pip
const GAP       : float = 2.0
const PER_STAR  : int   = 3      ## ranks collapsed into one star pip
const STARS_PER_COLOR : int = 3  ## stars before the colour flips gold↔cyan
const COLOR_LOW : Color = Color(1.00, 0.85, 0.30, 0.95)   ## gold
const COLOR_HI  : Color = Color(0.45, 0.85, 1.00, 0.95)   ## cyan
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
	@warning_ignore("integer_division")
	var stars : int = _rank / PER_STAR
	var chevs : int = _rank % PER_STAR
	var n     : int = stars + chevs
	if n == 0:
		return
	## Lay symbols left-to-right (stars first, then remainder chevrons), centred.
	var star_w  : float = STAR_R * 2.0
	var total_w : float = stars * star_w + chevs * CHEVRON_W + float(n - 1) * GAP
	var x : float = -total_w * 0.5
	for i in stars:
		@warning_ignore("integer_division")
		var band : int = i / STARS_PER_COLOR
		var col : Color = COLOR_HI if band % 2 == 1 else COLOR_LOW
		_draw_star(x + STAR_R, col)
		x += star_w + GAP
	for _i in chevs:
		_draw_chevron(x, COLOR_LOW)
		x += CHEVRON_W + GAP

## Filled diamond pip centred on cx, sitting just above the baseline.
func _draw_star(cx: float, col: Color) -> void:
	var p := PackedVector2Array([
		Vector2(cx,          -STAR_R * 2.0),
		Vector2(cx + STAR_R, -STAR_R),
		Vector2(cx,           0.0),
		Vector2(cx - STAR_R, -STAR_R),
	])
	draw_colored_polygon(p, col)
	draw_polyline(PackedVector2Array([p[0], p[1], p[2], p[3], p[0]]), OUTLINE, 1.0)

## Upward-pointing filled triangle with a dark outline (left edge at cx).
func _draw_chevron(cx: float, col: Color) -> void:
	var p := PackedVector2Array([
		Vector2(cx, 0.0),
		Vector2(cx + CHEVRON_W * 0.5, -CHEVRON_H),
		Vector2(cx + CHEVRON_W, 0.0),
	])
	draw_colored_polygon(p, col)
	draw_polyline(PackedVector2Array([p[0], p[1], p[2], p[0]]), OUTLINE, 1.0)
