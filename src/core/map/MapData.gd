## MapData.gd
## A single playable map (one planet or moon). Self-contained: saving and reloading
## this resource restores the full runtime state of the map, including fog, claims,
## and support-graph connectivity. See §2.3 of the map architecture handoff.
class_name MapData
extends Resource

const DEFAULT_COLS : int = 60
const DEFAULT_ROWS : int = 34

## Bytes per cell in the meta array. One u32 (4 bytes) holds all 30 used bits per cell.
const META_STRIDE  : int = 4

## -- Meta bitfield layout (u32 per cell, little-endian) --
## Bit 0      revealed              (1 bit)
## Bits 1-4   claimed_by            (4 bits, faction id 0–15; 0 = unclaimed)
## Bits 5-8   biomass_progress      (4 bits, 0–15)
## Bits 9-24  hacked_until_tick     (16 bits, wave-tick deadline; 0 = not hacked)
## Bits 25-28 ruins_proximity       (4 bits, effect strength 0–15)
## Bit 29     relay_covered         (1 bit)
## Bit 30     sensed                (1 bit) — covered by a sensor sphere (stealth detection)
## Bit 31     unused
const META_BIT_REVEALED           : int = 0
const META_BIT_CLAIMED_BY         : int = 1
const META_BIT_BIOMASS_PROGRESS   : int = 5
const META_BIT_HACKED_UNTIL_TICK  : int = 9
const META_BIT_RUINS_PROXIMITY    : int = 25
const META_BIT_RELAY_COVERED      : int = 29
const META_BIT_SENSED             : int = 30

const META_MASK_REVEALED          : int = 0x1
const META_MASK_CLAIMED_BY        : int = 0xF
const META_MASK_BIOMASS_PROGRESS  : int = 0xF
const META_MASK_HACKED_UNTIL_TICK : int = 0xFFFF
const META_MASK_RUINS_PROXIMITY   : int = 0xF
const META_MASK_RELAY_COVERED     : int = 0x1
const META_MASK_SENSED            : int = 0x1

@export var map_id: StringName = &""
@export var dimensions: Vector2i = Vector2i(DEFAULT_COLS, DEFAULT_ROWS)
@export var biome: StringName = &""
@export var topology_template: StringName = &""

## The RNG seed this map was generated from. A territory on the galactic map (future
## Total-War-style campaign layer) stores this seed plus its graph metadata (adjacency,
## owner, distance-to-core); the battle map is reproduced deterministically by calling
## MapGenerator.generate(seed) — persistence without storing the full cell grid. 0 means
## hand-authored / not procgen. (Named map_seed, not seed, to avoid shadowing the
## built-in seed() RNG function.)
@export var map_seed: int = 0

## Flat cell-type array. Length = dimensions.x * dimensions.y.
## Values match MapGrid.Cell enum. Enemy AStar reads only this array — never meta.
@export var cell_types: PackedByteArray = PackedByteArray()

## Per-cell runtime state packed as u32 bitfields. Length = dimensions.x * dimensions.y * META_STRIDE.
## Use get_meta_*/set_meta_* accessors only — never write bytes directly.
## NOTE: hacked_until_tick is relative to current_wave_tick; always snapshot both together.
@export var meta: PackedByteArray = PackedByteArray()

@export var zones: Array[ZoneRegion] = []
@export var spawn_points: Array[SpawnPoint] = []
@export var support_graph: SupportGraph = SupportGraph.new()

## Keyed by "faction_id:subpath_id" (e.g. "architects:standard") -> Array[ObjectiveData].
## Resolved at run start against the active player's faction and sub-path selection.
@export var objectives_by_faction_subpath: Dictionary = {}

## Ruins sites on this map. Typically 0–2 per core/17 §8.
## Typed as plain Array until RuinsSite resource is defined (Phase 7+).
@export var ruins_sites: Array = []

## Snapshot of the wave-tick counter when this MapData was last saved.
## Required to correctly interpret meta.hacked_until_tick across map switches.
## Always serialize alongside meta; do not separate them.
@export var current_wave_tick: int = 0

## -- Zone reverse index (runtime only, not serialized) --
## Built by build_zone_index() at map load and rebuilt only on map hot-swap.
## NEVER rebuilt mid-wave — Constraint #3 (no per-frame full-grid scans).

