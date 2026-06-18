## FriendlyRoster.gd
## Phase C — maps the player's faction to the roster unit its garrisons produce. The
## friendly army and the enemy waves draw from the SAME faction roster (core/17): when
## Architects are your enemy their Drones attack you; when you ARE Architects your Drones
## defend you. So we reuse the authored Tier-1 unit resource and just give it combat ability.
##
## Combat resolves through the one damage/armor triangle (the user's chosen model): a
## garrison unit deals its OWN faction's signature damage type vs the enemy's armor type.
class_name FriendlyRoster
extends RefCounted

## Player faction id → its Tier-1 roster unit resource (note the singular file names but
## plural faction ids — see the faction-id gotcha).
const _T1_PATHS : Dictionary = {
	"architects": "res://resources/units/architect_t1.tres",
	"bloom":      "res://resources/units/bloom_t1.tres",
	"mesh":       "res://resources/units/mesh_t1.tres",
}

## Default Tier-1 garrison combat stats, applied only when the roster resource hasn't
## authored attack values yet (it's currently tuned as a wave enemy). Light, fast, ranged
## harasser per core/17 (the Architect "Drone" and its faction equivalents).
const _T1_ATTACK_DAMAGE   : float = 8.0
const _T1_ATTACK_RANGE    : float = 150.0
const _T1_ATTACK_INTERVAL : float = 0.8

## Returns a combat-ready Tier-1 garrison UnitData for the faction, or null if unknown.
## Duplicates the shared resource so applying default attack stats never mutates the .tres.
static func garrison_unit(faction_id: String) -> UnitData:
	var path : String = str(_T1_PATHS.get(faction_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var base : UnitData = load(path) as UnitData
	if base == null:
		return null
	var u : UnitData = base.duplicate() as UnitData
	if u.attack_damage <= 0.0:
		u.attack_damage   = _T1_ATTACK_DAMAGE
		u.attack_range    = _T1_ATTACK_RANGE
		u.attack_interval = _T1_ATTACK_INTERVAL
	return u
