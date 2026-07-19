## FriendlyUnit.gd
## Phase C (C1) — a friendly army unit produced by a garrison. Holds/defends near its home garrison
## (leashed), acquires nearby enemies, fires through the triangle, takes attrition, dies.
##
## 3D MIGRATION (Stage 2h): now `extends Node3D` (model/view). Logical plane pos `_p` drives the
## transform via World3D; cross-entity reads via plane_pos()/World3D.node_plane(). Behavior stays in
## update(delta) so the C4 offline sim can fast-forward it. Visual is a 3D box + friendly ground ring
## + billboard health bar (was ColorRects).
extends Node3D

const Combat = preload("res://src/combat/Combat.gd")
const WORLD3D = preload("res://src/core/World3D.gd")
const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")
const UNIT_BODIES = preload("res://src/vfx/UnitBodies.gd")
const ASSET_LOADER = preload("res://src/core/AssetLoader.gd")
const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")
const BALANCE = preload("res://src/core/Balance.gd")
const FRIENDLY_ROSTER = preload("res://src/core/army/FriendlyRoster.gd")   ## U4 heresy lookup
const COSMETICS = preload("res://src/core/cosmetics/Cosmetics.gd")   ## player unit customization
const UNIT_MODIFIER = preload("res://src/entities/UnitModifier.gd")         ## U4 Kind enum

const AGGRO_RADIUS    : float = 240.0
const BLOCK_RANGE     : float = 28.0
const ARRIVE_DIST     : float = 4.0
const PATROL_RADIUS        : float = 120.0
const PATROL_ANGULAR_SPEED : float = 0.6

var data       : UnitData = null
var _p          : Vector2  = Vector2.ZERO
var _home       : Vector2  = Vector2.ZERO
var _faction    : String   = ""
## U0: per-faction tether radius (Architect wide / Bloom mid / Mesh short). The garrison
## may re-scale it (U1: Bloom maturity growth) via set_leash().
var _leash      : float    = 220.0
## U1 node-identity dials, driven by the home garrison each production tick (never by the
## player — auras apply automatically in radius, per the anti-micro rules).
var damage_mult : float    = 1.0   ## Bloom maturity/connection buff (garrison-driven each tick)
var rof_mult    : float    = 1.0   ## Mesh overlap targeting-share (<1.0 = faster fire)
## U3 — shared support systems (all pulled from emitter groups each frame; auras are automatic).
var _shield     : float    = 0.0   ## current absorb buffer (spent before HP)
var _shield_cap : float    = 0.0   ## ceiling granted by the strongest covering shield emitter
var _cloaked    : bool     = false ## covered by a Deceiver cloak aura this frame
## U3 — Adaptive Assault permanent growth (kept SEPARATE from damage_mult, which the Bloom node
## overwrites every production tick — adaptive must survive that).
var _self_dmg_mult : float = 1.0
var _bonus_max_hp  : float = 0.0
var _adapt_stacks  : int   = 0
## U4 — heresy modifiers (the Option B seam; mechanics only, never captioned).
var _mod_dmg_mult   : float = 1.0   ## flat damage dial from dream-stabilize / stat mods (+ rooting)
var _mod_armor      : float = 0.0   ## flat armor bonus from modifiers (+ rooting)
var _mod_speed_mult : float = 1.0   ## flat speed dial
var _absorb_radius  : float = 0.0   ## >0 → wreckage-absorb: consumes husks in this radius
var _absorb_timer   : float = 0.0
var _root_mod       : UnitModifier = null ## terrain-bond: a rooting bonus engaged while stationary
var _root_last_p    : Vector2 = Vector2(INF, INF)
var _root_timer     : float = 0.0
var _rooted         : bool  = false
var _current_health : float = 0.0
var _attack_timer   : float = 0.0
var _is_dead        : bool  = false
var _mesh           : MeshInstance3D = null
var _mat            : StandardMaterial3D = null   ## V4: for hit-flash
var _base_emission  : float = 0.0                 ## resting emission; hit-flash adds to it
var _hp_fill        : MeshInstance3D = null
var _shield_fill    : MeshInstance3D = null   ## U3: shield-buffer strip
var _garrison       : Node    = null
var _patrolling     : bool    = false
var _patrol_angle   : float   = 0.0
var _has_raid       : bool    = false
var _raid_target    : Vector2 = Vector2.ZERO
var _hit_flash      : float   = 0.0   ## V4: emission spike on damage

