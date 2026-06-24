## FriendlyUnit.gd
## Phase C (C1) — a friendly army unit produced by a garrison. Holds/defends near its home
## garrison (leashed so it guards its territory rather than chasing across the map), acquires
## nearby enemy wave units, and fires on them through the damage/armor triangle using its own
## faction's signature damage type. Takes attrition from adjacent enemies and dies — a real
## combat trade, per core/17 ("dies fast… buys the heavier unit three seconds").
##
## Mirrors the enemy Unit.gd shape (Node2D + placeholder visual + take_damage). The behavior
## is factored into update(delta) so the future offline simulation (C4) can fast-forward it
## headlessly. Movement is direct for C1 (the leash keeps units local on open ground);
## proper friendly pathfinding is a later refinement.
extends Node2D

const Combat = preload("res://src/combat/Combat.gd")

## Aggro / leash tuning (px). The unit engages enemies within AGGRO_RADIUS, but never
## commits past MAX_LEASH from its home garrison, then returns home when nothing's in reach.
const AGGRO_RADIUS    : float = 240.0
const MAX_LEASH       : float = 220.0
const BLOCK_RANGE     : float = 28.0   ## close to this of a foe to body-block it (stops its advance)
const ARRIVE_DIST     : float = 4.0
## Patrol: idle units roam a slow loop around home once the garrison fields enough of them,
## so the army covers ground and meets enemies further out instead of clustering on the building.
const PATROL_RADIUS        : float = 120.0
const PATROL_ANGULAR_SPEED : float = 0.6   ## radians/sec around the loop

var data       : UnitData = null
var _home       : Vector2  = Vector2.ZERO
var _faction    : String   = ""
var _current_health : float = 0.0
var _attack_timer   : float = 0.0
var _is_dead        : bool  = false
var _visual         : ColorRect = null
var _garrison       : Node    = null    ## producing garrison, for kill-XP reporting
var _patrolling     : bool    = false
var _patrol_angle   : float   = 0.0
var _has_raid       : bool    = false   ## C3: marching to claim a frontier cell
var _raid_target    : Vector2 = Vector2.ZERO

## Called by the garrison before adding to the scene tree. home_world is the guard anchor;
## garrison is the producing Building (kept for kill-XP reporting).
func setup(unit_data: UnitData, home_world: Vector2, garrison: Node = null) -> void:
	data      = unit_data
	_home     = home_world
	_garrison = garrison
	position  = home_world
	_patrol_angle = randf() * TAU   ## stagger phase so a squad spreads around the loop
	if data != null:
		_current_health = data.max_health

func _ready() -> void:
	add_to_group("friendly_units")
	if data == null:
		push_error("FriendlyUnit spawned without UnitData -- call setup() first.")
		return
	_faction = FactionManager.active_faction
	_build_visual()

func _process(delta: float) -> void:
	if _is_dead:
		return
	update(delta)

## Tick logic, separated from _process so the offline sim can drive it at an accelerated rate.
func update(delta: float) -> void:
	if data == null:
		return
	_attack_timer += delta

	var target : Node2D = _acquire_target()
	if target != null:
		var dist : float = global_position.distance_to(target.global_position)
		## Close in to body-block the foe (this is what stops its advance), then fire.
		if dist > BLOCK_RANGE:
			_move_toward(target.global_position, delta)
		if dist <= data.attack_range and _attack_timer >= data.attack_interval:
			_attack_timer = 0.0
			_fire(target)
	elif _has_raid:
		## On a raid: march to the frontier target to claim it (leash released so the
		## party can reach beyond its normal guard radius). Defense above still preempts this.
		_move_toward(_raid_target, delta, false)
	elif _patrolling:
		_patrol(delta)
	elif global_position.distance_to(_home) > ARRIVE_DIST:
		## Idle and too few for a patrol — return to the guard post.
		_move_toward(_home, delta)

## Nearest detectable enemy within AGGRO_RADIUS whose position is still within our leash of
## home (so we defend our patch instead of being kited away). Null if none.
func _acquire_target() -> Node2D:
	var best      : Node2D = null
	var best_dist : float  = AGGRO_RADIUS
	for enemy in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if enemy.has_method("is_detectable") and not enemy.call("is_detectable"):
			continue
		var e : Node2D = enemy as Node2D
		if e.global_position.distance_to(_home) > MAX_LEASH:
			continue
		var d : float = global_position.distance_to(e.global_position)
		if d <= best_dist:
			best      = e
			best_dist = d
	## Conquest: garrison units also assault enemy bases within their leash, so a garrison built
	## forward near a spawn helps the Commander take that base (army-only — towers can't, by DMZ).
	for base in get_tree().get_nodes_in_group("enemy_bases"):
		if not is_instance_valid(base) or not (base is Node2D):
			continue
		var b : Node2D = base as Node2D
		if b.global_position.distance_to(_home) > MAX_LEASH:
			continue
		var bd : float = global_position.distance_to(b.global_position)
		if bd <= best_dist:
			best      = b
			best_dist = bd
	return best

