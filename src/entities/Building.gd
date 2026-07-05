## Building.gd
## A production building / GARRISON placed on CLAIMED territory. Contributes passive income,
## produces friendly defenders, patrols, runs standing-order raids, and levels up.
##
## 3D MIGRATION (Stage 2c): now `extends Node3D` (model/view). Static plane position `_p` +
## place_at()/plane_pos(); all distance/cell math goes through World3D. Visual is a 3D box garrison
## with a raised cross identity (was a ColorRect square + plus). Defender production reuses the
## shared unit layer once FriendlyUnit is 3D-converted; it no-ops safely until then.
extends Node3D

const FriendlyUnitScript = preload("res://src/entities/FriendlyUnit.gd")
const FriendlyRosterScript = preload("res://src/core/army/FriendlyRoster.gd")
const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")
const WORLD3D = preload("res://src/core/World3D.gd")

const DETECT_RADIUS : float = 160.0

const GARRISON_BASE_MAX         : int   = 3
const GARRISON_PRODUCE_INTERVAL : float = 5.0
const GARRISON_PATROL_THRESHOLD : int   = 2

## -- U1 node identity (units-land-plan / Units_Land §2): how a faction's garrison behaves
##    over the life of the node. Replaces the old kill-XP leveling.
##  Architects — COMPOUND: undamaged uptime ramps production speed; damage/losses reset the ramp.
##  Bloom      — MATURE + CONNECT: node grows regen/damage/squad/tether over time; linked
##               Bloom nodes (touching radii) amplify each other.
##  Mesh       — OVERLAP + REROUTE: units inside ≥2 Mesh node radii fire faster; on node
##               death, survivors re-tether to the nearest Mesh node.
const ARCH_COMPOUND_FULL    : float = 360.0  ## seconds of clean uptime to reach full ramp
const ARCH_COMPOUND_CD_CUT  : float = 0.45   ## production interval −45% at full ramp
const ARCH_COMPOUND_KILL_T  : float = 2.0    ## each squad kill feeds the ramp a little
const ARCH_DAMAGE_DECAY     : float = 0.4    ## garrison damage keeps only 40% of the ramp
const ARCH_UNIT_LOSS_T      : float = 30.0   ## each tethered unit lost costs 30s of ramp
const BLOOM_MATURE_FULL     : float = 300.0  ## seconds to full maturity
const BLOOM_REGEN_HPS       : float = 3.0    ## unit regen at full maturity (HP/s, aura)
const BLOOM_MATURE_DMG      : float = 0.25   ## +25% unit damage at full maturity
const BLOOM_LINK_DMG        : float = 0.08   ## +8% unit damage per connected Bloom node
const BLOOM_LINK_CAP        : int   = 3
const BLOOM_TETHER_GROW     : float = 0.35   ## tether radius +35% at full maturity
const MESH_OVERLAP_ROF      : float = 0.25   ## fire-rate share per extra overlapping node

const RAID_MIN_SQUAD     : int   = 3
const RAID_RANGE_CELLS   : int   = 10
const RAID_CLAIM_RADIUS  : int   = 1
const RAID_THREAT_RADIUS : float = 260.0
const RAID_REACH_DIST    : float = 44.0

const MAX_HEALTH   : float = 120.0
const START_HEALTH : float = 10.0

var data : Resource = null   ## BuildingData instance
var _p   : Vector2 = Vector2.ZERO
var _income_active : bool = false
var _restored      : bool = false

## Construction state.
var _max_health : float = MAX_HEALTH
var _health     : float = MAX_HEALTH
var _built      : bool  = true

## Garrison state.
var _garrison_unit  : UnitData = null
var _unit_layer     : Node     = null
var _map_grid       : Node     = null
var _produce_timer  : float    = GARRISON_PRODUCE_INTERVAL
var _my_units       : Array    = []

## U2: which roster role this garrison produces ("line" default; cycled from the panel).
var _production_role : String = "line"

## U1 node state. _node_t is the identity clock: Architect compound ramp (decays on damage/
## losses) or Bloom maturity (monotonic). Mesh nodes read the battlefield instead (overlap).
var _faction        : String = ""
var _node_t         : float  = 0.0
var _links          : int    = 0      ## Bloom: connected nodes; Mesh: overlap shown on the bar
var _node_peaked    : bool   = false  ## one-shot "ramp complete" notification
var _node_bar       : MeshInstance3D = null

