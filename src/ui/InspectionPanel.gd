## InspectionPanel.gd
## Slide-up contextual panel showing stats for the clicked tower or building.
## Opened by Main.gd via HUD.open_tower_inspection() / open_building_inspection().
## Faction-agnostic first pass -- skin variants are a later pass.
## Upgrade button emits EventBus.panel_upgrade_requested; Main.gd handles the spend.
extends PanelContainer

const Combat = preload("res://src/combat/Combat.gd")

@onready var title_label   : Label  = $VBox/TitleRow/TitleLabel
@onready var stats_label   : Label  = $VBox/StatsLabel
@onready var upgrade_btn   : Button = $VBox/UpgradeBtn
@onready var close_btn     : Button = $VBox/TitleRow/CloseBtn

## The tower currently inspected (null for buildings) — used by the targeting toggle.
var _tower         : Node   = null
var _target_btn    : Button = null   ## cycles tower targeting priority; hidden for buildings
var _sell_btn      : Button = null   ## sells tower or building
var _upgrade_b_btn : Button = null   ## second branch (B) upgrade; hidden when no B branch

func _ready() -> void:
	close_btn.pressed.connect(func() -> void: visible = false)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	## Build the branch-B upgrade, Target, and Sell buttons in code (.tscn parser is brittle).
	## Order under VBox: Title, Stats, UpgradeBtn(A), UpgradeB, Target, Sell.
	var vbox : VBoxContainer = $VBox
	_upgrade_b_btn = Button.new()
	_upgrade_b_btn.pressed.connect(_on_upgrade_b_pressed)
	vbox.add_child(_upgrade_b_btn)
	_target_btn = Button.new()
	_target_btn.pressed.connect(_on_target_pressed)
	vbox.add_child(_target_btn)
	_sell_btn = Button.new()
	_sell_btn.text = "Sell"
	_sell_btn.pressed.connect(_on_sell_pressed)
	vbox.add_child(_sell_btn)
	visible = false

## Populates the panel with tower data and makes it visible.
## tower      : the Tower node (duck-typed; reads .data, .level, .xp, .xp_to_next)
## _can_afford : legacy param; affordability is now computed per-branch internally
func open_tower(tower: Node, _can_afford: bool) -> void:
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

	var dtype : String = Combat.damage_type_name(int(d.get("damage_type")) if d.get("damage_type") != null else 0)
	stats_label.text = (
		"DMG: %.1f %s  (×%.2f)     RANGE: %.0fpx     SPD: %.1f/s\n" % [dmg, dtype, mul, rng, spd] +
		"XP: %.0f / %.0f" % [xp_cur, xp_max]
	)
	## Pass 3 empowerment readout: aura received, territory bonus, aura-provider status.
	stats_label.text += _empowerment_suffix(tower)

	## Pass 3 branching: configure up to two upgrade buttons (A = upgrade_to, B = upgrade_to_b).
	## Affordability is computed per branch here (ignores the legacy can_afford param).
	_configure_upgrade_button(upgrade_btn,    d.get("upgrade_to"))
	_configure_upgrade_button(_upgrade_b_btn, d.get("upgrade_to_b"))
	if d.get("upgrade_to") == null and d.get("upgrade_to_b") == null:
		upgrade_btn.text     = "Max Tier"
		upgrade_btn.visible  = true
		upgrade_btn.disabled = true

	_tower = tower
	_target_btn.visible = tower.has_method("target_mode_name")
	if _target_btn.visible:
		_target_btn.text = "Target: %s" % tower.call("target_mode_name")
	_sell_btn.visible = true
	visible = true
	move_to_front()   ## draw above the minimap and other late-added HUD children

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
	_upgrade_b_btn.visible = false
	_tower = null
	_target_btn.visible = false   ## targeting is tower-only
	_sell_btn.visible = true
	visible = true

## Configures an upgrade button for a branch target (null hides it). Shows the
## target tower's name + fresh-build cost, and disables it when unaffordable.
func _configure_upgrade_button(btn: Button, target: Resource) -> void:
	if btn == null:
		return
	if target == null:
		btn.visible = false
		return
	var t_cost : float  = float(target.get("primary_cost") if target.get("primary_cost") != null else 0.0)
	var t_name : String = str(target.get("tower_name") if target.get("tower_name") else "Upgrade")
	btn.text     = "→ %s  [%d]" % [t_name, int(t_cost)]
	btn.visible  = true
	btn.disabled = not EconomyManager.can_afford({FactionManager.get_primary_resource(): t_cost})

## Builds the " +X% aura / +Y% territory / radiates aura" suffix for the stats line.
func _empowerment_suffix(tower: Node) -> String:
	var aura_mult : float = float(tower.get("_aura_recv_mult")) if tower.get("_aura_recv_mult") != null else 1.0
	var terr_mult : float = float(tower.get("_territory_mult")) if tower.get("_territory_mult") != null else 1.0
	var parts : Array[String] = []
	if aura_mult > 1.001:
		parts.append("+%d%% aura" % int(round((aura_mult - 1.0) * 100.0)))
	if terr_mult > 1.001:
		parts.append("+%d%% territory" % int(round((terr_mult - 1.0) * 100.0)))
	if tower.has_method("provides_aura") and bool(tower.call("provides_aura")):
		parts.append("◈ radiates aura")
	return ("\n" + "   ".join(parts)) if not parts.is_empty() else ""

func _on_upgrade_pressed() -> void:
	EventBus.panel_upgrade_requested.emit(0)
	visible = false

func _on_upgrade_b_pressed() -> void:
	EventBus.panel_upgrade_requested.emit(1)
	visible = false

## Cycles the inspected tower's targeting priority and refreshes the button label.
func _on_target_pressed() -> void:
	if _tower != null and is_instance_valid(_tower) and _tower.has_method("cycle_target_mode"):
		_tower.call("cycle_target_mode")
		_target_btn.text = "Target: %s" % _tower.call("target_mode_name")

func _on_sell_pressed() -> void:
	EventBus.panel_sell_requested.emit()
	visible = false
