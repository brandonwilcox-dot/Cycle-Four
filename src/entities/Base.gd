## Base.gd
## The player's Forward Operating Base. Always-on turret, breach-damage HP, fortification rank,
## sphere of influence, and FOB doctrine. Cannot be moved or sold.
##
## 3D MIGRATION (Stage 2d): now `extends Node3D` (model/view). Static plane position `_p` +
## place_at()/plane_pos(); influence/attack/cell math via World3D. Visual is a 3D fortified bunker
## with a turret + billboard HP bar (was ColorRects). 2D rank bar/chevrons deferred (null-guarded).
extends Node3D

const Combat = preload("res://src/combat/Combat.gd")
const WORLD3D = preload("res://src/core/World3D.gd")
const ASSETS = preload("res://src/core/AssetLoader.gd")
const STRUCTURE_LIGHTING = preload("res://src/vfx/StructureEmissionLighting.gd")
const ARCH_FOB_EMISSION_MASK = preload("res://assets/models/buildings/architect_fob_hifi_emission_mask.png")

## -- Bastion armament (playtest 2026-07-21): the fortress's four corner towers each carry
## a SELECTABLE weapon; the player sets the defensive posture from the FOB panel.
## Per weapon: display name, damage, interval (s), range (px), damage type (Combat enum),
## tracer color, and optional special (chain / aoe). Rail-gun keeps the old one-shot-smalls
## role (150 dmg clears ~100 effective through the weak-type ×0.66).
## vfx kind (VfxBolt enum): 0 BULLET · 1 ENERGY · 2 PLASMA · 3 ROCKET · 4 ARC.
const WEAPONS : Dictionary = {
	"railgun":     {"name": "Rail-Gun",      "damage": 150.0, "interval": 2.0,  "range": 420.0, "dtype": 0, "color": Color(1.0, 0.93, 0.6), "vfx": 0},
	"laser":       {"name": "Laser",          "damage": 22.0,  "interval": 0.45, "range": 300.0, "dtype": 1, "color": Color(0.35, 0.95, 1.0), "vfx": 1},
	"lightning":   {"name": "Lightning Arc",  "damage": 34.0,  "interval": 1.25, "range": 280.0, "dtype": 1, "color": Color(0.78, 0.86, 1.0), "chain": 2, "chain_radius": 140.0, "vfx": 4},
	"machine_gun": {"name": "Machine Gun",    "damage": 6.0,   "interval": 0.16, "range": 240.0, "dtype": 0, "color": Color(1.0, 0.82, 0.6), "vfx": 0},
	"rockets":     {"name": "Rockets",        "damage": 48.0,  "interval": 1.7,  "range": 360.0, "dtype": 0, "color": Color(1.0, 0.55, 0.25), "aoe": 90.0, "vfx": 3},
}
const WEAPON_ORDER : Array = ["railgun", "laser", "lightning", "machine_gun", "rockets"]
## Bastion plane offsets from the base centre (± 1.5 cells ≈ the fortress corner towers).
const BASTION_OFFSETS : Array = [
	Vector2(-96.0, -96.0), Vector2(96.0, -96.0), Vector2(-96.0, 96.0), Vector2(96.0, 96.0),
]
const CHAIN_DAMAGE_FRAC  : float = 0.6   ## lightning chained hits / rocket splash fraction
const UNIT_HIT_Y         : float = 16.0  ## target-side tracer height (unit mid-body)

const MAX_HP : float = 300.0
const CARGO_PER_RANK : float = 10.0

const FOB_SIGHT_RADIUS_BASE : int = 5
const FOB_CLAIM_RADIUS_BASE : int = 2
const FOB_SENSOR_EXTRA      : int = 3
const FOB_RADIUS_PER_RANK   : int = 1
const FOB_MAX_RANK          : int = 10

const DOCTRINE_FIRE_RATE_MULT       : float = 1.6
const DOCTRINE_REGEN_PER_SEC        : float = 4.0
const DOCTRINE_DETECTOR_BONUS_CELLS : int   = 3

var _map_grid : Node = null
var _p        : Vector2 = Vector2.ZERO

var _current_hp        : float  = MAX_HP
var _hp_fill           : MeshInstance3D = null
var _hp_mat            : StandardMaterial3D = null
var _bastion_weapons   : Array = ["railgun", "laser", "rockets", "machine_gun"]
var _bastion_timers    : Array = [0.0, 0.0, 0.0, 0.0]
var _bastion_points    : Array = []   ## measured tower muzzles (game units) when a model is up
var _is_destroyed      : bool   = false
var _cargo_received    : float  = 0.0
var _fortification_rank : int   = 0
var _doctrine           : String = ""
var _rank_bar          : Node = null   ## deferred (3D overlay polish); logic null-guards
var _rank_chevrons     : Node = null   ## deferred
var _height            : float = 70.0

