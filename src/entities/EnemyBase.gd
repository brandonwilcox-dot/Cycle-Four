## EnemyBase.gd
## A destructible enemy stronghold that anchors a wave spawn (one per active spawn).
## While it stands: its spawn keeps emitting waves AND projects the no-fire + no-build DMZ.
## It is destroyed by the ARMY — the Commander and friendly garrison units assault it via
## take_damage() (towers can't, by design: the no-fire DMZ keeps them off the spawn mouth).
## On death it emits EventBus.enemy_base_destroyed(spawn_id); Battle seals the spawn (so it
## stops emitting and its DMZ lifts) and ObjectiveManager ticks the DESTROY_BASES objective.
##
## Conquest keystone — see planning/territory-conquest-plan.md (Phase 1).
extends Node2D

## Tuned so a single Commander poke can't crack it — taking a base is an army push.
## Commander primary ≈ 20 dps at rank 0; a few garrison units bring it down faster. Tunable.
const MAX_HEALTH : float = 500.0

const BODY_SIZE   : float = 52.0   ## larger than towers (44-56) / units (16-24) so it reads as a base
const BODY_COLOR  : Color = Color(0.72, 0.12, 0.12, 1.0)   ## crimson — "enemy structure to destroy"
const CORE_COLOR  : Color = Color(1.00, 0.78, 0.20, 1.0)   ## bright core pip

var spawn_id : StringName = &""

var _max_health     : float = MAX_HEALTH
var _current_health : float = MAX_HEALTH
var _is_dead        : bool  = false
var _health_fg      : ColorRect = null

## Called by Battle before adding to the tree. faction is accepted for future theming.
func setup(p_spawn_id: StringName, _faction: String = "") -> void:
	spawn_id = p_spawn_id

func _ready() -> void:
	add_to_group("enemy_bases")
	_build_visual()

## Army damage. Type is ignored (no armor triangle on structures for Phase 1 — flat HP).
## Returns true when this hit destroys the base (matches the Unit/FriendlyUnit contract so
## the Commander's and friendly units' kill bookkeeping works unchanged).
func take_damage(amount: float, _damage_type: int = -1) -> bool:
	if _is_dead:
		return true
	_current_health = maxf(0.0, _current_health - amount)
	_update_health_visual()
	if _current_health <= 0.0:
		_is_dead = true
		EventBus.enemy_base_destroyed.emit(spawn_id)
		queue_free()
		return true
	return false

func _build_visual() -> void:
	var half : float = BODY_SIZE * 0.5

	## Dark border frame.
	var border := ColorRect.new()
	border.size     = Vector2(BODY_SIZE + 6.0, BODY_SIZE + 6.0)
	border.position = Vector2(-half - 3.0, -half - 3.0)
	border.color    = BODY_COLOR.darkened(0.55)
	add_child(border)

	## Main body.
	var body := ColorRect.new()
	body.size     = Vector2(BODY_SIZE, BODY_SIZE)
	body.position = Vector2(-half, -half)
	body.color    = BODY_COLOR
	add_child(body)

	## Bright core pip — marks it as the objective.
	var core := ColorRect.new()
	core.size     = Vector2(16.0, 16.0)
	core.position = Vector2(-8.0, -8.0)
	core.color    = CORE_COLOR
	add_child(core)

	## Health bar above the base.
	var bar_bg := ColorRect.new()
	bar_bg.size     = Vector2(BODY_SIZE, 5.0)
	bar_bg.position = Vector2(-half, -half - 12.0)
	bar_bg.color    = Color(0.12, 0.12, 0.12, 0.9)
	add_child(bar_bg)

	_health_fg          = ColorRect.new()
	_health_fg.size     = Vector2(BODY_SIZE, 5.0)
	_health_fg.position = Vector2(-half, -half - 12.0)
	_health_fg.color    = Color(0.95, 0.35, 0.30, 1.0)
	add_child(_health_fg)

	## World-space Control children must not eat clicks (NEVER_TOUCH: MOUSE_FILTER_IGNORE).
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_health_visual() -> void:
	if _health_fg == null:
		return
	var frac : float = clampf(_current_health / _max_health, 0.0, 1.0)
	_health_fg.size = Vector2(BODY_SIZE * frac, 5.0)
