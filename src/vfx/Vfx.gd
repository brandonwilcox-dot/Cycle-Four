## Cosmetic combat VFX factory: projectile bolts, muzzle flashes, impact/death
## spark bursts, and death poofs. Autoload (`Vfx`). Effects spawn into a
## world-space VfxLayer under WorldMap so the camera transform applies.
##
## PURELY VISUAL — never applies damage or touches gameplay state. Towers still
## hit instantly; bolts are decorative tracers. If the battle world isn't present
## (e.g. headless/offline), every method no-ops safely.
extends Node

const BOLT_SCRIPT  := preload("res://src/vfx/VfxBolt.gd")
const PULSE_SCRIPT := preload("res://src/vfx/VfxPulse.gd")

## Tint per Combat.DamageType (KINETIC / ENERGY / CORROSIVE).
const DAMAGE_COLORS : Array[Color] = [
	Color(1.0, 0.92, 0.55),   ## Kinetic   — pale gold tracer
	Color(0.45, 0.85, 1.0),   ## Energy    — cyan
	Color(0.55, 1.0, 0.5),    ## Corrosive — acid green
]

## Death-poof tint per faction id (plural, matching faction_id fields).
const FACTION_COLORS := {
	"architects": Color(0.45, 0.7, 1.0),
	"bloom":      Color(0.55, 0.95, 0.45),
	"mesh":       Color(0.8, 0.45, 1.0),
}

var _layer      : Node2D    = null
var _spark_tex  : Texture2D = null

func damage_color(damage_type: int) -> Color:
	if damage_type >= 0 and damage_type < DAMAGE_COLORS.size():
		return DAMAGE_COLORS[damage_type]
	return Color(1.0, 0.85, 0.6)

func faction_color(faction_id: String) -> Color:
	return FACTION_COLORS.get(faction_id, Color(0.8, 0.8, 0.85))

## A traveling tracer from -> to, tinted by damage type, that spawns an impact
## spark burst on arrival.
func bolt(from: Vector2, to: Vector2, damage_type: int) -> void:
	var layer : Node2D = _layer_node()
	if layer == null:
		return
	var b : Node2D = BOLT_SCRIPT.new()
	layer.add_child(b)
	b.setup(from, to, damage_color(damage_type))

## Quick bright bloom at a firing point.
func muzzle(at: Vector2, damage_type: int) -> void:
	_pulse(at, damage_color(damage_type), 14.0, 0.12, false)

## Faction-tinted poof + sparks when a unit dies.
func death(at: Vector2, faction_col: Color, radius: float) -> void:
	_pulse(at, faction_col, max(radius, 18.0), 0.35, true)
	spark_burst(at, faction_col, 12, 130.0)

## Generic one-shot spark burst (used by bolts on impact and by death).
func spark_burst(at: Vector2, color: Color, amount: int, speed: float) -> void:
	var layer : Node2D = _layer_node()
	if layer == null:
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = _spark_texture()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = max(1, amount)
	p.lifetime = 0.45
	p.spread = 180.0
	p.direction = Vector2.RIGHT
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2.ZERO
	p.damping_min = 140.0
	p.damping_max = 240.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	layer.add_child(p)
	_free_after(p, 0.9)

## -- Internal --

func _pulse(at: Vector2, color: Color, max_radius: float, life: float, filled: bool) -> void:
	var layer : Node2D = _layer_node()
	if layer == null:
		return
	var pu : Node2D = PULSE_SCRIPT.new()
	layer.add_child(pu)
	pu.setup(at, color, max_radius, life, filled)

## Lazily resolve (and cache) the world-space VFX layer under WorldMap.
func _layer_node() -> Node2D:
	if is_instance_valid(_layer):
		return _layer
	var battle : Node = get_tree().get_first_node_in_group("main_controller")
	if battle == null:
		return null
	var world : Node = battle.get_node_or_null("WorldMap")
	if world == null:
		return null
	var existing : Node = world.get_node_or_null("VfxLayer")
	if existing != null and existing is Node2D:
		_layer = existing
		return _layer
	var layer := Node2D.new()
	layer.name = "VfxLayer"
	layer.z_index = 50   ## render above units/towers
	world.add_child(layer)
	_layer = layer
	return _layer

## Small white square texture so CPUParticles2D sparks are visible without an
## external asset (tinted per call). Cached after first build.
func _spark_texture() -> Texture2D:
	if _spark_tex != null:
		return _spark_tex
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex

func _free_after(node: Node, secs: float) -> void:
	var timer : SceneTreeTimer = get_tree().create_timer(secs)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free())
