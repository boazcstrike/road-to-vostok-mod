# AI Rearchitecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the monolithic AI.gd script into modular, component-based architecture to enable cooperative squad behaviors, dynamic environmental adaptation, advanced combat tactics, learning systems, communication networks, personality variations, performance optimizations, advanced pathfinding, game system integration, and debug tools while maintaining compatibility with base AI.gd.

**Architecture:** Break AI.gd into child node components (SensoryModule, TargetingModule, CombatModule, NavigationModule, SquadModule, StateMachine) using composition over inheritance. Use Godot signals for event-driven communication. Preserve base class overrides for compatibility. Implement configuration-driven personality variations and performance optimizations.

**Tech Stack:** Godot 4.x, GDScript, Godot's Node system, Signals/Events, Resource system for configurations.

---

### Task 1: Setup Project Structure and Base Interfaces

**Files:**
- Create: `docs/plans/2026-04-16-ai-rearchitecture.md` (this file)
- Create: `RoadToVostokEnemyAI/interfaces/ITargetable.gd`
- Create: `RoadToVostokEnemyAI/interfaces/ISensory.gd`
- Create: `RoadToVostokEnemyAI/components/BaseAIComponent.gd`

**Step 1: Create interfaces directory and base interface files**

Create the interfaces directory and write the base interfaces for modularity.

**Step 2: Write ITargetable.gd**

```gdscript
# ITargetable.gd - Interface for targetable entities
class_name ITargetable
extends Node

# Returns the global position for targeting
func get_target_position() -> Vector3:
    return Vector3.ZERO

# Returns the faction string
func get_faction() -> String:
    return "Unknown"

# Checks if this entity can be targeted by the given faction
func can_be_targeted_by(faction: String) -> bool:
    return false
```

**Step 3: Write ISensory.gd**

```gdscript
# ISensory.gd - Interface for sensory components
class_name ISensory
extends Node

signal target_detected(target: Node3D, position: Vector3)
signal target_lost(target: Node3D)

# Perform sensory checks
func update_senses(delta: float) -> void:
    pass
```

**Step 4: Write BaseAIComponent.gd**

```gdscript
# BaseAIComponent.gd - Base class for AI components
class_name BaseAIComponent
extends Node

var ai_root: Node  # Reference to the main AI node

func _ready():
    ai_root = get_parent()
    if not ai_root:
        push_error("BaseAIComponent must be child of AI node")
```

**Step 5: Commit**

```bash
git add docs/plans/ RoadToVostokEnemyAI/interfaces/ RoadToVostokEnemyAI/components/
git commit -m "feat: setup AI rearchitecture project structure and base interfaces"
```

### Task 2: Extract SensoryModule

**Files:**
- Create: `RoadToVostokEnemyAI/components/SensoryModule.gd`
- Modify: `RoadToVostokEnemyAI/AI.gd` (remove sensory-related code, add component attachment)

**Step 1: Write SensoryModule.gd**

Extract LOS, hearing, and audio detection logic into a component.

```gdscript
# SensoryModule.gd - Handles all sensory detection
class_name SensoryModule
extends BaseAIComponent

var target_refresh_timer = 0.0
var target_refresh_cycle = 0.4
var ai_audio_sense_timer = 0.0

func _process(delta):
    update_senses(delta)

func update_senses(delta):
    target_refresh_timer -= delta
    ai_audio_sense_timer -= delta
    
    if target_refresh_timer <= 0:
        check_player_los()
        target_refresh_timer = target_refresh_cycle
    
    if ai_audio_sense_timer <= 0:
        check_ai_audio()
        ai_audio_sense_timer = 0.25  # Base cycle

func check_player_los():
    # Extracted LOSCheck logic
    var sight_multiplier = max(0.1, EnemyAISettings.ai_sight_multiplier)
    # ... (full LOSCheck implementation)
    if playerVisible:
        emit_signal("target_detected", null, playerPosition)  # Player detected

func check_ai_audio():
    # Extracted _sense_ai_audio logic
    var audible_target = find_audible_hostile_target()
    if audible_target:
        emit_signal("target_detected", audible_target, audible_target.global_position)
```

**Step 2: Modify AI.gd to use SensoryModule**

Remove sensory code from AI.gd, attach SensoryModule as child, connect signals.

