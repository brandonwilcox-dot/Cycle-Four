## AbilityController.gd
## Child node of Commander. Owns four ability slots:
##   Slot 0 (Q) — Lance          (charge-based AOE; faction divergence at cast)
##   Slot 1 (W) — Suppression Field (ground-targeted zone control; Bloom hazard on expiry)
##   Slot 2 (E) — Overdrive      (self-amp; faction divergence at cast)
##   Slot 3 (R) — Faction Ultimate (unlocks at Second Milestone)
##
## Faction divergences are dispatched via FactionManager.active_faction at cast time.
## The neutral numbers are the floor; faction branches add behavior.
class_name AbilityController
extends Node

const AbilityDataScript = preload("res://src/abilities/AbilityData.gd")
const Combat = preload("res://src/combat/Combat.gd")

const SLOT_COUNT : int = 4

## -- Overdrive state (read by Commander._process) --
var is_overdrive_active     : bool  = false
var overdrive_interval_mult : float = 0.5
var overdrive_damage_mult   : float = 1.5
var _overdrive_until        : float = -1.0
## Architect Overdrive compounding
var _overdrive_next_tick    : float = -1.0
var _overdrive_stacks       : int   = 0

## -- Suppression Field state (Commander reads for _draw / input) --
var targeting_active  : bool    = false
var field_active      : bool    = false
var field_center      : Vector2 = Vector2.ZERO
var _field_until      : float   = -1.0

const FIELD_RADIUS_PX : float = 192.0
const FIELD_DURATION  : float = 4.0
const FIELD_SLOW_MULT : float = 0.5

## -- Bloom hazard state (Commander reads for _draw) --
var hazard_active     : bool    = false
var hazard_center     : Vector2 = Vector2.ZERO
var _hazard_until     : float   = -1.0
var _hazard_next_tick : float   = -1.0

const HAZARD_DURATION  : float = 8.0
const HAZARD_SLOW_MULT : float = 0.7
const HAZARD_DPS       : float = 5.0

## -- Mesh Overdrive steal state --
var _steal_pending    : bool  = false
var _steal_until      : float = -1.0

## -- Bloom/Mesh Verdant Bulwark state --
var _bulwark_active     : bool  = false
var _bulwark_until      : float = -1.0
var _bulwark_next_heal  : float = -1.0
const BULWARK_RADIUS_PX : float = 384.0
const BULWARK_DURATION  : float = 12.0
const BULWARK_SLOW_MULT : float = 0.6
const BULWARK_HEAL_RATE : float = 4.0

## -- Mesh System Seizure state --
var _seizure_active : bool  = false
var _seizure_until  : float = -1.0

## -- Lance charge meter (slot 0) --
const LANCE_CHARGE_MAX : float = 60.0
var lance_charge       : float = 0.0
var lance_charged      : bool  = false

## -- Attack range (must match Commander.VISION_RADIUS * 64) --
const ATTACK_RANGE_PX : float = 192.0

var _abilities : Array = []
var _cooldowns : Array[float] = [0.0, 0.0, 0.0, 0.0]
var _unlocked  : Array[bool]  = [false, false, false, false]

var _commander = null

func _ready() -> void:
	_commander = get_parent()
	_build_abilities()
	_register_input_actions()
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.subpath_committed.connect(_on_subpath_committed)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	_unlock_slot(0)

func _process(delta: float) -> void:
	var now : float = Time.get_ticks_msec() / 1000.0

	## Slot 0 charge — emit every frame while unlocked.
	if _unlocked[0]:
		EventBus.ability_charge_changed.emit(0, lance_charge, LANCE_CHARGE_MAX)

	## Slots 1–3 cooldown countdown.
	for i in range(1, SLOT_COUNT):
		if _cooldowns[i] > 0.0:
			var prev : float = _cooldowns[i]
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
			var ab = _get_ability(i)
			if ab != null:
				EventBus.ability_cooldown_changed.emit(i, _cooldowns[i], ab.cooldown)
			if prev > 0.0 and _cooldowns[i] == 0.0:
				EventBus.ability_ready.emit(i)

	## Overdrive expiry and Architect compounding.
	if is_overdrive_active:
		if now >= _overdrive_until:
			is_overdrive_active = false
			_overdrive_stacks   = 0
		elif FactionManager.active_faction == "architects" and _overdrive_stacks < 3:
			if now >= _overdrive_next_tick:
				overdrive_damage_mult  *= 1.05
				_overdrive_stacks      += 1
				_overdrive_next_tick   += 2.0

	## Mesh steal window expiry.
	if _steal_pending and now >= _steal_until:
		_steal_pending = false

	## Suppression field update.
	if field_active:
		if now >= _field_until:
			_end_field(now)
		else:
			_apply_field_debuff()

	## Bloom biomass hazard update.
	if hazard_active:
		if now >= _hazard_until:
			_end_hazard()
		else:
			_apply_hazard_debuff()
			if now >= _hazard_next_tick:
				_hazard_next_tick += 1.0
				_tick_hazard_damage()

	## Bloom Verdant Bulwark update.
	if _bulwark_active:
		if now >= _bulwark_until:
			_end_bulwark()
		else:
			_apply_bulwark_debuff()
			if now >= _bulwark_next_heal:
				_bulwark_next_heal += 1.0
				EventBus.base_healed.emit(BULWARK_HEAL_RATE)

	## Mesh System Seizure window.
	if _seizure_active and now >= _seizure_until:
		_seizure_active = false

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return
	if kev.keycode == KEY_ESCAPE and targeting_active:
		_cancel_targeting()
		return
	for i in SLOT_COUNT:
		var ab = _get_ability(i)
		if ab == null:
			continue
		if InputMap.event_is_action(event, ab.key_action, true):
			_try_cast(i)
			get_viewport().set_input_as_handled()
			return

