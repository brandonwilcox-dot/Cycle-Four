## HUD.gd
## Owns the four-cluster layout per core/22_interface-design.md:
##   ResourceCluster (top-left)  -- faction, resources, FOB HP, territory, obj toggle
##   WavePanel       (top-right) -- wave state + axis diagram (self-contained script)
##   ActionBar       (bottom)    -- Begin Waves, Place Tower, Place Building
##   NotificationStack (bottom-right) -- auto-fading toast queue
## ObjectivePanel and InspectionPanel are contextual (tactical state).
## WavePanel and ObjectivePanel subscribe to EventBus directly.
##
## Progressive-disclosure depth states (§22 §2):
##   GLANCE   -- core HUD only; no contextual panels open
##   TACTICAL -- one contextual panel open (inspection or objective)
##   ACTIVE   -- research tree / galaxy map / pacification (future)
extends Control

enum HudDepth { GLANCE, TACTICAL, ACTIVE }

var _depth : HudDepth = HudDepth.GLANCE

## ── Resource cluster ────────────────────────────────────────────────────────
@onready var faction_label      : Label         = $ResourceCluster/VBox/FactionRow/FactionLabel
@onready var sub_path_label     : Label         = $ResourceCluster/VBox/FactionRow/SubPathLabel
@onready var primary_label      : Label         = $ResourceCluster/VBox/PrimaryRes/Amount
@onready var primary_rate       : Label         = $ResourceCluster/VBox/PrimaryRes/Rate
@onready var secondary_label    : Label         = $ResourceCluster/VBox/SecondaryRes/Amount
@onready var secondary_rate     : Label         = $ResourceCluster/VBox/SecondaryRes/Rate
@onready var base_hp_label      : Label         = $ResourceCluster/VBox/BaseHP/BaseAmount
@onready var territory_info     : HBoxContainer = $ResourceCluster/VBox/TerritoryInfo
@onready var territory_count    : Label         = $ResourceCluster/VBox/TerritoryInfo/TerritoryCount
@onready var obj_summary_btn    : Button        = $ResourceCluster/VBox/ObjSummaryBtn
@onready var milestone_row      : HBoxContainer = $ResourceCluster/VBox/MilestoneRow
@onready var milestone_icon     : Label         = $ResourceCluster/VBox/MilestoneRow/MilestoneIcon
@onready var milestone_progress : Label         = $ResourceCluster/VBox/MilestoneRow/MilestoneProgress

## ── Panels ──────────────────────────────────────────────────────────────────
@onready var objective_panel    : Control       = $ObjectivePanel
@onready var subpath_panel     : Control       = $SubpathCommitPanel
@onready var wave_panel         : Control       = $WavePanel
@onready var inspection_panel   : Control       = $InspectionPanel

## ── Action bar ──────────────────────────────────────────────────────────────
@onready var start_wave_btn     : Button        = $ActionBar/StartWaveBtn
@onready var place_tower_btn    : Button        = $ActionBar/PlaceTowerBtn
@onready var place_building_btn : Button        = $ActionBar/PlaceBuildingBtn
@onready var research_btn       : Button        = $ActionBar/ResearchBtn

## ── Notifications ───────────────────────────────────────────────────────────
@onready var notification_stack : VBoxContainer = $NotificationStack

const FORMAT_RATE : String = "+%.2f/s"
const MAX_TOASTS  : int    = 5

var _starter_tower         : Resource = null
var _starter_building      : Resource = null
var _territory_cells       : int      = 0
var _subpath_panel_shown   : bool     = false  ## fires once per run after wave 9

