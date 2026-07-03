## AbilityBar.gd
## Bottom-center HUD cluster showing four Commander ability slots (Q/W/E/R).
##
## Accessibility rules (core/22 §10):
##   - Cooldown state is conveyed by BOTH the bar sweep AND a numeric countdown
##     label ("4s"), so a colorblind player reads the state from text, not color.
##   - Ready state emits a brightness flash (shape change) in addition to bar clear.
##   - Charge state shows "READY" text when slot 0 is fully charged.
##   - Lock state shows a "—" text label inside the dark overlay (not color only).
##   - Slot is dimmed (0.70 opacity) while on cooldown, full opacity when ready.
extends Control

const SLOT_SIZE   : float = 52.0
const SLOT_GAP    : float = 8.0
const KEY_LABELS  : Array = ["1", "2", "3", "4"]   ## Q/W/E/R belong to the camera
const SLOT_COLORS : Array = [
	Color(1.00, 0.92, 0.30, 1.0),   ## Lance — gold
	Color(0.40, 0.80, 1.00, 1.0),   ## Suppression Field — cyan
	Color(1.00, 0.55, 0.18, 1.0),   ## Overdrive — orange
	Color(0.85, 0.30, 1.00, 1.0),   ## Ultimate — magenta placeholder
]

## Each entry: {panel, cooldown_bar, key_label, state_label, lock_overlay, lock_label}
## state_label shows cooldown countdown or "READY"; lock_label shows "—" when locked.
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
	for i in 4:
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

	## Cooldown / charge sweep bar.
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

	## State label — center of slot. Shows cooldown countdown ("4s"), charge
	## percentage label, or "READY" text. Hidden when neither applies.
	## Provides the non-color channel required by core/22 §10.
	var state_label := Label.new()
	state_label.text             = ""
	state_label.visible          = false
	state_label.set_anchors_preset(Control.PRESET_CENTER)
	state_label.offset_left      = -20.0
	state_label.offset_top       = -9.0
	state_label.offset_right     = 20.0
	state_label.offset_bottom    = 9.0
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(state_label)

	## Key glyph in bottom-left corner.
	var key_label := Label.new()
	key_label.text         = KEY_LABELS[index]
	key_label.position     = Vector2(4.0, SLOT_SIZE - 18.0)
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

	## Lock text — "—" centered in the overlay (non-color accessibility indicator).
	var lock_lbl := Label.new()
	lock_lbl.text             = "--"
	lock_lbl.set_anchors_preset(Control.PRESET_CENTER)
	lock_lbl.offset_left      = -12.0
	lock_lbl.offset_top       = -9.0
	lock_lbl.offset_right     = 12.0
	lock_lbl.offset_bottom    = 9.0
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lock_lbl.add_theme_font_size_override("font_size", 13)
	lock_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.45))
	lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(lock_lbl)

	return {
		panel        = panel,
		cooldown_bar = cd_bar,
		state_label  = state_label,
		key_label    = key_label,
		lock_overlay = lock,
		lock_label   = lock_lbl,
	}

## -- Signal handlers --

func _on_ability_used(slot_id: int) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var panel : PanelContainer = _slots[slot_id].panel
	var orig  : Color          = panel.modulate
	panel.modulate = Color(2.0, 2.0, 2.0, orig.a)
	get_tree().create_timer(0.10).timeout.connect(func() -> void: panel.modulate = orig)
	## Clear "READY" text immediately on cast.
	var state_label : Label = _slots[slot_id].state_label
	state_label.text    = ""
	state_label.visible = false

func _on_cooldown_changed(slot_id: int, remaining: float, total: float) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var slot        : Dictionary  = _slots[slot_id]
	var cd_bar      : ProgressBar = slot.cooldown_bar
	var state_label : Label       = slot.state_label
	var panel       : PanelContainer = slot.panel
	if remaining > 0.0:
		cd_bar.value        = remaining / maxf(total, 0.001)
		cd_bar.visible      = true
		## Countdown text: show tenths below 10 s, whole seconds above.
		var secs : String   = "%.1fs" % remaining if remaining < 10.0 else "%ds" % int(ceili(remaining))
		state_label.text    = secs
		state_label.visible = true
		panel.modulate      = Color(1.0, 1.0, 1.0, 0.70)  ## dim while on cooldown
	else:
		cd_bar.visible      = false
		state_label.visible = false
		panel.modulate      = Color(1.0, 1.0, 1.0, 1.0)

func _on_charge_changed(slot_id: int, current: float, max_charge: float) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var slot        : Dictionary  = _slots[slot_id]
	var cd_bar      : ProgressBar = slot.cooldown_bar
	var state_label : Label       = slot.state_label
	if current >= max_charge:
		## Fully charged — bar hidden, "READY" text shown.
		cd_bar.visible      = false
		state_label.text    = "READY"
		state_label.visible = true
	elif current > 0.0:
		cd_bar.value        = current / maxf(max_charge, 0.001)
		cd_bar.visible      = true
		## Show percentage as accessibility text alongside the fill bar.
		state_label.text    = "%d%%" % int(100.0 * current / max_charge)
		state_label.visible = true
	else:
		cd_bar.visible      = false
		state_label.text    = ""
		state_label.visible = false

func _on_ability_ready(slot_id: int) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var slot        : Dictionary     = _slots[slot_id]
	var panel       : PanelContainer = slot.panel
	var state_label : Label          = slot.state_label
	## Clear bar and dim-state.
	slot.cooldown_bar.visible = false
	panel.modulate            = Color(1.0, 1.0, 1.0, 1.0)
	## Slot 0 (charge) shows "READY" via _on_charge_changed; cooldown slots get
	## a brief flash indicating readiness.
	if slot_id != 0:
		state_label.text    = "!"
		state_label.visible = true
		var orig : Color    = panel.modulate
		panel.modulate = Color(1.6, 1.6, 1.6, orig.a)
		get_tree().create_timer(0.30).timeout.connect(func() -> void:
			panel.modulate      = orig
			state_label.text    = ""
			state_label.visible = false
		)

func _on_ability_unlocked(slot_id: int, _ability_id: StringName) -> void:
	if slot_id < 0 or slot_id >= _slots.size():
		return
	var slot : Dictionary = _slots[slot_id]
	slot.lock_overlay.visible = false
	slot.lock_label.visible   = false
	slot.panel.modulate       = Color(1.0, 1.0, 1.0, 1.0)
