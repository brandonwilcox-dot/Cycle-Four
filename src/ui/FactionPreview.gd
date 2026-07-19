## FactionPreview.gd — faction showcase + UNIT CUSTOMIZER (core/15; user directive
## 2026-07-18). Reached from the Title screen. Left: the turntable stage showing the
## Commander + T1 archetypes built exactly as in battle (real substrate materials, real
## Commander rig, real battle atmosphere). Right: the customizer panel — part slots
## (Head/Torso/Arms/Legs + faction Extra), three variation presets, and a color palette
## (faction swatches + free picker) for primary/secondary/glow channels.
##
## Everything here is available regardless of game state — the customizer exists to
## expose designs playtesting can't reach. Choices persist to user://cosmetics.json
## (Cosmetics.gd) and apply to the PLAYER's Commander + friendly units only.
extends Node3D

const ATMOSPHERE  = preload("res://src/core/BattleAtmosphere.gd")
const SUBSTRATE   = preload("res://src/vfx/SubstrateMaterials.gd")
const UNIT_BODIES = preload("res://src/vfx/UnitBodies.gd")
const ASSET_LOADER = preload("res://src/core/AssetLoader.gd")
const CMD_RIG     = preload("res://src/vfx/CommanderBodyRig.gd")
const COSMETICS   = preload("res://src/core/cosmetics/Cosmetics.gd")
const TITLE_SCENE : String = "res://scenes/ui/TitleScreen.tscn"

const FACTIONS : Array = ["architects", "bloom", "mesh"]
const FACTION_TITLES : Dictionary = {
	"architects": "THE ARCHITECTS — crystalline lattice",
	"bloom":      "THE BLOOM — biological fiber",
	"mesh":       "THE MESH — conductive mesh",
}
const ROSTER_PREFIX : Dictionary = {"architects": "architect", "bloom": "bloom", "mesh": "mesh"}
## Display lineup mirrors the customizable units: [unit_key, label, x offset, scale].
const LINEUP : Array = [
	["line", "LINE", -15.0, 1.0], ["scout", "SCOUT", 60.0, 0.85],
	["artillery", "ARTILLERY", 140.0, 1.1],
]
const UNIT_LABELS : Dictionary = {
	"commander": "Commander", "line": "Line", "scout": "Scout", "artillery": "Artillery",
}

const COL_PANEL    : Color = Color(0.06, 0.07, 0.10, 0.92)
const COL_ACCENT   : Color = Color(0.95, 0.85, 0.45)
const COL_DIM      : Color = Color(0.55, 0.60, 0.70)

var _stage : Node3D = null
var _title_label : Label = null
var _faction_idx : int = 0
var _unit_key : String = "commander"

## Panel widgets refreshed on any change.
var _unit_btns : Dictionary = {}          ## unit_key -> Button
var _slot_value_labels : Dictionary = {}  ## slot -> Label
var _slot_name_labels : Dictionary = {}   ## slot -> Label (extra renames per faction)
var _custom_check : CheckBox = null
var _channel_pickers : Dictionary = {}    ## channel -> ColorPickerButton
var _swatch_rows : Dictionary = {}        ## channel -> HBoxContainer
var _unit_stage_labels : Dictionary = {}  ## unit_key -> Label3D (highlight selection)

func _ready() -> void:
	add_child(ATMOSPHERE.new())
	var cam : Camera3D = Camera3D.new()
	cam.fov = 45.0
	cam.position = Vector3(20.0, 105.0, 220.0)
	add_child(cam)
	cam.look_at(Vector3(20.0, 28.0, 0.0), Vector3.UP)
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
	_stage.position = Vector3(-30.0, 0.0, 0.0)   ## shifted left; panel owns the right edge
	add_child(_stage)
	_build_ui()
	_show_faction(0)

func _process(delta: float) -> void:
	if _stage != null:
		_stage.rotate_y(delta * 0.22)   ## slow turntable

## -- stage ------------------------------------------------------------------------------

func _faction() -> String:
	return FACTIONS[_faction_idx]