## Vector2i (cell coord) -> Array[StringName] (zone ids covering that cell).
## Most cells have 0 entries; some have 1; rare cells in stacked zones have 2.
var _zones_by_cell: Dictionary = {}

## StringName (zone id) -> Array[Vector2i] (cells in that zone).
## Used for HUD overlays, flanker priority lists, and "all cells in zone X" queries.
var _cells_by_zone: Dictionary = {}

## -- Array initialisation --

## Resizes cell_types and meta to match dimensions. Call after setting dimensions.
## Fills both arrays with zeroes (GROUND cells, all meta flags cleared).
func init_arrays() -> void:
	var count : int = dimensions.x * dimensions.y
	cell_types.resize(count)
	cell_types.fill(0)
	meta.resize(count * META_STRIDE)
	meta.fill(0)

## -- Zone reverse index --

## Clears and rebuilds both reverse indices from the current zones array.
## Call after the zones list is populated, or after any change to a zone's shape.
## Cost: O(total cells across all zones). Never call mid-wave.
func build_zone_index() -> void:
	_zones_by_cell.clear()
	_cells_by_zone.clear()
	for zone in zones:
		if zone == null:
			continue
		var fresh_cells : Array[Vector2i] = []
		_cells_by_zone[zone.id] = fresh_cells
		if zone.use_rect:
			_index_rect(zone)
		else:
			_index_cell_list(zone)

## Returns the zone ids covering the given cell. Empty array if none.
## Returned array is the live index entry — treat as read-only.
func get_zones_at_cell(cell: Vector2i) -> Array[StringName]:
	if _zones_by_cell.has(cell):
		return _zones_by_cell[cell]
	var empty : Array[StringName] = []
	return empty

## Returns the cells belonging to the given zone. Empty array if the zone id is unknown.
## Returned array is the live index entry — treat as read-only.
func get_cells_in_zone(zone_id: StringName) -> Array[Vector2i]:
	if _cells_by_zone.has(zone_id):
		return _cells_by_zone[zone_id]
	var empty : Array[Vector2i] = []
	return empty

func _index_rect(zone: ZoneRegion) -> void:
	var r : Rect2i = zone.shape_rect
	for y in r.size.y:
		for x in r.size.x:
			_index_cell(Vector2i(r.position.x + x, r.position.y + y), zone.id)

func _index_cell_list(zone: ZoneRegion) -> void:
	for cell in zone.shape_cells:
		_index_cell(cell, zone.id)

func _index_cell(cell: Vector2i, zone_id: StringName) -> void:
	if cell.x < 0 or cell.x >= dimensions.x or cell.y < 0 or cell.y >= dimensions.y:
		return
	if not _zones_by_cell.has(cell):
		var fresh_zones : Array[StringName] = []
		_zones_by_cell[cell] = fresh_zones
	var zones_here : Array[StringName] = _zones_by_cell[cell]
	if not zone_id in zones_here:
		zones_here.append(zone_id)
	var cells_for_zone : Array[Vector2i] = _cells_by_zone[zone_id]
	if not cell in cells_for_zone:
		cells_for_zone.append(cell)

## -- Spawn point API --
## Spawn points are the source of truth for enemy spawn locations after Phase 4
## (replacing the legacy SPAWN_W/N/S/E cell type values). Cells at spawn positions
## are normal PATH cells in the cell_types array; "is this cell a spawn?" must be
## answered by consulting MapData, not by inspecting cell type.

## Returns the SpawnPoint at the given cell, or null if no spawn is there.
## O(spawn_count); typically ≤ 4 entries.
func get_spawn_at(cell: Vector2i) -> SpawnPoint:
	for sp in spawn_points:
		if sp != null and sp.position == cell:
			return sp
	return null

## Convenience boolean form of get_spawn_at().
func is_spawn_at(cell: Vector2i) -> bool:
	return get_spawn_at(cell) != null

## Returns the SpawnPoint with the given id, or null.
func get_spawn_by_id(id: StringName) -> SpawnPoint:
	for sp in spawn_points:
		if sp != null and sp.id == id:
			return sp
	return null

