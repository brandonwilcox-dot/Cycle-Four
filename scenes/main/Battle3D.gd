## Battle3D — the 3D battle screen (promoted from scenes/test during the 3D migration; reached via
## Root → TitleScreen → SceneManager.change_to). Owns the live board: faction-select, the FOB/Commander,
## tower/garrison/wall placement + the Commander engineering loop, paced waves, the galaxy deploy/
## capture loop, camera rig, and GameOver. The 2D scenes/main/Battle.tscn remains as a fallback.
## Remaining toward full parity: save/load (Continue), the scripted Academy tutorial, AbilityController.
extends Node3D

const WORLD3D     = preload("res://src/core/World3D.gd")
const CAM_RIG     = preload("res://src/core/CameraRig3D.gd")
const ATMOSPHERE  = preload("res://src/core/BattleAtmosphere.gd")
const UNIT_SCENE     = preload("res://scenes/main/Unit.tscn")
const TOWER_SCENE    = preload("res://scenes/main/Tower.tscn")
const BUILDING_SCENE = preload("res://scenes/main/Building.tscn")
const BUILDING_DATA  = preload("res://src/entities/BuildingData.gd")
const BASE_SCRIPT      = preload("res://src/entities/Base.gd")
const COMMANDER_SCRIPT  = preload("res://src/entities/Commander.gd")
const ENEMY_BASE_SCRIPT = preload("res://src/entities/EnemyBase.gd")
const WALL_SCRIPT       = preload("res://src/entities/Wall.gd")
const MAP_GRID_SCRIPT   = preload("res://src/core/map/MapGrid.gd")
const GALAXY_VIEW       = preload("res://src/ui/GalaxyView.gd")
const HUD_SCENE         = preload("res://scenes/ui/HUD.tscn")
const GAME_OVER_SCENE   = preload("res://scenes/ui/GameOverScreen.tscn")
const TITLE_SCENE       = "res://scenes/ui/TitleScreen.tscn"
const SETTINGS_PATH     = "user://settings.cfg"
const CONTROLS_TEXT     = "LEFT-CLICK  select Commander / tower\nU  upgrade selected tower\nRIGHT-CLICK  move Commander (hold Shift to chain)\nB  build tower        G  build garrison\nBuild Wall button  (Architects only)\n\nPgUp  birds-eye view      PgDn  focus Commander\nWheel  zoom (out far = galaxy map)\nWASD  pan       Q / E  rotate\nMIDDLE-drag  free rotate\nDelete  reset view   Insert  save custom view\n\nGalaxy zoom: LEFT-CLICK a frontier node to deploy\nESC  this menu"
const MAP_GENERATOR     = preload("res://src/core/map/MapGenerator.gd")
## A spread of tiers/branches/roles to show the 3D silhouettes differ.
const DEMO_TOWERS : Array = [
	[preload("res://resources/towers/architects_t1.tres"),  Vector2i(12, 12)],   ## T1 damage
	[preload("res://resources/towers/architects_t2b.tres"), Vector2i(18, 14)],   ## Railgun (1 long barrel)
	[preload("res://resources/towers/bloom_t3.tres"),       Vector2i(22, 20)],   ## gatling + detector antenna
	[preload("res://resources/towers/mesh_t2b.tres"),       Vector2i(26, 22)],   ## Relay Pylon (support halo)
]

## Mirror the real grid constants (MapGrid) so the mapping is exercised at production scale.
const CELL : int = 64
const COLS : int = 60
const ROWS : int = 34
const BASE_CELL : Vector2i = Vector2i(30, 17)

var _rig       : Node3D = null
var _marker    : MeshInstance3D = null
var _marker_target : Vector2 = Vector2.ZERO   ## plane pos of the active move order; marker hides on arrival
var _commander : Node = null

## Stage 6 controls.
const TOWER_DATA = preload("res://resources/towers/architects_t1.tres")
const SELECT_RADIUS : float = 52.0
var _map_grid    : Node = null
var _hud         : Control = null
var _galaxy_view : Node = null
var _deployed_node : String = ""    ## galaxy node currently being fought ("" = home); capture-on-clear target
## Placed-structure tracking (cell → node) for save/load capture. Mirrors the 2D Battle dicts.
var _tower_cells    : Dictionary = {}
var _building_cells : Dictionary = {}
var _wall_cells     : Dictionary = {}
var _selected_tower : Node = null   ## built tower selected for upgrade (U) / inspection
var _selected_building : Node = null   ## garrison currently inspected (for Sell)
var _last_upgrade_t  : float = -1.0   ## debounce: rapid upgrades thrash the free/rebuild cycle
const UPGRADE_COOLDOWN : float = 0.35
var _placing        : bool = false
var _place_building : bool = false   ## true = building/garrison (vs tower)
var _place_wall     : bool = false   ## true = Architect wall (overrides _place_building)
var _preview        : MeshInstance3D = null
var _preview_mat    : StandardMaterial3D = null

## Stage 6c faction-select. id → [sub_path, display name, accent color] (sub-paths match Academy defaults).
const FACTION_CHOICES : Array = [
	["architects", "standard",  "THE ARCHITECTS", "Efficiency. Strongest idle economy.", Color(1.00, 0.55, 0.18)],
	["bloom",      "purist",    "THE BLOOM",      "Adapt. Near-unkillable late game.",    Color(0.45, 0.80, 0.30)],
	["mesh",       "networked", "THE MESH",       "Raid. Steal the enemy's resources.",   Color(0.30, 0.65, 1.00)],
]
var _battle_started : bool = false
var _faction_layer  : CanvasLayer = null
var _pause_layer    : CanvasLayer = null   ## ESC game menu (Save/Load/Settings/Main Menu)
var _menu_open      : bool = false         ## gates gameplay input; freeze via Engine.time_scale (NOT tree pause, which blocks the menu buttons)
var _pause_status   : Label = null         ## in-menu confirmation line (e.g. "Game saved.")

