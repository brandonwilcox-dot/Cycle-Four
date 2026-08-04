## Tower.gd
## A placed defense tower. Scans for the nearest unit in range each attack cycle and calls
## take_damage() on it (instant hit; the tracer is cosmetic). Visual encodes tier + stats.
##
## 3D MIGRATION (Stage 2b): now `extends Node3D`. The tower is static, so its plane position `_p`
## is fixed at placement; the 3D transform follows via World3D. Cross-entity reads go through
## plane_pos()/World3D.node_plane(). The A1 stat-driven silhouette is re-expressed as MeshInstance3D
## bodies: a tier-sided body (cylinder w/ 4/6/8 segments), stat-driven barrels (count~fire-rate,
## length~range, thickness~damage) on a turret that yaws to the target, a damage-type-tinted emissive
## core, and a role emblem (support halo / detector antenna). 2D overlay widgets (XP bar, chevrons)
## are deferred to a later polish pass — their logic null-guards on the missing nodes.
extends Node3D

const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")
const WORLD3D       = preload("res://src/core/World3D.gd")
const ASSETS        = preload("res://src/core/AssetLoader.gd")
const STRUCTURE_LIGHTING = preload("res://src/vfx/StructureEmissionLighting.gd")
## Baked from the bastion's diffuse (Rodin De-light leaves the cyan channels as dark insets):
## a mip-safe grayscale mask that multiply-gates the cyan emission. See DESIGN-GUIDELINES.md.
const ARCH_BASTION_EMISSION_MASK = preload("res://assets/models/buildings/architect_plasma_bastion_hifi_emission_mask.png")
const ARCH_SPIRE_EMISSION_MASK = preload("res://assets/models/buildings/architect_sentry_spire_hifi_emission_mask.png")

## Targeting priority the player can cycle from the InspectionPanel (TD staple).
enum TargetMode { CLOSEST, FIRST, LAST, STRONGEST }
const TARGET_MODE_NAMES : Array = ["Closest", "First", "Last", "Strongest"]
var target_mode : int = TargetMode.CLOSEST

## Phase 9 progression constants.
const XP_BASE_THRESHOLD   : float = 50.0
const XP_LEVEL_EXPONENT   : float = 2.0
const DAMAGE_PER_LEVEL    : float = 0.15
const TOWER_MAX_LEVEL      : int = 10
const TOWER_SIGHT_BASE     : int = 3
const TOWER_SIGHT_PER_STEP : int = 3
const TOWER_SIGHT_BONUS_MAX : int = 3
const TOWER_SENSOR_EXTRA   : int = 2

## Pass 3 "Tower Mastery".
const BUFF_RECOMPUTE_PERIOD  : float = 0.5
const VETERAN_AURA_RADIUS    : float = 160.0
const VETERAN_AURA_BONUS     : float = 0.10
const TERRITORY_DAMAGE_BONUS : float = 0.15

## A1 visual identity (re-expressed in 3D). ROLE marks support/detector towers.
enum { ROLE_DAMAGE, ROLE_SUPPORT, ROLE_DETECTOR }
const DAMAGE_CORE : Array[Color] = [
	Color(1.0, 0.92, 0.55),   ## Kinetic   — gold
	Color(0.50, 0.88, 1.0),   ## Energy    — cyan
	Color(0.60, 1.0, 0.55),   ## Corrosive — green
]
## Turret aim: _aim_angle (plane radians) lerps toward the target bearing; applied as the turret's yaw.
const AIM_SCAN_PERIOD : float = 0.1
const AIM_TURN_RATE   : float = 9.0
## Authored crowns also ELEVATE. A tower muzzle sits 48-60u up while its targets stand at
## UNIT_HIT_Y, so a barrel locked horizontal needs 22-26 degrees of depression at close range —
## the tracer visibly kinks as it leaves the bore. Pitch removes that at every range; extending
## the tower's range only helps the far shots (7.2 deg at 256 vs 22.0 deg at 80).
const UNIT_HIT_Y        : float = 16.0    ## target mid-body height, matches the bolt endpoint
## Wide enough that a real firing solution is never clipped. A clamp that bites is what broke
## the first arc pass: the shell launched at 37° while the barrel sat at its 12° limit, so the
## round visibly left the bore at the wrong angle. The barrel angle must BE the launch angle.
const AIM_PITCH_MAX     : float = deg_to_rad(50.0)   ## depression (barrel down)
const AIM_PITCH_MIN     : float = deg_to_rad(-55.0)  ## elevation (barrel up, for lobs)
var _aim_angle        : float = 0.0
var _aim_target_angle : float = 0.0
var _aim_pitch        : float = 0.0
var _aim_target_pitch : float = 0.0
var _aim_scan_timer   : float = 0.0
## Ballistic shell params (muzzle speed, drag rate, gravity). ZERO = flat direct fire.
var _ballistics       : Vector3 = Vector3.ZERO
## Cached solve for the current target: (vertical launch speed, flight time).
var _shot_solution    : Vector2 = Vector2.ZERO
## Separable barrel group, pitched about its trunnion. When present the housing stays level and
## seated in its collar, and recoil slides the barrels back instead of lifting the whole crown.
var _barrels          : Node3D = null
var _barrel_origin    : Vector3 = Vector3.ZERO

