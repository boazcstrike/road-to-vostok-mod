# Bo's War Enemy AI Agents Documentation

## Overview

This document outlines the development standards, architectural patterns, and coding conventions for the Bo's War enemy AI system in the Road to Vostok mod. The system implements advanced AI behaviors including faction-based targeting, audio sensing, and configurable difficulty presets.

### Structure

- the project (game mod) folder is in `BosWar`
- `docs/` is where we keep the documentation and plans
- `mods/` is where we store the reference mods
- `Reference Scripts` is where we extract the existing .gd file scripts for reference; `./Road to Vostok` is where the game files codebase is; **CRITICAL**: never edit these files under this folder, and just reference them because these are implementations of the other developers
    - all Main files under this folder will be from the base game codes just like `AISpawnerMain.gd`
- `realistic shaders` is for the realistic shaders of the game

## 1. Language Criteria and Ruleset (GDScript)

### Naming Conventions

#### Variables and Properties
- **snake_case** for all variables and properties
- Boolean variables prefixed with `is_`, `has_`, `can_`, `should_`, etc.
- Private variables prefixed with single underscore: `_private_var`
- Constants in **SCREAMING_SNAKE_CASE**
- Exported properties use descriptive names without abbreviations

```gdscript
# Good
var current_ai_target: Node3D
var is_player_visible: bool
var target_refresh_timer: float
const MAX_SIGHT_DISTANCE = 200.0

# Bad
var curAITarg: Node3D
var playerVis: bool
var timer: float
const maxsight = 200
```

#### Functions and Methods
- **snake_case** for all functions
- Private methods prefixed with single underscore: `_private_method()`
- Verb-based naming for actions: `activate()`, `update_target()`, `calculate_damage()`
- Getter/setter pairs: `get_target_position()`, `set_target_visible()`

```gdscript
# Good
func activate_ai()
func _update_target_visibility()
func get_engagement_distance() -> float

# Bad
func ActivateAI()
func updateTargetVisibility()
func getEngagementDist()
```

#### Classes and Resources
- **PascalCase** for class names and custom resources
- Descriptive names that indicate purpose
- Suffix with type when appropriate: `AISettings`, `EnemySpawner`

```gdscript
# Good
class_name EnemyAISettings
extends Resource

# Bad
class_name enemyai
extends Resource
```

### Code Style Standards

#### Formatting
- 4-space indentation (Godot default)
- Maximum line length: 120 characters
- One statement per line
- Space around operators: `x + y`, not `x+y`

#### Documentation
- All public functions must have docstrings
- Complex logic requires inline comments
- Constants should be documented

```gdscript
## Calculates the engagement distance based on current target
## Returns distance in meters as float
func get_engagement_distance() -> float:
    if _player_priority_active():
        return player_distance_3d
    if _has_valid_ai_target():
        return current_ai_target_distance
    return player_distance_3d
```

#### Error Handling
- Use assertions for critical assumptions
- Validate input parameters in public functions
- Graceful degradation for optional features

```gdscript
func _is_valid_hostile_ai_target(node) -> bool:
    if not is_instance_valid(node):
        return false
    if node == self:
        return false
    if not node.has_method("weapon_damage"):
        return false
    # ... additional validation
```

## 2. Godot Project Structuring

### Directory Organization

```
RoadToVostokEnemyAI/
├── AI.gd                    # Main AI behavior script
├── AISpawner.gd            # AI spawning system
├── EnemyAISettings.gd      # Configuration resource
├── EnemyAISettings.tres    # Settings resource instance
├── Character.gd            # Character base class
├── Config.gd               # Configuration utilities
├── Main.gd                 # Main system coordinator
└── MCMCompat_Main.gd       # Mod Configuration Menu compatibility
```

### Scene Hierarchy Standards

#### AI Agent Scene Structure
```
AI_Agent (Node3D)
├── Skeleton (Skeleton3D)
│   ├── Head (BoneAttachment3D)
│   ├── Chest (BoneAttachment3D)
│   ├── Eyes (BoneAttachment3D)
│   └── Spine (BoneAttachment3D)
├── LOS (RayCast3D)          # Line of Sight
├── Fire (RayCast3D)         # Weapon firing
├── Muzzle (Node3D)          # Weapon muzzle position
├── Flash (GPUParticles3D)   # Muzzle flash effect
├── Agent (NavigationAgent3D)
└── Audio Nodes...
```

#### Spawner Scene Structure
```
AISpawner (Node3D)
├── SpawnPoints (Node3D)
│   ├── SpawnPoint1 (Node3D)
│   ├── SpawnPoint2 (Node3D)
│   └── ...
├── Waypoints (Node3D)
├── PatrolPoints (Node3D)
├── CoverPoints (Node3D)
└── HidePoints (Node3D)
```

### Resource Management

#### Settings Resources
- Use `.tres` files for runtime-configurable settings
- Separate configuration from logic
- Export properties with appropriate ranges and defaults