## Stage 6b waves — paced, finite waves with a grace period and rests (not an unending stream).
const SPAWN_INTERVAL : float = 1.6    ## seconds between units within a wave
const WAVE_GRACE     : float = 8.0    ## quiet time before the first wave (build a defense)
const WAVE_REST      : float = 14.0   ## quiet time between waves
const WAVE_SIZE_BASE : int   = 5      ## wave 1 size; +2 each subsequent wave
const MAX_LIVE_ENEMIES : int = 24     ## hard cap on concurrent hostiles — never let the field flood
var _unit_layer  : Node3D = null
var _spawn_cells : Array[Vector2i] = []
var _spawn_idx   : int   = 0
var _wave_num    : int   = 0
var _wave_left   : int   = 0          ## units still to spawn this wave
var _resting     : bool  = true       ## true during grace / between-wave rests
var _wave_timer  : float = WAVE_GRACE

func _ready() -> void:
	EventBus.enemy_base_destroyed.connect(_on_enemy_base_destroyed)   ## capture the deployed territory on clear
	EventBus.game_saving.connect(_capture_territory_development)      ## snapshot dev into the active node before each save
	EventBus.panel_upgrade_requested.connect(_on_panel_upgrade)      ## inspection-panel Upgrade buttons (branch A/B)
	EventBus.panel_sell_requested.connect(_on_panel_sell)           ## inspection-panel Sell button
	EventBus.fob_doctrine_requested.connect(_on_fob_doctrine)       ## inspection-panel FOB doctrine buttons
	_setup_environment()
	_spawn_map_grid()   ## Stage 3: the real MapGrid renders the 3D terrain + drives claim/fog
	_setup_marker()
	_setup_preview()
	_setup_hud()
	_spawn_galaxy()

	_rig = CAM_RIG.new()
	_rig.position = _cell_center3(BASE_CELL, 0.0)   ## look at the FOB to start
	add_child(_rig)

	## Continue (a save was loaded → GameState has a faction) restores straight into the battle;
	## New Game shows the faction-select screen. The world is built in _start_battle() either way.
	if not GameState.current_faction.is_empty():
		_continue_game()
	else:
		_show_faction_select()
	## (Controls used to be an on-map banner; they now live in ESC → Help.)

## EventBus is an autoload that outlives this scene; Load/Continue free + recreate Battle3D, so we MUST
## disconnect here or dead instances accumulate stale connections ("Lambda capture freed" errors + double
## captures across reload cycles).
func _exit_tree() -> void:
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0   ## never leave the engine frozen if we're torn down with the menu open
	for sig_cb in [
		[EventBus.enemy_base_destroyed, _on_enemy_base_destroyed],
		[EventBus.game_saving, _capture_territory_development],
		[EventBus.tower_placement_requested, _on_tower_req],
		[EventBus.building_placement_requested, _on_build_req],
		[EventBus.wall_placement_requested, _on_wall_req],
		[EventBus.panel_upgrade_requested, _on_panel_upgrade],
		[EventBus.panel_sell_requested, _on_panel_sell],
		[EventBus.fob_doctrine_requested, _on_fob_doctrine],
	]:
		if (sig_cb[0] as Signal).is_connected(sig_cb[1]):
			(sig_cb[0] as Signal).disconnect(sig_cb[1])

func _on_tower_req(_td: Resource = null) -> void:
	_place_building = false
	_place_wall = false
	_set_placing(true)

func _on_build_req(_bd: Resource = null) -> void:
	_place_building = true
	_place_wall = false
	_set_placing(true)

func _on_wall_req() -> void:
	_place_wall = true
	_set_placing(true)

## V1: lights + environment (sky/tonemap/glow/fog/SSAO/grade) live in the shared atmosphere
## rig — see src/core/BattleAtmosphere.gd + planning/visual-supercharge-plan.md.
func _setup_environment() -> void:
	add_child(ATMOSPHERE.new())

## Stage 3: instantiate the real MapGrid — it generates a map, renders the 3D terrain (MultiMesh
## tiles colored by cell type + fog), joins the "map_grid" group, and drives claim/reveal/sight for
## the entities. Replaces the old flat placeholder ground + grid overlay.
func _spawn_map_grid() -> void:
	var mg : Node = MAP_GRID_SCRIPT.new()
	mg.name = "MapGrid"
	add_child(mg)
	_map_grid = mg

## Stage 2d: the real Base (FOB) entity at the base cell — 3D bunker, HP bar, turret that
## shoots units in range and takes breach damage when units arrive.
func _spawn_base() -> void:
	var b : Node = BASE_SCRIPT.new()
	b.call("place_at", _cell_center2(BASE_CELL))
	add_child(b)

## Stage 2e: the player Commander (instantiated script-only → no AbilityController, so abilities
## no-op). Auto-attacks enemies, selectable (ground ring), and left-click issues a move order.
func _spawn_commander() -> void:
	_commander = COMMANDER_SCRIPT.new()
	_commander.call("place_at", _cell_center2(Vector2i(28, 17)))
	add_child(_commander)
	_commander.call("set_selected", true)

## Stage 2f: a destructible enemy base near the west spawn — fields mesh-faction defenders (real 3D
## Units) that guard it; the Commander/FOB/towers can grind it down.
func _spawn_enemy_base() -> void:
	_spawn_enemy_base_at(Vector2i(6, 17), "mesh", &"demo_spawn")

func _spawn_enemy_base_at(cell: Vector2i, faction: String, spawn_id: StringName) -> void:
	var eb : Node = ENEMY_BASE_SCRIPT.new()
	eb.call("setup", spawn_id, faction)
	eb.call("place_at", _cell_center2(cell))
	add_child(eb)

## Stage 5: populate a galaxy + add the 3D GalaxyView. Zoom the camera OUT past the galaxy
## threshold (wheel) and the board shrinks away to reveal the 3D territory-node graph.
func _spawn_galaxy() -> void:
	GalaxyManager.ensure_galaxy("architects")
	_galaxy_view = GALAXY_VIEW.new()
	add_child(_galaxy_view)
	_galaxy_view.call("setup", Vector2(COLS * CELL * 0.5, ROWS * CELL * 0.5))

## Stage 2g: a couple of built walls on the enemy approach — enemies grind them to pass.
func _spawn_walls() -> void:
	for cell in [Vector2i(20, 16), Vector2i(20, 18)]:
		var w : Node = WALL_SCRIPT.new()
		w.call("place_at", _cell_center2(cell))
		add_child(w)
		w.call("mark_built")
		_wall_cells[cell] = w