func deliver_target(world_pos: Vector2) -> void:
	if not targeting_active:
		return
	targeting_active = false
	EventBus.ability_targeting_changed.emit(1, false)
	_cast_suppression(world_pos)

## -- Casting --

func _try_cast(slot: int) -> void:
	if not _unlocked[slot]:
		return
	if slot == 0:
		if not lance_charged:
			return
	elif _cooldowns[slot] > 0.0:
		return
	var ab = _get_ability(slot)
	if ab == null:
		return
	if ab.targeting == AbilityDataScript.TARGETING_GROUND:
		_arm_targeting(slot)
		return
	match slot:
		0: _cast_lance()
		2: _cast_overdrive()
		3: _cast_ultimate()
	if slot != 0:
		_start_cooldown(slot)
	EventBus.ability_used.emit(slot)

func _arm_targeting(slot: int) -> void:
	targeting_active = true
	EventBus.ability_targeting_changed.emit(slot, true)

func _cancel_targeting() -> void:
	targeting_active = false
	EventBus.ability_targeting_changed.emit(1, false)

## -- Lance (slot 0) --

func _cast_lance() -> void:
	if _commander == null:
		return
	var dmg_mult : float = _commander.get_damage_multiplier()
	var ab = _get_ability(0)
	var base_dmg : float = ab.params.get("damage", 45.0) if ab != null else 45.0
	var hits     : int   = 0
	var kills    : int   = 0
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if _commander.global_position.distance_to(unit.global_position) <= ATTACK_RANGE_PX:
			var died : bool = unit.take_damage(base_dmg * dmg_mult, Combat.faction_damage_type(FactionManager.active_faction))
			hits += 1
			if died:
				kills += 1
			## Architect: stun non-immune enemies.
			if FactionManager.active_faction == "architects":
				unit.apply_stun(1.0)
	if hits > 0:
		_commander.call("_spawn_cannon_ring")
	## Reset charge; Mesh refunds from kills.
	lance_charge  = 0.0
	lance_charged = false
	if FactionManager.active_faction == "mesh" and kills > 0:
		lance_charge  = minf(kills * 15.0, LANCE_CHARGE_MAX)
		lance_charged = lance_charge >= LANCE_CHARGE_MAX
		if lance_charged:
			EventBus.ability_ready.emit(0)

func add_lance_charge(damage_dealt: float) -> void:
	if lance_charged:
		return
	var prev_charged : bool = lance_charged
	lance_charge  = minf(lance_charge + damage_dealt, LANCE_CHARGE_MAX)
	lance_charged = lance_charge >= LANCE_CHARGE_MAX
	if not prev_charged and lance_charged:
		EventBus.ability_ready.emit(0)

## Called on every primary hit. Used by Mesh System Seizure resource leak.
func on_primary_hit() -> void:
	if _seizure_active and Time.get_ticks_msec() / 1000.0 < _seizure_until:
		EconomyManager.add_resource(FactionManager.get_primary_resource(), 1.0)

## -- Suppression Field (slot 1) --

func _cast_suppression(center: Vector2) -> void:
	field_center = center
	field_active = true
	_field_until = Time.get_ticks_msec() / 1000.0 + FIELD_DURATION
	_start_cooldown(1)
	EventBus.ability_used.emit(1)
	if _commander != null:
		_commander.queue_redraw()

func _apply_field_debuff() -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var in_field : bool = field_center.distance_to(unit.global_position) <= FIELD_RADIUS_PX
		unit.set_debuff(FIELD_SLOW_MULT if in_field else 1.0)

