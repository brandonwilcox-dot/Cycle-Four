## Wall.gd
## Phase 4B — the Architect passive barrier. A destructible, cell-occupying blocker placed on the
## enemy corridor. It is deliberately NOT added to the enemy path graph (AStar), so enemies path
## straight into it and must DESTROY it to pass — "block paths enemies have to unblock." The Commander
## builds it like any structure (construction state); friendlies + the Commander ignore it (it only
## stops enemies, who grind it down in melee). See commander-and-faction-systems.md (Phase 4B).
extends Node2D

const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")

const MAX_HEALTH   : float = 160.0   ## sturdy enough to be a real speed bump (× Architect health mult)
const START_HEALTH : float = 10.0
const BODY_SIZE    : float = 50.0
const BUILD_BAR_W  : float = 46.0
const BODY_COLOR   : Color = Color(0.55, 0.58, 0.62, 1.0)   ## steel grey — reads as a barrier, not a tower

var _max_health : float     = MAX_HEALTH
var _health     : float     = START_HEALTH
var _built      : bool      = false
var _is_dead    : bool      = false
var _build_bar  : ColorRect = null

func _ready() -> void:
	add_to_group("walls")
	## Architects build sturdier (faction health multiplier). Placed UNBUILT — the Commander constructs it.
	_max_health = MAX_HEALTH * FACTION_PERKS.health_mult(FactionManager.active_faction)
	_health     = START_HEALTH
	_built      = false
	_build_visual()
	_refresh_build_visual()

func is_built() -> bool:
	return _built

## [Persistence] Restore a saved wall as already built (full HP, functional) — like towers/garrisons.
func mark_built() -> void:
	_health = _max_health
	_built  = true
	_refresh_build_visual()

func needs_engineering() -> bool:
	return _health < _max_health

## Commander construction / repair (same contract as Tower/Building, so the engineering pass builds it).
func receive_engineering(amount: float) -> bool:
	if _health >= _max_health:
		return false
	_health = minf(_max_health, _health + amount)
	if not _built and _health >= _max_health:
		_built = true
		EventBus.notification_pushed.emit("Wall raised.", "positive")
	_refresh_build_visual()
	return true

## Enemy melee damages a BUILT wall (flat — structures ignore the unit triangle). Returns killed,
## matching the take_damage contract enemy melee uses on any blocker.
func take_damage(amount: float, _damage_type: int = -1) -> bool:
	if _is_dead:
		return true
	_health = maxf(0.0, _health - amount)
	_refresh_build_visual()
	if _health <= 0.0:
		_is_dead = true
		queue_free()
		return true
	return false

func _build_visual() -> void:
	var half : float = BODY_SIZE * 0.5

	var border := ColorRect.new()
	border.size     = Vector2(BODY_SIZE + 4.0, BODY_SIZE + 4.0)
	border.position = Vector2(-half - 2.0, -half - 2.0)
	border.color    = BODY_COLOR.darkened(0.5)
	add_child(border)

	var body := ColorRect.new()
	body.size     = Vector2(BODY_SIZE, BODY_SIZE)
	body.position = Vector2(-half, -half)
	body.color    = BODY_COLOR
	add_child(body)

	## A couple of darker seams so it reads as a brick/blast wall, not a flat tile.
	for sy in [-half + 14.0, half - 18.0]:
		var seam := ColorRect.new()
		seam.size     = Vector2(BODY_SIZE, 4.0)
		seam.position = Vector2(-half, sy)
		seam.color    = BODY_COLOR.darkened(0.35)
		add_child(seam)

	## Construction / damage bar.
	_build_bar = ColorRect.new()
	_build_bar.size     = Vector2(BUILD_BAR_W, 4.0)
	_build_bar.position = Vector2(-BUILD_BAR_W * 0.5, half + 4.0)
	_build_bar.color    = Color(0.45, 1.0, 0.7, 0.95)
	add_child(_build_bar)

	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_build_visual() -> void:
	var frac : float = clampf(_health / _max_health, 0.0, 1.0)
	if _build_bar != null:
		_build_bar.visible = _health < _max_health   ## show while building or damaged
		_build_bar.size.x  = BUILD_BAR_W * frac
	modulate = Color(1, 1, 1, 1) if _built else Color(0.6, 0.85, 1.0, 0.5)
