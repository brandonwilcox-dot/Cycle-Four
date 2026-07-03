## Academy.gd — first-run opening sequence and faction sorting.
## Chapter 0: Pilgrimage chamber descent with cadet (unchanged).
## Chapter 1: Three live-map scenarios; AcademyBehaviorTracker watches silently.
## Chapter 2: Sorting reveal back in the chamber based on tracked behaviour.
extends Node2D

## Mimics the FactionSelectScreen contract so Main.gd needs no changes.
signal selection_confirmed()

const _TRACKER_SCRIPT = preload("res://src/academy/AcademyBehaviorTracker.gd")
const _CHAMBER_LIGHT  = preload("res://src/academy/ChamberLight.gd")
const _VEIL_SHADER    = preload("res://assets/shaders/chamber_veil.gdshader")

## Default sub-paths assigned when a faction is pre-seeded for Academy economy.
const DEFAULT_SUB_PATHS : Dictionary = {
	"architects": "standard",
	"bloom":      "purist",
	"mesh":       "networked",
}

## Visual accent colours per faction (match ability/UI palette).
const FACTION_COLORS : Dictionary = {
	"architects": Color(1.00, 0.55, 0.18),
	"bloom":      Color(0.45, 0.80, 0.30),
	"mesh":       Color(0.30, 0.65, 1.00),
}

## Lines shown in the sorting reveal per faction (in faction voice).
const FACTION_LINES : Dictionary = {
	"architects": "Efficiency potential assessed. Path available.",
	"bloom":      "You watched before you moved. We noticed.",
	"mesh":       "You found the weak point first. Good.",
}

## -- Scenario data (Chapter 1) --------------------------------------------------

## Text prompt displayed at the start of each scenario.
const SCENARIO_PROMPTS : Array[String] = [
	"Two contacts approach from opposite angles. The core is exposed.",
	"Surplus. The situation is in flux. Where do you put it?",
	"Something old at the edge. It does not move.",
]

## Seconds each scenario runs before auto-advancing.
const SCENARIO_DURATIONS : Array[float] = [75.0, 90.0, 90.0]

## How many enemy units to spawn per scenario.
## Scenario 0: two flanks; Scenario 1: one larger wave; Scenario 2: slow probe.
const SCENARIO_SPAWN_COUNTS : Array[int] = [4, 6, 3]

## Spawn-point index (into MapData.spawn_points) used per scenario.
## Scenario 0 uses indices 0 AND 1 simultaneously (two-flank setup).
const SCENARIO_SPAWN_IDX    : Array[int] = [0, 0, 2]

## Delay between individual unit spawns within one scenario (seconds).
const SPAWN_STAGGER : float = 0.7

## -- Text constants -------------------------------------------------------------
const TEXT_FADE_IN  : float = 0.7
const TEXT_HOLD     : float = 4.0   ## Chapter 0 opening line hold
const TEXT_FADE_OUT : float = 0.6

## -- Scene refs -----------------------------------------------------------------
@onready var _chamber        : Node2D      = $Chamber
@onready var _cadet          : Node2D      = $Cadet
@onready var _camera         : Camera2D   = $Camera
@onready var _line_label     : Label      = $TextLayer/Line
@onready var _scenario_label : Label      = $TextLayer/ScenarioLabel
@onready var _timer_label    : Label      = $TextLayer/TimerLabel
@onready var _sorting_layer  : CanvasLayer = $SortingLayer
@onready var _sigil_row      : HBoxContainer = $SortingLayer/SigilRow
@onready var _recommend_line : Label      = $SortingLayer/RecommendLine
@onready var _accept_btn     : Button     = $SortingLayer/Buttons/AcceptBtn
@onready var _choose_btn     : Button     = $SortingLayer/Buttons/ChooseBtn
@onready var _decline_btn    : Button     = $SortingLayer/Buttons/DeclineBtn
@onready var _wash_rect      : ColorRect  = $WashRect

## -- Runtime state --------------------------------------------------------------
var _tracker              : RefCounted        ## AcademyBehaviorTracker (duck-typed)
var _recommended_faction  : StringName = &""
var _chosen_faction       : StringName = &""
var _sigil_buttons        : Array[Button] = []

var _scenario_timer   : float = 0.0
var _scenario_running : bool  = false

