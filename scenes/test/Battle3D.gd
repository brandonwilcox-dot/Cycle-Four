## 3D migration Stage 1 — vertical slice (planning/3d-migration-plan.md).
## Proves the foundation: a Camera3D rig at ~52°, a DirectionalLight3D with shadows, a 3D ground
## built at the real grid size (MapGrid COLS×ROWS×CELL_SIZE), the FOB as a mesh, a grid overlay,
## and click→ground picking via World3D — clicking drops a marker on the picked cell centre,
## proving the 2D⇄3D coordinate mapping. NOT the real battle yet; entities arrive in Stage 2.
extends Node3D

const WORLD3D     = preload("res://src/core/World3D.gd")
const CAM_RIG     = preload("res://src/core/CameraRig3D.gd")
const UNIT_SCENE     = preload("res://scenes/main/Unit.tscn")
const TOWER_SCENE    = preload("res://scenes/main/Tower.tscn")
const BUILDING_SCENE = preload("res://scenes/main/Building.tscn")
const BUILDING_DATA  = preload("res://src/entities/BuildingData.gd")
const BASE_SCRIPT      = preload("res://src/entities/Base.gd")
const COMMANDER_SCRIPT  = preload("res://src/entities/Commander.gd")
const ENEMY_BASE_SCRIPT = preload("res://src/entities/EnemyBase.gd")
const WALL_SCRIPT       = preload("res://src/entities/Wall.gd")
const MAP_GRID_SCRIPT   = preload("res://src/core/map/MapGrid.gd")
const GALAXY_VIEW       = preload("res://src/ui/GalaxyView.gd")
const HUD_SCENE         = preload("res://scenes/ui/HUD.tscn")
## A spread of tiers/branches/roles to show the 3D silhouettes differ.
const DEMO_TOWERS : Array = [
	[preload("res://resources/towers/architects_t1.tres"),  Vector2i(12, 12)],   ## T1 damage
	[preload("res://resources/towers/architects_t2b.tres"), Vector2i(18, 14)],   ## Railgun (1 long barrel)
	[preload("res://resources/towers/bloom_t3.tres"),       Vector2i(22, 20)],   ## gatling + detector antenna
	[preload("res://resources/towers/mesh_t2b.tres"),       Vector2i(26, 22)],   ## Relay Pylon (support halo)
]

## Mirror the real grid constants (MapGrid) so the mapping is exercised at production scale.
const CELL : int = 64
const COLS : int = 60
const ROWS : int = 34
const BASE_CELL : Vector2i = Vector2i(30, 17)

var _rig       : Node3D = null
var _marker    : MeshInstance3D = null
var _commander : Node = null

## Stage 6 controls.
const TOWER_DATA = preload("res://resources/towers/architects_t1.tres")
const SELECT_RADIUS : float = 52.0
var _map_grid    : Node = null
var _hud         : Control = null
var _selected_tower : Node = null   ## built tower selected for upgrade (U)
var _last_upgrade_t  : float = -1.0   ## debounce: rapid upgrades thrash the free/rebuild cycle
const UPGRADE_COOLDOWN : float = 0.35
var _placing        : bool = false
var _place_building : bool = false   ## false = tower, true = building/garrison
var _preview        : MeshInstance3D = null
var _preview_mat    : StandardMaterial3D = null

## Stage 6b waves.
const SPAWN_INTERVAL : float = 1.6
var _unit_layer  : Node3D = null
var _spawn_cells : Array[Vector2i] = []
var _spawn_idx   : int   = 0
var _spawn_timer : float = 2.0

