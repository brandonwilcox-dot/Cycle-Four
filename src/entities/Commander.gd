## Commander.gd
## The player's on-map hero. Move orders (right-click, shift-chain) routed by Battle; as it walks,
## GROUND cells in its line-of-sight become CLAIMED. Auto-attacks enemies, builds/repairs structures
## (engineering), and can be destroyed (mortality).
##
## 3D MIGRATION (Stage 2e): now `extends Node3D` (model/view). Logical plane position `_p` drives the
## 3D transform via World3D; cross-entity reads via plane_pos()/World3D.node_plane(). Body is a 3D mesh
## (+ billboard health bar + flat ground selection ring + LoS/sensor range rings). Remaining deferred
## 2D `_draw` overlays (move-path preview, ability field/hazard rings, shot flash) await the polish
## pass — the Commander still moves/attacks/claims/builds/dies. AbilityController is a coupled
## follow-up (it still mixes Vector2 field centers with unit positions); it no-ops without a controller.
extends Node3D

const Combat = preload("res://src/combat/Combat.gd")
const FACTION_PERKS = preload("res://src/core/FactionPerks.gd")
const WORLD3D = preload("res://src/core/World3D.gd")
const _SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")

const VISION_RADIUS         : int   = 3
const SENSOR_RADIUS         : int   = 9
const MOVE_BASE_SPEED       : float = 140.0
const RATE_PER_CLAIMED_CELL : float = 0.05
const CELLS_PER_RANK        : int   = 25
const SPEED_PER_RANK        : float = 0.05
const DAMAGE_PER_RANK       : float = 0.10
const RANK_CAP             : int   = 15
const LOS_RANKS_PER_STEP   : int   = 5
const LOS_BONUS_MAX        : int   = 3
const SENSOR_RANKS_PER_STEP : int  = 3
const SENSOR_BONUS_MAX     : int   = 5

const ATTACK_RANGE_PX       : float = VISION_RADIUS * 64.0
const PRIMARY_INTERVAL      : float = 0.4
const PRIMARY_DAMAGE        : float = 8.0

const ENGINEER_RANGE_PX   : float = 110.0
const BUILD_RATE          : float = 50.0

const MAX_HEALTH       : float = 300.0
const HEALTH_BAR_W     : float = 40.0
const ENGINEER_LINE_COLOR : Color = Color(0.40, 1.00, 0.70, 0.90)   ## engineering beam tint
const CELL_SIZE_PX     : float = 64.0
const BODY_LIFT        : float = 42.0   ## torso centre — the Commander is a GIANT MECH now
const SELECT_RING_COLOR : Color = Color(0.40, 1.00, 0.55, 0.90)

var _map_grid       : Node      = null
var _p              : Vector2   = Vector2.ZERO
var _move_queue     : Array[Vector2] = []
var _selected       : bool      = false
var _claimed_count  : int       = 0
var _commander_rank : int       = 0
var _rank_bar       : Node      = null   ## deferred (3D overlay polish); null-guarded
var _rank_chevrons  : Node      = null   ## deferred

## 3D visual.
var _body        : MeshInstance3D = null
var _hp_fill     : MeshInstance3D = null
var _hp_mat      : StandardMaterial3D = null
var _select_ring : MeshInstance3D = null
var _los_ring    : MeshInstance3D = null   ## flat ground ring at vision (claim) radius — shown when selected
var _sensor_ring : MeshInstance3D = null   ## flat ground ring at sensor radius
var _beam        : MeshInstance3D = null   ## 3D engineering beam (Commander → structure under build)
var _beam_mat    : StandardMaterial3D = null

const LOS_RING_COLOR    : Color = Color(0.45, 0.95, 0.60, 0.32)
const SENSOR_RING_COLOR : Color = Color(0.40, 0.70, 1.00, 0.22)

var _sensed_cell_set    : Dictionary = {}

var _current_move_speed : float = MOVE_BASE_SPEED
var _damage_multiplier  : float = 1.0
var _primary_timer      : float = 0.0

var _engineer_target : Node = null

var _max_health     : float = MAX_HEALTH
var _current_health : float = MAX_HEALTH
var _dead           : bool  = false

var _ability_controller = null

