## DefaultMapBuilder.gd
## Constructs the hand-authored default MapData (30×17) that replicates the layout
## from MapGrid._build_default_paths(). This is the Phase 2 bridge resource.
## Phase 10 (procedural generator) will replace this for all maps except the tutorial.
class_name DefaultMapBuilder
extends RefCounted

## Local mirror of MapGrid.Cell enum values.
## Must stay in sync with MapGrid.Cell if those values ever change.
const _GROUND  : int = 0
const _PATH    : int = 2
const _BASE    : int = 3
const _SPAWN_W : int = 4
const _SPAWN_N : int = 5
const _SPAWN_S : int = 6
const _SPAWN_E : int = 7

const _COLS : int = 30
const _ROWS : int = 17

const _BASE_POS    := Vector2i(15, 8)
const _SPAWN_W_POS := Vector2i(0,  8)
const _SPAWN_N_POS := Vector2i(15, 0)
const _SPAWN_S_POS := Vector2i(15, 16)
const _SPAWN_E_POS := Vector2i(29, 8)

## Returns a fully initialised MapData matching the hardcoded default layout.
static func create() -> MapData:
	var data := MapData.new()
	data.map_id            = &"default"
	data.dimensions        = Vector2i(_COLS, _ROWS)
	data.biome             = &"temperate"
	data.topology_template = &"default_30x17"
	data.init_arrays()
	_build_paths(data)
	return data

## Ports every fill and stamp call from MapGrid._build_default_paths() into MapData.cell_types.
## Keep this function a 1-for-1 mirror of that function — if one changes, the other must too.
static func _build_paths(data: MapData) -> void:
	## West path: two-branch network between junction (4,8) and exit (13,8).
	_fill_h(data, 8,   0,  4,  _PATH)   ## entry: row 8 spawn to junction
	_fill_v(data, 4,   4,  12, _PATH)   ## junction vertical: col 4 rows 4-12
	_fill_h(data, 4,   4,  9,  _PATH)   ## branch A north: row 4 east
	_fill_v(data, 9,   4,  8,  _PATH)   ## branch A: col 9 south to exit row
	_fill_h(data, 8,   9,  13, _PATH)   ## branch A exit: row 8 east to (13,8)
	_fill_h(data, 12,  4,  13, _PATH)   ## branch B south: row 12 east
	_fill_v(data, 13,  8,  12, _PATH)   ## branch B: col 13 north to (13,8)
	_fill_h(data, 8,  13,  15, _PATH)   ## final approach: (13,8) to base

	## North path: jog from SPAWN_N down to row 8, merges into west branch A exit.
	_fill_v(data, 15,  0,  3,  _PATH)
	_fill_h(data, 3,  11,  15, _PATH)
	_fill_v(data, 11,  3,  8,  _PATH)
	_fill_h(data, 8,  11,  13, _PATH)   ## overlaps west branch A exit (same cells)

	## East path: two-branch mirror of west between junction (25,8) and exit (16,8).
	_fill_h(data, 8,  25,  29, _PATH)   ## entry: row 8 spawn to junction
	_fill_v(data, 25,  4,  12, _PATH)   ## junction vertical: col 25 rows 4-12
	_fill_h(data, 4,  20,  25, _PATH)   ## branch A north (mirror): row 4 west
	_fill_v(data, 20,  4,  8,  _PATH)   ## branch A: col 20 south to exit row
	_fill_h(data, 8,  16,  20, _PATH)   ## branch A exit: row 8 west to (16,8)
	_fill_h(data, 12, 16,  25, _PATH)   ## branch B south (mirror): row 12 west
	_fill_v(data, 16,  8,  12, _PATH)   ## branch B: col 16 north to (16,8)
	_fill_h(data, 8,  15,  16, _PATH)   ## east final approach to base

	## South path: jog from SPAWN_S up to row 8, merges into east exit corridor.
	_fill_v(data, 15, 13,  16, _PATH)
	_fill_h(data, 13, 15,  19, _PATH)
	_fill_v(data, 19,  8,  13, _PATH)
	_fill_h(data, 8,  15,  19, _PATH)

	## Stamp spawn and base markers last so they override any PATH written above.
	_set_raw(data, _SPAWN_W_POS.x, _SPAWN_W_POS.y, _SPAWN_W)
	_set_raw(data, _SPAWN_N_POS.x, _SPAWN_N_POS.y, _SPAWN_N)
	_set_raw(data, _SPAWN_S_POS.x, _SPAWN_S_POS.y, _SPAWN_S)
	_set_raw(data, _SPAWN_E_POS.x, _SPAWN_E_POS.y, _SPAWN_E)
	_set_raw(data, _BASE_POS.x,    _BASE_POS.y,    _BASE)

static func _set_raw(data: MapData, col: int, row: int, ctype: int) -> void:
	if col >= 0 and col < _COLS and row >= 0 and row < _ROWS:
		data.cell_types[col + row * _COLS] = ctype

static func _fill_h(data: MapData, row: int, col_a: int, col_b: int, ctype: int) -> void:
	var lo : int = min(col_a, col_b)
	var hi : int = max(col_a, col_b)
	for col in range(lo, hi + 1):
		_set_raw(data, col, row, ctype)

static func _fill_v(data: MapData, col: int, row_a: int, row_b: int, ctype: int) -> void:
	var lo : int = min(row_a, row_b)
	var hi : int = max(row_a, row_b)
	for row in range(lo, hi + 1):
		_set_raw(data, col, row, ctype)
