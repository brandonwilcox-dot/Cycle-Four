## Balance.gd — shared tunable gameplay constants. Preload where needed:
##   const BALANCE = preload("res://src/core/Balance.gd")
extends RefCounted

## Global movement multiplier applied to every self-propelled entity (Commander, enemy
## Units, FriendlyUnits, Convoys). 2026-07-06: dropped so nothing zips around the map —
## units read as deliberate/heavy. Raise toward 1.0 to speed everything back up.
const MOVE_SCALE : float = 0.6