# -------------------------------------------------------------------------------

func _ready() -> void:
	## Only run the Academy on a genuine first-run/new game. When continuing a
	## saved game (academy already completed) Main restores the world directly and
	## the Academy must stay fully inert — otherwise its scenario enemies spawn in
	## the background (phantom FOB damage) and the cadet competes for input.
	if GameState.academy_completed:
		hide()
		## CanvasLayer children render independently of the parent's visibility, so
		## hide them explicitly or the sorting buttons / text bleed over the live game.
		_sorting_layer.hide()
		var text_layer : CanvasLayer = get_node_or_null("TextLayer") as CanvasLayer
		if text_layer != null:
			text_layer.visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_camera.enabled = false
	_sorting_layer.hide()
	_line_label.modulate.a    = 0.0
	_scenario_label.modulate.a = 0.0
	_scenario_label.visible   = false
	_timer_label.modulate.a   = 0.0
	_timer_label.visible      = false
	_wash_rect.modulate.a     = 0.0
	_build_chamber_fx()   ## V5.0: aperture light drift + vignette/grain veil (additive-only)
	_tracker = _TRACKER_SCRIPT.new()
	_tracker.start_tracking()
	_run_chapter_0()

## V5.0 chamber effects — children of Chamber so they hide with it during the scenarios.
## Strictly decorative: the veil ignores the mouse; nothing here touches the input path.
func _build_chamber_fx() -> void:
	var light : Node2D = _CHAMBER_LIGHT.new()
	light.name = "ApertureLight"
	_chamber.add_child(light)
	var veil : ColorRect = ColorRect.new()
	veil.name = "Veil"
	var vm : ShaderMaterial = ShaderMaterial.new()
	vm.shader = _VEIL_SHADER
	veil.material = vm
	veil.position = Vector2(-960.0, -540.0)
	veil.size = Vector2(1920.0, 1080.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chamber.add_child(veil)

func _process(delta: float) -> void:
	if not _scenario_running:
		return
	_scenario_timer = maxf(0.0, _scenario_timer - delta)
	_timer_label.text = "%d" % int(ceil(_scenario_timer))
	if _scenario_timer <= 0.0:
		_scenario_running = false

# -- Chapter 0: chamber descent (unchanged) -------------------------------------

func _run_chapter_0() -> void:
	## Zoom-in via node scale rather than Camera2D (camera cannot drive CanvasLayer).
	scale = Vector2(0.30, 0.30)
	var tween : Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 3.0)
	await get_tree().create_timer(3.5).timeout
	await _show_line("Before you are assigned, you will be observed.")
	await get_tree().create_timer(0.5).timeout
	_run_all_scenarios()

# -- Chapter 1: live-map scenarios ----------------------------------------------

func _run_all_scenarios() -> void:
	## Pre-seed economy with Architects resources so the player has energy to
	## place towers. Faction is not committed yet — sorting decides that.
	FactionManager.select_faction("architects", "standard")
	EventBus.academy_phase_started.emit()

	## Fade chamber out so WorldMap is visible.
	await _fade_to_black()
	_chamber.hide()
	_cadet.hide()                              ## prevent ghost icon over WorldMap
	_cadet.set_process(false)
	_cadet.set_process_unhandled_input(false)
	_wash_rect.modulate.a = 0.0

	for i in 3:
		await _run_map_scenario(i)

	## Return to chamber for sorting reveal.
	await _fade_to_black()
	_chamber.show()
	_cadet.show()
	_cadet.set_process(true)
	_wash_rect.modulate.a = 0.0

	EventBus.academy_phase_ended.emit()
	_finish_sorting()

func _run_map_scenario(idx: int) -> void:
	## Show the scenario context line, then spawn enemies and let the timer run.
	await _show_scenario_text(SCENARIO_PROMPTS[idx])

	## Scenario 1: drop extra resources so the player has surplus to decide with.
	if idx == 1:
		EconomyManager.add_resource("energy", 100.0)

	## Spawn enemies — scenario 0 uses two flanks; others use one wave.
	var count : int = SCENARIO_SPAWN_COUNTS[idx]
	if idx == 0:
		await _spawn_wave(0, count / 2)
		await _spawn_wave(1, count - count / 2)
	else:
		await _spawn_wave(SCENARIO_SPAWN_IDX[idx], count)

	## Show timer and run.
	_timer_label.visible = true
	_timer_label.modulate.a = 1.0
	_scenario_timer  = SCENARIO_DURATIONS[idx]
	_scenario_running = true
	while _scenario_running:
		await get_tree().process_frame

	_timer_label.visible = false
	EventBus.academy_clear_units.emit()
	await get_tree().create_timer(1.2).timeout

