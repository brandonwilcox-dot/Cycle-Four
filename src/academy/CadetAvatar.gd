## CadetAvatar.gd — the player's cadet inside the Academy tableau.
## Trimmed Commander: gold 32x32 visual + click-to-move only.
## No combat, no fog, no rank, no territory claiming.
extends Node2D

const SPEED       : float = 160.0
const AVATAR_SIZE : int   = 32
const PIP_SIZE    : int   = 8

## Set by Academy.gd to the chamber's world-space origin so clicks are correct.
var chamber_origin : Vector2 = Vector2.ZERO

var _target : Vector2 = Vector2.ZERO
var _moving : bool    = false

func _ready() -> void:
	_target = position
	queue_redraw()

func _process(delta: float) -> void:
	if not _moving:
		return
	var dir  : Vector2 = _target - position
	var dist : float   = dir.length()
	if dist < 2.0:
		position = _target
		_moving  = false
		return
	position += dir.normalized() * SPEED * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_click : Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		_target = world_click
		_moving = true

func _draw() -> void:
	var half : int = AVATAR_SIZE / 2
	draw_rect(Rect2(-half, -half, AVATAR_SIZE, AVATAR_SIZE), Color(0.95, 0.78, 0.20))
	var pip_half : int = PIP_SIZE / 2
	draw_rect(Rect2(-pip_half, -pip_half, PIP_SIZE, PIP_SIZE), Color(1.0, 1.0, 1.0))
