## V1 atmosphere rig (visual-supercharge-plan.md, stage V1). One node that owns the whole
## look of a 3D screen: warm key light + cool fill (melancholy = warm/cool tension, not
## darkness), and a WorldEnvironment with starfield sky, AgX tonemap, glow (every emissive
## in the game finally blooms), soft depth fog, SSAO, and a subtle desaturating grade.
## Purely cosmetic — spawns no gameplay state. Battle3D adds one; future 3D screens reuse it.
## All units are pixels (CELL 64, tactical cam dist ~1600, galaxy zoom ≥5000) — fog density,
## SSAO radius and shadow distance below are calibrated to that scale, NOT meters.
extends Node3D

const SKY_SHADER := preload("res://assets/shaders/starfield_sky.gdshader")
const SUBSTRATE  := preload("res://src/vfx/SubstrateMaterials.gd")

## --- key / fill lights ---------------------------------------------------------------
const KEY_ROTATION_DEG   : Vector3 = Vector3(-52.0, -40.0, 0.0)   ## matches the pre-V1 sun angle
const KEY_COLOR          : Color = Color(1.0, 0.93, 0.82)          ## warm amber-white ("warm light on a work surface")
const KEY_ENERGY         : float = 1.15
const KEY_SHADOW_MAX_DIST: float = 6000.0                          ## pixel scale — default 100 is invisible here
const FILL_ROTATION_DEG  : Vector3 = Vector3(-28.0, 140.0, 0.0)    ## opposes the key in yaw
const FILL_COLOR         : Color = Color(0.45, 0.60, 0.90)         ## cool moonlight rim
const FILL_ENERGY        : float = 0.35

## --- environment ---------------------------------------------------------------------
const AMBIENT_COLOR      : Color = Color(0.38, 0.45, 0.58)
const AMBIENT_ENERGY     : float = 0.40
const GLOW_INTENSITY     : float = 0.70
const GLOW_BLOOM         : float = 0.05
const FOG_COLOR          : Color = Color(0.10, 0.14, 0.22)
const FOG_DENSITY        : float = 0.00005    ## exp fog at pixel scale: ~8% haze at 1600, ~26% at 6000
const FOG_FADE_RATE      : float = 0.00012    ## density/sec toward the zoom target (galaxy = no fog)
const SSAO_RADIUS        : float = 24.0       ## ~1/3 cell — grounds structures onto their tiles
const SSAO_INTENSITY     : float = 1.5
const GRADE_SATURATION   : float = 0.95       ## melancholy, not grimdark: a touch under neutral
const GRADE_CONTRAST     : float = 1.03

## V5.2 — THE canon effect (codex/03): while an Ancient is present, "color drains".
## Saturation sinks toward OBSERVED_SATURATION while anything is in the "ancients" group,
## then slowly returns. Drain is slower than recovery is slow — the world notices.
const OBSERVED_SATURATION : float = 0.35
const OBSERVED_DRAIN_RATE : float = 0.45   ## saturation/sec toward observed
const OBSERVED_RECOVER_RATE : float = 0.25 ## saturation/sec back to the normal grade

## E1 biome light grades (environment-skinning-plan.md): keyed by MapGrid's biome index.
## [key_color, key_energy, ambient_color, fog_color]
const BIOME_LIGHT : Array = [
	[Color(1.00, 0.93, 0.82), 1.15, Color(0.38, 0.45, 0.58), Color(0.10, 0.14, 0.22)],  ## verdant (baseline)
	[Color(1.00, 0.86, 0.70), 1.05, Color(0.46, 0.42, 0.40), Color(0.14, 0.12, 0.11)],  ## ashen — dusty, warm-grey
	[Color(0.90, 0.95, 1.00), 1.20, Color(0.36, 0.44, 0.64), Color(0.09, 0.13, 0.26)],  ## crystal — cold, clear
	[Color(1.00, 0.82, 0.62), 1.10, Color(0.48, 0.40, 0.34), Color(0.15, 0.11, 0.08)],  ## rust — low amber sun
]

## Volumetric fog (E1): faint light-shafted haze at tactical pitch. Density is an
## EXTINCTION PER UNIT — at pixel scale (fog length 4000) it must be tiny: 0.008 made an
## opaque wall (optical depth 32 — the 2026-07-19 "map all hidden" bug). 0.0001 ≈ 15%
## haze at tactical distance. Perf dial: set VOLUMETRIC false first if frames dip.
const VOLUMETRIC          : bool = true
const VOLUMETRIC_DENSITY  : float = 0.0001
const VOLUMETRIC_LENGTH   : float = 4000.0   ## pixel scale — covers the tactical camera band