```gdscript
# In AI.gd _ready()
var sensory = SensoryModule.new()
add_child(sensory)
sensory.connect("target_detected", Callable(self, "_on_target_detected"))
```

**Step 3: Test sensory extraction**

Run the game, verify LOS and audio detection still work.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/components/SensoryModule.gd RoadToVostokEnemyAI/AI.gd
git commit -m "feat: extract SensoryModule component"
```

### Task 3: Extract TargetingModule

**Files:**
- Create: `RoadToVostokEnemyAI/components/TargetingModule.gd`
- Modify: `RoadToVostokEnemyAI/AI.gd` (remove targeting logic, integrate component)

**Step 1: Write TargetingModule.gd**

Extract faction logic, target acquisition, hysteresis.

```gdscript
# TargetingModule.gd - Handles target selection and faction logic
class_name TargetingModule
extends BaseAIComponent

var current_target: Node3D
var target_distance = 9999.0

func acquire_target() -> Node3D:
    # Extracted _acquire_hostile_ai_target logic
    var nearest = find_nearest_hostile()
    return apply_hysteresis(nearest)

func is_hostile(faction: String) -> bool:
    # Extracted _is_hostile_faction logic
    return _self_faction() != faction or EnemyAISettings.bandit_infighting_enabled  # Simplified
```

**Step 2: Integrate into AI.gd**

Attach TargetingModule, use its methods in Parameters().

**Step 3: Test targeting**

Verify faction targeting and hysteresis work.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/components/TargetingModule.gd RoadToVostokEnemyAI/AI.gd
git commit -m "feat: extract TargetingModule component"
```

### Task 4: Extract CombatModule

**Files:**
- Create: `RoadToVostokEnemyAI/components/CombatModule.gd`
- Modify: `RoadToVostokEnemyAI/AI.gd` (remove combat logic)

**Step 1: Write CombatModule.gd**

Extract firing, accuracy, damage logic.

```gdscript
# CombatModule.gd - Handles combat mechanics
class_name CombatModule
extends BaseAIComponent

func fire_weapon():
    # Extracted Fire() logic
    if can_fire():
        calculate_accuracy()
        perform_raycast()
        play_effects()

func calculate_accuracy() -> Vector3:
    # Extracted FireAccuracy() logic
    var spread = 0.1 * (1.0 / max(0.1, EnemyAISettings.ai_accuracy_multiplier))
    return fireDirection + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), 0)
```

**Step 2: Integrate into AI.gd**

Use CombatModule in Fire() method.

**Step 3: Test combat**

Verify firing and accuracy work.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/components/CombatModule.gd RoadToVostokEnemyAI/AI.gd
git commit -m "feat: extract CombatModule component"
```

### Task 5: Extract NavigationModule

**Files:**
- Create: `RoadToVostokEnemyAI/components/NavigationModule.gd`
- Modify: `RoadToVostokEnemyAI/AI.gd` (remove navigation logic)

**Step 1: Write NavigationModule.gd**

Extract waypoint logic, pathfinding.

```gdscript
# NavigationModule.gd - Handles movement and pathfinding
class_name NavigationModule
extends BaseAIComponent

func get_hide_point() -> bool:
    # Extracted GetHidePoint() logic
    for point in nearbyPoints:
        if is_valid_hide_point(point):
            move_to_point(point.global_position)
            return true
    return false

func move_to_point(position: Vector3):
    agent.target_position = position
    agent.is_target_reached()  # Trigger movement
```

**Step 2: Integrate into AI.gd**

Use NavigationModule in state methods like GetHidePoint().

**Step 3: Test navigation**

Verify waypoint selection works.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/components/NavigationModule.gd RoadToVostokEnemyAI/AI.gd
git commit -m "feat: extract NavigationModule component"
```

### Task 6: Create SquadModule (New Feature)

**Files:**
- Create: `RoadToVostokEnemyAI/components/SquadModule.gd`
- Modify: `RoadToVostokEnemyAI/AI.gd` (add squad logic)

**Step 1: Write SquadModule.gd**

Implement basic squad communication.

