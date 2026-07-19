## Husk.gd
## U4 (units-land-plan / Units_Land §4) — a wreckage husk left when a unit dies, ON THE FIELD, for
## an Assimilator-Bloom army to consume (the "take/absorb" heresy borrowed from Mesh). Spawned by
## Unit._die only while the player is on the assimilator sub-path (no husks are made otherwise, so
## the mechanic costs nothing for every other faction/path).
##
## Deliberately scriptable-but-tiny: a Node3D in the "husks" group with a plane position, a resource
## `amount`, and a short lifetime. FriendlyUnit (WRECKAGE_ABSORB) consumes the nearest husk in radius.
extends Node3D

const WORLD3D = preload("res://src/core/World3D.gd")

const LIFETIME : float = 12.0   ## husks decay if nobody assimilates them

var amount : float = 8.0        ## primary resource granted on absorb
var _p     : Vector2 = Vector2.ZERO
var _life  : float = LIFETIME

func setup(p: Vector2, amt: float) -> void:
	_p     = p
	amount = amt
	position = WORLD3D.to3(_p, 0.0)

func plane_pos() -> Vector2:
	return _p

func _ready() -> void:
	add_to_group("husks")
	position = WORLD3D.to3(_p, 0.0)
	_build_visual()

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _build_visual() -> void:
	## A low, dim husk marker — reads as spent matter, not a live unit.
	var m : MeshInstance3D = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(12.0, 4.0, 12.0)
	m.mesh = bx
	m.position = Vector3(0.0, 2.0, 0.0)
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.22, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(0.12, 0.2, 0.08)
	mat.emission_energy_multiplier = 0.5
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
