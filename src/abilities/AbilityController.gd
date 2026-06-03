## AbilityController.gd
## Child node of Commander. Owns the three ability slots:
##   Slot 0 (Q) — Lance          (burst AOE, instant)
##   Slot 1 (W) — Suppression Field (ground-targeted zone control)
##   Slot 2 (E) — Overdrive      (self-amp buff)
##
## Registers Q/W/E input actions via InputMap API. Tracks cooldowns, unlock
## state, and active effect timers. Emits EventBus ability signals for the
## AbilityBar HUD. Commander reads is_overdrive_active and targeting_active.
##
## Preload AbilityData rather than relying on class_name: autoloads parse
## before global class_name registrations land (same pattern as ConvoyManager).
class_name AbilityController
extends Node

const AbilityDataScript = preload("res://src/abilities/AbilityData.gd")

const SLOT_COUNT : int = 3

## Overdrive state — read by Commander._process each tick.
var is_overdrive_active     : bool  = false
var overdrive_interval_mult : float = 0.5
var overdrive_damage_mult   : float = 1.5
var _overdrive_until        : float = -1.0

## Suppression field state — read by Commander._draw() for rendering.
var targeting_active  : bool    = false  ## true while waiting for a ground click
var field_active      : bool    = false
var field_center      : Vector2 = Vector2.ZERO
var _field_until      : float   = -1.0

const FIELD_RADIUS_PX : float = 192.0   ## 3 cells × 64 px; matches ATTACK_RANGE_PX
const FIELD_DURATION  : float = 4.0
const FIELD_SLOW_MULT : float = 0.5

## Attack range in px — must match Commander.VISION_RADIUS * 64 (= 192 px).
const ATTACK_RANGE_PX : float = 192.0

## Lance charge meter. Fills from primary attack damage; replaces cooldown for slot 0.
const LANCE_CHARGE_MAX : float = 60.0   ## total primary damage needed to fully charge
var lance_charge       : float = 0.0
var lance_charged      : bool  = false  ## true when charge >= max; cached to avoid per-frame compare

var _abilities : Array = []          ## 3 AbilityDataScript instances (untyped array)
var _cooldowns : Array[float] = [0.0, 0.0, 0.0]   ## slots 1 and 2 only; slot 0 uses charge
var _unlocked  : Array[bool]  = [false, false, false]

## Duck-typed reference to parent Commander node. Resolved in _ready.
var _commander = null

func _ready() -> void:
	_commander = get_parent()
	_build_abilities()
	_register_input_actions()
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	_unlock_slot(0)

func _process(delta: float) -> void:
	var now : float = Time.get_ticks_msec() / 1000.0

	## Slot 0 (Lance): charge-based — no cooldown tick, just emit current charge state.
	if _unlocked[0]:
		EventBus.ability_charge_changed.emit(0, lance_charge, LANCE_CHARGE_MAX)

	## Slots 1 and 2: cooldown countdown.
	for i in range(1, SLOT_COUNT):
		if _cooldowns[i] > 0.0:
			var prev : float = _cooldowns[i]
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
			var ab = _get_ability(i)
			if ab != null:
				EventBus.ability_cooldown_changed.emit(i, _cooldowns[i], ab.cooldown)
			if prev > 0.0 and _cooldowns[i] == 0.0:
				EventBus.ability_ready.emit(i)

	## Overdrive expiry.
	if is_overdrive_active and now >= _overdrive_until:
		is_overdrive_active = false

	## Suppression field — apply debuff each frame and check expiry.
	if field_active:
		if now >= _field_until:
			_end_field()
		else:
			_apply_field_debuff()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return
	## ESC cancels pending ground-target without consuming the event (HUD also uses ESC).
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

## Called by Commander._unhandled_input when a left-click lands in targeting mode.
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
	## Slot 0 (Lance) uses charge gate; all other slots use cooldown gate.
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
	if slot != 0:
		_start_cooldown(slot)   ## slot 0 (Lance) is charge-based; no cooldown
	EventBus.ability_used.emit(slot)