func place_at(p: Vector2) -> void:
	_p = p
	position = WORLD3D.to3(_p, 0.0)   ## local (entity layer at origin); safe before tree entry

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("commander")
	add_to_group("detectors")
	position = WORLD3D.to3(_p, 0.0)
	_map_grid = get_node_or_null("../../MapGrid")
	if _map_grid == null:
		_map_grid = get_tree().get_first_node_in_group("map_grid")   ## robust fallback (3D world layout)
	_build_visual()
	_ensure_beam()
	_ability_controller = get_node_or_null("AbilityController")
	_claim_around()
	_reveal_around()

func _process(delta: float) -> void:
	if _dead:
		return
	_primary_timer -= delta
	if _primary_timer <= 0.0:
		var interval : float = PRIMARY_INTERVAL
		if _ability_controller != null and _ability_controller.is_overdrive_active:
			interval *= _ability_controller.overdrive_interval_mult
		_primary_timer = interval
		_try_primary_attack()

	_try_engineering(delta)

	if _move_queue.is_empty():
		return
	var target    : Vector2 = _move_queue[0]
	var to_target : Vector2 = target - _p
	var dist      : float   = to_target.length()
	var step      : float   = _current_move_speed * delta
	if dist <= step:
		_set_plane(target)
		_move_queue.pop_front()
	else:
		_set_plane(_p + to_target.normalized() * step)
	_claim_around()
	_reveal_around()

## Set plane position, sync transform, face travel direction.
func _set_plane(p: Vector2) -> void:
	var d : Vector2 = p - _p
	_p = p
	global_position = WORLD3D.to3(_p, 0.0)
	if d.length_squared() > 0.0001:
		rotation.y = -atan2(d.y, d.x)

## -- Input --

## Delivers a ground-targeted ability cast to the AbilityController (mouse → ground plane).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mbe := event as InputEventMouseButton
	if not mbe.pressed or mbe.button_index != MOUSE_BUTTON_LEFT:
		return
	if _ability_controller != null and _ability_controller.targeting_active:
		var cam : Camera3D = get_viewport().get_camera_3d()
		var gp : Vector2 = WORLD3D.ground_point(cam, mbe.position)
		if WORLD3D.is_valid(gp):
			_ability_controller.deliver_target(gp)
			get_viewport().set_input_as_handled()

## -- Selection + move orders (called by Battle) --

func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	if _select_ring != null:
		_select_ring.visible = _selected
	if _los_ring != null:
		_los_ring.visible = _selected
	if _sensor_ring != null:
		_sensor_ring.visible = _selected
	if _selected:
		_refresh_range_rings()   ## sized to current rank-scaled radii

func is_selected() -> bool:
	return _selected

func move_command(world_pos: Vector2, append: bool) -> void:
	if not append:
		_move_queue.clear()
	_move_queue.append(world_pos)

## -- Territory claiming --

func _claim_around() -> void:
	if _map_grid == null:
		return
	var cell : Vector2i = _map_grid.world_to_cell(_p)
	var newly = _map_grid.call("claim_area", cell, _los_radius())
	if newly == null or newly.is_empty():
		return
	for nc in newly:
		EconomyManager.register_claimed_cell()
		EventBus.territory_claimed.emit(nc)
	_claimed_count += newly.size()
	var prev_rank : int = _commander_rank
	@warning_ignore("integer_division")
	_commander_rank = mini(_claimed_count / CELLS_PER_RANK, RANK_CAP)
	if _commander_rank > prev_rank:
		_recompute_rank_stats()
		_refresh_range_rings()   ## rank can grow LoS/sensor radius
		if _rank_chevrons != null:
			_rank_chevrons.call("set_rank", _commander_rank)
	_update_rank_bar()

func _los_radius() -> int:
	@warning_ignore("integer_division")
	return VISION_RADIUS + mini(_commander_rank / LOS_RANKS_PER_STEP, LOS_BONUS_MAX)

func _sensor_radius() -> int:
	@warning_ignore("integer_division")
	return SENSOR_RADIUS + mini(_commander_rank / SENSOR_RANKS_PER_STEP, SENSOR_BONUS_MAX)

## -- Spawn activation / fog --

