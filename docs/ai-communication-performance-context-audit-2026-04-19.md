# AI Communication Performance Context Audit (2026-04-19)

## Scope
- Audit `docs/context` guidance for constraints on AI communication/performance optimization proposals.

## Assumptions
- `docs/context/README.md` declares `agents.md` as source of truth.
- This pass extracts constraints only; no gameplay/script behavior changes are implemented.

## Constraints Captured
- Preserve role ownership (`AI.gd` behavior/state, `AISpawner.gd` population, `EnemyAISettings.gd` tuning resource).
- Keep optimization controls in settings resources and separate from behavior logic.
- Respect performance model requirements: distance/population-aware update cadence, targeting hysteresis, pool lifecycle cleanup.
- Keep observability centralized and optionally rate-limited.
- Keep changes minimal/surgical; avoid speculative abstractions.

## Outcome
- Constraints are ready to gate subsequent optimization proposals for threading/queueing/communication paths.
