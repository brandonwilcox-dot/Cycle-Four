## NavMarker.gd — the Commander's move-order marker: a planted FACTION STANDARD.
##
## Replaces the old red placeholder cube. A standard reads as an order the player gave (a
## banner staked into the ground) rather than a debug gizmo, and it carries faction identity:
## the flag is the faction's substrate color, the finial and ground ring glow with it.
##
## Animated, because a static flag looks dead: the cloth ripples on a travelling sine wave,
## the whole banner sways, the finial spins slowly, and the ground ring pulses. One marker is
## spawned per queued destination, so a shift-chained route plants a line of standards.
##
## PURELY COSMETIC — never touches movement, pathing, or gameplay state.
extends Node3D

const POLE_HEIGHT : float = 46.0
const POLE_RADIUS : float = 1.1
const FLAG_W      : float = 26.0   ## cloth length out from the pole
const FLAG_H      : float = 15.0
const FLAG_TOP    : float = 42.0   ## cloth hangs from here down
const SEGMENTS    : int   = 10     ## cloth subdivisions along its length (ripple resolution)

var _color     : Color = Color(0.45, 0.7, 1.0)
var _flag      : MeshInstance3D = null
var _flag_mesh : ImmediateMesh  = null
var _flag_mat  : StandardMaterial3D = null
var _finial    : MeshInstance3D = null
var _ring      : MeshInstance3D = null
var _ring_mat  : StandardMaterial3D = null
var _t         : float = 0.0
var _phase     : float = 0.0   ## per-marker offset so a row of standards doesn't ripple in lockstep

## `faction_color` comes from Vfx.faction_color(); `index` staggers the animation phase.
func setup(faction_color: Color, index: int = 0) -> void:
	_color = faction_color
	_phase = float(index) * 0.7

func _ready() -> void:
	_build()

func _build() -> void:
	var glow : Color = _color.lerp(Color.WHITE, 0.25)

	## Pole — a slim dark shaft so the cloth reads against it.
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = POLE_RADIUS
	pm.bottom_radius = POLE_RADIUS * 1.35
	pm.height = POLE_HEIGHT
	pm.radial_segments = 6
	pole.mesh = pm
	pole.position = Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.13, 0.15, 0.19)
	pole_mat.metallic = 0.6
	pole_mat.roughness = 0.35
	pole.material_override = pole_mat
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pole)

	## Finial — a glowing faction-colored tip that spins.
	_finial = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 2.6
	fm.height = 6.4
	fm.radial_segments = 6
	fm.rings = 4
	_finial.mesh = fm
	_finial.position = Vector3(0.0, POLE_HEIGHT + 2.0, 0.0)
	_finial.material_override = _emissive(glow, 3.2)
	_finial.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_finial)

	## Cloth — rebuilt per frame into an ImmediateMesh so it can ripple.
	_flag = MeshInstance3D.new()
	_flag_mesh = ImmediateMesh.new()
	_flag.mesh = _flag_mesh
	_flag_mat = _emissive(_color, 1.5)
	_flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED   ## visible from both sides
	_flag.material_override = _flag_mat
	_flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flag)

	## Ground ring — marks the exact destination cell and pulses.
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 11.0
	tm.outer_radius = 13.5
	tm.rings = 6
	tm.ring_segments = 20
	_ring.mesh = tm
	_ring.position = Vector3(0.0, 0.6, 0.0)
	_ring_mat = _emissive(glow, 2.2)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

func _emissive(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _process(delta: float) -> void:
	_t += delta
	var t : float = _t + _phase
	## Banner sway — the whole standard leans gently, as if in wind.
	rotation.z = sin(t * 1.1) * 0.035
	rotation.y = sin(t * 0.45) * 0.20
	if _finial != null:
		_finial.rotation.y += delta * 1.6
	if _ring != null:
		var pulse : float = 1.0 + 0.10 * sin(t * 2.4)
		_ring.scale = Vector3(pulse, 1.0, pulse)
		if _ring_mat != null:
			_ring_mat.emission_energy_multiplier = 1.7 + 0.9 * (0.5 + 0.5 * sin(t * 2.4))
	_rebuild_flag(t)

## Cloth as a travelling sine wave: amplitude grows toward the free edge (pinned at the pole),
## and the trailing edge lifts, so it reads as fabric catching wind rather than a rigid plane.
func _rebuild_flag(t: float) -> void:
	if _flag_mesh == null:
		return
	_flag_mesh.clear_surfaces()
	_flag_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var u : float = float(i) / float(SEGMENTS)
		var x : float = u * FLAG_W
		## ripple: zero at the pole, strongest at the free edge
		var wave : float = sin(u * 5.0 - t * 5.5) * (u * u) * 3.4
		var lift : float = sin(u * 2.2 - t * 3.0) * u * 1.6
		_flag_mesh.surface_set_uv(Vector2(u, 0.0))
		_flag_mesh.surface_add_vertex(Vector3(x, FLAG_TOP + lift, wave))
		_flag_mesh.surface_set_uv(Vector2(u, 1.0))
		_flag_mesh.surface_add_vertex(Vector3(x, FLAG_TOP - FLAG_H + lift * 0.6, wave * 0.85))
	_flag_mesh.surface_end()