func _ready() -> void:
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.tower_placement_requested.connect(_on_placement_started)
	EventBus.building_placement_requested.connect(_on_build_placement_started)
	EventBus.notification_pushed.connect(_on_notification_pushed)
	EventBus.territory_claimed.connect(_on_territory_claimed)
	EventBus.territory_raided.connect(_on_territory_raided)
	EventBus.spawn_activated.connect(_on_spawn_activated)
	EventBus.base_damaged.connect(_on_base_damaged)
	EventBus.base_destroyed.connect(_on_base_destroyed)
	EventBus.objective_progressed.connect(_on_obj_progressed)
	EventBus.objective_completed.connect(_on_obj_completed)
	EventBus.objective_lapsed.connect(_on_obj_lapsed)
	EventBus.map_completed.connect(_on_map_completed_hud)
	EventBus.milestone_progress_changed.connect(_on_milestone_progress)
	EventBus.milestone_reached.connect(_on_milestone_reached_hud)
	EventBus.subpath_committed.connect(_on_subpath_committed_hud)
	obj_summary_btn.pressed.connect(_toggle_objective_panel)
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	place_tower_btn.pressed.connect(_on_place_tower_pressed)
	place_building_btn.pressed.connect(_on_place_building_pressed)
	research_btn.pressed.connect(_on_research_pressed)
	EventBus.research_stage_purchased.connect(_on_research_stage_purchased)
	EventBus.offline_catch_up.connect(_on_offline_catch_up)
	place_tower_btn.disabled    = true   ## Enabled once faction is chosen
	place_building_btn.disabled = true
	start_wave_btn.disabled     = false

# -- Resource cluster handlers ------------------------------------------------

func _on_faction_selected(faction_id: String, sub_path: String) -> void:
	faction_label.text  = faction_id.capitalize()
	sub_path_label.text = sub_path.replace("_", " ").capitalize()
	_starter_tower = FactionManager.get_starter_tower()
	if _starter_tower != null:
		place_tower_btn.text     = "Place Tower [%d]" % int(_starter_tower.primary_cost)
		place_tower_btn.disabled = false
	else:
		place_tower_btn.text     = "Place Tower"
		place_tower_btn.disabled = true
	_starter_building = FactionManager.get_starter_building()
	if _starter_building != null:
		place_building_btn.text     = "Place Building [%d]" % int(_starter_building.get("primary_cost"))
		place_building_btn.disabled = false
	else:
		place_building_btn.text     = "Place Building"
		place_building_btn.disabled = true
	## Sync resource display immediately (handles post-game-over reloads where
	## resource_changed won't re-fire for values already set in EconomyManager).
	var p : String = FactionManager.get_primary_resource()
	var s : String = FactionManager.get_secondary_resource()
	primary_label.text   = _format_amount(EconomyManager.resources.get(p, 0.0))
	primary_rate.text    = FORMAT_RATE % EconomyManager.get_rate(p)
	secondary_label.text = _format_amount(EconomyManager.resources.get(s, 0.0))
	secondary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(s)
	base_hp_label.text   = "%d HP" % int(300)
	base_hp_label.add_theme_color_override("font_color", Color(0.20, 0.90, 0.20))
	_territory_cells       = 0
	_subpath_panel_shown   = false
	territory_info.visible = false
	milestone_row.visible  = true
	## Research button: only visible and relevant for Architects.
	research_btn.visible   = (faction_id == "architects")
	research_btn.disabled  = false
	_update_research_btn_label(0)
	milestone_progress.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30))
	var objectives := ObjectiveManager.get_active_objectives()
	objective_panel.populate(objectives)
	_refresh_obj_summary(objectives)
	obj_summary_btn.visible = true
	wave_panel.visible      = true

func _on_resource_changed(_faction_id: String, resource_id: String, amount: float) -> void:
	var primary   : String = FactionManager.get_primary_resource()
	var secondary : String = FactionManager.get_secondary_resource()
	if resource_id == primary:
		primary_label.text = _format_amount(amount)
		primary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(primary)
	elif resource_id == secondary:
		secondary_label.text = _format_amount(amount)
		secondary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(secondary)
	## Update affordability tint on action buttons.
	if _starter_tower != null and not place_tower_btn.disabled:
		var can_afford : bool = EconomyManager.can_afford(
			{primary: _starter_tower.primary_cost}
		)
		place_tower_btn.modulate = Color.WHITE if can_afford else Color(1.0, 0.5, 0.5)
	if _starter_building != null and not place_building_btn.disabled:
		var b_cost    : float = float(_starter_building.get("primary_cost"))
		var can_build : bool  = EconomyManager.can_afford({primary: b_cost})
		place_building_btn.modulate = Color.WHITE if can_build else Color(1.0, 0.5, 0.5)

