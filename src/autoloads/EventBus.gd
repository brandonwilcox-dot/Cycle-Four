## EventBus.gd
## Global signal bus. All cross-system communication goes through here.
## Keeps systems decoupled -- nothing imports another system directly.
## Usage: EventBus.economy_tick.emit(delta)
extends Node

# -- Economy --
signal resource_changed(faction: String, resource: String, amount: float)
signal idle_tick(delta: float)
signal offline_catch_up(seconds_elapsed: float)

# -- Waves --
signal wave_started(wave_number: int, commander_data: Dictionary)
signal wave_ended(wave_number: int, result: String)
signal wave_axis_committed(axis_weights: Dictionary)       ## spawn_id → unit_count; emitted before first spawn
signal wave_composition_committed(unit_name: String, count: int)  ## unit type + total count for the incoming wave
signal unit_spawned(unit_data: Dictionary)
signal unit_died(unit_data: Dictionary)
signal wave_flank_triggered(wave_number: int)  ## Scripted secondary-axis probe fired
signal base_damaged(amount: float, attacker_data: Dictionary)
signal base_healed(amount: float)           ## Bloom Overdrive / Verdant Bulwark FOB regen
signal base_destroyed()                     ## base HP reached zero; triggers game-over
signal enemy_count_changed(remaining: int)  ## fires on each kill/breach; HUD enemy counter

# -- Tower Defense --
signal tower_placement_requested(tower_data: Resource)     ## HUD -> Main: enter tower placement
signal tower_placed(tower_data: Resource, grid_pos: Vector2i)
signal path_changed  ## Emitted by Main when a tower blocks a PATH cell; units reroute
signal building_placement_requested(building_data: Resource) ## HUD -> Main: enter build mode
signal building_placed(building_data: Resource, grid_pos: Vector2i)
signal building_destroyed(building_data: Resource, grid_pos: Vector2i)
signal building_sold(building_data: Dictionary, grid_pos: Vector2i)
signal building_upgraded(building_data: Dictionary, tier: int)

# -- Commander --
signal territory_claimed(cell: Vector2i)     ## Commander stepped onto a new GROUND cell
signal territory_raided(cell: Vector2i)      ## Flanker successfully unclaimed a cell
signal spawn_activated(spawn_id: StringName) ## A previously-dormant spawn became active (Phase 4+: spawn_id, not cell)
signal region_revealed(cells: Array[Vector2i]) ## Phase 6: fog-of-war reveal — list of newly-visible cells
signal path_discovered(edge_id: StringName)    ## Phase 7: an ancient PathEdge transitioned to discovered=true
signal region_sensed(cells: Array[Vector2i])   ## Sensor ring: cells detected but not yet revealed

# -- Convoys (Phase 8+) --
signal convoy_spawned(convoy_id: StringName, from_node: StringName, to_node: StringName)
signal convoy_arrived(convoy_id: StringName, to_node: StringName, cargo_amount: float)
signal convoy_destroyed(convoy_id: StringName, by_unit_id: StringName)

# -- Progression (Phase 9+) --
signal tower_leveled_up(tower: Node, new_level: int)
signal convoy_proficiency_changed(convoy_id: StringName, new_proficiency: float)

# -- Abilities --
signal ability_used(slot_id: int)                                             ## cast fired
signal ability_cooldown_changed(slot_id: int, remaining: float, total: float) ## per-frame; drives radial sweep
signal ability_charge_changed(slot_id: int, current: float, max_charge: float) ## charge-based slots; bar fills up
signal ability_ready(slot_id: int)                                            ## cooldown hit zero / charge full
signal ability_unlocked(slot_id: int, ability_id: StringName)                 ## slot opened
signal ability_targeting_changed(slot_id: int, active: bool)                  ## ground-target armed/cancelled

# -- Objectives (Phase 5+) --
signal objective_sensed(objective_id: StringName)   ## Sensor ring detected a spawn linked to this objective
signal objective_progressed(objective_id: StringName, old_progress: int, new_progress: int)
signal objective_completed(objective_id: StringName)
signal objective_lapsed(objective_id: StringName)   ## Was complete; regressed below target (e.g., territory raided)
signal map_completed()                              ## All objectives on the active map are complete

# -- Factions & Progression --
signal faction_selected(faction_id: String, sub_path: String)
signal milestone_reached(faction_id: String, milestone_index: int)
signal milestone_progress_changed(current: int, target: int, label: String)
signal research_stage_purchased(stage: int, cost: float)  ## Architect research; MilestoneManager listens
signal subpath_committed(sub_path: String)   ## Player confirmed sub-path between waves 9-10
signal prestige_started(faction_id: String, collapse_count: int)
signal prestige_completed(faction_id: String)

# -- Galaxy --
signal star_system_captured(system_id: String, faction_id: String)
signal treaty_formed(faction_a: String, faction_b: String, treaty_type: String)
signal treaty_broken(faction_a: String, faction_b: String, reason: String)

# -- Ancients --
signal ruins_discovered(ruins_id: String)
signal pacification_progress_changed(ruins_id: String, progress: float)
signal fragment_acquired(fragment_index: int)
signal ancient_gift_received(gift_data: Dictionary)
signal observed_status_changed(is_observed: bool)

# -- Academy --
signal academy_scenario_resolved(index: int, faction: StringName)  ## telemetry / feel hooks
signal academy_completed(faction: StringName, unsorted: bool)      ## fired on Academy commit
signal academy_phase_started()      ## HUD hides wave button during Academy scenarios
signal academy_phase_ended()        ## HUD restores wave button after sorting
signal academy_spawn_requested(spawn_idx: int, count: int)  ## WaveSpawner handles
signal academy_clear_units()        ## WaveSpawner frees all units between scenarios
signal commander_attacked()         ## Commander primary fire hit — Mesh behavior signal

# -- Memory / Pilgrimage --
signal memory_tier_unlocked(tier: int)
signal pilgrimage_entered()
signal pilgrimage_exited()
signal mark_progress_changed(progress: float)

# -- UI --
signal hud_state_changed(depth: String)  ## "glance" | "tactical" | "active"(new_state: String)  # "glance" | "tactical" | "active"
signal notification_pushed(message: String, priority: String)
signal panel_open_requested(panel_id: String, data: Dictionary)
signal panel_close_requested(panel_id: String)
signal panel_upgrade_requested   ## InspectionPanel upgrade btn → Main._try_upgrade_tower