func _show_faction(idx: int) -> void:
	_faction_idx = wrapi(idx, 0, FACTIONS.size())
	if _title_label != null:
		_title_label.text = FACTION_TITLES.get(_faction(), _faction())
	_rebuild_stage()
	_refresh_panel()

func _rebuild_stage() -> void:
	var fac : String = _faction()
	_unit_stage_labels.clear()
	for c in _stage.get_children():
		c.queue_free()

	## Commander — exactly as in battle (rig applies cosmetics parts/tint itself).
	var cmd_holder : Node3D = Node3D.new()
	cmd_holder.position = Vector3(-115.0, 0.0, 0.0)
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
	_stage_label(cmd_holder, "commander", float(rig.get("bar_y")) + 16.0)

	## T1 archetypes — shared faction body per archetype, customized per unit_key.
	var ud : UnitData = load("res://resources/units/%s_t1.tres" % ROSTER_PREFIX.get(fac, "mesh"))
	for entry in LINEUP:
		_build_unit(str(entry[0]), str(entry[1]), float(entry[2]), float(entry[3]), fac, ud)

func _build_unit(key: String, label: String, x: float, sc: float, fac: String, ud: UnitData) -> void:
	var holder : Node3D = Node3D.new()
	holder.position = Vector3(x, 0.0, 0.0)
	holder.scale = Vector3.ONE * sc
	_stage.add_child(holder)
	var base_col : Color = ud.color_hint if ud != null else Color.WHITE
	var col : Color = COSMETICS.primary_color(fac, key, base_col)
	var pivot : Node3D = Node3D.new()
	holder.add_child(pivot)
	var body_scale : float = 24.0
	var base_body : Node3D = null
	if fac in ASSET_LOADER.FACTION_MODELS:
		var model : Node3D = ASSET_LOADER.load_unit_model(fac, col, false)
		if model != null:
			pivot.position = Vector3(0.0, 14.0, 0.0)
			pivot.add_child(model)
			var mat : StandardMaterial3D = ASSET_LOADER.prepare_unit_material(model, col)
			if mat != null and COSMETICS.uses_custom_colors(fac, key):
				mat.albedo_color = mat.albedo_color.lerp(col, COSMETICS.CUSTOM_TINT_STRENGTH)
			base_body = model
			body_scale = 26.0
	if base_body == null:
		## Procedural composed silhouette fallback.
		pivot.position = Vector3(0.0, 17.0, 0.0)
		var body : MeshInstance3D = MeshInstance3D.new()
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var m : StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = col
		SUBSTRATE.apply(m, fac, false)
		COSMETICS.style_material(m, fac, key)
		body.material_override = m
		UNIT_BODIES.compose(body, fac, 24.0, m)
		pivot.add_child(body)
		base_body = body
	COSMETICS.attach_parts(pivot, fac, key, body_scale, base_body)
	_stage_label(holder, key, 44.0, label)