func _ready() -> void:
	_setup_environment()
	_spawn_map_grid()   ## Stage 3: the real MapGrid renders the 3D terrain + drives claim/fog
	_setup_marker()
	_setup_preview()
	_setup_hud()
	_select_faction()      ## Stage 6c: set active_faction → HUD resources/buttons + garrison production
	_setup_unit_layer()    ## must exist before garrisons _ready (their friendly units spawn here)
	_spawn_base()
	_spawn_commander()
	_spawn_enemy_base()
	_spawn_walls()
	_spawn_galaxy()

	_rig = CAM_RIG.new()
	_rig.position = _cell_center3(BASE_CELL, 0.0)   ## look at the FOB to start
	add_child(_rig)

	_spawn_demo_towers()
	_spawn_demo_building()
	_setup_waves()

	var title : Label3D = Label3D.new()
	title.text = "3D MIGRATION — Stage 6c\nLEFT select Commander / tower | U upgrade selected tower | RIGHT move (Shift chain) | B tower | G garrison | PgUp birds-eye | PgDn focus | wheel zoom (out=galaxy) | WASD pan | MIDDLE+drag rotate | Del/Ins view"
	title.position = _cell_center3(BASE_CELL, 420.0)
	title.pixel_size = 0.9
	title.modulate = Color(0.8, 0.9, 1.0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)

func _setup_environment() -> void:
	var light : DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -40.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)

	var we : WorldEnvironment = WorldEnvironment.new()
	var env : Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.06, 0.09)
	env.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.ambient_light_energy = 0.55
	we.environment = env
	add_child(we)

## Stage 3: instantiate the real MapGrid — it generates a map, renders the 3D terrain (MultiMesh
## tiles colored by cell type + fog), joins the "map_grid" group, and drives claim/reveal/sight for
## the entities. Replaces the old flat placeholder ground + grid overlay.
func _spawn_map_grid() -> void:
	var mg : Node = MAP_GRID_SCRIPT.new()
	mg.name = "MapGrid"
	add_child(mg)
	_map_grid = mg

## Stage 2d: the real Base (FOB) entity at the base cell — 3D bunker, HP bar, turret that
## shoots units in range and takes breach damage when units arrive.
func _spawn_base() -> void:
	var b : Node = BASE_SCRIPT.new()
	b.call("place_at", _cell_center2(BASE_CELL))
	add_child(b)

## Stage 2e: the player Commander (instantiated script-only → no AbilityController, so abilities
## no-op). Auto-attacks enemies, selectable (ground ring), and left-click issues a move order.
func _spawn_commander() -> void:
	_commander = COMMANDER_SCRIPT.new()
	_commander.call("place_at", _cell_center2(Vector2i(28, 17)))
	add_child(_commander)
	_commander.call("set_selected", true)

## Stage 2f: a destructible enemy base near the west spawn — fields mesh-faction defenders (real 3D
## Units) that guard it; the Commander/FOB/towers can grind it down.
func _spawn_enemy_base() -> void:
	var eb : Node = ENEMY_BASE_SCRIPT.new()
	eb.call("setup", &"demo_spawn", "mesh")
	eb.call("place_at", _cell_center2(Vector2i(6, 17)))
	add_child(eb)

## Stage 5: populate a galaxy + add the 3D GalaxyView. Zoom the camera OUT past the galaxy
## threshold (wheel) and the board shrinks away to reveal the 3D territory-node graph.
func _spawn_galaxy() -> void:
	GalaxyManager.ensure_galaxy("architects")
	var gv : Node = GALAXY_VIEW.new()
	add_child(gv)
	gv.call("setup", Vector2(COLS * CELL * 0.5, ROWS * CELL * 0.5))

## Stage 2g: a couple of built walls on the enemy approach — enemies grind them to pass.
func _spawn_walls() -> void:
	for cell in [Vector2i(20, 16), Vector2i(20, 18)]:
		var w : Node = WALL_SCRIPT.new()
		w.call("place_at", _cell_center2(cell))
		add_child(w)
		w.call("mark_built")

func _setup_marker() -> void:
	_marker = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(CELL * 0.8, CELL * 0.8, CELL * 0.8)
	_marker.mesh = bx
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.25, 0.2)
	_marker.material_override = mat
	_marker.visible = false
	add_child(_marker)