## Returns cell positions of every spawn currently in ACTIVE state.
## Used by WaveSpawner each spawn cycle and by MapGrid for connectivity checks.
func get_active_spawn_cells() -> Array[Vector2i]:
	var out : Array[Vector2i] = []
	for sp in spawn_points:
		if sp != null and sp.state == SpawnPoint.SpawnState.ACTIVE:
			out.append(sp.position)
	return out

## Returns the full SpawnPoint objects for every ACTIVE spawn.
## Preferred over get_active_spawn_cells() when id or axis metadata is needed.
func get_active_spawn_points() -> Array[SpawnPoint]:
	var out : Array[SpawnPoint] = []
	for sp in spawn_points:
		if sp != null and sp.state == SpawnPoint.SpawnState.ACTIVE:
			out.append(sp)
	return out

## Flips a DORMANT spawn to ACTIVE by id. Returns true if found and transitioned.
## Phase 4 manual activation hook; Phase 5+ will drive state from objective evaluator.
## SEALED / PERMANENTLY_SEALED spawns are not re-activated by this method.
func activate_spawn_by_id(id: StringName) -> bool:
	var sp : SpawnPoint = get_spawn_by_id(id)
	if sp == null:
		return false
	if sp.state == SpawnPoint.SpawnState.DORMANT:
		sp.state = SpawnPoint.SpawnState.ACTIVE
		return true
	return false

## Flips an ACTIVE spawn back to DORMANT by id. Returns true if found and transitioned.
## Phase 4 manual hook; future phases derive state from objective lapses.
func deactivate_spawn_by_id(id: StringName) -> bool:
	var sp : SpawnPoint = get_spawn_by_id(id)
	if sp == null:
		return false
	if sp.state == SpawnPoint.SpawnState.ACTIVE:
		sp.state = SpawnPoint.SpawnState.DORMANT
		return true
	return false

## -- Objective resolution (Phase 5+) --

## Returns the active objective list for the given (faction, sub_path) pair.
## Keys in objectives_by_faction_subpath follow the form "faction_id:sub_path_id".
## Returns an empty array if no list is authored for that combination.
func get_objectives_for(faction_id: String, sub_path: String) -> Array[ObjectiveData]:
	var key : String = "%s:%s" % [faction_id, sub_path]
	if not objectives_by_faction_subpath.has(key):
		var empty : Array[ObjectiveData] = []
		return empty
	## Dictionary values are stored as untyped Array; rebuild as typed Array[ObjectiveData].
	var raw : Array = objectives_by_faction_subpath[key]
	var typed : Array[ObjectiveData] = []
	for entry in raw:
		if entry is ObjectiveData:
			typed.append(entry)
	return typed

## -- SupportGraph + Ancient path API (Phase 7+) --

## Returns every ancient PathEdge currently undiscovered. Used by the fog-reveal
## subsystem to test for discovery on region_revealed events.
func get_undiscovered_ancient_edges() -> Array[PathEdge]:
	var out : Array[PathEdge] = []
	if support_graph == null:
		return out
	for edge in support_graph.edges:
		if edge == null:
			continue
		if edge.kind == PathEdge.PathEdgeKind.ANCIENT and not edge.discovered:
			out.append(edge)
	return out

## Returns the PathEdge with the given id, or null. O(N) on edge count.
func get_path_edge_by_id(edge_id: StringName) -> PathEdge:
	if support_graph == null:
		return null
	for edge in support_graph.edges:
		if edge != null and edge.id == edge_id:
			return edge
	return null

## --

## Walks the given objective list and populates each spawn's seal_condition_refs by
## scanning ObjectiveData.seals (the authoritative side of the relationship per §2.7a).
## Should be called once after objectives are resolved for the active player.
## Idempotent: re-running on the same list rebuilds refs from scratch.
func resolve_spawn_seal_refs(active_objectives: Array[ObjectiveData]) -> void:
	## Clear existing refs on every spawn (idempotent rebuild).
	for sp in spawn_points:
		if sp != null:
			sp.seal_condition_refs = []
	## For each objective, add its id to every spawn it claims to seal.
	for obj in active_objectives:
		if obj == null:
			continue
		for spawn_id in obj.seals:
			var sp : SpawnPoint = get_spawn_by_id(spawn_id)
			if sp != null and not obj.objective_id in sp.seal_condition_refs:
				sp.seal_condition_refs.append(obj.objective_id)