func setup(unit_data: UnitData, home_world: Vector2, garrison: Node = null) -> void:
	data      = unit_data
	_home     = home_world
	_garrison = garrison
	_p        = home_world
	_patrol_angle = randf() * TAU
	if data != null:
		_current_health = data.max_health

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("friendly_units")
	if data == null:
		push_error("FriendlyUnit spawned without UnitData -- call setup() first.")
		return
	_faction = FactionManager.active_faction
	_leash   = FACTION_PERKS.tether_radius(_faction)
	## U2: scout roles are stealth detectors (the "detectors" group contract).
	if data.detector_radius > 0.0:
		add_to_group("detectors")
	## U3: register support emitters into cheap dedicated groups (covered units pull from these).
	if data.provides_shield > 0.0:
		add_to_group("shield_emitters")
	if data.regen_aura > 0.0:
		add_to_group("regen_emitters")
	if data.cloak_ally:
		add_to_group("cloak_emitters")
	## U3: Adaptive Assault grows permanently for each wave it lives through.
	if data.adapt_per_wave > 0.0 and data.adapt_cap > 0:
		EventBus.wave_ended.connect(_on_wave_survived)
	## U4: apply this unit's heresy modifiers (flat durability now; rooting/absorb run per-frame).
	_apply_modifiers()
	position = WORLD3D.to3(_p, 0.0)
	_build_visual()

## U4 — gather eligible modifiers (per-unit authored slots + the committed sub-path's heresy grant)
## and apply them. The kinship this expresses is NEVER surfaced in UI, dialogue, or achievements.
func _apply_modifiers() -> void:
	var subp : String = FactionManager.active_sub_path
	var mods : Array[UnitModifier] = []
	for m in data.modifier_slots:
		if m != null and m.is_eligible(subp):
			mods.append(m)
	var h : UnitModifier = FRIENDLY_ROSTER.heretic_modifier(subp)
	if h != null:
		mods.append(h)
	for m in mods:
		match m.kind:
			UNIT_MODIFIER.Kind.TERRAIN_BOND:
				_root_mod = m                       ## conditional — engages while rooted
			UNIT_MODIFIER.Kind.WRECKAGE_ABSORB:
				_absorb_radius = maxf(_absorb_radius, m.effect_radius)
				_apply_flat_modifier(m)
			_:                                      ## STAT / DREAM_STABILIZE — flat durability/dials
				_apply_flat_modifier(m)

func _apply_flat_modifier(m: UnitModifier) -> void:
	if m.health_mult != 1.0:
		var add_hp : float = data.max_health * (m.health_mult - 1.0)
		_bonus_max_hp   += add_hp
		_current_health += add_hp
	_mod_armor      += m.armor_bonus
	_mod_dmg_mult   *= m.damage_mult
	_mod_speed_mult *= m.speed_mult

## U4 — terrain-bond "rooting": a Spiritual-Tech unit draws from the ground when it holds position,
## gaining the modifier's bonus; moving breaks the root. (F1 will additionally gate it on favored
## terrain; the movement-based root is the queryable-today expression of the same idea.)
const ROOT_TIME : float = 1.2
func _update_root(delta: float) -> void:
	if _root_mod == null:
		return
	var moving : bool = _root_last_p.is_finite() and _p.distance_squared_to(_root_last_p) > 0.25
	_root_last_p = _p
	if moving:
		_root_timer = 0.0
		if _rooted:
			_rooted = false
			_mod_dmg_mult /= _root_mod.damage_mult
			_mod_armor    -= _root_mod.armor_bonus
	else:
		_root_timer += delta
		if not _rooted and _root_timer >= ROOT_TIME:
			_rooted = true
			_mod_dmg_mult *= _root_mod.damage_mult
			_mod_armor    += _root_mod.armor_bonus

## U4 — wreckage-absorb: an Assimilator unit consumes a nearby husk for HP + resource.
const ABSORB_HEAL     : float = 30.0
const ABSORB_COOLDOWN : float = 0.4
func _update_absorb(delta: float) -> void:
	if _absorb_radius <= 0.0:
		return
	_absorb_timer -= delta
	if _absorb_timer > 0.0:
		return
	for hu in get_tree().get_nodes_in_group("husks"):
		if is_instance_valid(hu) and _p.distance_to(hu.call("plane_pos")) <= _absorb_radius:
			heal(ABSORB_HEAL)
			EconomyManager.add_resource(FactionManager.get_primary_resource(), float(hu.get("amount")))
			hu.queue_free()
			_absorb_timer = ABSORB_COOLDOWN
			return

