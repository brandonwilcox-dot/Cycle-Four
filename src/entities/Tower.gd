## Tower.gd
## A placed defense tower. Scans for the nearest unit in range each attack cycle
## and calls take_damage() on it. No projectiles -- instant hit for MVP.
## Visual scales with tier: body grows, pip count matches tier number.
extends Node2D

const TowerDataClass    = preload("res://src/entities/TowerData.gd")
const FACTION_PERKS     = preload("res://src/core/FactionPerks.gd")
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

## Construction (Phase 2B — commander-and-faction-systems.md). A freshly placed tower starts inert
## at START_HEALTH and only comes online once the Commander builds it up to MAX_HEALTH (the weapon
## doubles as the engineering tool). A built-but-damaged tower is repaired the same way. Restored
## towers load already built. While not built the tower does not attack, buff, or tick.
const MAX_HEALTH   : float = 100.0
const START_HEALTH : float = 10.0
const BUILD_BAR_W  : float = 40.0

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

## Construction state. _built false = under construction (inert); _health ramps from START_HEALTH
## to MAX_HEALTH under the Commander's engineering tool, then the tower comes online.
var _max_health : float     = MAX_HEALTH
var _health     : float     = MAX_HEALTH
var _built      : bool      = true   ## setup() flips this false for fresh placements
var _build_bar  : ColorRect = null

## Phase 4A faction build-prefs: Bloom growth + Mesh chain damage multipliers (1.0 = none).
var _growth_mult   : float = 1.0
var _growth_stacks : int   = 0
var _grow_timer    : float = 0.0
var _chain_mult    : float = 1.0
var _pollen_timer  : float = 0.0   ## Phase 4B Bloom pollen emit cadence
var _hijack_timer  : float = 2.0   ## Phase 4B Mesh hijack cooldown (first convert ~2s after active)

## Called by Main before adding to scene tree. start_built=true for save-restore (already built);
## fresh placements default to false so the Commander must construct them.
func setup(tower_data: Resource, start_built: bool = false) -> void:
	data    = tower_data
	## Phase 4A: Architects build sturdier structures (faction health multiplier).
	_max_health = MAX_HEALTH * FACTION_PERKS.health_mult(FactionManager.active_faction)
	_built  = start_built
	_health = _max_health if start_built else START_HEALTH

func _ready() -> void:
	add_to_group("towers")
	if data == null:
		push_error("Tower: no TowerData -- call setup() before adding to tree.")
		return
	_build_visual()
	_refresh_detector_group()

## -- Construction / engineering (Phase 2B) --

func is_built() -> bool:
	return _built

## True while the tower still needs the Commander (under construction, or built-but-damaged).
func needs_engineering() -> bool:
	return _health < _max_health

## The Commander channels its engineering tool here. Adds build/repair progress; on first reaching
## full health the tower comes online. Returns true if it changed anything (drives the build beam).
func receive_engineering(amount: float) -> bool:
	if _health >= _max_health:
		return false
	_health = minf(_max_health, _health + amount)
	if not _built and _health >= _max_health:
		_built = true
		var nm : String = str(data.get("tower_name")) if data.get("tower_name") != null else "Tower"
		EventBus.notification_pushed.emit("%s online." % nm, "positive")
	_refresh_build_visual()
	return true

