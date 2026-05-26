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
signal unit_spawned(unit_data: Dictionary)
signal unit_died(unit_data: Dictionary)
signal base_damaged(amount: float, attacker_data: Dictionary)

# -- Tower Defense --
signal tower_placement_requested(tower_data: Resource)  ## HUD -> Main: enter placement mode
signal tower_placed(tower_data: Resource, grid_pos: Vector2i)
signal building_placed(building_data: Dictionary, grid_pos: Vector2i)
signal building_sold(building_data: Dictionary, grid_pos: Vector2i)
signal building_upgraded(building_data: Dictionary, tier: int)

# -- Factions & Progression --
signal faction_selected(faction_id: String, sub_path: String)
signal milestone_reached(faction_id: String, milestone_index: int)
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

# -- Memory / Pilgrimage --
signal memory_tier_unlocked(tier: int)
signal pilgrimage_entered()
signal pilgrimage_exited()
signal mark_progress_changed(progress: float)

# -- UI --
signal hud_state_changed(new_state: String)  # "glance" | "tactical" | "active"
signal notification_pushed(message: String, priority: String)
signal panel_open_requested(panel_id: String, data: Dictionary)
signal panel_close_requested(panel_id: String)
