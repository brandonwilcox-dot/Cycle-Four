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

# -- Bloom passive: pollen (built towers emit a slow + blind cloud) --
const BLOOM_POLLEN_RADIUS   : float = 130.0  ## px (~2 cells) cloud around a built Bloom tower
const BLOOM_POLLEN_SLOW     : float = 0.45   ## enemies move at 45% speed inside the cloud
const BLOOM_POLLEN_REFRESH  : float = 0.5    ## seconds between the tower re-applying pollen
const BLOOM_POLLEN_DURATION : float = 1.1    ## pollen lingers this long after leaving the cloud

# -- Mesh: connected tower chains empower their endpoints --
const MESH_LINK_RANGE       : float = 200.0  ## towers within this (px) are linked
const MESH_CHAIN_DAMAGE_PCT : float = 0.12   ## +12% damage per other tower in the chain (endpoints only)

# -- Mesh passive: hijack (built towers convert a nearby enemy to fight its allies, briefly) --
const MESH_HIJACK_RADIUS    : float = 180.0  ## px; tower converts an enemy within this
const MESH_HIJACK_COOLDOWN  : float = 8.0    ## seconds between hijacks per tower
const MESH_HIJACK_DURATION  : float = 6.0    ## the convert lasts this long, then the enemy reverts

# -- U0 (units-land-plan): per-faction garrison tether radius (Units_Land §2 node identities) --
# Architects wide (few durable units cover a big node), Bloom mid (grows with maturity in U1),
# Mesh short (pushes dense overlapping nodes — overlap-share pays it back in U1).
const TETHER_RADIUS : Dictionary = {
	"architects": 300.0,
	"bloom":      220.0,
	"mesh":       150.0,
}

## Construction-speed multiplier for the player's faction (Commander build rate).
static func build_rate_mult(faction: String) -> float:
	return ARCHITECT_BUILD_RATE_MULT if faction == "architects" else 1.0

## Structure max-health multiplier for the player's faction (towers + garrisons).
static func health_mult(faction: String) -> float:
	return ARCHITECT_HEALTH_MULT if faction == "architects" else 1.0

## U0: tether (leash) radius for a faction's garrison units. U1 scales Bloom's with maturity.
static func tether_radius(faction: String) -> float:
	return float(TETHER_RADIUS.get(faction, 220.0))
