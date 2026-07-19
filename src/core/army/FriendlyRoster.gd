## FriendlyRoster.gd
## Phase C — maps the player's faction to the roster units its garrisons produce. The
## friendly army and the enemy waves draw from the SAME faction roster (core/17): when
## Architects are your enemy their units attack you; when you ARE Architects they defend you.
##
## U2 (units-land-plan): the roster is now multi-role. Each faction's "line" unit is its
## T1 balance anchor (the existing t1 .tres); scouts/artillery are new authored roles.
## U3: the T2/T3 roster joins — Heavy Assault, Support/Shield, Regen, Adaptive, Siege,
## Deceiver. Availability of a role is gated by the committed SUB-PATH (the T2 commit point,
## core/17): a unit whose sub_path_lock is set only appears once the player commits it.
## Mobile AA is DEFERRED until an air layer exists (an AA unit with nothing to shoot is a
## trap pick). Combat resolves through the one damage/armor triangle: a garrison unit deals
## its OWN faction's signature damage type vs the enemy's armor type.
class_name FriendlyRoster
extends RefCounted

## faction id → role id → unit .tres (singular file names, plural faction ids — see the
## faction-id gotcha). Friendly T2/T3 use their OWN .tres (attack-tuned for the player); the
## shared t2/t3 .tres stay enemy-wave units so the two sides tune independently.
const _ROSTER : Dictionary = {
	"architects": {
		"line":      "res://resources/units/architect_t1.tres",
		"scout":     "res://resources/units/architect_t1_scout.tres",
		"heavy":     "res://resources/units/architect_t2_heavy.tres",
		"support":   "res://resources/units/architect_t2_support.tres",
		"versatile": "res://resources/units/architect_t3_versatile.tres",
	},
	"bloom": {
		"line":      "res://resources/units/bloom_t1.tres",
		"scout":     "res://resources/units/bloom_t1_scout.tres",
		"artillery": "res://resources/units/bloom_t1_artillery.tres",
		"regen":     "res://resources/units/bloom_t2_regen.tres",
		"shield":    "res://resources/units/bloom_t2_shield.tres",
		"adaptive":  "res://resources/units/bloom_t3_adaptive.tres",
	},
	"mesh": {
		"line":     "res://resources/units/mesh_t1.tres",
		"scout":    "res://resources/units/mesh_t1_scout.tres",
		"heavy":    "res://resources/units/mesh_t2_heavy.tres",
		"deceiver": "res://resources/units/mesh_t2_deceiver.tres",
		"siege":    "res://resources/units/mesh_t3_siege.tres",
	},
}

## Stable cycle order for the garrison production toggle (T1 → T2 → T3 within each faction).
const _ROLE_ORDER : Dictionary = {
	"architects": ["line", "scout", "heavy", "support", "versatile"],
	"bloom":      ["line", "scout", "artillery", "regen", "shield", "adaptive"],
	"mesh":       ["line", "scout", "heavy", "deceiver", "siege"],
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
	## Only backfill default attack stats for combat units that authored none. Support/shield/
	## cloak emitters (U3) are DELIBERATELY non-combatant — never turn them into shooters.
	var is_support : bool = u.provides_shield > 0.0 or u.regen_aura > 0.0 or u.cloak_ally
	if u.attack_damage <= 0.0 and u.detector_radius <= 0.0 and not is_support:
		u.attack_damage   = _T1_ATTACK_DAMAGE
		u.attack_range    = _T1_ATTACK_RANGE
		u.attack_interval = _T1_ATTACK_INTERVAL
	return u

## U4 (units-land-plan / Units_Land §4) — the heresy modifier layer. Each HERETIC sub-path grants
## its whole army one borrowed-mechanic modifier (the Option B seam, expressed only as mechanics —
## NEVER captioned in-game). Orthodox paths (standard / purist / networked) grant nothing here and
## stay internally clean. First-class resources, never one-offs.
const _HERETIC_MODIFIERS : Dictionary = {
	"spiritual_tech": "res://resources/modifiers/terrain_bond.tres",     ## Architect → Bloom (rooting)
	"assimilator":    "res://resources/modifiers/wreckage_absorb.tres",  ## Bloom → Mesh (take/absorb)
	"dreamer":        "res://resources/modifiers/dream_stabilize.tres",  ## Mesh → the unbroken origin
}

## Returns the heretic UnitModifier for a committed sub-path, or null on an orthodox path.
static func heretic_modifier(sub_path: String) -> UnitModifier:
	var path : String = str(_HERETIC_MODIFIERS.get(sub_path, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as UnitModifier

## The production roles a faction's garrisons can cycle through, filtered by the committed
## sub-path (U3: T2+ units may lock to a sub-path — the T2 commit point, core/17). A role
## with an empty sub_path_lock is available on every path.
static func roles_for(faction_id: String, sub_path: String = "") -> Array:
	var order : Array = _ROLE_ORDER.get(faction_id, ["line"])
	var out : Array = []
	for role in order:
		if _role_eligible(faction_id, str(role), sub_path):
			out.append(role)
	return out if not out.is_empty() else ["line"]

## Whether a role's unit is buildable under the given committed sub-path.
static func _role_eligible(faction_id: String, role: String, sub_path: String) -> bool:
	var roles : Dictionary = _ROSTER.get(faction_id, {})
	var path  : String = str(roles.get(role, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var u : UnitData = load(path) as UnitData
	if u == null:
		return false
	return u.sub_path_lock == "" or u.sub_path_lock == sub_path
