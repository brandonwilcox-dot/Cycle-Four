## SubpathCommitPanel.gd
## Modal overlay shown once between waves 9 and 10 (core/16 Chapter 5 — Identity beat).
## Player confirms or changes their sub-path. On COMMIT, calls FactionManager.commit_sub_path()
## which emits EventBus.subpath_committed and unlocks the Suppression Field ability.
##
## This is the only deliberate pause in the first session per core/16 hard constraints.
## Built procedurally so the HUD.tscn stays clean — just add an empty Control node here.
extends Control

## Faction-voiced prompts per core/16 §5.
const PROMPTS : Dictionary = {
	"architects": "The standard optimization path is available. An alternative configuration has been flagged. Committing to one closes the other.",
	"bloom":      "The colony has reached the branching point. Two growth strategies are available. The network cannot hold both.",
	"mesh":       "Fork in the protocol detected. Standard network path. Or — the other one. Decision required before next wave.",
}

## Sub-path descriptions in faction voice.
const DESCRIPTIONS : Dictionary = {
	"standard":      "Standard — Established efficiency protocols. Multiplicative build order.",
	"spiritual_tech": "Spiritual-Tech — The inefficiency has purpose. Recursive insight.",
	"purist":        "Purist — The lineage holds. Evolution without contamination.",
	"assimilator":   "Assimilator — Absorb what you encounter. Adapt the absorbed.",
	"networked":     "Networked — Standard protocol topology. Reliable signal reach.",
	"dreamer":       "Dreamer — Off-protocol. The signal goes where the map doesn't.",
}

var _selected_sub_path : String = ""
var _commit_btn        : Button = null
var _path_btns         : Array  = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func populate(faction_id: String, current_sub_path: String) -> void:
	_selected_sub_path = current_sub_path
	## Rebuild UI with faction-specific content.
	for child in get_children():
		child.queue_free()
	_path_btns.clear()
	_build_ui()
	## Apply faction prompt text and sub-path buttons.
	var prompt_label : Label = get_node_or_null("Dimmer/../Card/VBox/PromptLabel")
	if prompt_label:
		prompt_label.text = PROMPTS.get(faction_id, "Choose your path.")
	## Refresh button states.
	var paths : Array = FactionManager.SUB_PATHS.get(faction_id, [])
	for i in minf(paths.size(), _path_btns.size()):
		var btn : Button    = _path_btns[i]
		var pid : String    = paths[i]
		btn.text            = DESCRIPTIONS.get(pid, pid)
		btn.button_pressed  = (pid == _selected_sub_path)
		var captured_pid    : String = pid
		if not btn.pressed.is_connected(func() -> void: _on_path_pressed(captured_pid)):
			btn.pressed.connect(func() -> void: _on_path_pressed(captured_pid))
	if _commit_btn:
		_commit_btn.disabled = _selected_sub_path.is_empty()

## -- Internal --

func _build_ui() -> void:
	## Full-screen dim.
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color        = Color(0.0, 0.0, 0.0, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	## Centered card.
	var card := PanelContainer.new()
	card.name             = "Card"
	card.custom_minimum_size = Vector2(480.0, 0.0)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left  = -240.0
	card.offset_right = 240.0
	card.offset_top   = -160.0
	card.offset_bottom = 160.0
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	## Title.
	var title := Label.new()
	title.text = "— COMMIT TO A PATH —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.90, 0.82, 0.45))
	vbox.add_child(title)

	## Faction-voiced prompt.
	var prompt := Label.new()
	prompt.name        = "PromptLabel"
	prompt.text        = PROMPTS.get(FactionManager.active_faction, "Choose your path.")
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	vbox.add_child(prompt)

	## Separator.
	vbox.add_child(HSeparator.new())

	## Sub-path buttons (one per option, toggle style).
	var paths : Array = FactionManager.SUB_PATHS.get(FactionManager.active_faction, [])
	var btn_grp := ButtonGroup.new()
	_path_btns.clear()
	for pid in paths:
		var btn := Button.new()
		btn.text           = DESCRIPTIONS.get(pid, pid)
		btn.toggle_mode    = true
		btn.button_group   = btn_grp
		btn.button_pressed = (pid == _selected_sub_path)
		btn.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 12)
		var captured_pid   : String = pid
		btn.pressed.connect(func() -> void: _on_path_pressed(captured_pid))
		vbox.add_child(btn)
		_path_btns.append(btn)

	## Separator.
	vbox.add_child(HSeparator.new())

	## Commit button.
	_commit_btn          = Button.new()
	_commit_btn.text     = "COMMIT"
	_commit_btn.disabled = _selected_sub_path.is_empty()
	_commit_btn.add_theme_font_size_override("font_size", 14)
	_commit_btn.pressed.connect(_on_commit_pressed)
	vbox.add_child(_commit_btn)

func _on_path_pressed(path_id: String) -> void:
	_selected_sub_path = path_id
	if _commit_btn:
		_commit_btn.disabled = false

func _on_commit_pressed() -> void:
	if _selected_sub_path.is_empty():
		return
	FactionManager.commit_sub_path(_selected_sub_path)
	visible = false