func _reveal_around() -> void:
	if _map_grid == null:
		return
	var data : MapData = _map_grid.get("map_data") as MapData
	if data == null:
		return
	var commander_cell : Vector2i = _map_grid.world_to_cell(_p)
	var los    : int = _los_radius()
	var sensor : int = _sensor_radius()

	var newly_revealed : Array[Vector2i] = []
	for dy in range(-los, los + 1):
		for dx in range(-los, los + 1):
			var col : int = commander_cell.x + dx
			var row : int = commander_cell.y + dy
			if col < 0 or col >= data.dimensions.x:
				continue
			if row < 0 or row >= data.dimensions.y:
				continue
			var idx : int = col + row * data.dimensions.x
			if data.get_meta_revealed(idx):
				continue
			data.set_meta_revealed(idx, true)
			newly_revealed.append(Vector2i(col, row))
	if not newly_revealed.is_empty():
		EventBus.region_revealed.emit(newly_revealed)
		_map_grid.queue_redraw()

	var newly_sensed : Array[Vector2i] = []
	for dy in range(-sensor, sensor + 1):
		for dx in range(-sensor, sensor + 1):
			if absi(dx) <= los and absi(dy) <= los:
				continue
			var col : int = commander_cell.x + dx
			var row : int = commander_cell.y + dy
			if col < 0 or col >= data.dimensions.x:
				continue
			if row < 0 or row >= data.dimensions.y:
				continue
			var cell : Vector2i = Vector2i(col, row)
			if _sensed_cell_set.has(cell):
				continue
			var idx : int = col + row * data.dimensions.x
			if data.get_meta_revealed(idx):
				continue
			_sensed_cell_set[cell] = true
			newly_sensed.append(cell)
	if not newly_sensed.is_empty():
		EventBus.region_sensed.emit(newly_sensed)

func get_damage_multiplier() -> float:
	return _damage_multiplier

func _update_rank_bar() -> void:
	if _rank_bar == null:
		return
	var into_rank : int = _claimed_count % CELLS_PER_RANK
	_rank_bar.call("set_progress", float(into_rank) / float(CELLS_PER_RANK))

func _recompute_rank_stats() -> void:
	_current_move_speed = MOVE_BASE_SPEED * pow(1.0 + SPEED_PER_RANK, float(_commander_rank))
	_damage_multiplier  = pow(1.0 + DAMAGE_PER_RANK, float(_commander_rank))

## -- save/load: the Commander's earned progress (claimed count drives rank/XP/speed/damage/rings) --

func get_claimed_count() -> int:
	return _claimed_count

## Restore earned progress on Continue: rank, XP bar, range rings, and rank-scaled stats.
func restore_progress(claimed_count: int) -> void:
	_claimed_count = maxi(0, claimed_count)
	@warning_ignore("integer_division")
	_commander_rank = mini(_claimed_count / CELLS_PER_RANK, RANK_CAP)
	_recompute_rank_stats()
	_refresh_range_rings()
	if _rank_chevrons != null:
		_rank_chevrons.call("set_rank", _commander_rank)
	_update_rank_bar()

## -- Combat --

func _try_primary_attack() -> void:
	var target : Node = _find_nearest_unit_in_range()
	if target == null:
		return
	var dmg : float = PRIMARY_DAMAGE * _damage_multiplier
	if _ability_controller != null and _ability_controller.is_overdrive_active:
		dmg *= _ability_controller.overdrive_damage_mult
	var dt : int = Combat.faction_damage_type(FactionManager.active_faction)
	Vfx.muzzle(_p, dt)
	Vfx.bolt(_p, WORLD3D.node_plane(target), dt)   ## 3D tracer (replaces the old 2D shot flash)
	target.take_damage(dmg, dt)
	EventBus.commander_attacked.emit()
	if _ability_controller != null:
		_ability_controller.add_lance_charge(dmg)
		_ability_controller.on_primary_hit()

func _find_nearest_unit_in_range() -> Node:
	var best : Node  = null
	var best_dist : float = ATTACK_RANGE_PX
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.has_method("is_detectable") and not unit.call("is_detectable"):
			continue
		var dist : float = _p.distance_to(WORLD3D.node_plane(unit))
		if dist < best_dist:
			best_dist = dist
			best      = unit
	for base in get_tree().get_nodes_in_group("enemy_bases"):
		if not is_instance_valid(base):
			continue
		var bdist : float = _p.distance_to(WORLD3D.node_plane(base))
		if bdist < best_dist:
			best_dist = bdist
			best      = base
	return best

