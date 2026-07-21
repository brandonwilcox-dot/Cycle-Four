## TerrainProps.gd — E1 rock outcrops (environment-skinning-plan.md). A seeded MultiMesh
## scatter of low-poly rocks over HIGH open ground: never on paths/spawns/base/claimed,
## never in water, and FOG-GATED (unrevealed rocks are zero-scaled so the unknown stays
## unknown). Rebuilt per territory (seed change); visibility refreshed with the map.
## Purely cosmetic — no collision, no pathing impact. Per convention, callers PRELOAD this.
extends Node3D

const COUNT        : int = 90        ## placement attempts (real count lands lower)
const SIZE_MIN     : float = 10.0
const SIZE_MAX     : float = 30.0
const HEIGHT_BAND  : float = 0.045   ## how far above water level ground must be
## Forest/jungle pass (2026-07-20): denser canopy, clustered into groves so trees form
## navigable boundaries between clearings (open plains are now the exception).
const GRASS_FIELD_DENSITY : float = 1.90
const GRASS_PATCH_DENSITY : float = 1.60
const BUSH_DENSITY        : float = 3.20
const TREE_DENSITY        : float = 3.60
## Grove clustering: trees/bushes favour cells where this coarse field is high, leaving
## the rest as clearings. FREQ/LEVEL mirror MapGrid.FOREST_* so the visual canopy lines
## up with the concealment mask (dense trees == reduced vision there).
const GROVE_FREQ  : float = 0.010
const GROVE_LEVEL : float = 0.50
const ROCK_COLOR   : Color = Color(0.82, 0.80, 0.78)
const ROCK_ALBEDO  : Texture2D = preload("res://assets/textures/ground/aerial_rocks_02_diff.jpg")
const ROCK_NORMAL  : Texture2D = preload("res://assets/textures/ground/aerial_rocks_02_nor.jpg")
const ROCK_ROUGH   : Texture2D = preload("res://assets/textures/ground/aerial_rocks_02_rough.jpg")
const FLORA_SHADER := preload("res://assets/shaders/biome_flora.gdshader")
const FLORA_STYLES := [
	{"grass_fields": 30, "grass_per_field": 15, "bush_attempts": 170, "tree_attempts": 115,
		"base": Color(0.08, 0.25, 0.055), "tip": Color(0.44, 0.72, 0.18),
		"bush_base": Color(0.055, 0.20, 0.045), "bush_tip": Color(0.30, 0.58, 0.12),
		"tree_base": Color(0.035, 0.15, 0.035), "tree_tip": Color(0.24, 0.52, 0.10),
		"trunk": Color(0.20, 0.115, 0.055), "emission": Color(0.0, 0.0, 0.0),
		"energy": 0.0, "roughness": 0.92, "wind": 0.14,
		"grass_min_h": 7.0, "grass_max_h": 14.0, "bush_min_h": 13.0, "bush_max_h": 27.0,
		"tree_min_h": 46.0, "tree_max_h": 78.0, "min_relief": 0.012, "max_relief": 0.19},
	{"grass_fields": 17, "grass_per_field": 12, "bush_attempts": 115, "tree_attempts": 65,
		"base": Color(0.20, 0.17, 0.11), "tip": Color(0.50, 0.40, 0.21),
		"bush_base": Color(0.17, 0.15, 0.10), "bush_tip": Color(0.38, 0.33, 0.19),
		"tree_base": Color(0.13, 0.14, 0.11), "tree_tip": Color(0.31, 0.32, 0.23),
		"trunk": Color(0.17, 0.13, 0.095), "emission": Color(0.0, 0.0, 0.0),
		"energy": 0.0, "roughness": 0.98, "wind": 0.085,
		"grass_min_h": 6.0, "grass_max_h": 12.0, "bush_min_h": 11.0, "bush_max_h": 23.0,
		"tree_min_h": 38.0, "tree_max_h": 66.0, "min_relief": 0.022, "max_relief": 0.22},
	{"grass_fields": 16, "grass_per_field": 12, "bush_attempts": 90, "tree_attempts": 52,
		"base": Color(0.12, 0.25, 0.46), "tip": Color(0.52, 0.82, 1.0),
		"bush_base": Color(0.10, 0.22, 0.42), "bush_tip": Color(0.40, 0.70, 1.0),
		"tree_base": Color(0.08, 0.18, 0.38), "tree_tip": Color(0.46, 0.76, 1.0),
		"trunk": Color(0.10, 0.15, 0.25), "emission": Color(0.18, 0.48, 1.0),
		"energy": 0.38, "roughness": 0.28, "wind": 0.035,
		"grass_min_h": 9.0, "grass_max_h": 17.0, "bush_min_h": 15.0, "bush_max_h": 30.0,
		"tree_min_h": 50.0, "tree_max_h": 82.0, "min_relief": 0.045, "max_relief": 0.29},
	{"grass_fields": 21, "grass_per_field": 13, "bush_attempts": 145, "tree_attempts": 80,
		"base": Color(0.25, 0.095, 0.03), "tip": Color(0.72, 0.34, 0.075),
		"bush_base": Color(0.20, 0.07, 0.025), "bush_tip": Color(0.56, 0.21, 0.055),
		"tree_base": Color(0.18, 0.055, 0.02), "tree_tip": Color(0.50, 0.18, 0.045),
		"trunk": Color(0.19, 0.075, 0.035), "emission": Color(0.34, 0.08, 0.02),
		"energy": 0.06, "roughness": 0.86, "wind": 0.08,
		"grass_min_h": 7.0, "grass_max_h": 14.0, "bush_min_h": 12.0, "bush_max_h": 25.0,
		"tree_min_h": 42.0, "tree_max_h": 72.0, "min_relief": 0.020, "max_relief": 0.21},
]

