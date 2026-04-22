# 06 - AI Architecture

## Core architecture
- **AI controller**: state machine, sensing, targeting, combat behaviors
- **Spawner**: population scaling, pool replenishment, performance-aware counts
- **Settings resource**: presets/multipliers/faction flags

## Behavioral states (examples)
Wander, Guard, Patrol, Combat, Hide, Cover, Vantage, Hunt, Attack, Shift, Return, Ambush.

## Key design patterns
- **State pattern** for behavior transitions.
- **Observer pattern** for debug/status reporting.
- **Strategy pattern** for preset-driven tuning.

## Performance expectations
- Distance/population-aware update cycles.
- Targeting hysteresis to reduce rapid switching.
- Pool-based lifecycle and cleanup.

## Faction/targeting model
- Team-vs-team hostility is primary when both AIs have valid `team_id` and IDs differ.
- Team-based hostility is the rule for AI-vs-AI engagement decisions.
- Inter-faction warfare remains controlled by supported-faction checks.
- Player target priority and audio-triggered acquisition supported.

## Validation and debug
- Centralized debug logs and optional rate-limited logging paths.
- Defensive instance/method checks with fallback behavior.
