## FactionDialogue.gd
## Static lookup table mapping event keys and faction ids to one-liner notification strings.
## Add new event keys here; callers get an empty string if the lookup misses.
class_name FactionDialogue
extends RefCounted

const _LINES : Dictionary = {
	"convoy_arrived": {
		"architects": "Supply chain initialized.",
		"bloom":      "The root holds.",
		"mesh":       "Route confirmed. Signal nominal.",
	},
	"unit_died": {
		"architects": "Unit lost. Efficiency noted.",
		"bloom":      "Something died. We remember.",
		"mesh":       "Node dropped. Re-routing.",
	},
	"wave_flank": {
		"architects": "Secondary axis detected.",
		"bloom":      "They flank. Adapt.",
		"mesh":       "Flank vector found. Classic.",
	},
	"subpath_committed": {
		"architects": "Configuration locked.",
		"bloom":      "The branch holds.",
		"mesh":       "Protocol fork committed.",
	},
}

## Returns the faction-voiced one-liner for the given event key and faction id.
## Returns an empty string if no line is defined for the combination.
static func get_line(event_key: StringName, faction: String) -> String:
	var event_lines : Dictionary = _LINES.get(event_key, {})
	return event_lines.get(faction, "")