## -- Engineering --

func _try_engineering(delta: float) -> void:
	_engineer_target = _find_structure_needing_work()
	if _engineer_target != null:
		var rate : float = BUILD_RATE * FACTION_PERKS.build_rate_mult(FactionManager.active_faction)
		if not bool(_engineer_target.call("receive_engineering", rate * delta)):
			_engineer_target = null
	_update_beam()

## 3D engineering beam — a thin emissive bar from the Commander to the structure it's building/repairing.
## Lives in the world (parent), updated each frame; hidden when idle.
func _ensure_beam() -> void:
	if _beam != null:
		return
	_beam = MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(5.0, 5.0, 1.0)   ## unit length along Z; scaled to the target distance
	_beam.mesh = bx
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.albedo_color = ENGINEER_LINE_COLOR
	_beam_mat.emission_enabled = true
	_beam_mat.emission = ENGINEER_LINE_COLOR
	_beam_mat.emission_energy_multiplier = 3.0
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	var parent : Node = get_parent()
	if parent != null:
		parent.add_child(_beam)

func _update_beam() -> void:
	if _beam == null:
		return
	if _engineer_target == null or not is_instance_valid(_engineer_target):
		_beam.visible = false
		return
	var from3 : Vector3 = WORLD3D.to3(_p, 20.0)
	var to3   : Vector3 = WORLD3D.to3(WORLD3D.node_plane(_engineer_target), 28.0)
	var dist  : float   = from3.distance_to(to3)
	_beam.global_position = (from3 + to3) * 0.5
	if dist > 0.01:
		_beam.look_at(to3, Vector3.UP)
	_beam.scale = Vector3(1.0, 1.0, dist)
	_beam.visible = true

func _exit_tree() -> void:
	if is_instance_valid(_beam):
		_beam.queue_free()

func _find_structure_needing_work() -> Node:
	var best : Node = null
	var best_dist : float = ENGINEER_RANGE_PX
	for grp in ["towers", "buildings", "walls"]:
		for s in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(s) or not s.has_method("needs_engineering"):
				continue
			if not bool(s.call("needs_engineering")):
				continue
			var d : float = _p.distance_to(WORLD3D.node_plane(s))
			if d < best_dist:
				best_dist = d
				best = s
	return best

## -- Mortality --

func take_damage(amount: float, _damage_type: int = -1) -> bool:
	if _dead:
		return true
	_current_health = maxf(0.0, _current_health - amount)
	_update_health_visual()
	if _current_health <= 0.0:
		_dead = true
		hide()
		EventBus.commander_destroyed.emit()
		return true
	return false

func revive() -> void:
	_dead = false
	_current_health = _max_health
	show()
	_update_health_visual()

## Stealth detection radii (px) — match the (former) drawn rings; grow with rank.
func get_detector_radius() -> float:
	return (float(_los_radius()) + 0.5) * CELL_SIZE_PX

func get_sensor_radius() -> float:
	return (float(_sensor_radius()) + 0.5) * CELL_SIZE_PX

## -- Visual (3D) --