# -- Wave handlers (action bar only; WavePanel owns status display) -----------

func _on_wave_started(wave_number: int, commander_data: Dictionary) -> void:
	start_wave_btn.disabled = true
	## Combat begins: collapse all contextual panels so the player can focus.
	enter_glance_state()
	## Surface commander name at waves 11+ (core/12).
	var cmd_name : String = commander_data.get("name", "")
	if not cmd_name.is_empty():
		_push_notification("Wave %d — %s" % [wave_number, cmd_name], Color(0.80, 0.70, 1.00))

func _on_wave_ended(wave_number: int, _result: String) -> void:
	start_wave_btn.disabled = false
	## Core/16 Chapter 5: sub-path commit fires once after wave 9.
	## Panel is the only modal pause in the first session.
	if wave_number == 9 and not _subpath_panel_shown and not FactionManager.active_faction.is_empty():
		_subpath_panel_shown     = true
		start_wave_btn.disabled  = true   ## block start until committed
		subpath_panel.populate(FactionManager.active_faction, FactionManager.active_sub_path)
		subpath_panel.visible = true

# -- Territory handlers -------------------------------------------------------

func _on_territory_claimed(_cell: Vector2i) -> void:
	_territory_cells += 1
	territory_count.text   = "%d cells" % _territory_cells
	territory_info.visible = true

func _on_territory_raided(_cell: Vector2i) -> void:
	_territory_cells = max(0, _territory_cells - 1)
	territory_count.text   = "%d cells" % _territory_cells
	territory_info.visible = _territory_cells > 0
	var primary : String = FactionManager.get_primary_resource()
	_push_notification(
		"Territory raided!  -%d %s" % [int(15), primary],
		Color(0.95, 0.25, 0.20)
	)

func _on_spawn_activated(spawn_id: StringName) -> void:
	var dir : String = _spawn_direction(spawn_id)
	_push_notification("New spawn active: %s front" % dir, Color(1.0, 0.60, 0.18))

func _on_base_damaged(amount: float, _attacker_data: Dictionary) -> void:
	var base_nodes := get_tree().get_nodes_in_group("base")
	if not base_nodes.is_empty():
		var b     := base_nodes[0]
		var hp    : float = b.get("_current_hp") if b.get("_current_hp") != null else 0.0
		var maxhp : float = b.get("MAX_HP")      if b.get("MAX_HP")      != null else 300.0
		_update_base_hp_label(hp, maxhp)
	_push_notification("Base breached!  -%d HP" % int(amount), Color(0.95, 0.15, 0.15))

func _on_base_destroyed() -> void:
	base_hp_label.text = "0 HP"
	base_hp_label.add_theme_color_override("font_color", Color(0.90, 0.20, 0.10))
	start_wave_btn.disabled     = true
	place_tower_btn.disabled    = true
	place_building_btn.disabled = true

func _update_base_hp_label(hp: float, max_hp: float) -> void:
	base_hp_label.text = "%d HP" % int(hp)
	var ratio : float = hp / max_hp if max_hp > 0.0 else 0.0
	if ratio > 0.5:
		base_hp_label.add_theme_color_override("font_color", Color(0.20, 0.90, 0.20))
	elif ratio > 0.25:
		base_hp_label.add_theme_color_override("font_color", Color(0.90, 0.70, 0.10))
	else:
		base_hp_label.add_theme_color_override("font_color", Color(0.90, 0.20, 0.10))

