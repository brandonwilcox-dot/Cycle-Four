## A cosmetic 3D pulse (migration Stage 4): an expanding, fading emissive sphere used for muzzle
## flashes and death poofs. Self-frees when its lifetime elapses. Decoration only.
extends Node3D

var _color : Color = Color.WHITE
var _max_r : float = 16.0
var _life  : float = 0.3
var _age   : float = 0.0
var _mesh  : MeshInstance3D = null
var _mat   : StandardMaterial3D = null

func setup(at3: Vector3, color: Color, max_radius: float, life: float) -> void:
	position = at3
	_color = color
	_max_r = max_radius
	_life = maxf(0.01, life)

	_mesh = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	_mesh.mesh = sp
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 2.0
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	var t : float = _age / _life
	var r : float = _max_r * t
	_mesh.scale = Vector3(r, r, r)            ## unit sphere → scale = radius
	_mat.albedo_color.a = 1.0 - t
