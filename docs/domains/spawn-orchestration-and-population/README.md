# Spawn Orchestration and Population

## Purpose
Owns spawn pool creation, team composition, spawn cadence, active count enforcement, and replenishment behavior.

## Owned By
`BosWar/AISpawner.gd`

## Boundaries
- In scope: Spawn pool lifecycle and live population control.
- Out of scope: Per-agent combat decisioning and player safety behavior.

## Interfaces
- Inputs: `EnemyAISettings`, spawn points, zone context.
- Outputs: Activated agents with metadata, spawn counters, and spawn events.

## Dependencies
- Upstream: Configuration domain, runtime bootstrap domain.
- Downstream: AI decision and observability domains.

## Change Process
1. Create an RFC for cross-domain contract changes.
2. Record accepted architecture choices in ADRs.
3. Update `system-map.md` for any boundary change.

