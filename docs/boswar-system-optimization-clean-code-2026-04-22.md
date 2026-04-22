# BosWar System Optimization and Clean Code Task Context (2026-04-22)

## Scope
- Audit BosWar runtime systems for necessary performance and clean-code adjustments.
- Implement only high-impact, low-risk, surgical optimizations.
- Use multi-agent orchestration with disjoint file ownership.

## Assumptions
- Existing local modifications in `BosWar/AI.gd`, `BosWar/AISpawner.gd`, and `BosWar/EnemyAISettings.gd` are intentional and must be preserved.
- Runtime behavior should remain functionally equivalent unless a change is required to remove avoidable overhead.
- This pass targets BosWar systems only (`BosWar/`), with `Road to Vostok/` treated as read-only reference.

## Success Criteria
1. Hot-path logic in at least two BosWar runtime scripts is simplified or optimized without broad refactor.
2. Every changed line maps directly to optimization or clean-code goals in this task.
3. A final report is produced with approach, implementation details, verification notes, and recommendations.

## Verification Plan
1. Audit current hotspots -> Verify: concrete line-level targets identified in `AI.gd` and `AISpawner.gd`.
2. Implement minimal changes -> Verify: edits remain inside explicit file ownership boundaries.
3. Validate integrity -> Verify: no obviously orphaned symbols/imports introduced by this pass.
4. Report outcomes -> Verify: report includes plan, implementation, approach, risks, and next recommendations.

## Task Decomposition (Multi-Agent)
- Agent A: `BosWar/AI.gd` hot-path review and optimization proposals.
- Agent B: `BosWar/AISpawner.gd` spawn/cache/path review and optimization proposals.
- Agent C: implementation support for one disjoint file after proposals are accepted.

## Progress Log
- 2026-04-22: Task file created. Baseline repo state and memory context reviewed.