func _process(delta: float) -> void:
	if _placing:
		_update_preview()
	## Stage 6b: trickle enemy waves from the map's spawn points along their real A* paths.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_one_enemy()

## Stage 6 RTS controls: LEFT = select (Commander) or place tower; RIGHT = move (shift-chain) or
## cancel placement; B = toggle tower-build mode; ESC = cancel/deselect. All via 3D ground raycast.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb : InputEventMouseButton = event
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _placing:
				_try_place(_hovered_cell())
				if not Input.is_key_pressed(KEY_SHIFT):
					_set_placing(false)
			else:
				_left_click(_mouse_ground())
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if _placing:
				_set_placing(false)
			elif is_instance_valid(_commander) and bool(_commander.call("is_selected")):
				var g : Vector2 = _mouse_ground()
				if WORLD3D.is_valid(g):
					_commander.call("move_command", g, Input.is_key_pressed(KEY_SHIFT))
					_flash_marker(g)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k : InputEventKey = event
		if k.keycode == KEY_B:
			if _placing and not _place_building:
				_set_placing(false)
			else:
				_place_building = false
				_set_placing(true)
		elif k.keycode == KEY_G:
			if _placing and _place_building:
				_set_placing(false)
			else:
				_place_building = true
				_set_placing(true)
		elif k.keycode == KEY_U:
			_try_upgrade_selected_tower()
		elif k.keycode == KEY_PAGEUP:
			## Birds-eye centered on the map.
			_rig.call("snap_birdseye", Vector3(COLS * CELL * 0.5, 0.0, ROWS * CELL * 0.5), float(COLS * CELL) * 0.9)
		elif k.keycode == KEY_PAGEDOWN:
			## Focus the Commander; frame ~its sensor range.
			if is_instance_valid(_commander):
				var sr : float = float(_commander.call("get_sensor_radius"))
				_rig.call("snap_focus", WORLD3D.to3(_commander.call("plane_pos"), 0.0), sr * 2.0)
		elif k.keycode == KEY_ESCAPE:
			if _placing:
				_set_placing(false)
			elif is_instance_valid(_commander):
				_commander.call("set_selected", false)

## -- RTS control helpers (Stage 6) --

func _mouse_ground() -> Vector2:
	var cam : Camera3D = _rig.call("get_camera")
	return WORLD3D.ground_point(cam, get_viewport().get_mouse_position(), 0.0)

func _hovered_cell() -> Vector2i:
	var g : Vector2 = _mouse_ground()
	if not WORLD3D.is_valid(g):
		return Vector2i(-1, -1)
	return Vector2i(int(clampf(floor(g.x / CELL), 0, COLS - 1)), int(clampf(floor(g.y / CELL), 0, ROWS - 1)))

## LEFT-click dispatch: a built tower under the cursor selects it (for upgrade); otherwise fall through
## to Commander select/deselect.
func _left_click(world2: Vector2) -> void:
	var t : Node = _tower_at(world2)
	if t != null:
		_selected_tower = t
		if is_instance_valid(_commander):
			_commander.call("set_selected", false)
		EventBus.notification_pushed.emit("Tower selected — press U to upgrade.", "normal")
		return
	_selected_tower = null
	_select_at(world2)

## Nearest built tower within a small radius of a plane point, or null.
func _tower_at(world2: Vector2) -> Node:
	if not WORLD3D.is_valid(world2):
		return null
	var best   : Node  = null
	var best_d : float = 36.0
	for t in get_tree().get_nodes_in_group("towers"):
		if not is_instance_valid(t) or not bool(t.call("is_built")):
			continue
		var d : float = world2.distance_to(t.call("plane_pos"))
		if d <= best_d:
			best_d = d
			best   = t
	return best