func _arm_targeting(slot: int) -> void:
	targeting_active = true
	EventBus.ability_targeting_changed.emit(slot, true)

func _cancel_targeting() -> void:
	targeting_active = false
	EventBus.ability_targeting_changed.emit(1, false)

## Lance: AOE damage to every unit within ATTACK_RANGE_PX. Reuses existing cannon VFX.
## Resets the charge meter on cast.
func _cast_lance() -> void:
	if _commander == null:
		return
	var dmg_mult : float = _commander.get_damage_multiplier()
	var ab = _get_ability(0)
	var base_dmg : float = ab.params.get("damage", 45.0) if ab != null else 45.0
	var hits     : int   = 0
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if _commander.global_position.distance_to(unit.global_position) <= ATTACK_RANGE_PX:
			unit.take_damage(base_dmg * dmg_mult)
			hits += 1
	if hits > 0:
		_commander.call("_spawn_cannon_ring")
	## Reset charge after cast.
	lance_charge  = 0.0
	lance_charged = false

## Called by Commander after each primary attack to accumulate Lance charge.
## Charge fills proportionally to damage dealt (including rank scaling).
func add_lance_charge(damage_dealt: float) -> void:
	if lance_charged:
		return   ## already full; don't overflow
	var prev_charged : bool = lance_charged
	lance_charge  = minf(lance_charge + damage_dealt, LANCE_CHARGE_MAX)
	lance_charged = lance_charge >= LANCE_CHARGE_MAX
	if not prev_charged and lance_charged:
		EventBus.ability_ready.emit(0)

## Suppression Field: activate the zone at the clicked world position.
func _cast_suppression(center: Vector2) -> void:
	field_center = center
	field_active = true
	_field_until = Time.get_ticks_msec() / 1000.0 + FIELD_DURATION
	_start_cooldown(1)
	EventBus.ability_used.emit(1)
	if _commander != null:
		_commander.queue_redraw()

## Each frame while the field is active: slow units inside, restore units outside.
func _apply_field_debuff() -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var in_field : bool = field_center.distance_to(unit.global_position) <= FIELD_RADIUS_PX
		unit.set_debuff(FIELD_SLOW_MULT if in_field else 1.0)

func _end_field() -> void:
	field_active = false
	for unit in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(unit):
			unit.set_debuff(1.0)
	if _commander != null:
		_commander.queue_redraw()

## Overdrive: double primary fire rate + 50% damage boost for the configured duration.
## Resets the primary timer so the effect starts with the very next shot.
func _cast_overdrive() -> void:
	var ab = _get_ability(2)
	if ab == null:
		return
	is_overdrive_active     = true
	overdrive_interval_mult = ab.params.get("interval_mult", 0.5)
	overdrive_damage_mult   = ab.params.get("damage_mult",   1.5)
	_overdrive_until        = Time.get_ticks_msec() / 1000.0 + ab.params.get("duration", 6.0)
	if _commander != null:
		_commander.set("_primary_timer", 0.0)

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
		"Ability unlocked: %s  [%s]" % [ab.display_name if ab != null else "?", ["Q","W","E"][slot]],
		"normal"
	)

func _on_faction_selected(_faction_id: String, _sub_path: String) -> void:
	_unlock_slot(1)   ## sub-path commit — faction_selected is the current closest hook

func _on_milestone_reached(_faction_id: String, _milestone_index: int) -> void:
	_unlock_slot(2)

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

	_abilities = [lance, field, overdrive]

func _get_ability(slot: int):
	if slot < 0 or slot >= _abilities.size():
		return null
	return _abilities[slot]

func _register_input_actions() -> void:
	var bindings : Array = [
		[&"ability_1", KEY_Q],
		[&"ability_2", KEY_W],
		[&"ability_3", KEY_E],
	]
	for binding in bindings:
		var action  : StringName = binding[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.keycode = binding[1] as Key
		InputMap.action_add_event(action, ev)
