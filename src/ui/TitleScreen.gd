## TitleScreen.gd
## Production entry point. Built programmatically (house style — see AbilityBar.gd)
## so it doesn't depend on a fragile hand-authored .tscn tree.
##
## Menu: New Game / Continue / Options / Quit.
##   New Game  — resets in-memory state to defaults and loads Main (Academy plays).
##   Continue  — loads the save file, then loads Main (Main restores the world).
##               Disabled when no save exists.
##   Options   — master volume + fullscreen, persisted to user://settings.cfg.
##
## SaveManager no longer auto-loads at startup; this screen owns the load decision.
extends Control

const BATTLE_SCENE   : String = "res://scenes/main/Battle3D.tscn"   ## 3D battle (promoted from scenes/test; 2D Battle.tscn kept as fallback)
const SETTINGS_PATH : String = "user://settings.cfg"

const COL_BG       : Color = Color(0.05, 0.05, 0.08, 1.0)
const COL_TITLE    : Color = Color(0.95, 0.85, 0.45, 1.0)
const COL_SUBTITLE : Color = Color(0.55, 0.60, 0.70, 1.0)

var _menu_root      : CenterContainer = null
var _options_root   : CenterContainer = null
var _continue_btn   : Button          = null
var _volume_slider  : HSlider         = null
var _fullscreen_chk : CheckButton     = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_and_apply_settings()
	## Pull the window to the foreground on launch so it doesn't open behind other apps.
	DisplayServer.window_move_to_foreground()
	_build_ui()

# -- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COL_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_menu()
	_build_options()
	_options_root.hide()

func _build_menu() -> void:
	_menu_root = CenterContainer.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_root)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_menu_root.add_child(vbox)

	var title := Label.new()
	title.text = "CYCLE FOUR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", COL_TITLE)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Idle · Tower Defense · Endless Wave"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", COL_SUBTITLE)
	vbox.add_child(subtitle)

	vbox.add_child(_spacer(24))

	var new_game_btn := _menu_button("New Game")
	new_game_btn.pressed.connect(_on_new_game_pressed)
	vbox.add_child(new_game_btn)

	_continue_btn = _menu_button("Continue")
	_continue_btn.disabled = not SaveManager.has_save()
	_continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(_continue_btn)

	var options_btn := _menu_button("Options")
	options_btn.pressed.connect(_on_options_pressed)
	vbox.add_child(options_btn)

	var quit_btn := _menu_button("Quit")
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	new_game_btn.grab_focus()

func _build_options() -> void:
	_options_root = CenterContainer.new()
	_options_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_options_root)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	_options_root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "Options"
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", COL_TITLE)
	vbox.add_child(header)

	vbox.add_child(_spacer(8))

	var vol_label := Label.new()
	vol_label.text = "Master Volume"
	vbox.add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = _current_master_linear()
	_volume_slider.custom_minimum_size = Vector2(0.0, 24.0)
	_volume_slider.value_changed.connect(_on_volume_changed)
	vbox.add_child(_volume_slider)

	_fullscreen_chk = CheckButton.new()
	_fullscreen_chk.text = "Fullscreen"
	_fullscreen_chk.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	_fullscreen_chk.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(_fullscreen_chk)

	vbox.add_child(_spacer(8))

	var back_btn := _menu_button("Back")
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

func _menu_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(240.0, 44.0)
	btn.add_theme_font_size_override("font_size", 20)
	return btn

func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, float(height))
	return c

# -- Menu actions -------------------------------------------------------------

func _on_new_game_pressed() -> void:
	## Fresh slate. We do NOT delete the existing save here — it is overwritten
	## naturally once the new run auto-saves, so quitting mid-Academy is non-destructive.
	GameState.reset_for_new_game()
	SceneManager.change_to(BATTLE_SCENE)

func _on_continue_pressed() -> void:
	if not SaveManager.has_save():
		return
	SaveManager.load_game()
	SceneManager.change_to(BATTLE_SCENE)

func _on_options_pressed() -> void:
	_menu_root.hide()
	_options_root.show()

func _on_back_pressed() -> void:
	_options_root.hide()
	_menu_root.show()

func _on_quit_pressed() -> void:
	get_tree().quit()

# -- Settings -----------------------------------------------------------------

func _on_volume_changed(value: float) -> void:
	_apply_master_volume(value)
	_save_settings()

func _on_fullscreen_toggled(on: bool) -> void:
	## Exclusive fullscreen genuinely covers the taskbar and grabs the display, so the
	## bottom UI (action bar, sell button) is never clipped. Unchecked → maximized window
	## (respects the work area, stays above the taskbar) rather than a tiny floating window.
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_MAXIMIZED
	)
	_save_settings()

func _apply_master_volume(linear: float) -> void:
	var bus : int = AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(linear, 0.0001, 1.0)))
	AudioServer.set_bus_mute(bus, linear <= 0.0001)

func _current_master_linear() -> float:
	var bus : int = AudioServer.get_bus_index("Master")
	if bus < 0:
		return 1.0
	if AudioServer.is_bus_mute(bus):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus))

func _load_and_apply_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var vol : float = float(cfg.get_value("audio", "master_volume", 1.0))
	_apply_master_volume(vol)
	var fs : bool = bool(cfg.get_value("display", "fullscreen", false))
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_MAXIMIZED
	)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   ## keep any keys we don't manage
	if _volume_slider != null:
		cfg.set_value("audio", "master_volume", _volume_slider.value)
	if _fullscreen_chk != null:
		cfg.set_value("display", "fullscreen", _fullscreen_chk.button_pressed)
	cfg.save(SETTINGS_PATH)
