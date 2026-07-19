## Cosmetics.gd — unit customization data layer (core/15; user directive 2026-07-18).
## Part slots + color channels + variation presets per faction/unit, persisted to
## user://cosmetics.json (account-level: survives New Game / prestige / save wipes).
##
## DESIGN CONTRACT:
##   - Player-side only: FriendlyUnit + Commander (+ the FactionPreview customizer) read
##     this; enemy Unit NEVER does (threat readability stays stock).
##   - Everything in the customizer is available regardless of game state — the customizer
##     exists precisely to expose designs playtesting can't reach.
##   - Colors flow through the SAME albedo/emission channels SubstrateMaterials configures,
##     so damage-fade / hijack cyan / stealth alpha / hit-flash mechanics keep working.
##   - Parts are GLTF .glb files dropped into assets/models/parts/<faction>/<unit>/<slot>/.
##     "stock" (no file) keeps today's procedural / Rodin body piece. A non-stock TORSO
##     replaces the base body; every other slot attaches at its anchor.
##
## Per project convention callers PRELOAD this script:
##   const COSMETICS = preload("res://src/core/cosmetics/Cosmetics.gd")
extends RefCounted

const PROFILE_PATH : String = "user://cosmetics.json"
const PARTS_ROOT   : String = "res://assets/models/parts"
const STOCK        : String = "stock"

const FACTIONS : Array = ["architects", "bloom", "mesh"]
## v1 customizable units: the Commander + the T1 roster archetypes (an archetype restyles
## every unit sharing that body). Role ordinals from UnitData.role.
const UNITS : Array = ["commander", "line", "scout", "artillery"]
const _ROLE_TO_UNIT : Dictionary = {0: "line", 1: "scout", 3: "artillery"}

const SLOTS : Array = ["head", "torso", "arm_l", "arm_r", "legs", "extra"]
const SLOT_LABELS : Dictionary = {
	"head": "Head", "torso": "Torso", "arm_l": "Left Arm",
	"arm_r": "Right Arm", "legs": "Legs",
}
## The faction-flavored extra slot (user spec 2026-07-18).
const EXTRA_LABELS : Dictionary = {
	"architects": "Fins", "bloom": "Flora", "mesh": "Tentacles",
}

## Where each attachable slot mounts, in unit space (multiplied by the body scale factor
## the caller passes). Placeholder anchors — tune as real parts land.
const SLOT_ANCHORS : Dictionary = {
	"head":  Vector3(0.10, 0.55, 0.0),
	"arm_l": Vector3(0.0, 0.15, 0.45),
	"arm_r": Vector3(0.0, 0.15, -0.45),
	"legs":  Vector3(0.0, -0.35, 0.0),
	"extra": Vector3(-0.35, 0.35, 0.0),
}

const COLOR_CHANNELS : Array = ["primary", "secondary", "glow"]
## Curated faction swatches (customizer also offers a free picker).
const FACTION_SWATCHES : Dictionary = {
	"architects": [Color(1.00, 0.82, 0.18), Color(0.92, 0.93, 0.98), Color(0.75, 0.58, 0.20),
		Color(0.30, 0.55, 0.85), Color(0.85, 0.35, 0.25), Color(0.20, 0.22, 0.28)],
	"bloom": [Color(0.35, 0.80, 0.40), Color(0.60, 0.90, 0.45), Color(0.15, 0.45, 0.30),
		Color(0.80, 0.60, 0.85), Color(0.90, 0.75, 0.30), Color(0.25, 0.30, 0.22)],
	"mesh": [Color(0.45, 0.40, 0.75), Color(0.20, 0.20, 0.26), Color(0.35, 0.75, 1.00),
		Color(0.85, 0.25, 0.45), Color(0.55, 0.95, 0.85), Color(0.70, 0.72, 0.78)],
}
## Default glow per faction = the substrate accent (SubstrateMaterials energies).
const FACTION_GLOW : Dictionary = {
	"architects": Color(1.00, 0.82, 0.38),
	"bloom": Color(0.45, 1.00, 0.50),
	"mesh": Color(0.35, 0.75, 1.00),
}

