## Building.gd
## A production building placed on CLAIMED territory by the player.
## Contributes a passive income rate to EconomyManager when alive.
## Destroyed by flanker raids (Main listens to territory_raided and calls destroy()).
##
## Visual identity: 40×40 square body with a cross/plus overlay.
## Distinct from towers (square + pips) and units (small square + health bar).
extends Node2D

const FriendlyUnitScript = preload("res://src/entities/FriendlyUnit.gd")
const FriendlyRosterScript = preload("res://src/core/army/FriendlyRoster.gd")
const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")

## Item 3: every garrison reveals hidden (stealth) units within this modest bubble (~2.5 cells).
const DETECT_RADIUS : float = 160.0

## Phase C (C1): every production building doubles as a GARRISON — it produces a friendly
## defender on a cooldown, up to a cap, that guards the building's territory (core/17 §0:
## "Defensive structures double as production facilities"). Later sub-paths gate roles/tiers
## by garrison level and let the player invest resources to develop the garrison.
const GARRISON_BASE_MAX         : int   = 3     ## squad cap at level 1 (+1 per garrison level)
const GARRISON_PRODUCE_INTERVAL : float = 5.0   ## seconds between defenders at level 1
const GARRISON_PATROL_THRESHOLD : int   = 2     ## squad size at which idle units start patrolling
const GARRISON_XP_PER_LEVEL     : int   = 4     ## kills to level up (scales × current level)

## C3 — standing-order raids. When a garrison fields a full, safe squad it expands the player's
## territory: the squad marches to the nearest unclaimed frontier cell and claims a pocket there.
## Raids are withheld / aborted while enemies threaten the garrison (defense first), which makes
## the army expand during lulls — the rhythm the C4 offline loop will fast-forward.
const RAID_MIN_SQUAD     : int   = 3      ## need the full base squad before expanding
const RAID_RANGE_CELLS   : int   = 10     ## how far out to look for frontier ground to claim
const RAID_CLAIM_RADIUS  : int   = 1      ## cells claimed around the target on arrival (up to 3×3)
const RAID_THREAT_RADIUS : float = 260.0  ## an enemy this close withholds/aborts a raid
const RAID_REACH_DIST    : float = 44.0   ## a raider within this of the target completes the claim

## Construction (Phase 2B — commander-and-faction-systems.md). A freshly placed garrison starts inert
## at START_HEALTH — no income, no production — until the Commander builds it up to MAX_HEALTH (the
## weapon doubles as the engineering tool). Restored garrisons load already built.
const MAX_HEALTH   : float = 120.0
const START_HEALTH : float = 10.0
const BUILD_BAR_W  : float = 44.0

var data : Resource = null   ## BuildingData instance
var _income_active : bool = false
## True when this building was reconstructed by save-restore. Its income is already part of the
## restored territory_rates, so _ready must NOT re-add it (double-count). See persistence-design.md.
var _restored      : bool = false

## Construction state. _built false = under construction (inert); _health ramps from START_HEALTH to
## MAX_HEALTH under the Commander's engineering tool, then the garrison comes online.
var _max_health : float     = MAX_HEALTH
var _health     : float     = MAX_HEALTH
var _built      : bool      = true   ## _ready sets this from _restored / fresh
var _build_bar  : ColorRect = null

## Garrison state.
var _garrison_unit  : UnitData = null     ## the defender type this garrison produces
var _unit_layer     : Node2D   = null     ## where spawned defenders live (shared with enemies)
var _map_grid       : Node     = null     ## resolved from the "map_grid" group (for claim API)
var _produce_timer  : float    = GARRISON_PRODUCE_INTERVAL
var _my_units       : Array    = []       ## live defenders from this garrison (pruned each tick)
var _level          : int      = 1        ## garrison level — scales squad cap + production speed
var _kills          : int      = 0        ## kills banked toward the next level

## Raid state.
var _raiding           : bool    = false
var _raid_target_cell  : Vector2i = Vector2i(-1, -1)
var _raid_target_world : Vector2  = Vector2.ZERO

## Called by Main before adding to the scene tree.
func setup(building_data: Resource, restored: bool = false) -> void:
	data = building_data
	_restored = restored

## -- Construction / engineering (Phase 2B) --

func is_built() -> bool:
	return _built

## True while the garrison still needs the Commander (under construction, or built-but-damaged).
func needs_engineering() -> bool:
	return _health < _max_health

## The Commander channels its engineering tool here. Adds build/repair progress; on first reaching
## full health the garrison comes online. Returns true if it changed anything (drives the build beam).
func receive_engineering(amount: float) -> bool:
	if _health >= _max_health:
		return false
	_health = minf(_max_health, _health + amount)
	if not _built and _health >= _max_health:
		_complete_build()
	_refresh_build_visual()
	return true

