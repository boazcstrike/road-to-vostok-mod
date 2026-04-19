# system-map-spawn-orchestration-and-population

## Scope
Spawn Orchestration and Population

## Owned Responsibilities
- Build and replenish pools.
- Select spawn points and spawn cadence.
- Enforce active limits and team spawn constraints.

## Dependencies In
- Runtime settings and zone context.
- Spawn point graph and world conditions.

## Dependencies Out
- Active agent set and spawn events.
- Population metrics for debugging.

## Boundary Contracts
- Publishes agent metadata required by AI domain.

## Known Risks
- Incorrect pool accounting can desync active counts and spawn limits.

