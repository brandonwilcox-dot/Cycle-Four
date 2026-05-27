## HUD.gd
## Displays live resource counts, production rates, wave info, territory count,
## enemy counter, and fade-out notification toasts for key game events.
## Connects to EventBus -- never polls; always event-driven.
## Three depth states per core/22_interface-design.md:
##   glance   -- resource totals only (default)
##   tactical -- + rates and wave info
##   active   -- + all panels (not implemented yet)
extends Control

## Node references (must match HUD.tscn hierarchy)
@onready var faction_label      : Label          = $TopBar/FactionLabel
@onready var sub_path_label     : Label          = $TopBar/SubPathLabel
@onready var primary_label      : Label          = $TopBar/PrimaryRes/Amount
@onready var primary_rate       : Label          = $TopBar/PrimaryRes/Rate
@onready var secondary_label    : Label          = $TopBar/SecondaryRes/Amount
@onready var secondary_rate     : Label          = $TopBar/SecondaryRes/Rate
@onready var territory_info     : HBoxContainer  = $TopBar/TerritoryInfo
@onready var territory_count    : Label          = $TopBar/TerritoryInfo/TerritoryCount
@onready var wave_label         : Label          = $BottomBar/WaveLabel
@onready var wave_status        : Label          = $BottomBar/WaveStatus
@onready var enemy_count_label  : Label          = $BottomBar/EnemyCount
@onready var start_wave_btn     : Button         = $BottomBar/StartWaveBtn
@onready var place_tower_btn    : Button         = $BottomBar/PlaceTowerBtn
@onready var place_building_btn : Button         = $BottomBar/PlaceBuildingBtn
@onready var base_hp_label      : Label          = $TopBar/BaseHP/BaseAmount
@onready var notification_stack : VBoxContainer  = $NotificationStack

const FORMAT_RESOURCE : String = "%s"
const FORMAT_RATE     : String = "+%.2f/s"

## Maximum simultaneous toasts before the oldest is removed.
const MAX_TOASTS : int = 5

var _starter_tower    : Resource = null   ## TowerData for current faction
var _starter_building : Resource = null   ## BuildingData for current faction
var _territory_cells  : int      = 0      ## locally tracked; updated by signals

func _ready() -> void:
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.enemy_count_changed.connect(_on_enemy_count_changed)
	EventBus.tower_placement_requested.connect(_on_placement_started)
	EventBus.building_placement_requested.connect(_on_build_placement_started)
	EventBus.notification_pushed.connect(_on_notification_pushed)
	EventBus.territory_claimed.connect(_on_territory_claimed)
	EventBus.territory_raided.connect(_on_territory_raided)
	EventBus.spawn_activated.connect(_on_spawn_activated)
	EventBus.base_damaged.connect(_on_base_damaged)
	EventBus.base_destroyed.connect(_on_base_destroyed)
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	place_tower_btn.pressed.connect(_on_place_tower_pressed)
	place_building_btn.pressed.connect(_on_place_building_pressed)
	place_tower_btn.disabled    = true   ## Enabled once faction is chosen
	place_building_btn.disabled = true
	_refresh_wave_ui()

# -- Resource event handlers --

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
	## Reset FOB HP display
	base_hp_label.text = "%d HP" % int(300)
	base_hp_label.add_theme_color_override("font_color", Color(0.20, 0.90, 0.20))
	## Reset territory display on faction change
	_territory_cells       = 0
	territory_info.visible = false

func _on_resource_changed(_faction_id: String, resource_id: String, amount: float) -> void:
	var primary   : String = FactionManager.get_primary_resource()
	var secondary : String = FactionManager.get_secondary_resource()
	if resource_id == primary:
		primary_label.text = _format_amount(amount)
		primary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(primary)
	elif resource_id == secondary:
		secondary_label.text = _format_amount(amount)
		secondary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(secondary)
	## Update affordability tint on action buttons
	if _starter_tower != null and not place_tower_btn.disabled:
		var can_afford : bool = EconomyManager.can_afford(
			{primary: _starter_tower.primary_cost}
		)
		place_tower_btn.modulate = Color.WHITE if can_afford else Color(1.0, 0.5, 0.5)
	if _starter_building != null and not place_building_btn.disabled:
		var b_cost : float = float(_starter_building.get("primary_cost"))
		var can_build : bool = EconomyManager.can_afford({primary: b_cost})
		place_building_btn.modulate = Color.WHITE if can_build else Color(1.0, 0.5, 0.5)

# -- Wave event handlers --

