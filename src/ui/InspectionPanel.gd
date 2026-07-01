## InspectionPanel.gd
## Slide-up contextual panel showing stats for the clicked tower or building.
## Opened by Main.gd via HUD.open_tower_inspection() / open_building_inspection().
## Faction-agnostic first pass -- skin variants are a later pass.
## Upgrade button emits EventBus.panel_upgrade_requested; Main.gd handles the spend.
extends PanelContainer

const Combat = preload("res://src/combat/Combat.gd")

## FOB doctrine options (RPS upgrade). [faction_id, button label].
const DOCTRINE_DEFS : Array = [
	["architects", "Architect — Kinetic + fire rate"],
	["bloom",      "Bloom — Corrosive + regen"],
	["mesh",       "Mesh — Energy + detection"],
]

@onready var title_label   : Label  = $VBox/TitleRow/TitleLabel
@onready var stats_label   : Label  = $VBox/StatsLabel
@onready var upgrade_btn   : Button = $VBox/UpgradeBtn
@onready var close_btn     : Button = $VBox/TitleRow/CloseBtn

## The tower currently inspected (null for buildings) — used by the targeting toggle.
var _tower         : Node   = null
var _target_btn    : Button = null   ## cycles tower targeting priority; hidden for buildings
var _sell_btn      : Button = null   ## sells tower or building
var _upgrade_b_btn : Button = null   ## second branch (B) upgrade; hidden when no B branch
var _doctrine_btns : Array[Button] = []   ## FOB doctrine buttons (shown only for the FOB)

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
	## FOB doctrine buttons (RPS upgrade) — hidden unless the FOB is inspected.
	for d in DOCTRINE_DEFS:
		var db := Button.new()
		db.visible = false
		db.pressed.connect(_on_doctrine_pressed.bind(str(d[0])))
		vbox.add_child(db)
		_doctrine_btns.append(db)
	visible = false

func _on_doctrine_pressed(doctrine_id: String) -> void:
	EventBus.fob_doctrine_requested.emit(doctrine_id)

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
		"DMG %.1f %s  (×%.2f)\n" % [dmg, dtype, mul] +
		"RANGE %.0f   ·   SPD %.1f/s\n" % [rng, spd] +
		"XP %.0f / %.0f" % [xp_cur, xp_max]
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
	for b in _doctrine_btns:
		b.visible = false
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
	for b in _doctrine_btns:
		b.visible = false
	visible = true

## Populates the panel with FOB stats. The FOB can't be upgraded, retargeted, or sold.
func open_fob(base: Node) -> void:
	var hp   : float = float(base.get("_current_hp")) if base.get("_current_hp") != null else 0.0
	var rank : int   = int(base.get("_fortification_rank")) if base.get("_fortification_rank") != null else 0
	var det  : float = float(base.call("get_detector_radius")) if base.has_method("get_detector_radius") else 0.0
	var cur : String = str(base.call("get_doctrine")) if base.has_method("get_doctrine") else ""
	title_label.text = "Forward Operating Base"
	var doc_line : String = ("Doctrine: %s" % cur.capitalize()) if cur != "" else "Doctrine: none — pick one"
	stats_label.text = (
		"HP %d   ·   Fort rank %d\n" % [int(hp), rank] +
		"Detects stealth within %.0f px\n" % det +
		doc_line
	)
	upgrade_btn.visible    = false
	_upgrade_b_btn.visible = false
	_target_btn.visible    = false
	_sell_btn.visible      = false   ## the FOB can't be sold
	## Show the three doctrine options; mark the active one.
	for i in _doctrine_btns.size():
		var did : String = str(DOCTRINE_DEFS[i][0])
		var b   : Button = _doctrine_btns[i]
		b.visible  = true
		b.text     = ("✓ " + str(DOCTRINE_DEFS[i][1])) if did == cur else str(DOCTRINE_DEFS[i][1])
		b.disabled = (did == cur)
	_tower = null
	visible = true
	move_to_front()

