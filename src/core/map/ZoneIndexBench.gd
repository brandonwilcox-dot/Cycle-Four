## ZoneIndexBench.gd
## Phase 3 performance bench for MapData's cell→zone reverse index.
## Confirms 100k random cell lookups complete in sub-frame time (<16.67ms at 60 fps).
##
## Usage from any script (e.g. a debug autoload or test scene):
##     var result := ZoneIndexBench.run()
##     print(result)
##
## Returns a Dictionary with: query_count, elapsed_ms, avg_us_per_query, sub_frame_pass.
class_name ZoneIndexBench
extends RefCounted

const DEFAULT_QUERY_COUNT : int = 100000
const SUB_FRAME_BUDGET_US : int = 16667   ## ~16.67 ms = one frame at 60 fps.
const RNG_SEED            : int = 42      ## Deterministic across runs.

## Runs the benchmark and returns timing data.
static func run(query_count: int = DEFAULT_QUERY_COUNT) -> Dictionary:
	var data : MapData = _make_test_map()
	var queries : Array[Vector2i] = _generate_queries(data, query_count)

	var start_us : int = Time.get_ticks_usec()
	for q in queries:
		var _ignore : Array[StringName] = data.get_zones_at_cell(q)
	var elapsed_us : int = Time.get_ticks_usec() - start_us

	var result : Dictionary = {
		"query_count":      query_count,
		"elapsed_ms":       elapsed_us / 1000.0,
		"avg_us_per_query": float(elapsed_us) / float(query_count),
		"sub_frame_pass":   elapsed_us < SUB_FRAME_BUDGET_US,
		"zone_count":       data.zones.size(),
		"indexed_cells":    data._zones_by_cell.size(),
	}
	_print_summary(result)
	return result

## Builds a test MapData with five zones of varied shapes — three rect, two irregular.
## Coverage is intentionally varied so some queries hit, some miss, some hit multiply.
static func _make_test_map() -> MapData:
	var data := MapData.new()
	data.map_id    = &"zone_bench_test"
	data.dimensions = Vector2i(30, 17)
	data.init_arrays()

	var mineral := ZoneRegion.new()
	mineral.id = &"bench_mineral"
	mineral.kind = ZoneRegion.ZoneKind.MINERAL_VEIN
	mineral.shape_rect = Rect2i(2, 2, 6, 4)
	data.zones.append(mineral)

	var hazard := ZoneRegion.new()
	hazard.id = &"bench_hazard"
	hazard.kind = ZoneRegion.ZoneKind.HAZARD
	hazard.shape_rect = Rect2i(15, 6, 5, 5)
	data.zones.append(hazard)

	var control := ZoneRegion.new()
	control.id = &"bench_control_point"
	control.kind = ZoneRegion.ZoneKind.CONTROL_POINT
	control.shape_rect = Rect2i(22, 10, 4, 4)
	data.zones.append(control)

	## Irregular zone overlapping the hazard rect — tests multi-zone cell stacking.
	var crossing := ZoneRegion.new()
	crossing.id = &"bench_path_crossing"
	crossing.kind = ZoneRegion.ZoneKind.ANCIENT_PATH_CROSSING
	crossing.use_rect = false
	crossing.shape_cells = [
		Vector2i(16, 7), Vector2i(17, 7), Vector2i(18, 7),
		Vector2i(17, 8), Vector2i(17, 9),
	]
	data.zones.append(crossing)

	var ley := ZoneRegion.new()
	ley.id = &"bench_ley_cluster"
	ley.kind = ZoneRegion.ZoneKind.LEY_CLUSTER
	ley.use_rect = false
	ley.shape_cells = [
		Vector2i(5, 12), Vector2i(6, 12), Vector2i(7, 12),
		Vector2i(5, 13), Vector2i(6, 13), Vector2i(7, 13),
		Vector2i(6, 14),
	]
	data.zones.append(ley)

	data.build_zone_index()
	return data

static func _generate_queries(data: MapData, count: int) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNG_SEED
	var out : Array[Vector2i] = []
	out.resize(count)
	for i in count:
		out[i] = Vector2i(
			rng.randi_range(0, data.dimensions.x - 1),
			rng.randi_range(0, data.dimensions.y - 1)
		)
	return out

static func _print_summary(r: Dictionary) -> void:
	var verdict : String = "PASS" if r["sub_frame_pass"] else "FAIL"
	print("ZoneIndexBench [%s] %d queries -> %.3f ms total, %.3f us/query (zones=%d, indexed_cells=%d)" % [
		verdict,
		int(r["query_count"]),
		float(r["elapsed_ms"]),
		float(r["avg_us_per_query"]),
		int(r["zone_count"]),
		int(r["indexed_cells"]),
	])