func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("base")
	add_to_group("detectors")
	position = WORLD3D.to3(_p, 0.0)
	_build_visual()
	EventBus.base_damaged.connect(_on_base_damaged)
	EventBus.base_healed.connect(_on_base_healed)
	EventBus.convoy_arrived.connect(_on_convoy_arrived)
	call_deferred("_apply_influence")
	call_deferred("_register_apron")

## Perimeter path apron (2026-07-21): the FOB projects a worked-path pad + perimeter ring
## (radius 3 ≈ the hi-fi fortress footprint + walkway) so incoming map corridors connect
## visually from ANY side — no per-faction gate alignment needed. Visual-only (MapGrid).
const APRON_RADIUS : int = 3

func _register_apron() -> void:
	if not is_inside_tree():
		return
	var grid : Node = _get_map_grid()
	if grid != null and grid.has_method("add_structure_apron"):
		grid.call("add_structure_apron", grid.call("world_to_cell", _p), APRON_RADIUS)

func _exit_tree() -> void:
	var grid : Node = get_tree().get_first_node_in_group("map_grid")
	if grid != null and grid.has_method("remove_structure_apron"):
		grid.call("remove_structure_apron", grid.call("world_to_cell", _p))

const FOB_DETECTOR_RADIUS_CELLS : int = 6

func get_detector_radius() -> float:
	var cells : int = FOB_DETECTOR_RADIUS_CELLS + (DOCTRINE_DETECTOR_BONUS_CELLS if _doctrine == "mesh" else 0)
	return float(cells * 64)

func _get_map_grid() -> Node:
	if _map_grid == null or not is_instance_valid(_map_grid):
		_map_grid = get_tree().get_first_node_in_group("map_grid")
	return _map_grid

func _apply_influence() -> void:
	var grid : Node = _get_map_grid()
	if grid == null:
		return
	var center : Vector2i = grid.world_to_cell(_p)
	var sight  : int = FOB_SIGHT_RADIUS_BASE + _fortification_rank * FOB_RADIUS_PER_RANK
	var claim  : int = FOB_CLAIM_RADIUS_BASE + _fortification_rank * FOB_RADIUS_PER_RANK
	grid.call("reveal_area", center, sight)
	grid.call("sense_area", center, sight, sight + FOB_SENSOR_EXTRA)
	var claimed = grid.call("claim_area", center, claim)
	if claimed != null:
		for nc in claimed:
			EconomyManager.register_claimed_cell()
			EventBus.territory_claimed.emit(nc)

func _on_convoy_arrived(_convoy_id: StringName, _to_node: StringName, cargo: float) -> void:
	_cargo_received += cargo
	var prev_rank : int = _fortification_rank
	while _cargo_received >= CARGO_PER_RANK and _fortification_rank < FOB_MAX_RANK:
		_cargo_received -= CARGO_PER_RANK
		_fortification_rank += 1
	if _fortification_rank >= FOB_MAX_RANK:
		_cargo_received = 0.0
	_update_rank_bar()
	if _fortification_rank > prev_rank:
		if _rank_chevrons != null:
			_rank_chevrons.call("set_rank", _fortification_rank)
		_apply_influence()

func restore_rank(restored_rank: int) -> void:
	_fortification_rank = clampi(restored_rank, 0, FOB_MAX_RANK)
	_update_rank_bar()
	if _rank_chevrons != null:
		_rank_chevrons.call("set_rank", _fortification_rank)
	_apply_influence()

func _update_rank_bar() -> void:
	if _rank_bar == null:
		return
	_rank_bar.call("set_progress", _cargo_received / CARGO_PER_RANK)

func _process(delta: float) -> void:
	if _is_destroyed:
		return
	if _doctrine == "bloom" and _current_hp < MAX_HP:
		_current_hp = minf(MAX_HP, _current_hp + DOCTRINE_REGEN_PER_SEC * delta)
		_update_hp_bar()
	var rate_mult : float = DOCTRINE_FIRE_RATE_MULT if _doctrine == "architects" else 1.0
	for i in _bastion_weapons.size():
		_bastion_timers[i] += delta
		var w : Dictionary = WEAPONS[_bastion_weapons[i]]
		if _bastion_timers[i] >= float(w["interval"]) / rate_mult:
			if _fire_bastion(i, w):
				_bastion_timers[i] = 0.0

func set_doctrine(doctrine_id: String) -> void:
	_doctrine = doctrine_id

func get_doctrine() -> String:
	return _doctrine

func _turret_damage_type() -> int:
	var fid : String = _doctrine if _doctrine != "" else FactionManager.active_faction
	return Combat.faction_damage_type(fid)

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

