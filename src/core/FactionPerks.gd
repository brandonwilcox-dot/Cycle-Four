## FactionPerks.gd
## Phase 4A — single source of faction BUILD-PREFERENCE tuning (commander-and-faction-systems.md).
## The player's faction shapes how its structures build and grow:
##   Architects — build faster + sturdier structures (flat multipliers; see Commander + Tower/Building).
##   Bloom      — towers grow stronger the longer they stand (Tower applies the growth tick).
##   Mesh       — connected tower chains buff their endpoints (Tower computes the chain).
## Preloaded by callers (Commander, Tower, Building) — global class_name resolution is unreliable at
## parse time in Godot 4.6, so consumers use `const FACTION_PERKS = preload(...)`.
class_name FactionPerks
extends RefCounted

# -- Architects: faster construction, sturdier structures --
const ARCHITECT_BUILD_RATE_MULT : float = 1.6
const ARCHITECT_HEALTH_MULT     : float = 1.4

# -- Bloom: towers grow while they stand (per tick, capped) --
const BLOOM_GROW_INTERVAL   : float = 5.0    ## seconds between growth ticks
const BLOOM_GROW_HEALTH_PCT : float = 0.08   ## +8% max health per tick (heals as it grows)
const BLOOM_GROW_DAMAGE_PCT : float = 0.06   ## +6% damage per tick (compounding)
const BLOOM_GROW_MAX_STACKS : int   = 6      ## cap → ~+59% health, +42% damage at full growth

# -- Mesh: connected tower chains empower their endpoints --
const MESH_LINK_RANGE       : float = 200.0  ## towers within this (px) are linked
const MESH_CHAIN_DAMAGE_PCT : float = 0.12   ## +12% damage per other tower in the chain (endpoints only)

## Construction-speed multiplier for the player's faction (Commander build rate).
static func build_rate_mult(faction: String) -> float:
	return ARCHITECT_BUILD_RATE_MULT if faction == "architects" else 1.0

## Structure max-health multiplier for the player's faction (towers + garrisons).
static func health_mult(faction: String) -> float:
	return ARCHITECT_HEALTH_MULT if faction == "architects" else 1.0
