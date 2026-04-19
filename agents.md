# Bo's War Enemy AI Agents Guide

This file is the **operational contract** for work in this repo.

## Document Priority
1. `agents.md` (this file) = source of truth for mandatory behavior.
2. `docs/context/README.md` and `docs/context/agents/*.md` = granular summaries/reference.
3. If any conflict exists, follow `agents.md`.

## Repo Structure (Critical)
- Main mod project: `BosWar/`
- Docs, plans, task context files: `docs/`
- Reference mods: `mods/`
- Extracted reference scripts: `Reference Scripts/`
- Base game code snapshot: `Road to Vostok/`
- Shader work: `realistic shaders/`

### Non-Negotiable Guardrail
**Never edit files in `./Road to Vostok/`.** Use them as read-only reference only.

## Required Workflow (Every Task)
For every feature, bugfix, refactor, or investigation:
1. Create/update a task context file in `docs/` (example: `docs/<task-name>.md`).
2. Track assumptions, design decisions, tradeoffs, anti-patterns, and outcomes.
3. Update that file incrementally as work progresses.
4. Cross-reference related context files when tasks overlap.

## GDScript Standards (Quick Rules)
- Naming:
  - Variables/functions: `snake_case`
  - Booleans: `is_`, `has_`, `can_`, `should_`
  - Private members/methods: `_prefix`
  - Constants: `SCREAMING_SNAKE_CASE`
  - Classes/resources: `PascalCase`
- Formatting: 4 spaces, max 120 chars per line, one statement per line, spaced operators.
- Documentation: public functions require docstrings; comment complex logic.
- Error handling: validate public inputs, assert critical assumptions, degrade gracefully for optional systems.

## Architecture Expectations (Quick Rules)
- `AI.gd`: state machine + sensing + decision logic.
- `AISpawner.gd`: spawn pools + scaling + replenishment.
- `EnemyAISettings.gd`: presets/multipliers/faction toggles.
- Use state/observer/strategy patterns where appropriate.
- Use performance-aware updates (distance/agent-count scaling, hysteresis, pooling).
- Keep faction behavior configurable (infighting + warfare gating + player targeting priority).

## Detailed References
Use these for granular guidance/examples:
- `docs/context/README.md`
- `docs/context/agents/01-overview-and-structure.md`
- `docs/context/agents/02-workflow-and-documentation.md`
- `docs/context/agents/03-execution-principles.md`
- `docs/context/agents/04-gdscript-standards.md`
- `docs/context/agents/05-project-structuring.md`
- `docs/context/agents/06-ai-architecture.md`
