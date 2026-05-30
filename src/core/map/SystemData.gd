## SystemData.gd
## Top-level loadable resource representing one star system.
## Contains one or more MapData instances (planets, moons in the same system).
## Cross-map persistence is implemented by saving each MapData snapshot back into
## this resource on map switch. See §2.2 of the map architecture handoff.
class_name SystemData
extends Resource

@export var system_id: StringName = &""
@export var name: String = ""

## All playable maps in this system (planets, moons).
@export var maps: Array[MapData] = []

## Objectives that span multiple maps. The system is complete when all are met.
@export var system_objectives: Array[ObjectiveData] = []

## Derived: true once all system_objectives are complete and the system is quiet.
## Once true, the system remains owned by the player unless the endgame threat
## (Arrival / Silence Vector, core/14 + core/20) forces a re-invasion.
var secured: bool = false

## Biome templates this system's maps draw from. Affects procedural generation odds.
## A system near the galactic core has different biome odds than an outer-arm system.
@export var biome_template_refs: Array[StringName] = []

## NPC factions with territory or interest in this system. Drives objective generation.
## Keyed by faction_id (String) -> presence weight or data (Variant).
@export var faction_presence: Dictionary = {}
