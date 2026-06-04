## Academy.gd — first-run opening sequence and faction front-end.
## Replaces FactionSelectScreen. Exposes the same selection_confirmed signal.
## Sequence: Chapter 0 descent → 3 sorting scenarios → recommendation UI → faction-color wash → handoff.
extends Node2D

## Mimics the FactionSelectScreen contract so Main.gd needs minimal changes.
signal selection_confirmed()

const _SCENARIO_SCRIPT = preload("res://src/academy/AcademyScenario.gd")

# -- Default sub-paths handed to FactionManager; sub-path commit is Track D-2's job.
const DEFAULT_SUB_PATHS : Dictionary = {
	"architects": "standard",
	"bloom":      "purist",
	"mesh":       "networked",
}

# -- Faction accent colors (match ability/UI palette already in build).
const FACTION_COLORS : Dictionary = {
	"architects": Color(1.00, 0.55, 0.18),
	"bloom":      Color(0.45, 0.80, 0.30),
	"mesh":       Color(0.30, 0.65, 1.00),
}

const FACTION_LINES : Dictionary = {
	"architects": "Efficiency potential assessed. Path available.",
	"bloom":      "You watched before you moved. We noticed.",
	"mesh":       "You found the weak point first. Good.",
}

const ZONE_DETECT_RADIUS : float = 60.0
const ZONE_APPROACH_DIST : float = 120.0  # label fades in within this distance
const TEXT_FADE_IN       : float = 0.8
const TEXT_HOLD          : float = 3.0
const TEXT_FADE_OUT      : float = 0.6
const PULSE_PERIOD       : float = 6.0

# -- Scene refs (set up in Academy.tscn, wired in _ready) --
@onready var _floor_node    : Node2D     = $Chamber/Floor
@onready var _zone_layer    : Node2D     = $Chamber/ZoneLayer
@onready var _cadet         : Node2D     = $Cadet
@onready var _camera        : Camera2D   = $Camera
@onready var _line_label    : Label      = $TextLayer/Line
@onready var _sorting_layer : CanvasLayer = $SortingLayer
@onready var _sigil_row     : HBoxContainer = $SortingLayer/SigilRow
@onready var _recommend_line: Label      = $SortingLayer/RecommendLine
@onready var _accept_btn    : Button     = $SortingLayer/Buttons/AcceptBtn
@onready var _choose_btn    : Button     = $SortingLayer/Buttons/ChooseBtn
@onready var _decline_btn   : Button     = $SortingLayer/Buttons/DeclineBtn
@onready var _wash_rect     : ColorRect  = $WashRect

# -- Runtime state --
var _scenarios     : Array = []  ## Array of AcademyScenario resources
var _current_idx   : int = 0
var _votes         : Dictionary = { "architects": 0.0, "bloom": 0.0, "mesh": 0.0 }
var _last_voted    : StringName = &""
var _zone_markers  : Array[Node2D] = []
var _zone_labels   : Array[Label]  = []
var _timeout_timer : float = 0.0
var _scenario_active : bool = false
var _recommended_faction : StringName = &""
var _chosen_faction      : StringName = &""
var _pulse_t    : float = 0.0
var _sigil_buttons : Array[Button] = []

func _ready() -> void:
	## Disable the Camera2D — it lives in a CanvasLayer so it cannot control
	## CanvasLayer rendering, but it CAN hijack the world camera at zoom 0.3,
	## breaking the game-world view. Scale tweening replaces its zoom effect.
	_camera.enabled = false
	_sorting_layer.hide()
	_line_label.modulate.a = 0.0
	_wash_rect.modulate.a  = 0.0
	_load_scenarios()
	_run_chapter_0()

# -- Chapter 0: camera descent + opening line --

func _run_chapter_0() -> void:
	## Zoom-in effect via node scale rather than Camera2D (camera doesn't control
	## CanvasLayer rendering). Academy is positioned at screen center in Main.tscn,
	## so its Backdrop fills the screen at scale (1,1) and zooms in from scale (0.3,0.3).
	scale = Vector2(0.30, 0.30)
	var tween : Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 3.0)
	await get_tree().create_timer(3.5).timeout
	await _show_line("Before you are assigned, you will be observed.")
	await get_tree().create_timer(0.5).timeout
	_run_next_scenario()