## -- Bastion armament API (FOB panel) --

func get_bastion_weapons() -> Array:
	return _bastion_weapons.duplicate()

func bastion_weapon_label(idx: int) -> String:
	if idx < 0 or idx >= _bastion_weapons.size():
		return ""
	return str(WEAPONS[_bastion_weapons[idx]]["name"])

func cycle_bastion_weapon(idx: int) -> void:
	if idx < 0 or idx >= _bastion_weapons.size():
		return
	var cur : int = WEAPON_ORDER.find(_bastion_weapons[idx])
	_bastion_weapons[idx] = WEAPON_ORDER[(cur + 1) % WEAPON_ORDER.size()]
	_bastion_timers[idx] = 0.0

func set_bastion_weapons(ids: Array) -> void:
	for i in mini(ids.size(), _bastion_weapons.size()):
		if WEAPONS.has(str(ids[i])):
			_bastion_weapons[i] = str(ids[i])

func _bastion_pos(idx: int) -> Vector2:
	if idx < _bastion_points.size():
		var v : Vector3 = _bastion_points[idx]
		return _p + Vector2(v.x, v.z)
	return _p + BASTION_OFFSETS[idx]

## Tracer height: the measured tower-top when a model is up, else the wall top.
func _bastion_y(idx: int) -> float:
	if idx < _bastion_points.size():
		return float((_bastion_points[idx] as Vector3).y)
	return _height

## Fires bastion `idx` at the nearest detectable enemy in its weapon range.
## Returns false (no cooldown reset) when nothing is in range.
func _fire_bastion(idx: int, w: Dictionary) -> bool:
	var from : Vector2 = _bastion_pos(idx)
	var nearest      : Node  = null
	var nearest_dist : float = float(w["range"])
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.has_method("is_detectable") and not unit.call("is_detectable"):
			continue
		var dist : float = from.distance_to(WORLD3D.node_plane(unit))
		if dist < nearest_dist:
			nearest_dist = dist
			nearest      = unit
	if nearest == null or not nearest.has_method("take_damage"):
		return false
	var col : Color = w["color"]
	var dt  : int   = int(w["dtype"])
	var target2 : Vector2 = WORLD3D.node_plane(nearest)
	## Tracer leaves the corner tower-top and angles DOWN to the unit (mid-body height),
	## instead of flying flat at wall height. Muzzle flash sits at the tower.
	var my : float = _bastion_y(idx)
	var vk : int = int(w.get("vfx", 0))
	Vfx.pulse_at(from, col, 12.0, 0.1, my)
	Vfx.bolt_from_to(from, my, target2, UNIT_HIT_Y, col, vk)
	nearest.take_damage(float(w["damage"]), dt)
	## Lightning: arc onward to nearby enemies for fractional damage.
	if w.has("chain"):
		var chained : int = 0
		for unit in get_tree().get_nodes_in_group("units"):
			if chained >= int(w["chain"]) or not is_instance_valid(unit) or unit == nearest:
				continue
			if unit.has_method("is_detectable") and not unit.call("is_detectable"):
				continue
			var up : Vector2 = WORLD3D.node_plane(unit)
			if target2.distance_to(up) <= float(w["chain_radius"]) and unit.has_method("take_damage"):
				Vfx.bolt_styled(target2, up, col, 20.0, 4)   ## ARC beam
				unit.take_damage(float(w["damage"]) * CHAIN_DAMAGE_FRAC, dt)
				chained += 1
	## Rockets: splash around the impact point.
	if w.has("aoe"):
		Vfx.pulse_at(target2, col, float(w["aoe"]), 0.3)
		for unit in get_tree().get_nodes_in_group("units"):
			if not is_instance_valid(unit) or unit == nearest:
				continue
			var up : Vector2 = WORLD3D.node_plane(unit)
			if target2.distance_to(up) <= float(w["aoe"]) and unit.has_method("take_damage"):
				unit.take_damage(float(w["damage"]) * CHAIN_DAMAGE_FRAC, dt)
	return true

## -- Visual (3D) --

func _update_hp_bar() -> void:
	if _hp_fill == null:
		return
	var ratio : float = _current_hp / MAX_HP
	_hp_fill.scale.x = clampf(ratio, 0.0, 1.0)
	if _hp_mat != null:
		if ratio > 0.5:
			_hp_mat.albedo_color = Color(0.20, 0.90, 0.20)
		elif ratio > 0.25:
			_hp_mat.albedo_color = Color(0.90, 0.70, 0.10)
		else:
			_hp_mat.albedo_color = Color(0.90, 0.20, 0.10)