func _setup_marker() -> void:
	_marker = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(CELL * 0.8, CELL * 0.8, CELL * 0.8)
	_marker.mesh = bx
	var mat : StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.25, 0.2)
	_marker.material_override = mat
	_marker.visible = false
	add_child(_marker)

func _process(delta: float) -> void:
	if _menu_open:
		return   ## game menu open — Engine.time_scale=0 already froze movement; skip gameplay logic
	if _placing:
		_update_preview()
	## Stage 6b: paced waves down the map's real A* paths — grace, then bursts separated by rests.
	if not _battle_started:
		return   ## wait for faction-select to build the world
	_update_marker_fade()
	_wave_timer -= delta
	if _resting:
		if _wave_timer <= 0.0:
			_start_next_wave()
		return
	if _wave_left <= 0:
		_resting = true                  ## wave done — rest before the next
		_wave_timer = WAVE_REST
		return
	if _wave_timer <= 0.0:
		## Hard anti-flood cap: if the field is already full of hostiles, hold this spawn (don't
		## consume the wave) until some die. Prevents any runaway/endless on-screen stream.
		if get_tree().get_nodes_in_group("units").size() >= MAX_LIVE_ENEMIES:
			return
		_wave_timer = SPAWN_INTERVAL
		_spawn_one_enemy()
		_wave_left -= 1

## Stage 6 RTS controls: LEFT = select (Commander) or place tower; RIGHT = move (shift-chain) or
## cancel placement; B = toggle tower-build mode; ESC = cancel/deselect. All via 3D ground raycast.
func _unhandled_input(event: InputEvent) -> void:
	if not _battle_started:
		return   ## faction-select still up — no gameplay input yet (camera rig handles its own input)
	## ESC: cancel placement first, else toggle the pause/game menu (works while paused — node is ALWAYS).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _placing:
			_set_placing(false)
		else:
			_toggle_pause_menu()
		return
	if _menu_open:
		return   ## menu open — swallow all other gameplay input
	if event is InputEventMouseButton:
		var mb : InputEventMouseButton = event
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _placing:
				_try_place(_hovered_cell())
				if not Input.is_key_pressed(KEY_SHIFT):
					_set_placing(false)
			elif bool(_rig.call("is_galaxy_zoom")):
				_try_deploy(_mouse_ground())   ## zoomed out → click a frontier node to deploy
			else:
				_left_click(_mouse_ground())
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if _placing:
				_set_placing(false)
			elif is_instance_valid(_commander) and bool(_commander.call("is_selected")):
				var g : Vector2 = _mouse_ground()
				if WORLD3D.is_valid(g):
					g = _clamp_to_map(g)   ## keep move orders inside the play area (ray hits the infinite plane)
					_commander.call("move_command", g, Input.is_key_pressed(KEY_SHIFT))
					_flash_marker(g)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k : InputEventKey = event
		if k.keycode == KEY_B:
			if _placing and not _place_building and not _place_wall:
				_set_placing(false)
			else:
				_place_building = false
				_place_wall = false
				_set_placing(true)
		elif k.keycode == KEY_G:
			if _placing and _place_building:
				_set_placing(false)
			else:
				_place_building = true
				_place_wall = false
				_set_placing(true)
		elif k.keycode == KEY_U:
			_try_upgrade_selected_tower()
		elif k.keycode == KEY_PAGEUP:
			## Birds-eye centered on the map.
			_rig.call("snap_birdseye", Vector3(COLS * CELL * 0.5, 0.0, ROWS * CELL * 0.5), float(COLS * CELL) * 0.9)
		elif k.keycode == KEY_PAGEDOWN:
			## Focus the Commander; frame ~its sensor range.
			if is_instance_valid(_commander):
				var sr : float = float(_commander.call("get_sensor_radius"))
				_rig.call("snap_focus", WORLD3D.to3(_commander.call("plane_pos"), 0.0), sr * 2.0)
		elif k.keycode == KEY_ESCAPE:
			pass   ## ESC handled at the top of _unhandled_input (pause menu)

## -- RTS control helpers (Stage 6) --

func _mouse_ground() -> Vector2:
	var cam : Camera3D = _rig.call("get_camera")
	return WORLD3D.ground_point(cam, get_viewport().get_mouse_position(), 0.0)

## Clamp a plane point to the playfield (with a half-cell inset) so the ray-vs-infinite-plane pick
## can't send the Commander off the board.
func _clamp_to_map(v2: Vector2) -> Vector2:
	var lo : float = CELL * 0.5
	return Vector2(
		clampf(v2.x, lo, COLS * CELL - lo),
		clampf(v2.y, lo, ROWS * CELL - lo))

func _hovered_cell() -> Vector2i:
	var g : Vector2 = _mouse_ground()
	if not WORLD3D.is_valid(g):
		return Vector2i(-1, -1)
	return Vector2i(int(clampf(floor(g.x / CELL), 0, COLS - 1)), int(clampf(floor(g.y / CELL), 0, ROWS - 1)))

## LEFT-click dispatch: open the stats inspection panel for whatever's under the cursor
## (tower → also selectable for upgrade; garrison; FOB; unit), else select/deselect the Commander.
func _left_click(world2: Vector2) -> void:
	_selected_building = null
	var t : Node = _tower_at(world2)
	if t != null:
		_selected_tower = t
		if is_instance_valid(_commander):
			_commander.call("set_selected", false)
		if _hud != null:
			_hud.call("open_tower_inspection", t, true)
		return
	_selected_tower = null
	var b : Node = _building_at(world2)
	if b != null:
		_selected_building = b
		if _hud != null:
			_hud.call("open_building_inspection", b)
		return
	var fob : Node = _fob_at(world2)
	if fob != null:
		if _hud != null:
			_hud.call("open_fob_inspection", fob)
		return
	var u : Node = _unit_at(world2)
	if u != null:
		if _hud != null:
			_hud.call("open_unit_inspection", u)
		return
	## Empty ground: select/deselect the Commander (which opens/closes its stat panel).
	_select_at(world2)