## Raid state.
var _raiding           : bool    = false
var _raid_target_cell  : Vector2i = Vector2i(-1, -1)
var _raid_target_world : Vector2  = Vector2.ZERO

## 3D visual.
var _body_root : Node3D = null   ## body parts container
var _con_rig   : Node3D = null   ## per-faction construction effect
var _body_mats : Array[StandardMaterial3D] = []
var _build_bar : MeshInstance3D = null
var _height    : float = 50.0

func setup(building_data: Resource, restored: bool = false) -> void:
	data = building_data
	_restored = restored

## Fix the garrison's plane position (and 3D transform).
func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

func plane_pos() -> Vector2:
	return _p

## -- Construction / engineering (Phase 2B) --

func is_built() -> bool:
	return _built

func needs_engineering() -> bool:
	return _health < _max_health

func receive_engineering(amount: float) -> bool:
	if _health >= _max_health:
		return false
	_health = minf(_max_health, _health + amount)
	if not _built and _health >= _max_health:
		_complete_build()
	_refresh_build_visual()
	return true

func _complete_build() -> void:
	_built = true
	if not _income_active:
		_income_active = true
		EconomyManager.add_territory_rate(FactionManager.get_primary_resource(), float(data.get("income_rate")))
	var nm : String = str(data.get("building_name")) if data.get("building_name") != null else "Garrison"
	EventBus.notification_pushed.emit("%s online." % nm, "positive")

## Ghosts the garrison (material alpha) while under construction and drives the build bar.
func _refresh_build_visual() -> void:
	var frac : float = clampf(_health / _max_health, 0.0, 1.0)
	if _build_bar != null:
		_build_bar.visible = _health < _max_health
		_build_bar.scale.x = frac
	## Per-faction construction language lives in the rig (grow / carve / drone-assemble).
	if _con_rig != null:
		_con_rig.call("update", frac, _built)

func get_detector_radius() -> float:
	return DETECT_RADIUS

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("detectors")
	if data == null:
		push_error("Building: no BuildingData -- call setup() before adding to tree.")
		return
	position = WORLD3D.to3(_p, 0.0)
	_faction = FactionManager.active_faction
	_max_health = MAX_HEALTH * FACTION_PERKS.health_mult(_faction)
	_built  = _restored
	_health = _max_health if _built else START_HEALTH
	if _restored:
		_income_active = true
	_build_visual()
	_unit_layer    = get_node_or_null("../../UnitLayer")
	_map_grid      = get_tree().get_first_node_in_group("map_grid")
	_garrison_unit = FriendlyRosterScript.garrison_unit(_faction, _production_role)

## -- U2: production role selection (cycled from the inspection panel; new spawns use it,
##    existing squad members serve out their posting) --

func set_production_role(role: String) -> void:
	if role in FriendlyRosterScript.roles_for(_faction):
		_production_role = role
		_garrison_unit   = FriendlyRosterScript.garrison_unit(_faction, role)

func cycle_production_role() -> void:
	var roles : Array = FriendlyRosterScript.roles_for(_faction)
	var idx : int = roles.find(_production_role)
	set_production_role(roles[(idx + 1) % roles.size()])

func production_role_name() -> String:
	var unit_name : String = _garrison_unit.unit_name if _garrison_unit != null else "?"
	return "%s — %s" % [_production_role.capitalize(), unit_name]

func _process(delta: float) -> void:
	if not _built:
		return
	## U1: the node identity clock runs whenever the node is built.
	_node_t = minf(_node_t + delta, maxf(ARCH_COMPOUND_FULL, BLOOM_MATURE_FULL))
	if _faction == "bloom":
		_apply_bloom_regen(delta)
	## Resolve the friendly-unit layer lazily: the hardcoded ../../UnitLayer path doesn't hold in the
	## 3D scene layout, so fall back to the "unit_layer" group once it exists.
	if _unit_layer == null:
		_unit_layer = get_node_or_null("../../UnitLayer")
		if _unit_layer == null:
			_unit_layer = get_tree().get_first_node_in_group("unit_layer")
	if _garrison_unit == null or _unit_layer == null:
		return
	_produce_timer -= delta
	if _produce_timer > 0.0:
		return
	_produce_timer = _produce_interval()
	_my_units = _my_units.filter(func(u): return is_instance_valid(u))
	_apply_node_identity()
	_update_raid()
	var patrolling : bool = (not _raiding) and _my_units.size() >= GARRISON_PATROL_THRESHOLD
	for u in _my_units:
		if u.has_method("set_patrol"):
			u.call("set_patrol", patrolling)
	if _my_units.size() < _max_units():
		_spawn_defender()

