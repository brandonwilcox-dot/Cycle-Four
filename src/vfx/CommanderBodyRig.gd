## CommanderBodyRig.gd — the faction Commander mechs (planning/commander-mech-directions.md,
## recommended trio approved 2026-07-03). One rig per Commander: builds the faction body onto
## the Commander's `_body` MeshInstance3D and owns its idle/movement animation. Cosmetic only.
##
##   architects — A1 "The Needle":     hovering polished spire, floating halo + wing-blades,
##                                     under-glow disc. Glides; never touches the ground.
##   bloom      — B1 "The Broodmother": wide six-legged crab; crusher + manipulator claws,
##                                     breathing spore polyps, eye stalks. Tripod gait.
##   mesh       — M1 "The Weaver":     near-black core on eight thin legs, electric-blue
##                                     joint nodes with a signal pulsing around the body.
##   (anything else)                   the previous shared mech, kept as the fallback.
##
## Structural parts share the Commander's substrate material (tints/substrate apply body-wide);
## small glow decor (halo, disc, polyps, joint nodes) get their own emissive materials.
## The rig exposes body_lift / pip_position / bar_y so the Commander places its overlays.
## Per project convention, callers PRELOAD this script.
extends Node3D

const AMBER : Color = Color(1.00, 0.82, 0.38)
const BIO_GREEN : Color = Color(0.45, 1.00, 0.50)
const SIGNAL_BLUE : Color = Color(0.35, 0.75, 1.00)

const _ASSET = preload("res://src/core/AssetLoader.gd")
const _COSMETICS = preload("res://src/core/cosmetics/Cosmetics.gd")
const WORLD3D = preload("res://src/core/World3D.gd")

## Body scale for cosmetic part anchors (commander stands ~70 game units).
const COSMETIC_PART_SCALE : float = 60.0

## Hand-modeled GLTF path (Blender). When a faction has a rigged commander model
## it replaces the procedural build; the walk animation is driven by movement.
var _use_gltf  : bool             = false
var _gltf_root : Node3D           = null
var _anim      : AnimationPlayer  = null
var _walk_name : String           = ""
var _idle_name : String           = ""
const WALK_SPEED_SCALE : float = 0.75   ## lumbering cadence for a colossal mech
const ANIM_BLEND       : float = 0.35   ## crossfade time (squares up on stop)

## Torso aim-twist (GLTF rigs): the upper body tracks the Commander's aim/build target
## up to ±45° off the leg line, so it can fire/build off-axis without turning in place.
const TORSO_TWIST_MAX  : float = 0.7853981  ## 45° each way (90° total range)
const TORSO_TWIST_RATE : float = 3.0        ## rad/s toward the target offset
const TORSO_TWIST_SIGN : float = 1.0        ## flip to -1.0 if the twist tracks mirrored
var _skel      : Skeleton3D = null
var _torso_idx : int = -1
var _torso_rest : Quaternion = Quaternion.IDENTITY
var _twist     : float = 0.0

## Charged-shot glow (GLTF rigs): fins + cannon lights ramp while the heavy shot winds up.
var _fins_mat        : StandardMaterial3D = null
var _fins_base_e     : float = 1.0
var _cannon_mat      : StandardMaterial3D = null
var _cannon_base_e   : float = 1.0
var _charge_level    : float = 0.0   ## 0..1 windup (set_charge)
var _flash           : float = 0.0   ## discharge flash, decays in _process
## Engineering scan (GLTF rigs): fins wobble + pulse while the build beam rasters.
var _fins_mi         : MeshInstance3D = null
var _fins_center     : Vector3 = Vector3.ZERO   ## fins AABB centre, fins-local
var _fins_idx        : int = -1
var _fins_rest       : Quaternion = Quaternion.IDENTITY
var _scan_active     : bool = false
var _scan_phase      : float = 0.0

var body_lift    : float = 42.0                    ## Y of the hull centre
var pip_position : Vector3 = Vector3(6.0, 69.0, 0.0)
var bar_y        : float = 82.0
## Cannon-tip fire origins in the COMMANDER's local frame (+X forward, ±Z lateral, +Y up).
## The Commander transforms these by its facing to spawn one tracer per cannon arm.
var muzzles      : Array[Vector3] = []

var _faction : String = ""
var _body    : MeshInstance3D = null
var _mat     : Material = null
var _t       : float = 0.0