## Nearest node in `group` within `radius` of a plane point (optionally must be built). null if none.
func _nearest_in_group(world2: Vector2, group: String, radius: float, must_be_built: bool) -> Node:
	if not WORLD3D.is_valid(world2):
		return null
	var best   : Node  = null
	var best_d : float = radius
	for n in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(n):
			continue
		if must_be_built and n.has_method("is_built") and not bool(n.call("is_built")):
			continue
		var d : float = world2.distance_to(n.call("plane_pos"))
		if d <= best_d:
			best_d = d
			best   = n
	return best

func _tower_at(world2: Vector2) -> Node:
	return _nearest_in_group(world2, "towers", 36.0, true)

func _building_at(world2: Vector2) -> Node:
	return _nearest_in_group(world2, "buildings", 40.0, false)

func _fob_at(world2: Vector2) -> Node:
	return _nearest_in_group(world2, "base", 56.0, false)

## Nearest unit (enemy or friendly) under the cursor.
func _unit_at(world2: Vector2) -> Node:
	var e : Node = _nearest_in_group(world2, "units", 34.0, false)
	if e != null:
		return e
	return _nearest_in_group(world2, "friendly_units", 34.0, false)

## U key: quick-upgrade the selected tower on branch A (debounced against the free/rebuild churn).
func _try_upgrade_selected_tower() -> void:
	if not is_instance_valid(_selected_tower):
		return
	## Debounce: upgrade() frees + rebuilds the whole tower visual; rapid repeats thrash that cycle
	## (the known rapid-interaction hang). Ignore presses inside the cooldown.
	var now : float = Time.get_ticks_msec() / 1000.0
	if now - _last_upgrade_t < UPGRADE_COOLDOWN:
		return
	_last_upgrade_t = now
	_do_upgrade(0)

## Upgrade the selected tower on branch (0 = A / upgrade_to, 1 = B / upgrade_to_b), charging its cost.
func _do_upgrade(branch: int) -> void:
	if not is_instance_valid(_selected_tower):
		return
	if not bool(_selected_tower.call("is_built")):
		EventBus.notification_pushed.emit("Finish building the tower first.", "warning")
		return
	var d : Resource = _selected_tower.get("data")
	var nxt : Resource = null
	if d != null:
		nxt = d.get("upgrade_to_b") if branch == 1 else d.get("upgrade_to")
	if nxt == null:
		EventBus.notification_pushed.emit("Tower is at its max tier.", "warning")
		return
	var primary : String = FactionManager.get_primary_resource()
	var cost : float = float(nxt.get("primary_cost")) if nxt.get("primary_cost") != null else 0.0
	if not EconomyManager.can_afford({primary: cost}):
		EventBus.notification_pushed.emit("Not enough %s to upgrade (need %d)." % [primary, int(cost)], "warning")
		return
	EconomyManager.spend({primary: cost})
	_selected_tower.call("upgrade", nxt)
	EventBus.notification_pushed.emit("Tower upgraded to %s." % str(nxt.get("tower_name")), "positive")

## -- Inspection-panel button handlers --

func _on_panel_upgrade(branch: int) -> void:
	_do_upgrade(branch)

func _on_panel_sell() -> void:
	var primary : String = FactionManager.get_primary_resource()
	if is_instance_valid(_selected_tower):
		var d : Resource = _selected_tower.get("data")
		var refund : float = floorf(float(d.get("primary_cost")) * 0.5) if d != null and d.get("primary_cost") != null else 0.0
		EconomyManager.add_resource(primary, refund)
		var cell : Vector2i = _map_grid.call("world_to_cell", _selected_tower.call("plane_pos"))
		_map_grid.call("unmark_tower", cell.x, cell.y)
		_tower_cells.erase(cell)
		_selected_tower.queue_free()
		_selected_tower = null
		EventBus.notification_pushed.emit("Tower sold — refunded %d %s." % [int(refund), primary], "positive")
	elif is_instance_valid(_selected_building):
		var cell : Vector2i = _map_grid.call("world_to_cell", _selected_building.call("plane_pos"))
		_building_cells.erase(cell)
		if _selected_building.has_method("destroy"):
			_selected_building.call("destroy")   ## reverses territory income + frees
		else:
			_selected_building.queue_free()
		_selected_building = null
		EventBus.notification_pushed.emit("Garrison sold.", "positive")
	if _hud != null:
		_hud.call("close_inspection")

func _on_fob_doctrine(doctrine_id: String) -> void:
	var base : Node = get_tree().get_first_node_in_group("base")
	if base == null or not base.has_method("set_doctrine"):
		return
	var primary : String = FactionManager.get_primary_resource()
	var cost : float = 60.0
	if not EconomyManager.can_afford({primary: cost}):
		EventBus.notification_pushed.emit("Not enough %s for an FOB doctrine (need %d)." % [primary, int(cost)], "warning")
		return
	EconomyManager.spend({primary: cost})
	base.call("set_doctrine", doctrine_id)
	EventBus.notification_pushed.emit("FOB doctrine set: %s." % doctrine_id.capitalize(), "positive")
	if _hud != null:
		_hud.call("open_fob_inspection", base)   ## refresh the panel

## Select the Commander if the click landed within SELECT_RADIUS of it, else deselect.
func _select_at(world2: Vector2) -> void:
	if not is_instance_valid(_commander):
		return
	var hit : bool = WORLD3D.is_valid(world2) and world2.distance_to(_commander.call("plane_pos")) <= SELECT_RADIUS
	_commander.call("set_selected", hit)
	if _hud != null:
		if hit:
			_hud.call("open_commander_inspection", _commander)
		else:
			_hud.call("close_inspection")

## Place an (unbuilt) tower or building at the hovered cell if the map allows it; the Commander builds it.
func _try_place(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1) or _map_grid == null:
		return
	if not bool(_map_grid.call("can_place_at", cell.x, cell.y)):
		return
	if _place_wall:
		var w : Node = WALL_SCRIPT.new()
		w.call("place_at", _cell_center2(cell))   ## inert — the Commander raises it (engineering)
		add_child(w)
		_wall_cells[cell] = w
	elif _place_building:
		## Use the faction's starter garrison (.tres) so it has a resource_path → persistable on save.
		var bd : Resource = FactionManager.get_starter_building()
		if bd == null:
			bd = BUILDING_DATA.new()
			bd.building_name = "Garrison"
			bd.color_hint = Color(0.55, 0.75, 0.95)
			bd.income_rate = 0.5
		var b : Node = BUILDING_SCENE.instantiate()
		b.call("setup", bd, false)        ## unbuilt — Commander constructs it
		b.call("place_at", _cell_center2(cell))
		add_child(b)
		_building_cells[cell] = b
	else:
		var t : Node = TOWER_SCENE.instantiate()
		t.call("setup", TOWER_DATA, false)   ## unbuilt — the Commander constructs it
		t.call("place_at", _cell_center2(cell))
		add_child(t)
		_map_grid.call("mark_tower_placed", cell.x, cell.y)
		_tower_cells[cell] = t