func get_detector_radius() -> float:
	return data.detector_radius if data != null else 0.0

## U1 hook — garrisons re-scale the tether (e.g. Bloom maturity widens it).
func set_leash(radius: float) -> void:
	_leash = radius

## U3 — effective max HP includes any permanent Adaptive-Assault bonus.
func _max_hp() -> float:
	return (data.max_health if data != null else 0.0) + _bonus_max_hp

## U1 — Bloom node regen aura ("living tech heals"). U3 regen-support units heal through this too.
func heal(amount: float) -> void:
	if _is_dead or data == null or _current_health >= _max_hp():
		return
	_current_health = minf(_max_hp(), _current_health + amount)
	_update_health_visual()

## U3 — pulled every frame: shield ceiling, regen, and cloak from covering emitters. All auras
## apply automatically in radius (anti-micro §6); the covered unit reads the emitter groups so
## emitters never have to track who enters/leaves their radius.
const SHIELD_REFILL_RATE : float = 0.35   ## fraction of ceiling refilled per second while covered
func _update_support(delta: float) -> void:
	var cap : float = 0.0
	for e in get_tree().get_nodes_in_group("shield_emitters"):
		var ed : UnitData = e.get("data") if is_instance_valid(e) else null
		if ed != null and _p.distance_to(e.call("plane_pos")) <= ed.shield_radius:
			cap = maxf(cap, ed.provides_shield)
	_shield_cap = cap
	if _shield > _shield_cap:
		_shield = _shield_cap
	elif _shield < _shield_cap:
		_shield = minf(_shield_cap, _shield + _shield_cap * SHIELD_REFILL_RATE * delta)
	var hps : float = 0.0
	for e in get_tree().get_nodes_in_group("regen_emitters"):
		var ed : UnitData = e.get("data") if is_instance_valid(e) else null
		if ed != null and _p.distance_to(e.call("plane_pos")) <= ed.regen_radius:
			hps = maxf(hps, ed.regen_aura)
	if hps > 0.0:
		heal(hps * delta)
	var cloaked : bool = false
	for e in get_tree().get_nodes_in_group("cloak_emitters"):
		var ed : UnitData = e.get("data") if is_instance_valid(e) else null
		if ed != null and _p.distance_to(e.call("plane_pos")) <= ed.cloak_radius:
			cloaked = true
			break
	_cloaked = cloaked
	_update_shield_visual()

## U3 — Deceiver contract: non-detector enemies can't acquire a cloaked friendly (Unit.gd checks this).
func is_cloaked() -> bool:
	return _cloaked and not _is_dead

## U3 — Adaptive Assault: one permanent stack (damage + max HP) per wave survived, capped.
func _on_wave_survived(_wave_number: int, _result: String) -> void:
	if _is_dead or data == null or _adapt_stacks >= data.adapt_cap:
		return
	_adapt_stacks += 1
	_self_dmg_mult += data.adapt_per_wave
	var add_hp : float = data.max_health * data.adapt_per_wave
	_bonus_max_hp   += add_hp
	_current_health += add_hp   ## the veteran actually gains the HP, not just a bigger bar
	_update_health_visual()

## U1 — Mesh reroute-on-loss: when the home garrison dies, surviving units re-tether to
## the nearest Mesh node instead of orphaning ("lose a node, reroute").
func retether(home_world: Vector2, garrison: Node) -> void:
	_home     = home_world
	_garrison = garrison

func _process(delta: float) -> void:
	if _is_dead:
		return
	_animate(delta)   ## V4 gait — driven off actual movement
	update(delta)

## -- V4 motion: per-faction gait (mirrors Unit._animate; rest height is the build Y) --

const _GAIT_REST_Y : float = 10.0
const _GAIT_SETTLE : float = 8.0
const HIT_FLASH_BOOST : float = 2.5   ## emission added at peak of a damage flash

var _anim_t      : float = 0.0
var _anim_last_p : Vector2 = Vector2(INF, INF)

