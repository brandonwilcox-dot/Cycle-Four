## ProgressionBar.gd
## Phase 9 — small horizontal bar showing 0–100% progress toward the next rank/level.
## Add as a child of any entity that wants visible progression feedback; call
## set_progress(value) whenever the underlying value changes (value in [0.0, 1.0]).
## Visibility cascades from the parent, so fog hiding works automatically.
class_name ProgressionBar
extends Node2D

const WIDTH      : float = 36.0
const HEIGHT     : float = 3.0
const BG_COLOR   : Color = Color(0.10, 0.10, 0.15, 0.70)
const FILL_COLOR : Color = Color(0.40, 0.85, 0.40, 1.00)

var _bg   : ColorRect = null
var _fill : ColorRect = null

func _ready() -> void:
	_bg          = ColorRect.new()
	_bg.size     = Vector2(WIDTH, HEIGHT)
	_bg.position = Vector2(-WIDTH * 0.5, 0.0)
	_bg.color    = BG_COLOR
	add_child(_bg)
	_fill          = ColorRect.new()
	_fill.size     = Vector2(0.0, HEIGHT)
	_fill.position = Vector2(-WIDTH * 0.5, 0.0)
	_fill.color    = FILL_COLOR
	add_child(_fill)

func set_progress(value: float) -> void:
	if _fill == null:
		return
	_fill.size.x = WIDTH * clampf(value, 0.0, 1.0)