func _end_field(now: float) -> void:
	field_active = false
	if FactionManager.active_faction == "bloom":
		## Bloom: transition to biomass hazard instead of clearing.
		hazard_active     = true
		hazard_center     = field_center
		_hazard_until     = now + HAZARD_DURATION
		_hazard_next_tick = now + 1.0
		## Field debuffs carry over; hazard replaces them at its rate.
	else:
		for unit in get_tree().get_nodes_in_group("units"):
			if is_instance_valid(unit):
				unit.set_debuff(1.0)
	if _commander != null:
		_commander.queue_redraw()

## -- Bloom biomass hazard --

func _apply_hazard_debuff() -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var in_hazard : bool = hazard_center.distance_to(unit.global_position) <= FIELD_RADIUS_PX
		unit.set_debuff(HAZARD_SLOW_MULT if in_hazard else 1.0)

func _tick_hazard_damage() -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if hazard_center.distance_to(unit.global_position) <= FIELD_RADIUS_PX:
			unit.take_damage(HAZARD_DPS, Combat.faction_damage_type(FactionManager.active_faction))

func _end_hazard() -> void:
	hazard_active = false
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit):
			unit.set_debuff(1.0)
	if _commander != null:
		_commander.queue_redraw()

## -- Overdrive (slot 2) --

func _cast_overdrive() -> void:
	var ab = _get_ability(2)
	if ab == null:
		return
	is_overdrive_active     = true
	overdrive_interval_mult = ab.params.get("interval_mult", 0.5)
	overdrive_damage_mult   = ab.params.get("damage_mult",   1.5)
	_overdrive_stacks       = 0
	var now : float = Time.get_ticks_msec() / 1000.0
	var dur : float = 8.0 if FactionManager.active_faction == "architects" else ab.params.get("duration", 6.0)
	_overdrive_until      = now + dur
	_overdrive_next_tick  = now + 2.0
	if _commander != null:
		_commander.set("_primary_timer", 0.0)
	## Faction branches.
	match FactionManager.active_faction:
		"bloom":
			EventBus.base_healed.emit(10.0)
		"mesh":
			_steal_pending = true
			_steal_until   = now + dur
			## Connect one-shot to unit_died for steal payout.
			if not EventBus.unit_died.is_connected(_on_unit_died_steal):
				EventBus.unit_died.connect(_on_unit_died_steal, CONNECT_ONE_SHOT)

func _on_unit_died_steal(_unit_data: Dictionary) -> void:
	if not _steal_pending:
		return
	if Time.get_ticks_msec() / 1000.0 >= _steal_until:
		_steal_pending = false
		return
	EconomyManager.add_resource(FactionManager.get_primary_resource(), 5.0)
	_steal_pending = false

## -- Faction Ultimate (slot 3) --

func _cast_ultimate() -> void:
	match FactionManager.active_faction:
		"architects": _cast_compile_cascade()
		"bloom":     _cast_verdant_bulwark()
		"mesh":      _cast_system_seizure()
	## Faction-specific cooldown overrides the AbilityData default.
	match FactionManager.active_faction:
		"architects": _cooldowns[3] = 90.0
		"bloom":     _cooldowns[3] = 120.0
		"mesh":      _cooldowns[3] = 100.0
	EventBus.ability_cooldown_changed.emit(3, _cooldowns[3], _cooldowns[3])

func _cast_compile_cascade() -> void:
	## Architect: 50 + 2×N damage to EVERY enemy on the map.
	if _commander == null:
		return
	var dmg_mult : float = _commander.get_damage_multiplier()
	var units    : Array = get_tree().get_nodes_in_group("units")
	var N        : int   = units.size()
	var dmg      : float = (50.0 + 2.0 * N) * dmg_mult
	for unit in units:
		if is_instance_valid(unit):
			unit.take_damage(dmg, Combat.faction_damage_type(FactionManager.active_faction))
	## Full-screen flash VFX via a brief white ColorRect on Commander.
	if _commander != null:
		_commander.call("_spawn_cannon_ring")

func _cast_verdant_bulwark() -> void:
	## Bloom: 12 s of FOB +4 HP/s regen and 40 % slow on enemies within 384 px of FOB.
	var now : float = Time.get_ticks_msec() / 1000.0
	_bulwark_active    = true
	_bulwark_until     = now + BULWARK_DURATION
	_bulwark_next_heal = now + 1.0

func _apply_bulwark_debuff() -> void:
	var base_node = get_tree().get_first_node_in_group("base")
	if base_node == null:
		return
	var base_pos : Vector2 = base_node.global_position
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var in_bulwark : bool = base_pos.distance_to(unit.global_position) <= BULWARK_RADIUS_PX
		unit.set_debuff(BULWARK_SLOW_MULT if in_bulwark else 1.0)

func _end_bulwark() -> void:
	_bulwark_active = false
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit):
			unit.set_debuff(1.0)

