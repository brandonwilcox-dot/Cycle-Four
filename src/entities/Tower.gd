## Tower.gd
## A placed defense tower. Scans for the nearest unit in range each attack cycle
## and calls take_damage() on it. No projectiles -- instant hit for MVP.
## Visual scales with tier: body grows, pip count matches tier number.
extends Node2D

const TowerDataClass    = preload("res://src/entities/TowerData.gd")
const ProgressionBarScript = preload("res://src/ui/ProgressionBar.gd")
const RankChevronsScript   = preload("res://src/ui/RankChevrons.gd")

## Targeting priority the player can cycle from the InspectionPanel (TD staple).
## Order must match TARGET_MODE_NAMES.
enum TargetMode { CLOSEST, FIRST, LAST, STRONGEST }
const TARGET_MODE_NAMES : Array = ["Closest", "First", "Last", "Strongest"]
var target_mode : int = TargetMode.CLOSEST

## Phase 9 progression constants. Step-function scaling per the handoff §8.1.
const XP_BASE_THRESHOLD   : float = 50.0   ## XP needed for level 1 → 2
const XP_LEVEL_EXPONENT   : float = 2.0    ## threshold scales as XP_BASE × level^exp
const DAMAGE_PER_LEVEL    : float = 0.15   ## +15% damage per level (multiplicative)
## Veterancy cap + sight growth: a tower's sight sphere widens as it racks up kills,
## one cell every TOWER_SIGHT_PER_STEP levels, up to the bonus max. Level is capped.
const TOWER_MAX_LEVEL      : int = 10
const TOWER_SIGHT_BASE     : int = 3
const TOWER_SIGHT_PER_STEP : int = 3   ## +1 sight cell every 3 levels
const TOWER_SIGHT_BONUS_MAX : int = 3  ## sight 3 → 6 at max level
const TOWER_SENSOR_EXTRA   : int = 2   ## sensor ring reaches sight + this

## Pass 3 "Tower Mastery": aura/support, territory empowerment, max-level promotion.
const BUFF_RECOMPUTE_PERIOD  : float = 0.5    ## seconds between aura/territory recompute (cheap, not per-frame)
const VETERAN_AURA_RADIUS    : float = 160.0  ## a max-level tower radiates a support aura this wide
const VETERAN_AURA_BONUS     : float = 0.10   ## +10% damage to friendly towers inside a veteran aura
const TERRITORY_DAMAGE_BONUS : float = 0.15   ## +15% damage while standing on claimed ground

var data: Resource = null   ## TowerData instance
var _attack_timer: float = 0.0

## Phase 9: level + XP. Level is earned through kills, independent of tier (which
## is bought by spending resources). Damage scales multiplicatively per level via
## _damage_multiplier so the shared TowerData resource is never mutated.
var level              : int   = 1
var xp                 : float = 0.0
var xp_to_next         : float = XP_BASE_THRESHOLD
var _damage_multiplier : float = 1.0
var _aura_recv_mult    : float = 1.0   ## best damage aura received from nearby towers (1.0 = none)
var _territory_mult    : float = 1.0   ## territory empowerment multiplier (1.0 = none)
var _buff_timer        : float = 0.0   ## throttle for _recompute_buffs
var _xp_bar            : Node2D = null   ## ProgressionBar instance
var _chevrons          : Node2D = null   ## RankChevrons instance
var _map_grid          : Node   = null   ## resolved lazily from the "map_grid" group

## Called by Main before adding to scene tree.
func setup(tower_data: Resource) -> void:
	data = tower_data

func _ready() -> void:
	add_to_group("towers")
	if data == null:
		push_error("Tower: no TowerData -- call setup() before adding to tree.")
		return
	_build_visual()
	_refresh_detector_group()

func _process(delta: float) -> void:
	if data == null:
		return
	_attack_timer += delta
	if _attack_timer >= 1.0 / data.attack_speed:
		_attack_timer = 0.0
		_try_attack()
	## Pass 3: refresh aura/territory empowerment on a slow cadence (not per-frame).
	_buff_timer -= delta
	if _buff_timer <= 0.0:
		_buff_timer = BUFF_RECOMPUTE_PERIOD
		_recompute_buffs()

## Replaces this tower's data with the next tier and rebuilds the visual in place.
## Called by Main._try_upgrade_tower() after spending the upgrade cost.
func upgrade(next_data: Resource) -> void:
	data = next_data
	## Clear existing child visuals then rebuild.
	for child in get_children():
		child.queue_free()
	_build_visual()
	_refresh_detector_group()   ## the new tier may gain/lose stealth detection

## -- Combat --

func _try_attack() -> void:
	var target : Node = _select_target()
	if target != null and target.has_method("take_damage"):
		var effective_damage : float = data.damage * _damage_multiplier * _aura_recv_mult * _territory_mult
		var killed : bool = target.take_damage(effective_damage, int(data.damage_type))
		if killed:
			_award_xp_for_kill(target)

## Picks the in-range enemy that best matches the current targeting mode:
## Closest (to tower), First (nearest the base = furthest along), Last (least progress),
## Strongest (highest current HP). Single pass; higher score wins.
func _select_target() -> Node:
	var best       : Node  = null
	var best_score : float = 0.0
	var have       : bool  = false
	var base_pos   : Vector2 = _base_pos()
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var d : float = global_position.distance_to(unit.global_position)
		if d > data.range:
			continue
		## Stealth: can't lock onto an undetected unit (outside any sensor sphere).
		if unit.has_method("is_detectable") and not unit.call("is_detectable"):
			continue
		var score : float
		match target_mode:
			TargetMode.STRONGEST:
				score = float(unit.get("_current_health")) if unit.get("_current_health") != null else 0.0
			TargetMode.FIRST:
				score = -base_pos.distance_to(unit.global_position)   ## nearest the base
			TargetMode.LAST:
				score = base_pos.distance_to(unit.global_position)    ## farthest from base
			_:  ## CLOSEST
				score = -d
		if not have or score > best_score:
			best       = unit
			best_score = score
			have       = true
	return best