var _env : Environment = null
var _rig : Node = null   ## camera_rig group — fog fades out at galaxy zoom so the graph stays clear
var _key : DirectionalLight3D = null

func _ready() -> void:
	name = "Atmosphere"
	add_to_group("atmosphere")
	_build_lights()
	_build_environment()

## E1: grade the light rig for the territory's biome (called by MapGrid on map refresh).
func set_biome(idx: int) -> void:
	var b : Array = BIOME_LIGHT[clampi(idx, 0, BIOME_LIGHT.size() - 1)]
	if _key != null:
		_key.light_color = b[0]
		_key.light_energy = b[1]
	if _env != null:
		_env.ambient_light_color = b[2]
		_env.fog_light_color = b[3]
		if VOLUMETRIC:
			_env.volumetric_fog_albedo = b[3].lightened(0.35)

func _build_lights() -> void:
	var key : DirectionalLight3D = DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = KEY_ROTATION_DEG
	key.light_color = KEY_COLOR
	key.light_energy = KEY_ENERGY
	key.shadow_enabled = true
	key.directional_shadow_max_distance = KEY_SHADOW_MAX_DIST
	key.directional_shadow_blend_splits = true
	key.light_volumetric_fog_energy = 1.0   ## E1: the key carves shafts through the haze
	add_child(key)
	_key = key

	var fill : DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = FILL_ROTATION_DEG
	fill.light_color = FILL_COLOR
	fill.light_energy = FILL_ENERGY
	fill.light_specular = 0.2
	add_child(fill)

func _build_environment() -> void:
	_env = Environment.new()

	var sky_mat : ShaderMaterial = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky : Sky = Sky.new()
	sky.sky_material = sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky

	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = AMBIENT_COLOR
	_env.ambient_light_energy = AMBIENT_ENERGY

	_env.tonemap_mode = Environment.TONE_MAPPER_AGX

	_env.glow_enabled = true
	_env.glow_intensity = GLOW_INTENSITY
	_env.glow_bloom = GLOW_BLOOM
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.glow_hdr_threshold = 1.0

	_env.fog_enabled = true
	_env.fog_light_color = FOG_COLOR
	_env.fog_density = FOG_DENSITY
	_env.fog_sky_affect = 0.0
	_env.fog_aerial_perspective = 0.5

	## E1 volumetric haze: soft light shafts at tactical pitch (fades with the exp fog).
	if VOLUMETRIC:
		_env.volumetric_fog_enabled = true
		_env.volumetric_fog_density = VOLUMETRIC_DENSITY
		_env.volumetric_fog_length = VOLUMETRIC_LENGTH
		_env.volumetric_fog_albedo = FOG_COLOR.lightened(0.35)
		_env.volumetric_fog_emission_energy = 0.0
		_env.volumetric_fog_sky_affect = 0.0

	_env.ssao_enabled = true
	_env.ssao_radius = SSAO_RADIUS
	_env.ssao_intensity = SSAO_INTENSITY

	_env.adjustment_enabled = true
	_env.adjustment_saturation = GRADE_SATURATION
	_env.adjustment_contrast = GRADE_CONTRAST

	var we : WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = _env
	add_child(we)

## Depth fog sells scale at tactical pitch but would wash out the galaxy graph at zoom-out
## (nodes sit 5000–14000 px away), so fade it toward zero while the rig reports galaxy zoom.
## Also the heartbeat for the living substrates (V4): Bloom breathes, Mesh traces travel.
func _process(delta: float) -> void:
	SUBSTRATE.tick(Time.get_ticks_msec() / 1000.0)
	if _env == null:
		return
	if not is_instance_valid(_rig):
		_rig = get_tree().get_first_node_in_group("camera_rig")
		if _rig == null:
			return
	var galaxy : bool = bool(_rig.call("is_galaxy_zoom"))
	var target : float = 0.0 if galaxy else FOG_DENSITY
	_env.fog_density = move_toward(_env.fog_density, target, FOG_FADE_RATE * delta)
	if VOLUMETRIC:
		var vt : float = 0.0 if galaxy else VOLUMETRIC_DENSITY
		_env.volumetric_fog_density = move_toward(_env.volumetric_fog_density, vt, VOLUMETRIC_DENSITY * 1.5 * delta)
	## V5.2 Ancient observation: color drains while a watcher is on the field, returns after.
	var observed : bool = get_tree().get_first_node_in_group("ancients") != null
	var sat_target : float = OBSERVED_SATURATION if observed else GRADE_SATURATION
	var rate : float = OBSERVED_DRAIN_RATE if observed else OBSERVED_RECOVER_RATE
	_env.adjustment_saturation = move_toward(_env.adjustment_saturation, sat_target, rate * delta)