func _set_placing(value: bool) -> void:
	_placing = value
	if _preview != null:
		_preview.visible = value
	if value:
		_update_preview()
	elif _hud != null:
		_hud.call("end_placement_mode")   ## unlock the HUD build buttons when placement ends

func _update_preview() -> void:
	if _preview == null:
		return
	var cell : Vector2i = _hovered_cell()
	if cell == Vector2i(-1, -1):
		_preview.visible = false
		return
	_preview.visible = true
	_preview.position = _cell_center3(cell, 6.0)
	var ok : bool = _map_grid != null and bool(_map_grid.call("can_place_at", cell.x, cell.y))
	_preview_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.5) if ok else Color(1.0, 0.3, 0.25, 0.5)

## Stage 6c: pick a faction so active_faction is set — lights up the HUD's faction resources +
## build buttons + tower upgrades AND lets garrisons resolve their roster unit. (architects/standard;
## the real game routes this through the FactionSelect screen — wired here so the battle plays.)
## Stage 6c faction-select screen: a simple full-screen chooser shown before the battle. Picking a
## faction selects it (with its default sub-path), then builds the world via _start_battle().
func _show_faction_select() -> void:
	_faction_layer = CanvasLayer.new()
	add_child(_faction_layer)

	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_faction_layer.add_child(bg)

	var col : VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_faction_layer.add_child(col)

	var heading : Label = Label.new()
	heading.text = "CHOOSE YOUR FACTION"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	col.add_child(heading)

	for choice in FACTION_CHOICES:
		var btn : Button = Button.new()
		btn.custom_minimum_size = Vector2(440.0, 78.0)
		btn.text = "%s\n%s" % [choice[2], choice[3]]
		btn.add_theme_color_override("font_color", choice[4])
		btn.add_theme_font_size_override("font_size", 22)
		var fid : String = choice[0]
		var sub : String = choice[1]
		btn.pressed.connect(func() -> void: _choose_faction(fid, sub))
		col.add_child(btn)

## Commit the chosen faction and start the battle.
func _choose_faction(faction_id: String, sub_path: String) -> void:
	FactionManager.select_faction(faction_id, sub_path)
	## Demo convenience: seed resources so the HUD build button is affordable immediately (the real
	## game earns these by claiming territory through the Academy ramp).
	EconomyManager.add_resource(FactionManager.get_primary_resource(), 400.0)
	if is_instance_valid(_faction_layer):
		_faction_layer.queue_free()
		_faction_layer = null
	_start_battle()

## Continue: a save was loaded (faction/economy/galaxy already restored by SaveManager). Restore the
## faction listeners, load the active node's seeded map, and start the battle without demo clutter.
## (Development restore — saved towers/buildings/walls/claims/FOB rank — is the next save/load increment.)
func _continue_game() -> void:
	FactionManager.restore_faction(GameState.current_faction, GameState.current_sub_path)
	var node_id : String = GalaxyManager.active_node
	if node_id != "" and GalaxyManager.star_systems.has(node_id):
		var seed_v : int = int(GalaxyManager.star_systems[node_id].get("seed", 0))
		_map_grid.call("load_map_data", MAP_GENERATOR.generate(seed_v))
		_map_grid.call("queue_redraw")
	_start_battle(true)
	## Re-place the saved development (claims, towers, garrisons, walls, FOB rank) onto the loaded map.
	if node_id != "" and GalaxyManager.star_systems.has(node_id):
		_restore_territory_development(GalaxyManager.star_systems[node_id].get("development", {}))
	EventBus.notification_pushed.emit("Game restored.", "positive")

## -- ESC pause / game menu (Save / Load / Settings / Main Menu) --

func _toggle_pause_menu() -> void:
	if _pause_layer != null:
		_close_pause_menu()
	else:
		_open_pause_menu()

func _open_pause_menu() -> void:
	_menu_open = true
	Engine.time_scale = 0.0   ## freeze all delta-based motion; input/GUI is unaffected, so buttons work
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 50
	add_child(_pause_layer)
	var bg : ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.07, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(bg)
	_build_pause_main()

func _close_pause_menu() -> void:
	_menu_open = false
	Engine.time_scale = 1.0
	if is_instance_valid(_pause_layer):
		_pause_layer.queue_free()
	_pause_layer = null

## Frees the current menu column (keeps the dim background) so we can swap main ⇄ settings.
func _pause_column(title_text: String) -> VBoxContainer:
	for c in _pause_layer.get_children():
		if c is VBoxContainer:
			c.free()
	var col : VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_layer.add_child(col)
	var title : Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	col.add_child(title)
	return col

func _menu_button(text: String, cb: Callable) -> Button:
	var b : Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300.0, 46.0)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b

func _build_pause_main() -> void:
	var col : VBoxContainer = _pause_column("PAUSED")
	_pause_status = Label.new()
	_pause_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	col.add_child(_pause_status)
	col.add_child(_menu_button("Resume", _close_pause_menu))
	col.add_child(_menu_button("Save Game", _pause_save))
	col.add_child(_menu_button("Load Game", _pause_load))
	col.add_child(_menu_button("Help", _build_pause_help))
	col.add_child(_menu_button("Settings", _build_pause_settings))
	col.add_child(_menu_button("Return to Main Menu", _pause_main_menu))

func _build_pause_help() -> void:
	var col : VBoxContainer = _pause_column("CONTROLS")
	var lbl : Label = Label.new()
	lbl.text = CONTROLS_TEXT
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(lbl)
	col.add_child(_menu_button("Back", _build_pause_main))