func _base_pos() -> Vector2:
	var b : Node = get_tree().get_first_node_in_group("base")
	return (b as Node2D).global_position if b is Node2D else global_position

## Cycles to the next targeting mode (called by the InspectionPanel button).
func cycle_target_mode() -> void:
	target_mode = (target_mode + 1) % TARGET_MODE_NAMES.size()

func target_mode_name() -> String:
	return TARGET_MODE_NAMES[target_mode]

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
	while level < TOWER_MAX_LEVEL and xp >= xp_to_next:
		xp -= xp_to_next
		_level_up()
	if level >= TOWER_MAX_LEVEL:
		xp = 0.0   ## maxed — park the XP bar full-empty
	_update_xp_bar()

func _update_xp_bar() -> void:
	if _xp_bar != null and xp_to_next > 0.0:
		_xp_bar.set_progress(xp / xp_to_next)

func _level_up() -> void:
	level += 1
	_damage_multiplier = pow(1.0 + DAMAGE_PER_LEVEL, float(level - 1))
	xp_to_next = XP_BASE_THRESHOLD * pow(float(level), XP_LEVEL_EXPONENT)
	EventBus.tower_leveled_up.emit(self, level)
	if _chevrons != null:
		_chevrons.call("set_rank", level - 1)
	_apply_sight()       ## leveling widens the tower's sight/sensor sphere
	_recompute_buffs()   ## hitting max level grants the veteran aura immediately

## Resolves and caches the MapGrid from its group.
func _get_map_grid() -> Node:
	if _map_grid == null or not is_instance_valid(_map_grid):
		_map_grid = get_tree().get_first_node_in_group("map_grid")
	return _map_grid

## Reveals/senses this tower's sight sphere. Radius widens with veterancy level, so a
## battle-hardened tower lights up more of the map around it. Idempotent re-reveal.
func _apply_sight() -> void:
	var grid : Node = _get_map_grid()
	if grid == null:
		return
	var cell  : Vector2i = grid.world_to_cell(global_position)
	@warning_ignore("integer_division")
	var sight : int = TOWER_SIGHT_BASE + mini(level / TOWER_SIGHT_PER_STEP, TOWER_SIGHT_BONUS_MAX)
	grid.call("reveal_area", cell, sight)
	grid.call("sense_area", cell, sight, sight + TOWER_SENSOR_EXTRA)

## -- Pass 3: aura / support / territory --

## True if this tower projects a damage aura (from its data, or as a max-level veteran).
func provides_aura() -> bool:
	return get_aura_radius() > 0.0 and get_aura_bonus() > 0.0

## Aura radius in px: the larger of the data-defined aura and (at max level) the veteran aura.
func get_aura_radius() -> float:
	var r : float = float(data.aura_radius) if data != null and data.get("aura_radius") != null else 0.0
	if level >= TOWER_MAX_LEVEL:
		r = maxf(r, VETERAN_AURA_RADIUS)
	return r

## Aura damage bonus (fraction): the larger of the data-defined bonus and the veteran bonus.
func get_aura_bonus() -> float:
	var b : float = float(data.aura_damage_bonus) if data != null and data.get("aura_damage_bonus") != null else 0.0
	if level >= TOWER_MAX_LEVEL:
		b = maxf(b, VETERAN_AURA_BONUS)
	return b

## Recomputes the aura received from nearby towers and the territory bonus. Throttled.
func _recompute_buffs() -> void:
	var best_bonus : float = 0.0
	for other in get_tree().get_nodes_in_group("towers"):
		if other == self or not is_instance_valid(other):
			continue
		if not other.has_method("get_aura_radius"):
			continue
		var radius : float = float(other.call("get_aura_radius"))
		if radius <= 0.0:
			continue
		if global_position.distance_to((other as Node2D).global_position) <= radius:
			best_bonus = maxf(best_bonus, float(other.call("get_aura_bonus")))
	_aura_recv_mult = 1.0 + best_bonus
	_territory_mult = 1.0 + (TERRITORY_DAMAGE_BONUS if _on_claimed_ground() else 0.0)

## Stealth detection: radius (px) within which this tower reveals stealth units.
func get_detector_radius() -> float:
	return float(data.detector_radius) if data != null and data.get("detector_radius") != null else 0.0

func provides_detection() -> bool:
	return get_detector_radius() > 0.0

## Joins/leaves the "detectors" group based on the current data's detector_radius.
func _refresh_detector_group() -> void:
	if provides_detection():
		if not is_in_group("detectors"):
			add_to_group("detectors")
	elif is_in_group("detectors"):
		remove_from_group("detectors")

## True when the tower's own cell is claimed friendly territory.
func _on_claimed_ground() -> bool:
	var grid : Node = _get_map_grid()
	if grid == null:
		return false
	var cell : Vector2i = grid.world_to_cell(global_position)
	return bool(grid.call("is_claimed", cell.x, cell.y))

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
	## Veterancy chevrons above the XP bar (one per level earned beyond the first).
	_chevrons = RankChevronsScript.new()
	_chevrons.position = Vector2(0.0, -half - 16.0)
	add_child(_chevrons)
	_chevrons.call("set_rank", level - 1)
