# AI Brain

## Purpose
Defines AI behavior, decision layers, commander autonomy, and how non-player actors interact with the simulation.

## Core rule
AI uses the same command pipeline as players.
AI never directly mutates simulation state.

## AI architecture layers
### Strategic AI
- expansion timing
- tech choices
- economy priorities
- factory planning
- superweapon pursuit
- global threat response
- top-level objective assignment

### Operational AI
- commander role assignment
- force distribution by domain
- patrol and defense sectors
- reinforcement routing
- objective reallocation between commanders

### Tactical AI
- formations
- attack waves
- defense posture
- harassment
- target area selection
- retreat or reinforcement logic
- stance shaping

### Micro AI
- local targeting preferences
- ability usage
- standoff versus chase
- formation cohesion
- threat legality checks
- avoidance of worthless suicide attacks

## Commander autonomy model
Sub-commanders should be able to:
- interpret high-level objectives into tactics
- maintain formation discipline
- recruit eligible nearby unassigned units if allowed
- report status upward
- request reinforcement or reassignment

The Ultra Leader or CPU equivalent should:
- issue strategic objectives
- monitor top-level commanders
- redistribute effort between domains
- remain the root recipient of command progress and army status

## Constraints
- must obey build rules
- must obey production rules
- must obey targeting legality
- must operate through valid commands only
- must support land, sea, and air domains
- must respect persistent hierarchy ownership