func _build_visual() -> void:
	## Gold hero body — taller/brighter than units so it reads as the player.
	_body = MeshInstance3D.new()
	var torso : BoxMesh = BoxMesh.new()
	torso.size = Vector3(26.0, 24.0, 30.0)
	_body.mesh = torso
	_body.position = Vector3(0.0, BODY_LIFT, 0.0)
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var bmat : StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.82, 0.18)
	## V3: the Commander's hull carries the faction substrate (replaces the old flat emission).
	_SUBSTRATE.apply(bmat, FactionManager.active_faction)
	_body.material_override = bmat
	add_child(_body)
	## Playtest 2026-07-02: GIANT MECH silhouette — legs, pelvis, torso, pauldrons, head,
	## shoulder cannon, comms mast. All parts share bmat (substrate); +X = facing. Positions
	## are torso-relative; leg bottoms land on the ground (BODY_LIFT is the torso centre).
	_mech_part(bmat, _mech_box(11.0, 30.0, 12.0), Vector3(2.0, -27.0, 9.5))    ## legs
	_mech_part(bmat, _mech_box(11.0, 30.0, 12.0), Vector3(2.0, -27.0, -9.5))
	_mech_part(bmat, _mech_box(18.0, 9.0, 26.0), Vector3(0.0, -15.0, 0.0))     ## pelvis
	_mech_part(bmat, _mech_box(13.0, 11.0, 14.0), Vector3(-2.0, 13.0, 21.0))   ## pauldrons
	_mech_part(bmat, _mech_box(13.0, 11.0, 14.0), Vector3(-2.0, 13.0, -21.0))
	var head_mesh : SphereMesh = SphereMesh.new()
	head_mesh.radius = 7.5
	head_mesh.height = 15.0
	_mech_part(bmat, head_mesh, Vector3(6.0, 17.0, 0.0))                       ## sensor head
	_mech_part(bmat, _mech_box(30.0, 7.0, 7.0), Vector3(12.0, 11.0, 21.0))     ## shoulder cannon
	_mech_part(bmat, _mech_box(2.4, 24.0, 2.4), Vector3(-9.0, 22.0, -8.0))     ## comms mast

	## Centre pip — a small white cap on top.
	var pip : MeshInstance3D = MeshInstance3D.new()
	var sp : SphereMesh = SphereMesh.new()
	sp.radius = 6.0
	sp.height = 12.0
	pip.mesh = sp
	pip.position = Vector3(6.0, BODY_LIFT + 27.0, 0.0)   ## atop the mech's sensor head
	pip.material_override = _unlit(Color(1, 1, 1, 0.95))
	add_child(pip)

	## Flat ground selection ring — shown only while selected.
	_select_ring = MeshInstance3D.new()
	var tm : TorusMesh = TorusMesh.new()
	tm.inner_radius = 40.0
	tm.outer_radius = 46.0
	_select_ring.mesh = tm
	_select_ring.position = Vector3(0.0, 2.0, 0.0)
	_select_ring.material_override = _unlit(SELECT_RING_COLOR)
	_select_ring.visible = false
	add_child(_select_ring)

	## Flat ground range rings — vision (claim) + sensor radius, shown only while selected.
	_sensor_ring = _make_ground_ring(SENSOR_RING_COLOR)
	_los_ring    = _make_ground_ring(LOS_RING_COLOR)
	_refresh_range_rings()

	## Billboard health bar above the body.
	var bar_y : float = BODY_LIFT + 40.0
	_make_bar(Color(0.12, 0.12, 0.12), bar_y, HEALTH_BAR_W)
	_hp_fill = _make_bar(Color(0.30, 0.95, 0.40), bar_y + 0.1, HEALTH_BAR_W)
	_hp_mat = _hp_fill.material_override as StandardMaterial3D
	_update_health_visual()

## A thin flat ground ring (TorusMesh laid in the XZ plane). Radius set later by _refresh_range_rings.
func _make_ground_ring(col: Color) -> MeshInstance3D:
	var r : MeshInstance3D = MeshInstance3D.new()
	r.mesh = TorusMesh.new()
	r.position = Vector3(0.0, 1.0, 0.0)
	r.material_override = _unlit(col)
	r.visible = false
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(r)
	return r

## Size the range rings to the current rank-scaled vision/sensor radii (in pixels).
func _refresh_range_rings() -> void:
	_set_ring_radius(_los_ring,    float(_los_radius())    * CELL_SIZE_PX)
	_set_ring_radius(_sensor_ring, float(_sensor_radius()) * CELL_SIZE_PX)

func _set_ring_radius(ring: MeshInstance3D, radius_px: float) -> void:
	if ring == null:
		return
	var tm : TorusMesh = ring.mesh as TorusMesh
	if tm != null:
		tm.outer_radius = radius_px
		tm.inner_radius = maxf(0.0, radius_px - 5.0)

func _mech_part(mat: Material, mesh: Mesh, pos: Vector3) -> void:
	var mi : MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_body.add_child(mi)

func _mech_box(x: float, y: float, z: float) -> BoxMesh:
	var b : BoxMesh = BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

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
	qm.size = Vector2(width, 5.0)
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
	if _hp_fill == null:
		return
	var frac : float = clampf(_current_health / _max_health, 0.0, 1.0)
	_hp_fill.scale.x = frac
	if _hp_mat != null:
		_hp_mat.albedo_color = Color(0.30, 0.95, 0.40).lerp(Color(0.95, 0.25, 0.20), 1.0 - frac)