func _spawn_defender() -> void:
	var offset : Vector2 = Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
	var unit : Node = FriendlyUnitScript.new()
	unit.call("setup", _garrison_unit, _p + offset, self)
	_unit_layer.add_child(unit)
	_my_units.append(unit)

## -- U1 node identity engine --

## Architect compound / Bloom maturity progress, 0..1.
func _node_frac() -> float:
	match _faction:
		"architects": return clampf(_node_t / ARCH_COMPOUND_FULL, 0.0, 1.0)
		"bloom":      return clampf(_node_t / BLOOM_MATURE_FULL, 0.0, 1.0)
	return 0.0

## Applied on the production tick (a few seconds) — auras are automatic, never micro'd.
func _apply_node_identity() -> void:
	match _faction:
		"bloom":
			_links = _count_bloom_links()
			var dmg : float = 1.0 + BLOOM_MATURE_DMG * _node_frac() + BLOOM_LINK_DMG * float(_links)
			var leash : float = FACTION_PERKS.tether_radius("bloom") * (1.0 + BLOOM_TETHER_GROW * _node_frac())
			for u in _my_units:
				u.set("damage_mult", dmg)
				if u.has_method("set_leash"):
					u.call("set_leash", leash)
		"mesh":
			var max_overlap : int = 0
			for u in _my_units:
				var n : int = _mesh_overlap_count(WORLD3D.node_plane(u))
				max_overlap = maxi(max_overlap, n)
				u.set("rof_mult", 1.0 / (1.0 + MESH_OVERLAP_ROF * float(n - 1)) if n >= 2 else 1.0)
			_links = max_overlap
	_update_node_bar()
	if not _node_peaked and _node_frac() >= 1.0:
		_node_peaked = true
		match _faction:
			"architects": EventBus.notification_pushed.emit("Garrison compound at peak efficiency.", "positive")
			"bloom":      EventBus.notification_pushed.emit("Bloom node fully matured.", "positive")

## Bloom regen aura — the maturing node heals its tethered units (and itself) every frame.
func _apply_bloom_regen(delta: float) -> void:
	var hps : float = BLOOM_REGEN_HPS * _node_frac()
	if hps <= 0.0:
		return
	for u in _my_units:
		if is_instance_valid(u) and u.has_method("heal"):
			u.call("heal", hps * delta)
	_health = minf(_max_health, _health + hps * 0.5 * delta)

## Bloom connection bonus: other built Bloom garrisons whose tether radii touch this one's.
func _count_bloom_links() -> int:
	var reach : float = FACTION_PERKS.tether_radius("bloom") * 2.0
	var n : int = 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if b == self or not is_instance_valid(b):
			continue
		if b.has_method("is_built") and not b.call("is_built"):
			continue
		if _p.distance_to(WORLD3D.node_plane(b)) <= reach:
			n += 1
	return mini(n, BLOOM_LINK_CAP)

## Mesh overlap: how many built Mesh garrison radii cover this plane point.
func _mesh_overlap_count(at: Vector2) -> int:
	var r : float = FACTION_PERKS.tether_radius("mesh")
	var n : int = 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b):
			continue
		if b.has_method("is_built") and not b.call("is_built"):
			continue
		if at.distance_to(WORLD3D.node_plane(b)) <= r:
			n += 1
	return n

## Squad kills still feed back — for Architects they nudge the compound ramp.
func report_kill() -> void:
	if _faction == "architects":
		_node_t = minf(_node_t + ARCH_COMPOUND_KILL_T, ARCH_COMPOUND_FULL)

## U1 punish — losing a tethered unit costs an Architect node part of its ramp.
func report_unit_lost() -> void:
	if _faction == "architects":
		_node_t = maxf(0.0, _node_t - ARCH_UNIT_LOSS_T)