func _stage_label(parent: Node3D, unit_key: String, y: float, text: String = "") -> void:
	var l : Label3D = Label3D.new()
	l.text = text if not text.is_empty() else str(UNIT_LABELS.get(unit_key, unit_key)).to_upper()
	l.position = Vector3(0.0, y, 0.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.pixel_size = 0.35
	l.outline_size = 8
	l.modulate = COL_ACCENT if unit_key == _unit_key else Color(0.85, 0.90, 1.00, 0.9)
	parent.add_child(l)
	_unit_stage_labels[unit_key] = l

## -- UI ---------------------------------------------------------------------------------

func _build_ui() -> void:
	var cl : CanvasLayer = CanvasLayer.new()
	add_child(cl)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position = Vector2(-600.0, 36.0)
	_title_label.size = Vector2(800.0, 60.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", COL_ACCENT)
	cl.add_child(_title_label)

	var hint : Label = Label.new()
	hint.text = "Unit customizer — choices apply to YOUR units in battle and are saved automatically."
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(-600.0, 84.0)
	hint.size = Vector2(800.0, 30.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", COL_DIM)
	cl.add_child(hint)

	_build_customizer_panel(cl)

	var row : HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	row.position = Vector2(40.0, -80.0)
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

## The right-side customizer: unit selector / variations / part slots / colors.
func _build_customizer_panel(cl: CanvasLayer) -> void:
	var panel : PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -430.0
	panel.offset_top = 120.0
	panel.offset_bottom = -100.0
	panel.offset_right = -24.0
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.corner_radius_top_left = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	cl.add_child(panel)

	var scroll : ScrollContainer = ScrollContainer.new()
	panel.add_child(scroll)
	var vb : VBoxContainer = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	scroll.add_child(vb)

	_section(vb, "UNIT")
	var urow : HBoxContainer = HBoxContainer.new()
	urow.add_theme_constant_override("separation", 6)
	vb.add_child(urow)
	for key in COSMETICS.UNITS:
		var b : Button = Button.new()
		b.text = str(UNIT_LABELS.get(key, key))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0.0, 36.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k : String = str(key)
		b.pressed.connect(func() -> void: _select_unit(k))
		urow.add_child(b)
		_unit_btns[key] = b

	_section(vb, "DESIGN VARIATIONS")
	var vrow : HBoxContainer = HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 6)
	vb.add_child(vrow)
	for i in 3:
		var b : Button = Button.new()
		b.custom_minimum_size = Vector2(0.0, 34.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vidx : int = i
		b.pressed.connect(func() -> void: _apply_variation(vidx))
		vrow.add_child(b)
		b.set_meta("variation_idx", i)
	set_meta("variation_row", vrow)

	_section(vb, "PARTS")
	for slot in COSMETICS.SLOTS:
		var srow : HBoxContainer = HBoxContainer.new()
		srow.add_theme_constant_override("separation", 6)
		vb.add_child(srow)
		var name_l : Label = Label.new()
		name_l.custom_minimum_size = Vector2(96.0, 0.0)
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.add_theme_color_override("font_color", COL_DIM)
		srow.add_child(name_l)
		_slot_name_labels[slot] = name_l
		var prev : Button = Button.new()
		prev.text = "◀"
		prev.custom_minimum_size = Vector2(34.0, 32.0)
		var s1 : String = str(slot)
		prev.pressed.connect(func() -> void: _cycle_part(s1, -1))
		srow.add_child(prev)
		var val : Label = Label.new()
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 15)
		srow.add_child(val)
		_slot_value_labels[slot] = val
		var next : Button = Button.new()
		next.text = "▶"
		next.custom_minimum_size = Vector2(34.0, 32.0)
		next.pressed.connect(func() -> void: _cycle_part(s1, 1))
		srow.add_child(next)

	_section(vb, "COLORS")
	_custom_check = CheckBox.new()
	_custom_check.text = "Use custom colors"
	_custom_check.add_theme_font_size_override("font_size", 15)
	_custom_check.toggled.connect(_on_custom_toggled)
	vb.add_child(_custom_check)
	for ch in COSMETICS.COLOR_CHANNELS:
		var crow : HBoxContainer = HBoxContainer.new()
		crow.add_theme_constant_override("separation", 5)
		vb.add_child(crow)
		var cl_l : Label = Label.new()
		cl_l.text = str(ch).capitalize()
		cl_l.custom_minimum_size = Vector2(88.0, 0.0)
		cl_l.add_theme_font_size_override("font_size", 15)
		cl_l.add_theme_color_override("font_color", COL_DIM)
		crow.add_child(cl_l)
		var ch1 : String = str(ch)
		var srow2 : HBoxContainer = HBoxContainer.new()
		srow2.add_theme_constant_override("separation", 4)
		crow.add_child(srow2)
		_swatch_rows[ch] = srow2
		var picker : ColorPickerButton = ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(48.0, 28.0)
		picker.edit_alpha = false
		picker.color_changed.connect(func(c: Color) -> void: _set_channel(ch1, c))
		crow.add_child(picker)
		_channel_pickers[ch] = picker

	var reset : Button = Button.new()
	reset.text = "Reset This Unit to Stock"
	reset.custom_minimum_size = Vector2(0.0, 36.0)
	reset.pressed.connect(_on_reset_unit)
	vb.add_child(reset)

func _section(vb: VBoxContainer, text: String) -> void:
	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", COL_ACCENT)
	vb.add_child(l)

## -- interactions -----------------------------------------------------------------------

func _select_unit(key: String) -> void:
	_unit_key = key
	_rebuild_stage()
	_refresh_panel()

func _cycle_part(slot: String, dir: int) -> void:
	var fac : String = _faction()
	var parts : Array = COSMETICS.parts_for(fac, _unit_key, slot)
	var cur : String = str(COSMETICS.unit_cfg(fac, _unit_key)["parts"].get(slot, COSMETICS.STOCK))
	var idx : int = 0
	for i in parts.size():
		if str(parts[i]["id"]) == cur:
			idx = i
			break
	idx = wrapi(idx + dir, 0, parts.size())
	COSMETICS.set_part(fac, _unit_key, slot, str(parts[idx]["id"]))
	_rebuild_stage()
	_refresh_panel()

func _apply_variation(idx: int) -> void:
	COSMETICS.apply_variation(_faction(), _unit_key, idx)
	_rebuild_stage()
	_refresh_panel()

func _set_channel(channel: String, col: Color) -> void:
	COSMETICS.set_color(_faction(), _unit_key, channel, col)
	_rebuild_stage()
	_refresh_panel()

func _on_custom_toggled(on: bool) -> void:
	COSMETICS.set_use_custom_colors(_faction(), _unit_key, on)
	_rebuild_stage()
	_refresh_panel()

func _on_reset_unit() -> void:
	COSMETICS.reset_unit(_faction(), _unit_key)
	_rebuild_stage()
	_refresh_panel()

## -- refresh ----------------------------------------------------------------------------

func _refresh_panel() -> void:
	var fac : String = _faction()
	for key in _unit_btns:
		(_unit_btns[key] as Button).button_pressed = str(key) == _unit_key
	## Variation button names per faction.
	var vrow : HBoxContainer = get_meta("variation_row") as HBoxContainer
	if vrow != null:
		var vars_list : Array = COSMETICS.VARIATIONS.get(fac, [])
		for b in vrow.get_children():
			var i : int = int((b as Button).get_meta("variation_idx"))
			(b as Button).text = str(vars_list[i]["name"]) if i < vars_list.size() else "—"
	## Part slot rows.
	var cfg : Dictionary = COSMETICS.unit_cfg(fac, _unit_key)
	for slot in COSMETICS.SLOTS:
		(_slot_name_labels[slot] as Label).text = COSMETICS.slot_label(fac, str(slot))
		var pid : String = str(cfg["parts"].get(slot, COSMETICS.STOCK))
		var entry : Dictionary = COSMETICS.part_entry(fac, _unit_key, str(slot), pid)
		var count : int = COSMETICS.parts_for(fac, _unit_key, str(slot)).size()
		var val : Label = _slot_value_labels[slot] as Label
		val.text = str(entry["name"]) if count > 1 else "Stock (no parts yet)"
		val.add_theme_color_override("font_color",
			Color.WHITE if count > 1 else Color(0.45, 0.48, 0.55))
	## Colors.
	var custom : bool = COSMETICS.uses_custom_colors(fac, _unit_key)
	_custom_check.set_pressed_no_signal(custom)
	for ch in COSMETICS.COLOR_CHANNELS:
		var fallback : Color = COSMETICS.FACTION_GLOW.get(fac, Color.WHITE) if str(ch) == "glow" \
			else (COSMETICS.FACTION_SWATCHES.get(fac, [Color.WHITE])[0] as Color)
		var cur : Color = COSMETICS.channel_color(fac, _unit_key, str(ch), fallback)
		(_channel_pickers[ch] as ColorPickerButton).color = cur
		_rebuild_swatches(str(ch), fac)

func _rebuild_swatches(channel: String, fac: String) -> void:
	var row : HBoxContainer = _swatch_rows.get(channel) as HBoxContainer
	if row == null:
		return
	for c in row.get_children():
		c.queue_free()
	for col in COSMETICS.FACTION_SWATCHES.get(fac, []):
		var b : Button = Button.new()
		b.custom_minimum_size = Vector2(26.0, 26.0)
		var sb : StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = col
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		var c2 : Color = col
		b.pressed.connect(func() -> void: _set_channel(channel, c2))
		row.add_child(b)
