## InspectionPanel.gd
## Slide-up contextual panel showing stats for the clicked tower or building.
## Opened by Main.gd via HUD.open_tower_inspection() / open_building_inspection().
## Faction-agnostic first pass -- skin variants are a later pass.
## Upgrade button emits EventBus.panel_upgrade_requested; Main.gd handles the spend.
extends PanelContainer

@onready var title_label   : Label  = $VBox/TitleRow/TitleLabel
@onready var stats_label   : Label  = $VBox/StatsLabel
@onready var upgrade_btn   : Button = $VBox/UpgradeBtn
@onready var close_btn     : Button = $VBox/TitleRow/CloseBtn

func _ready() -> void:
	close_btn.pressed.connect(func() -> void: visible = false)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	visible = false

## Populates the panel with tower data and makes it visible.
## tower      : the Tower node (duck-typed; reads .data, .level, .xp, .xp_to_next)
## can_afford : whether the player can currently pay the upgrade cost
func open_tower(tower: Node, can_afford: bool) -> void:
	var d : Resource = tower.get("data")
	if d == null:
		return
	var name_str  : String = str(d.get("tower_name") if d.get("tower_name") else "Tower")
	var tier      : int    = int(d.get("tier")         if d.get("tier")         else 1)
	var dmg       : float  = float(d.get("damage")     if d.get("damage")       else 0.0)
	var rng       : float  = float(d.get("range")      if d.get("range")        else 0.0)
	var spd       : float  = float(d.get("attack_speed") if d.get("attack_speed") else 1.0)
	var lv        : int    = int(tower.get("level")    if tower.get("level")    != null else 1)
	var mul       : float  = float(tower.get("_damage_multiplier") if tower.get("_damage_multiplier") != null else 1.0)
	var xp_cur    : float  = float(tower.get("xp")         if tower.get("xp")         != null else 0.0)
	var xp_max    : float  = float(tower.get("xp_to_next") if tower.get("xp_to_next") != null else 1.0)

	title_label.text = "%s  —  Tier %d  |  Lv %d" % [name_str, tier, lv]

	stats_label.text = (
		"DMG: %.1f  (×%.2f)     RANGE: %.0fpx     SPD: %.1f/s\n" % [dmg, mul, rng, spd] +
		"XP: %.0f / %.0f" % [xp_cur, xp_max]
	)

	var next : Resource = d.get("upgrade_to")
	if next != null:
		var next_tier : int   = int(next.get("tier")         if next.get("tier")         else tier + 1)
		var next_cost : float = float(next.get("primary_cost") if next.get("primary_cost") else 0.0)
		upgrade_btn.text     = "Upgrade → Tier %d  [%d]" % [next_tier, int(next_cost)]
		upgrade_btn.visible  = true
		upgrade_btn.disabled = not can_afford
	else:
		upgrade_btn.text    = "Max Tier"
		upgrade_btn.visible = true
		upgrade_btn.disabled = true

	visible = true

## Populates the panel with building data and makes it visible.
func open_building(building: Node) -> void:
	var d : Resource = building.get("data")
	if d == null:
		return
	var name_str : String = str(d.get("building_name") if d.get("building_name") else "Building")
	var rate     : float  = float(d.get("income_rate") if d.get("income_rate")   else 0.0)
	var primary  : String = FactionManager.get_primary_resource().capitalize()

	title_label.text  = name_str
	stats_label.text  = "Income: +%.2f %s/s" % [rate, primary]
	upgrade_btn.visible = false
	visible = true

func _on_upgrade_pressed() -> void:
	EventBus.panel_upgrade_requested.emit()
	visible = false