## A1 animated refs.
var _halo   : MeshInstance3D = null
var _blades : Array[MeshInstance3D] = []
var _disc_mat : StandardMaterial3D = null
## B1 animated refs.
var _legs   : Array[MeshInstance3D] = []   ## leg roots (B1: 6, M1: 8 pivots)
var _polyp_mats : Array[StandardMaterial3D] = []
## M1 animated refs.
var _node_mats : Array[StandardMaterial3D] = []

func setup(faction: String, body: MeshInstance3D, mat: Material) -> void:
	_faction = faction
	_body = body
	_mat = mat
	## Prefer a hand-modeled rigged GLTF when one exists for this faction.
	if not _try_build_gltf(faction):
		match faction:
			"architects":
				_build_needle()
			"bloom":
				_build_broodmother()
			"mesh":
				_build_weaver()
			_:
				_build_fallback_mech()
	_apply_cosmetics(faction)
	_compute_muzzles()

## Player customization (Cosmetics.gd — user://cosmetics.json). The rig is PLAYER-side
## only (enemies have no Commander), so this never touches enemy readability.
## Custom primary tints the body; glow recolors the procedural emission; authored parts
## attach at their anchors (a non-stock torso replaces the GLTF body).
func _apply_cosmetics(faction: String) -> void:
	if _COSMETICS.uses_custom_colors(faction, "commander"):
		if _use_gltf and _gltf_root != null:
			_COSMETICS.tint_model(_gltf_root,
				_COSMETICS.primary_color(faction, "commander", Color.WHITE))
		elif _mat is StandardMaterial3D:
			_COSMETICS.style_material(_mat as StandardMaterial3D, faction, "commander")
	if _body != null:
		_COSMETICS.attach_parts(_body, faction, "commander", COSMETIC_PART_SCALE, _gltf_root)

## -- GLTF commander (hand-modeled in Blender) -----------------------------------------
## Loads the rigged model as a child of _body, scaled to game units and oriented so its
## front (Godot -Z) points along the Commander's forward (+X). Sets overlay heights and
## grabs the AnimationPlayer so movement can drive the walk cycle.
func _try_build_gltf(faction: String) -> bool:
	var model : Node3D = _ASSET.load_commander_model(faction)
	if model == null:
		return false
	var mscale : float = float(_ASSET.FACTION_COMMANDER_SCALE.get(faction, 20.0))
	model.scale = Vector3(mscale, mscale, mscale)
	var yaw : float = float(_ASSET.FACTION_COMMANDER_YAW.get(faction, -90.0))
	model.rotation_degrees = Vector3(0.0, yaw, 0.0)   ## model front -> +X forward (per faction)
	_body.add_child(model)
	_gltf_root = model
	body_lift = 0.0                                     ## feet at ground (model local y=0)
	## Place overlays from the model's actual height (works for tall biped + low crab/spider).
	var top : float = 70.0
	var mi : MeshInstance3D = _ASSET.find_mesh_instance(model)
	if mi != null:
		var ab : AABB = mi.get_aabb()
		top = (ab.position.y + ab.size.y) * mscale
	pip_position = Vector3(0.0, top + 8.0, 0.0)
	bar_y        = top
	_anim = _ASSET.find_animation_player(model)
	if _anim != null:
		for n in _anim.get_animation_list():
			var a : Animation = _anim.get_animation(n)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
			var low : String = n.to_lower()
			if "walk" in low:
				_walk_name = n
			elif "idle" in low:
				_idle_name = n
		if _walk_name == "" and _anim.get_animation_list().size() > 0:
			_walk_name = _anim.get_animation_list()[0]
		if _idle_name == "":
			_idle_name = _walk_name
	## Torso twist: grab the skeleton + torso bone (not animated by Walk/Idle, so a
	## per-frame pose write persists cleanly on top of the leg animation).
	_skel = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skel != null:
		_torso_idx = _skel.find_bone("torso")
		if _torso_idx >= 0:
			_torso_rest = _skel.get_bone_rest(_torso_idx).basis.get_rotation_quaternion()
	## Charged-shot glow materials (duplicated so ramping never touches shared resources).
	var fins_mi : MeshInstance3D = model.find_child("Fins", true, false) as MeshInstance3D
	if fins_mi != null:
		_fins_mi = fins_mi
		var fa : AABB = fins_mi.get_aabb()
		_fins_center = fa.position + fa.size * 0.5
		if fins_mi.get_active_material(0) is StandardMaterial3D:
			_fins_mat = (fins_mi.get_active_material(0) as StandardMaterial3D).duplicate()
			_fins_base_e = _fins_mat.emission_energy_multiplier
			fins_mi.material_override = _fins_mat
	if _skel != null:
		_fins_idx = _skel.find_bone("fins")
		if _fins_idx >= 0:
			_fins_rest = _skel.get_bone_rest(_fins_idx).basis.get_rotation_quaternion()
			## Pre-express the measured fin edges in fins-bone-local space so the live
			## bone pose (scan wobble / torso twist) carries the beam emitters with it.
			var inv_rest : Transform3D = _skel.get_bone_global_rest(_fins_idx).affine_inverse()
			_edge_local.clear()
			for seg in FIN_EDGES_MODEL:
				_edge_local.append([inv_rest * seg[0], inv_rest * seg[1]])
	var can_mats : Array[MeshInstance3D] = []
	for nm in ["Cannon_L", "Cannon_R"]:
		var cmi : MeshInstance3D = model.find_child(nm, true, false) as MeshInstance3D
		if cmi != null:
			can_mats.append(cmi)
	if not can_mats.is_empty() and can_mats[0].get_active_material(0) is StandardMaterial3D:
		_cannon_mat = (can_mats[0].get_active_material(0) as StandardMaterial3D).duplicate()
		_cannon_base_e = _cannon_mat.emission_energy_multiplier
		for cmi in can_mats:
			cmi.material_override = _cannon_mat
	_use_gltf = true
	return true

