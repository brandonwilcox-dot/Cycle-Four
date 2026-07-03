## FactionPreview.gd — the faction showcase (user request 2026-07-03: "previews of the
## units… perhaps a menu option to customize your faction"). Reached from the Title screen.
## Shows each faction's Commander and unit archetypes on a slowly turning stage, dressed in
## the REAL substrate materials, under the REAL battle atmosphere — the Commander rigs run
## their idle animations live (Needle hover/halo, Broodmother breathing, Weaver signal ring).
##
## This screen is the intended home of cosmetic customization later (core/15 — palettes,
## prestige effects, skins). For now it is a viewer; the layout leaves room for that.
extends Node3D

const ATMOSPHERE  = preload("res://src/core/BattleAtmosphere.gd")
const SUBSTRATE   = preload("res://src/vfx/SubstrateMaterials.gd")
const UNIT_BODIES = preload("res://src/vfx/UnitBodies.gd")
const CMD_RIG     = preload("res://src/vfx/CommanderBodyRig.gd")
const TITLE_SCENE : String = "res://scenes/ui/TitleScreen.tscn"

const FACTIONS : Array = ["architects", "bloom", "mesh"]
const FACTION_TITLES : Dictionary = {
	"architects": "THE ARCHITECTS — crystalline lattice",
	"bloom":      "THE BLOOM — biological fiber",
	"mesh":       "THE MESH — conductive mesh",
}
const ROSTER_PREFIX : Dictionary = {"architects": "architect", "bloom": "bloom", "mesh": "mesh"}
## Display lineup: [label, x offset, uniform scale] — mirrors the battle archetypes.
const LINEUP : Array = [["LINE", -10.0, 1.0], ["RUNNER", 70.0, 0.8], ["BRUTE", 150.0, 1.25]]

var _stage : Node3D = null
var _title_label : Label = null
var _faction_idx : int = 0

func _ready() -> void:
	add_child(ATMOSPHERE.new())
	var cam : Camera3D = Camera3D.new()
	cam.fov = 45.0
	cam.position = Vector3(20.0, 105.0, 220.0)
	add_child(cam)
	cam.look_at(Vector3(20.0, 28.0, 0.0), Vector3.UP)
	## Display floor — a wide dark disc so the stage reads as a place, not a void.
	var floor_mesh : CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = 280.0
	floor_mesh.bottom_radius = 280.0
	floor_mesh.height = 4.0
	var floor_mi : MeshInstance3D = MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.position = Vector3(20.0, -2.0, 0.0)
	var fm : StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.10, 0.12, 0.15)
	fm.roughness = 0.9
	floor_mi.material_override = fm
	add_child(floor_mi)
	_stage = Node3D.new()
	_stage.position = Vector3(20.0, 0.0, 0.0)
	add_child(_stage)
	_build_ui()
	_show_faction(0)

func _process(delta: float) -> void:
	if _stage != null:
		_stage.rotate_y(delta * 0.22)   ## slow turntable

func _show_faction(idx: int) -> void:
	_faction_idx = wrapi(idx, 0, FACTIONS.size())
	var fac : String = FACTIONS[_faction_idx]
	if _title_label != null:
		_title_label.text = FACTION_TITLES.get(fac, fac)
	for c in _stage.get_children():
		c.queue_free()

	## Commander — built exactly as in battle: body mesh + substrate + CommanderBodyRig.
	## The rig's idle animation runs here (its is_moving() poll finds no such method → idle).
	var cmd_holder : Node3D = Node3D.new()
	cmd_holder.position = Vector3(-105.0, 0.0, 0.0)
	_stage.add_child(cmd_holder)
	var cmd_body : MeshInstance3D = MeshInstance3D.new()
	cmd_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cmat : StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.82, 0.18)
	SUBSTRATE.apply(cmat, fac)
	cmd_body.material_override = cmat
	cmd_holder.add_child(cmd_body)
	var rig : Node3D = CMD_RIG.new()
	cmd_holder.add_child(rig)
	rig.call("setup", fac, cmd_body, cmat)
	cmd_body.position = Vector3(0.0, float(rig.get("body_lift")), 0.0)
	_label(cmd_holder, "COMMANDER", float(rig.get("bar_y")) + 16.0)

	## Unit archetypes — the real roster color + substrate + composed body per archetype.
	var ud : UnitData = load("res://resources/units/%s_t1.tres" % ROSTER_PREFIX.get(fac, "mesh"))
	for entry in LINEUP:
		var holder : Node3D = Node3D.new()
		holder.position = Vector3(float(entry[1]), 0.0, 0.0)
		holder.scale = Vector3.ONE * float(entry[2])
		_stage.add_child(holder)
		var body : MeshInstance3D = MeshInstance3D.new()
		body.position = Vector3(0.0, 17.0, 0.0)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var m : StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = ud.color_hint if ud != null else Color.WHITE
		SUBSTRATE.apply(m, fac, false)
		body.material_override = m
		UNIT_BODIES.compose(body, fac, 24.0, m)
		holder.add_child(body)
		_label(holder, str(entry[0]), 44.0)

func _label(parent: Node3D, text: String, y: float) -> void:
	var l : Label3D = Label3D.new()
	l.text = text
	l.position = Vector3(0.0, y, 0.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.pixel_size = 0.35
	l.modulate = Color(0.85, 0.90, 1.00, 0.9)
	l.outline_size = 8
	parent.add_child(l)

## -- UI ---------------------------------------------------------------------------------

func _build_ui() -> void:
	var cl : CanvasLayer = CanvasLayer.new()
	add_child(cl)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position = Vector2(-400.0, 36.0)
	_title_label.size = Vector2(800.0, 60.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	cl.add_child(_title_label)

	var hint : Label = Label.new()
	hint.text = "Faction preview — cosmetic customization will live here."
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(-400.0, 84.0)
	hint.size = Vector2(800.0, 30.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70))
	cl.add_child(hint)

	var row : HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(-330.0, -80.0)
	row.add_theme_constant_override("separation", 14)
	cl.add_child(row)
	for i in FACTIONS.size():
		var b : Button = Button.new()
		b.text = str(FACTIONS[i]).capitalize()
		b.custom_minimum_size = Vector2(150.0, 44.0)
		b.add_theme_font_size_override("font_size", 18)
		var idx : int = i
		b.pressed.connect(func() -> void: _show_faction(idx))
		row.add_child(b)
	var back : Button = Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120.0, 44.0)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: SceneManager.change_to(TITLE_SCENE))
	row.add_child(back)
