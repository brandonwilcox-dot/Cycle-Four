## A cosmetic 3D tracer bolt (migration Stage 4): a thin emissive bar that travels from a start to a
## target point over a short lifetime, then spawns an impact spark burst and frees itself. Never
## applies damage — decoration only.
extends Node3D

const SPEED     : float = 1400.0   ## px/s — sets lifetime from distance
const MIN_LIFE  : float = 0.04
const MAX_LIFE  : float = 0.18
const TRAIL_LEN : float = 40.0

var _from  : Vector3
var _to    : Vector3
var _color : Color = Color.WHITE
var _life  : float = 0.1
var _age   : float = 0.0
var _done  : bool  = false

func setup(from3: Vector3, to3: Vector3, color: Color) -> void:
	_from = from3
	_to = to3
	_color = color
	position = from3
	var dist : float = from3.distance_to(to3)
	_life = clampf(dist / SPEED, MIN_LIFE, MAX_LIFE)

	var mesh := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(3.0, 3.0, TRAIL_LEN)   ## length along local -Z (look_at axis)
	mesh.mesh = bx
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

	## Orient the bar along the travel direction (look_at points local -Z at the target).
	if dist > 0.01:
		look_at(to3, Vector3.UP)

func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var t : float = clampf(_age / _life, 0.0, 1.0)
	position = _from.lerp(_to, t)
	if _age >= _life:
		_done = true
		Vfx.spark_burst3(_to, _color, 8, 140.0)
		queue_free()