var _mmi        : MultiMeshInstance3D = null
var _mat        : StandardMaterial3D = null
var _seed       : int = -1
var _cells      : PackedInt32Array = []      ## owning cell index per rock
var _xforms     : Array[Transform3D] = []    ## full-size transforms (zero-scaled when fogged)
var _shown      : PackedByteArray = []
var _grid          : Node = null
var _flora_mmi     : MultiMeshInstance3D = null
var _flora_mat     : ShaderMaterial = null
var _flora_cells   : PackedInt32Array = []
var _flora_xforms  : Array[Transform3D] = []
var _flora_shown   : PackedByteArray = []
var _bush_mmi      : MultiMeshInstance3D = null
var _bush_mat      : ShaderMaterial = null
var _bush_cells    : PackedInt32Array = []
var _bush_xforms   : Array[Transform3D] = []
var _bush_shown    : PackedByteArray = []
var _tree_mmi      : MultiMeshInstance3D = null
var _tree_mat      : ShaderMaterial = null
var _trunk_mat     : StandardMaterial3D = null
var _tree_cells    : PackedInt32Array = []
var _tree_xforms   : Array[Transform3D] = []
var _tree_shown    : PackedByteArray = []

## --- the shader's noise, replicated exactly (hash12/vnoise/fbm) so rocks sit on the
## same hills the ground shader displaces ------------------------------------------------
static func _hash12(p: Vector2) -> float:
	var p3 := Vector3(fposmod(p.x * 0.1031, 1.0), fposmod(p.y * 0.1031, 1.0), fposmod(p.x * 0.1031, 1.0))
	var d : float = p3.dot(Vector3(p3.y, p3.z, p3.x) + Vector3(33.33, 33.33, 33.33))
	p3 += Vector3(d, d, d)
	return fposmod((p3.x + p3.y) * p3.z, 1.0)

static func _vnoise(p: Vector2) -> float:
	var i := Vector2(floor(p.x), floor(p.y))
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	return lerpf(
		lerpf(_hash12(i), _hash12(i + Vector2(1, 0)), f.x),
		lerpf(_hash12(i + Vector2(0, 1)), _hash12(i + Vector2(1, 1)), f.x), f.y)

static func _fbm(p: Vector2) -> float:
	var v : float = 0.0
	var a : float = 0.5
	var q := p
	for k in 4:
		v += a * _vnoise(q)
		q = q * 2.13 + Vector2(17.7, 17.7)
		a *= 0.5
	return v

