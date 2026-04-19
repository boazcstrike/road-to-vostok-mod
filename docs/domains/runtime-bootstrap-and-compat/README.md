# Runtime Bootstrap and Compatibility

## Purpose
Owns startup-time script override wiring, runtime entrypoint concerns, and compatibility patching for external mod interfaces.

## Owned By
`BosWar/Main.gd`, `BosWar/MCMCompat_Main.gd`

## Boundaries
- In scope: Script takeover lifecycle, bootstrap sequence, compatibility patch activation.
- Out of scope: Spawn policy, per-agent combat decisions, user settings schema.

## Interfaces
- Inputs: Base script paths, MCM script availability, `EnemyAISettings`.
- Outputs: Active script overrides, initialized debug root and runtime state.

## Dependencies
- Upstream: Base game script contracts, MCM mod availability.
- Downstream: Spawner, AI, and Character override paths.

## Change Process
1. Create an RFC for cross-domain contract changes.
2. Record accepted architecture choices in ADRs.
3. Update `system-map.md` for any boundary change.

