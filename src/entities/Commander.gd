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
const _BODY_RIG  = preload("res://src/vfx/CommanderBodyRig.gd")
const BALANCE    = preload("res://src/core/Balance.gd")

const VISION_RADIUS         : int   = 3
const SENSOR_RADIUS         : int   = 9
const MOVE_BASE_SPEED       : float = 36.0   ## slowed to match the deliberate walk cadence (was 140; ~21.6 u/s effective after MOVE_SCALE)
## Deliberate, colossal-mech turning: the body swivels toward the heading at a limited
## rate, and striding is gated until it is roughly aligned (torso leads, then legs stride).
const TURN_RATE_DEG        : float = 80.0    ## yaw degrees per second
const STRIDE_ALIGN_DEG     : float = 20.0    ## begin striding within this of the heading
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

## Charged shot — automatic heavy shot on a cycle (NOT a hotkey ability): the fins
## visibly charge up over the windup, then the next primary volley hits much harder.
const CHARGED_INTERVAL : float = 9.0    ## seconds between charged shots
const CHARGED_WINDUP   : float = 2.2    ## fins/cannon glow ramp during the last stretch
const CHARGED_MULT     : float = 4.0    ## damage multiplier on the charged volley
var _charge_timer : float = 0.0

## Last aim/build point — the body rig twists the torso toward this (±45°).
var _aim_plane : Vector2 = Vector2.INF
var _aim_hold  : float   = 0.0

const ENGINEER_RANGE_PX   : float = 110.0
## 2026-07-19: slowed from 50 so construction paces the fins scan animation — a fresh
## tower (90 HP of work) takes 4.5s = exactly TWO full SCAN_CYCLEs of the raster sweep.
const BUILD_RATE          : float = 20.0
const SCAN_CYCLE          : float = 2.25   ## seconds per full fins scan sweep
var _scan_t : float = 0.0

const MAX_HEALTH       : float = 300.0
const HEALTH_BAR_W     : float = 40.0
const ENGINEER_LINE_COLOR : Color = Color(0.40, 1.00, 0.70, 0.90)   ## engineering beam tint
const CELL_SIZE_PX     : float = 64.0
const SELECT_RING_COLOR : Color = Color(0.40, 1.00, 0.55, 0.90)

var _map_grid       : Node      = null
var _p              : Vector2   = Vector2.ZERO
var _move_queue     : Array[Vector2] = []
var _is_striding    : bool      = false   ## actually translating (vs turning in place)
var _selected       : bool      = false
var _claimed_count  : int       = 0
var _commander_rank : int       = 0
var _rank_bar       : Node      = null   ## deferred (3D overlay polish); null-guarded
var _rank_chevrons  : Node      = null   ## deferred

## 3D visual.
var _body        : MeshInstance3D = null
var _body_rig    : Node3D = null   ## faction mech builder/animator (CommanderBodyRig)
var _hp_fill     : MeshInstance3D = null
var _hp_mat      : StandardMaterial3D = null
var _select_ring : MeshInstance3D = null
var _los_ring    : MeshInstance3D = null   ## flat ground ring at vision (claim) radius — shown when selected
var _sensor_ring : MeshInstance3D = null   ## flat ground ring at sensor radius
var _beams       : Array[MeshInstance3D] = []   ## scan sheets (one per fin → structure)

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

	## Charged-shot cycle: accumulate, drive the fins/cannon glow through the windup,
	## then the next volley (in _try_primary_attack) discharges it.
	_charge_timer = minf(_charge_timer + delta, CHARGED_INTERVAL)
	if _body_rig != null and _body_rig.has_method("set_charge"):
		var wind : float = clampf((_charge_timer - (CHARGED_INTERVAL - CHARGED_WINDUP)) / CHARGED_WINDUP, 0.0, 1.0)
		_body_rig.call("set_charge", wind)

	_aim_hold = maxf(0.0, _aim_hold - delta)
	_try_engineering(delta)
	if _engineer_target != null and is_instance_valid(_engineer_target):
		_aim_plane = WORLD3D.node_plane(_engineer_target)
		_aim_hold = 0.5

	if _move_queue.is_empty():
		_is_striding = false
		return
	var target    : Vector2 = _move_queue[0]
	var to_target : Vector2 = target - _p
	var dist      : float   = to_target.length()

	## Deliberate turn: swivel yaw toward the heading at a limited rate; only stride once
	## roughly aligned (the torso leads the turn, then the legs take stride).
	if to_target.length_squared() > 0.0001:
		var desired : float = -atan2(to_target.y, to_target.x)
		var err     : float = wrapf(desired - rotation.y, -PI, PI)
		var turn    : float = deg_to_rad(TURN_RATE_DEG) * delta
		if absf(err) <= turn:
			rotation.y = desired
		else:
			rotation.y += signf(err) * turn
		_is_striding = absf(wrapf(desired - rotation.y, -PI, PI)) < deg_to_rad(STRIDE_ALIGN_DEG)
	else:
		_is_striding = true

	if not _is_striding:
		return   ## finish squaring up / swivelling before moving

	var step : float = _current_move_speed * BALANCE.MOVE_SCALE * delta
	if dist <= step:
		_set_plane(target)
		_move_queue.pop_front()
	else:
		_set_plane(_p + to_target.normalized() * step)
	_claim_around()
	_reveal_around()