func _animate(delta: float) -> void:
	## V4: hit-flash emission on damage
	if _hit_flash > 0.0 and _mat != null:
		_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
		_mat.emission_energy_multiplier = _base_emission + HIT_FLASH_BOOST * _hit_flash
	if _mesh == null:
		return
	var moved : bool = _anim_last_p.is_finite() and _p.distance_squared_to(_anim_last_p) > 0.02
	_anim_last_p = _p
	if moved:
		match data.faction_id if data != null else "":
			## 2026-07-19: damped ~50% alongside the enemy gait — see Unit._animate.
			"architects":
				_anim_t += delta * 1.6
				_mesh.position.y = _GAIT_REST_Y + 1.2 + sin(_anim_t * TAU * 0.5) * 0.5
			"bloom":
				_anim_t += delta * 2.6
				_mesh.position.y = _GAIT_REST_Y + absf(sin(_anim_t * TAU * 0.5)) * 2.6
				_mesh.rotation.z = sin(_anim_t * TAU * 0.5) * 0.10
				_mesh.rotation.y = sin(_anim_t * TAU * 0.25) * 0.05
			"mesh":
				_anim_t += delta * 7.0
				_mesh.position.y = _GAIT_REST_Y + absf(sin(_anim_t * TAU * 0.5)) * 1.2
				_mesh.rotation.z = sin(_anim_t * TAU) * 0.04
				_mesh.position.z = sin(_anim_t * TAU * 0.7) * 0.8
	else:
		_mesh.position.y = lerpf(_mesh.position.y, _GAIT_REST_Y, minf(1.0, delta * _GAIT_SETTLE))
		_mesh.position.z = lerpf(_mesh.position.z, 0.0, minf(1.0, delta * _GAIT_SETTLE))
		_mesh.rotation.z = lerpf(_mesh.rotation.z, 0.0, minf(1.0, delta * _GAIT_SETTLE))
		_mesh.rotation.y = lerpf(_mesh.rotation.y, 0.0, minf(1.0, delta * _GAIT_SETTLE))

func update(delta: float) -> void:
	if data == null:
		return
	_update_support(delta)   ## U3: shield/regen/cloak auras (automatic, in-radius)
	_update_root(delta)      ## U4: terrain-bond rooting
	_update_absorb(delta)    ## U4: wreckage-absorb husk consumption
	_attack_timer += delta
	## U2: non-combatants (pure scouts) never chase — they patrol and sense.
	var target : Node = _acquire_target() if data.attack_damage > 0.0 else null
	if target != null:
		var tpos : Vector2 = WORLD3D.node_plane(target)
		var dist : float = _p.distance_to(tpos)
		if dist > BLOCK_RANGE:
			_move_toward(tpos, delta)
		if dist <= data.attack_range and _attack_timer >= data.attack_interval * rof_mult:
			_attack_timer = 0.0
			_fire(target)
	elif _has_raid:
		_move_toward(_raid_target, delta, false)
	elif _patrolling:
		_patrol(delta)
	elif _p.distance_to(_home) > ARRIVE_DIST:
		_move_toward(_home, delta)

func _acquire_target() -> Node:
	var best      : Node = null
	## U2: artillery outranges the default aggro bubble — acquisition reaches to attack range.
	var best_dist : float  = maxf(AGGRO_RADIUS, data.attack_range)
	for enemy in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_detectable") and not enemy.call("is_detectable"):
			continue
		var epos : Vector2 = WORLD3D.node_plane(enemy)
		var d : float = _p.distance_to(epos)
		## The leash constrains MOVEMENT, not fire: a target is eligible inside the node's
		## radius, or already inside this unit's own weapon range.
		if epos.distance_to(_home) > _leash and d > data.attack_range:
			continue
		## U2 Mesh direct-fire: no shooting past walls.
		if data.requires_los and not _has_los(epos):
			continue
		if d <= best_dist:
			best      = enemy
			best_dist = d
	for base in get_tree().get_nodes_in_group("enemy_bases"):
		if not is_instance_valid(base):
			continue
		var bpos : Vector2 = WORLD3D.node_plane(base)
		var bd : float = _p.distance_to(bpos)
		if bpos.distance_to(_home) > _leash and bd > data.attack_range:
			continue
		if data.requires_los and not _has_los(bpos):
			continue
		if bd <= best_dist:
			best      = base
			best_dist = bd
	return best