## Populates the panel with unit stats (enemy or friendly). Units can't be upgraded/sold/retargeted.
const _ARMOR_NAMES : Array = ["Plated", "Organic", "Synthetic"]
func open_unit(unit: Node) -> void:
	var d : Resource = unit.get("data")
	if d == null:
		return
	var name_str : String = str(d.get("unit_name") if d.get("unit_name") else "Unit")
	var tier   : int   = int(d.get("tier") if d.get("tier") != null else 1)
	var maxhp  : float = float(d.get("max_health") if d.get("max_health") != null else 0.0)
	var curhp  : float = float(unit.get("_current_health")) if unit.get("_current_health") != null else maxhp
	var dmg    : float = float(d.get("attack_damage") if d.get("attack_damage") != null else 0.0)
	var rng    : float = float(d.get("attack_range") if d.get("attack_range") != null else 0.0)
	var spd    : float = float(d.get("move_speed") if d.get("move_speed") != null else 0.0)
	var armor  : float = float(d.get("armor") if d.get("armor") != null else 0.0)
	var atype  : int   = int(d.get("armor_type") if d.get("armor_type") != null else 0)
	var atype_str : String = _ARMOR_NAMES[atype] if atype >= 0 and atype < _ARMOR_NAMES.size() else ""
	var fac : String = str(d.get("faction_id") if d.get("faction_id") else "")
	title_label.text = "%s  —  Tier %d%s" % [name_str, tier, ("  (%s)" % fac.capitalize()) if fac != "" else ""]
	var combat_line : String = ("DMG %.1f   ·   RANGE %.0f\n" % [dmg, rng]) if dmg > 0.0 else "Non-combatant\n"
	stats_label.text = (
		"HP %d / %d\n" % [int(curhp), int(maxhp)] +
		combat_line +
		"SPD %.0f   ·   ARMOR %.0f %s" % [spd, armor, atype_str]
	)
	upgrade_btn.visible    = false
	_upgrade_b_btn.visible = false
	_target_btn.visible    = false
	_sell_btn.visible      = false
	for b in _doctrine_btns:
		b.visible = false
	_tower = null
	visible = true
	move_to_front()

## Populates the panel with the player Commander's stats (rank/HP/damage/speed/sight/territory).
func open_commander(cmd: Node) -> void:
	var hp     : float = float(cmd.get("_current_health")) if cmd.get("_current_health") != null else 0.0
	var maxhp  : float = float(cmd.get("_max_health")) if cmd.get("_max_health") != null else 0.0
	var rank   : int   = int(cmd.get("_commander_rank")) if cmd.get("_commander_rank") != null else 0
	var claimed: int   = int(cmd.get("_claimed_count")) if cmd.get("_claimed_count") != null else 0
	var spd    : float = float(cmd.get("_current_move_speed")) if cmd.get("_current_move_speed") != null else 0.0
	var dmul   : float = float(cmd.get("_damage_multiplier")) if cmd.get("_damage_multiplier") != null else 1.0
	var los    : int   = int(cmd.call("_los_radius")) if cmd.has_method("_los_radius") else 0
	var sensor : int   = int(cmd.call("_sensor_radius")) if cmd.has_method("_sensor_radius") else 0
	title_label.text = "Commander  —  Rank %d" % rank
	stats_label.text = (
		"HP %d / %d\n" % [int(hp), int(maxhp)] +
		"DMG ×%.2f   ·   SPD %.0f\n" % [dmul, spd] +
		"Sight %d   ·   Sensor %d  (cells)\n" % [los, sensor] +
		"Territory claimed: %d cells" % claimed
	)
	upgrade_btn.visible    = false
	_upgrade_b_btn.visible = false
	_target_btn.visible    = false
	_sell_btn.visible      = false
	for b in _doctrine_btns:
		b.visible = false
	_tower = null
	visible = true
	move_to_front()

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
	if tower.has_method("provides_detection") and bool(tower.call("provides_detection")):
		parts.append("◎ detects stealth")
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