func _build_visual() -> void:
	## Hi-fi Rodin fortress, when the active faction has one (Architects "Default" FOB).
	## Design rule: the Commander must not out-height the external walls — enforced by
	## AssetLoader.FACTION_BASE_SCALE. The model replaces apron/body/corners/turret
	## (the sculptural fortress IS the turret; Vfx muzzle/bolt fire from the plane pos).
	var faction : String = FactionManager.active_faction
	var model : Node3D = ASSETS.load_base_model(faction)
	if model != null:
		add_child(model)
		_height = ASSETS.base_wall_height(faction)      ## wall top drives derived layout
		_bastion_points = ASSETS.base_bastion_points(faction)   ## measured tower muzzles
		## Authored emission is mask-multiplied, then small measured aperture/core lights
		## provide local spill. This replaces the old 520-unit blanket fill that flattened
		## the entire fortress and now matches the Garrison's lighting rule.
		if faction == "architects":
			STRUCTURE_LIGHTING.tune_masked_emission(model, 2.60, ARCH_FOB_EMISSION_MASK)
			STRUCTURE_LIGHTING.add_architect_fob_lights(self, float(ASSETS.FACTION_BASE_SCALE[faction]))
			STRUCTURE_LIGHTING.add_architect_fob_portal_interior(
				self, float(ASSETS.FACTION_BASE_SCALE[faction]))
		else:
			STRUCTURE_LIGHTING.enforce_masked_emission(model)
		var bar_top : float = ASSETS.base_total_height(faction) + 18.0
		_make_bar(Color(0.15, 0.15, 0.15), bar_top, 160.0)                    ## bg
		_hp_fill = _make_bar(Color(0.20, 0.90, 0.20), bar_top + 0.1, 160.0)   ## fill
		_hp_mat = _hp_fill.material_override as StandardMaterial3D
		return

	## Concrete apron (wide, low).
	var apron : MeshInstance3D = MeshInstance3D.new()
	var ab : BoxMesh = BoxMesh.new()
	ab.size = Vector3(108.0, 18.0, 108.0)
	apron.mesh = ab
	apron.position = Vector3(0.0, 9.0, 0.0)
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	apron.material_override = _solid(Color(0.30, 0.27, 0.20))
	add_child(apron)

	## Fortified body — olive drab.
	var body : MeshInstance3D = MeshInstance3D.new()
	var bb : BoxMesh = BoxMesh.new()
	bb.size = Vector3(84.0, _height, 84.0)
	body.mesh = bb
	body.position = Vector3(0.0, _height * 0.5 + 18.0, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.material_override = _solid(Color(0.22, 0.32, 0.17))
	add_child(body)

	## Corner reinforcements.
	for cx in [-36.0, 36.0]:
		for cz in [-36.0, 36.0]:
			var c : MeshInstance3D = MeshInstance3D.new()
			var cm : BoxMesh = BoxMesh.new()
			cm.size = Vector3(16.0, _height + 8.0, 16.0)
			c.mesh = cm
			c.position = Vector3(cx, (_height + 8.0) * 0.5 + 18.0, cz)
			c.material_override = _solid(Color(0.18, 0.18, 0.14))
			add_child(c)

	## Turret — gun-metal drum + barrel.
	var turret_base : MeshInstance3D = MeshInstance3D.new()
	var tc : CylinderMesh = CylinderMesh.new()
	tc.top_radius = 22.0
	tc.bottom_radius = 24.0
	tc.height = 20.0
	turret_base.mesh = tc
	turret_base.position = Vector3(0.0, _height + 28.0, 0.0)
	turret_base.material_override = _solid(Color(0.14, 0.14, 0.14))
	add_child(turret_base)
	var barrel : MeshInstance3D = MeshInstance3D.new()
	var brm : BoxMesh = BoxMesh.new()
	brm.size = Vector3(34.0, 7.0, 7.0)
	barrel.mesh = brm
	barrel.position = Vector3(20.0, _height + 30.0, 0.0)
	barrel.material_override = _solid(Color(0.10, 0.10, 0.10))
	add_child(barrel)

	## HP bar — billboarded above the FOB.
	var bar_y : float = _height + 56.0
	_make_bar(Color(0.15, 0.15, 0.15), bar_y, 90.0)            ## bg
	_hp_fill = _make_bar(Color(0.20, 0.90, 0.20), bar_y + 0.1, 90.0)   ## fill
	_hp_mat = _hp_fill.material_override as StandardMaterial3D

const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")

## V3: the FOB structure carries the player faction's substrate.
func _solid(col: Color) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	_SUBSTRATE.apply(m, FactionManager.active_faction)
	return m

func _make_bar(col: Color, y: float, width: float) -> MeshInstance3D:
	var q : MeshInstance3D = MeshInstance3D.new()
	var qm : QuadMesh = QuadMesh.new()
	qm.size = Vector2(width, 7.0)
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