## U2 — direct-fire LOS: the shot line must clear every wall (F1 will add terrain).
const _LOS_BLOCK_RADIUS : float = 24.0
func _has_los(tpos: Vector2) -> bool:
	for w in get_tree().get_nodes_in_group("walls"):
		if not is_instance_valid(w):
			continue
		var wpos : Vector2 = WORLD3D.node_plane(w)
		if Geometry2D.get_closest_point_to_segment(wpos, _p, tpos).distance_to(wpos) < _LOS_BLOCK_RADIUS:
			return false
	return true

func _fire(target: Node) -> void:
	if not target.has_method("take_damage"):
		return
	var dt : int = Combat.faction_damage_type(_faction)
	Vfx.bolt(_p, WORLD3D.node_plane(target), dt)
	## damage_mult = node aura (Bloom); _self_dmg_mult = Adaptive growth (U3); _mod_dmg_mult =
	## heresy modifiers incl. active rooting (U4).
	var dmg : float = data.attack_damage * damage_mult * _self_dmg_mult * _mod_dmg_mult
	var killed : bool = bool(target.call("take_damage", dmg, dt))
	if killed and is_instance_valid(_garrison) and _garrison.has_method("report_kill"):
		_garrison.call("report_kill")

func _patrol(delta: float) -> void:
	_patrol_angle += PATROL_ANGULAR_SPEED * delta
	var point : Vector2 = _home + Vector2(cos(_patrol_angle), sin(_patrol_angle)) * PATROL_RADIUS
	_move_toward(point, delta)

func set_patrol(value: bool) -> void:
	_patrolling = value

func set_raid_target(world: Vector2) -> void:
	_raid_target = world
	_has_raid    = true

func clear_raid() -> void:
	_has_raid = false

func _move_toward(point: Vector2, delta: float, clamp_leash: bool = true) -> void:
	var step : float = data.move_speed * _mod_speed_mult * BALANCE.MOVE_SCALE * BALANCE.UNIT_MOVE_SCALE * delta
	var dir  : Vector2 = point - _p
	var np   : Vector2
	if dir.length() <= step:
		np = point
	else:
		np = _p + dir.normalized() * step
	if clamp_leash:
		var from_home : Vector2 = np - _home
		if from_home.length() > _leash:
			np = _home + from_home.normalized() * _leash
	_set_plane(np)

func _set_plane(p: Vector2) -> void:
	var d : Vector2 = p - _p
	_p = p
	position = WORLD3D.to3(_p, 0.0)
	if d.length_squared() > 0.0001:
		rotation.y = -atan2(d.y, d.x)

func take_damage(amount: float, damage_type: int = -1) -> bool:
	var mult : float = Combat.multiplier(damage_type, data.armor_type) if damage_type >= 0 else 1.0
	## U4: modifier armor (dream-stabilize durability + active rooting) stacks with base armor.
	_apply_damage(max(0.0, amount * mult - (data.armor + _mod_armor)))
	return _is_dead

func _apply_damage(flat: float) -> void:
	if _is_dead:
		return
	_hit_flash = 1.0   ## V4: visual damage feedback
	## U3: a shield buffer (from a Mobile Shield / Support-Shield emitter) soaks damage first.
	if _shield > 0.0:
		var absorbed : float = minf(_shield, flat)
		_shield -= absorbed
		flat    -= absorbed
		_update_shield_visual()
		if flat <= 0.0:
			return
	_current_health -= flat
	_update_health_visual()
	if _current_health <= 0.0:
		_is_dead = true
		## U3: Mesh Siege on-death EMP — one legible trick, fired visibly as the unit falls.
		if data != null and data.emp_on_death:
			_emp_pulse()
		## U1: the Architect compound punish — losing a tethered unit costs the node its ramp.
		if is_instance_valid(_garrison) and _garrison.has_method("report_unit_lost"):
			_garrison.call("report_unit_lost")
		queue_free()

## U3 — the Siege Bot's death trick: an EMP that stuns nearby enemies, with a blue pulse cue.
func _emp_pulse() -> void:
	Vfx.death(_p, Color(0.35, 0.7, 1.0), maxf(data.emp_radius, 40.0))
	Vfx.spark_burst(_p, Color(0.5, 0.85, 1.0), 14, 160.0)
	for e in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(e) and e.has_method("apply_stun") \
				and _p.distance_to(WORLD3D.node_plane(e)) <= data.emp_radius:
			e.call("apply_stun", data.emp_stun)

## -- Visual (3D) --

