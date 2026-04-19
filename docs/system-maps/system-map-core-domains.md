# system-map-core-domains

## Scope
Core runtime architecture of the Bo's War mod (`BosWar/*.gd`).

## Domain Topology
1. Runtime Bootstrap and Compatibility
2. Configuration and Settings
3. Spawn Orchestration and Population
4. AI Decision and Targeting
5. Player Character Safety
6. Observability and Debugging

## High-Level Flow
- Runtime Bootstrap and Compatibility initializes overrides and compatibility patching.
- Configuration and Settings provides runtime values via `EnemyAISettings.tres`.
- Spawn Orchestration and Population creates and activates enemy entities.
- AI Decision and Targeting drives behavior and combat for active entities.
- Player Character Safety applies player-invulnerability behavior when configured.
- Observability and Debugging receives events and exposes telemetry.

## Source Anchors
- `BosWar/Main.gd`
- `BosWar/Config.gd`
- `BosWar/EnemyAISettings.gd`
- `BosWar/AISpawner.gd`
- `BosWar/AI.gd`
- `BosWar/Character.gd`
- `BosWar/DebugUtils.gd`