## U5 wave-targeting will call this (Architect waves focus production). Damage to the
## garrison is the other Architect compound punish.
func take_damage(amount: float, _damage_type: int = -1) -> bool:
	if not _built:
		return false
	_health -= amount
	if _faction == "architects":
		_node_t *= ARCH_DAMAGE_DECAY
		_node_peaked = false
	_refresh_build_visual()
	if _health <= 0.0:
		var cell : Vector2i = _map_grid.world_to_cell(_p) if _map_grid != null else Vector2i(-1, -1)
		EventBus.building_destroyed.emit(data, cell)
		EventBus.notification_pushed.emit("Garrison destroyed!", "alert")
		destroy()
		return true
	return false

## core/18 pacification hook — when the Dominance Meter lands, node activity reports here.
func dominance_hook() -> void:
	pass

func _max_units() -> int:
	## Bloom nodes literally grow: +1 squad slot at half maturity, +1 at full.
	if _faction == "bloom":
		return GARRISON_BASE_MAX + (1 if _node_frac() >= 0.5 else 0) + (1 if _node_frac() >= 1.0 else 0)
	return GARRISON_BASE_MAX

func _produce_interval() -> float:
	## Architect compound: production accelerates with clean uptime.
	if _faction == "architects":
		return GARRISON_PRODUCE_INTERVAL * (1.0 - ARCH_COMPOUND_CD_CUT * _node_frac())
	return GARRISON_PRODUCE_INTERVAL

## -- C3: standing-order raids --

func _update_raid() -> void:
	if _map_grid == null:
		return
	var threatened : bool = _enemy_within(RAID_THREAT_RADIUS)
	if _raiding:
		if threatened:
			_abort_raid()
			return
		for u in _my_units:
			if is_instance_valid(u) and WORLD3D.node_plane(u).distance_to(_raid_target_world) <= RAID_REACH_DIST:
				_complete_raid()
				return
		return
	if threatened or _my_units.size() < RAID_MIN_SQUAD:
		return
	var gcell  : Vector2i = _map_grid.world_to_cell(_p)
	var target : Vector2i = _map_grid.call("get_raid_target", gcell, RAID_RANGE_CELLS)
	if target == Vector2i(-1, -1):
		return
	_raiding           = true
	_raid_target_cell  = target
	_raid_target_world = _map_grid.cell_to_world(target.x, target.y)
	for u in _my_units:
		if u.has_method("set_raid_target"):
			u.call("set_raid_target", _raid_target_world)

func _complete_raid() -> void:
	var newly : Array = _map_grid.call("claim_area", _raid_target_cell, RAID_CLAIM_RADIUS)
	if newly != null and not newly.is_empty():
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

func _enemy_within(radius: float) -> bool:
	for e in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(e) and _p.distance_to(WORLD3D.node_plane(e)) <= radius:
			return true
	return false

## -- C4: offline resolution --

const OFFLINE_RAID_CYCLE : float = 30.0
const OFFLINE_MAX_RAIDS  : int   = 20

func simulate_offline_raids(seconds: float) -> int:
	## U1: the node clock also advances offline (compound assumes clean uptime; Bloom matures).
	_node_t = minf(_node_t + seconds, maxf(ARCH_COMPOUND_FULL, BLOOM_MATURE_FULL))
	if _map_grid == null or _garrison_unit == null:
		return 0
	var raids   : int = clampi(int(seconds / OFFLINE_RAID_CYCLE), 0, OFFLINE_MAX_RAIDS)
	var claimed : int = 0
	var gcell   : Vector2i = _map_grid.world_to_cell(_p)
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

func destroy() -> void:
	if _income_active:
		_income_active = false
		EconomyManager.add_territory_rate(
			FactionManager.get_primary_resource(),
			-float(data.get("income_rate"))
		)
	## U1 — Mesh reroute-on-loss: survivors re-tether to the nearest Mesh node. "The network
	## does not mourn. It reroutes." Other factions' survivors keep their old post and attrit.
	if _faction == "mesh":
		_reroute_survivors()
	queue_free()