## Set plane position + sync transform. Facing is handled in _process (smooth turn), so
## this no longer snaps rotation.
func _set_plane(p: Vector2) -> void:
	_p = p
	global_position = WORLD3D.to3(_p, 0.0)

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

## True while executing move orders — the body rig reads this to drive gaits.
func is_moving() -> bool:
	return not _move_queue.is_empty() and not _dead

## True only while actually translating (aligned to the heading) — the rig plays Walk vs
## Idle off this, so a pure in-place turn keeps the squared stance until it strides.
func is_striding() -> bool:
	return _is_striding and not _dead

## Current aim/build point (plane coords) — the body rig twists the torso toward it,
## clamped ±45°, so the Commander fires/builds off-axis without turning its legs.
func aim_point() -> Vector2:
	return _aim_plane if _aim_hold > 0.0 else Vector2.INF

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
	## Charged volley: the fins finished winding up — this shot hits far harder.
	var charged : bool = _charge_timer >= CHARGED_INTERVAL
	if charged:
		dmg *= CHARGED_MULT
		_charge_timer = 0.0
	var dt : int = Combat.faction_damage_type(FactionManager.active_faction)
	var tpos : Vector2 = WORLD3D.node_plane(target)
	_aim_plane = tpos
	_aim_hold = 1.2
	## Fire a tracer from each cannon arm (the rig exposes muzzle offsets); to_global folds in the
	## Commander's facing so the blast leaves the arm cannons, not center mass. Fall back to center.
	var mz : Array = []
	if _body_rig != null:
		var mv : Variant = _body_rig.get("muzzles")
		if mv is Array:
			mz = mv
	if not mz.is_empty():
		for m in mz:
			var mp : Vector2 = WORLD3D.to2(to_global(m))
			Vfx.muzzle(mp, dt)
			Vfx.bolt(mp, tpos, dt)
			if charged:
				Vfx.bolt(mp, tpos, dt)   ## double tracer — the heavy shot reads thicker
	else:
		Vfx.muzzle(_p, dt)
		Vfx.bolt(_p, tpos, dt)   ## 3D tracer (replaces the old 2D shot flash)
	if charged:
		## Discharge event: fins flash + recoil snap (rig), muzzle bursts, a double
		## impact ring at the target, and a camera kick — the heavy shot should be FELT.
		if _body_rig != null and _body_rig.has_method("discharge"):
			_body_rig.call("discharge")
		for m in mz:
			Vfx.death(WORLD3D.to2(to_global(m)), Color(0.55, 0.85, 1.00), 26.0)
		Vfx.death(tpos, Color(0.35, 0.75, 1.00), 52.0)   ## electric-blue impact bloom
		Vfx.death(tpos, Color(0.75, 0.92, 1.00), 88.0)   ## outer shockwave ring
		var cam : Node = get_tree().get_first_node_in_group("camera_rig")
		if cam != null and cam.has_method("add_trauma"):
			cam.call("add_trauma", 0.3)
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
	## Fins scan cycle: phase advances only while actually engineering.
	if _engineer_target != null:
		_scan_t += delta
	if _body_rig != null and _body_rig.has_method("set_scan"):
		_body_rig.call("set_scan", _engineer_target != null, fmod(_scan_t / SCAN_CYCLE, 1.0))
	_update_beam()

## 3D engineering beam — a thin emissive bar from the Commander to the structure it's building/repairing.
## Lives in the world (parent), updated each frame; hidden when idle.
const _SCAN_SHEET_SHADER = preload("res://assets/shaders/scan_sheet.gdshader")

