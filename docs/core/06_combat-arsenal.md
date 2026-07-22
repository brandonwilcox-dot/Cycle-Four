# Combat Arsenal

## Combat goals
Combat must be:
- performant
- readable
- scalable
- data-driven
- consistent across domains

## Weapon pipeline
1. acquire or validate target
2. check legal target masks
3. check range and firing conditions
4. consume cooldown or charge rules
5. resolve hitscan or spawn projectile
6. apply damage events
7. process death, veterancy, and effects

## Target masks
Weapons may target:
- ground
- sea
- air
- structure
- commander
- any valid hostile

## Damage model
The first implementation can stay simple:
- flat damage
- range checks
- cooldowns
- area-of-effect radius support

Future support can include:
- armor classes
- resist tables
- shields
- overkill handling
- splash falloff
- directional rules

## Performance law
No unit may scan the whole battlefield for targets.
All target acquisition depends on spatial queries.
