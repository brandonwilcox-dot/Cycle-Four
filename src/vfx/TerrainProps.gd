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
const ROCK_COLOR   : Color = Color(0.82, 0.80, 0.78)
const ROCK_ALBEDO  : Texture2D = preload("res://assets/textures/ground/aerial_rocks_02_diff.jpg")
const ROCK_NORMAL  : Texture2D = preload("res://assets/textures/ground/aerial_rocks_02_nor.jpg")
const ROCK_ROUGH   : Texture2D = preload("res://assets/textures/ground/aerial_rocks_02_rough.jpg")
const FLORA_SHADER := preload("res://assets/shaders/biome_flora.gdshader")
const FLORA_STYLES := [
	{"attempts": 620, "base": Color(0.10, 0.30, 0.08), "tip": Color(0.48, 0.72, 0.22),
		"emission": Color(0.0, 0.0, 0.0), "energy": 0.0, "roughness": 0.92,
		"wind": 0.14, "min_h": 8.0, "max_h": 25.0, "min_relief": 0.015, "max_relief": 0.18},
	{"attempts": 360, "base": Color(0.24, 0.20, 0.14), "tip": Color(0.52, 0.42, 0.24),
		"emission": Color(0.0, 0.0, 0.0), "energy": 0.0, "roughness": 0.98,
		"wind": 0.09, "min_h": 7.0, "max_h": 20.0, "min_relief": 0.025, "max_relief": 0.22},
	{"attempts": 220, "base": Color(0.16, 0.28, 0.46), "tip": Color(0.60, 0.82, 1.0),
		"emission": Color(0.18, 0.48, 1.0), "energy": 0.42, "roughness": 0.24,
		"wind": 0.018, "min_h": 12.0, "max_h": 31.0, "min_relief": 0.055, "max_relief": 0.30},
	{"attempts": 420, "base": Color(0.30, 0.12, 0.045), "tip": Color(0.72, 0.36, 0.10),
		"emission": Color(0.34, 0.08, 0.02), "energy": 0.06, "roughness": 0.86,
		"wind": 0.08, "min_h": 8.0, "max_h": 22.0, "min_relief": 0.025, "max_relief": 0.20},
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
	_flora_cells.clear(); _flora_xforms.clear(); _flora_shown = PackedByteArray()
	var cols : int = grid.COLS
	var rows : int = grid.ROWS
	var csize : float = float(grid.CELL_SIZE)
	var tseed : float = float(_seed % 4096)
	var water_level : float = 0.34
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
	_build_flora(grid, map_data, spawn_cells, tseed, water_level, amp)

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

static func _make_flora_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var angle : float = float(blade) * TAU / 5.0
		var right := Vector3(cos(angle), 0.0, sin(angle)) * 0.38
		var lean := Vector3(-sin(angle), 0.0, cos(angle)) * 0.68
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(-right)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(right)
		st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(Vector3.UP + lean)
	st.generate_normals()
	return st.commit()

func _build_flora(grid: Node, map_data, spawn_cells: Dictionary, tseed: float,
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
	var placed : Array[Transform3D] = []
	var colors : Array[Color] = []
	for attempt in int(style["attempts"]):
		var col : int = rng.randi_range(1, cols - 2)
		var row : int = rng.randi_range(1, rows - 2)
		var i : int = col + row * cols
		var kind : int = grid._cells[i]
		if spawn_cells.has(i) or (kind != grid.Cell.GROUND and kind != grid.Cell.CLAIMED):
			continue
		var wx : float = (float(col) + rng.randf_range(0.15, 0.85)) * csize
		var wz : float = (float(row) + rng.randf_range(0.15, 0.85)) * csize
		var hn : float = _fbm(Vector2(wx, wz) * 0.006 + Vector2(tseed, tseed))
		var relief : float = hn - water_level
		if relief < float(style["min_relief"]) or relief > float(style["max_relief"]):
			continue
		var y : float = relief * relief * amp + 0.25
		var height : float = rng.randf_range(float(style["min_h"]), float(style["max_h"]))
		var width : float = height * rng.randf_range(0.07, 0.12)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.scaled(Vector3(width, height, width))
		placed.append(Transform3D(basis, Vector3(wx, y, wz)))
		var tint : float = rng.randf_range(0.84, 1.14)
		colors.append(Color(tint * rng.randf_range(0.94, 1.05), tint,
			tint * rng.randf_range(0.90, 1.06), 1.0))
		_flora_cells.append(i)
	if placed.is_empty():
		return
	_flora_mat = ShaderMaterial.new()
	_flora_mat.shader = FLORA_SHADER
	_flora_mat.set_shader_parameter("base_color", style["base"])
	_flora_mat.set_shader_parameter("tip_color", style["tip"])
	_flora_mat.set_shader_parameter("emission_color", style["emission"])
	_flora_mat.set_shader_parameter("emission_strength", style["energy"])
	_flora_mat.set_shader_parameter("roughness_value", style["roughness"])
	_flora_mat.set_shader_parameter("wind_strength", style["wind"])
	var mesh := _make_flora_mesh()
	mesh.surface_set_material(0, _flora_mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = placed.size()
	mm.custom_aabb = AABB(Vector3(0.0, -2.0, 0.0),
		Vector3(float(cols) * csize, float(style["max_h"]) + 12.0, float(rows) * csize))
	_flora_xforms.assign(placed)
	_flora_shown.resize(placed.size())
	for k in placed.size():
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), placed[k].origin))
		mm.set_instance_color(k, colors[k])
		_flora_shown[k] = 0
	_flora_mmi = MultiMeshInstance3D.new()
	_flora_mmi.name = "BiomeFlora"
	_flora_mmi.multimesh = mm
	_flora_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_flora_mmi)

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
