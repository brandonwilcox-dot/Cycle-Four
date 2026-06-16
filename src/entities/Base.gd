## Base.gd
## The player's Forward Operating Base. Militarised starting position --
## an always-on turret provides early-wave defense. Cannot be moved or sold.
## HP tracks cumulative breach damage; reaching zero emits base_destroyed.
## Design ref: core/17_units-maps-buildings.md (FOB concept)
extends Node2D

const Combat = preload("res://src/combat/Combat.gd")

## Turret stats -- strong enough to carry early waves solo, challenged past wave 5.
const RANGE        : float = 256.0   ## pixels -- covers ~4 grid cells
const DAMAGE       : float = 18.0    ## per shot
const ATTACK_SPEED : float = 1.5     ## shots per second

## HP -- 300 means 30 breaches at default unit damage (10.0). Tune in balance pass.
const MAX_HP : float = 300.0

## Phase 9: FOB fortification rank — accumulates from convoy deliveries. Drives the
## sphere of influence below (more cargo → more sight + territory).
const CARGO_PER_RANK : float = 10.0

## Sphere of influence. The FOB reveals a sight sphere, projects a sensor ring beyond
## it, and claims a territory sphere — all growing one cell per fortification rank.
const FOB_SIGHT_RADIUS_BASE : int = 5   ## fog reveal radius at rank 0
const FOB_CLAIM_RADIUS_BASE : int = 2   ## territory claim radius at rank 0
const FOB_SENSOR_EXTRA      : int = 3   ## sensor ring reaches sight + this
const FOB_RADIUS_PER_RANK   : int = 1   ## sight and claim each grow this per rank
const FOB_MAX_RANK          : int = 10  ## fortification cap (sight 5→15, claim 2→12)

## MapGrid is resolved lazily from the "map_grid" group (set in MapGrid._ready).
var _map_grid : Node = null

const ProgressionBarScript = preload("res://src/ui/ProgressionBar.gd")
const RankChevronsScript   = preload("res://src/ui/RankChevrons.gd")

var _current_hp        : float     = MAX_HP
var _hp_bar            : ColorRect = null   ## tracked for live updates
var _attack_timer      : float     = 0.0
var _is_destroyed      : bool      = false
var _cargo_received    : float     = 0.0
var _fortification_rank : int      = 0
var _rank_bar          : Node2D    = null
var _rank_chevrons     : Node2D    = null

func _ready() -> void:
	add_to_group("base")
	_build_visual()
	EventBus.base_damaged.connect(_on_base_damaged)
	EventBus.base_healed.connect(_on_base_healed)
	EventBus.convoy_arrived.connect(_on_convoy_arrived)
	## Project the initial sphere of influence once the map is loaded (deferred so
	## MapGrid._ready has run and joined the "map_grid" group).
	call_deferred("_apply_influence")

## Resolves and caches the MapGrid from its group.
func _get_map_grid() -> Node:
	if _map_grid == null or not is_instance_valid(_map_grid):
		_map_grid = get_tree().get_first_node_in_group("map_grid")
	return _map_grid

## Reveals the FOB's sight sphere, projects its sensor ring, and claims its territory
## sphere. All three radii grow with fortification rank, so leveling the FOB visibly
## expands its reach. Safe to call repeatedly — claim/reveal skip cells already done.
func _apply_influence() -> void:
	var grid : Node = _get_map_grid()
	if grid == null:
		return
	var center : Vector2i = grid.world_to_cell(global_position)
	var sight  : int = FOB_SIGHT_RADIUS_BASE + _fortification_rank * FOB_RADIUS_PER_RANK
	var claim  : int = FOB_CLAIM_RADIUS_BASE + _fortification_rank * FOB_RADIUS_PER_RANK
	grid.call("reveal_area", center, sight)
	grid.call("sense_area", center, sight, sight + FOB_SENSOR_EXTRA)
	var claimed = grid.call("claim_area", center, claim)
	if claimed != null:
		for nc in claimed:
			EconomyManager.register_claimed_cell()
			EventBus.territory_claimed.emit(nc)

## Phase 9: FOB receives cargo and gains fortification rank. Visual-only stub
## for now; future phases can bind regen or defense bonuses to rank.
func _on_convoy_arrived(_convoy_id: StringName, _to_node: StringName, cargo: float) -> void:
	_cargo_received += cargo
	var prev_rank : int = _fortification_rank
	while _cargo_received >= CARGO_PER_RANK and _fortification_rank < FOB_MAX_RANK:
		_cargo_received -= CARGO_PER_RANK
		_fortification_rank += 1
	if _fortification_rank >= FOB_MAX_RANK:
		_cargo_received = 0.0   ## maxed — stop banking cargo toward rank
	_update_rank_bar()
	## Leveling up expands the sphere of influence: more sight + more territory.
	if _fortification_rank > prev_rank:
		if _rank_chevrons != null:
			_rank_chevrons.call("set_rank", _fortification_rank)
		_apply_influence()

