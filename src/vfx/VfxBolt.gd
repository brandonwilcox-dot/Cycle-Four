## A cosmetic 3D PROJECTILE (2026-07-21 realistic pass): a shaped, oriented mesh round that
## travels from a start to a target and spawns an impact burst on arrival. The form is chosen
## by KIND so each weapon/damage-type fires believable ordnance instead of a flat bar:
##   BULLET  — kinetic tracer round + glowing streak (drones, machine gun, rail-gun)
##   ENERGY  — bright energy bolt spindle (lasers, energy weapons)
##   PLASMA  — corrosive glowing glob + comet tail
##   ROCKET  — rocket body (nose/body/flame) + grey smoke trail, slower
##   ARC     — thin lightning beam (fast, point-to-point)
## NEVER applies damage — decoration only; damage is dealt instantly by the firer.
extends Node3D

enum { BULLET, ENERGY, PLASMA, ROCKET, ARC }

## Per-kind travel speed (px/s) → lifetime from distance.
const SPEED := {
	BULLET: 1900.0, ENERGY: 2600.0, PLASMA: 1200.0, ROCKET: 720.0, ARC: 4200.0,
}
const MIN_LIFE : float = 0.035
const MAX_LIFE : float = 0.5

var _from  : Vector3
var _to    : Vector3
var _color : Color = Color.WHITE
var _kind  : int   = BULLET
var _life  : float = 0.1
var _age   : float = 0.0
var _done  : bool  = false
var _spin  : Node3D = null
## BALLISTIC FLIGHT WITH DRAG (siege ordnance), as Vector4(vx0, vy0, gravity, drag):
##   horizontal  x(s) = vx0·(1 − e^(−k·s)) / k     — forward speed decays, the round SLOWS
##   vertical    y(s) = vy0·s − ½·g·s²             — gravity keeps accumulating
## Drag is the whole point. A plain parabola holds its horizontal speed, so its descent only
## ever mirrors its climb; with drag the shell leaves fast and shallow, visibly loses way, and
## the last third plunges. The firer solved its barrel elevation from these same numbers, so
## the round leaves collinear with the bore. Zero vector -> ordinary straight tracer.
var _vx0   : float = 0.0
var _vy0   : float = 0.0
var _grav  : float = 0.0
var _drag  : float = 0.0
var _flight: float = 0.0
const MAX_FLIGHT : float = 2.5

func setup(from3: Vector3, to3: Vector3, color: Color, kind: int = BULLET,
		flight_params: Vector4 = Vector4.ZERO) -> void:
	_from = from3
	_to = to3
	_color = color
	_kind = kind
	position = from3
	var dist : float = from3.distance_to(to3)
	_life = clampf(dist / float(SPEED.get(kind, 1900.0)), MIN_LIFE, MAX_LIFE)
	if flight_params != Vector4.ZERO:
		_vx0 = flight_params.x
		_vy0 = flight_params.y
		_grav = flight_params.z
		_drag = flight_params.w
		## Invert the horizontal law for the flight time so the shell lands exactly on target.
		var flat : float = Vector2(to3.x - from3.x, to3.z - from3.z).length()
		if _drag > 0.0 and _vx0 > 0.0 and _drag * flat < _vx0 * 0.995:
			_flight = clampf(-log(1.0 - _drag * flat / _vx0) / _drag, 0.02, MAX_FLIGHT)
			_life = _flight
		else:
			_grav = 0.0   ## unreachable or degenerate — fall back to a straight tracer
	if dist > 0.01:
		look_at(to3, Vector3.UP)   ## local -Z now points at the target

	## A spin pivot so asymmetric ordnance (rocket fins) can roll along its axis.
	_spin = Node3D.new()
	add_child(_spin)
	match kind:
		ENERGY:   _build_energy(color)
		PLASMA:   _build_plasma(color)
		ROCKET:   _build_rocket(color)
		ARC:      _build_arc(color, dist)
		_:        _build_bullet(color)

## -- projectile bodies (all elongated along local -Z to match look_at) --

func _emissive(col: Color, energy: float, unshaded: bool = true, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, orient: Basis = Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(orient, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(mi)
	return mi

## Kinetic tracer: a stubby bright round + a long tapering streak behind it.
func _build_bullet(col: Color) -> void:
	var head := CapsuleMesh.new()
	head.radius = 1.5; head.height = 8.0; head.radial_segments = 6; head.rings = 1
	_add_mesh(head, _emissive(col.lerp(Color.WHITE, 0.4), 4.0),
		Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5))   ## capsule Y-axis → local Z
	var trail := CylinderMesh.new()
	trail.top_radius = 0.15; trail.bottom_radius = 1.1; trail.height = 46.0; trail.radial_segments = 6
	_add_mesh(trail, _emissive(col, 2.2, true, true),
		Vector3(0, 0, 23.0), Basis(Vector3.RIGHT, PI * 0.5))   ## streak recedes +Z (behind)

## Energy bolt: a long bright spindle, additive glow.
func _build_energy(col: Color) -> void:
	var body := CapsuleMesh.new()
	body.radius = 2.2; body.height = 22.0; body.radial_segments = 8; body.rings = 1
	_add_mesh(body, _emissive(col.lerp(Color.WHITE, 0.5), 6.0),
		Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5))
	var halo := CapsuleMesh.new()
	halo.radius = 4.2; halo.height = 30.0; halo.radial_segments = 8; halo.rings = 1
	var hm := _emissive(col, 2.4, true, true)
	hm.albedo_color = Color(col.r, col.g, col.b, 0.5)
	_add_mesh(halo, hm, Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5))