## Upgrade the selected tower to its next tier (branch A) if it has one. Demo: free (real game charges).
func _try_upgrade_selected_tower() -> void:
	if not is_instance_valid(_selected_tower):
		return
	## Debounce: upgrade() frees + rebuilds the whole tower visual; rapid repeats thrash that cycle
	## (the known rapid-interaction hang). Ignore presses inside the cooldown.
	var now : float = Time.get_ticks_msec() / 1000.0
	if now - _last_upgrade_t < UPGRADE_COOLDOWN:
		return
	if not bool(_selected_tower.call("is_built")):
		EventBus.notification_pushed.emit("Finish building the tower first.", "warning")
		return
	var d : Resource = _selected_tower.get("data")
	var nxt : Resource = d.get("upgrade_to") if d != null else null
	if nxt == null:
		EventBus.notification_pushed.emit("Tower is at its max tier.", "warning")
		return
	_last_upgrade_t = now
	_selected_tower.call("upgrade", nxt)
	EventBus.notification_pushed.emit("Tower upgraded to %s." % str(nxt.get("tower_name")), "positive")

## Select the Commander if the click landed within SELECT_RADIUS of it, else deselect.
func _select_at(world2: Vector2) -> void:
	if not is_instance_valid(_commander):
		return
	var hit : bool = WORLD3D.is_valid(world2) and world2.distance_to(_commander.call("plane_pos")) <= SELECT_RADIUS
	_commander.call("set_selected", hit)

## Place an (unbuilt) tower or building at the hovered cell if the map allows it; the Commander builds it.
func _try_place(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1) or _map_grid == null:
		return
	if not bool(_map_grid.call("can_place_at", cell.x, cell.y)):
		return
	if _place_building:
		var bd : BuildingData = BUILDING_DATA.new()
		bd.building_name = "Garrison"
		bd.color_hint = Color(0.55, 0.75, 0.95)
		bd.income_rate = 0.5
		var b : Node = BUILDING_SCENE.instantiate()
		b.call("setup", bd, false)        ## unbuilt — Commander constructs it
		b.call("place_at", _cell_center2(cell))
		add_child(b)
	else:
		var t : Node = TOWER_SCENE.instantiate()
		t.call("setup", TOWER_DATA, false)   ## unbuilt — the Commander constructs it
		t.call("place_at", _cell_center2(cell))
		add_child(t)
		_map_grid.call("mark_tower_placed", cell.x, cell.y)

func _set_placing(value: bool) -> void:
	_placing = value
	if _preview != null:
		_preview.visible = value
	if value:
		_update_preview()
	elif _hud != null:
		_hud.call("end_placement_mode")   ## unlock the HUD build buttons when placement ends

func _update_preview() -> void:
	if _preview == null:
		return
	var cell : Vector2i = _hovered_cell()
	if cell == Vector2i(-1, -1):
		_preview.visible = false
		return
	_preview.visible = true
	_preview.position = _cell_center3(cell, 6.0)
	var ok : bool = _map_grid != null and bool(_map_grid.call("can_place_at", cell.x, cell.y))
	_preview_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.5) if ok else Color(1.0, 0.3, 0.25, 0.5)

## Stage 6c: pick a faction so active_faction is set — lights up the HUD's faction resources +
## build buttons + tower upgrades AND lets garrisons resolve their roster unit. (architects/standard;
## the real game routes this through the FactionSelect screen — wired here so the battle plays.)
func _select_faction() -> void:
	FactionManager.select_faction("architects", "standard")
	## Demo convenience: seed resources so the HUD build button is affordable immediately (the real
	## game earns these by claiming territory through the Academy ramp). Without this, can_afford gates
	## the HUD button at battle start — which is why it "did nothing" while the B-key (free) worked.
	EconomyManager.add_resource(FactionManager.get_primary_resource(), 400.0)

## Friendly units (garrison defenders) live here; tagged "unit_layer" so a Building can resolve it
## by group (its hardcoded ../../UnitLayer path doesn't hold in the 3D scene layout).
func _setup_unit_layer() -> void:
	_unit_layer = Node3D.new()
	_unit_layer.name = "UnitLayer"
	_unit_layer.add_to_group("unit_layer")
	add_child(_unit_layer)

