## SaveManager.gd
## Handles save/load for all game state.
## Saves to user:// (Godot's user data directory, per-platform).
## Auto-saves every 60 seconds and on wave end.
extends Node

const SAVE_PATH: String         = "user://cycle_four_save.json"
const BACKUP_PATH: String       = "user://cycle_four_save.backup.json"
const AUTO_SAVE_INTERVAL: float = 60.0

## Set true during development to wipe saves on every launch.
## Flip to false before shipping or when testing persistence.
const DEV_CLEAR_SAVE: bool = false

var _auto_save_timer: float = 0.0
var _save_dirty: bool = false

func _ready() -> void:
	EventBus.wave_ended.connect(_on_wave_ended)
	EventBus.prestige_completed.connect(_on_prestige_completed)
	EventBus.faction_selected.connect(func(_f: String, _s: String) -> void: mark_dirty())
	EventBus.building_placed.connect(_on_dirty_event)
	EventBus.tower_placed.connect(_on_dirty_event)
	EventBus.tower_upgraded.connect(_on_dirty_event)
	if DEV_CLEAR_SAVE:
		_wipe_saves()
	## NOTE: we no longer auto-load here. TitleScreen owns the load decision
	## (Continue → load_game(); New Game → fresh state). This keeps app launch
	## on the title screen instead of jumping straight into a restored run.

func _process(delta: float) -> void:
	if _save_dirty:
		_auto_save_timer += delta
		if _auto_save_timer >= AUTO_SAVE_INTERVAL:
			save_game()

# -- Public API --

func save_game() -> void:
	var data: Dictionary = _collect_all_state()
	# Rotate backup before overwrite
	if FileAccess.file_exists(SAVE_PATH):
		var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var content := src.get_as_text()
		src.close()
		var bak := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		bak.store_string(content)
		bak.close()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_auto_save_timer = 0.0
	_save_dirty = false

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return  # New game -- managers initialize with defaults
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		push_error("SaveManager: corrupt save file. Trying backup.")
		_try_load_backup()
		return
	_apply_all_state(result)

func mark_dirty() -> void:
	_save_dirty = true

## True when a save file exists on disk. TitleScreen uses this to enable Continue.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Deletes save + backup. Public wrapper around _wipe_saves() for menu use.
func clear_save() -> void:
	_wipe_saves()

# -- Internal --

func _collect_all_state() -> Dictionary:
	return {
		"version":  1,
		"timestamp": Time.get_unix_time_from_system(),
		"game_state":       GameState.to_save_data(),
		"resources":        EconomyManager.resources,
		"production_rates": EconomyManager.production_rates,
		"territory_rates":  EconomyManager.territory_rates,
		"storage_caps":     EconomyManager.storage_caps,
		"galaxy":           _galaxy_to_dict(),
	}

func _apply_all_state(data: Dictionary) -> void:
	var offline_seconds: float = Time.get_unix_time_from_system() - data.get("timestamp", 0.0)
	GameState.apply_save_data(data.get("game_state", {}))
	var res: Dictionary = data.get("resources", {})
	for k in res:
		EconomyManager.resources[k] = float(res[k])
	var rates: Dictionary = data.get("production_rates", {})
	for k in rates:
		EconomyManager.set_production_rate(k, float(rates[k]))
	var caps: Dictionary = data.get("storage_caps", {})
	for k in caps:
		EconomyManager.storage_caps[k] = float(caps[k])
	var terr: Dictionary = data.get("territory_rates", {})
	for k in terr:
		EconomyManager.territory_rates[k] = float(terr[k])
	_galaxy_from_dict(data.get("galaxy", {}))
	# Apply offline production after all state is restored
	if offline_seconds > 30.0:
		EconomyManager.apply_offline_time(offline_seconds)

func _galaxy_to_dict() -> Dictionary:
	return {
		"star_systems":  GalaxyManager.star_systems,
		"treaties":      GalaxyManager.treaties,
		"run_number":    GameState.galaxy_run_number,
	}

func _galaxy_from_dict(data: Dictionary) -> void:
	GalaxyManager.star_systems = data.get("star_systems", {})
	GalaxyManager.treaties     = data.get("treaties", {})

func _wipe_saves() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _try_load_backup() -> void:
	if not FileAccess.file_exists(BACKUP_PATH):
		push_error("SaveManager: no backup available. Starting fresh.")
		return
	var file := FileAccess.open(BACKUP_PATH, FileAccess.READ)
	var result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if result:
		_apply_all_state(result)

func _on_wave_ended(_wave: int, _result: String) -> void:
	save_game()

func _on_prestige_completed(_faction: String) -> void:
	save_game()

## Shared dirty-marker wired to placement events. Godot 4 invokes the callable with
## the signal's arguments and errors if the method takes fewer, so accept (and ignore)
## the up-to-two payload args the placement signals carry.
func _on_dirty_event(_arg1: Variant = null, _arg2: Variant = null) -> void:
	mark_dirty()