## Corrosive plasma: a glowing glob with a short comet tail.
func _build_plasma(col: Color) -> void:
	var glob := SphereMesh.new()
	glob.radius = 3.4; glob.height = 6.8; glob.radial_segments = 8; glob.rings = 5
	_add_mesh(glob, _emissive(col.lerp(Color.WHITE, 0.25), 4.5), Vector3.ZERO)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.1; tail.bottom_radius = 2.6; tail.height = 34.0; tail.radial_segments = 6
	_add_mesh(tail, _emissive(col, 2.0, true, true),
		Vector3(0, 0, 17.0), Basis(Vector3.RIGHT, PI * 0.5))

## Rocket: gunmetal body + nose + flame, with a grey smoke trail. Slower, so it reads.
func _build_rocket(_col: Color) -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.28, 0.28, 0.30); steel.metallic = 0.7; steel.roughness = 0.4
	var body := CylinderMesh.new()
	body.top_radius = 1.6; body.bottom_radius = 1.6; body.height = 12.0; body.radial_segments = 8
	_add_mesh(body, steel, Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5))
	var nose := CylinderMesh.new()
	nose.top_radius = 0.05; nose.bottom_radius = 1.6; nose.height = 5.0; nose.radial_segments = 8
	_add_mesh(nose, steel, Vector3(0, 0, -8.5), Basis(Vector3.RIGHT, -PI * 0.5))
	## three fins at the tail
	for fi in 3:
		var fin := BoxMesh.new(); fin.size = Vector3(0.4, 3.4, 3.4)
		var roll := Basis(Vector3(0, 0, 1), float(fi) * TAU / 3.0)
		_add_mesh(fin, steel, roll * Vector3(0, 0, 6.2), roll)
	## bright exhaust flame
	var flame := CylinderMesh.new()
	flame.top_radius = 1.3; flame.bottom_radius = 0.1; flame.height = 9.0; flame.radial_segments = 6
	_add_mesh(flame, _emissive(Color(1.0, 0.65, 0.25), 5.0, true, true),
		Vector3(0, 0, 10.5), Basis(Vector3.RIGHT, PI * 0.5))
	## grey smoke trail (emits backward in world space)
	var smoke := CPUParticles3D.new()
	smoke.amount = 26; smoke.lifetime = 0.6; smoke.local_coords = false
	smoke.direction = Vector3(0, 0, 1); smoke.spread = 8.0
	smoke.initial_velocity_min = 40.0; smoke.initial_velocity_max = 80.0
	smoke.gravity = Vector3.ZERO
	smoke.scale_amount_min = 2.0; smoke.scale_amount_max = 5.0
	var puff := SphereMesh.new(); puff.radius = 1.0; puff.height = 2.0
	puff.radial_segments = 5; puff.rings = 3
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.5, 0.5, 0.52, 0.5)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = pm
	smoke.mesh = puff
	add_child(smoke)   ## on the root so it doesn't inherit the spin

## Lightning arc: a thin bright beam spanning the whole gap (near-instant).
func _build_arc(col: Color, dist: float) -> void:
	var beam := CylinderMesh.new()
	beam.top_radius = 0.9; beam.bottom_radius = 0.9; beam.height = maxf(dist, 1.0)
	beam.radial_segments = 5
	## centred between the endpoints, spanning local -Z
	_add_mesh(beam, _emissive(col.lerp(Color.WHITE, 0.55), 6.0, true, true),
		Vector3(0, 0, -dist * 0.5), Basis(Vector3.RIGHT, PI * 0.5))

func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var t : float = clampf(_age / _life, 0.0, 1.0)
	if _kind != ARC:
		if _grav > 0.0:
			var s : float = t * _flight
			var flat : Vector3 = Vector3(_to.x - _from.x, 0.0, _to.z - _from.z)
			var span : float = flat.length()
			var dir : Vector3 = flat / span if span > 0.001 else Vector3.FORWARD
			## Horizontal distance covered so far, decaying with drag.
			var travelled : float = _vx0 * (1.0 - exp(-_drag * s)) / _drag
			position = _from + dir * travelled + Vector3.UP * (_vy0 * s - 0.5 * _grav * s * s)
			## Nose along the CURRENT velocity — forward speed bleeding off while the vertical
			## keeps building is what makes the shell tip over into its terminal plunge.
			var vel : Vector3 = dir * (_vx0 * exp(-_drag * s)) \
				+ Vector3.UP * (_vy0 - _grav * s)
			if vel.length_squared() > 0.001:
				look_at(position + vel, Vector3.UP)
		else:
			position = _from.lerp(_to, t)
	if _spin != null and (_kind == ROCKET or _kind == PLASMA):
		_spin.rotate_object_local(Vector3(0, 0, 1), delta * 12.0)
	if _age >= _life:
		_done = true
		var amt : int = 12 if _kind == ROCKET else 8
		Vfx.spark_burst3(_to, _color, amt, 150.0)
		queue_free()
