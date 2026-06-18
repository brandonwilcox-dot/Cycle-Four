## GalaxyManager.gd
## Manages the persistent galaxy meta-layer.
## Galaxy state survives individual runs (prestiges).
## Handles star systems, treaties, alliances, and the Neutral Core.
extends Node

# Treaty types from core/11_galaxy-politics.md
enum TreatyType { NONE, NON_AGGRESSION, TRADE, MUTUAL_DEFENSE, ALLIANCE }

## Phase D — galaxy graph. Each node (star_systems[id]) is a dict of JSON-safe fields:
##   owner (String: faction id / "neutral" / "core"), ring (int, 0=core), px/py (float,
##   galaxy-space position relative to the board centre), adj (Array[String] of neighbour
##   ids), seed (int → the territory's battle map via MapGenerator.generate(seed)).
## The galaxy is laid out in the SAME world space as the tactical board but far larger and
## centred on it, so zooming the camera out shrinks the board to the home node and reveals
## the surrounding rings (continuous tactical→galactic zoom).
var star_systems: Dictionary = {}     # system_id -> node dict (see above)
var treaties: Dictionary = {}         # "factionA_factionB" -> TreatyType
var alliance_data: Dictionary = {}    # active super-treaties
var custodian_position: String = ""   # system_id where Custodian is located

# Neutral Core systems (never capturable)
var neutral_core_systems: Array[String] = []

## The territory whose battle map is currently loaded, and (while invading a frontier node)
## the node a win will capture. active_node is the player's "you are here".
var active_node: String = ""
var invading_node: String = ""

## Galaxy layout (galaxy-space px, same units as the world/board).
const RING_COUNT     : int   = 4
const RING_SPACING   : float = 1600.0
const NODES_PER_RING : Array  = [1, 6, 10, 12, 14]   # index by ring; ring 0 = core

func _ready() -> void:
	pass  # Galaxy initialized from SaveManager on load, or generated via ensure_galaxy()

# -- Phase D: graph generation + queries --

## Generates the galaxy once per save (no-op if already populated, e.g. restored from save).
func ensure_galaxy(player_faction: String) -> void:
	if not star_systems.is_empty():
		if active_node.is_empty():
			active_node = _find_owned(player_faction)
		return
	generate_galaxy(player_faction)

## Builds concentric rings of nodes around a central core, webbed to adjacent rings + ring
## neighbours, with the player owning one rim node. Deterministic per galaxy_run_number.
func generate_galaxy(player_faction: String) -> void:
	star_systems.clear()
	neutral_core_systems.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("galaxy_%d" % GameState.galaxy_run_number)

	star_systems["core"] = { "owner": "core", "ring": 0, "px": 0.0, "py": 0.0, "adj": [], "seed": int(rng.randi()) }
	neutral_core_systems.append("core")

	var prev_ids : Array = ["core"]
	for ring in range(1, RING_COUNT + 1):
		var count  : int   = int(NODES_PER_RING[ring]) if ring < NODES_PER_RING.size() else 12
		var radius : float = float(ring) * RING_SPACING
		var ids    : Array = []
		for i in count:
			var ang : float  = TAU * float(i) / float(count) + rng.randf_range(-0.12, 0.12)
			var id  : String = "n%d_%d" % [ring, i]
			star_systems[id] = {
				"owner": "neutral", "ring": ring,
				"px": cos(ang) * radius, "py": sin(ang) * radius,
				"adj": [], "seed": int(rng.randi()),
			}
			ids.append(id)
		for id in ids:
			var nearest : String = _nearest_of(id, prev_ids)
			if nearest != "":
				_connect(id, nearest)
		for i in ids.size():
			_connect(ids[i], ids[(i + 1) % ids.size()])
		prev_ids = ids

	## Player starts owning one outermost-ring node — the campaign begins on the rim.
	var start : String = prev_ids[rng.randi_range(0, prev_ids.size() - 1)]
	star_systems[start]["owner"] = player_faction
	active_node = start

## Frontier = nodes adjacent to a player-owned node that the player does NOT own (the
## capturable targets, mirroring the tactical raid model one scale up).
func frontier(player_faction: String) -> Array:
	var out : Array = []
	for id in star_systems:
		if star_systems[id].get("owner") != player_faction:
			continue
		for nb in star_systems[id].get("adj", []):
			if star_systems.get(nb, {}).get("owner") != player_faction and nb not in out:
				out.append(nb)
	return out

func is_frontier(node_id: String, player_faction: String) -> bool:
	return node_id in frontier(player_faction)

## Galaxy-space position of a node (relative to the board centre; the view adds the centre).
func node_pos(node_id: String) -> Vector2:
	var n : Dictionary = star_systems.get(node_id, {})
	return Vector2(float(n.get("px", 0.0)), float(n.get("py", 0.0)))

func node_seed(node_id: String) -> int:
	return int(star_systems.get(node_id, {}).get("seed", 0))

func _find_owned(faction_id: String) -> String:
	for id in star_systems:
		if star_systems[id].get("owner") == faction_id:
			return id
	return ""

func _connect(a: String, b: String) -> void:
	if a == b:
		return
	if b not in star_systems[a]["adj"]:
		star_systems[a]["adj"].append(b)
	if a not in star_systems[b]["adj"]:
		star_systems[b]["adj"].append(a)

func _nearest_of(id: String, candidates: Array) -> String:
	var best : String = ""
	var best_d : float = INF
	var p : Vector2 = node_pos(id)
	for c in candidates:
		var d : float = p.distance_to(node_pos(c))
		if d < best_d:
			best_d = d
			best   = c
	return best

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
