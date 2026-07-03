## ConstructionRig.gd — per-faction construction language (playtest 2026-07-02). One rig per
## structure (child of the entity); the entity calls update(frac, built) from its
## _refresh_build_visual and flourish() after an upgrade rebuild. Cosmetic only.
##
##   bloom (and unknown)  — GROWS: the body rises out of the ground, ghosted until done.
##   architects           — CARVES: a solid granite block stands at full height from the first
##                          moment; a laser ring sweeps down it, and the stone resolves into
##                          the finished crystalline surface as the carve completes.
##   mesh                 — ASSEMBLES: a translucent digital frame appears at full size while
##                          builder drones orbit it, printing the shell layer by layer.
##
## Per project convention, callers PRELOAD this script.
extends Node3D

const STONE_COL : Color = Color(0.16, 0.17, 0.19)   ## uncarved granite
const LASER_COL : Color = Color(1.00, 0.82, 0.38)
const DRONE_COL : Color = Color(0.35, 0.75, 1.00)
const FLOURISH_SECS : float = 1.2
const DRONE_COUNT : int = 3

var _faction    : String = ""
var _body_root  : Node3D = null
var _mats       : Array = []          ## the entity's _body_mats (StandardMaterial3D)
var _final_cols : Array[Color] = []   ## albedo snapshot at setup = the finished look
var _height     : float = 50.0
var _radius     : float = 30.0
var _frac       : float = 1.0
var _active     : bool = false
var _flourish_t : float = 0.0
var _ring       : MeshInstance3D = null
var _drones     : Array[MeshInstance3D] = []
var _t          : float = 0.0

func setup(faction: String, body_root: Node3D, mats: Array, height: float, radius: float) -> void:
	_faction   = faction
	_body_root = body_root
	_mats      = mats
	_height    = height
	_radius    = radius
	for m in mats:
		_final_cols.append((m as StandardMaterial3D).albedo_color)
	match _faction:
		"architects":
			_ring = MeshInstance3D.new()
			var tm : TorusMesh = TorusMesh.new()
			tm.inner_radius = _radius
			tm.outer_radius = _radius + 3.5
			_ring.mesh = tm
			var rm : StandardMaterial3D = StandardMaterial3D.new()
			rm.albedo_color = LASER_COL
			rm.emission_enabled = true
			rm.emission = LASER_COL
			rm.emission_energy_multiplier = 2.2   ## the carve line blooms
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ring.material_override = rm
			_ring.visible = false
			add_child(_ring)
		"mesh":
			for i in DRONE_COUNT:
				var d : MeshInstance3D = MeshInstance3D.new()
				var bx : BoxMesh = BoxMesh.new()
				bx.size = Vector3(6.0, 3.0, 6.0)
				d.mesh = bx
				var dm : StandardMaterial3D = StandardMaterial3D.new()
				dm.albedo_color = DRONE_COL
				dm.emission_enabled = true
				dm.emission = DRONE_COL
				dm.emission_energy_multiplier = 1.6
				dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				d.material_override = dm
				d.visible = false
				add_child(d)
				_drones.append(d)

## Drive the construction look. built=true restores the finished appearance (also used
## while a BUILT structure is merely being repaired — no construction theatrics then).
func update(frac: float, built: bool) -> void:
	_frac = clampf(frac, 0.0, 1.0)
	_active = not built
	if built:
		_restore()
		return
	match _faction:
		"architects":
			## Full-height granite resolving into the finished surface as the laser carves down.
			if _body_root != null:
				_body_root.scale.y = 1.0
			for i in _mats.size():
				var m : StandardMaterial3D = _mats[i]
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				m.albedo_color = STONE_COL.lerp(_final_cols[i], _frac)
		"mesh":
			## Translucent digital frame at full size; the drones do the printing.
			if _body_root != null:
				_body_root.scale.y = 1.0
			for i in _mats.size():
				var m : StandardMaterial3D = _mats[i]
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				var c : Color = _final_cols[i]
				c.a = 0.30 + 0.55 * _frac
				m.albedo_color = c
		_:
			## Bloom / default: grow out of the ground, ghosted until complete.
			if _body_root != null:
				_body_root.scale.y = 0.12 + 0.88 * _frac
			for i in _mats.size():
				var m : StandardMaterial3D = _mats[i]
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				var c : Color = _final_cols[i]
				c.a = 0.5
				m.albedo_color = c

## Upgrade flourish: replay the faction's construction signature for a beat (cosmetic).
func flourish() -> void:
	_flourish_t = FLOURISH_SECS

func _restore() -> void:
	if _body_root != null:
		_body_root.scale.y = 1.0
	for i in _mats.size():
		var m : StandardMaterial3D = _mats[i]
		if m == null:
			continue
		m.albedo_color = _final_cols[i]
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	if _flourish_t <= 0.0:
		if _ring != null:
			_ring.visible = false
		for d in _drones:
			d.visible = false

func _process(delta: float) -> void:
	_t += delta
	if _flourish_t > 0.0:
		_flourish_t = maxf(0.0, _flourish_t - delta)
		if _flourish_t == 0.0 and not _active:
			_restore()
	var fx : bool = _active or _flourish_t > 0.0
	match _faction:
		"architects":
			if _ring == null:
				return
			_ring.visible = fx
			if fx:
				## Carving sweeps down with progress; the flourish replays one full sweep.
				var sweep : float = (_flourish_t / FLOURISH_SECS) if _flourish_t > 0.0 else (1.0 - _frac)
				_ring.position.y = maxf(2.0, _height * sweep)
		"mesh":
			for i in _drones.size():
				var d : MeshInstance3D = _drones[i]
				d.visible = fx
				if fx:
					var a : float = _t * 2.6 + float(i) * TAU / float(DRONE_COUNT)
					var lift : float = _height * (_frac if _active else 0.6)
					d.position = Vector3(
						cos(a) * (_radius + 8.0),
						clampf(lift + sin(_t * 3.1 + float(i)) * 6.0, 4.0, _height + 12.0),
						sin(a) * (_radius + 8.0))
		_:
			## Bloom flourish: one confident swell.
			if _flourish_t > 0.0 and _body_root != null:
				_body_root.scale.y = 1.0 + 0.10 * sin((1.0 - _flourish_t / FLOURISH_SECS) * PI)
