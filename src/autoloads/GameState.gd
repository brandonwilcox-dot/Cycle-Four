## GameState.gd
## Single source of truth for top-level game state.
## Read from anywhere. Write only through dedicated Managers.
extends Node

# -- Session --
var current_faction: String = ""       # "architects" | "bloom" | "mesh"
var current_sub_path: String = ""      # faction-specific sub-path id
var wave_number: int = 0
var collapse_count: int = 0            # prestige counter
var session_start_time: int = 0        # Unix timestamp

# -- Progression --
var memory_tier: int = 0               # 0-11
var mark_progress: float = 0.0         # 0.0-1.0
var fragments_collected: Array[int] = []  # indices of collected fragments
var milestones_reached: Array[int] = []   # milestone indices

# -- Galaxy --
var galaxy_run_number: int = 0         # increments each prestige

# -- Flags --
var is_paused: bool = false
var is_in_pilgrimage: bool = false
var tutorial_complete: bool = false
var academy_completed: bool = false  # true after first-run Academy commit; gate for skip logic
var unsorted: bool = false           # true if player declined Academy recommendation; read by D-2

# -- Called by SaveManager on load --
func apply_save_data(data: Dictionary) -> void:
	current_faction    = data.get("current_faction", "")
	current_sub_path   = data.get("current_sub_path", "")
	wave_number        = data.get("wave_number", 0)
	collapse_count     = data.get("collapse_count", 0)
	memory_tier        = data.get("memory_tier", 0)
	mark_progress      = data.get("mark_progress", 0.0)
	fragments_collected.assign(data.get("fragments_collected", []))
	milestones_reached.assign(data.get("milestones_reached", []))
	galaxy_run_number  = data.get("galaxy_run_number", 0)
	tutorial_complete  = data.get("tutorial_complete", false)
	academy_completed  = data.get("academy_completed", false)
	unsorted           = data.get("unsorted", false)

func to_save_data() -> Dictionary:
	return {
		"current_faction":    current_faction,
		"current_sub_path":   current_sub_path,
		"wave_number":        wave_number,
		"collapse_count":     collapse_count,
		"memory_tier":        memory_tier,
		"mark_progress":      mark_progress,
		"fragments_collected": fragments_collected,
		"milestones_reached": milestones_reached,
		"galaxy_run_number":  galaxy_run_number,
		"tutorial_complete":  tutorial_complete,
		"academy_completed":  academy_completed,
		"unsorted":           unsorted,
	}