## Rebuild if the territory changed, else just re-gate visibility against the fog.
func sync(grid: Node, map_data) -> void:
	if map_data == null:
		return
	_grid = grid
	var mseed : int = int(map_data.map_seed)
	if mseed != _seed:
		_seed = mseed
		_rebuild(grid, map_data)
	_update_visibility(map_data)

func _rebuild(grid: Node, map_data) -> void:
	if _mmi != null:
		_mmi.queue_free()
		_mmi = null
	if _flora_mmi != null:
		_flora_mmi.queue_free()
		_flora_mmi = null
	_cells.clear(); _xforms.clear(); _shown = PackedByteArray()
	if _bush_mmi != null:
		_bush_mmi.queue_free()
		_bush_mmi = null
	if _tree_mmi != null:
		_tree_mmi.queue_free()
		_tree_mmi = null
	_bush_cells.clear(); _bush_xforms.clear(); _bush_shown = PackedByteArray()
	_tree_cells.clear(); _tree_xforms.clear(); _tree_shown = PackedByteArray()
	_flora_cells.clear(); _flora_xforms.clear(); _flora_shown = PackedByteArray()
	var cols : int = grid.COLS
	var rows : int = grid.ROWS
	var csize : float = float(grid.CELL_SIZE)
	var tseed : float = float(_seed % 4096)
	var water_level : float = 0.40   ## F1: matches MapGrid.WATER_LEVEL / shader
	var amp : float = 21.0 * 3.0
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 31 + 7

	var spawn_cells : Dictionary = {}
	for sp in map_data.spawn_points:
		if sp != null:
			spawn_cells[int(sp.position.x + sp.position.y * cols)] = true

	var placed : Array[Transform3D] = []
	var colors : Array[Color] = []
	for attempt in COUNT:
		var col : int = rng.randi_range(1, cols - 2)
		var row : int = rng.randi_range(1, rows - 2)
		var i : int = col + row * cols
		if spawn_cells.has(i):
			continue
		var kind : int = grid._cells[i]
		if kind != grid.Cell.GROUND and kind != grid.Cell.CLAIMED:
			continue   ## natural ground keeps its dressing after exploration/claiming
		var wx : float = (float(col) + rng.randf_range(0.2, 0.8)) * csize
		var wz : float = (float(row) + rng.randf_range(0.2, 0.8)) * csize
		var hn : float = _fbm(Vector2(wx, wz) * 0.006 + Vector2(tseed, tseed))
		var relief : float = hn - water_level
		if relief < HEIGHT_BAND:
			continue   ## keep out of water + shoreline; rocks live on the high ground
		var y : float = relief * relief * amp
		var s : float = rng.randf_range(SIZE_MIN, SIZE_MAX) * (1.0 + relief * 1.2)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15)))
		b = b.scaled(Vector3(s * rng.randf_range(0.8, 1.4), s * rng.randf_range(0.5, 0.8), s * rng.randf_range(0.8, 1.4)))
		placed.append(Transform3D(b, Vector3(wx, y, wz)))
		var tint : float = rng.randf_range(0.82, 1.08)
		colors.append(Color(tint * rng.randf_range(0.96, 1.04), tint, tint * rng.randf_range(0.94, 1.03), 1.0))
		_cells.append(i)

	_build_rocks(placed, colors)
	_build_vegetation(grid, spawn_cells, tseed, water_level, amp)

func _build_rocks(placed: Array[Transform3D], colors: Array[Color]) -> void:
	if placed.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.6
	mesh.radial_segments = 7
	mesh.rings = 4
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = ROCK_COLOR
		_mat.albedo_texture = ROCK_ALBEDO
		_mat.roughness = 1.0
		_mat.roughness_texture = ROCK_ROUGH
		_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		_mat.metallic = 0.02
		_mat.normal_enabled = true
		_mat.normal_texture = ROCK_NORMAL
		_mat.normal_scale = 0.78
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mat.uv1_scale = Vector3(1.35, 1.35, 1.35)
		_mat.vertex_color_use_as_albedo = true
	mesh.material = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = placed.size()
	_xforms.assign(placed)
	_shown.resize(placed.size())
	for k in placed.size():
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), placed[k].origin))
		mm.set_instance_color(k, colors[k])
		_shown[k] = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "RockOutcrops"
	_mmi.multimesh = mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mmi)