func _process(delta: float) -> void:
	if data == null:
		return
	if not _built:
		return   ## under construction — inert until the Commander finishes it
	_attack_timer += delta
	if _attack_timer >= 1.0 / data.attack_speed:
		_attack_timer = 0.0
		_try_attack()
	## Pass 3: refresh aura/territory empowerment on a slow cadence (not per-frame).
	_buff_timer -= delta
	if _buff_timer <= 0.0:
		_buff_timer = BUFF_RECOMPUTE_PERIOD
		_recompute_buffs()
	## Phase 4A: Bloom towers grow stronger the longer they stand (max health + damage, capped).
	if _growth_stacks < FACTION_PERKS.BLOOM_GROW_MAX_STACKS and FactionManager.active_faction == "bloom":
		_grow_timer += delta
		if _grow_timer >= FACTION_PERKS.BLOOM_GROW_INTERVAL:
			_grow_timer = 0.0
			_apply_growth()
	## Phase 4B: Bloom towers emit a pollen cloud — slow + blind enemies in radius.
	if FactionManager.active_faction == "bloom":
		_pollen_timer -= delta
		if _pollen_timer <= 0.0:
			_pollen_timer = FACTION_PERKS.BLOOM_POLLEN_REFRESH
			_emit_pollen()
	## Phase 4B: Mesh towers periodically hijack a nearby enemy to fight its allies.
	if FactionManager.active_faction == "mesh":
		_hijack_timer -= delta
		if _hijack_timer <= 0.0:
			_hijack_timer = FACTION_PERKS.MESH_HIJACK_COOLDOWN if _try_hijack() else 0.5

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
		var effective_damage : float = data.damage * _damage_multiplier * _aura_recv_mult * _territory_mult * _growth_mult * _chain_mult
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
	var grid       : Node  = _get_map_grid()
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var d : float = global_position.distance_to(unit.global_position)
		if d > data.range:
			continue
		## Stealth: can't lock onto an undetected unit (outside any sensor sphere).
		if unit.has_method("is_detectable") and not unit.call("is_detectable"):
			continue
		## DMZ: don't fire on enemies still inside a spawn's no-fire buffer — they need
		## to clear the spawn mouth and reach the field (fixes spawn-adjacent instakill).
		if grid != null and grid.call("is_in_spawn_dmz", unit.global_position):
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

## [Persistence Step 4] Restores veterancy level from a save — applies the cumulative effect of
## _level_up (damage multiplier, XP threshold, sight, chevrons) without replaying kills.
func restore_level(restored_level: int) -> void:
	level = clampi(restored_level, 1, TOWER_MAX_LEVEL)
	_damage_multiplier = pow(1.0 + DAMAGE_PER_LEVEL, float(level - 1))
	xp = 0.0
	xp_to_next = XP_BASE_THRESHOLD * pow(float(level), XP_LEVEL_EXPONENT)
	if _chevrons != null:
		_chevrons.call("set_rank", level - 1)
	_apply_sight()
	_recompute_buffs()
	_update_xp_bar()

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
	## Phase 4A: Mesh connected-tower chains empower their endpoints.
	_chain_mult = _compute_chain_mult() if FactionManager.active_faction == "mesh" else 1.0

## Phase 4A: Bloom growth — a tick raises this tower's max health (heals to match) + damage, capped,
## with a subtle scale-up so the growth reads on the board.
func _apply_growth() -> void:
	_growth_stacks += 1
	_growth_mult = pow(1.0 + FACTION_PERKS.BLOOM_GROW_DAMAGE_PCT, float(_growth_stacks))
	var grow_hp : float = _max_health * FACTION_PERKS.BLOOM_GROW_HEALTH_PCT
	_max_health += grow_hp
	_health = minf(_max_health, _health + grow_hp)
	scale = Vector2.ONE * (1.0 + 0.03 * float(_growth_stacks))

## Phase 4A: Mesh node-chains — an endpoint tower (linked to ≤1 other built tower) is empowered by the
## size of the connected chain it terminates; interior relays aren't buffed (the line feeds its ends).
func _compute_chain_mult() -> float:
	var towers : Array = get_tree().get_nodes_in_group("towers")
	var degree : int = 0
	for t in towers:
		if t == self or not _is_linkable(t):
			continue
		if global_position.distance_to((t as Node2D).global_position) <= FACTION_PERKS.MESH_LINK_RANGE:
			degree += 1
	if degree > 1:
		return 1.0   ## interior relay — only the ends of the line are empowered
	var comp : int = _chain_component_size(towers)
	return 1.0 + float(maxi(0, comp - 1)) * FACTION_PERKS.MESH_CHAIN_DAMAGE_PCT

