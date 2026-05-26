## HUD.gd
## Displays live resource counts, production rates, wave number, and faction.
## Connects to EventBus -- never polls; always event-driven.
## Three depth states per core/22_interface-design.md:
##   glance   -- resource totals only (default)
##   tactical -- + rates and wave info
##   active   -- + all panels (not implemented yet)
extends Control

## Node references (must match HUD.tscn hierarchy)
@onready var faction_label: Label      = $TopBar/FactionLabel
@onready var sub_path_label: Label     = $TopBar/SubPathLabel
@onready var primary_label: Label      = $TopBar/PrimaryRes/Amount
@onready var primary_rate: Label       = $TopBar/PrimaryRes/Rate
@onready var secondary_label: Label    = $TopBar/SecondaryRes/Amount
@onready var secondary_rate: Label     = $TopBar/SecondaryRes/Rate
@onready var wave_label: Label         = $BottomBar/WaveLabel
@onready var wave_status: Label        = $BottomBar/WaveStatus
@onready var start_wave_btn: Button    = $BottomBar/StartWaveBtn
@onready var place_tower_btn: Button   = $BottomBar/PlaceTowerBtn

const FORMAT_RESOURCE: String = "%s"
const FORMAT_RATE: String     = "+%.2f/s"

var _starter_tower: Resource = null   ## TowerData for current faction

func _ready() -> void:
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.tower_placement_requested.connect(_on_placement_started)
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	place_tower_btn.pressed.connect(_on_place_tower_pressed)
	place_tower_btn.disabled = true   ## Enabled once faction is chosen
	_refresh_wave_ui()

# -- Event handlers --

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

func _on_resource_changed(faction_id: String, resource_id: String, amount: float) -> void:
	var primary: String   = FactionManager.get_primary_resource()
	var secondary: String = FactionManager.get_secondary_resource()

	if resource_id == primary:
		primary_label.text = _format_amount(amount)
		primary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(primary)
	elif resource_id == secondary:
		secondary_label.text = _format_amount(amount)
		secondary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(secondary)

	## Update affordability indicator on the tower button
	if _starter_tower != null and not place_tower_btn.disabled:
		var can_afford: bool = EconomyManager.can_afford(
			{FactionManager.get_primary_resource(): _starter_tower.primary_cost}
		)
		place_tower_btn.modulate = Color.WHITE if can_afford else Color(1.0, 0.5, 0.5)

func _on_wave_started(wave_number: int, _commander_data: Dictionary) -> void:
	wave_label.text  = "Wave %d" % wave_number
	wave_status.text = "INCOMING"
	wave_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1))
	start_wave_btn.disabled = true

func _on_wave_ended(_wave_number: int, result: String) -> void:
	wave_status.text = result.to_upper()
	wave_status.add_theme_color_override(
		"font_color",
		Color(0.3, 1.0, 0.3) if result == "victory" else Color(1.0, 0.3, 0.3)
	)
	start_wave_btn.disabled = false

func _on_placement_started(_tower_data: Resource) -> void:
	## Show that we're in placement mode; let Main handle the actual clicks
	place_tower_btn.text     = "Placing... [RMB/ESC]"
	place_tower_btn.disabled = true

func _on_start_wave_pressed() -> void:
	## Do NOT touch the button or status here.
	## begin_waves() may still be in COUNTDOWN from a rapid re-press;
	## wave_started fires ~1 s later and disables the button correctly.
	## Driving state from the press handler caused a soft-lock when the
	## request was silently dropped (RESULTS state) but the button was
	## already disabled with nothing left to re-enable it.
	WaveManager.begin_waves()

func _on_place_tower_pressed() -> void:
	if _starter_tower == null:
		return
	if not EconomyManager.can_afford(
		{FactionManager.get_primary_resource(): _starter_tower.primary_cost}
	):
		return
	EventBus.tower_placement_requested.emit(_starter_tower)

# -- Internal --

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

## Called by Main when placement mode ends (placed or cancelled)
func end_placement_mode() -> void:
	if _starter_tower != null:
		place_tower_btn.text     = "Place Tower [%d]" % int(_starter_tower.primary_cost)
		place_tower_btn.disabled = false
	else:
		place_tower_btn.disabled = true