func _build_pause_settings() -> void:
	var col : VBoxContainer = _pause_column("SETTINGS")
	var vlabel : Label = Label.new()
	vlabel.text = "Master Volume"
	vlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(vlabel)
	var vol : HSlider = HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.01
	vol.custom_minimum_size = Vector2(300.0, 24.0)
	var bus : int = AudioServer.get_bus_index("Master")
	vol.value = db_to_linear(AudioServer.get_bus_volume_db(bus)) if bus >= 0 and not AudioServer.is_bus_mute(bus) else (1.0 if bus >= 0 else 1.0)
	vol.value_changed.connect(_on_pause_volume_changed)
	col.add_child(vol)
	var fs : CheckButton = CheckButton.new()
	fs.text = "Fullscreen"
	var mode : int = DisplayServer.window_get_mode()
	fs.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	fs.toggled.connect(_on_pause_fullscreen_toggled)
	col.add_child(fs)
	col.add_child(_menu_button("Back", _build_pause_main))

func _pause_save() -> void:
	SaveManager.save_game()
	if _pause_status != null:
		_pause_status.text = "Game saved."

func _pause_load() -> void:
	if not SaveManager.has_save():
		EventBus.notification_pushed.emit("No save to load.", "warning")
		return
	_menu_open = false
	Engine.time_scale = 1.0
	SaveManager.load_game()
	get_tree().reload_current_scene()   ## re-runs _ready → _continue_game restores faction + dev

func _pause_main_menu() -> void:
	_menu_open = false
	Engine.time_scale = 1.0
	SceneManager.change_to(TITLE_SCENE)

func _on_pause_volume_changed(value: float) -> void:
	var bus : int = AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(value, 0.0001, 1.0)))
		AudioServer.set_bus_mute(bus, value <= 0.0001)
	_save_pause_settings()

func _on_pause_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_MAXIMIZED)
	_save_pause_settings()

## Persist to the same user://settings.cfg the TitleScreen reads (audio/master_volume, display/fullscreen).
func _save_pause_settings() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var bus : int = AudioServer.get_bus_index("Master")
	if bus >= 0:
		var lin : float = 0.0 if AudioServer.is_bus_mute(bus) else db_to_linear(AudioServer.get_bus_volume_db(bus))
		cfg.set_value("audio", "master_volume", lin)
	var mode : int = DisplayServer.window_get_mode()
	cfg.set_value("display", "fullscreen", mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	cfg.save(SETTINGS_PATH)

## Build the faction-dependent world (units/base/commander/enemy/waves). On a fresh start it also
## drops the demo towers/garrison; a restored game skips those (saved development restores instead).
func _start_battle(restored: bool = false) -> void:
	if _battle_started:
		return
	_battle_started = true
	_setup_unit_layer()    ## must exist before garrisons _ready (their friendly units spawn here)
	_spawn_base()
	_spawn_commander()
	_spawn_enemy_base()
	if not restored:
		## Clean playtest: NO demo towers/garrisons/walls. A fresh game starts empty — just the FOB,
		## Commander, and one enemy base — so the player builds everything and saves contain only real
		## progress (no showcase clutter polluting save/load).
		## Seed reconcile (fresh start): pin the home node's seed to the map actually generated, so a
		## later Continue regenerates this exact map and the saved cells line up.
		if GalaxyManager.active_node != "" and GalaxyManager.star_systems.has(GalaxyManager.active_node):
			var md : MapData = _map_grid.map_data
			if md != null:
				GalaxyManager.star_systems[GalaxyManager.active_node]["seed"] = int(md.map_seed)
	_setup_waves()

## Friendly units (garrison defenders) live here; tagged "unit_layer" so a Building can resolve it
## by group (its hardcoded ../../UnitLayer path doesn't hold in the 3D scene layout).
func _setup_unit_layer() -> void:
	_unit_layer = Node3D.new()
	_unit_layer.name = "UnitLayer"
	_unit_layer.add_to_group("unit_layer")
	add_child(_unit_layer)

## Stage 6c: overlay the real HUD (a Control) on a CanvasLayer above the 3D viewport. It's
## EventBus-driven (resources / waves / notifications / objectives), so it displays live with no
## controller wiring. The build button needs the faction-select flow (deeper 6c); meanwhile we connect
## its placement signal to our 3D placement mode and keep the B key.
func _setup_hud() -> void:
	var cl : CanvasLayer = CanvasLayer.new()
	add_child(cl)
	_hud = HUD_SCENE.instantiate()
	cl.add_child(_hud)
	## HUD build buttons → 3D placement mode (tower / garrison / Architect wall).
	EventBus.tower_placement_requested.connect(_on_tower_req)
	EventBus.building_placement_requested.connect(_on_build_req)
	EventBus.wall_placement_requested.connect(_on_wall_req)
	## Game-over overlay — self-wires to base_destroyed, shows itself, Try Again / Menu reload the scene.
	cl.add_child(GAME_OVER_SCENE.instantiate())

func _setup_preview() -> void:
	_preview = MeshInstance3D.new()
	var bx : BoxMesh = BoxMesh.new()
	bx.size = Vector3(CELL * 0.9, 8.0, CELL * 0.9)
	_preview.mesh = bx
	_preview_mat = StandardMaterial3D.new()
	_preview_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.5)
	_preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview.material_override = _preview_mat
	_preview.visible = false
	add_child(_preview)

## Brief flash at a Commander move order.
func _flash_marker(world2: Vector2) -> void:
	if _marker == null:
		return
	_marker.position = WORLD3D.to3(world2, CELL * 0.3)
	_marker.visible = true
	_marker_target = world2

## Hide the move-order marker once the Commander has reached (or nearly reached) the target.
func _update_marker_fade() -> void:
	if _marker == null or not _marker.visible or not is_instance_valid(_commander):
		return
	if _commander.call("plane_pos").distance_to(_marker_target) <= CELL * 0.6:
		_marker.visible = false

func _cell_center3(cell: Vector2i, height: float) -> Vector3:
	return WORLD3D.to3(_cell_center2(cell), height)

func _cell_center2(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)

## Stage 6b: real waves — collect the map's spawn cells and trickle enemies down their A* paths.
func _setup_waves() -> void:
	_collect_spawns()

