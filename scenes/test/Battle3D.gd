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

func _ready() -> void:
	_setup_environment()
	_setup_ground()
	_setup_grid_overlay()
	_setup_marker()
	_spawn_base()
	_spawn_commander()
	_spawn_enemy_base()
	_spawn_walls()

	_rig = CAM_RIG.new()
	_rig.position = _cell_center3(BASE_CELL, 0.0)   ## look at the FOB to start
	add_child(_rig)

	_spawn_demo_towers()
	_spawn_demo_building()
	_spawn_demo_units()

	var title : Label3D = Label3D.new()
	title.text = "3D MIGRATION — Stage 2a: enemy units marching in 3D\nWheel = zoom | WASD/arrows = pan | hold MIDDLE+drag = rotate | MIDDLE+wheel = angle | Delete = reset view | Insert = lock view | Left-click = cell marker"
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

func _setup_ground() -> void:
	var ground : MeshInstance3D = MeshInstance3D.new()
	var pm : PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(COLS * CELL, ROWS * CELL)
	ground.mesh = pm
	## PlaneMesh is centred on its origin → place its centre at the map centre.
	ground.position = Vector3(COLS * CELL * 0.5, 0.0, ROWS * CELL * 0.5)
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.26, 0.20)
	ground.material_override = mat
	add_child(ground)

func _setup_grid_overlay() -> void:
	var im : ImmediateMesh = ImmediateMesh.new()
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.30, 0.45, 0.35, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var y : float = 1.0   ## lift slightly to avoid z-fighting with the ground
	for c in range(COLS + 1):
		var x : float = float(c * CELL)
		im.surface_add_vertex(Vector3(x, y, 0.0))
		im.surface_add_vertex(Vector3(x, y, float(ROWS * CELL)))
	for r in range(ROWS + 1):
		var z : float = float(r * CELL)
		im.surface_add_vertex(Vector3(0.0, y, z))
		im.surface_add_vertex(Vector3(float(COLS * CELL), y, z))
	im.surface_end()
	var mi : MeshInstance3D = MeshInstance3D.new()
	mi.mesh = im
	add_child(mi)

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb : InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_pick(mb.position)

## Click → ground point → cell → snap a marker to the cell centre (proves the mapping + picking).
func _pick(screen_pos: Vector2) -> void:
	var cam : Camera3D = (_rig as Object).call("get_camera")
	var ground2d : Vector2 = WORLD3D.ground_point(cam, screen_pos, 0.0)
	if not WORLD3D.is_valid(ground2d):
		return
	var col : int = int(clampf(floor(ground2d.x / CELL), 0, COLS - 1))
	var row : int = int(clampf(floor(ground2d.y / CELL), 0, ROWS - 1))
	_marker.position = _cell_center3(Vector2i(col, row), CELL * 0.4)
	_marker.visible = true
	## Stage 2e: left-click also issues a move order to the demo Commander (proves 3D movement).
	if is_instance_valid(_commander):
		_commander.call("move_command", _cell_center2(Vector2i(col, row)), false)
	print("[Battle3D] picked cell (%d, %d)" % [col, row])

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