## -- Meta bitfield accessors --
## All public accessors take cell_idx = col + row * dimensions.x.

func get_meta_revealed(cell_idx: int) -> bool:
	return _get_field(cell_idx, META_BIT_REVEALED, META_MASK_REVEALED) != 0

func set_meta_revealed(cell_idx: int, value: bool) -> void:
	_set_field(cell_idx, META_BIT_REVEALED, META_MASK_REVEALED, 1 if value else 0)

func get_meta_claimed_by(cell_idx: int) -> int:
	return _get_field(cell_idx, META_BIT_CLAIMED_BY, META_MASK_CLAIMED_BY)

func set_meta_claimed_by(cell_idx: int, faction_id: int) -> void:
	_set_field(cell_idx, META_BIT_CLAIMED_BY, META_MASK_CLAIMED_BY, faction_id)

func get_meta_biomass_progress(cell_idx: int) -> int:
	return _get_field(cell_idx, META_BIT_BIOMASS_PROGRESS, META_MASK_BIOMASS_PROGRESS)

func set_meta_biomass_progress(cell_idx: int, value: int) -> void:
	_set_field(cell_idx, META_BIT_BIOMASS_PROGRESS, META_MASK_BIOMASS_PROGRESS, value)

func get_meta_hacked_until_tick(cell_idx: int) -> int:
	return _get_field(cell_idx, META_BIT_HACKED_UNTIL_TICK, META_MASK_HACKED_UNTIL_TICK)

func set_meta_hacked_until_tick(cell_idx: int, tick: int) -> void:
	_set_field(cell_idx, META_BIT_HACKED_UNTIL_TICK, META_MASK_HACKED_UNTIL_TICK, tick)

func get_meta_ruins_proximity(cell_idx: int) -> int:
	return _get_field(cell_idx, META_BIT_RUINS_PROXIMITY, META_MASK_RUINS_PROXIMITY)

func set_meta_ruins_proximity(cell_idx: int, value: int) -> void:
	_set_field(cell_idx, META_BIT_RUINS_PROXIMITY, META_MASK_RUINS_PROXIMITY, value)

func get_meta_relay_covered(cell_idx: int) -> bool:
	return _get_field(cell_idx, META_BIT_RELAY_COVERED, META_MASK_RELAY_COVERED) != 0

func set_meta_relay_covered(cell_idx: int, value: bool) -> void:
	_set_field(cell_idx, META_BIT_RELAY_COVERED, META_MASK_RELAY_COVERED, 1 if value else 0)

func get_meta_sensed(cell_idx: int) -> bool:
	return _get_field(cell_idx, META_BIT_SENSED, META_MASK_SENSED) != 0

func set_meta_sensed(cell_idx: int, value: bool) -> void:
	_set_field(cell_idx, META_BIT_SENSED, META_MASK_SENSED, 1 if value else 0)

## -- Private bitfield helpers --

func _byte_offset(cell_idx: int) -> int:
	return cell_idx * META_STRIDE

func _read_u32(cell_idx: int) -> int:
	var b : int = _byte_offset(cell_idx)
	if b + 3 >= meta.size():
		return 0
	return meta[b] | (meta[b + 1] << 8) | (meta[b + 2] << 16) | (meta[b + 3] << 24)

func _write_u32(cell_idx: int, value: int) -> void:
	var b : int = _byte_offset(cell_idx)
	if b + 3 >= meta.size():
		return
	meta[b]     = value & 0xFF
	meta[b + 1] = (value >> 8)  & 0xFF
	meta[b + 2] = (value >> 16) & 0xFF
	meta[b + 3] = (value >> 24) & 0xFF

func _get_field(cell_idx: int, bit: int, mask: int) -> int:
	return (_read_u32(cell_idx) >> bit) & mask

func _set_field(cell_idx: int, bit: int, mask: int, value: int) -> void:
	var u : int = _read_u32(cell_idx)
	u = (u & ~(mask << bit)) | ((value & mask) << bit)
	_write_u32(cell_idx, u)