## Charged-shot windup 0..1: fins blaze up, cannon side-lights brighten with them.
func set_charge(t: float) -> void:
	_charge_level = clampf(t, 0.0, 1.0)

## The charged volley just fired — spike the glow hard, then decay (see _update_glow).
func discharge() -> void:
	_flash = 1.0

## Engineering scan state: `phase` is the raster cycle 0..1 (wraps); drives the fins wobble.
func set_scan(active: bool, phase: float) -> void:
	_scan_active = active
	_scan_phase = phase

## Fin leading-edge segments, measured from the Cathedral fins geometry in Blender
## (armature/model space, pre-scale; glTF axes: x lateral, y up, z forward).
## Each entry is [edge_bottom, edge_top] — the beam sheet emits along this edge.
const FIN_EDGES_MODEL : Array = [
	[Vector3(0.590, 1.800, 0.120), Vector3(0.348, 2.574, -0.105)],    ## left fin
	[Vector3(-0.588, 1.800, 0.120), Vector3(-0.346, 2.574, -0.105)],  ## right fin
]
var _edge_local : Array = []   ## FIN_EDGES_MODEL re-expressed fins-bone-local (setup)

## World-space fin leading edges, following the LIVE fins bone pose (scan wobble,
## torso twist, walk motion). Returns [[bot,top],[bot,top]] or [] when unavailable.
func fin_edges() -> Array:
	if _skel == null or _fins_idx < 0 or _edge_local.is_empty():
		return []
	var bone_xf : Transform3D = _skel.global_transform * _skel.get_bone_global_pose(_fins_idx)
	var out : Array = []
	for seg in _edge_local:
		out.append([bone_xf * seg[0], bone_xf * seg[1]])
	return out

## World-space emitter points — one on EACH fin (upper-outer region of the pair),
## so the construction beams triangulate onto the scanned structure.
func fins_points() -> Array:
	if _fins_mi != null and _fins_mi.is_inside_tree():
		var fa : AABB = _fins_mi.get_aabb()
		var c : Vector3 = fa.position + fa.size * 0.5
		var lat : float = fa.size.x * 0.35          ## out toward each fin blade
		var up  : float = fa.position.y + fa.size.y * 0.72   ## upper span of the fins
		var xf : Transform3D = _fins_mi.global_transform
		return [xf * Vector3(c.x + lat, up, c.z),
				xf * Vector3(c.x - lat, up, c.z)]
	var parent : Node = get_parent()
	if parent is Node3D:
		var p : Vector3 = (parent as Node3D).global_position + Vector3(0, 45.0, 0)
		return [p, p]
	return [global_position, global_position]