func _is_linkable(t) -> bool:
	return is_instance_valid(t) and (t is Node2D) and t.has_method("is_built") and bool(t.call("is_built"))

func _chain_component_size(towers: Array) -> int:
	var visited : Dictionary = {}
	visited[self] = true   ## object key (a bare {self: true} literal would key the string "self")
	var stack : Array = [self]
	while not stack.is_empty():
		var cur : Node2D = stack.pop_back() as Node2D
		for t in towers:
			if visited.has(t) or not _is_linkable(t):
				continue
			if cur.global_position.distance_to((t as Node2D).global_position) <= FACTION_PERKS.MESH_LINK_RANGE:
				visited[t] = true
				stack.append(t)
	return visited.size()

## Phase 4B: re-apply pollen to every enemy unit inside this Bloom tower's cloud (slow + blind).
func _emit_pollen() -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not (u is Node2D) or not u.has_method("apply_pollen"):
			continue
		if global_position.distance_to((u as Node2D).global_position) <= FACTION_PERKS.BLOOM_POLLEN_RADIUS:
			u.call("apply_pollen", FACTION_PERKS.BLOOM_POLLEN_DURATION)

## Phase 4B: convert the nearest enemy in range to fight its allies. Returns true if one was hijacked.
func _try_hijack() -> bool:
	var best : Node2D = null
	var best_d : float = FACTION_PERKS.MESH_HIJACK_RADIUS
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not (u is Node2D) or not u.has_method("apply_hijack"):
			continue
		var d : float = global_position.distance_to((u as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = u
	if best == null:
		return false
	best.call("apply_hijack", FACTION_PERKS.MESH_HIJACK_DURATION)
	return true

## Phase 4B: draw the Bloom pollen cloud so its reach reads on the board (built Bloom towers only).
func _draw() -> void:
	if not (_built and FactionManager.active_faction == "bloom"):
		return
	var r : float = FACTION_PERKS.BLOOM_POLLEN_RADIUS
	draw_circle(Vector2.ZERO, r, Color(0.35, 0.75, 0.30, 0.10))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.45, 0.85, 0.40, 0.45), 1.5, true)

## Item 3: every tower reveals hidden units. Base reveal = its attack range (it sees what it can
## engage); dedicated detector towers (detector_radius set) reveal farther. Returns the larger.
func get_detector_radius() -> float:
	if data == null:
		return 0.0
	var dr  : float = float(data.detector_radius) if data.get("detector_radius") != null else 0.0
	var rng : float = float(data.range) if data.get("range") != null else 0.0
	return maxf(dr, rng)

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

	## Construction / repair bar — below the body; shown only while building or damaged.
	_build_bar = ColorRect.new()
	_build_bar.size     = Vector2(BUILD_BAR_W, 4.0)
	_build_bar.position = Vector2(-BUILD_BAR_W * 0.5, half + 4.0)
	_build_bar.color    = Color(0.45, 1.0, 0.7, 0.95)   ## engineering green
	add_child(_build_bar)

	## Decorative Controls must not eat world clicks (default MOUSE_FILTER_STOP
	## would consume LMB before it reaches selection/placement handlers).
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_refresh_build_visual()

## Updates the build/repair bar and ghosts the tower while it is under construction.
func _refresh_build_visual() -> void:
	var frac : float = clampf(_health / _max_health, 0.0, 1.0)
	if _build_bar != null:
		_build_bar.visible = _health < _max_health   ## show while building or damaged
		_build_bar.size.x  = BUILD_BAR_W * frac
	modulate = Color(1, 1, 1, 1) if _built else Color(0.6, 0.85, 1.0, 0.5)
	queue_redraw()   ## refresh the Bloom pollen aura (drawn in _draw) when build state changes