# -- Scenario runner --

func _load_scenarios() -> void:
	var paths : Array[String] = [
		"res://resources/academy/scenario_1.tres",
		"res://resources/academy/scenario_2.tres",
		"res://resources/academy/scenario_3.tres",
	]
	for p in paths:
		var s = load(p)
		if s != null:
			_scenarios.append(s)

func _run_next_scenario() -> void:
	if _current_idx >= _scenarios.size():
		_finish_sorting()
		return
	var sc = _scenarios[_current_idx]
	_clear_zones()
	await _show_line(sc.prompt)
	await get_tree().create_timer(0.4).timeout
	_spawn_zones(sc)
	_timeout_timer    = sc.duration
	_scenario_active  = true

func _spawn_zones(sc) -> void:
	for z in sc.zones:
		var marker : Node2D = Node2D.new()
		marker.position = z["pos"]
		_zone_layer.add_child(marker)
		_zone_markers.append(marker)

		var lbl : Label = Label.new()
		lbl.text         = z["label"]
		lbl.modulate.a   = 0.0
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-60.0, 36.0)
		marker.add_child(lbl)
		_zone_labels.append(lbl)

func _clear_zones() -> void:
	for m in _zone_markers:
		if is_instance_valid(m):
			m.queue_free()
	_zone_markers.clear()
	_zone_labels.clear()

func _process(delta: float) -> void:
	_pulse_t += delta
	_floor_node.queue_redraw()
	if not _scenario_active:
		return
	_timeout_timer -= delta
	_update_zone_labels()
	_check_zone_entry()
	if _timeout_timer <= 0.0:
		_resolve_scenario(_scenarios[_current_idx].timeout_vote)

func _update_zone_labels() -> void:
	var cadet_pos : Vector2 = _cadet.position
	for i in _zone_markers.size():
		var m   : Node2D = _zone_markers[i]
		var lbl : Label  = _zone_labels[i]
		var dist : float = cadet_pos.distance_to(m.global_position)
		lbl.modulate.a = clampf(1.0 - (dist - ZONE_DETECT_RADIUS) / (ZONE_APPROACH_DIST - ZONE_DETECT_RADIUS), 0.0, 1.0)

func _check_zone_entry() -> void:
	if not _scenario_active:
		return
	var cadet_pos : Vector2 = _cadet.position
	var sc = _scenarios[_current_idx]
	for i in _zone_markers.size():
		var m : Node2D = _zone_markers[i]
		if cadet_pos.distance_to(m.global_position) <= ZONE_DETECT_RADIUS:
			var faction : StringName = sc.zones[i]["faction"]
			_resolve_scenario(faction)
			return

func _resolve_scenario(faction: StringName) -> void:
	_scenario_active = false
	var weight : float = 1.0
	if _current_idx < _scenarios.size():
		var zones : Array = _scenarios[_current_idx].zones
		for z in zones:
			if z["faction"] == faction:
				weight = z.get("weight", 1.0)
				break
	_votes[faction] = _votes.get(faction, 0.0) + weight
	_last_voted = faction
	print("[Academy] Scenario %d → %s (votes: %s)" % [_current_idx + 1, faction, str(_votes)])
	EventBus.academy_scenario_resolved.emit(_current_idx, faction)
	_current_idx += 1
	_clear_zones()
	await get_tree().create_timer(0.6).timeout
	_run_next_scenario()

# -- Sorting + recommendation UI --

func _finish_sorting() -> void:
	_recommended_faction = _compute_recommendation()
	_show_sorting_ui()