# -- Action bar handlers ------------------------------------------------------

func _on_placement_started(_tower_data: Resource) -> void:
	place_tower_btn.text     = "Placing... [RMB/ESC]"
	place_tower_btn.disabled = true

func _on_start_wave_pressed() -> void:
	WaveManager.begin_waves()

func _on_place_tower_pressed() -> void:
	if _starter_tower == null:
		return
	if not EconomyManager.can_afford(
		{FactionManager.get_primary_resource(): _starter_tower.primary_cost}
	):
		return
	EventBus.tower_placement_requested.emit(_starter_tower)

## Called by Main when tower placement mode ends (placed or cancelled).
func end_placement_mode() -> void:
	if _starter_tower != null:
		place_tower_btn.text     = "Place Tower [%d]" % int(_starter_tower.primary_cost)
		place_tower_btn.disabled = false
	else:
		place_tower_btn.disabled = true

func _on_place_building_pressed() -> void:
	if _starter_building == null:
		return
	var b_cost : float = float(_starter_building.get("primary_cost"))
	if not EconomyManager.can_afford({FactionManager.get_primary_resource(): b_cost}):
		return
	EventBus.building_placement_requested.emit(_starter_building)

func _on_build_placement_started(_building_data: Resource) -> void:
	place_building_btn.text     = "Building... [RMB/ESC]"
	place_building_btn.disabled = true

## -- Inspection panel API (called by Main) -----------------------------------

## Opens the tower inspection panel and enters tactical state.
func open_tower_inspection(tower: Node, can_afford: bool) -> void:
	inspection_panel.open_tower(tower, can_afford)
	_set_depth(HudDepth.TACTICAL)

## Opens the building inspection panel and enters tactical state.
func open_building_inspection(building: Node) -> void:
	inspection_panel.open_building(building)
	_set_depth(HudDepth.TACTICAL)

## Closes the inspection panel. Returns to glance if no other panel is open.
func close_inspection() -> void:
	inspection_panel.visible = false
	if not objective_panel.visible:
		_set_depth(HudDepth.GLANCE)

## Collapses all contextual panels and returns to glance state.
## Called by ESC (Main) and wave_started.
func enter_glance_state() -> void:
	_set_depth(HudDepth.GLANCE)

## Called by Main when build mode ends (placed or cancelled).
func end_build_mode() -> void:
	if _starter_building != null:
		place_building_btn.text     = "Place Building [%d]" % int(_starter_building.get("primary_cost"))
		place_building_btn.disabled = false
	else:
		place_building_btn.disabled = true

# -- Milestone handlers -------------------------------------------------------

func _on_research_pressed() -> void:
	MilestoneManager.try_purchase_research()

func _on_research_stage_purchased(stage: int, _cost: float) -> void:
	_update_research_btn_label(stage)
	if stage >= MilestoneManager.RESEARCH_STAGES:
		research_btn.disabled = true
		research_btn.text     = "Research Complete"

func _update_research_btn_label(stage: int) -> void:
	if stage >= MilestoneManager.RESEARCH_STAGES:
		research_btn.text = "Research Complete"
		return
	var cost : float = MilestoneManager.RESEARCH_COSTS[stage]
	research_btn.text = "Research [%d sch]" % int(cost)

func _on_subpath_committed_hud(_sub_path: String) -> void:
	## Sub-path confirmed — close panel and re-enable wave start.
	subpath_panel.visible    = false
	start_wave_btn.disabled  = false
	sub_path_label.text      = _sub_path.replace("_", " ").capitalize()
	EventBus.notification_pushed.emit("Sub-path committed: %s" % _sub_path.replace("_", " ").capitalize(), "positive")

func _on_milestone_progress(_current: int, _target: int, label: String) -> void:
	## label already formatted as "Defenses: 3/8" etc.
	var parts := label.split(": ", true, 1)
	if parts.size() == 2:
		milestone_icon.text    = parts[0]
		milestone_progress.text = parts[1]
	else:
		milestone_progress.text = label

