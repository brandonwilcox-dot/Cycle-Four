## THROWAWAY SPIKE (not shipped) — 2.5D presentation option.
## Keeps the existing 2D approach (Node2D + _draw) but fakes height: every object is an
## EXTRUDED PRISM (top face + shaded side walls) sitting on a drop shadow, on a vertically
## squashed grid that implies a tilted (~45°) board. Compare against Spike3D.tscn.
extends Node2D

const CENTER     : Vector2 = Vector2(960, 560)
const GROUND_TILT: float   = 0.62          ## vertical squash → tilted-plane illusion
const TOWER_H    : float   = 52.0
const TOWER_R    : float   = 30.0
const UNIT_H     : float   = 18.0
const UNIT_R     : float   = 12.0
const TOWER_COL  : Color   = Color(0.35, 0.6, 1.0)
const UNIT_COL   : Color   = Color(0.95, 0.5, 0.45)

var _units  : Array = []   ## {pos:Vector2, spd:float, phase:float}
var _bolts  : Array = []   ## {from:Vector2, to:Vector2, age:float}
var _fire_t : float = 0.0
var _aim    : float = 0.0

func _ready() -> void:
	for i in 6:
		_units.append({
			"pos": Vector2(360 + i * 60, 150 + i * 35),
			"spd": 46.0 + i * 5.0,
			"phase": float(i) * 0.6,
		})

func _process(delta: float) -> void:
	var nearest : Dictionary = {}
	var nd : float = 1e9
	for u in _units:
		var to_t : Vector2 = CENTER - u.pos
		if to_t.length() > 95.0:
			u.pos += to_t.normalized() * u.spd * delta
		u.phase += delta * 4.0
		var d : float = to_t.length()
		if d < nd:
			nd = d
			nearest = u
	if not nearest.is_empty():
		_aim = (nearest.pos - CENTER).angle()
	_fire_t -= delta
	if _fire_t <= 0.0 and not nearest.is_empty():
		_fire_t = 0.45
		_bolts.append({"from": CENTER - Vector2(0, TOWER_H), "to": nearest.pos - Vector2(0, UNIT_H), "age": 0.0})
	for b in _bolts:
		b.age += delta
	_bolts = _bolts.filter(func(b: Dictionary) -> bool: return b.age < 0.12)
	queue_redraw()

func _draw() -> void:
	_draw_ground()
	## Title.
	draw_string(ThemeDB.fallback_font, Vector2(40, 60),
		"2.5D PRESENTATION SPIKE  —  extruded height + shadows on a tilted board (still pure 2D)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.8, 0.9, 1.0))

	## Draw back-to-front so nearer things overlap farther ones (units sorted by y).
	var sorted_units : Array = _units.duplicate()
	sorted_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	for u in sorted_units:
		if u.pos.y < CENTER.y:
			_draw_unit(u)
	_draw_tower()
	for u in sorted_units:
		if u.pos.y >= CENTER.y:
			_draw_unit(u)

	## Tracers (drawn on top).
	for b in _bolts:
		var a : float = 1.0 - b.age / 0.12
		draw_line(b.from, b.to, Color(1.0, 0.95, 0.6, a), 3.0)
		draw_circle(b.to, 6.0 * a, Color(1, 1, 1, a))

func _draw_ground() -> void:
	var grid : Color = Color(0.30, 0.45, 0.35, 0.5)
	for gx in range(-12, 13):
		var x : float = CENTER.x + gx * 72.0
		draw_line(Vector2(x, CENTER.y - 360.0 * GROUND_TILT), Vector2(x, CENTER.y + 300.0 * GROUND_TILT), grid, 1.0)
	for gy in range(-5, 6):
		var y : float = CENTER.y + gy * 72.0 * GROUND_TILT
		draw_line(Vector2(CENTER.x - 864.0, y), Vector2(CENTER.x + 864.0, y), grid, 1.0)

func _draw_unit(u: Dictionary) -> void:
	var bob : float = sin(u.phase) * 3.0
	_draw_shadow(u.pos, UNIT_R)
	_draw_prism(u.pos - Vector2(0, bob), _square(UNIT_R), UNIT_H, UNIT_COL.lightened(0.15), UNIT_COL.darkened(0.4))

func _draw_tower() -> void:
	_draw_shadow(CENTER, TOWER_R)
	_draw_prism(CENTER, _regular(8, TOWER_R, 0.0), TOWER_H, TOWER_COL.lightened(0.1), TOWER_COL.darkened(0.45))
	## Core gem + barrel on the top face.
	var top : Vector2 = CENTER - Vector2(0, TOWER_H)
	draw_circle(top, TOWER_R * 0.32, Color(1.0, 0.95, 0.6, 0.95))
	draw_circle(top, TOWER_R * 0.18, Color(1, 1, 1, 0.9))
	var dir : Vector2 = Vector2(cos(_aim), sin(_aim) * GROUND_TILT)
	draw_line(top, top + dir * 34.0, TOWER_COL.darkened(0.2), 7.0)
	draw_circle(top + dir * 34.0, 5.0, TOWER_COL.lightened(0.3))

## -- Helpers --

func _draw_shadow(base: Vector2, r: float) -> void:
	draw_colored_polygon(_ellipse(base + Vector2(6, 4), r * 1.1, r * 0.5), Color(0, 0, 0, 0.28))

## Extruded prism: a base polygon raised by `height`, with shaded side walls + a top face.
func _draw_prism(base: Vector2, poly: PackedVector2Array, height: float, top_col: Color, side_col: Color) -> void:
	var n : int = poly.size()
	var bot : PackedVector2Array = PackedVector2Array()
	var top : PackedVector2Array = PackedVector2Array()
	for p in poly:
		bot.append(base + Vector2(p.x, p.y * GROUND_TILT))
		top.append(base + Vector2(p.x, p.y * GROUND_TILT) - Vector2(0, height))
	for i in n:
		var j : int = (i + 1) % n
		draw_colored_polygon(PackedVector2Array([bot[i], bot[j], top[j], top[i]]), side_col)
	draw_colored_polygon(top, top_col)

func _regular(sides: int, radius: float, rot: float) -> PackedVector2Array:
	var pts : PackedVector2Array = PackedVector2Array()
	for i in sides:
		var a : float = rot + TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

func _square(r: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])

func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts : PackedVector2Array = PackedVector2Array()
	for i in 20:
		var a : float = TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
