## AcademyBehaviorTracker.gd — silently watches player behaviour during Academy
## map scenarios and produces a faction recommendation from three counters.
##
## Architects : towers placed   (build and fortify)
## Bloom       : territory claimed  (expand and hold)
## Mesh        : Commander attacks  (aggressive, up-close)
extends RefCounted

## Thresholds: how many actions saturate the 0–1 score for each faction.
const ARCH_THRESHOLD  : float = 6.0
const BLOOM_THRESHOLD : float = 20.0
const MESH_THRESHOLD  : float = 12.0

var towers_placed     : int = 0
var territory_claimed : int = 0
var commander_attacks : int = 0

func start_tracking() -> void:
	EventBus.tower_placed.connect(func(_d: Resource, _c: Vector2i) -> void:
		towers_placed += 1
	)
	EventBus.territory_claimed.connect(func(_c: Vector2i) -> void:
		territory_claimed += 1
	)
	EventBus.commander_attacked.connect(func() -> void:
		commander_attacks += 1
	)

## Returns normalised 0-1 scores per faction.
func get_scores() -> Dictionary:
	return {
		"architects": clampf(float(towers_placed)     / ARCH_THRESHOLD,  0.0, 1.0),
		"bloom":      clampf(float(territory_claimed) / BLOOM_THRESHOLD, 0.0, 1.0),
		"mesh":       clampf(float(commander_attacks) / MESH_THRESHOLD,  0.0, 1.0),
	}

## Returns the faction with the highest score, or StringName("") on a flat tie.
## Minimum score of 0.05 required — a player who did nothing gets no recommendation.
func compute_recommendation() -> StringName:
	var scores : Dictionary = get_scores()
	var best_fac   : StringName = &""
	var best_val   : float      = 0.05   ## minimum threshold
	for fac : String in scores:
		var v : float = scores[fac]
		if v > best_val:
			best_val = v
			best_fac = fac
		elif absf(v - best_val) < 0.01:
			best_fac = &""   ## tie at top — no clear recommendation
	return best_fac
