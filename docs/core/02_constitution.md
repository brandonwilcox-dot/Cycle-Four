# Constitution

## Prime directive
BattleSim is the source of truth.
The scene tree is presentation only.

## Core rules
1. No per-unit gameplay `_process()` or `_physics_process()`.
2. No gameplay authority in presenter nodes.
3. No direct state mutation outside BattleSim systems.
4. All gameplay flows through the simulation tick.
5. AI uses commands, not direct control.
6. Spatial queries must use partitioning systems.
7. Data-driven design is preferred over hardcoding.
8. Systems must scale to 8-player late game.
9. Prefer clear ownership over convenience glue.
10. Selection is UI state only, never command authority.
11. Persistent command hierarchy must exist in simulation, not presentation.

## Global class rule
- each `class_name` must exist exactly once in the project
- duplicate `class_name` definitions are forbidden
- experimental copies must not register global classes

## Source of truth rule
- only one live implementation per system
- no duplicate folders containing active systems
- archive and test versions must live outside the active project

## Command authority rule
- groups are persistent simulation entities or data models
- selecting units does not create or redefine hierarchy
- command relationships are owned by simulation systems
- objectives flow down the hierarchy
- experience, status, and performance data flow up the hierarchy

## Authority model
### Simulation owns
- entity state
- movement
- combat
- health and death
- economy
- construction
- production
- upgrades
- veterancy
- command hierarchy
- recruitment
- tactical objective assignment
- commander progression
- AI execution

### Presentation owns
- visuals
- animation
- VFX
- audio
- UI
- interpolation
- selection visuals
- command queue previews
- formation markers

## Conflict rule
If convenience conflicts with scalability, scalability wins.