func _fire(target: Node2D) -> void:
	if not target.has_method("take_damage"):
		return
	var killed : bool = bool(target.call("take_damage", data.attack_damage, Combat.faction_damage_type(_faction)))
	if killed and is_instance_valid(_garrison) and _garrison.has_method("report_kill"):
		_garrison.call("report_kill")

## Idle patrol: roam a slow circular loop around the garrison. Enabled by the garrison once
## it fields enough units (Building drives set_patrol on its squad each production tick).
func _patrol(delta: float) -> void:
	_patrol_angle += PATROL_ANGULAR_SPEED * delta
	var point : Vector2 = _home + Vector2(cos(_patrol_angle), sin(_patrol_angle)) * PATROL_RADIUS
	_move_toward(point, delta)

func set_patrol(value: bool) -> void:
	_patrolling = value

## C3 raids: the garrison points its squad at a frontier cell to claim. Raiding overrides
## patrol/guard but NOT defense — an acquired enemy still takes priority in update().
func set_raid_target(world: Vector2) -> void:
	_raid_target = world
	_has_raid    = true

func clear_raid() -> void:
	_has_raid = false

## Move toward a world point. By default clamps within MAX_LEASH of home (guard/patrol);
## raids pass clamp_leash=false so the party can march out to claim distant frontier ground.
func _move_toward(point: Vector2, delta: float, clamp_leash: bool = true) -> void:
	var step : float = data.move_speed * delta
	var dir  : Vector2 = point - global_position
	if dir.length() <= step:
		global_position = point
	else:
		global_position += dir.normalized() * step
	if clamp_leash:
		var from_home : Vector2 = global_position - _home
		if from_home.length() > MAX_LEASH:
			global_position = _home + from_home.normalized() * MAX_LEASH

## Typed damage (future: enemies firing back). Applies the triangle vs our armor_type.
func take_damage(amount: float, damage_type: int = -1) -> bool:
	var mult : float = Combat.multiplier(damage_type, data.armor_type) if damage_type >= 0 else 1.0
	_apply_damage(max(0.0, amount * mult - data.armor))
	return _is_dead

## Flat HP loss + death check. Used by attrition and (via take_damage) by typed hits.
func _apply_damage(flat: float) -> void:
	if _is_dead:
		return
	_current_health -= flat
	_update_health_visual()
	if _current_health <= 0.0:
		_is_dead = true
		queue_free()

## -- Visual: small faction-colored square with a bright friendly ring + health bar. --

func _build_visual() -> void:
	var ring := ColorRect.new()
	ring.size     = Vector2(22.0, 22.0)
	ring.position = Vector2(-11.0, -11.0)
	ring.color    = Color(0.85, 0.95, 1.0, 0.9)   ## friendly marker (vs plain enemy squares)
	add_child(ring)

	_visual          = ColorRect.new()
	_visual.size     = Vector2(16.0, 16.0)
	_visual.position = Vector2(-8.0, -8.0)
	_visual.color    = data.color_hint if data != null else Color.CYAN
	add_child(_visual)

	var bar_bg := ColorRect.new()
	bar_bg.size     = Vector2(20.0, 3.0)
	bar_bg.position = Vector2(-10.0, -15.0)
	bar_bg.color    = Color(0.15, 0.15, 0.15)
	add_child(bar_bg)

	var bar_fg := ColorRect.new()
	bar_fg.name     = "HealthBar"
	bar_fg.size     = Vector2(20.0, 3.0)
	bar_fg.position = Vector2(-10.0, -15.0)
	bar_fg.color    = Color(0.45, 0.85, 1.0)
	add_child(bar_fg)

	## Decorative Controls must not eat world clicks (default MOUSE_FILTER_STOP
	## would consume LMB before it reaches selection/placement handlers).
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _update_health_visual() -> void:
	var bar : ColorRect = get_node_or_null("HealthBar")
	if bar != null and data != null and data.max_health > 0.0:
		bar.size.x = 20.0 * clampf(_current_health / data.max_health, 0.0, 1.0)