static func _is_natural_cell(grid: Node, cell: int) -> bool:
	var kind : int = grid._cells[cell]
	return kind == grid.Cell.GROUND or kind == grid.Cell.CLAIMED

static func _has_natural_clearance(grid: Node, col: int, row: int,
		spawn_cells: Dictionary, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c : int = col + dx
			var r : int = row + dy
			if c < 0 or c >= grid.COLS or r < 0 or r >= grid.ROWS:
				return false
			var cell : int = c + r * grid.COLS
			if spawn_cells.has(cell) or not _is_natural_cell(grid, cell):
				return false
	return true

static func _make_grass_field_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81931
	for blade in 44:
		var center := Vector3(rng.randf_range(-0.48, 0.48), 0.0, rng.randf_range(-0.48, 0.48))
		var height : float = rng.randf_range(0.52, 1.0)
		var angle : float = rng.randf() * TAU
		var right := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.022, 0.040)
		var lean := Vector3(-sin(angle), 0.0, cos(angle)) * rng.randf_range(0.12, 0.27)
		var p0 : Vector3 = center - right
		var p1 : Vector3 = center + right
		var p2 : Vector3 = center + Vector3.UP * height * 0.55 + lean * 0.38 + right * 0.55
		var p3 : Vector3 = center + Vector3.UP * height * 0.55 + lean * 0.38 - right * 0.55
		var p4 : Vector3 = center + Vector3.UP * height + lean
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p1)
		st.set_uv(Vector2(1.0, 0.55)); st.add_vertex(p2)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 0.55)); st.add_vertex(p2)
		st.set_uv(Vector2(0.0, 0.55)); st.add_vertex(p3)
		st.set_uv(Vector2(0.0, 0.55)); st.add_vertex(p3)
		st.set_uv(Vector2(1.0, 0.55)); st.add_vertex(p2)
		st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(p4)
	st.generate_normals()
	return st.commit()