## Construction (Phase 2B).
const MAX_HEALTH   : float = 100.0
const START_HEALTH : float = 10.0

var data: Resource = null   ## TowerData instance
var _p   : Vector2 = Vector2.ZERO   ## fixed plane position (pixel units)
var _attack_timer: float = 0.0

## Phase 9: level + XP.
var level              : int   = 1
var xp                 : float = 0.0
var xp_to_next         : float = XP_BASE_THRESHOLD
var _damage_multiplier : float = 1.0
var _aura_recv_mult    : float = 1.0
var _territory_mult    : float = 1.0
var _buff_timer        : float = 0.0
var _xp_bar            : Node = null   ## deferred (3D overlay polish); logic null-guards
var _chevrons          : Node = null   ## deferred
var _map_grid          : Node = null

## Construction state.
var _max_health : float = MAX_HEALTH
var _health     : float = MAX_HEALTH
var _built      : bool  = true

## Phase 4A/4B faction perks.
var _growth_mult   : float = 1.0
var _growth_stacks : int   = 0
var _grow_timer    : float = 0.0
var _chain_mult    : float = 1.0
var _pollen_timer  : float = 0.0
var _hijack_timer  : float = 2.0

## 3D visual nodes.
var _turret    : Node3D = null
var _muzzles   : Array[Vector3] = []   ## per-barrel tip, in TURRET-local space (fire origin per cannon)
## Authored GLB tower: the crown mesh is split off the hull and parented to _turret so it
## ROTATES to track targets. Its cannons face model +Z (Rodin front), where the procedural
## turret's barrels face +X — hence the yaw offset and the +Z recoil axis.
var _glb_tower     : bool    = false
var _turret_origin : Vector3 = Vector3.ZERO   ## rest position of the turret node (recoil returns here)
var _body_root : Node3D = null   ## body parts container (construction rig scales/tints it)
var _con_rig   : Node3D = null   ## per-faction construction effect (grow / carve / assemble)
var _recoil    : float = 0.0   ## V4: 1.0 on fire → decays; turret kicks back along the barrels
var _body_mats : Array[StandardMaterial3D] = []   ## for ghosting (construction)
var _build_bar : MeshInstance3D = null
var _base_height : float = 40.0

## Called by the placer before adding to the scene tree. start_built=true for save-restore.
func setup(tower_data: Resource, start_built: bool = false) -> void:
	data    = tower_data
	_max_health = MAX_HEALTH * FACTION_PERKS.health_mult(FactionManager.active_faction)
	_built  = start_built
	_health = _max_health if start_built else START_HEALTH

## Fix the tower's plane position (and 3D transform). Call before or after adding to the tree.
func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

## The cross-entity contract: this tower's logical plane position.
func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("towers")
	if data == null:
		push_error("Tower: no TowerData -- call setup() before adding to tree.")
		return
	position = WORLD3D.to3(_p, 0.0)
	_build_visual()
	_refresh_detector_group()
	call_deferred("_register_apron")

## Perimeter path apron (2026-07-21): every placed structure gets a ring of worked-path
## ground (visual-only, MapGrid data texture). Registered while the structure stands;
## _exit_tree covers sell, enemy destruction, and deploy resets alike.
func _register_apron() -> void:
	if not is_inside_tree():
		return
	var grid : Node = get_tree().get_first_node_in_group("map_grid")
	if grid != null and grid.has_method("add_structure_apron"):
		grid.call("add_structure_apron", grid.call("world_to_cell", _p), 1)

func _exit_tree() -> void:
	var grid : Node = get_tree().get_first_node_in_group("map_grid")
	if grid != null and grid.has_method("remove_structure_apron"):
		grid.call("remove_structure_apron", grid.call("world_to_cell", _p))

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
		_built = true
		var nm : String = str(data.get("tower_name")) if data.get("tower_name") != null else "Tower"
		EventBus.notification_pushed.emit("%s online." % nm, "positive")
	_refresh_build_visual()
	return true

