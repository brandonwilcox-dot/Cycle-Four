## Cosmetic combat VFX factory (3D — migration Stage 4): projectile bolts, muzzle flashes,
## impact/death spark bursts, and death poofs. Autoload (`Vfx`). Public API takes LOGICAL PLANE
## coords (Vector2, pixel units) — callers (Tower/Unit/Commander/…) are unchanged from the 2D pass;
## this converts to 3D via World3D and spawns Node3D effects into a VfxLayer under the MapGrid.
##
## PURELY VISUAL — never applies damage. No-ops safely if no map (group "map_grid") is present.
extends Node

const BOLT_SCRIPT  := preload("res://src/vfx/VfxBolt.gd")
const PULSE_SCRIPT := preload("res://src/vfx/VfxPulse.gd")
const WORLD3D      := preload("res://src/core/World3D.gd")

## Tint per Combat.DamageType (KINETIC / ENERGY / CORROSIVE).
const DAMAGE_COLORS : Array[Color] = [
	Color(1.0, 0.92, 0.55),   ## Kinetic   — pale gold tracer
	Color(0.45, 0.85, 1.0),   ## Energy    — cyan
	Color(0.55, 1.0, 0.5),    ## Corrosive — acid green
]
const FACTION_COLORS := {
	"architects": Color(0.45, 0.7, 1.0),
	"bloom":      Color(0.55, 0.95, 0.45),
	"mesh":       Color(0.8, 0.45, 1.0),
}

const BOLT_Y  : float = 24.0   ## tracers/muzzle fly at ~mid-entity height
const DEATH_Y : float = 12.0

var _layer : Node3D = null

func damage_color(damage_type: int) -> Color:
	if damage_type >= 0 and damage_type < DAMAGE_COLORS.size():
		return DAMAGE_COLORS[damage_type]
	return Color(1.0, 0.85, 0.6)

func faction_color(faction_id: String) -> Color:
	return FACTION_COLORS.get(faction_id, Color(0.8, 0.8, 0.85))

## A traveling tracer (plane from -> to), tinted by damage type, spawning an impact burst on arrival.
func bolt(from2: Vector2, to2: Vector2, damage_type: int) -> void:
	var layer : Node3D = _layer_node()
	if layer == null:
		return
	var b : Node3D = BOLT_SCRIPT.new()
	layer.add_child(b)
	b.setup(WORLD3D.to3(from2, BOLT_Y), WORLD3D.to3(to2, BOLT_Y), damage_color(damage_type))

## Quick bright bloom at a firing point.
func muzzle(at2: Vector2, damage_type: int) -> void:
	_pulse(WORLD3D.to3(at2, BOLT_Y), damage_color(damage_type), 16.0, 0.12)

## Faction-tinted poof + sparks when a unit dies.
func death(at2: Vector2, faction_col: Color, radius: float) -> void:
	_pulse(WORLD3D.to3(at2, DEATH_Y), faction_col, maxf(radius, 22.0), 0.35)
	spark_burst3(WORLD3D.to3(at2, DEATH_Y), faction_col, 14, 130.0)

## Plane-space spark burst wrapper (kept for API symmetry).
func spark_burst(at2: Vector2, color: Color, amount: int, speed: float) -> void:
	spark_burst3(WORLD3D.to3(at2, BOLT_Y), color, amount, speed)

## 3D spark burst — a one-shot CPUParticles3D explosion of small emissive cubes.
func spark_burst3(at3: Vector3, color: Color, amount: int, speed: float) -> void:
	var layer : Node3D = _layer_node()
	if layer == null:
		return
	var p := CPUParticles3D.new()
	p.position = at3
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(1, amount)
	p.lifetime = 0.5
	p.mesh = _spark_mesh(color)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3.ZERO
	p.damping_min = 120.0
	p.damping_max = 220.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	layer.add_child(p)
	_free_after(p, 1.0)

## -- Internal --

func _pulse(at3: Vector3, color: Color, max_radius: float, life: float) -> void:
	var layer : Node3D = _layer_node()
	if layer == null:
		return
	var pu : Node3D = PULSE_SCRIPT.new()
	layer.add_child(pu)
	pu.setup(at3, color, max_radius, life)

## Lazily resolve (and cache) the world-space VFX layer under the MapGrid (a Node3D at world origin).
func _layer_node() -> Node3D:
	if is_instance_valid(_layer):
		return _layer
	var mg : Node = get_tree().get_first_node_in_group("map_grid")
	if mg == null or not (mg is Node3D):
		return null
	var existing : Node = mg.get_node_or_null("VfxLayer")
	if existing != null and existing is Node3D:
		_layer = existing
		return _layer
	var layer := Node3D.new()
	layer.name = "VfxLayer"
	mg.add_child(layer)
	_layer = layer
	return _layer

## Small emissive cube mesh for spark particles, tinted per burst.
func _spark_mesh(color: Color) -> Mesh:
	var bx := BoxMesh.new()
	bx.size = Vector3(4.0, 4.0, 4.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bx.material = m
	return bx

func _free_after(node: Node, secs: float) -> void:
	var timer : SceneTreeTimer = get_tree().create_timer(secs)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())