```gdscript
# SquadModule.gd - Handles squad coordination
class_name SquadModule
extends BaseAIComponent

signal squad_message(type: String, data: Dictionary)

var squad_id = ""
var squad_role = "member"

func join_squad(id: String):
    squad_id = id
    emit_signal("squad_message", "join", {"id": id})

func send_message(type: String, data: Dictionary):
    emit_signal("squad_message", type, data)
```

**Step 2: Integrate into AI.gd**

Attach SquadModule, connect to communication.

**Step 3: Test squad basics**

Verify message sending.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/components/SquadModule.gd RoadToVostokEnemyAI/AI.gd
git commit -m "feat: add SquadModule for cooperative behaviors"
```

### Task 7: Implement StateMachine

**Files:**
- Create: `RoadToVostokEnemyAI/components/StateMachine.gd`
- Modify: `RoadToVostokEnemyAI/AI.gd` (replace state logic)

**Step 1: Write StateMachine.gd**

Simple state machine for behaviors.

```gdscript
# StateMachine.gd - Manages AI behavior states
class_name StateMachine
extends BaseAIComponent

enum State { Idle, Combat, Hide, Hunt }

var current_state = State.Idle

func change_state(new_state: State):
    current_state = new_state
    # Call appropriate methods based on state
    match current_state:
        State.Combat: ai_root.Decision()
        State.Hide: ai_root.GetHidePoint()
```

**Step 2: Integrate into AI.gd**

Use StateMachine for state changes.

**Step 3: Test state machine**

Verify state transitions work.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/components/StateMachine.gd RoadToVostokEnemyAI/AI.gd
git commit -m "feat: implement StateMachine component"
```

### Task 8: Add Personality Variations

**Files:**
- Modify: `RoadToVostokEnemyAI/EnemyAISettings.gd` (add personality configs)
- Modify: `RoadToVostokEnemyAI/AI.gd` (apply personality multipliers)

**Step 1: Add personality settings**

Extend EnemyAISettings with personality profiles.

```gdscript
# In EnemyAISettings.gd
export var personality_profiles = {
    "aggressive": {"fire_rate": 1.5, "accuracy": 0.8},
    "defensive": {"fire_rate": 0.7, "accuracy": 1.2}
}
```

**Step 2: Apply in AI.gd**

Load personality based on faction/type.

**Step 3: Test variations**

Verify different behaviors.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/EnemyAISettings.gd RoadToVostokEnemyAI/AI.gd
git commit -m "feat: add personality variation system"
```

### Task 9: Performance Optimizations

**Files:**
- Modify: `RoadToVostokEnemyAI/components/SensoryModule.gd` (add caching)
- Modify: `RoadToVostokEnemyAI/components/TargetingModule.gd` (add spatial partitioning)

**Step 1: Add caching to SensoryModule**

Cache raycast results for performance.

**Step 2: Add spatial queries to TargetingModule**

Use area queries instead of looping all agents.

**Step 3: Test performance**

Monitor frame rates with multiple agents.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/components/
git commit -m "feat: add performance optimizations"
```

### Task 10: Debug Tools Integration

**Files:**
- Create: `RoadToVostokEnemyAI/components/DebugOverlay.gd`
- Modify: `RoadToVostokEnemyAI/Main.gd` (attach debug overlay)

**Step 1: Write DebugOverlay.gd**

Visual debug indicators.

```gdscript
# DebugOverlay.gd - Debug visualization
class_name DebugOverlay
extends Node3D

func _draw():
    if current_target:
        draw_line(global_position, current_target.global_position, Color.RED)
```

**Step 2: Integrate into Main.gd**

Attach to AI nodes when debug enabled.

**Step 3: Test debug tools**

Verify visual indicators work.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/components/DebugOverlay.gd RoadToVostokEnemyAI/Main.gd
git commit -m "feat: add debug tools component"
```

### Task 11: Final Integration and Testing

**Files:**
- Modify: `RoadToVostokEnemyAI/AI.gd` (ensure all components work together)
- Test: Run full game tests

**Step 1: Verify all components integrated**

Check that AI.gd uses all modules correctly.

**Step 2: Run comprehensive tests**

Test spawning, combat, squads, etc.

**Step 3: Performance benchmark**

Ensure no regressions.

**Step 4: Commit**

```bash
git add RoadToVostokEnemyAI/
git commit -m "feat: complete AI rearchitecture integration"
```