## Three design-variation presets per faction (user is authoring these; placeholders set
## colors now, and each carries a parts dict that fills in as parts are authored).
const VARIATIONS : Dictionary = {
	"architects": [
		{"name": "Seraphic", "colors": {"primary": Color(0.92, 0.93, 0.98),
			"secondary": Color(1.00, 0.82, 0.18), "glow": Color(1.00, 0.82, 0.38)}, "parts": {}},
		{"name": "Gilded", "colors": {"primary": Color(1.00, 0.82, 0.18),
			"secondary": Color(0.20, 0.22, 0.28), "glow": Color(1.00, 0.65, 0.20)}, "parts": {}},
		{"name": "Obsidian", "colors": {"primary": Color(0.20, 0.22, 0.28),
			"secondary": Color(0.92, 0.93, 0.98), "glow": Color(0.30, 0.55, 0.85)}, "parts": {}},
	],
	"bloom": [
		{"name": "Verdant", "colors": {"primary": Color(0.35, 0.80, 0.40),
			"secondary": Color(0.15, 0.45, 0.30), "glow": Color(0.45, 1.00, 0.50)}, "parts": {}},
		{"name": "Sporefall", "colors": {"primary": Color(0.80, 0.60, 0.85),
			"secondary": Color(0.35, 0.80, 0.40), "glow": Color(0.90, 0.55, 0.95)}, "parts": {}},
		{"name": "Mire", "colors": {"primary": Color(0.25, 0.30, 0.22),
			"secondary": Color(0.90, 0.75, 0.30), "glow": Color(0.75, 0.95, 0.35)}, "parts": {}},
	],
	"mesh": [
		{"name": "Signal", "colors": {"primary": Color(0.20, 0.20, 0.26),
			"secondary": Color(0.45, 0.40, 0.75), "glow": Color(0.35, 0.75, 1.00)}, "parts": {}},
		{"name": "Ember", "colors": {"primary": Color(0.28, 0.20, 0.22),
			"secondary": Color(0.85, 0.25, 0.45), "glow": Color(1.00, 0.40, 0.30)}, "parts": {}},
		{"name": "Ghost", "colors": {"primary": Color(0.70, 0.72, 0.78),
			"secondary": Color(0.20, 0.20, 0.26), "glow": Color(0.55, 0.95, 0.85)}, "parts": {}},
	],
}

## How hard a custom primary pulls a GLTF model's textured albedo (stronger than the
## subtle faction tint so the choice reads; still keeps model detail).
const CUSTOM_TINT_STRENGTH : float = 0.55

static var _profile : Dictionary = {}
static var _loaded : bool = false
static var _parts_cache : Dictionary = {}   ## "fac/unit/slot" -> Array[Dictionary]

## -- profile ---------------------------------------------------------------------------

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(PROFILE_PATH):
		var f : FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_profile = parsed

static func save() -> void:
	var f : FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_profile, "  "))

## Config dict for one faction/unit (created on demand). Parts default to stock,
## colors to the faction look, use_custom_colors to false.
static func unit_cfg(faction: String, unit: String) -> Dictionary:
	_ensure_loaded()
	var fac : Dictionary = _profile.get(faction, {})
	var cfg : Dictionary = fac.get(unit, {})
	if not cfg.has("parts"):
		var parts : Dictionary = {}
		for s in SLOTS:
			parts[s] = STOCK
		cfg["parts"] = parts
		cfg["use_custom_colors"] = false
		cfg["colors"] = {}
		fac[unit] = cfg
		_profile[faction] = fac
	return cfg

static func set_part(faction: String, unit: String, slot: String, part_id: String) -> void:
	unit_cfg(faction, unit)["parts"][slot] = part_id
	save()

static func set_color(faction: String, unit: String, channel: String, col: Color) -> void:
	var cfg : Dictionary = unit_cfg(faction, unit)
	cfg["colors"][channel] = col.to_html(false)
	cfg["use_custom_colors"] = true
	save()

static func set_use_custom_colors(faction: String, unit: String, on: bool) -> void:
	unit_cfg(faction, unit)["use_custom_colors"] = on
	save()

static func reset_unit(faction: String, unit: String) -> void:
	_ensure_loaded()
	if _profile.has(faction):
		_profile[faction].erase(unit)
	save()

## Apply a variation preset (colors + any authored parts) to one faction/unit.
static func apply_variation(faction: String, unit: String, idx: int) -> void:
	var vars_list : Array = VARIATIONS.get(faction, [])
	if idx < 0 or idx >= vars_list.size():
		return
	var v : Dictionary = vars_list[idx]
	var cfg : Dictionary = unit_cfg(faction, unit)
	for ch in COLOR_CHANNELS:
		cfg["colors"][ch] = (v["colors"][ch] as Color).to_html(false)
	cfg["use_custom_colors"] = true
	for s in SLOTS:
		cfg["parts"][s] = v["parts"].get(s, STOCK)
	save()

## -- reads used by battle + preview ----------------------------------------------------

static func unit_key_for_role(role: int) -> String:
	return _ROLE_TO_UNIT.get(role, "line")

static func uses_custom_colors(faction: String, unit: String) -> bool:
	return bool(unit_cfg(faction, unit).get("use_custom_colors", false))

## Channel color, or `fallback` when the player hasn't customized this unit.
static func channel_color(faction: String, unit: String, channel: String, fallback: Color) -> Color:
	var cfg : Dictionary = unit_cfg(faction, unit)
	if not bool(cfg.get("use_custom_colors", false)):
		return fallback
	var html = cfg["colors"].get(channel)
	return Color.from_string(str(html), fallback) if html != null else fallback