## Merge every glow source into the fins/cannon materials + drive the fins scan wobble.
func _update_glow(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.2)
	var scan_pulse : float = 0.0
	if _scan_active:
		scan_pulse = 0.5 * (1.0 - cos(_scan_phase * TAU))
	if _fins_mat != null:
		_fins_mat.emission_energy_multiplier = _fins_base_e * \
			(1.0 + 3.5 * _charge_level + 0.9 * scan_pulse + 6.0 * _flash)
	if _cannon_mat != null:
		_cannon_mat.emission_energy_multiplier = _cannon_base_e * \
			(1.0 + 1.5 * _charge_level + 4.0 * _flash)
	## Fins wobble: a slow sweeping nod while scanning, a sharp kick on discharge.
	if _skel != null and _fins_idx >= 0:
		var pitch : float = 0.0
		var yaw   : float = 0.0
		if _scan_active:
			pitch = sin(_scan_phase * TAU) * 0.14
			yaw   = sin(_scan_phase * TAU * 0.5) * 0.06
		pitch += -0.22 * _flash   ## recoil snap on the heavy shot
		_skel.set_bone_pose_rotation(_fins_idx,
			_fins_rest * Quaternion(Vector3(1, 0, 0), pitch) * Quaternion(Vector3(0, 0, 1), yaw))

## Upper-body aim tracking: ease the torso bone toward the Commander's aim offset.
func _update_torso_twist(delta: float) -> void:
	if _skel == null or _torso_idx < 0:
		return
	var parent : Node = get_parent()
	var want : float = 0.0
	if parent is Node3D and parent.has_method("aim_point"):
		var aim : Vector2 = parent.call("aim_point")
		if aim.is_finite():
			var to : Vector2 = aim - WORLD3D.node_plane(parent)
			if to.length_squared() > 1.0:
				var desired : float = -atan2(to.y, to.x)
				var offset  : float = wrapf(desired - (parent as Node3D).rotation.y, -PI, PI)
				want = clampf(offset, -TORSO_TWIST_MAX, TORSO_TWIST_MAX)
	_twist = move_toward(_twist, want, TORSO_TWIST_RATE * delta)
	_skel.set_bone_pose_rotation(_torso_idx,
		_torso_rest * Quaternion(Vector3.UP, _twist * TORSO_TWIST_SIGN))

## Crossfade Walk (while striding) <-> Idle (squared stance when stopped/turning).
func _drive_gltf() -> void:
	if _anim == null:
		return
	var parent : Node = get_parent()
	## Stride only when actually translating (Commander.is_striding); a pure in-place
	## turn keeps the Idle stance so the mech squares up and swivels before walking.
	var striding : bool = parent != null and parent.has_method("is_striding") and bool(parent.call("is_striding"))
	var want : String = _walk_name if striding else _idle_name
	if want == "":
		return
	if _anim.current_animation != want:
		_anim.play(want, ANIM_BLEND)
	_anim.speed_scale = WALK_SPEED_SCALE if striding else 1.0

## -- muzzle points ----------------------------------------------------------------------
## Derive two symmetric cannon-arm fire origins from the built body's bounds, expressed in the
## Commander's local frame (+X forward, ±Z lateral). Works for the GLB biped (arm cannons) and
## the procedural bodies alike; the Commander re-orients them by its facing when it fires.
func _compute_muzzles() -> void:
	muzzles.clear()
	var ref : Node = get_parent()   ## the Commander node — muzzles live in its local frame
	if ref == null or not (ref is Node3D):
		return
	## GLTF rig: fire from the actual cannon blade TIPS (forward-lowest point of each
	## cannon mesh's bounds in the Commander's frame) so tracers leave the muzzles.
	if _use_gltf and _gltf_root != null:
		for nm in ["Cannon_L", "Cannon_R"]:
			var cmi : MeshInstance3D = _gltf_root.find_child(nm, true, false) as MeshInstance3D
			if cmi == null or not cmi.is_inside_tree():
				continue
			var ca : AABB = _local_aabb_of(cmi, ref as Node3D)
			muzzles.append(Vector3(
				ca.position.x + ca.size.x,          ## forward-most (+X = facing)
				ca.position.y + ca.size.y * 0.12,   ## near the low tip
				ca.position.z + ca.size.z * 0.5))   ## each cannon centers on its own arm
		if not muzzles.is_empty():
			return
	var mi : MeshInstance3D = null
	if _use_gltf and _gltf_root != null:
		mi = _ASSET.find_mesh_instance(_gltf_root)
	elif _body != null and _body.mesh != null:
		mi = _body
	if mi == null or not mi.is_inside_tree():
		return
	var la : AABB = _local_aabb_of(mi, ref as Node3D)
	var c  : Vector3 = la.position + la.size * 0.5
	var fwd : float = c.x + la.size.x * 0.5 * 0.7    ## out toward the front face
	var hgt : float = c.y + la.size.y * 0.5 * 0.15   ## a touch above centre (shoulder/arm height)
	var lat : float = la.size.z * 0.5 * 0.62         ## split to the left/right arms
	muzzles = [Vector3(fwd, hgt, lat), Vector3(fwd, hgt, -lat)]