func _build_visual() -> void:
	## Friendly ground ring — marks it as ours at a glance.
	var ring : MeshInstance3D = MeshInstance3D.new()
	var tm : TorusMesh = TorusMesh.new()
	tm.inner_radius = 13.0
	tm.outer_radius = 16.0
	ring.mesh = tm
	ring.position = Vector3(0.0, 1.0, 0.0)
	ring.material_override = _unlit(Color(0.85, 0.95, 1.0, 0.9))
	add_child(ring)

	## Player cosmetics (Cosmetics.gd): friendly units are always the PLAYER's army, so
	## the customized archetype colors/parts apply here (enemy Unit.gd stays stock).
	var _ckey : String = COSMETICS.unit_key_for_role(data.role if data != null else 0)
	var _cfac : String = data.faction_id if data != null else ""
	var _ccol : Color = COSMETICS.primary_color(_cfac, _ckey,
		data.color_hint if data != null else Color.CYAN)

	## V6: GLTF model for this faction (keeps its own hi-fi materials). No-mesh pivot the
	## gait animates; scaled model parented under it (gait offsets stay in world units).
	if data != null and data.faction_id in ASSET_LOADER.FACTION_MODELS:
		var gmodel = ASSET_LOADER.load_unit_model(data.faction_id, _ccol, false)
		if gmodel != null:
			_mesh = MeshInstance3D.new()
			_mesh.position = Vector3(0.0, _GAIT_REST_Y, 0.0)
			add_child(_mesh)
			gmodel.position = Vector3.ZERO
			_mesh.add_child(gmodel)
			## Per-instance material: keep Rodin textures, add subtle faction tint + flash channel.
			_mat = ASSET_LOADER.prepare_unit_material(gmodel, _ccol)
			## Custom primary pulls harder than the subtle faction tint so the choice reads.
			if _mat != null and COSMETICS.uses_custom_colors(_cfac, _ckey):
				_mat.albedo_color = _mat.albedo_color.lerp(_ccol, COSMETICS.CUSTOM_TINT_STRENGTH)
			_base_emission = _mat.emission_energy_multiplier if _mat != null else 0.0
			COSMETICS.attach_parts(_mesh, _cfac, _ckey, 26.0, gmodel)
			return

	## Body — small faction-colored box.
	_mesh = MeshInstance3D.new()
	_mesh.position = Vector3(0.0, 10.0, 0.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = _ccol
	if data != null:
		## V3: army wears its faction's substrate (animate=false: small moving bodies
		## don't need the shared breathe/scroll — their gait carries the life).
		_SUBSTRATE.apply(m, data.faction_id, false)
		COSMETICS.style_material(m, _cfac, _ckey)
	_mesh.material_override = m
	_mat = m   ## V4: for hit-flash
	_base_emission = m.emission_energy_multiplier if m.emission_enabled else 0.0
	## V6-lite: per-faction composed silhouette (parts share the material → tints apply).
	UNIT_BODIES.compose(_mesh, data.faction_id if data != null else "", 18.0, m)
	COSMETICS.attach_parts(_mesh, _cfac, _ckey, 18.0, null)
	add_child(_mesh)

	## Billboard health bar.
	_make_bar(Color(0.15, 0.15, 0.15), 26.0, 20.0)
	_hp_fill = _make_bar(Color(0.45, 0.85, 1.0), 26.1, 20.0)
	## U3: thin shield strip above the HP bar; only shown while a shield buffer is present.
	_shield_fill = _make_bar(Color(0.55, 0.85, 1.0), 29.0, 20.0)
	_shield_fill.visible = false

func _unlit(col: Color) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _make_bar(col: Color, y: float, width: float) -> MeshInstance3D:
	var q : MeshInstance3D = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(width, 3.5)
	q.mesh = qm
	q.position = Vector3(0.0, y, 0.0)
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	return q

func _update_health_visual() -> void:
	if _hp_fill != null and data != null and _max_hp() > 0.0:
		_hp_fill.scale.x = clampf(_current_health / _max_hp(), 0.0, 1.0)

## U3 — shield strip: visible only while a shield buffer exists, scaled to its ceiling.
func _update_shield_visual() -> void:
	if _shield_fill == null:
		return
	var show : bool = _shield_cap > 0.0 and _shield > 0.01
	_shield_fill.visible = show
	if show:
		_shield_fill.scale.x = clampf(_shield / _shield_cap, 0.0, 1.0)