## Emits academy_spawn_requested for each unit with staggered timing.
func _spawn_wave(spawn_idx: int, count: int) -> void:
	for _i in count:
		EventBus.academy_spawn_requested.emit(spawn_idx, 1)
		await get_tree().create_timer(SPAWN_STAGGER).timeout

## Fades _wash_rect to opaque black, leaving it set so caller can then
## show/hide scene nodes, then set modulate.a = 0.0 to reveal.
func _fade_to_black() -> void:
	_wash_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_wash_rect.modulate.a = 0.0
	var t : Tween = create_tween()
	t.tween_property(_wash_rect, "modulate:a", 1.0, 0.5)
	await t.finished

# -- Sorting + recommendation UI (unchanged logic, adapted to use tracker) ------

func _finish_sorting() -> void:
	_recommended_faction = _tracker.compute_recommendation()
	_show_sorting_ui()

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
	var scores : Dictionary = _tracker.get_scores()
	var factions : Array[StringName] = [&"architects", &"bloom", &"mesh"]
	for fac in factions:
		var btn   : Button = Button.new()
		btn.text          = str(fac).capitalize()
		var col   : Color  = FACTION_COLORS.get(fac, Color.WHITE)
		var alpha : float  = scores.get(str(fac), 0.0)
		btn.modulate       = Color(col.r, col.g, col.b, lerpf(0.3, 1.0, alpha))
		btn.pressed.connect(_on_sigil_pressed.bind(fac))
		_sigil_row.add_child(btn)
		_sigil_buttons.append(btn)

func _on_accept_pressed() -> void:
	if _recommended_faction == &"":
		return
	_commit_faction(_recommended_faction)

func _on_choose_pressed() -> void:
	for btn in _sigil_buttons:
		btn.modulate.a = 1.0
	_accept_btn.hide()
	_choose_btn.hide()
	_decline_btn.hide()

func _on_sigil_pressed(faction: StringName) -> void:
	_commit_faction(faction)

func _on_decline_pressed() -> void:
	GameState.unsorted = true
	var blank_btn : Button = Button.new()
	blank_btn.text = "?"
	blank_btn.pressed.connect(func() -> void: pass)
	_sigil_row.add_child(blank_btn)
	_recommend_line.text = "The unsorted cadets remember things they were never taught."
	_accept_btn.hide()
	_choose_btn.hide()
	_decline_btn.hide()
	for btn in _sigil_buttons:
		btn.modulate.a = 1.0

# -- Transition -----------------------------------------------------------------

func _commit_faction(faction: StringName) -> void:
	_sorting_layer.hide()
	_chosen_faction = faction
	await _faction_wash(faction)
	GameState.academy_completed = true
	## Re-select the actual chosen faction (may differ from the Academy pre-seed).
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

# -- Text helpers ---------------------------------------------------------------

func _show_line(text: String) -> void:
	_line_label.text       = text
	_line_label.modulate.a = 0.0
	var tween : Tween = create_tween()
	tween.tween_property(_line_label, "modulate:a", 1.0, TEXT_FADE_IN)
	tween.tween_interval(TEXT_HOLD)
	tween.tween_property(_line_label, "modulate:a", 0.0, TEXT_FADE_OUT)
	await tween.finished

func _show_scenario_text(text: String) -> void:
	_scenario_label.text       = text
	_scenario_label.modulate.a = 0.0
	_scenario_label.visible    = true
	var tween : Tween = create_tween()
	tween.tween_property(_scenario_label, "modulate:a", 1.0, 0.6)
	tween.tween_interval(5.0)   ## Long enough to read while also moving the Commander
	tween.tween_property(_scenario_label, "modulate:a", 0.0, 0.6)
	await tween.finished
	_scenario_label.visible = false
