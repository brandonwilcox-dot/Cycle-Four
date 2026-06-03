## WaveTableBuilder.gd
## Builds WaveTable instances in GDScript for each faction.
## Used by WaveSpawner when no authored wave_table.tres exists.
## Wave curve design (core/17):
##   Waves  1-12 : Tier 1 — light, plentiful, escalating count + speed
##   Waves 13-19 : Tier 2 — mid-weight, fewer but durable
##   Waves 20-25+: Tier 3 — heavy anchors, small count, dangerous
## Commander names (core/12) appear on waves 11+ as a "commander" dict.
class_name WaveTableBuilder
extends RefCounted

## Unit resource paths per faction and tier.
const _UNIT_PATHS : Dictionary = {
	"architects": {
		1: "res://resources/units/architect_t1.tres",
		2: "res://resources/units/architect_t2.tres",
		3: "res://resources/units/architect_t3.tres",
	},
	"bloom": {
		1: "res://resources/units/bloom_t1.tres",
		2: "res://resources/units/bloom_t2.tres",
		3: "res://resources/units/bloom_t3.tres",
	},
	"mesh": {
		1: "res://resources/units/mesh_t1.tres",
		2: "res://resources/units/mesh_t2.tres",
		3: "res://resources/units/mesh_t3.tres",
	},
}

## Commander names per faction for waves 11-25 (core/12 tiers 11-25).
## Each entry: wave_number -> "Name, Title"
const _COMMANDERS : Dictionary = {
	"architects": {
		11: "Adjutant Venn",
		13: "Overseer Dusk",
		15: "Magistrate Cael",
		18: "Director Sorin",
		20: "Archivist Krenn",
		23: "Grand Compiler Vell",
		25: "Prime Director Aethon",
	},
	"bloom": {
		11: "The First Tendril",
		13: "Verdant Scion",
		15: "Elder Root",
		18: "The Spreading Dark",
		20: "Biomass Incarnate",
		23: "The Living Archive",
		25: "The Biosphere's Voice",
	},
	"mesh": {
		11: "Node-7",
		13: "Subnet Kael",
		15: "The Distributed",
		18: "Signal Override",
		20: "Daemon-Core",
		23: "System Primarch",
		25: "The Network Itself",
	},
}

## Builds and returns a WaveTable for the given faction.
## Returns null if the faction is unknown or unit paths are missing.
static func build(faction_id: String) -> WaveTable:
	if not _UNIT_PATHS.has(faction_id):
		push_warning("WaveTableBuilder: unknown faction '%s'" % faction_id)
		return null
	var paths  : Dictionary = _UNIT_PATHS[faction_id]
	var t1     : UnitData   = _load_unit(paths.get(1, ""))
	var t2     : UnitData   = _load_unit(paths.get(2, ""))
	var t3     : UnitData   = _load_unit(paths.get(3, ""))
	if t1 == null:
		push_warning("WaveTableBuilder: T1 unit missing for '%s'" % faction_id)
		return null
	var table  : WaveTable = WaveTable.new()
	var cmds   : Dictionary = _COMMANDERS.get(faction_id, {})
	for w : int in 30:
		var wave_num : int = w + 1
		table.waves.append(_make_entry(wave_num, t1, t2, t3, cmds))
	return table

## Builds one wave entry dictionary.
static func _make_entry(wave: int, t1: UnitData, t2: UnitData, t3: UnitData,
		cmds: Dictionary) -> Dictionary:
	var unit     : UnitData = _unit_for_wave(wave, t1, t2, t3)
	var count    : int      = _count_for_wave(wave)
	var interval : float    = _interval_for_wave(wave)
	var cmd_name : String   = ""
	if wave >= 11:
		## Find the most recent commander at or before this wave number.
		for cw : int in cmds.keys():
			if cw <= wave:
				cmd_name = cmds[cw]
	var entry : Dictionary = {
		"unit":     unit,
		"count":    count,
		"interval": interval,
	}
	if not cmd_name.is_empty():
		entry["commander"] = { "name": cmd_name }
	return entry

## Selects the unit tier appropriate for this wave.
static func _unit_for_wave(wave: int, t1: UnitData, t2: UnitData, t3: UnitData) -> UnitData:
	if wave >= 20:
		return t3 if t3 != null else (t2 if t2 != null else t1)
	if wave >= 13:
		return t2 if t2 != null else t1
	return t1

## Unit count per wave — rises through T1, drops at each tier transition then rises again.
## T1 (1-12): 6 → 22  T2 (13-19): 5 → 11  T3 (20-25+): 3 → 8
static func _count_for_wave(wave: int) -> int:
	if wave >= 20:
		return clampi(3 + (wave - 20), 3, 10)
	if wave >= 13:
		return clampi(5 + (wave - 13), 5, 12)
	return clampi(4 + wave * 2, 6, 24)

## Spawn interval (seconds between individual unit spawns).
## Shorter intervals = faster pressure. Resets slightly on tier transitions.
static func _interval_for_wave(wave: int) -> float:
	if wave >= 20:
		return clampf(2.0 - (wave - 20) * 0.06, 1.4, 2.0)
	if wave >= 13:
		return clampf(1.6 - (wave - 13) * 0.06, 1.1, 1.6)
	return clampf(1.6 - wave * 0.05, 0.9, 1.6)

static func _load_unit(path: String) -> UnitData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as UnitData
