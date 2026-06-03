## WavePanel.gd
## Always-visible top-right HUD cluster showing wave state and the axis diagram.
## The axis diagram displays pre-committed unit counts per spawn direction so the
## player can read incoming pressure before the first enemy steps out.
## Faction-agnostic -- visual styling is a later pass.
## Self-contained: subscribes to EventBus directly; no routing through HUD.gd.
extends PanelContainer

@onready var wave_label          : Label         = $VBox/WaveRow/WaveLabel
@onready var status_label        : Label         = $VBox/WaveRow/StatusLabel
@onready var expand_btn          : Button        = $VBox/WaveRow/ExpandBtn
@onready var enemy_label         : Label         = $VBox/EnemyLabel
@onready var composition_detail  : Label         = $VBox/CompositionDetail
@onready var axis_list           : VBoxContainer = $VBox/AxisList

const COLOR_STANDBY   : Color = Color(0.70, 0.70, 0.70)
const COLOR_INCOMING  : Color = Color(1.00, 0.55, 0.10)
const COLOR_VICTORY   : Color = Color(0.30, 1.00, 0.30)
const COLOR_DEFEAT    : Color = Color(1.00, 0.30, 0.30)
const COLOR_AXIS_BAR  : Color = Color(0.90, 0.55, 0.15)
const COLOR_COMP_TEXT : Color = Color(0.75, 0.75, 0.75)

## Largest unit count seen across all axes this wave -- used to scale bar widths.
var _max_axis_count    : int  = 1
var _detail_expanded   : bool = false

func _ready() -> void:
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.wave_axis_committed.connect(_on_wave_axis_committed)
	EventBus.wave_composition_committed.connect(_on_wave_composition_committed)
	EventBus.enemy_count_changed.connect(_on_enemy_count_changed)
	expand_btn.pressed.connect(_on_expand_pressed)
	_set_status("STANDBY", COLOR_STANDBY)
	enemy_label.visible        = false
	composition_detail.visible = false
	expand_btn.visible         = false

## -- Signal handlers --

func _on_wave_started(wave_number: int, _commander_data: Dictionary) -> void:
	wave_label.text            = "Wave %d" % wave_number
	enemy_label.visible        = true
	_set_status("INCOMING", COLOR_INCOMING)
	## Reset expand state each wave so detail starts collapsed.
	_detail_expanded           = false
	composition_detail.visible = false
	expand_btn.text            = "▶"

func _on_wave_ended(_wave_number: int, result: String) -> void:
	enemy_label.visible        = false
	composition_detail.visible = false
	expand_btn.visible         = false
	_detail_expanded           = false
	if result == "victory":
		_set_status("VICTORY", COLOR_VICTORY)
	else:
		_set_status("DEFEAT", COLOR_DEFEAT)

func _on_wave_composition_committed(unit_name: String, count: int) -> void:
	composition_detail.text = "%s  ×%d" % [unit_name, count]
	expand_btn.text         = "▶"
	expand_btn.visible      = true

func _on_expand_pressed() -> void:
	_detail_expanded           = not _detail_expanded
	composition_detail.visible = _detail_expanded
	expand_btn.text            = "▼" if _detail_expanded else "▶"

func _on_wave_axis_committed(axis_weights: Dictionary) -> void:
	_rebuild_axis_rows(axis_weights)

func _on_enemy_count_changed(remaining: int) -> void:
	enemy_label.text = "%d remaining" % remaining

## -- Axis diagram --

func _rebuild_axis_rows(axis_weights: Dictionary) -> void:
	for child in axis_list.get_children():
		child.queue_free()
	if axis_weights.is_empty():
		return
	_max_axis_count = 1
	for spawn_id in axis_weights:
		var n : int = axis_weights[spawn_id]
		if n > _max_axis_count:
			_max_axis_count = n
	for spawn_id in axis_weights:
		_add_axis_row(spawn_id, axis_weights[spawn_id])

func _add_axis_row(spawn_id: StringName, unit_count: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dir_label := Label.new()
	dir_label.text = _spawn_label(spawn_id)
	dir_label.custom_minimum_size = Vector2(52.0, 0.0)
	dir_label.add_theme_font_size_override("font_size", 12)
	dir_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(_max_axis_count)
	bar.value     = float(unit_count)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(80.0, 14.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Tint the bar fill amber to suggest threat.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_AXIS_BAR
	bar.add_theme_stylebox_override("fill", style)

	var count_label := Label.new()
	count_label.text = str(unit_count)
	count_label.custom_minimum_size = Vector2(22.0, 0.0)
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hbox.add_child(dir_label)
	hbox.add_child(bar)
	hbox.add_child(count_label)
	axis_list.add_child(hbox)

## -- Helpers --

func _set_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)

## Maps spawn_id to a readable direction label.
## Handles both named cardinal IDs and procedurally-generated IDs gracefully.
func _spawn_label(spawn_id: StringName) -> String:
	match spawn_id:
		&"spawn_w": return "WEST"
		&"spawn_n": return "NORTH"
		&"spawn_s": return "SOUTH"
		&"spawn_e": return "EAST"
		_:
			## Procedural IDs: strip "spawn_" prefix and capitalize remainder.
			var s : String = str(spawn_id)
			if s.begins_with("spawn_"):
				return s.substr(6).to_upper()
			return s.to_upper()