func _process(delta: float) -> void:
	if data == null:
		return
	if not _built:
		return   ## under construction — inert
	_update_aim(delta)
	_attack_timer += delta
	if _attack_timer >= 1.0 / data.attack_speed:
		_attack_timer = 0.0
		_try_attack()
	_buff_timer -= delta
	if _buff_timer <= 0.0:
		_buff_timer = BUFF_RECOMPUTE_PERIOD
		_recompute_buffs()
	if _growth_stacks < FACTION_PERKS.BLOOM_GROW_MAX_STACKS and FactionManager.active_faction == "bloom":
		_grow_timer += delta
		if _grow_timer >= FACTION_PERKS.BLOOM_GROW_INTERVAL:
			_grow_timer = 0.0
			_apply_growth()
	if FactionManager.active_faction == "bloom":
		_pollen_timer -= delta
		if _pollen_timer <= 0.0:
			_pollen_timer = FACTION_PERKS.BLOOM_POLLEN_REFRESH
			_emit_pollen()
	if FactionManager.active_faction == "mesh":
		_hijack_timer -= delta
		if _hijack_timer <= 0.0:
			_hijack_timer = FACTION_PERKS.MESH_HIJACK_COOLDOWN if _try_hijack() else 0.5

## Replaces this tower's data with the next tier and rebuilds the visual in place.
func upgrade(next_data: Resource) -> void:
	data = next_data
	for child in get_children():
		child.queue_free()
	_turret = null
	_body_root = null
	_con_rig = null
	_body_mats.clear()
	_build_bar = null
	_glb_tower = false       ## reset — the next tier decides (procedural barrels vs authored crown)
	_turret_origin = Vector3.ZERO
	_ballistics = Vector3.ZERO   ## only the siege battery lobs; other tiers are direct fire
	_shot_solution = Vector2.ZERO
	_barrels = null
	_barrel_origin = Vector3.ZERO
	_aim_pitch = 0.0
	_aim_target_pitch = 0.0
	_build_visual()
	if _con_rig != null:
		_con_rig.call("flourish")   ## the faction's construction signature marks the upgrade
	_refresh_detector_group()

## -- Combat --

func _try_attack() -> void:
	var target : Node = _select_target()
	if target != null and target.has_method("take_damage"):
		var effective_damage : float = data.damage * _damage_multiplier * _aura_recv_mult * _territory_mult * _growth_mult * _chain_mult
		var dt : int = int(data.damage_type)
		var tpos : Vector2 = WORLD3D.node_plane(target)
		_aim_target_angle = (tpos - _p).angle()
		_aim_target_pitch = _aim_pitch_to(tpos)
		## Cosmetic tracer/muzzle — fire one from each barrel tip (upgraded towers have 2+ cannons),
		## transforming each turret-local muzzle to world plane so the blast leaves the cannon, not center.
		if _turret != null and not _muzzles.is_empty():
			var gun : Node3D = _gun_node()
			## Flight parameters for a ballistic shell: (muzzle speed, vertical launch speed,
			## gravity, drag). _shot_solution was cached by the same solve that set the barrel
			## elevation, so the visual trajectory and the firing solution cannot disagree.
			var flight : Vector4 = Vector4.ZERO
			if _ballistics != Vector3.ZERO and _shot_solution.y > 0.0:
				flight = Vector4(_ballistics.x, _shot_solution.x, _ballistics.z, _ballistics.y)
			for mloc in _muzzles:
				var mworld : Vector3 = gun.to_global(mloc)
				var mp : Vector2 = WORLD3D.to2(mworld)
				if _glb_tower:
					var col : Color = Vfx.damage_color(dt)
					Vfx.pulse_at(mp, col, 13.0, 0.1, mworld.y)
					## A ballistic round reads as heavy ordnance, so it gets the ROCKET body +
					## trail rather than the flat tracer the direct-fire towers use.
					var kind : int = 3 if flight != Vector4.ZERO else 0   ## ROCKET / BULLET
					Vfx.bolt_from_to(mp, mworld.y, tpos, UNIT_HIT_Y, col, kind, flight)
				else:
					Vfx.muzzle(mp, dt)
					Vfx.bolt(mp, tpos, dt)
		else:
			Vfx.muzzle(_p, dt)
			Vfx.bolt(_p, tpos, dt)
		_recoil = 1.0   ## V4: turret kick (re-seats in _update_aim)
		var killed : bool = target.take_damage(effective_damage, dt)
		if killed:
			_award_xp_for_kill(target)

func _select_target() -> Node:
	var best       : Node  = null
	var best_score : float = 0.0
	var have       : bool  = false
	var base_pos   : Vector2 = _base_pos()
	var grid       : Node  = _get_map_grid()
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var upos : Vector2 = WORLD3D.node_plane(unit)
		var d : float = _p.distance_to(upos)
		if d > data.range:
			continue
		if unit.has_method("is_detectable") and not unit.call("is_detectable"):
			continue
		if grid != null and grid.call("is_in_spawn_dmz", upos):
			continue
		var score : float
		match target_mode:
			TargetMode.STRONGEST:
				score = float(unit.get("_current_health")) if unit.get("_current_health") != null else 0.0
			TargetMode.FIRST:
				score = -base_pos.distance_to(upos)
			TargetMode.LAST:
				score = base_pos.distance_to(upos)
			_:  ## CLOSEST
				score = -d
		if not have or score > best_score:
			best       = unit
			best_score = score
			have       = true
	return best