func _compute_recommendation() -> StringName:
	var best_val  : float     = -1.0
	var best_fac  : StringName = &""
	var tie_count : int       = 0
	for fac in _votes:
		if _votes[fac] > best_val:
			best_val  = _votes[fac]
			best_fac  = fac
			tie_count = 1
		elif _votes[fac] == best_val:
			tie_count += 1
	if tie_count > 1:
		# Prefer last-voted on a tie
		if _votes.get(_last_voted, 0.0) == best_val:
			return _last_voted
		return &""   # full 3-way tie; surface no recommendation
	return best_fac

func _show_sorting_ui() -> void:
	_sorting_layer.show()
	_build_sigil_buttons()
	if _recommended_faction != &"":
		_recommend_line.text = FACTION_LINES.get(_recommended_faction, "")
	else:
		_recommend_line.text = "Your instincts are not yet decided."
	_accept_btn.pressed.connect(_on_accept_pressed)
	_choose_btn.pressed.connect(_on_choose_pressed)
	_decline_btn.pressed.connect(_on_decline_pressed)
	if _recommended_faction == &"":
		_accept_btn.disabled = true

func _build_sigil_buttons() -> void:
	var factions : Array[StringName] = [&"architects", &"bloom", &"mesh"]
	for fac in factions:
		var btn    : Button = Button.new()
		btn.text          = str(fac).capitalize()
		var col   : Color  = FACTION_COLORS.get(fac, Color.WHITE)
		var alpha : float  = _votes.get(fac, 0.0) / 3.0
		btn.modulate       = Color(col.r, col.g, col.b, lerpf(0.3, 1.0, alpha))
		btn.pressed.connect(_on_sigil_pressed.bind(fac))
		_sigil_row.add_child(btn)
		_sigil_buttons.append(btn)

func _on_accept_pressed() -> void:
	if _recommended_faction == &"":
		return
	_commit_faction(_recommended_faction)

func _on_choose_pressed() -> void:
	# Highlight all sigils to invite direct choice; hide Accept/Choose/Decline until picked.
	for btn in _sigil_buttons:
		btn.modulate.a = 1.0
	_accept_btn.hide()
	_choose_btn.hide()
	_decline_btn.hide()

func _on_sigil_pressed(faction: StringName) -> void:
	_commit_faction(faction)

func _on_decline_pressed() -> void:
	GameState.unsorted = true
	# Reveal blank sigil with the unsorted line; player still picks a faction.
	var blank_btn : Button = Button.new()
	blank_btn.text         = "?"
	blank_btn.pressed.connect(func() -> void: pass)
	_sigil_row.add_child(blank_btn)
	_recommend_line.text = "The unsorted cadets remember things they were never taught."
	_accept_btn.hide()
	_choose_btn.hide()
	_decline_btn.hide()
	for btn in _sigil_buttons:
		btn.modulate.a = 1.0

# -- Transition --

func _commit_faction(faction: StringName) -> void:
	## Stop the Cadet responding to clicks before we hand off to the game world.
	_cadet.set_process(false)
	_cadet.set_process_unhandled_input(false)
	_chosen_faction = faction
	_sorting_layer.hide()
	await _faction_wash(faction)
	GameState.academy_completed = true
	FactionManager.select_faction(str(faction), DEFAULT_SUB_PATHS[str(faction)])
	EventBus.academy_completed.emit(faction, GameState.unsorted)
	selection_confirmed.emit()

func _faction_wash(faction: StringName) -> void:
	var col : Color = FACTION_COLORS.get(faction, Color.WHITE)
	_wash_rect.color = Color(col.r, col.g, col.b, 0.0)
	var tween : Tween = create_tween()
	tween.tween_property(_wash_rect, "modulate:a", 0.6, 1.0)
	tween.tween_interval(0.8)
	await tween.finished

# -- Text helpers --

func _show_line(text: String) -> void:
	_line_label.text       = text
	_line_label.modulate.a = 0.0
	var tween : Tween = create_tween()
	tween.tween_property(_line_label, "modulate:a", 1.0, TEXT_FADE_IN)
	tween.tween_interval(TEXT_HOLD)
	tween.tween_property(_line_label, "modulate:a", 0.0, TEXT_FADE_OUT)
	await tween.finished