func _on_wave_started(wave_number: int, _commander_data: Dictionary) -> void:
	wave_label.text  = "Wave %d" % wave_number
	wave_status.text = "INCOMING"
	wave_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1))
	start_wave_btn.disabled    = true
	enemy_count_label.visible  = true

func _on_wave_ended(_wave_number: int, result: String) -> void:
	wave_status.text = result.to_upper()
	wave_status.add_theme_color_override(
		"font_color",
		Color(0.3, 1.0, 0.3) if result == "victory" else Color(1.0, 0.3, 0.3)
	)
	start_wave_btn.disabled   = false
	enemy_count_label.visible = false

func _on_enemy_count_changed(remaining: int) -> void:
	enemy_count_label.text = "%d %s" % [remaining, "enemy" if remaining == 1 else "enemies"]

# -- Territory event handlers --

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

func _on_spawn_activated(spawn_cell: Vector2i) -> void:
	## Map spawn cell coords to a cardinal direction label for the toast.
	var dir : String = _spawn_direction(spawn_cell)
	_push_notification(
		"New spawn active: %s front" % dir,
		Color(1.0, 0.60, 0.18)
	)

func _on_base_damaged(amount: float, _attacker_data: Dictionary) -> void:
	## Update FOB HP label. Base.gd tracks exact HP; we derive display from the signal.
	## Read current HP from Base node if available, otherwise subtract locally.
	var base_nodes := get_tree().get_nodes_in_group("base")
	if not base_nodes.is_empty():
		var b := base_nodes[0]
		var hp    : float = b.get("_current_hp") if b.get("_current_hp") != null else 0.0
		var maxhp : float = b.get("MAX_HP")      if b.get("MAX_HP")      != null else 300.0
		_update_base_hp_label(hp, maxhp)
	_push_notification(
		"Base breached!  -%d HP" % int(amount),
		Color(0.95, 0.15, 0.15)
	)

func _on_base_destroyed() -> void:
	base_hp_label.text = "0 HP"
	base_hp_label.add_theme_color_override("font_color", Color(0.90, 0.20, 0.10))
	## Disable action buttons -- game is over.
	start_wave_btn.disabled    = true
	place_tower_btn.disabled   = true
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

# -- Tower placement --

func _on_placement_started(_tower_data: Resource) -> void:
	place_tower_btn.text     = "Placing... [RMB/ESC]"
	place_tower_btn.disabled = true

func _on_start_wave_pressed() -> void:
	## Do NOT touch button/status here -- wave_started/wave_ended own that state.
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

## Called by Main when build mode ends (placed or cancelled).
func end_build_mode() -> void:
	if _starter_building != null:
		place_building_btn.text     = "Place Building [%d]" % int(_starter_building.get("primary_cost"))
		place_building_btn.disabled = false
	else:
		place_building_btn.disabled = true

func _on_notification_pushed(message: String, priority: String) -> void:
	var color : Color
	match priority:
		"positive": color = Color(0.35, 1.0,  0.45)
		"warning":  color = Color(1.0,  0.60, 0.18)
		"alert":    color = Color(0.95, 0.20, 0.20)
		_:          color = Color(0.82, 0.82, 0.82)   ## "info" and unknown
	_push_notification(message, color)

# -- Notification toast system --

## Pushes a right-aligned, auto-fading label into the notification stack.
## text  : the message to display
## color : font colour conveying urgency (red = threat, orange = warning, green = positive)
func _push_notification(text: String, color: Color) -> void:
	## Evict the oldest toast when the stack is full.
	while notification_stack.get_child_count() >= MAX_TOASTS:
		notification_stack.get_child(0).queue_free()

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	notification_stack.add_child(label)

	## Linger for 1.4 s then fade over 1.2 s.
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)

# -- Internal helpers --

func _refresh_wave_ui() -> void:
	wave_label.text  = "Wave 0"
	wave_status.text = "STANDBY"
	start_wave_btn.disabled = false

func _format_amount(amount: float) -> String:
	if amount >= 1_000_000.0:
		return "%.2fM" % (amount / 1_000_000.0)
	elif amount >= 1_000.0:
		return "%.1fK" % (amount / 1_000.0)
	else:
		return "%.1f" % amount

func _spawn_direction(spawn_cell: Vector2i) -> String:
	match spawn_cell:
		Vector2i(0,  8):  return "West"
		Vector2i(15, 0):  return "North"
		Vector2i(15, 16): return "South"
		Vector2i(29, 8):  return "East"
		_:                return "Unknown"
