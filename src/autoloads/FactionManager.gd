## FactionManager.gd
## Owns faction selection, sub-path tracking, and faction-specific data lookups.
## All "what does this faction do" questions are answered here.
extends Node

const FACTION_IDS: Array[String] = ["architects", "bloom", "mesh"]

const SUB_PATHS: Dictionary = {
	"architects": ["standard", "spiritual_tech"],
	"bloom":      ["purist", "assimilator"],
	"mesh":       ["networked", "dreamer"],
}

# Faction resource names (primary / secondary)
const FACTION_RESOURCES: Dictionary = {
	"architects": ["energy",  "schematics"],
	"bloom":      ["biomass", "lineages"],
	"mesh":       ["signal",  "routes"],
}

var active_faction: String = ""
var active_sub_path: String = ""

# -- Public API --

func select_faction(faction_id: String, sub_path: String) -> void:
	assert(faction_id in FACTION_IDS, "Unknown faction: " + faction_id)
	assert(sub_path in SUB_PATHS[faction_id], "Unknown sub-path: " + sub_path)
	active_faction  = faction_id
	active_sub_path = sub_path
	GameState.current_faction  = faction_id
	GameState.current_sub_path = sub_path
	_initialize_faction_economy()
	EventBus.faction_selected.emit(faction_id, sub_path)

func get_primary_resource() -> String:
	return FACTION_RESOURCES.get(active_faction, ["energy", ""])[0]

func get_secondary_resource() -> String:
	return FACTION_RESOURCES.get(active_faction, ["", "schematics"])[1]

func get_wave_data(wave_number: int) -> Dictionary:
	## Load wave definition from faction-specific resource table.
	## Returns empty dict if no data exists yet (safe default).
	var path: String = "res://resources/factions/%s/waves.tres" % active_faction
	if ResourceLoader.exists(path):
		var table = load(path)
		if table and table.has_method("get_wave"):
			return table.get_wave(wave_number)
	return {"enemy_count": _default_enemy_count(wave_number), "commander": {}}

func get_starter_tower() -> Resource:
	## Returns the T1 TowerData for the active faction, or null if not found.
	var path: String = "res://resources/towers/%s_t1.tres" % active_faction
	if ResourceLoader.exists(path):
		return load(path)
	return null

func get_production_rates(sub_path: String) -> Dictionary:
	## Base production rates before building bonuses.
	## Override per faction in their faction script.
	return {}

# -- Internal --

func _initialize_faction_economy() -> void:
	## Seed EconomyManager with starting resources and rates for chosen faction.
	var primary:   String = get_primary_resource()
	var secondary: String = get_secondary_resource()
	## Reset pools so a faction switch doesn't carry over old resources
	EconomyManager.resources       = {}
	EconomyManager.production_rates = {}
	EconomyManager.storage_caps[primary]   = 1000.0
	EconomyManager.storage_caps[secondary] = 500.0
	## Base rates -- buildings add on top of these
	EconomyManager.set_production_rate(primary,   1.0)
	EconomyManager.set_production_rate(secondary, 0.2)
	## Use add_resource() so resource_changed fires immediately and HUD shows correct values
	EconomyManager.add_resource(primary,   50.0)
	EconomyManager.add_resource(secondary, 10.0)

func _default_enemy_count(wave: int) -> int:
	## Fallback scaling before wave tables are authored.
	return 5 + (wave * 2)