## (Re)reads the current map's spawn cells for the wave driver — also after a galaxy deploy.
func _collect_spawns() -> void:
	_spawn_cells.clear()
	_spawn_idx = 0
	_reset_waves()   ## restart the wave cadence (grace period) for the new map
	var md : MapData = _map_grid.map_data if _map_grid != null else null
	if md != null:
		for sp in md.spawn_points:
			if sp != null:
				_spawn_cells.append(sp.position)

## Stage 6c: galaxy deploy — when zoomed out, click a frontier node to load that territory's seeded
## map and drop back onto the battlefield. (Capture-on-win is a follow-up; this is the deploy nav.)
func _try_deploy(world2: Vector2) -> void:
	if _galaxy_view == null or not WORLD3D.is_valid(world2) or _map_grid == null:
		return
	var id : String = _galaxy_view.call("node_at", world2)
	if id == "":
		return
	if not (id in GalaxyManager.frontier(FactionManager.active_faction)):
		EventBus.notification_pushed.emit("That territory isn't on your frontier.", "warning")
		return
	_capture_territory_development()         ## snapshot the territory we're leaving before switching
	var seed_v : int = int(GalaxyManager.star_systems[id].get("seed", 0))
	_map_grid.call("load_map_data", MAP_GENERATOR.generate(seed_v))
	_map_grid.call("queue_redraw")          ## recolor the 3D terrain from the new map
	GalaxyManager.active_node = id
	_collect_spawns()                        ## new map → new spawn cells for the wave driver
	_reset_battlefield()                     ## fresh territory: clear forces, reset Commander to base
	_restore_territory_development(GalaxyManager.star_systems[id].get("development", {}))   ## re-place saved dev
	_deployed_node = id
	## A fresh enemy base to destroy = the capture condition for this territory (skip if already captured).
	if not _spawn_cells.is_empty() and GalaxyManager.star_systems[id].get("owner", "") != FactionManager.active_faction:
		var owner_fac : String = str(GalaxyManager.star_systems[id].get("owner", "mesh"))
		_spawn_enemy_base_at(_spawn_cells[0], owner_fac, StringName("deploy_%s" % id))
	if _galaxy_view.has_method("queue_redraw"):
		_galaxy_view.call("queue_redraw")    ## recenter the graph on the new active node
	_rig.call("snap_focus", Vector3(COLS * CELL * 0.5, 0.0, ROWS * CELL * 0.5), 1600.0)
	EventBus.notification_pushed.emit("Deployed to territory %s — destroy its base to capture it." % id, "positive")

## Clears all transient combat entities and returns the Commander to base — a clean fight per territory.
func _reset_battlefield() -> void:
	for n in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(n):
			if n.has_method("destroy"):
				n.call("destroy")   ## reverses territory income before freeing
			else:
				n.queue_free()
	for grp in ["towers", "friendly_units", "units", "walls", "enemy_bases"]:
		for n in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(n):
				n.queue_free()
	_selected_tower = null
	_tower_cells.clear()
	_building_cells.clear()
	_wall_cells.clear()
	if _marker != null:
		_marker.visible = false
	if is_instance_valid(_commander):
		var start2 : Vector2 = _cell_center2(Vector2i(28, 17))
		_commander.call("place_at", start2)
		_commander.call("move_command", start2, false)   ## clear queued orders / stop here
		_commander.call("set_selected", true)

## Capture-on-clear: destroying the deployed territory's enemy base flips it to the player.
func _on_enemy_base_destroyed(_spawn_id: StringName) -> void:
	if _deployed_node == "":
		return   ## home/demo base — not a deploy target
	var node_id : String = _deployed_node
	_deployed_node = ""
	GalaxyManager.capture_system(node_id, FactionManager.active_faction)
	if _galaxy_view != null and _galaxy_view.has_method("queue_redraw"):
		_galaxy_view.call("queue_redraw")
	EventBus.notification_pushed.emit("Territory %s captured!" % node_id, "positive")

## -- save/load: per-territory development capture/restore (port of the 2D Battle.gd helpers) --

## [game_saving] Snapshot the active territory's development (claims, towers, garrisons, walls, FOB
## rank) into GalaxyManager so SaveManager persists it inside the galaxy block.
func _capture_territory_development() -> void:
	if not _battle_started:
		return
	var node_id : String = GalaxyManager.active_node
	if node_id.is_empty() or not GalaxyManager.star_systems.has(node_id):
		return
	var dev : Dictionary = GalaxyManager.star_systems[node_id].get("development", {})
	dev["claimed"]   = _map_grid.call("get_claimed_indices")
	dev["revealed"]  = _map_grid.call("get_revealed_indices")   ## fog-of-war the player uncovered
	dev["towers"]    = _capture_towers()
	dev["buildings"] = _capture_buildings()
	dev["walls"]     = _capture_walls()
	dev["fob"]       = _capture_fob()
	dev["commander"] = {"claimed": int(_commander.call("get_claimed_count"))} if is_instance_valid(_commander) else {}
	GalaxyManager.star_systems[node_id]["development"] = dev

func _capture_towers() -> Array:
	var out : Array = []
	for cell in _tower_cells:
		var t = _tower_cells[cell]
		if not is_instance_valid(t):
			continue
		var td = t.get("data")
		if td == null or String(td.resource_path).is_empty():
			continue
		out.append({"id": String(td.resource_path), "cell": [int(cell.x), int(cell.y)], "level": int(t.get("level"))})
	return out

func _capture_buildings() -> Array:
	var out : Array = []
	for cell in _building_cells:
		var b = _building_cells[cell]
		if not is_instance_valid(b):
			continue
		var bd = b.get("data")
		if bd == null or String(bd.resource_path).is_empty():
			continue   ## runtime-built data (no path) isn't restorable — skip
		out.append({"id": String(bd.resource_path), "cell": [int(cell.x), int(cell.y)], "level": int(b.get("_level"))})
	return out

func _capture_walls() -> Array:
	var out : Array = []
	for cell in _wall_cells:
		if is_instance_valid(_wall_cells[cell]):
			out.append([int(cell.x), int(cell.y)])
	return out

func _capture_fob() -> Dictionary:
	var b : Node = get_tree().get_first_node_in_group("base")
	if b == null:
		return {}
	return {"rank": int(b.get("_fortification_rank"))}

