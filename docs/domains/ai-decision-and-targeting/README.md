# AI Decision and Targeting

## Purpose
Owns per-agent sensing, hostile target selection, tactical state transitions, and combat execution.

## Owned By
`BosWar/AI.gd`

## Boundaries
- In scope: Sensing loops, targeting rules, state transitions, combat mechanics.
- Out of scope: Spawn pool management, bootstrap patching, settings persistence.

## Interfaces
- Inputs: Spawner-provided agents, world sensor data, `EnemyAISettings`.
- Outputs: State changes, damage events, target telemetry updates.

## Dependencies
- Upstream: Spawn orchestration, configuration domain.
- Downstream: Observability and debugging domain.

## Change Process
1. Create an RFC for cross-domain contract changes.
2. Record accepted architecture choices in ADRs.
3. Update `system-map.md` for any boundary change.

