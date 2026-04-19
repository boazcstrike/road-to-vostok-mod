# 05 - Project Structuring

## Expected script roles
- `AI.gd`: agent behavior/state and sensing
- `AISpawner.gd`: spawn/population control
- `EnemyAISettings.gd`: configuration resource
- `Main.gd`: system coordination
- `MCMCompat_Main.gd`: settings menu compatibility

## Scene conventions
### AI agent
Include skeleton anchors, LOS/fire raycasts, muzzle/flash, navigation agent, and audio nodes.

### Spawner
Organize spawn, waypoint, patrol, cover, and hide point groups.

## Resource management
- Use `.tres` for tunable runtime settings.
- Separate configuration from behavior logic.
- Prefer inheritance/composition over copy-paste duplication.