func _update_rank_bar() -> void:
	if _rank_bar == null:
		return
	_rank_bar.set_progress(_cargo_received / CARGO_PER_RANK)

func _process(delta: float) -> void:
	if _is_destroyed:
		return
	_attack_timer += delta
	if _attack_timer >= 1.0 / ATTACK_SPEED:
		_attack_timer = 0.0
		_try_attack()

## -- Combat --

func _on_base_damaged(amount: float, _attacker_data: Dictionary) -> void:
	if _is_destroyed:
		return
	_current_hp = maxf(0.0, _current_hp - amount)
	_update_hp_bar()
	if _current_hp <= 0.0:
		_is_destroyed = true
		EventBus.base_destroyed.emit()

func _on_base_healed(amount: float) -> void:
	if _is_destroyed:
		return
	_current_hp = minf(MAX_HP, _current_hp + amount)
	_update_hp_bar()

func _try_attack() -> void:
	var nearest      : Node  = null
	var nearest_dist : float = RANGE
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		## Stealth: the FOB turret can't fire on an undetected unit.
		if unit.has_method("is_detectable") and not unit.call("is_detectable"):
			continue
		var dist : float = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest      = unit
	if nearest != null and nearest.has_method("take_damage"):
		nearest.take_damage(DAMAGE, Combat.faction_damage_type(FactionManager.active_faction))

## -- Visual --

func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.size.x = 80.0 * (_current_hp / MAX_HP)
	var ratio : float = _current_hp / MAX_HP
	if ratio > 0.5:
		_hp_bar.color = Color(0.20, 0.90, 0.20)
	elif ratio > 0.25:
		_hp_bar.color = Color(0.90, 0.70, 0.10)
	else:
		_hp_bar.color = Color(0.90, 0.20, 0.10)

func _build_visual() -> void:
	## Sandbag / concrete outer ring
	var ring := ColorRect.new()
	ring.size     = Vector2(100.0, 100.0)
	ring.position = Vector2(-50.0, -50.0)
	ring.color    = Color(0.30, 0.27, 0.20, 1.0)
	add_child(ring)

	## Main fortified body -- military olive drab
	var body := ColorRect.new()
	body.size     = Vector2(80.0, 80.0)
	body.position = Vector2(-40.0, -40.0)
	body.color    = Color(0.22, 0.32, 0.17, 1.0)
	add_child(body)

	## Corner reinforcement marks (four small squares)
	for corner in [Vector2(-40,-40), Vector2(28,-40), Vector2(-40,28), Vector2(28,28)]:
		var c := ColorRect.new()
		c.size     = Vector2(12.0, 12.0)
		c.position = corner
		c.color    = Color(0.18, 0.18, 0.14, 1.0)
		add_child(c)

	## Turret base -- gun metal
	var turret_base := ColorRect.new()
	turret_base.size     = Vector2(32.0, 32.0)
	turret_base.position = Vector2(-16.0, -16.0)
	turret_base.color    = Color(0.14, 0.14, 0.14, 1.0)
	add_child(turret_base)

	## Turret barrel indicator
	var barrel := ColorRect.new()
	barrel.size     = Vector2(8.0, 22.0)
	barrel.position = Vector2(-4.0, -30.0)
	barrel.color    = Color(0.10, 0.10, 0.10, 1.0)
	add_child(barrel)

	## FOB label
	var label := Label.new()
	label.text     = "FOB"
	label.position = Vector2(-18.0, 34.0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.55, 1.0))
	add_child(label)

	## HP bar background
	var bar_bg := ColorRect.new()
	bar_bg.size     = Vector2(80.0, 6.0)
	bar_bg.position = Vector2(-40.0, 52.0)
	bar_bg.color    = Color(0.20, 0.20, 0.20)
	add_child(bar_bg)

	## HP bar foreground (tracked for live updates)
	_hp_bar          = ColorRect.new()
	_hp_bar.size     = Vector2(80.0, 6.0)
	_hp_bar.position = Vector2(-40.0, 52.0)
	_hp_bar.color    = Color(0.20, 0.90, 0.20)
	add_child(_hp_bar)

	## Phase 9: fortification rank progression bar above the FOB.
	_rank_bar = ProgressionBarScript.new()
	_rank_bar.position = Vector2(0.0, -62.0)
	add_child(_rank_bar)
	_update_rank_bar()
	## Veterancy chevrons above the rank bar (one per fortification rank).
	_rank_chevrons = RankChevronsScript.new()
	_rank_chevrons.position = Vector2(0.0, -70.0)
	add_child(_rank_chevrons)