static func _make_bush_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var lobes : Array = [
		[Vector3(0.0, 0.34, 0.0), Vector3(0.78, 0.64, 0.72)],
		[Vector3(-0.28, 0.27, 0.05), Vector3(0.52, 0.48, 0.55)],
		[Vector3(0.27, 0.28, 0.08), Vector3(0.56, 0.52, 0.50)],
		[Vector3(-0.05, 0.24, -0.27), Vector3(0.57, 0.46, 0.52)],
		[Vector3(0.09, 0.52, -0.03), Vector3(0.48, 0.46, 0.46)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lobe in lobes:
		var xform := Transform3D(Basis().scaled(lobe[1]), lobe[0])
		st.append_from(sphere, 0, xform)
	st.generate_normals()
	return st.commit()

static func _make_tree_mesh() -> ArrayMesh:
	var tree := ArrayMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.34
	trunk.bottom_radius = 0.62
	trunk.height = 1.0
	trunk.radial_segments = 7
	trunk.rings = 1
	var trunk_st := SurfaceTool.new()
	trunk_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	trunk_st.append_from(trunk, 0,
		Transform3D(Basis().scaled(Vector3(0.13, 0.66, 0.13)), Vector3(0.0, 0.33, 0.0)))
	trunk_st.generate_normals()
	trunk_st.commit(tree)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var crowns : Array = [
		[Vector3(0.0, 0.67, 0.0), Vector3(0.92, 0.52, 0.86)],
		[Vector3(-0.27, 0.72, 0.04), Vector3(0.58, 0.44, 0.60)],
		[Vector3(0.27, 0.73, 0.07), Vector3(0.60, 0.46, 0.55)],
		[Vector3(-0.04, 0.76, -0.27), Vector3(0.62, 0.46, 0.58)],
		[Vector3(0.06, 0.90, 0.0), Vector3(0.52, 0.38, 0.50)],
	]
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for crown in crowns:
		var xform := Transform3D(Basis().scaled(crown[1]), crown[0])
		leaf_st.append_from(sphere, 0, xform)
	leaf_st.generate_normals()
	leaf_st.commit(tree)
	return tree

func _make_flora_material(style: Dictionary, base_key: String, tip_key: String,
		wind_scale: float, energy_scale: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FLORA_SHADER
	mat.set_shader_parameter("base_color", style[base_key])
	mat.set_shader_parameter("tip_color", style[tip_key])
	mat.set_shader_parameter("emission_color", style["emission"])
	mat.set_shader_parameter("emission_strength", float(style["energy"]) * energy_scale)
	mat.set_shader_parameter("roughness_value", style["roughness"])
	mat.set_shader_parameter("wind_strength", float(style["wind"]) * wind_scale)
	return mat

func _create_vegetation_layer(layer_name: String, mesh: Mesh,
		placed: Array[Transform3D], colors: Array[Color], cols: int, rows: int,
		csize: float, max_height: float, casts_shadow: bool) -> MultiMeshInstance3D:
	if placed.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = placed.size()
	mm.custom_aabb = AABB(Vector3(0.0, -2.0, 0.0),
		Vector3(float(cols) * csize, max_height + 16.0, float(rows) * csize))
	for k in placed.size():
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), placed[k].origin))
		mm.set_instance_color(k, colors[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = layer_name
	mmi.multimesh = mm
	mmi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	add_child(mmi)
	return mmi

func _build_vegetation(grid: Node, spawn_cells: Dictionary, tseed: float,
		water_level: float, amp: float) -> void:
	var biome_index : int = (_seed >> 4) % FLORA_STYLES.size()
	if biome_index < 0:
		biome_index += FLORA_STYLES.size()
	var style : Dictionary = FLORA_STYLES[biome_index]
	var cols : int = grid.COLS
	var rows : int = grid.ROWS
	var csize : float = float(grid.CELL_SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 73 + 19

	var grass_placed : Array[Transform3D] = []
	var grass_colors : Array[Color] = []
	var field_target : int = int(round(float(style["grass_fields"]) * GRASS_FIELD_DENSITY))
	var fields_placed : int = 0
	for field_try in field_target * 6:
		if fields_placed >= field_target:
			break
		var center_col : int = rng.randi_range(2, cols - 3)
		var center_row : int = rng.randi_range(2, rows - 3)
		var center_cell : int = center_col + center_row * cols
		if spawn_cells.has(center_cell) or not _is_natural_cell(grid, center_cell):
			continue
		var center_x : float = (float(center_col) + rng.randf_range(0.30, 0.70)) * csize
		var center_z : float = (float(center_row) + rng.randf_range(0.30, 0.70)) * csize
		var center_hn : float = _fbm(Vector2(center_x, center_z) * 0.006 + Vector2(tseed, tseed))
		var center_relief : float = center_hn - water_level
		if center_relief < float(style["min_relief"]) or center_relief > float(style["max_relief"]):
			continue
		fields_placed += 1
		var patch_count : int = maxi(8,
			int(round(float(style["grass_per_field"]) * GRASS_PATCH_DENSITY)) + rng.randi_range(-4, 6))
		var field_radius : float = csize * rng.randf_range(0.58, 1.45)
		for patch in patch_count:
			var angle : float = rng.randf() * TAU
			var distance_from_center : float = sqrt(rng.randf()) * field_radius
			var wx : float = center_x + cos(angle) * distance_from_center
			var wz : float = center_z + sin(angle) * distance_from_center
			var col : int = int(floor(wx / csize))
			var row : int = int(floor(wz / csize))
			if col < 1 or col >= cols - 1 or row < 1 or row >= rows - 1:
				continue
			var cell : int = col + row * cols
			if spawn_cells.has(cell) or not _is_natural_cell(grid, cell):
				continue
			var hn : float = _fbm(Vector2(wx, wz) * 0.006 + Vector2(tseed, tseed))
			var relief : float = hn - water_level
			if relief < float(style["min_relief"]) or relief > float(style["max_relief"]):
				continue
			var height : float = rng.randf_range(float(style["grass_min_h"]), float(style["grass_max_h"]))
			var width : float = csize * rng.randf_range(0.28, 0.48)
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			basis = basis.scaled(Vector3(width, height, width))
			grass_placed.append(Transform3D(basis, Vector3(wx, relief * relief * amp + 0.20, wz)))
			var tint : float = rng.randf_range(0.78, 1.18)
			grass_colors.append(Color(tint * rng.randf_range(0.92, 1.05), tint,
				tint * rng.randf_range(0.86, 1.05), 1.0))
			_flora_cells.append(cell)

	var bush_placed : Array[Transform3D] = []
	var bush_colors : Array[Color] = []
	for bush_try in int(round(float(style["bush_attempts"]) * BUSH_DENSITY)):
		var col : int = rng.randi_range(1, cols - 2)
		var row : int = rng.randi_range(1, rows - 2)
		var cell : int = col + row * cols
		if spawn_cells.has(cell) or not _is_natural_cell(grid, cell):
			continue
		var wx : float = (float(col) + rng.randf_range(0.20, 0.80)) * csize
		var wz : float = (float(row) + rng.randf_range(0.20, 0.80)) * csize
		var hn : float = _fbm(Vector2(wx, wz) * 0.006 + Vector2(tseed, tseed))
		var relief : float = hn - water_level
		if relief < float(style["min_relief"]) or relief > float(style["max_relief"]):
			continue
		var height : float = rng.randf_range(float(style["bush_min_h"]), float(style["bush_max_h"]))
		var width : float = height * rng.randf_range(1.10, 1.55)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(width, height, width))
		bush_placed.append(Transform3D(basis, Vector3(wx, relief * relief * amp + 0.18, wz)))
		var tint : float = rng.randf_range(0.78, 1.16)
		bush_colors.append(Color(tint * rng.randf_range(0.92, 1.05), tint,
			tint * rng.randf_range(0.88, 1.04), 1.0))
		_bush_cells.append(cell)

	var tree_placed : Array[Transform3D] = []
	var tree_colors : Array[Color] = []
	var tree_taken : Dictionary = {}
	for tree_try in int(round(float(style["tree_attempts"]) * TREE_DENSITY)):
		var col : int = rng.randi_range(2, cols - 3)
		var row : int = rng.randi_range(2, rows - 3)
		## natural cell + no water/path neighbour (radius 1) — trees ring clearings, not water
		if not _has_natural_clearance(grid, col, row, spawn_cells, 1):
			continue
		## Grove clustering: high grove noise packs a dense canopy (multiple trees per cell
		## allowed); low grove is a clearing (mostly rejected). Groves become the boundaries.
		var gx : float = (float(col) + 0.5) * csize
		var gz : float = (float(row) + 0.5) * csize
		var grove : float = _fbm(Vector2(gx, gz) * GROVE_FREQ + Vector2(tseed + 91.3, tseed - 47.1))
		var grove_w : float = clampf((grove - GROVE_LEVEL) / (1.0 - GROVE_LEVEL), 0.0, 1.0)
		if rng.randf() > 0.12 + grove_w * grove_w:
			continue   ## sparse in the open, thick in the grove
		var cell : int = col + row * cols
		var stack : int = tree_taken.get(cell, 0)
		if stack >= 1 + int(round(grove_w * 2.0)):
			continue   ## up to 3 trees/cell at grove core, 1 in light woods
		var wx : float = (float(col) + rng.randf_range(0.18, 0.82)) * csize
		var wz : float = (float(row) + rng.randf_range(0.18, 0.82)) * csize
		var hn : float = _fbm(Vector2(wx, wz) * 0.006 + Vector2(tseed, tseed))
		var relief : float = hn - water_level
		if relief < float(style["min_relief"]) or relief > float(style["max_relief"]):
			continue
		tree_taken[cell] = stack + 1
		var height : float = rng.randf_range(float(style["tree_min_h"]), float(style["tree_max_h"]))
		var width : float = height * rng.randf_range(0.42, 0.60)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(width, height, width))
		tree_placed.append(Transform3D(basis, Vector3(wx, relief * relief * amp + 0.12, wz)))
		var tint : float = rng.randf_range(0.82, 1.14)
		tree_colors.append(Color(tint * rng.randf_range(0.94, 1.04), tint,
			tint * rng.randf_range(0.90, 1.05), 1.0))
		_tree_cells.append(cell)

	_flora_mat = _make_flora_material(style, "base", "tip", 1.0, 1.0)
	_bush_mat = _make_flora_material(style, "bush_base", "bush_tip", 0.36, 0.55)
	_tree_mat = _make_flora_material(style, "tree_base", "tree_tip", 0.16, 0.65)
	_trunk_mat = StandardMaterial3D.new()
	_trunk_mat.albedo_color = style["trunk"]
	_trunk_mat.roughness = 0.98
	var grass_mesh := _make_grass_field_mesh()
	grass_mesh.surface_set_material(0, _flora_mat)
	var bush_mesh := _make_bush_mesh()
	bush_mesh.surface_set_material(0, _bush_mat)
	var tree_mesh := _make_tree_mesh()
	tree_mesh.surface_set_material(0, _trunk_mat)
	tree_mesh.surface_set_material(1, _tree_mat)

	_flora_xforms.assign(grass_placed)
	_flora_shown.resize(grass_placed.size())
	_flora_shown.fill(0)
	_flora_mmi = _create_vegetation_layer("GrassFields", grass_mesh, grass_placed, grass_colors,
		cols, rows, csize, float(style["grass_max_h"]), false)
	_bush_xforms.assign(bush_placed)
	_bush_shown.resize(bush_placed.size())
	_bush_shown.fill(0)
	_bush_mmi = _create_vegetation_layer("BiomeBushes", bush_mesh, bush_placed, bush_colors,
		cols, rows, csize, float(style["bush_max_h"]), true)
	_tree_xforms.assign(tree_placed)
	_tree_shown.resize(tree_placed.size())
	_tree_shown.fill(0)
	_tree_mmi = _create_vegetation_layer("BiomeTrees", tree_mesh, tree_placed, tree_colors,
		cols, rows, csize, float(style["tree_max_h"]), true)

func _cell_is_visible(map_data, cell: int) -> bool:
	if _grid == null:
		return false
	var kind : int = _grid._cells[cell]
	return (map_data.get_meta_revealed(cell)
		and (kind == _grid.Cell.GROUND or kind == _grid.Cell.CLAIMED))

## Fog gate: natural props persist on revealed ground after it becomes claimed.
func _update_visibility(map_data) -> void:
	if _mmi != null:
		var rock_mm : MultiMesh = _mmi.multimesh
		for k in _cells.size():
			var want : int = 1 if _cell_is_visible(map_data, _cells[k]) else 0
			if want != _shown[k]:
				_shown[k] = want
				rock_mm.set_instance_transform(k, _xforms[k] if want == 1 else Transform3D(Basis().scaled(Vector3.ZERO), _xforms[k].origin))
	if _flora_mmi != null:
		var flora_mm : MultiMesh = _flora_mmi.multimesh
		for k in _flora_cells.size():
			var want : int = 1 if _cell_is_visible(map_data, _flora_cells[k]) else 0
			if want != _flora_shown[k]:
				_flora_shown[k] = want
				flora_mm.set_instance_transform(k, _flora_xforms[k] if want == 1 else Transform3D(Basis().scaled(Vector3.ZERO), _flora_xforms[k].origin))
	if _bush_mmi != null:
		var bush_mm : MultiMesh = _bush_mmi.multimesh
		for k in _bush_cells.size():
			var want : int = 1 if _cell_is_visible(map_data, _bush_cells[k]) else 0
			if want != _bush_shown[k]:
				_bush_shown[k] = want
				bush_mm.set_instance_transform(k, _bush_xforms[k] if want == 1 else Transform3D(Basis().scaled(Vector3.ZERO), _bush_xforms[k].origin))
	if _tree_mmi != null:
		var tree_mm : MultiMesh = _tree_mmi.multimesh
		for k in _tree_cells.size():
			var want : int = 1 if _cell_is_visible(map_data, _tree_cells[k]) else 0
			if want != _tree_shown[k]:
				_tree_shown[k] = want
				tree_mm.set_instance_transform(k, _tree_xforms[k] if want == 1 else Transform3D(Basis().scaled(Vector3.ZERO), _tree_xforms[k].origin))