## Construction finished: activate passive income and let _process run garrison production + raids.
func _complete_build() -> void:
	_built = true
	if not _income_active:
		_income_active = true
		EconomyManager.add_territory_rate(FactionManager.get_primary_resource(), float(data.get("income_rate")))
	var nm : String = str(data.get("building_name")) if data.get("building_name") != null else "Garrison"
	EventBus.notification_pushed.emit("%s online." % nm, "positive")

## Updates the build/repair bar and ghosts the garrison while it is under construction.
func _refresh_build_visual() -> void:
	var frac : float = clampf(_health / _max_health, 0.0, 1.0)
	if _build_bar != null:
		_build_bar.visible = _health < _max_health   ## show while building or damaged
		_build_bar.size.x  = BUILD_BAR_W * frac
	modulate = Color(1, 1, 1, 1) if _built else Color(0.6, 0.85, 1.0, 0.5)

## Item 3: stealth-reveal radius (px). Joins the "detectors" group contract (Unit scans it).
func get_detector_radius() -> float:
	return DETECT_RADIUS

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("detectors")   ## item 3: garrisons reveal hidden units
	if data == null:
		push_error("Building: no BuildingData -- call setup() before adding to tree.")
		return
	## Construction gate: a restored garrison loads already built (its income is already part of the
	## restored territory_rates, so don't re-add). A fresh placement starts UNDER CONSTRUCTION — no
	## income or production until the Commander finishes it (receive_engineering → _complete_build).
	## Phase 4A: Architects build sturdier structures (faction health multiplier).
	_max_health = MAX_HEALTH * FACTION_PERKS.health_mult(FactionManager.active_faction)
	_built  = _restored
	_health = _max_health if _built else START_HEALTH
	if _restored:
		_income_active = true   ## already counted in restored rates; don't re-add
	_build_visual()
	## Garrison: resolve the shared unit layer (WorldMap/UnitLayer) and the defender type
	## for the player's faction. Null faction (e.g. Academy) → no production, harmlessly.
	_unit_layer    = get_node_or_null("../../UnitLayer") as Node2D
	_map_grid      = get_tree().get_first_node_in_group("map_grid")
	_garrison_unit = FriendlyRosterScript.garrison_unit(FactionManager.active_faction)

func _process(delta: float) -> void:
	if not _built:
		return   ## under construction — no income, production, or raids until the Commander finishes it
	if _garrison_unit == null or _unit_layer == null:
		return
	_produce_timer -= delta
	if _produce_timer > 0.0:
		return
	_produce_timer = _produce_interval()
	## Prune dead/freed defenders, evaluate raids, drive patrol state, then top up the squad.
	_my_units = _my_units.filter(func(u): return is_instance_valid(u))
	_update_raid()
	## Patrol only when idle (not raiding) and the squad is big enough.
	var patrolling : bool = (not _raiding) and _my_units.size() >= GARRISON_PATROL_THRESHOLD
	for u in _my_units:
		if u.has_method("set_patrol"):
			u.call("set_patrol", patrolling)
	if _my_units.size() < _max_units():
		_spawn_defender()

## Spawns one friendly defender anchored to this garrison, with a small offset so they fan
## out rather than stacking on the exact same pixel. Passes self so the unit can report kills.
func _spawn_defender() -> void:
	var offset : Vector2 = Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
	var unit : Node2D = FriendlyUnitScript.new()
	unit.call("setup", _garrison_unit, global_position + offset, self)
	_unit_layer.add_child(unit)
	_my_units.append(unit)

## Called by a defender when it lands a killing blow. Garrison XP → level → larger, faster squad
## (later sub-passes also gate new roles/tiers on level).
func report_kill() -> void:
	_kills += 1
	if _kills >= GARRISON_XP_PER_LEVEL * _level:
		_kills = 0
		_level += 1
		EventBus.notification_pushed.emit("Garrison advanced to level %d." % _level, "normal")

func _max_units() -> int:
	return GARRISON_BASE_MAX + (_level - 1)

func _produce_interval() -> float:
	return maxf(2.0, GARRISON_PRODUCE_INTERVAL - 0.5 * float(_level - 1))

## -- C3: standing-order raids --

## Starts, completes, or aborts a raid. Called each production tick. Defense first: any enemy
## near the garrison withholds a new raid and aborts one in progress.
func _update_raid() -> void:
	if _map_grid == null:
		return
	var threatened : bool = _enemy_within(RAID_THREAT_RADIUS)
	if _raiding:
		if threatened:
			_abort_raid()
			return
		## Complete when any raider reaches the frontier target — claim a pocket there.
		for u in _my_units:
			if is_instance_valid(u) and (u as Node2D).global_position.distance_to(_raid_target_world) <= RAID_REACH_DIST:
				_complete_raid()
				return
		return
	## Idle: launch a raid if the squad is full and the area is safe.
	if threatened or _my_units.size() < RAID_MIN_SQUAD:
		return
	var gcell  : Vector2i = _map_grid.world_to_cell(global_position)
	var target : Vector2i = _map_grid.call("get_raid_target", gcell, RAID_RANGE_CELLS)
	if target == Vector2i(-1, -1):
		return
	_raiding           = true
	_raid_target_cell  = target
	_raid_target_world = _map_grid.cell_to_world(target.x, target.y)
	for u in _my_units:
		if u.has_method("set_raid_target"):
			u.call("set_raid_target", _raid_target_world)

