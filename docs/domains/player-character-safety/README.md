# Player Character Safety

## Purpose
Owns player-protection overrides tied to spectator and testing modes, including damage prevention behavior.

## Owned By
`BosWar/Character.gd`

## Boundaries
- In scope: Character-level invulnerability and safety stat enforcement.
- Out of scope: Enemy AI decisions and spawn policy.

## Interfaces
- Inputs: `EnemyAISettings.player_invulnerable`, base character lifecycle hooks.
- Outputs: Health, oxygen, and death behavior overrides.

## Dependencies
- Upstream: Runtime bootstrap domain, configuration domain.
- Downstream: Gameplay runtime behavior.

## Change Process
1. Create an RFC for cross-domain contract changes.
2. Record accepted architecture choices in ADRs.
3. Update `system-map.md` for any boundary change.