func _ensure_beam() -> void:
	if not _beams.is_empty():
		return
	## Barcode-scanner sheets: one light-plane per fin, fanned from the fin's leading
	## edge to the scan point. Geometry is rebuilt per-frame (ImmediateMesh, world coords).
	var smat := ShaderMaterial.new()
	smat.shader = _SCAN_SHEET_SHADER
	var parent : Node = get_parent()
	for i in 2:
		var beam := MeshInstance3D.new()
		beam.mesh = ImmediateMesh.new()
		beam.material_override = smat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.visible = false
		if parent != null:
			parent.add_child(beam)
		_beams.append(beam)

func _update_beam() -> void:
	if _beams.is_empty():
		return
	if _engineer_target == null or not is_instance_valid(_engineer_target):
		for beam in _beams:
			beam.visible = false
		return
	## Barcode-scanner sheets: each fin's LEADING EDGE (live, bone-tracked) fans a
	## striped light-plane onto a short vertical line at the scan point, which RASTERS
	## the structure — sweeping laterally while climbing, like a fabricator pass.
	var edges : Array = []
	if _body_rig != null and _body_rig.has_method("fin_edges"):
		edges = _body_rig.call("fin_edges")
	if edges.is_empty():
		var p3 : Vector3 = WORLD3D.to3(_p, 20.0)
		edges = [[p3, p3 + Vector3(0, 18, 0)], [p3, p3 + Vector3(0, 18, 0)]]
	var tplane : Vector2 = WORLD3D.node_plane(_engineer_target)
	var phase : float = fmod(_scan_t / SCAN_CYCLE, 1.0)
	var dir : Vector2 = (tplane - _p)
	var perp : Vector2 = Vector2.ZERO
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		perp = Vector2(-dir.y, dir.x)
	var sweep_lat : float = sin(phase * TAU) * 18.0                    ## side-to-side pass
	var sweep_h   : float = 6.0 + (1.0 - cos(phase * TAU)) * 0.5 * 34.0  ## climbs the structure
	var to3 : Vector3 = WORLD3D.to3(tplane + perp * sweep_lat, sweep_h)
	var tgt_bot : Vector3 = to3 - Vector3(0, 4.0, 0)   ## narrow target line the sheet converges to
	var tgt_top : Vector3 = to3 + Vector3(0, 4.0, 0)
	for i in _beams.size():
		var beam : MeshInstance3D = _beams[i]
		var seg : Array = edges[i] if i < edges.size() else edges[0]
		var im : ImmediateMesh = beam.mesh as ImmediateMesh
		beam.global_transform = Transform3D.IDENTITY   ## vertices in world space
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		## quad: edge_bot(0,0) edge_top(0,1) tgt_top(1,1) tgt_bot(1,0)
		im.surface_set_uv(Vector2(0, 0)); im.surface_add_vertex(seg[0])
		im.surface_set_uv(Vector2(0, 1)); im.surface_add_vertex(seg[1])
		im.surface_set_uv(Vector2(1, 1)); im.surface_add_vertex(tgt_top)
		im.surface_set_uv(Vector2(0, 0)); im.surface_add_vertex(seg[0])
		im.surface_set_uv(Vector2(1, 1)); im.surface_add_vertex(tgt_top)
		im.surface_set_uv(Vector2(1, 0)); im.surface_add_vertex(tgt_bot)
		im.surface_end()
		beam.visible = true

func _exit_tree() -> void:
	for beam in _beams:
		if is_instance_valid(beam):
			beam.queue_free()

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
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var bmat : StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.82, 0.18)
	## V3: the Commander's hull carries the faction substrate (replaces the old flat emission).
	_SUBSTRATE.apply(bmat, FactionManager.active_faction)
	_body.material_override = bmat
	add_child(_body)
	## 2026-07-03: faction Commander mechs (approved trio — planning/commander-mech-directions.md).
	## The rig builds the body (Needle / Broodmother / Weaver / fallback mech) onto _body and
	## owns its animation; it reports the lift + overlay heights for this silhouette.
	_body_rig = _BODY_RIG.new()
	add_child(_body_rig)
	_body_rig.call("setup", FactionManager.active_faction, _body, bmat)
	_body.position = Vector3(0.0, float(_body_rig.get("body_lift")), 0.0)

	## Centre pip — a small white cap on top (procedural mechs only; a rigged GLTF
	## commander reads as the player by itself, and the pip looks like a stray ball).
	if not bool(_body_rig.get("_use_gltf")):
		var pip : MeshInstance3D = MeshInstance3D.new()
		var sp : SphereMesh = SphereMesh.new()
		sp.radius = 6.0
		sp.height = 12.0
		pip.mesh = sp
		pip.position = _body_rig.get("pip_position")   ## atop this silhouette's head/crown
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
	var bar_y : float = float(_body_rig.get("bar_y"))
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