## Re-apply a territory's saved development onto the freshly-loaded map. Towers/garrisons/walls come
## back already BUILT (the Commander already raised them in the saved session).
func _restore_territory_development(dev: Dictionary) -> void:
	var n_towers : int = 0
	var n_builds : int = 0
	var n_walls  : int = 0
	var claims : Array = dev.get("claimed", [])
	if not claims.is_empty():
		_map_grid.call("apply_claimed_indices", claims)
	var revealed : Array = dev.get("revealed", [])
	if not revealed.is_empty():
		_map_grid.call("apply_revealed_indices", revealed)   ## restore explored fog-of-war
	var cmd : Dictionary = dev.get("commander", {})
	if is_instance_valid(_commander) and cmd.has("claimed"):
		_commander.call("restore_progress", int(cmd.get("claimed", 0)))
	for trec in dev.get("towers", []):
		if typeof(trec) != TYPE_DICTIONARY:
			continue
		var tdata : Resource = load(String(trec.get("id", "")))
		var tcell : Array = trec.get("cell", [])
		if tdata != null and tcell.size() == 2:
			var cell : Vector2i = Vector2i(int(tcell[0]), int(tcell[1]))
			var t : Node = TOWER_SCENE.instantiate()
			t.call("setup", tdata, true)   ## restored = already built
			t.call("place_at", _cell_center2(cell))
			add_child(t)
			_map_grid.call("mark_tower_placed", cell.x, cell.y)
			_tower_cells[cell] = t
			if int(trec.get("level", 1)) > 1:
				t.call("restore_level", int(trec.get("level", 1)))
			n_towers += 1
	for brec in dev.get("buildings", []):
		if typeof(brec) != TYPE_DICTIONARY:
			continue
		var bdata : Resource = load(String(brec.get("id", "")))
		var bcell : Array = brec.get("cell", [])
		if bdata != null and bcell.size() == 2:
			var cell : Vector2i = Vector2i(int(bcell[0]), int(bcell[1]))
			var b : Node = BUILDING_SCENE.instantiate()
			b.call("setup", bdata, true)   ## restored = built, income already in restored rates
			b.call("place_at", _cell_center2(cell))
			add_child(b)
			if int(brec.get("level", 1)) > 1:
				b.set("_level", int(brec.get("level", 1)))
			_building_cells[cell] = b
			n_builds += 1
	for wrec in dev.get("walls", []):
		if typeof(wrec) != TYPE_ARRAY or (wrec as Array).size() != 2:
			continue
		var wcell : Vector2i = Vector2i(int(wrec[0]), int(wrec[1]))
		var w : Node = WALL_SCRIPT.new()
		w.call("place_at", _cell_center2(wcell))
		add_child(w)
		w.call("mark_built")
		_wall_cells[wcell] = w
		n_walls += 1
	var fob : Dictionary = dev.get("fob", {})
	if int(fob.get("rank", 0)) > 0:
		var base : Node = get_tree().get_first_node_in_group("base")
		if base != null and base.has_method("restore_rank"):
			base.call("restore_rank", int(fob.get("rank", 0)))
	_map_grid.call("queue_redraw")   ## recolor terrain so restored CLAIMED cells show
	EventBus.notification_pushed.emit(
		"Restored: %d towers, %d garrisons, %d walls, %d claimed cells." % [n_towers, n_builds, n_walls, claims.size()],
		"positive")

## Begin the next wave: size grows each wave; announce it.
func _start_next_wave() -> void:
	_wave_num += 1
	_wave_left = WAVE_SIZE_BASE + (_wave_num - 1) * 2
	_resting = false
	_wave_timer = 0.0   ## first unit of the wave spawns right away
	EventBus.notification_pushed.emit("Wave %d incoming — %d hostiles." % [_wave_num, _wave_left], "warning")

## Reset the wave cadence (fresh battle / after a galaxy deploy): grace period, wave 1 next.
func _reset_waves() -> void:
	_wave_num   = 0
	_wave_left  = 0
	_resting    = true
	_wave_timer = WAVE_GRACE

func _spawn_one_enemy() -> void:
	if _spawn_cells.is_empty() or _map_grid == null:
		return
	var cell : Vector2i = _spawn_cells[_spawn_idx % _spawn_cells.size()]
	_spawn_idx += 1
	var wp : Array = _map_grid.call("get_path_to_base", cell)
	if wp.is_empty():
		return
	var u : Node = UNIT_SCENE.instantiate()
	u.call("setup", _enemy_data(), wp)
	_unit_layer.add_child(u)

func _enemy_data() -> UnitData:
	var ud : UnitData = UnitData.new()
	ud.unit_name = "Raider"
	ud.faction_id = "mesh"
	ud.max_health = 60.0
	ud.move_speed = 95.0
	ud.color_hint = Color(0.85, 0.45, 0.95)
	return ud

## Stage 2b demo: place converted Towers (built) along the path so they shoot the marching units —
## a mini 3D battle that exercises the real Tower logic + the 3D stat-driven silhouettes.
func _spawn_demo_towers() -> void:
	for entry in DEMO_TOWERS:
		var t : Node = TOWER_SCENE.instantiate()
		t.call("setup", entry[0], true)            ## start_built so it attacks immediately
		t.call("place_at", _cell_center2(entry[1]))
		add_child(t)
		_map_grid.call("mark_tower_placed", int(entry[1].x), int(entry[1].y))
		_tower_cells[entry[1]] = t

## Stage 2c demo: place one converted Building (garrison) to show its 3D mesh. Inert here (no
## faction/unit-layer), so it just demonstrates the structure; production lights up post-FriendlyUnit.
func _spawn_demo_building() -> void:
	var bd : BuildingData = BUILDING_DATA.new()
	bd.building_name = "Demo Garrison"
	bd.color_hint = Color(0.55, 0.75, 0.95)
	var b : Node = BUILDING_SCENE.instantiate()
	b.call("setup", bd, true)                       ## restored=true → built/solid, no economy side effects
	b.call("place_at", _cell_center2(Vector2i(16, 20)))
	add_child(b)
	_building_cells[Vector2i(16, 20)] = b           ## runtime BuildingData has no resource_path → capture skips it