func _reroute_survivors() -> void:
	var best : Node = null
	var best_d : float = INF
	for b in get_tree().get_nodes_in_group("buildings"):
		if b == self or not is_instance_valid(b) or not b.has_method("adopt_unit"):
			continue
		if b.has_method("is_built") and not b.call("is_built"):
			continue
		var d : float = _p.distance_to(WORLD3D.node_plane(b))
		if d < best_d:
			best   = b
			best_d = d
	if best == null:
		return
	var moved : int = 0
	for u in _my_units:
		if is_instance_valid(u):
			best.call("adopt_unit", u)
			moved += 1
	_my_units.clear()
	if moved > 0:
		EventBus.notification_pushed.emit("Node lost — %d units rerouted." % moved, "normal")

## U1 — receive a rerouted unit from a destroyed Mesh node.
func adopt_unit(u: Node) -> void:
	if u.has_method("retether"):
		u.call("retether", _p, self)
	_my_units.append(u)

## -- Visual (3D) --

func _build_visual() -> void:
	_body_mats.clear()
	## V4 rising construction: body parts under _body_root, scaled up in Y with build progress.
	_body_root = Node3D.new()
	add_child(_body_root)
	var col : Color = data.get("color_hint") if data.get("color_hint") else Color.WHITE

	## Garrison body — a squat block.
	var body : MeshInstance3D = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(46.0, _height, 46.0)
	body.mesh = bx
	body.position = Vector3(0.0, _height * 0.5, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.material_override = _mat(col)
	_body_root.add_child(body)

	## Raised cross/plus on top — the building identity (distinct from towers/units).
	var cross_col : Color = col.darkened(0.5)
	var hbar : MeshInstance3D = MeshInstance3D.new()
	var hb : BoxMesh = BoxMesh.new()
	hb.size = Vector3(34.0, 8.0, 10.0)
	hbar.mesh = hb
	hbar.position = Vector3(0.0, _height + 5.0, 0.0)
	hbar.material_override = _mat(cross_col)
	_body_root.add_child(hbar)
	var vbar : MeshInstance3D = MeshInstance3D.new()
	var vb : BoxMesh = BoxMesh.new()
	vb.size = Vector3(10.0, 8.0, 34.0)
	vbar.mesh = vb
	vbar.position = Vector3(0.0, _height + 5.0, 0.0)
	vbar.material_override = _mat(cross_col)
	_body_root.add_child(vbar)

	## Construction/repair bar — billboarded above; shown while building/damaged.
	_build_bar = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(48.0, 5.0)
	_build_bar.mesh = qm
	_build_bar.position = Vector3(0.0, _height + 18.0, 0.0)
	var bmat : StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.45, 1.0, 0.7)
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_build_bar.material_override = bmat
	_build_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_build_bar)

	## U1 node-state bar — a thin faction-colored strip under the build bar. Architects: the
	## compound ramp. Bloom: maturity. Mesh: overlap share (links/cap). Fills left→right.
	_node_bar = MeshInstance3D.new()
	var nqm : QuadMesh = QuadMesh.new()
	nqm.size = Vector2(48.0, 2.5)
	_node_bar.mesh = nqm
	_node_bar.position = Vector3(0.0, _height + 12.5, 0.0)
	var nmat : StandardMaterial3D = StandardMaterial3D.new()
	nmat.albedo_color = _node_bar_color()
	nmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_node_bar.material_override = nmat
	_node_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_node_bar.scale.x = 0.0
	add_child(_node_bar)

	_con_rig = _CON_RIG.new()
	add_child(_con_rig)
	_con_rig.call("setup", FactionManager.active_faction, _body_root, _body_mats, _height + 10.0, 36.0)

	_refresh_build_visual()

func _node_bar_color() -> Color:
	match _faction:
		"architects": return Color(1.0, 0.78, 0.35)   ## compound amber
		"bloom":      return Color(0.55, 1.0, 0.55)   ## growth green
		"mesh":       return Color(0.45, 0.85, 1.0)   ## network blue
	return Color.WHITE

func _update_node_bar() -> void:
	if _node_bar == null:
		return
	var frac : float = _node_frac()
	if _faction == "mesh":
		frac = clampf(float(_links) / 3.0, 0.0, 1.0)
	_node_bar.visible = _built and frac > 0.01
	_node_bar.scale.x = frac

const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")
const _CON_RIG   = preload("res://src/vfx/ConstructionRig.gd")

## V3: garrison bodies carry the player faction's substrate.
func _mat(col: Color) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	_SUBSTRATE.apply(m, FactionManager.active_faction)
	_body_mats.append(m)
	return m