## Claims the frontier pocket and ends the raid (squad reverts to guard/patrol).
func _complete_raid() -> void:
	var newly : Array = _map_grid.call("claim_area", _raid_target_cell, RAID_CLAIM_RADIUS)
	if newly != null and not newly.is_empty():
		## Batch event emissions: register all cells, then emit once per cell.
		## (Emit per-cell for ObjectiveManager to track; batching the redraw above prevents thrashing.)
		for nc in newly:
			EconomyManager.register_claimed_cell()
		for nc in newly:
			EventBus.territory_claimed.emit(nc)
		EventBus.notification_pushed.emit("Raiding party claimed %d cells of territory." % newly.size(), "normal")
	_abort_raid()

func _abort_raid() -> void:
	_raiding          = false
	_raid_target_cell = Vector2i(-1, -1)
	for u in _my_units:
		if is_instance_valid(u) and u.has_method("clear_raid"):
			u.call("clear_raid")

## True if any enemy wave unit is within `radius` of this garrison.
func _enemy_within(radius: float) -> bool:
	for e in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(e) and (e is Node2D) and global_position.distance_to((e as Node2D).global_position) <= radius:
			return true
	return false

## -- C4: offline resolution --

const OFFLINE_RAID_CYCLE : float = 30.0   ## offline seconds per completed raid
const OFFLINE_MAX_RAIDS  : int   = 20     ## cap per garrison so offline expansion is bounded

## Fast-forwards this garrison's standing-order raids over `seconds` of offline time and
## returns how many cells it claimed. Runs the SAME raid rules as live play (the real
## get_raid_target + claim_area against the live map), iterated cycle-by-cycle so each claim
## advances the frontier exactly as it would have online. Naturally bounded: it stops when no
## frontier remains within RAID_RANGE_CELLS of the garrison, or at OFFLINE_MAX_RAIDS.
func simulate_offline_raids(seconds: float) -> int:
	if _map_grid == null or _garrison_unit == null:
		return 0
	var raids   : int = clampi(int(seconds / OFFLINE_RAID_CYCLE), 0, OFFLINE_MAX_RAIDS)
	var claimed : int = 0
	var gcell   : Vector2i = _map_grid.world_to_cell(global_position)
	for _i in raids:
		var target : Vector2i = _map_grid.call("get_raid_target", gcell, RAID_RANGE_CELLS)
		if target == Vector2i(-1, -1):
			break
		var newly : Array = _map_grid.call("claim_area", target, RAID_CLAIM_RADIUS)
		if newly == null or newly.is_empty():
			break
		for nc in newly:
			EconomyManager.register_claimed_cell()
			EventBus.territory_claimed.emit(nc)
		claimed += newly.size()
	return claimed

## Called by Main._on_territory_raided() when a flanker destroys the cell.
## Removes the income contribution then frees the node.
func destroy() -> void:
	if _income_active:
		_income_active = false
		EconomyManager.add_territory_rate(
			FactionManager.get_primary_resource(),
			-float(data.get("income_rate"))
		)
	queue_free()

## -- Visual --

func _build_visual() -> void:
	var col : Color = data.get("color_hint") if data.get("color_hint") else Color.WHITE

	## Outer border (44×44)
	var border := ColorRect.new()
	border.size     = Vector2(44.0, 44.0)
	border.position = Vector2(-22.0, -22.0)
	border.color    = col.darkened(0.45)
	add_child(border)

	## Main body (40×40)
	var body := ColorRect.new()
	body.size     = Vector2(40.0, 40.0)
	body.position = Vector2(-20.0, -20.0)
	body.color    = col
	add_child(body)

	## Cross / plus symbol -- distinguishes buildings from towers and units.
	## Horizontal bar
	var h_bar := ColorRect.new()
	h_bar.size     = Vector2(26.0, 7.0)
	h_bar.position = Vector2(-13.0, -3.5)
	h_bar.color    = col.darkened(0.55)
	add_child(h_bar)

	## Vertical bar
	var v_bar := ColorRect.new()
	v_bar.size     = Vector2(7.0, 26.0)
	v_bar.position = Vector2(-3.5, -13.0)
	v_bar.color    = col.darkened(0.55)
	add_child(v_bar)

	## Construction / repair bar — below the body; shown only while building or damaged.
	_build_bar = ColorRect.new()
	_build_bar.size     = Vector2(BUILD_BAR_W, 4.0)
	_build_bar.position = Vector2(-BUILD_BAR_W * 0.5, 24.0)
	_build_bar.color    = Color(0.45, 1.0, 0.7, 0.95)   ## engineering green
	add_child(_build_bar)

	## Decorative Controls must not eat world clicks (default MOUSE_FILTER_STOP
	## would consume LMB before it reaches selection/placement handlers).
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_refresh_build_visual()
