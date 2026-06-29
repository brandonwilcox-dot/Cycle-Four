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
var _placing     : bool = false
var _preview     : MeshInstance3D = null
var _preview_mat : StandardMaterial3D = null

func _ready() -> void:
	_setup_environment()
	_spawn_map_grid()   ## Stage 3: the real MapGrid renders the 3D terrain + drives claim/fog
	_setup_marker()
	_setup_preview()
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
	_spawn_demo_units()

	var title : Label3D = Label3D.new()
	title.text = "3D MIGRATION — Stage 6: RTS controls\nLEFT = select Commander | RIGHT = move (Shift = chain) | B = build tower (LEFT place / RIGHT cancel) | wheel = zoom (out far = galaxy) | WASD = pan | MIDDLE+drag = rotate | Delete/Insert = reset/lock view"
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

func _process(_delta: float) -> void:
	if _placing:
		_update_preview()

## Stage 6 RTS controls: LEFT = select (Commander) or place tower; RIGHT = move (shift-chain) or
## cancel placement; B = toggle tower-build mode; ESC = cancel/deselect. All via 3D ground raycast.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb : InputEventMouseButton = event
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _placing:
				_try_place_tower(_hovered_cell())
				if not Input.is_key_pressed(KEY_SHIFT):
					_set_placing(false)
			else:
				_select_at(_mouse_ground())
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
			_set_placing(not _placing)
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

## Select the Commander if the click landed within SELECT_RADIUS of it, else deselect.
func _select_at(world2: Vector2) -> void:
	if not is_instance_valid(_commander):
		return
	var hit : bool = WORLD3D.is_valid(world2) and world2.distance_to(_commander.call("plane_pos")) <= SELECT_RADIUS
	_commander.call("set_selected", hit)

## Place an (unbuilt) tower at the hovered cell if the map allows it; the Commander then builds it.
func _try_place_tower(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1) or _map_grid == null:
		return
	if not bool(_map_grid.call("can_place_at", cell.x, cell.y)):
		return
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

## Stage 2 demo: spawn a column of converted enemy Units that march to the FOB in 3D, using the
## REAL Unit logic (waypoints/movement/visual) — proving the Node3D conversion drives correctly.
func _spawn_demo_units() -> void:
	var path : Array[Vector2] = [
		_cell_center2(Vector2i(2, 17)),
		_cell_center2(Vector2i(14, 10)),
		_cell_center2(Vector2i(24, 24)),
		_cell_center2(BASE_CELL),
	]
	for i in 10:
		var ud : UnitData = UnitData.new()
		ud.unit_name = "Demo Crawler"
		ud.faction_id = "mesh"
		ud.max_health = 60.0
		ud.move_speed = 95.0
		ud.color_hint = Color(0.85, 0.45, 0.95)
		var wp : Array[Vector2] = []
		## Stagger each unit further back so they stream in as a column.
		wp.append(path[0] + Vector2(-float(i) * 90.0, float(i % 3 - 1) * 50.0))
		wp.append_array(path)
		var u : Node = UNIT_SCENE.instantiate()
		u.call("setup", ud, wp)
		add_child(u)

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
