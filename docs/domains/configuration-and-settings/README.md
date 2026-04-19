# Configuration and Settings

## Purpose
Owns mod configuration schema, persistence and migration, and shared runtime settings resource values.

## Owned By
`BosWar/Config.gd`, `BosWar/EnemyAISettings.gd`, `BosWar/EnemyAISettings.tres`

## Boundaries
- In scope: Config model, MCM registration, settings synchronization.
- Out of scope: Runtime spawn and combat execution.

## Interfaces
- Inputs: MCM values and config file state.
- Outputs: Runtime settings consumed by all operational domains.

## Dependencies
- Upstream: User configuration and MCM integration.
- Downstream: Bootstrap, spawner, AI, character, and observability domains.

## Change Process
1. Create an RFC for cross-domain contract changes.
2. Record accepted architecture choices in ADRs.
3. Update `system-map.md` for any boundary change.