func _base_pos() -> Vector2:
	var b : Node = get_tree().get_first_node_in_group("base")
	return WORLD3D.node_plane(b) if b != null else _p

func cycle_target_mode() -> void:
	target_mode = (target_mode + 1) % TARGET_MODE_NAMES.size()

func target_mode_name() -> String:
	return TARGET_MODE_NAMES[target_mode]

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
		xp = 0.0
	_update_xp_bar()

func _update_xp_bar() -> void:
	if _xp_bar != null and xp_to_next > 0.0:
		_xp_bar.call("set_progress", xp / xp_to_next)

func _level_up() -> void:
	level += 1
	_damage_multiplier = pow(1.0 + DAMAGE_PER_LEVEL, float(level - 1))
	xp_to_next = XP_BASE_THRESHOLD * pow(float(level), XP_LEVEL_EXPONENT)
	EventBus.tower_leveled_up.emit(self, level)
	if _chevrons != null:
		_chevrons.call("set_rank", level - 1)
	_apply_sight()
	_recompute_buffs()

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

func _get_map_grid() -> Node:
	if _map_grid == null or not is_instance_valid(_map_grid):
		_map_grid = get_tree().get_first_node_in_group("map_grid")
	return _map_grid

func _apply_sight() -> void:
	var grid : Node = _get_map_grid()
	if grid == null:
		return
	var cell  : Vector2i = grid.world_to_cell(_p)
	@warning_ignore("integer_division")
	var sight : int = TOWER_SIGHT_BASE + mini(level / TOWER_SIGHT_PER_STEP, TOWER_SIGHT_BONUS_MAX)
	grid.call("reveal_area", cell, sight)
	grid.call("sense_area", cell, sight, sight + TOWER_SENSOR_EXTRA)

## -- Pass 3: aura / support / territory --

func provides_aura() -> bool:
	return get_aura_radius() > 0.0 and get_aura_bonus() > 0.0

func get_aura_radius() -> float:
	var r : float = float(data.aura_radius) if data != null and data.get("aura_radius") != null else 0.0
	if level >= TOWER_MAX_LEVEL:
		r = maxf(r, VETERAN_AURA_RADIUS)
	return r

func get_aura_bonus() -> float:
	var b : float = float(data.aura_damage_bonus) if data != null and data.get("aura_damage_bonus") != null else 0.0
	if level >= TOWER_MAX_LEVEL:
		b = maxf(b, VETERAN_AURA_BONUS)
	return b

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
		if _p.distance_to(WORLD3D.node_plane(other)) <= radius:
			best_bonus = maxf(best_bonus, float(other.call("get_aura_bonus")))
	_aura_recv_mult = 1.0 + best_bonus
	_territory_mult = 1.0 + (TERRITORY_DAMAGE_BONUS if _on_claimed_ground() else 0.0)
	_chain_mult = _compute_chain_mult() if FactionManager.active_faction == "mesh" else 1.0

func _apply_growth() -> void:
	_growth_stacks += 1
	_growth_mult = pow(1.0 + FACTION_PERKS.BLOOM_GROW_DAMAGE_PCT, float(_growth_stacks))
	var grow_hp : float = _max_health * FACTION_PERKS.BLOOM_GROW_HEALTH_PCT
	_max_health += grow_hp
	_health = minf(_max_health, _health + grow_hp)
	scale = Vector3.ONE * (1.0 + 0.03 * float(_growth_stacks))

func _compute_chain_mult() -> float:
	var towers : Array = get_tree().get_nodes_in_group("towers")
	var degree : int = 0
	for t in towers:
		if t == self or not _is_linkable(t):
			continue
		if _p.distance_to(WORLD3D.node_plane(t)) <= FACTION_PERKS.MESH_LINK_RANGE:
			degree += 1
	if degree > 1:
		return 1.0
	var comp : int = _chain_component_size(towers)
	return 1.0 + float(maxi(0, comp - 1)) * FACTION_PERKS.MESH_CHAIN_DAMAGE_PCT

func _is_linkable(t) -> bool:
	return is_instance_valid(t) and t.has_method("is_built") and bool(t.call("is_built"))

func _chain_component_size(towers: Array) -> int:
	var visited : Dictionary = {}
	visited[self] = true
	var stack : Array = [self]
	while not stack.is_empty():
		var cur : Node = stack.pop_back()
		var cur_p : Vector2 = WORLD3D.node_plane(cur)
		for t in towers:
			if visited.has(t) or not _is_linkable(t):
				continue
			if cur_p.distance_to(WORLD3D.node_plane(t)) <= FACTION_PERKS.MESH_LINK_RANGE:
				visited[t] = true
				stack.append(t)
	return visited.size()

func _emit_pollen() -> void:
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not u.has_method("apply_pollen"):
			continue
		if _p.distance_to(WORLD3D.node_plane(u)) <= FACTION_PERKS.BLOOM_POLLEN_RADIUS:
			u.call("apply_pollen", FACTION_PERKS.BLOOM_POLLEN_DURATION)

