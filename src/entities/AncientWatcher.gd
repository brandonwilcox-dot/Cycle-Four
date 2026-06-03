## AncientWatcher.gd
## Non-combat Ancient unit that appears at milestone. Lerps to a target position over
## WALK_DURATION seconds, pushes a dialogue notification, then removes itself.
## Not in the "units" group — invisible to wave logic and towers.
extends Node2D

const WALK_DURATION : float = 4.0
const RECT_SIZE     : float = 32.0
const ANCIENT_COLOR : Color = Color(0.85, 0.80, 0.55, 1.0)

var _target_pos     : Vector2 = Vector2.ZERO
var _start_pos      : Vector2 = Vector2.ZERO
var _dialogue_line  : String  = ""
var _elapsed        : float   = 0.0
var _delivered      : bool    = false

## Call immediately after adding to the scene tree.
func setup(target: Vector2, dialogue: String) -> void:
	_target_pos    = target
	_start_pos     = global_position
	_dialogue_line = dialogue

func _draw() -> void:
	var half : float = RECT_SIZE * 0.5
	draw_rect(Rect2(-half, -half, RECT_SIZE, RECT_SIZE), ANCIENT_COLOR)

func _process(delta: float) -> void:
	if _delivered:
		return
	_elapsed += delta
	var t : float = clampf(_elapsed / WALK_DURATION, 0.0, 1.0)
	global_position = _start_pos.lerp(_target_pos, t)
	queue_redraw()
	if t >= 1.0:
		_delivered = true
		if not _dialogue_line.is_empty():
			EventBus.notification_pushed.emit(_dialogue_line, "info")
		queue_free()
