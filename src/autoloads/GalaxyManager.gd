## GalaxyManager.gd
## Manages the persistent galaxy meta-layer.
## Galaxy state survives individual runs (prestiges).
## Handles star systems, treaties, alliances, and the Neutral Core.
extends Node

# Treaty types from core/11_galaxy-politics.md
enum TreatyType { NONE, NON_AGGRESSION, TRADE, MUTUAL_DEFENSE, ALLIANCE }

var star_systems: Dictionary = {}     # system_id -> { owner, value, has_ruins }
var treaties: Dictionary = {}         # "factionA_factionB" -> TreatyType
var alliance_data: Dictionary = {}    # active super-treaties
var custodian_position: String = ""   # system_id where Custodian is located

# Neutral Core systems (never capturable)
var neutral_core_systems: Array[String] = []

func _ready() -> void:
	pass  # Galaxy initialized from SaveManager on load

# -- Public API --

func capture_system(system_id: String, faction_id: String) -> void:
	if system_id in neutral_core_systems:
		return  # Neutral Core is uncapturable
	var previous_owner: String = star_systems.get(system_id, {}).get("owner", "")
	if system_id in star_systems:
		star_systems[system_id]["owner"] = faction_id
	EventBus.star_system_captured.emit(system_id, faction_id)
	_check_treaty_breach(system_id, previous_owner, faction_id)

func form_treaty(faction_a: String, faction_b: String, treaty_type: TreatyType) -> void:
	var key: String = _treaty_key(faction_a, faction_b)
	treaties[key] = treaty_type
	EventBus.treaty_formed.emit(faction_a, faction_b, TreatyType.keys()[treaty_type])

func break_treaty(faction_a: String, faction_b: String, reason: String) -> void:
	var key: String = _treaty_key(faction_a, faction_b)
	treaties.erase(key)
	EventBus.treaty_broken.emit(faction_a, faction_b, reason)

func get_treaty(faction_a: String, faction_b: String) -> TreatyType:
	return treaties.get(_treaty_key(faction_a, faction_b), TreatyType.NONE)

func get_system_count_by_faction(faction_id: String) -> int:
	var count: int = 0
	for sys in star_systems.values():
		if sys.get("owner") == faction_id:
			count += 1
	return count

# -- Internal --

func _treaty_key(a: String, b: String) -> String:
	# Canonical order so "architects_bloom" == "bloom_architects"
	var sorted: Array = [a, b]
	sorted.sort()
	return "_".join(sorted)

func _check_treaty_breach(system_id: String, previous_owner: String, new_owner: String) -> void:
	if previous_owner.is_empty() or previous_owner == new_owner:
		return
	var treaty: TreatyType = get_treaty(new_owner, previous_owner)
	if treaty != TreatyType.NONE:
		# Capturing a system breaks any active treaty -- notify but don't auto-break
		# (player may have valid Defector/Cooperator play -- let game logic decide)
		EventBus.notification_pushed.emit(
			"Capturing %s may breach your treaty with %s." % [system_id, previous_owner],
			"warning"
		)