## AABB of mesh instance `mi`, re-expressed in `ref`'s local space (all 8 corners transformed).
func _local_aabb_of(mi: MeshInstance3D, ref: Node3D) -> AABB:
	var ab : AABB = mi.get_aabb()
	var xf : Transform3D = ref.global_transform.affine_inverse() * mi.global_transform
	var out : AABB = AABB()
	for i in 8:
		var corner : Vector3 = ab.position + Vector3(
			ab.size.x if (i & 1) else 0.0,
			ab.size.y if (i & 2) else 0.0,
			ab.size.z if (i & 4) else 0.0)
		var p : Vector3 = xf * corner
		if i == 0:
			out = AABB(p, Vector3.ZERO)
		else:
			out = out.expand(p)
	return out

## -- shared part helpers ---------------------------------------------------------------

func _part(mesh: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi : MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	if rot_deg != Vector3.ZERO:
		mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_body.add_child(mi)
	return mi

func _box(x: float, y: float, z: float) -> BoxMesh:
	var b : BoxMesh = BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

func _sphere(r: float, h: float = -1.0) -> SphereMesh:
	var s : SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = h if h > 0.0 else r * 2.0
	return s

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c : CapsuleMesh = CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c

func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m : StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## -- A1: The Needle (architects) -------------------------------------------------------
## A slender polished spire that HOVERS — base ~6 px off the ground. Floating halo and
## wing-blades; a soft amber glow disc beneath. Aeon-sleek: nothing stomps.

func _build_needle() -> void:
	body_lift    = 34.0
	pip_position = Vector3(0.0, 34.0 + 34.0, 0.0)
	bar_y        = 34.0 + 44.0
	var spire : CylinderMesh = CylinderMesh.new()
	spire.top_radius = 5.0
	spire.bottom_radius = 12.0
	spire.height = 56.0
	_body.mesh = spire
	_part(_sphere(6.5, 13.0), Vector3(0.0, 31.0, 0.0), _mat)                 ## crown
	var halo_mesh : TorusMesh = TorusMesh.new()
	halo_mesh.inner_radius = 13.0
	halo_mesh.outer_radius = 16.0
	_halo = _part(halo_mesh, Vector3(0.0, 39.0, 0.0), _glow_mat(AMBER, 1.1))
	for side in [-1.0, 1.0]:
		var blade : MeshInstance3D = _part(_box(4.0, 30.0, 10.0),
			Vector3(-4.0, 4.0, side * 20.0), _mat, Vector3(0.0, 0.0, side * 12.0))
		_blades.append(blade)
	var disc : CylinderMesh = CylinderMesh.new()
	disc.top_radius = 11.0
	disc.bottom_radius = 11.0
	disc.height = 2.0
	_disc_mat = _glow_mat(AMBER, 0.9)
	var d : MeshInstance3D = _part(disc, Vector3(0.0, -30.0, 0.0), _disc_mat)
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## Seraphim tech underscore (playtest 2026-07-03): one thin light-channel up the spire —
	## sleek and polished, but unmistakably engineered.
	var line : MeshInstance3D = _part(_box(1.4, 42.0, 2.2), Vector3(10.0, -4.0, 0.0),
		_glow_mat(Color(1.0, 0.92, 0.75), 1.3))
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## -- B1: The Broodmother (bloom) --------------------------------------------------------
## Wide low crab: domed carapace on six stepping legs; one crusher claw, one slender
## manipulator (the engineering limb); spore polyps breathing on the shell.

func _build_broodmother() -> void:
	body_lift    = 26.0
	pip_position = Vector3(0.0, 26.0 + 22.0, 0.0)
	bar_y        = 26.0 + 34.0
	_body.mesh = _sphere(24.0, 30.0)   ## squashed dome carapace
	## Six legs, yawed around the shell, angled out-and-down to plant on the ground.
	for i in 6:
		var yaw : float = 30.0 + 60.0 * float(i)
		var pivot : MeshInstance3D = _part(_capsule(3.5, 30.0),
			Vector3(cos(deg_to_rad(yaw)) * 20.0, -6.0, sin(deg_to_rad(yaw)) * 20.0),
			_mat, Vector3(0.0, -yaw, 62.0))
		_legs.append(pivot)
	## Crusher claw (starboard) + jaw wedge.
	_part(_box(15.0, 9.0, 12.0), Vector3(21.0, -8.0, 10.0), _mat)
	_part(_box(9.0, 5.0, 10.0), Vector3(29.0, -11.0, 10.0), _mat, Vector3(0.0, 0.0, -14.0))
	## Manipulator (port) — slender engineering limb.
	_part(_capsule(2.2, 20.0), Vector3(22.0, -6.0, -10.0), _mat, Vector3(0.0, 0.0, 75.0))
	## Spore polyps on the shell — each breathes on its own phase (driven in _process).
	for p in [Vector3(-10.0, 13.0, 8.0), Vector3(-14.0, 11.0, -6.0), Vector3(-4.0, 15.0, -2.0)]:
		var pm : StandardMaterial3D = _glow_mat(BIO_GREEN, 0.9)
		var polyp : MeshInstance3D = _part(_sphere(4.5), p, pm)
		polyp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_polyp_mats.append(pm)
	## Eye stalks.
	for side in [-1.0, 1.0]:
		_part(_capsule(1.4, 10.0), Vector3(18.0, 8.0, side * 5.0), _mat, Vector3(0.0, 0.0, 55.0))

## -- M1: The Weaver (mesh) --------------------------------------------------------------
## A compact near-black core slung between eight thin angular legs; an electric-blue node
## at every knee, with the signal pulsing around the body in sequence. Sensor stalk raised.

func _build_weaver() -> void:
	body_lift    = 22.0
	pip_position = Vector3(6.0, 22.0 + 26.0, 0.0)
	bar_y        = 22.0 + 36.0
	_body.mesh = _box(20.0, 12.0, 16.0)
	_part(_box(14.0, 8.0, 12.0), Vector3(0.0, -8.0, 0.0), _mat)   ## underslung node housing
	for i in 8:
		var yaw : float = 22.5 + 45.0 * float(i)
		var dir : Vector3 = Vector3(cos(deg_to_rad(yaw)), 0.0, sin(deg_to_rad(yaw)))
		## Upper segment: out and slightly up from the hull edge.
		var upper : MeshInstance3D = _part(_box(22.0, 3.0, 3.0),
			Vector3(dir.x * 18.0, 2.0, dir.z * 18.0), _mat, Vector3(0.0, -yaw, 18.0))
		_legs.append(upper)
		## Knee node + lower segment hang off the upper segment's far end (local +X).
		var nm : StandardMaterial3D = _glow_mat(SIGNAL_BLUE, 0.8)
		var knee : MeshInstance3D = MeshInstance3D.new()
		knee.mesh = _sphere(2.6)
		knee.position = Vector3(12.0, 0.0, 0.0)
		knee.material_override = nm
		knee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		upper.add_child(knee)
		_node_mats.append(nm)
		var lower : MeshInstance3D = MeshInstance3D.new()
		lower.mesh = _box(3.0, 24.0, 3.0)
		lower.position = Vector3(12.0, -11.0, 0.0)
		lower.rotation_degrees = Vector3(0.0, 0.0, -12.0)
		lower.material_override = _mat
		lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		upper.add_child(lower)
	## Sensor stalk.
	_part(_box(2.0, 18.0, 2.0), Vector3(6.0, 13.0, 0.0), _mat)
	var tip : MeshInstance3D = _part(_sphere(2.4), Vector3(6.0, 23.0, 0.0), _glow_mat(SIGNAL_BLUE, 1.4))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## -- Fallback: the previous shared mech (unknown faction) --------------------------------

func _build_fallback_mech() -> void:
	body_lift    = 42.0
	pip_position = Vector3(6.0, 42.0 + 27.0, 0.0)
	bar_y        = 42.0 + 40.0
	_body.mesh = _box(26.0, 24.0, 30.0)
	_part(_box(11.0, 30.0, 12.0), Vector3(2.0, -27.0, 9.5), _mat)
	_part(_box(11.0, 30.0, 12.0), Vector3(2.0, -27.0, -9.5), _mat)
	_part(_box(18.0, 9.0, 26.0), Vector3(0.0, -15.0, 0.0), _mat)
	_part(_box(13.0, 11.0, 14.0), Vector3(-2.0, 13.0, 21.0), _mat)
	_part(_box(13.0, 11.0, 14.0), Vector3(-2.0, 13.0, -21.0), _mat)
	_part(_sphere(7.5, 15.0), Vector3(6.0, 17.0, 0.0), _mat)
	_part(_box(30.0, 7.0, 7.0), Vector3(12.0, 11.0, 21.0), _mat)
	_part(_box(2.4, 24.0, 2.4), Vector3(-9.0, 22.0, -8.0), _mat)

## -- animation ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if _body == null:
		return
	if _use_gltf:
		_drive_gltf()
		_update_torso_twist(delta)
		_update_glow(delta)
		return
	var parent : Node = get_parent()
	var moving : bool = parent != null and parent.has_method("is_moving") and bool(parent.call("is_moving"))
	match _faction:
		"architects":
			## Hover bob; halo spins; the body leans into travel; wing-blades trail.
			_body.position.y = body_lift + sin(_t * 1.2 * TAU * 0.2) * 2.5
			if _halo != null:
				_halo.rotation.y += delta * 0.8
			var lean_target : float = -0.10 if moving else 0.0
			_body.rotation.z = lerpf(_body.rotation.z, lean_target, minf(1.0, delta * 4.0))
			for i in _blades.size():
				var trail : float = (-8.0 if moving else -4.0) + sin(_t * 1.5 + float(i) * PI) * 1.5
				_blades[i].position.x = lerpf(_blades[i].position.x, trail, minf(1.0, delta * 3.0))
			if _disc_mat != null:
				_disc_mat.emission_energy_multiplier = 0.8 + 0.3 * sin(_t * 2.2)
		"bloom":
			## Carapace breathes; polyps pulse out of phase; legs step in tripod groups.
			## Playtest 2026-07-03: locomotion was imperceptible — the body now visibly
			## bobs and pitches with the stride, and the legs swing much harder.
			var breath : float = 1.0 + 0.02 * sin(_t * 1.4)
			_body.scale = Vector3(breath, 1.0 / breath, breath)
			for i in _polyp_mats.size():
				_polyp_mats[i].emission_energy_multiplier = 0.7 + 0.5 * sin(_t * 1.8 + float(i) * 2.1)
			var step_amp : float = 0.32 if moving else 0.02
			for i in _legs.size():
				var phase : float = 0.0 if i % 2 == 0 else PI   ## tripod: alternate legs anti-phase
				_legs[i].rotation.x = sin(_t * 7.5 + phase) * step_amp
			var bob_target : float = body_lift + (absf(sin(_t * 3.75)) * 3.5 if moving else 0.0)
			_body.position.y = lerpf(_body.position.y, bob_target, minf(1.0, delta * 10.0))
			_body.rotation.z = lerpf(_body.rotation.z, (sin(_t * 3.75) * 0.05 if moving else 0.0), minf(1.0, delta * 8.0))
		"mesh":
			## Signal travels the joint nodes around the body; legs flow in tetrapod groups
			## while moving, micro-twitch at rest (the skitter DNA).
			var head : float = fmod(_t * 0.9, 1.0) * float(_node_mats.size())
			for i in _node_mats.size():
				var d : float = absf(float(i) - head)
				d = minf(d, float(_node_mats.size()) - d)   ## wrap distance around the ring
				_node_mats[i].emission_energy_multiplier = 0.5 + 2.0 * maxf(0.0, 1.0 - d)
			for i in _legs.size():
				if moving:
					var phase : float = 0.0 if (i % 4) < 2 else PI   ## tetrapod flow
					_legs[i].rotation.x = sin(_t * 10.0 + phase + float(i) * 0.35) * 0.24
				else:
					_legs[i].rotation.x = sin(_t * 2.0 + float(i) * 1.7) * 0.03
			## Playtest 2026-07-03: the chassis now visibly scuttles — quick shallow bounce.
			var scuttle : float = body_lift + (absf(sin(_t * 10.0)) * 2.2 if moving else 0.0)
			_body.position.y = lerpf(_body.position.y, scuttle, minf(1.0, delta * 12.0))
		_:
			pass   ## fallback mech is static (as before)
