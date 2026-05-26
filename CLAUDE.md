# Cycle Four -- Game Project

Godot 4.6.1 | GDScript | D:\AI\Cycle Four\

Design corpus lives at:
  C:\ClaudeProjects\Skippy Gaming Design Engineer Agent\core\
Read PROJECT-MEMORY.md and core/23_open-questions-resolved.md before
making any design decisions in code.

---

## The Game

**Title:** Cycle Four
**Genre:** Idle-Miner / Tower Defense / Endless Wave hybrid
**Three-layer gameplay:**
  1. Idle production -- always running, offline-capable (EconomyManager)
  2. Tower defense -- passive auto-attack, 5-min session viable (WaveManager)
  3. Unit production on cooldown -- active RTS layer (WaveManager + entities)

**Design philosophy:** Lore-first. The IP is the asset.
**Session target:** Meaningful in 5 minutes. Deep over months.

---

## The Four Factions

**Architects** (faction id: "architects")
- Philosophy: Efficiency is virtue. Multiplicative economy.
- Resources: energy (primary), schematics (secondary)
- Sub-paths: "standard" | "spiritual_tech"
- Strength: strongest idle loop, best diplomats
- Weakness: brittle under attack, accidentally trigger doomsday devices
- Units feel like: precision machines, clean geometric forms

**Bloom** (faction id: "bloom")
- Philosophy: Life spreads. Adapt or die.
- Resources: biomass (primary), lineages (secondary)
- Sub-paths: "purist" | "assimilator"
- Strength: units evolve from damage, near-unkillable late game
- Weakness: weakest early, buries Ruins (makes Ancients hostile)
- Units feel like: organic, asymmetric, grotesque beauty

**Mesh** (faction id: "mesh")
- Philosophy: Everything is a system. Hack it.
- Resources: signal (primary), routes (secondary)
- Sub-paths: "networked" | "dreamer"
- Strength: steals resources and infrastructure, strongest raider
- Weakness: weakest passive economy, dependent on stealing
- Units feel like: glitchy, fragmented, neon-edged constructs

**Ancients** (not playable)
- Librarians for the apocalypse. Seed vaults. Fled here from something.
- React to the leading faction by countering their core strength.
- The Custodian unit: unkillable, non-attacking, follows the player.
- Pacification economy: sacrifice faction-specific things at Ruins.

---

## Autoload Architecture

All autoloads are globally accessible. Do NOT import them -- they are
singletons injected by Godot at startup.

| Autoload | Responsibility |
|---|---|
| EventBus | All cross-system signals. Read/emit only -- no state. |
| GameState | Top-level state (faction, wave, prestige). Read anywhere, write via Managers. |
| EconomyManager | All resource production, storage, spending. Idle tick owner. |
| WaveManager | Wave spawning, enemy tracking, TD loop. |
| FactionManager | Faction selection, sub-path, faction-specific data lookups. |
| GalaxyManager | Persistent galaxy layer, star systems, treaties, alliances. |
| SaveManager | Save/load, auto-save, offline catch-up trigger. |

**Signal rule:** Systems communicate ONLY through EventBus signals.
A script that needs to tell another system something emits a signal.
It does NOT call the other system's methods directly (unless it owns it).

---

## File / Folder Conventions

```
src/autoloads/     -- Global singletons (one per Manager)
src/core/economy/  -- EconomyManager helpers, resource definitions
src/core/waves/    -- Wave table loaders, spawn logic
src/core/units/    -- Unit stat definitions, cooldown logic
src/core/galaxy/   -- Galaxy generation, cascade logic
src/core/ancients/ -- Pacification system, Dominance Meter
src/factions/architects/  -- Architect-specific scripts
src/factions/bloom/       -- Bloom-specific scripts
src/factions/mesh/        -- Mesh-specific scripts
src/ui/            -- HUD, panels, notification system
src/entities/      -- Unit, building, projectile base classes
src/utils/         -- Math helpers, constants, formatters
scenes/main/       -- Main game scene, game loop scene
scenes/ui/         -- UI subscenes
scenes/test/       -- Throwaway test scenes (not shipped)
resources/         -- .tres data files (unit stats, building defs, wave tables)
assets/            -- sprites, audio, fonts, shaders
```

**Naming:**
- Scripts: PascalCase.gd (e.g. ArchitectUnit.gd)
- Scenes: PascalCase.tscn (e.g. TowerBase.tscn)
- Resources: snake_case.tres (e.g. architect_tier1_unit.tres)
- Constants: ALL_CAPS
- Signals: past_tense_snake_case (e.g. wave_ended, resource_changed)
- Functions: snake_case. Private functions prefix with _

---

## GDScript Style Rules

- Always use static typing (var x: float = 0.0, not var x = 0.0)
- Class-level doc comment with ## on the first line of every file
- Keep functions under 40 lines. Extract helpers if longer.
- No magic numbers -- define as const at top of file or in a constants file
- Signals are defined in EventBus.gd only -- scripts never define their own
  cross-system signals
- Use await sparingly -- prefer signals for async flow
- @export variables for anything a designer might tune in the editor

---

## Key Design Numbers (from core/23_open-questions-resolved.md)

- Idle tick rate: 1 second
- Offline cap: 8 hours
- Auto-save interval: 60 seconds
- Wave countdown between waves: 5 seconds
- First session target: meaningful content within 5 minutes
- Production tiers: 1-3 (standard), 4-5 (research-gated), 6 (post-milestone)
- Memory Tiers: 0-11 (cross-prestige Option B system)
- Fragments: 7 total (gate Memory Tier progression)

---

## What Is NOT Started Yet

- Scene files (.tscn) -- none exist, only scripts
- Unit / building resource files (.tres)
- Wave tables
- UI scenes
- Faction-specific unit scripts
- The Pacification / Dominance Meter system
- Research tree
- Galaxy generation

Work in order: Economy baseline -> first wave -> faction units -> UI.
