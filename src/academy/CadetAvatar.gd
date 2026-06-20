## CadetAvatar.gd — the player's cadet inside the Academy chamber tableau.
## A NON-INTERACTIVE cutscene prop: a gold 32x32 visual, nothing more. The chamber
## (Academy chapters 0 and 2) is a cutscene; the player commands the real Commander
## once the live scenarios begin. The cadet deliberately has no input handler.
##
## (History: it used to have click-to-move, but the screen->local click transform
## through this CanvasLayer-parented Node2D was unstable and produced the "clicking
## the cadet nudges it / it drifts back to centre" bug. Removing the handler is the
## fix. See planning/architecture-north-star.md §4.)
extends Node2D

const AVATAR_SIZE : int = 32
const PIP_SIZE    : int = 8

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var half : int = AVATAR_SIZE / 2
	draw_rect(Rect2(-half, -half, AVATAR_SIZE, AVATAR_SIZE), Color(0.95, 0.78, 0.20))
	var pip_half : int = PIP_SIZE / 2
	draw_rect(Rect2(-pip_half, -pip_half, PIP_SIZE, PIP_SIZE), Color(1.0, 1.0, 1.0))
