## THROWAWAY SPIKE (not shipped) — true 3D option.
## Real Node3D scene: Camera3D at ~45°, DirectionalLight3D with shadows, primitive meshes built
## in code (no art assets) for the tower + units. The turret yaws to face the nearest unit.
## Compare against Spike25D.tscn.
extends Node3D

var _units  : Array = []          ## MeshInstance3D
var _tower  : Node3D = null
var _turret : Node3D = null
var _core   : MeshInstance3D = null
var _pulse  : float = 0.0

func _ready() -> void:
	var cam : Camera3D = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.0, 13.0, 13.0)
	cam.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	cam.fov = 50.0

	var light : DirectionalLight3D = DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-52.0, -45.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true

	var we : WorldEnvironment = WorldEnvironment.new()
	var env : Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.10)
	env.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.ambient_light_energy = 0.55
	we.environment = env
	add_child(we)

	var ground : MeshInstance3D = MeshInstance3D.new()
	var pm : PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(44.0, 44.0)
	ground.mesh = pm
	var gmat : StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.16, 0.28, 0.20)
	ground.material_override = gmat
	add_child(ground)

	var title : Label3D = Label3D.new()
	title.text = "3D SPIKE — real meshes, 45° camera, real shadows"
	title.position = Vector3(0.0, 7.5, 0.0)
	title.pixel_size = 0.012
	title.modulate = Color(0.8, 0.9, 1.0)
	add_child(title)

	_tower = _make_tower()
	add_child(_tower)

	for i in 6:
		var u : MeshInstance3D = _make_unit(Color(0.95, 0.5, 0.45))
		u.position = Vector3(-12.0 + float(i) * 2.2, 0.5, -12.0 - float(i) * 1.4)
		add_child(u)
		_units.append(u)

func _make_tower() -> Node3D:
	var root : Node3D = Node3D.new()

	var body : MeshInstance3D = MeshInstance3D.new()
	var cyl : CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 2.0
	cyl.height = 2.6
	cyl.radial_segments = 8          ## octagon — mirrors the in-game T3 plate
	body.mesh = cyl
	body.position = Vector3(0.0, 1.3, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var bm : StandardMaterial3D = StandardMaterial3D.new()
	bm.albedo_color = Color(0.3, 0.55, 1.0)
	body.material_override = bm
	root.add_child(body)

	_core = MeshInstance3D.new()
	var sp : SphereMesh = SphereMesh.new()
	sp.radius = 0.62
	sp.height = 1.24
	_core.mesh = sp
	_core.position = Vector3(0.0, 2.9, 0.0)
	var cm : StandardMaterial3D = StandardMaterial3D.new()
	cm.albedo_color = Color(1.0, 0.95, 0.6)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.9, 0.5)
	cm.emission_energy_multiplier = 2.0
	_core.material_override = cm
	root.add_child(_core)

	_turret = Node3D.new()
	_turret.position = Vector3(0.0, 1.8, 0.0)
	var barrel : MeshInstance3D = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(0.5, 0.5, 2.6)
	barrel.mesh = bx
	barrel.position = Vector3(0.0, 0.0, -1.5)   ## extends toward -Z so look_at() aims it at the target
	var brm : StandardMaterial3D = StandardMaterial3D.new()
	brm.albedo_color = Color(0.2, 0.35, 0.7)
	barrel.material_override = brm
	_turret.add_child(barrel)
	root.add_child(_turret)

	return root

func _make_unit(col: Color) -> MeshInstance3D:
	var u : MeshInstance3D = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(1.1, 1.1, 1.1)
	u.mesh = bx
	u.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	u.material_override = m
	return u

func _process(delta: float) -> void:
	_pulse += delta * 4.0
	if _core != null:
		var s : float = 1.0 + sin(_pulse) * 0.12
		_core.scale = Vector3(s, s, s)

	var nearest : MeshInstance3D = null
	var nd : float = 1e9
	for u in _units:
		var flat_t : Vector3 = Vector3(0.0, u.position.y, 0.0)
		if u.position.distance_to(flat_t) > 3.0:
			u.position += (flat_t - u.position).normalized() * 2.6 * delta
		u.rotate_y(delta * 1.5)
		var d : float = u.position.length()
		if d < nd:
			nd = d
			nearest = u
	if nearest != null and _turret != null:
		var look : Vector3 = Vector3(nearest.position.x, _turret.global_position.y, nearest.position.z)
		_turret.look_at(look, Vector3.UP)