func _cast_system_seizure() -> void:
	## Mesh: instant 3×N resources, then 6 s of +1 resource per primary hit.
	var units : Array = get_tree().get_nodes_in_group("units")
	var N     : int   = units.size()
	EconomyManager.add_resource(FactionManager.get_primary_resource(), 3.0 * N)
	var now : float = Time.get_ticks_msec() / 1000.0
	_seizure_active = true
	_seizure_until  = now + 6.0

## -- Cooldown helpers --

func _start_cooldown(slot: int) -> void:
	var ab = _get_ability(slot)
	if ab != null:
		_cooldowns[slot] = ab.cooldown

## -- Unlock --

func _unlock_slot(slot: int) -> void:
	if _unlocked[slot]:
		return
	_unlocked[slot] = true
	var ab = _get_ability(slot)
	EventBus.ability_unlocked.emit(slot, ab.id if ab != null else &"")
	EventBus.notification_pushed.emit(
		"Ability unlocked: %s  [%s]" % [ab.display_name if ab != null else "?", ["Q","W","E","R"][slot]],
		"normal"
	)

func _on_subpath_committed(_sub_path: String) -> void:
	_unlock_slot(1)   ## Identity arc beat — Suppression Field unlocks at sub-path commit

func _on_faction_selected(faction_id: String, _sub_path: String) -> void:
	## Slot 1 (Suppression Field) is NOT unlocked here; it waits for subpath_committed.
	## Set ultimate cooldown and display name based on faction now that it is known.
	var ultimate = _get_ability(3)
	if ultimate != null:
		match faction_id:
			"architects":
				ultimate.cooldown     = 90.0
				ultimate.display_name = "Compile Cascade"
				ultimate.color        = Color(1.00, 0.92, 0.30, 1.0)
			"bloom":
				ultimate.cooldown     = 120.0
				ultimate.display_name = "Verdant Bulwark"
				ultimate.color        = Color(0.35, 1.00, 0.45, 1.0)
			"mesh":
				ultimate.cooldown     = 100.0
				ultimate.display_name = "System Seizure"
				ultimate.color        = Color(0.40, 0.80, 1.00, 1.0)

func _on_milestone_reached(_faction_id: String, milestone_index: int) -> void:
	if milestone_index == 0:
		_unlock_slot(2)   ## First Milestone → Overdrive
	elif milestone_index == 1:
		_unlock_slot(3)   ## Second Milestone → Faction Ultimate

## -- Ability data --

func _build_abilities() -> void:
	var lance = AbilityDataScript.new()
	lance.id           = &"lance"
	lance.display_name = "Lance"
	lance.key_action   = &"ability_1"
	lance.cooldown     = 6.0
	lance.targeting    = AbilityDataScript.TARGETING_NONE
	lance.color        = Color(1.00, 0.92, 0.30, 1.0)
	lance.params       = {"damage": 45.0}

	var field = AbilityDataScript.new()
	field.id           = &"suppression_field"
	field.display_name = "Suppression Field"
	field.key_action   = &"ability_2"
	field.cooldown     = 12.0
	field.targeting    = AbilityDataScript.TARGETING_GROUND
	field.color        = Color(0.40, 0.80, 1.00, 1.0)
	field.params       = {"slow_mult": 0.5, "duration": 4.0, "radius_px": 192.0}

	var overdrive = AbilityDataScript.new()
	overdrive.id           = &"overdrive"
	overdrive.display_name = "Overdrive"
	overdrive.key_action   = &"ability_3"
	overdrive.cooldown     = 20.0
	overdrive.targeting    = AbilityDataScript.TARGETING_NONE
	overdrive.color        = Color(1.00, 0.55, 0.18, 1.0)
	overdrive.params       = {"interval_mult": 0.5, "damage_mult": 1.5, "duration": 6.0}

	## Slot 3 (R) — faction ultimate. Name/cooldown/color set at faction select.
	var ultimate = AbilityDataScript.new()
	ultimate.id           = &"faction_ultimate"
	ultimate.display_name = "Ultimate"
	ultimate.key_action   = &"ability_4"
	ultimate.cooldown     = 90.0
	ultimate.targeting    = AbilityDataScript.TARGETING_NONE
	ultimate.color        = Color(0.85, 0.30, 1.00, 1.0)   ## magenta placeholder
	ultimate.params       = {}

	_abilities = [lance, field, overdrive, ultimate]

func _get_ability(slot: int):
	if slot < 0 or slot >= _abilities.size():
		return null
	return _abilities[slot]

func _register_input_actions() -> void:
	var bindings : Array = [
		[&"ability_1", KEY_Q],
		[&"ability_2", KEY_W],
		[&"ability_3", KEY_E],
		[&"ability_4", KEY_R],
	]
	for binding in bindings:
		var action  : StringName = binding[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.keycode = binding[1] as Key
		InputMap.action_add_event(action, ev)
