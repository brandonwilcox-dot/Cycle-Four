# Visuals

## Purpose
Define the presentation-layer architecture, visual direction, and rendering rules for ULBFF V3.

## Authority rule
BattleSim remains the only gameplay authority.
Presentation reads simulation state and renders it.
Presentation never owns gameplay truth.

## Camera direction
- top-down RTS presentation
- large-battle readability
- realistic unit and world scaling
- support strategic battlefield awareness

## Visual priorities
1. readability at gameplay camera height
2. clean faction distinction
3. movement clarity
4. targeting and weapon readability
5. scalable VFX cost for late-game battles

## Presentation architecture rules
- presentation is downstream of BattleSim
- use snapshot or sync publishing from simulation
- presenter nodes may interpolate, animate, and display effects
- presenter nodes may not make gameplay decisions
- selection visuals belong only to presentation
- movement smoothing must not alter sim truth

## Planned systems
- PresentationSyncSystem
- PresentationManager
- UnitPresenter
- SelectionIndicator
- ProjectilePresenter
- EffectSpawner
- HealthBarWidget
- ConstructionVisualPresenter