func _on_milestone_reached_hud(_faction_id: String, _index: int) -> void:
	milestone_icon.text    = "Milestone"
	milestone_progress.text = "REACHED"
	milestone_progress.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))

# -- Objective handlers -------------------------------------------------------

func _on_obj_progressed(_id: StringName, _old: int, _new_val: int) -> void:
	_refresh_obj_summary(ObjectiveManager.get_active_objectives())

func _on_obj_completed(_id: StringName) -> void:
	_refresh_obj_summary(ObjectiveManager.get_active_objectives())

func _on_obj_lapsed(_id: StringName) -> void:
	_refresh_obj_summary(ObjectiveManager.get_active_objectives())

func _on_map_completed_hud() -> void:
	obj_summary_btn.text = "Map Complete!"

func _toggle_objective_panel() -> void:
	objective_panel.visible = not objective_panel.visible
	if objective_panel.visible:
		_set_depth(HudDepth.TACTICAL)
	elif not inspection_panel.visible:
		_set_depth(HudDepth.GLANCE)

func _refresh_obj_summary(objectives: Array[ObjectiveData]) -> void:
	var total : int = objectives.size()
	var done  : int = 0
	for obj in objectives:
		if obj != null and obj.complete:
			done += 1
	obj_summary_btn.text = "Objectives: %d/%d" % [done, total]

# -- Notification toast system ------------------------------------------------

func _on_notification_pushed(message: String, priority: String) -> void:
	var color : Color
	match priority:
		"positive": color = Color(0.35, 1.0,  0.45)
		"warning":  color = Color(1.0,  0.60, 0.18)
		"alert":    color = Color(0.95, 0.20, 0.20)
		_:          color = Color(0.82, 0.82, 0.82)
	_push_notification(message, color)

## Pushes a right-aligned, auto-fading label into the notification stack.
func _push_notification(text: String, color: Color) -> void:
	while notification_stack.get_child_count() >= MAX_TOASTS:
		notification_stack.get_child(0).queue_free()
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	notification_stack.add_child(label)
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)

# -- Depth state --------------------------------------------------------------

## Transitions to a new HUD depth. On GLANCE, closes all contextual panels.
## Emits hud_state_changed so other systems can react (camera focus, etc.).
func _set_depth(d: HudDepth) -> void:
	if _depth == d:
		return
	_depth = d
	if d == HudDepth.GLANCE:
		inspection_panel.visible = false
		objective_panel.visible  = false
	EventBus.hud_state_changed.emit(_depth_label(d))

func _depth_label(d: HudDepth) -> String:
	match d:
		HudDepth.GLANCE:   return "glance"
		HudDepth.TACTICAL: return "tactical"
		HudDepth.ACTIVE:   return "active"
	return "unknown"

# -- Offline catch-up --------------------------------------------------------

func _on_offline_catch_up(seconds_elapsed: float) -> void:
	var hours   : int   = int(seconds_elapsed / 3600.0)
	var minutes : int   = int(fmod(seconds_elapsed, 3600.0) / 60.0)
	var msg     : String
	if hours > 0:
		msg = "Welcome back! %dh %dm of idle income collected." % [hours, minutes]
	else:
		msg = "Welcome back! %dm of idle income collected." % minutes
	_push_notification(msg, Color(0.35, 1.0, 0.45))

# -- Helpers ------------------------------------------------------------------

func _format_amount(amount: float) -> String:
	if amount >= 1_000_000.0:
		return "%.2fM" % (amount / 1_000_000.0)
	elif amount >= 1_000.0:
		return "%.1fK" % (amount / 1_000.0)
	else:
		return "%.1f" % amount

func _spawn_direction(spawn_id: StringName) -> String:
	match spawn_id:
		&"spawn_w": return "West"
		&"spawn_n": return "North"
		&"spawn_s": return "South"
		&"spawn_e": return "East"
		_:          return "Unknown"
