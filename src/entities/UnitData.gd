## UnitData.gd
## Resource definition for a single unit type.
## One .tres file per unit. Loaded by wave tables at spawn time.
## Ref: core/17_units-maps-buildings.md for stat philosophy.
@tool
extends Resource
class_name UnitData

## Display
@export var unit_name: String = ""
@export var faction_id: String = ""         ## "architects" | "bloom" | "mesh"
@export var tier: int = 1                   ## Production tier 1-6

## U0 (units-land-plan / docs/codex/Units_Land.md §3) — roster role. Line is the
## per-faction T1 balance anchor, so existing .tres files default to it correctly.
## Ordinals are saved into .tres files — append, never reorder.
@export_enum("Line", "Scout", "AA", "Artillery", "Support", "Shield", "Assault", "Siege")
var role: int = 0

## U0 — sub-path gating (core/17: T1 shared, T2 is the sub-path commit point).
## "" = available to every sub-path; else a FactionManager.SUB_PATHS id
## ("standard" | "spiritual_tech" | "purist" | "assimilator" | "networked" | "dreamer").
@export var sub_path_lock: String = ""

## U0 — modifier slots (Units_Land §4). Orthodox units carry clean stat mods;
## heretic sub-paths unlock one borrowed-mechanic modifier. Eligibility is enforced
## by UnitModifier.is_eligible against the player's committed sub-path (U4 behavior).
@export var modifier_slots: Array[UnitModifier] = []

## Combat stats
@export var max_health: float = 100.0
@export var move_speed: float = 80.0        ## pixels per second along path
@export var damage_on_arrival: float = 10.0 ## damage dealt to base when unit reaches end
@export var armor: float = 0.0              ## flat damage reduction (applied after type multiplier)

## Pass 2 combat identity. armor_type feeds the damage triangle (Combat.gd):
## Plated=Architect, Organic=Bloom, Synthetic=Mesh. Ordinal must match Combat.ArmorType.
@export_enum("Plated", "Organic", "Synthetic") var armor_type: int = 0
## Stealth units render and can be targeted only inside a sensor sphere (sensed cells).
@export var stealth: bool = false

## Active-RTS combat (Phase C friendly army). Enemies don't use these (they only march
## and deal damage_on_arrival), so they default to 0 / inert. A friendly garrison unit with
## attack_damage > 0 fires on enemies in range via the damage/armor triangle, using its
## OWN faction's signature damage type (Combat.faction_damage_type), exactly like towers.
@export var attack_damage: float = 0.0      ## per-shot damage; 0 = non-combatant
@export var attack_range: float = 0.0       ## px; how far it can engage
@export var attack_interval: float = 1.0    ## seconds between shots

## Economy
@export var resource_reward: float = 5.0   ## primary resource dropped on death
@export var spawn_cost: Dictionary = {}     ## cost to produce (unit production layer)
@export var cooldown: float = 8.0          ## seconds between spawns (active layer)

## Visual hint (texture assigned in editor; placeholder until art exists)
@export var color_hint: Color = Color.WHITE ## faction color shown on placeholder rect

## Bloom-specific: evolve on damage
@export var evolve_threshold: float = 0.0  ## 0 = no evolution; >0 = HP% that triggers adapt
@export var evolved_unit: UnitData = null  ## unit type to replace this one after evolving

## Mesh-specific: hacks nearby buildings on death
@export var hacks_on_death: bool = false
@export var hack_radius: float = 0.0

## Ability system: units flagged true ignore stun and slow from ability effects.
## Set on heavy/lore-immune chassis (Mire-Beast, Bio-Titan, etc.).
@export var status_immune: bool = false

## U2 (units-land-plan) — role mechanics.
## Mesh direct-fire constraint: cannot shoot past walls (raycast LOS; terrain occlusion
## arrives with backlog F1).
@export var requires_los: bool = false
## Bloom hover/amphibious: inert until F1 gives terrain a movement penalty — wired now so
## F1 activates it for free.
@export var ignores_terrain_penalty: bool = false
## Scout utility: >0 makes a friendly unit a stealth detector (joins the "detectors" group
## with this radius — the reveal-tier contract).
@export var detector_radius: float = 0.0

## U3 (units-land-plan) — T2/T3 shared systems. All auras apply automatically in radius
## (anti-micro §6); a value of 0 means "this unit is not that kind of emitter".
## Shield emitter (Bloom Mobile Shield / Architect Support-Shield Hybrid): grants tethered
## allies a damage-absorbing shield buffer of `provides_shield` HP within `shield_radius`.
@export var provides_shield: float = 0.0
@export var shield_radius: float = 0.0
## Regeneration aura (Bloom Regeneration Support — "living tech heals, it doesn't get fixed"):
## heals allied friendly units `regen_aura` HP/s within `regen_radius`. Distinct from the
## Bloom NODE regen (that's the garrison's maturity aura); this one is mobile and unit-driven.
@export var regen_aura: float = 0.0
@export var regen_radius: float = 0.0
## Adaptive Assault (Bloom T3 — the maturation fantasy in one unit): gains a small PERMANENT
## stat buff (+adapt_per_wave to damage & health, fraction) each wave it survives, capped at
## `adapt_cap` stacks. Extends the evolve scaffolding without replacing it.
@export var adapt_per_wave: float = 0.0
@export var adapt_cap: int = 0
## Mesh Siege on-death trick (one legible idea): an EMP pulse that stuns enemies within
## `emp_radius` for `emp_stun` seconds when the unit dies. Surfaced VISUALLY, not via a wiki.
@export var emp_on_death: bool = false
@export var emp_radius: float = 0.0
@export var emp_stun: float = 0.0
## Mesh Deceiver (stealth decoy vs the reveal-tier system): while alive and undetected, cloaks
## allied friendly units within `cloak_radius` — non-detector enemies can't acquire them.
@export var cloak_ally: bool = false
@export var cloak_radius: float = 0.0
