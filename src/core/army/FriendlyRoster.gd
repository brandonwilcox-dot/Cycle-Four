## FriendlyRoster.gd
## Phase C — maps the player's faction to the roster units its garrisons produce. The
## friendly army and the enemy waves draw from the SAME faction roster (core/17): when
## Architects are your enemy their units attack you; when you ARE Architects they defend you.
##
## U2 (units-land-plan): the roster is now multi-role. Each faction's "line" unit is its
## T1 balance anchor (the existing t1 .tres); scouts/artillery are new authored roles.
## Mobile AA is DEFERRED until an air layer exists (an AA unit with nothing to shoot is a
## trap pick). Combat resolves through the one damage/armor triangle: a garrison unit deals
## its OWN faction's signature damage type vs the enemy's armor type.
class_name FriendlyRoster
extends RefCounted

## faction id → role id → unit .tres (singular file names, plural faction ids — see the
## faction-id gotcha).
const _ROSTER : Dictionary = {
	"architects": {
		"line":  "res://resources/units/architect_t1.tres",
		"scout": "res://resources/units/architect_t1_scout.tres",
	},
	"bloom": {
		"line":      "res://resources/units/bloom_t1.tres",
		"scout":     "res://resources/units/bloom_t1_scout.tres",
		"artillery": "res://resources/units/bloom_t1_artillery.tres",
	},
	"mesh": {
		"line":  "res://resources/units/mesh_t1.tres",
		"scout": "res://resources/units/mesh_t1_scout.tres",
	},
}

## Stable cycle order for the garrison production toggle.
const _ROLE_ORDER : Dictionary = {
	"architects": ["line", "scout"],
	"bloom":      ["line", "scout", "artillery"],
	"mesh":       ["line", "scout"],
}

## Default garrison combat stats, applied only when the roster resource hasn't authored
## attack values (kept for safety; U2 authored real values onto every roster unit).
const _T1_ATTACK_DAMAGE   : float = 8.0
const _T1_ATTACK_RANGE    : float = 150.0
const _T1_ATTACK_INTERVAL : float = 0.8

## Returns a combat-ready garrison UnitData for the faction + role, or null if unknown.
## Duplicates the shared resource so applying default attack stats never mutates the .tres.
static func garrison_unit(faction_id: String, role: String = "line") -> UnitData:
	var roles : Dictionary = _ROSTER.get(faction_id, {})
	var path  : String = str(roles.get(role, roles.get("line", "")))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var base : UnitData = load(path) as UnitData
	if base == null:
		return null
	var u : UnitData = base.duplicate() as UnitData
	if u.attack_damage <= 0.0 and u.detector_radius <= 0.0:
		u.attack_damage   = _T1_ATTACK_DAMAGE
		u.attack_range    = _T1_ATTACK_RANGE
		u.attack_interval = _T1_ATTACK_INTERVAL
	return u

## The production roles a faction's garrisons can cycle through.
static func roles_for(faction_id: String) -> Array:
	return _ROLE_ORDER.get(faction_id, ["line"])