## Stage 6c: overlay the real HUD (a Control) on a CanvasLayer above the 3D viewport. It's
## EventBus-driven (resources / waves / notifications / objectives), so it displays live with no
## controller wiring. The build button needs the faction-select flow (deeper 6c); meanwhile we connect
## its placement signal to our 3D placement mode and keep the B key.
func _setup_hud() -> void:
	var cl : CanvasLayer = CanvasLayer.new()
	add_child(cl)
	_hud = HUD_SCENE.instantiate()
	cl.add_child(_hud)
	## HUD build buttons → 3D placement mode (tower vs garrison).
	EventBus.tower_placement_requested.connect(func(_td: Resource) -> void:
		_place_building = false
		_set_placing(true))
	EventBus.building_placement_requested.connect(func(_bd: Resource) -> void:
		_place_building = true
		_set_placing(true))

func _setup_preview() -> void:
	_preview = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(CELL * 0.9, 8.0, CELL * 0.9)
	_preview.mesh = bx
	_preview_mat = StandardMaterial3D.new()
	_preview_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.5)
	_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview.material_override = _preview_mat
	_preview.visible = false
	add_child(_preview)

## Brief flash at a Commander move order.
func _flash_marker(world2: Vector2) -> void:
	if _marker == null:
		return
	_marker.position = WORLD3D.to3(world2, CELL * 0.3)
	_marker.visible = true

func _cell_center3(cell: Vector2i, height: float) -> Vector3:
	return WORLD3D.to3(_cell_center2(cell), height)

func _cell_center2(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)

## Stage 6b: real waves — collect the map's spawn cells and trickle enemies down their A* paths.
func _setup_waves() -> void:
	var md : MapData = _map_grid.map_data if _map_grid != null else null
	if md != null:
		for sp in md.spawn_points:
			if sp != null:
				_spawn_cells.append(sp.position)

func _spawn_one_enemy() -> void:
	if _spawn_cells.is_empty() or _map_grid == null:
		return
	var cell : Vector2i = _spawn_cells[_spawn_idx % _spawn_cells.size()]
	_spawn_idx += 1
	var wp : Array = _map_grid.call("get_path_to_base", cell)
	if wp.is_empty():
		return
	var u : Node = UNIT_SCENE.instantiate()
	u.call("setup", _enemy_data(), wp)
	_unit_layer.add_child(u)

func _enemy_data() -> UnitData:
	var ud : UnitData = UnitData.new()
	ud.unit_name = "Raider"
	ud.faction_id = "mesh"
	ud.max_health = 60.0
	ud.move_speed = 95.0
	ud.color_hint = Color(0.85, 0.45, 0.95)
	return ud

## Stage 2b demo: place converted Towers (built) along the path so they shoot the marching units —
## a mini 3D battle that exercises the real Tower logic + the 3D stat-driven silhouettes.
func _spawn_demo_towers() -> void:
	for entry in DEMO_TOWERS:
		var t : Node = TOWER_SCENE.instantiate()
		t.call("setup", entry[0], true)            ## start_built so it attacks immediately
		t.call("place_at", _cell_center2(entry[1]))
		add_child(t)

## Stage 2c demo: place one converted Building (garrison) to show its 3D mesh. Inert here (no
## faction/unit-layer), so it just demonstrates the structure; production lights up post-FriendlyUnit.
func _spawn_demo_building() -> void:
	var bd : BuildingData = BUILDING_DATA.new()
	bd.building_name = "Demo Garrison"
	bd.color_hint = Color(0.55, 0.75, 0.95)
	var b : Node = BUILDING_SCENE.instantiate()
	b.call("setup", bd, true)                       ## restored=true → built/solid, no economy side effects
	b.call("place_at", _cell_center2(Vector2i(16, 20)))
	add_child(b)