func _try_hijack() -> bool:
	var best : Node = null
	var best_d : float = FACTION_PERKS.MESH_HIJACK_RADIUS
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not u.has_method("apply_hijack"):
			continue
		var d : float = _p.distance_to(WORLD3D.node_plane(u))
		if d <= best_d:
			best_d = d
			best = u
	if best == null:
		return false
	best.call("apply_hijack", FACTION_PERKS.MESH_HIJACK_DURATION)
	return true

## Continuously rotate the turret toward the current target (yaw), tracking every frame.
func _update_aim(delta: float) -> void:
	_aim_scan_timer -= delta
	if _aim_scan_timer <= 0.0:
		_aim_scan_timer = AIM_SCAN_PERIOD
		var tgt : Node = _select_target()
		if tgt != null:
			var tp : Vector2 = WORLD3D.node_plane(tgt)
			_aim_target_angle = (tp - _p).angle()
			_aim_target_pitch = _aim_pitch_to(tp)
	_aim_angle = lerp_angle(_aim_angle, _aim_target_angle, minf(1.0, AIM_TURN_RATE * delta))
	_aim_pitch = lerpf(_aim_pitch, _aim_target_pitch, minf(1.0, AIM_TURN_RATE * delta))
	if _turret != null:
		## plane angle → 3D yaw. Procedural barrels face local +X; the authored crown's cannons
		## face local +Z, so it needs a quarter-turn offset to point the same way. The turret
		## ring only ever YAWS — elevation belongs to the trunnion below.
		var yaw : float = -_aim_angle + (PI * 0.5 if _glb_tower else 0.0)
		if _recoil > 0.0:
			_recoil = maxf(0.0, _recoil - delta * 6.0)
		if _barrels != null:
			## Split crown: housing stays level and seated, only the gun group elevates, and
			## recoil slides the barrels back INTO the housing along their own axis.
			_turret.rotation = Vector3(0.0, yaw, 0.0)
			_turret.position = _turret_origin
			_barrels.rotation = Vector3(_aim_pitch, 0.0, 0.0)
			_barrels.position = _barrel_origin - _barrels.basis.z * (5.0 * _recoil)
		else:
			## Fused crown (no barrel group authored): pitch the whole thing, but recoil only
			## along the HORIZONTAL barrel line. Following a pitched barrel adds a vertical
			## kick that visibly lifts the crown out of its collar every time it fires.
			_turret.rotation = Vector3(_aim_pitch if _glb_tower else 0.0, yaw, 0.0)
			var fwd : Vector3 = _turret.basis.z if _glb_tower else _turret.basis.x
			fwd.y = 0.0
			if fwd.length_squared() > 0.001:
				fwd = fwd.normalized()
			_turret.position = _turret_origin - fwd * (5.0 * _recoil)

## The node the barrels belong to — the pitching group when the model has one, else the crown.
func _gun_node() -> Node3D:
	return _barrels if _barrels != null else _turret

## Barrel elevation to put a round on `tpos`, in local radians (+ = depression, barrel down).
##
## Direct-fire towers simply point at the target. A BALLISTIC tower solves the shot properly:
## horizontal travel decays with drag, so x(s) = vx0·(1 − e^(−k·s))/k inverts to a closed-form
## flight time, and the vertical launch speed follows from Δy = vy0·T − ½g·T². The barrel angle
## is then atan2(vy0, vx0) — the TRUE launch direction, so the round always leaves collinear
## with the bore. No search, no clamp that bites, no divergence.
##
## Also caches the solve so the shot fired this frame uses exactly the angle the barrel holds.
func _aim_pitch_to(tpos: Vector2) -> float:
	if not _glb_tower or _muzzles.is_empty():
		return 0.0
	var horiz : float = maxf(_p.distance_to(tpos), 1.0)
	var rise : float = UNIT_HIT_Y - _muzzle_height()
	if _ballistics == Vector3.ZERO:
		return clampf(-atan2(rise, horiz), AIM_PITCH_MIN, AIM_PITCH_MAX)
	var vx0 : float = _ballistics.x
	var k : float = _ballistics.y
	var g : float = _ballistics.z
	## Beyond vx0/k the round can never arrive however it is aimed — hold max elevation.
	if k * horiz >= vx0 * 0.995:
		_shot_solution = Vector2.ZERO
		return AIM_PITCH_MIN
	var flight : float = -log(1.0 - k * horiz / vx0) / k
	var vy0 : float = (rise + 0.5 * g * flight * flight) / flight
	_shot_solution = Vector2(vy0, flight)
	return clampf(-atan2(vy0, vx0), AIM_PITCH_MIN, AIM_PITCH_MAX)