static func primary_color(faction: String, unit: String, fallback: Color) -> Color:
	return channel_color(faction, unit, "primary", fallback)

static func glow_color(faction: String, unit: String) -> Color:
	return channel_color(faction, unit, "glow", FACTION_GLOW.get(faction, Color.WHITE))

static func secondary_color(faction: String, unit: String, fallback: Color) -> Color:
	return channel_color(faction, unit, "secondary", fallback)

## Restyle an already-substrate-configured material with the player's custom colors.
## Writes the same channels gameplay writes (albedo) or decor owns (emission color) —
## never energy/texture, so substrate animation + hit-flash stay intact.
static func style_material(m: StandardMaterial3D, faction: String, unit: String) -> void:
	if m == null or not uses_custom_colors(faction, unit):
		return
	m.albedo_color = primary_color(faction, unit, m.albedo_color)
	if m.emission_enabled:
		m.emission = glow_color(faction, unit)

## -- part discovery --------------------------------------------------------------------

## All parts available for a slot: always [stock, ...authored .glb files]. Entries:
## {id, name, path} (stock path = ""). Handles exported-build .remap/.import listings.
static func parts_for(faction: String, unit: String, slot: String) -> Array:
	var key : String = "%s/%s/%s" % [faction, unit, slot]
	if _parts_cache.has(key):
		return _parts_cache[key]
	var list : Array = [{"id": STOCK, "name": "Stock", "path": ""}]
	var dir_path : String = "%s/%s" % [PARTS_ROOT, key]
	var dir : DirAccess = DirAccess.open(dir_path)
	if dir != null:
		for f in dir.get_files():
			var fn : String = f.trim_suffix(".remap").trim_suffix(".import")
			if fn.get_extension() == "glb" or fn.get_extension() == "gltf":
				var id : String = fn.get_basename()
				list.append({"id": id, "name": id.capitalize(),
					"path": "%s/%s" % [dir_path, fn]})
	_parts_cache[key] = list
	return list

static func part_entry(faction: String, unit: String, slot: String, part_id: String) -> Dictionary:
	for p in parts_for(faction, unit, slot):
		if str(p["id"]) == part_id:
			return p
	return {"id": STOCK, "name": "Stock", "path": ""}

## -- part attachment -------------------------------------------------------------------

## Instance the unit's selected non-stock parts under `holder`. `body_scale` sizes the
## anchors (pass the unit's body scale, e.g. 24.0). If a non-stock TORSO is selected it
## REPLACES the base body: `base_body` (may be null) is hidden. Secondary color tints
## attached parts. Returns the number of parts attached.
static func attach_parts(holder: Node3D, faction: String, unit: String,
		body_scale: float, base_body: Node3D = null) -> int:
	var cfg : Dictionary = unit_cfg(faction, unit)
	var attached : int = 0
	var sec : Color = secondary_color(faction, unit, Color.WHITE)
	var custom : bool = uses_custom_colors(faction, unit)
	for slot in SLOTS:
		var pid : String = str(cfg["parts"].get(slot, STOCK))
		if pid == STOCK:
			continue
		var entry : Dictionary = part_entry(faction, unit, slot, pid)
		var path : String = str(entry["path"])
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var res = ResourceLoader.load(path)
		if res == null:
			continue
		var inst : Node3D = res.instantiate() as Node3D
		if inst == null:
			continue
		inst.scale = Vector3.ONE * body_scale
		if slot == "torso":
			inst.position = Vector3.ZERO
			if base_body != null:
				base_body.visible = false
		else:
			inst.position = SLOT_ANCHORS.get(slot, Vector3.ZERO) * body_scale
		if custom:
			_tint_part(inst, sec)
		holder.add_child(inst)
		attached += 1
	return attached

## Public: pull every material in a model toward `col` (per-instance duplicates).
## Used for custom-primary tint on GLTF bodies that keep their own textures.
static func tint_model(node: Node, col: Color) -> void:
	if node != null:
		_tint_part(node, col)

## Pull an attached part's albedo toward the secondary channel (per-instance material).
static func _tint_part(node: Node, col: Color) -> void:
	if node is MeshInstance3D:
		var mi : MeshInstance3D = node
		var src : Material = mi.get_active_material(0)
		var mat : StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
		mat.albedo_color = mat.albedo_color.lerp(col, CUSTOM_TINT_STRENGTH)
		mi.material_override = mat
	for c in node.get_children():
		_tint_part(c, col)

static func slot_label(faction: String, slot: String) -> String:
	if slot == "extra":
		return str(EXTRA_LABELS.get(faction, "Extra"))
	return str(SLOT_LABELS.get(slot, slot.capitalize()))
