## Tower.gd
## A placed defense tower. Scans for the nearest unit in range each attack cycle
## and calls take_damage() on it. No projectiles -- instant hit for MVP.
## Visual scales with tier: body grows, pip count matches tier number.
extends Node2D

const TowerDataClass    = preload("res://src/entities/TowerData.gd")
const ProgressionBarScript = preload("res://src/ui/ProgressionBar.gd")

## Phase 9 progression constants. Step-function scaling per the handoff §8.1.
const XP_BASE_THRESHOLD   : float = 50.0   ## XP needed for level 1 → 2
const XP_LEVEL_EXPONENT   : float = 2.0    ## threshold scales as XP_BASE × level^exp
const DAMAGE_PER_LEVEL    : float = 0.15   ## +15% damage per level (multiplicative)

var data: Resource = null   ## TowerData instance
var _attack_timer: float = 0.0

## Phase 9: level + XP. Level is earned through kills, independent of tier (which
## is bought by spending resources). Damage scales multiplicatively per level via
## _damage_multiplier so the shared TowerData resource is never mutated.
var level              : int   = 1
var xp                 : float = 0.0
var xp_to_next         : float = XP_BASE_THRESHOLD
var _damage_multiplier : float = 1.0
var _xp_bar            : Node2D = null   ## ProgressionBar instance

## Called by Main before adding to scene tree.
func setup(tower_data: Resource) -> void:
	data = tower_data

func _ready() -> void:
	add_to_group("towers")
	if data == null:
		push_error("Tower: no TowerData -- call setup() before adding to tree.")
		return
	_build_visual()

func _process(delta: float) -> void:
	if data == null:
		return
	_attack_timer += delta
	if _attack_timer >= 1.0 / data.attack_speed:
		_attack_timer = 0.0
		_try_attack()

## Replaces this tower's data with the next tier and rebuilds the visual in place.
## Called by Main._try_upgrade_tower() after spending the upgrade cost.
func upgrade(next_data: Resource) -> void:
	data = next_data
	## Clear existing child visuals then rebuild.
	for child in get_children():
		child.queue_free()
	_build_visual()

## -- Combat --

func _try_attack() -> void:
	var nearest: Node = null
	var nearest_dist: float = data.range
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var dist: float = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	if nearest != null and nearest.has_method("take_damage"):
		var effective_damage : float = data.damage * _damage_multiplier
		var killed : bool = nearest.take_damage(effective_damage)
		if killed:
			_award_xp_for_kill(nearest)

## Phase 9: XP attribution. Award XP proportional to the killed unit's max health
## (proxy for its value). On crossing xp_to_next, level up — applies a multiplicative
## damage boost and rescales the next threshold by level^XP_LEVEL_EXPONENT.
func _award_xp_for_kill(killed_unit: Node) -> void:
	var unit_data = killed_unit.get("data")
	if unit_data == null:
		return
	var unit_value : float = float(unit_data.get("max_health"))
	if unit_value <= 0.0:
		return
	xp += unit_value
	while xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	_update_xp_bar()

func _update_xp_bar() -> void:
	if _xp_bar != null and xp_to_next > 0.0:
		_xp_bar.set_progress(xp / xp_to_next)

func _level_up() -> void:
	level += 1
	_damage_multiplier = pow(1.0 + DAMAGE_PER_LEVEL, float(level - 1))
	xp_to_next = XP_BASE_THRESHOLD * pow(float(level), XP_LEVEL_EXPONENT)
	EventBus.tower_leveled_up.emit(self, level)

## -- Visual --

func _build_visual() -> void:
	var col      : Color = data.color_hint
	var tier     : int   = int(data.get("tier")) if data.get("tier") else 1
	## Body grows 4 px per tier: T1=48, T2=52, T3=56
	var body_sz  : float = 44.0 + tier * 4.0
	var half     : float = body_sz * 0.5
	var border_sz: float = body_sz + 4.0
	var b_half   : float = border_sz * 0.5

	## Darker border -- reads as distinct from units
	var border := ColorRect.new()
	border.size     = Vector2(border_sz, border_sz)
	border.position = Vector2(-b_half, -b_half)
	border.color    = col.darkened(0.5)
	add_child(border)

	## Main body -- brighter at higher tiers
	var body := ColorRect.new()
	body.size     = Vector2(body_sz, body_sz)
	body.position = Vector2(-half, -half)
	body.color    = col.lightened((tier - 1) * 0.12)
	add_child(body)

	## Tier pips: one small square per tier, centred horizontally.
	## T1 = 1 pip (single centre), T2 = 2 pips, T3 = 3 pips.
	var pip_sz    : float = 8.0
	var gap       : float = 3.0
	var total_w   : float = tier * pip_sz + (tier - 1) * gap
	var start_x   : float = -total_w * 0.5
	for i in tier:
		var pip := ColorRect.new()
		pip.size     = Vector2(pip_sz, pip_sz)
		pip.position = Vector2(start_x + i * (pip_sz + gap), -pip_sz * 0.5)
		pip.color    = col.darkened(0.60)
		add_child(pip)

	## Phase 9: XP progression bar above the tower body.
	_xp_bar = ProgressionBarScript.new()
	_xp_bar.position = Vector2(0.0, -half - 10.0)
	add_child(_xp_bar)
	_update_xp_bar()
