## AbilityBar.gd
## Bottom-center HUD cluster showing the three Commander ability slots.
## Each slot shows a cooldown sweep, keybind glyph, and lock overlay.
## Subscribes to EventBus ability signals; never polls.
extends Control

const SLOT_SIZE   : float = 52.0
const SLOT_GAP    : float = 8.0
const KEY_LABELS  : Array = ["Q", "W", "E"]
const SLOT_COLORS : Array = [
	Color(1.00, 0.92, 0.30, 1.0),   ## Lance — gold
	Color(0.40, 0.80, 1.00, 1.0),   ## Suppression Field — cyan
	Color(1.00, 0.55, 0.18, 1.0),   ## Overdrive — orange
]

## Each entry: {panel, bg, cooldown_bar, key_label, lock_overlay}
var _slots : Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots()
	EventBus.ability_used.connect(_on_ability_used)
	EventBus.ability_cooldown_changed.connect(_on_cooldown_changed)
	EventBus.ability_charge_changed.connect(_on_charge_changed)
	EventBus.ability_ready.connect(_on_ability_ready)
	EventBus.ability_unlocked.connect(_on_ability_unlocked)

func _build_slots() -> void:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", int(SLOT_GAP))
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)
	for i in 3:
		var slot := _make_slot(i)
		hbox.add_child(slot.panel)
		_slots.append(slot)

func _make_slot(index: int) -> Dictionary:
	var col : Color = SLOT_COLORS[index]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter        = Control.MOUSE_FILTER_STOP
	panel.modulate            = Color(1.0, 1.0, 1.0, 0.50)   ## dimmed until unlocked

	var stack := Control.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)

	## Tinted background.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color        = Color(col, 0.18)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(bg)

	## Cooldown sweep — fills from top as remaining/total.
	var cd_bar := ProgressBar.new()
	cd_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd_bar.min_value       = 0.0
	cd_bar.max_value       = 1.0
	cd_bar.value           = 0.0
	cd_bar.show_percentage = false
	cd_bar.visible         = false
	cd_bar.modulate        = Color(col, 0.55)
	cd_bar.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	stack.add_child(cd_bar)

	## Key glyph in bottom-left corner.
	var key_label := Label.new()
	key_label.text        = KEY_LABELS[index]
	key_label.position    = Vector2(4.0, SLOT_SIZE - 18.0)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.add_theme_color_override("font_color", Color(col, 0.85))
	stack.add_child(key_label)

	## Dark overlay shown while the slot is locked.
	var lock := ColorRect.new()
	lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock.color        = Color(0.0, 0.0, 0.0, 0.70)
	lock.visible      = true
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(lock)

	return {panel = panel, cooldown_bar = cd_bar, key_label = key_label, lock_overlay = lock}

## -- Signal handlers --

func _on_ability_used(slot_id: int) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var panel : PanelContainer = _slots[slot_id].panel
	var orig  : Color          = panel.modulate
	panel.modulate = Color(2.0, 2.0, 2.0, orig.a)
	get_tree().create_timer(0.10).timeout.connect(func() -> void: panel.modulate = orig)

func _on_cooldown_changed(slot_id: int, remaining: float, total: float) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var slot   : Dictionary  = _slots[slot_id]
	var cd_bar : ProgressBar = slot.cooldown_bar
	cd_bar.value   = remaining / maxf(total, 0.001)
	cd_bar.visible = remaining > 0.0

## Charge-based slot (slot 0 / Lance): bar fills upward as damage accumulates.
func _on_charge_changed(slot_id: int, current: float, max_charge: float) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var slot   : Dictionary  = _slots[slot_id]
	var cd_bar : ProgressBar = slot.cooldown_bar
	cd_bar.value   = current / maxf(max_charge, 0.001)
	cd_bar.visible = current > 0.0 and current < max_charge

func _on_ability_ready(slot_id: int) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	_slots[slot_id].cooldown_bar.visible = false

func _on_ability_unlocked(slot_id: int, _ability_id: StringName) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var slot: Dictionary = _slots[slot_id]
	slot.lock_overlay.visible = false
	slot.panel.modulate       = Color(1.0, 1.0, 1.0, 1.0)