## Muzzle height above the tower's ground plane, taken at rest so it doesn't chase the pitch.
##
## Muzzles are stored RELATIVE to whichever node carries them, so rebuilding the absolute
## height means adding every offset back: the barrel group's own origin (when the model has
## one) AND the turret pivot. The pivot term used to be omissible because every pivot was
## y=0; it no longer is, and without it a raised pivot silently under-reports muzzle height,
## which feeds `_aim_pitch_to` a wrong `rise` and mis-aims every shot.
func _muzzle_height() -> float:
	if _muzzles.is_empty():
		return _base_height
	return float(_muzzles[0].y) + (_barrel_origin.y if _barrels != null else 0.0) + _turret_origin.y

## Recursive case-insensitive node-name search (finds "bastion_crown" from "crown").
func _find_child_named(node: Node, needle: String) -> Node3D:
	for c in node.get_children():
		if c is Node3D and needle.to_lower() in String(c.name).to_lower():
			return c
		var deeper : Node3D = _find_child_named(c, needle)
		if deeper != null:
			return deeper
	return null

func _tier_sides(t: int) -> int:
	return [4, 6, 8][clampi(t - 1, 0, 2)]

func _role() -> int:
	if data == null:
		return ROLE_DAMAGE
	var aura : float = float(data.get("aura_radius")) if data.get("aura_radius") != null else 0.0
	if aura > 0.0:
		return ROLE_SUPPORT
	var det : float = float(data.get("detector_radius")) if data.get("detector_radius") != null else 0.0
	if det > 0.0:
		return ROLE_DETECTOR
	return ROLE_DAMAGE

## Item 3: detection radius.
func get_detector_radius() -> float:
	if data == null:
		return 0.0
	var dr  : float = float(data.detector_radius) if data.get("detector_radius") != null else 0.0
	var rng : float = float(data.range) if data.get("range") != null else 0.0
	return maxf(dr, rng)

func provides_detection() -> bool:
	return get_detector_radius() > 0.0

func _refresh_detector_group() -> void:
	if provides_detection():
		if not is_in_group("detectors"):
			add_to_group("detectors")
	elif is_in_group("detectors"):
		remove_from_group("detectors")

func _on_claimed_ground() -> bool:
	var grid : Node = _get_map_grid()
	if grid == null:
		return false
	var cell : Vector2i = grid.world_to_cell(_p)
	return bool(grid.call("is_claimed", cell.x, cell.y))

## -- Visual (3D) — re-expresses the A1 stat-driven silhouette as meshes --

