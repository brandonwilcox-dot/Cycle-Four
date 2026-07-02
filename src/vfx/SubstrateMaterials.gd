## SubstrateMaterials.gd — V3 of the visual plan (visual-supercharge-plan.md): the three canon
## substrates (codex/08 — the Mark's three circles) as material treatments for entity bodies.
##   architects — crystalline lattice: polished, engineered; amber seams glow along a lattice.
##   bloom      — biological fiber:   matte, alive; bioluminescent veins mottle the surface.
##   mesh       — conductive mesh:    near-black metal; electric-blue traces run the shell.
##
## Applied ON TOP of an entity's existing StandardMaterial3D (never replaces it), so every
## albedo-based mechanic keeps working untouched: damage tint, hijack cyan, pollen, spawn
## flash, and construction-ghost alpha all write albedo_color as before. Patterns are tiny
## code-generated emission textures (no asset pipeline), triplanar-mapped in object space so
## they wrap the procedural primitives uniformly. Bodies only — HP/build bars, rings, beams
## and the damage-type core gem stay clean (readability is inviolable, core/22).
##
## Per project convention (global class_name is unreliable), callers PRELOAD this script:
##   const SUBSTRATE = preload("res://src/vfx/SubstrateMaterials.gd")
##   SUBSTRATE.apply(mat, faction_id)
extends RefCounted

const TEX_SIZE : int = 64
const PATTERN_SEED : int = 74501   ## fixed — patterns must be identical every boot

static var _tex_cache : Dictionary = {}

## V4 motion: registered bloom/mesh materials are animated by tick() (called once per frame
## from BattleAtmosphere) — Bloom veins breathe, Mesh traces travel. Weak refs: materials die
## with their entities; dead (or pattern-stripped) entries are pruned during tick.
static var _anim_bloom : Array[WeakRef] = []
static var _anim_mesh  : Array[WeakRef] = []

## Configure `m` with the faction's substrate. Reads the albedo the caller already set and
## keeps it (mesh darkens toward near-black but keeps the hue). Unknown faction = no-op.
## animate=false for materials that drive their own emission (unit hit-flash owns it).
static func apply(m: StandardMaterial3D, faction_id: String, animate: bool = true) -> StandardMaterial3D:
	match faction_id:
		"architects":
			m.roughness = 0.22
			m.metallic = 0.30
			m.metallic_specular = 0.7
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.6
			_emit(m, _tex("seams"), Color(1.00, 0.82, 0.38), 0.9)
		"bloom":
			m.roughness = 0.90
			m.metallic = 0.0
			_emit(m, _tex("veins"), Color(0.45, 1.00, 0.50), 1.0)
			if animate:
				_anim_bloom.append(weakref(m))
		"mesh":
			m.roughness = 0.35
			m.metallic = 0.65
			m.albedo_color = m.albedo_color.darkened(0.30)
			_emit(m, _tex("circuit"), Color(0.35, 0.75, 1.00), 1.3)
			if animate:
				_anim_mesh.append(weakref(m))
	return m

## Drive the living substrates. Bloom bioluminescence breathes (slow, desynchronized —
## organic, quiet); Mesh circuit traces crawl along the shell (signal in transit).
static func tick(t: float) -> void:
	for i in range(_anim_bloom.size() - 1, -1, -1):
		var m : StandardMaterial3D = _anim_bloom[i].get_ref() as StandardMaterial3D
		if m == null or m.emission_texture == null:
			_anim_bloom.remove_at(i)   ## freed with its entity, or pattern-stripped (core gem)
			continue
		m.emission_energy_multiplier = 1.0 + 0.40 * sin(t * 1.5 + float(i) * 0.73)
	var scroll : float = t * 0.10   ## UV-repeat units/sec (~4.4 px/s of surface)
	for i in range(_anim_mesh.size() - 1, -1, -1):
		var m : StandardMaterial3D = _anim_mesh[i].get_ref() as StandardMaterial3D
		if m == null or m.emission_texture == null:
			_anim_mesh.remove_at(i)
			continue
		m.uv1_offset.x = scroll

static func _emit(m: StandardMaterial3D, tex: Texture2D, col: Color, energy: float) -> void:
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.emission_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * (1.0 / 44.0)   ## one pattern repeat ≈ 44 px of surface

## -- code-generated pattern textures (cached; deterministic via PATTERN_SEED) --

static func _tex(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var img : Image = Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	match kind:
		"seams":
			_gen_seams(img)
		"veins":
			_gen_veins(img)
		"circuit":
			_gen_circuit(img)
	var tex : ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[kind] = tex
	return tex

## Architects: a clean orthogonal lattice — two seams per repeat, hairline-soft edges.
static func _gen_seams(img: Image) -> void:
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var v : float = 0.0
			if x % 32 == 0 or y % 32 == 0:
				v = 1.0
			elif x % 32 == 1 or x % 32 == 31 or y % 32 == 1 or y % 32 == 31:
				v = 0.30
			img.set_pixel(x, y, Color(v, v, v))

## Bloom: blotchy bioluminescent veins from layered value noise; sparse bright nodes.
static func _gen_veins(img: Image) -> void:
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = PATTERN_SEED
	## Two octaves of bilinear value noise over coarse grids (wrap for tiling).
	var g1 : Array = _noise_grid(rng, 8)
	var g2 : Array = _noise_grid(rng, 16)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var n : float = _sample_grid(g1, 8, x, y) * 0.65 + _sample_grid(g2, 16, x, y) * 0.35
			var v : float = clampf((n - 0.58) / 0.10, 0.0, 1.0) * 0.75
			if n > 0.74:
				v = 1.0   ## bright node
			img.set_pixel(x, y, Color(v, v, v))

## Mesh: horizontal traces with sparse vertical connectors and junction nodes.
static func _gen_circuit(img: Image) -> void:
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = PATTERN_SEED + 1
	img.fill(Color.BLACK)
	var rows : Array[int] = [8, 24, 40, 56]
	for ry in rows:
		for x in TEX_SIZE:
			img.set_pixel(x, ry, Color(0.8, 0.8, 0.8))
	for i in rows.size():
		var y0 : int = rows[i]
		var y1 : int = rows[(i + 1) % rows.size()]
		for _c in 3:   ## three connectors per band
			var cx : int = rng.randi_range(0, TEX_SIZE - 1)
			var yy : int = y0
			while yy != y1:
				img.set_pixel(cx, yy, Color(0.8, 0.8, 0.8))
				yy = (yy + 1) % TEX_SIZE
			img.set_pixel(cx, y0, Color.WHITE)   ## junction nodes
			img.set_pixel(cx, y1, Color.WHITE)

static func _noise_grid(rng: RandomNumberGenerator, cells: int) -> Array:
	var g : Array = []
	for i in cells * cells:
		g.append(rng.randf())
	return g

## Bilinear sample of a wrapped coarse grid at texel (x, y) — tiles seamlessly.
static func _sample_grid(g: Array, cells: int, x: int, y: int) -> float:
	var fx : float = float(x) / float(TEX_SIZE) * cells
	var fy : float = float(y) / float(TEX_SIZE) * cells
	var x0 : int = int(fx) % cells
	var y0 : int = int(fy) % cells
	var x1 : int = (x0 + 1) % cells
	var y1 : int = (y0 + 1) % cells
	var tx : float = fx - floorf(fx)
	var ty : float = fy - floorf(fy)
	var a : float = lerpf(g[x0 + y0 * cells], g[x1 + y0 * cells], tx)
	var b : float = lerpf(g[x0 + y1 * cells], g[x1 + y1 * cells], tx)
	return lerpf(a, b, ty)
