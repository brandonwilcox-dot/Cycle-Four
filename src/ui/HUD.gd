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

const FORMAT_RESOURCE: String = "%s"
const FORMAT_RATE: String     = "+%.2f/s"

func _ready() -> void:
	EventBus.faction_selected.connect(_on_faction_selected)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_ended.connect(_on_wave_ended)
	start_wave_btn.pressed.connect(_on_start_wave_pressed)
	_refresh_wave_ui()

# -- Event handlers --

func _on_faction_selected(faction_id: String, sub_path: String) -> void:
	faction_label.text = faction_id.capitalize()
	sub_path_label.text = sub_path.replace("_", " ").capitalize()

func _on_resource_changed(faction_id: String, resource_id: String, amount: float) -> void:
	var primary: String   = FactionManager.get_primary_resource()
	var secondary: String = FactionManager.get_secondary_resource()

	if resource_id == primary:
		primary_label.text = _format_amount(amount)
		primary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(primary)
	elif resource_id == secondary:
		secondary_label.text = _format_amount(amount)
		secondary_rate.text  = FORMAT_RATE % EconomyManager.get_rate(secondary)

func _on_wave_started(wave_number: int, _commander_data: Dictionary) -> void:
	wave_label.text  = "Wave %d" % wave_number
	wave_status.text = "ACTIVE"
	wave_status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	start_wave_btn.disabled = true

func _on_wave_ended(_wave_number: int, result: String) -> void:
	wave_status.text = result.to_upper()
	wave_status.add_theme_color_override(
		"font_color",
		Color(0.3, 1.0, 0.3) if result == "victory" else Color(1.0, 0.3, 0.3)
	)
	start_wave_btn.disabled = false

func _on_start_wave_pressed() -> void:
	WaveManager.begin_waves()
	start_wave_btn.disabled = true
	wave_status.text = "INCOMING..."
	wave_status.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))

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
