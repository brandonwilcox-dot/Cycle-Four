## SceneManager.gd -- autoload. Owns the single active "screen" scene and swaps
## between screens with a short fade. The active screen is kept as
## get_tree().current_scene, so this stays compatible with reload_current_scene()
## (GameOverScreen restarts that way).
##
## Stage 1 of the architecture-north-star migration: introduces the swap mechanism
## WITHOUT changing observable behavior -- boot still lands on Title, New Game still
## loads Main. Later stages route Academy / FactionSelect / Battle through here too.
extends Node

## Fade duration each way (seconds). Short -- hides the instantiation hitch.
const FADE_TIME  : float = 0.25
## CanvasLayer layer for the fade overlay -- above all gameplay/UI layers (max used = 10).
const FADE_LAYER : int   = 100

var _fade_layer : CanvasLayer = null
var _fade_rect  : ColorRect   = null
var _busy       : bool        = false

func _ready() -> void:
	## Keep transitions running even if a screen pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_overlay()

## Swap the active screen to the scene at `path`, with a fade-out / free / instance /
## fade-in cycle. Safe to call from a button or signal handler: the actual swap runs
## after the first fade await, i.e. outside the caller's call stack.
func change_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade(0.0, 1.0)
	_swap_now(path)
	await get_tree().process_frame
	await _fade(1.0, 0.0)
	_busy = false

func _swap_now(path: String) -> void:
	var tree := get_tree()
	var old : Node = tree.current_scene
	if old != null and is_instance_valid(old):
		old.free()
	var packed : PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("SceneManager: could not load PackedScene at %s" % path)
		return
	var inst : Node = packed.instantiate()
	tree.root.add_child(inst)
	tree.current_scene = inst

func _fade(from_a: float, to_a: float) -> void:
	_fade_rect.visible = true
	_fade_rect.color = Color(0.0, 0.0, 0.0, from_a)
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", to_a, FADE_TIME)
	await tw.finished
	if to_a <= 0.0:
		_fade_rect.visible = false

func _build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = FADE_LAYER
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## STOP filter eats clicks during the transition; harmless while invisible.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.visible = false
	_fade_layer.add_child(_fade_rect)
