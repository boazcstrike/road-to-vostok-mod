# boundary-matrix-core-domains

| Domain | Owns | Consumes | Publishes |
|---|---|---|---|
| Runtime Bootstrap and Compatibility | Script overrides, boot lifecycle, MCM compatibility patch trigger | Base script paths, settings resource | Active runtime overrides, debug root node |
| Configuration and Settings | MCM schema, config persistence, settings resource values | User config files, MCM helper APIs | `EnemyAISettings` runtime values |
| Spawn Orchestration and Population | Spawn pools, team spawn logic, active agent count | `EnemyAISettings`, world spawn points | Spawned agents, spawn telemetry |
| AI Decision and Targeting | Sensing, target selection, state transitions, combat behavior | `EnemyAISettings`, spawned agents, world state | Target updates, combat events, telemetry updates |
| Player Character Safety | Player invulnerability behavior overrides | `EnemyAISettings.player_invulnerable` | Player safety state effects |
| Observability and Debugging | Debug logging and overlay state | Runtime events from bootstrap, spawner, AI | Debug console output and overlay text |

