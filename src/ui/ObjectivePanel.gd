## ObjectivePanel.gd
## Slide-in panel listing all active map objectives with live progress bars.
## Faction-agnostic — no skin applied here; faction theming is a later pass.
## Toggled by ObjSummaryBtn in the TopBar. Updates via EventBus; never polls.
extends PanelContainer

@onready var panel_title   : Label          = $VBox/Header/PanelTitle
@onready var close_btn     : Button         = $VBox/Header/CloseBtn
@onready var objective_list: VBoxContainer  = $VBox/ObjectiveList

## Maps objective_id (StringName) → {obj, bar, status} for targeted row updates.
## Values are untyped because GDScript typed dicts don't support heterogeneous value types.
var _rows: Dictionary = {}

func _ready() -> void:
	EventBus.objective_progressed.connect(_on_objective_progressed)
	EventBus.objective_completed.connect(_on_objective_completed)
	EventBus.objective_lapsed.connect(_on_objective_lapsed)
	EventBus.map_completed.connect(_on_map_completed)
	EventBus.objective_sensed.connect(_on_objective_sensed)
	close_btn.pressed.connect(func() -> void: visible = false)

## Rebuilds the row list. Call after faction selection or map load.
func populate(objectives: Array[ObjectiveData]) -> void:
	_rows.clear()
	for child in objective_list.get_children():
		child.queue_free()
	panel_title.text = "OBJECTIVES"
	panel_title.remove_theme_color_override("font_color")
	for obj in objectives:
		if obj == null:
			continue
		_rows[obj.objective_id] = _add_row(obj)

## -- Signal handlers --

func _on_objective_progressed(id: StringName, _old: int, _new_val: int) -> void:
	if not _rows.has(id):
		return
	_refresh_row(_rows[id])

func _on_objective_completed(id: StringName) -> void:
	if not _rows.has(id):
		return
	_refresh_row(_rows[id])

func _on_objective_lapsed(id: StringName) -> void:
	if not _rows.has(id):
		return
	_refresh_row(_rows[id])

func _on_objective_sensed(id: StringName) -> void:
	if not _rows.has(id):
		return
	var row : Dictionary = _rows[id]
	var desc : Label          = row.desc
	var hbox : HBoxContainer  = row.hbox
	if not desc.text.begins_with("? "):
		desc.text = "? " + desc.text
	hbox.modulate = Color(1.0, 1.0, 1.0, 0.50)

func _on_map_completed() -> void:
	panel_title.text = "OBJECTIVES — MAP COMPLETE"
	panel_title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))

## -- Row construction --

func _add_row(obj: ObjectiveData) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var desc := Label.new()
	desc.text = obj.description if not obj.description.is_empty() else str(obj.objective_id)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maxf(float(obj.target), 1.0)
	bar.value = float(obj.progress)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(72.0, 16.0)

	var status := Label.new()
	status.text = "✓" if obj.complete else ""
	status.custom_minimum_size = Vector2(18.0, 0.0)
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))

	hbox.add_child(desc)
	hbox.add_child(bar)
	hbox.add_child(status)
	objective_list.add_child(hbox)

	return {obj = obj, bar = bar, status = status, desc = desc, hbox = hbox}

## Reads the live ObjectiveData resource (already mutated by ObjectiveManager) and repaints.
## Also restores full opacity and cleans the "?" prefix once the objective has real progress.
func _refresh_row(row: Dictionary) -> void:
	var obj    : ObjectiveData   = row.obj
	var bar    : ProgressBar     = row.bar
	var status : Label           = row.status
	var desc   : Label           = row.desc
	var hbox   : HBoxContainer   = row.hbox
	bar.value   = float(obj.progress)
	status.text = "✓" if obj.complete else ""
	if obj.progress > 0 and hbox.modulate.a < 1.0:
		hbox.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if desc.text.begins_with("? "):
			desc.text = desc.text.substr(2)