func _build_visual() -> void:
	_body_mats.clear()
	_muzzles.clear()
	## V4 rising construction: every body part lives under _body_root, which scales up in Y
	## with build progress (the Commander raises the structure out of the ground).
	_body_root = Node3D.new()
	add_child(_body_root)

	## Hi-fi authored tower model (Architect Plasma Bastion = tier-2), when one exists for this
	## tower resource. The fused GLB IS the tower + turret (like the FOB) — no procedural body or
	## rotating turret; the twin plasma emitters are FIXED muzzles, tracers leave them at height.
	if data != null and String(data.resource_path) in ASSETS.FACTION_TOWER_MODELS:
		var tpath : String = String(data.resource_path)
		var model : Node3D = ASSETS.load_tower_model(tpath)
		if model != null:
			_body_root.add_child(model)
			_base_height = ASSETS.tower_model_height(tpath)
			_glb_tower = true
			var mscale : float = float(ASSETS.TOWER_MODEL_SCALE.get(tpath, 40.0))
			_ballistics = ASSETS.TOWER_BALLISTICS.get(tpath, Vector3.ZERO)
			## The turret node sits at the tower origin (the crown's own verts carry its height)
			## and yaws to track targets. The crown mesh is lifted out of the imported hull and
			## reparented here, carrying the model scale itself since _turret is unscaled.
			_turret = Node3D.new()
			## The crown yaws about the ROTATION COLLAR, which is not always the model origin.
			## Offsetting the turret to the collar and the crown back by the same amount makes
			## the crown spin in place instead of orbiting the origin.
			var pivot : Vector3 = ASSETS.tower_turret_pivot(tpath)
			_turret_origin = pivot
			_turret.position = pivot
			_body_root.add_child(_turret)
			var crown : Node3D = _find_child_named(model, "crown")
			if crown != null:
				crown.get_parent().remove_child(crown)
				_turret.add_child(crown)
				crown.transform = Transform3D.IDENTITY
				crown.scale = Vector3(mscale, mscale, mscale)
				crown.position = -pivot
			## Separable gun group (models split at the trunnion). It hangs off the yawing
			## turret and owns elevation + recoil, so the housing never leaves its collar.
			var trunnion : Vector3 = ASSETS.tower_trunnion(tpath)
			var guns : Node3D = _find_child_named(model, "barrels")
			if guns != null:
				_barrels = Node3D.new()
				_barrel_origin = trunnion - pivot
				_barrels.position = _barrel_origin
				_turret.add_child(_barrels)
				guns.get_parent().remove_child(guns)
				_barrels.add_child(guns)
				guns.transform = Transform3D.IDENTITY
				guns.scale = Vector3(mscale, mscale, mscale)
				guns.position = -trunnion
			## Muzzles live in the frame of whatever node carries the barrels, so they inherit
			## that node's rotation: the gun group when one exists, else the crown itself.
			var muzzle_base : Vector3 = trunnion if _barrels != null else pivot
			for mp : Vector3 in ASSETS.tower_model_muzzles(tpath):
				_muzzles.append(mp - muzzle_base)
			## Selective emission + compact local spill (the shared structure recipe). Applied to
			## _body_root so BOTH the hull and the reparented crown get the masked cyan; the
			## emitter/crown lights ride the turret so their spill sweeps with the barrels.
			## Per-model mask + light cluster: every authored tower has its own baked mask and its
			## own measured emitter positions, so this cannot be one shared call.
			match tpath:
				"res://resources/towers/architects_t1.tres":
					STRUCTURE_LIGHTING.tune_masked_emission(_body_root, 3.0, ARCH_SPIRE_EMISSION_MASK)
					STRUCTURE_LIGHTING.add_architect_sentry_spire_turret_lights(_turret, mscale, pivot)
					STRUCTURE_LIGHTING.add_architect_sentry_spire_base_lights(self, mscale)
				"res://resources/towers/architects_t3.tres":
					## NO MASK ON PURPOSE. This export has no emissive map and its diffuse cannot
					## yield one, so a colour-derived mask would be noise (the Garrison Keep
					## mistake). Passing null leaves emission off; the light cluster plus the
					## procedural inserts below carry the cyan until a Blender emissive pass lands.
					STRUCTURE_LIGHTING.tune_masked_emission(_body_root, 3.0, null)
					STRUCTURE_LIGHTING.add_architect_siege_foundry_turret_lights(_turret, mscale, pivot)
					STRUCTURE_LIGHTING.add_architect_siege_foundry_base_lights(self, mscale)
					STRUCTURE_LIGHTING.add_architect_siege_foundry_inserts(
						_gun_node(), _body_root, mscale, muzzle_base)
				_:
					STRUCTURE_LIGHTING.tune_masked_emission(_body_root, 3.0, ARCH_BASTION_EMISSION_MASK)
					STRUCTURE_LIGHTING.add_architect_plasma_bastion_turret_lights(_turret, mscale, pivot)
					STRUCTURE_LIGHTING.add_architect_plasma_bastion_base_lights(self, mscale)
			## Construction/repair bar above the bastion.
			_build_bar = MeshInstance3D.new()
			var gqm : QuadMesh = QuadMesh.new()
			gqm.size = Vector2(70.0, 5.0)
			_build_bar.mesh = gqm
			_build_bar.position = Vector3(0.0, _base_height + 12.0, 0.0)
			var gbm : StandardMaterial3D = StandardMaterial3D.new()
			gbm.albedo_color = Color(0.45, 1.0, 0.7)
			gbm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			gbm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			_build_bar.material_override = gbm
			_build_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_build_bar)
			_con_rig = _CON_RIG.new()
			add_child(_con_rig)
			_con_rig.call("setup", FactionManager.active_faction, _body_root, _body_mats, _base_height + 12.0, 44.0)
			_refresh_build_visual()
			return

	var tier   : int   = int(data.get("tier")) if data.get("tier") else 1
	var col    : Color = data.color_hint
	var body_r : float = 18.0 + tier * 6.0          ## 24 / 30 / 36
	_base_height       = 30.0 + tier * 10.0          ## 40 / 50 / 60 — taller than units, shorter than FOB
	var sides  : int   = _tier_sides(tier)

	## Body — a tier-sided frustum.
	var body : MeshInstance3D = MeshInstance3D.new()
	var cyl : CylinderMesh = CylinderMesh.new()
	cyl.top_radius = body_r * 0.7
	cyl.bottom_radius = body_r
	cyl.height = _base_height
	cyl.radial_segments = sides
	body.mesh = cyl
	body.position = Vector3(0.0, _base_height * 0.5, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.material_override = _mat(col.darkened(0.1))
	_body_root.add_child(body)

	## Tier rings around the base (one per tier) — quick tier read.
	for i in tier:
		var ring : MeshInstance3D = MeshInstance3D.new()
		var tm : TorusMesh = TorusMesh.new()
		tm.inner_radius = body_r + 2.0 + float(i) * 4.0
		tm.outer_radius = tm.inner_radius + 2.5
		ring.mesh = tm
		ring.position = Vector3(0.0, 2.0 + float(i) * 2.0, 0.0)
		ring.material_override = _mat(col.lightened(0.15))
		_body_root.add_child(ring)

	## Turret + barrels (built along +X; yawed to the target in _update_aim).
	_turret = Node3D.new()
	_turret_origin = Vector3(0.0, _base_height, 0.0)
	_turret.position = _turret_origin
	_body_root.add_child(_turret)
	var count  : int   = clampi(int(round(float(data.attack_speed))), 1, 4)
	var blen   : float = clampf(remap(float(data.range), 150.0, 320.0, 18.0, 46.0), 18.0, 46.0)
	var bwid   : float = clampf(remap(float(data.damage), 10.0, 70.0, 5.0, 14.0), 5.0, 14.0)
	var spread : float = 0.0 if count == 1 else 10.0   ## px lateral offset between barrels
	for i in count:
		var barrel : MeshInstance3D = MeshInstance3D.new()
		var bx : BoxMesh = BoxMesh.new()
		bx.size = Vector3(blen, bwid, bwid)
		barrel.mesh = bx
		var off : float = 0.0 if count == 1 else lerpf(-spread, spread, float(i) / float(count - 1))
		barrel.position = Vector3(body_r * 0.5 + blen * 0.5, 0.0, off)   ## +X, base near body
		barrel.material_override = _mat(col.darkened(0.35))
		_turret.add_child(barrel)
		_muzzles.append(Vector3(body_r * 0.5 + blen, 0.0, off))   ## barrel tip (far end) — each fires its own tracer

	## Core gem — damage-type tinted, emissive (matches the tracer).
	var core : MeshInstance3D = MeshInstance3D.new()
	var sp : SphereMesh = SphereMesh.new()
	sp.radius = body_r * 0.34
	sp.height = body_r * 0.68
	core.mesh = sp
	core.position = Vector3(0.0, _base_height + body_r * 0.2, 0.0)
	var ccol : Color = DAMAGE_CORE[clampi(int(data.damage_type), 0, DAMAGE_CORE.size() - 1)]
	var cmat : StandardMaterial3D = _mat(ccol)
	cmat.emission_enabled = true
	cmat.emission = ccol
	cmat.emission_energy_multiplier = 1.6
	cmat.emission_texture = null       ## the core gem is pure damage-type color — no substrate
	cmat.uv1_triplanar = false         ## pattern (readability: it must match the tracer exactly)
	core.material_override = cmat
	_body_root.add_child(core)

	## Role emblem: support = gold halo torus; detector = antenna mast + tip.
	var role : int = _role()
	if role == ROLE_SUPPORT:
		var halo : MeshInstance3D = MeshInstance3D.new()
		var ht : TorusMesh = TorusMesh.new()
		ht.inner_radius = body_r + 8.0
		ht.outer_radius = body_r + 11.0
		halo.mesh = ht
		halo.position = Vector3(0.0, _base_height + 14.0, 0.0)
		halo.material_override = _mat(Color(1.0, 0.95, 0.6))
		_body_root.add_child(halo)
	elif role == ROLE_DETECTOR:
		var mast : MeshInstance3D = MeshInstance3D.new()
		var mb : BoxMesh = BoxMesh.new()
		mb.size = Vector3(2.5, 22.0, 2.5)
		mast.mesh = mb
		mast.position = Vector3(0.0, _base_height + 18.0, 0.0)
		mast.material_override = _mat(Color(0.7, 0.95, 1.0))
		_body_root.add_child(mast)
		var tip : MeshInstance3D = MeshInstance3D.new()
		var ts : SphereMesh = SphereMesh.new()
		ts.radius = 4.0
		ts.height = 8.0
		tip.mesh = ts
		tip.position = Vector3(0.0, _base_height + 30.0, 0.0)
		tip.material_override = _mat(Color(0.8, 0.97, 1.0))
		_body_root.add_child(tip)

	## Construction/repair bar — billboarded above the tower; shown while building/damaged.
	_build_bar = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(body_r * 1.6, 5.0)
	_build_bar.mesh = qm
	_build_bar.position = Vector3(0.0, _base_height + body_r + 6.0, 0.0)
	var bmat : StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.45, 1.0, 0.7)
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_build_bar.material_override = bmat
	_build_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_build_bar)

	_con_rig = _CON_RIG.new()
	add_child(_con_rig)
	_con_rig.call("setup", FactionManager.active_faction, _body_root, _body_mats, _base_height + 16.0, body_r + 10.0)

	_refresh_build_visual()

const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")
const _CON_RIG   = preload("res://src/vfx/ConstructionRig.gd")

## Builds a StandardMaterial3D, tracking it so ghosting can fade the whole tower while unbuilt.
## V3: body parts carry the player faction's substrate (crystalline / organic / conductive).
func _mat(col: Color) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	_SUBSTRATE.apply(m, FactionManager.active_faction)
	_body_mats.append(m)
	return m

## Ghosts the tower (alpha) while under construction and drives the build bar.
func _refresh_build_visual() -> void:
	var frac : float = clampf(_health / _max_health, 0.0, 1.0)
	if _build_bar != null:
		_build_bar.visible = _health < _max_health
		_build_bar.scale.x = frac
	## Per-faction construction language lives in the rig (grow / carve / drone-assemble).
	if _con_rig != null:
		_con_rig.call("update", frac, _built)