```gdscript
@export var ai_health_multiplier: float = 1.0
@export_range(0.1, 5.0, 0.1) var ai_sight_multiplier: float = 1.0
@export var bandit_infighting_enabled: bool = false
```

#### Script Inheritance
- Extend base classes rather than duplicating code
- Use composition for complex behaviors
- Single responsibility principle per script

```gdscript
extends "res://Scripts/AI.gd"  # Extend base AI
# Add custom faction-based targeting logic
```

## 3. Development Architecture Standards

### AI System Architecture

#### Core Components

1. **AI.gd** - Main AI controller implementing:
   - State machine (Wander, Combat, Hide, etc.)
   - Sensory systems (vision, hearing)
   - Decision making and behavior execution
   - Custom faction-based targeting

2. **AISpawner.gd** - Population management:
   - Dynamic spawning based on settings
   - Pool management and replenishment
   - Performance scaling with active agent count

3. **EnemyAISettings.gd** - Configuration system:
   - Difficulty presets and multipliers
   - Faction relationships and warfare
   - Performance tuning parameters

#### Behavioral States

```gdscript
enum State {
    Wander,     # Random movement
    Guard,      # Stationary defense
    Patrol,     # Follow patrol route
    Combat,     # Active engagement
    Hide,       # Take cover
    Cover,      # Use cover position
    Vantage,    # Move to high ground
    Hunt,       # Pursue target
    Attack,     # Close-range assault
    Shift,      # Tactical repositioning
    Return,     # Return to position
    Ambush      # Wait in ambush
}
```

### Design Patterns

#### State Pattern
- Clear state transitions with validation
- State-specific timing and behavior
- Override base state methods for customization

```gdscript
func change_state(state):
    super(state)  # Call base implementation
    # Apply custom timing multipliers
    match current_state:
        State.Combat:
            combat_cycle *= cycle_scale
```

#### Observer Pattern
- Debug system integration
- Event-driven status updates
- Loose coupling between components

```gdscript
func _push_debug_status(event_text: String):
    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if debug_main:
        debug_main.update_status(active_agents, {
            "last_event": event_text,
            "current_target": target_label
        })
```

#### Strategy Pattern
- Configurable AI presets (Passive, Default, Aggressive, Relentless)
- Dynamic behavior scaling
- Settings-driven parameter adjustment

```gdscript
func _get_tactics_cycle_scale() -> float:
    match enemy_ai_settings.ai_tactics_preset:
        0: return 1.5    # Passive
        2: return 0.75   # Aggressive
        3: return 0.5    # Relentless
        _: return 1.0    # Default
```

### Performance Optimization

#### Distance-Based Processing
- Scale processing frequency with agent count
- Reduce update rates for distant agents
- Hysteresis in target acquisition to prevent thrashing

```gdscript
func _current_target_refresh_cycle() -> float:
    var active_count = _active_ai_count()
    var base_cycle = target_refresh_cycle + target_refresh_jitter

    if active_count >= 64:
        base_cycle = 1.45 + target_refresh_jitter
    elif active_count >= 24:
        base_cycle = 0.58 + target_refresh_jitter
    # ... scale based on performance needs
```

#### Memory Management
- Pool-based object reuse
- Cleanup of inactive agents
- Resource preloading for performance

```gdscript
func death(direction, force):
    # Replenish spawn pools
    if is_instance_valid(ai_spawner) and not boss:
        ai_spawner.replenish_regular_pool(_self_faction())
    super(direction, force)
```

### Faction System Design

#### Faction Relationships
- Configurable infighting within factions
- Inter-faction warfare system
- Player faction alignment

```gdscript
func _is_hostile_faction(self_faction: String, other_faction: String) -> bool:
    if self_faction == other_faction:
        return _same_faction_targeting_allowed(self_faction)
    return _faction_warfare_active() and \
           _is_supported_warfare_faction(self_faction) and \
           _is_supported_warfare_faction(other_faction)
```

#### Targeting Priority
- Player priority system with timers
- Audio-based target acquisition
- Hysteresis to prevent target switching

### Testing and Validation

#### Debug Integration
- Comprehensive logging system
- Visual debug overlays
- Performance monitoring

```gdscript
func _debug_log(message: String):
    # Centralized debug logging
    pass  # Implementation depends on debug settings

func _debug_log_ai_audio(key: String, message: String):
    # Rate-limited audio debug logging
    var now = float(Time.get_ticks_msec()) / 1000.0
    if ai_audio_log_cooldowns.has(key) and now < ai_audio_log_cooldowns[key]:
        return
    ai_audio_log_cooldowns[key] = now + AI_AUDIO_LOG_COOLDOWN
    _debug_log(message)
```

#### Validation Checks
- Instance validity checks
- Method existence validation
- Fallback behavior for missing components

This architecture provides a robust, scalable enemy AI system that can be easily configured and extended for the Bo's War mod.