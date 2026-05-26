## WaveTable.gd
## Resource that holds the spawn definition for every wave in a faction's run.
## One WaveTable.tres per faction. The WaveManager loads the active faction's table.
## Each entry in waves[] is a Dictionary:
##   {
##     "unit": UnitData,   ## which unit type to spawn
##     "count": int,        ## how many
##     "interval": float,   ## seconds between individual spawns
##     "commander": {}      ## optional commander dialogue dict (see core/12)
##   }
@tool
extends Resource
class_name WaveTable

## Indexed by wave number (1-based). waves[0] = wave 1 data.
@export var waves: Array[Dictionary] = []

## Returns data for a given wave number (1-based).
## Falls back to a procedural default if the table doesn't define that wave.
func get_wave(wave_number: int) -> Dictionary:
	var idx: int = wave_number - 1
	if idx >= 0 and idx < waves.size():
		return waves[idx]
	return _procedural_wave(wave_number)

## Simple procedural fallback so waves never run dry during development.
func _procedural_wave(wave_number: int) -> Dictionary:
	return {
		"unit":      null,
		"count":     5 + (wave_number * 2),
		"interval":  1.2,
		"commander": {},
	}
