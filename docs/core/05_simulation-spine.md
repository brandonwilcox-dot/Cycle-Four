# Simulation Spine

## Core principle
BattleSim is a fixed-step ECS-style simulation core.

## Tick model
- 20 ticks per second baseline
- rendering is independent
- presentation interpolates between ticks

## Responsibilities
- entity lifecycle
- command intake
- system execution
- event handling
- player state
- command structure state
- sync output for presentation

## Required systems
- command_system
- movement_system
- targeting_system
- weapon_system
- economy_system
- production_system
- construction_system
- command_structure_system
- formation or group system
- experience_flow_system

## Recommended execution order
1. command intake
2. command structure updates
3. recruitment and hierarchy validation
4. movement and formation slot assignment
5. targeting and combat
6. economy, production, construction
7. experience and promotion flow
8. event resolution
9. presentation snapshot publish

## Hard rules
- presenter nodes contain zero gameplay authority
- all systems execute inside BattleSim
- selection data lives outside gameplay authority
