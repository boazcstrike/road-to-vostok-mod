# 07 - Godot Community Standards

Supplemental community conventions. If anything conflicts with `agents.md`, follow `agents.md`.

## File and folder structure
- Prefer feature-oriented grouping over type-only grouping.
- Keep related scene/script/resource close together when ownership is clear.
- Use one primary class per script file.
- Keep autoloads minimal and cross-cutting only (save/global events/config access).
- Separate runtime tuning data (`.tres`) from behavior scripts.

## Scene and script boundaries
- Treat scenes as composition roots; keep scripts focused on one responsibility.
- Avoid deep inheritance chains when composition can solve the problem.
- Keep node-lifecycle methods (`_ready`, `_process`, `_physics_process`) thin and orchestration-focused.
- Move reusable decision logic to helper methods/resources instead of duplicating across states.

## Logic architecture conventions
- Use explicit state transitions for AI/agent behavior.
- Prefer signal-driven coordination over hard-coded node-path coupling.
- Avoid direct traversal chains (`../../..`) in gameplay logic; use references or signals.
- Keep dependency direction simple: settings/data -> logic -> presentation/debug.

## Performance conventions
- Avoid per-frame allocations in hot paths.
- Prefer squared-distance checks for threshold comparisons.
- Cache stable references and precomputed lookups when repeatedly queried.
- Throttle expensive checks (LOS/raycast/scans) with timers/budgets where behavior allows.
- Use pooling/reuse for high-churn entities.

## Configuration and tuning
- Keep balancing/tuning in Resources (`EnemyAISettings`-style) rather than hardcoding.
- Document expected ranges and defaults for key tuning values.
- Keep runtime defaults consistent across bootstrap and gameplay systems.

## Reliability and observability
- Validate public inputs and guard optional dependencies.
- Keep debug logging structured and rate-limited on hot paths.
- Gate heavy debug-only audits behind explicit debug flags.

## Clean-code expectations
- Prefer short, purpose-driven functions over large mixed-responsibility blocks.
- Name by intent (`_has_*`, `_is_*`, `_can_*`) for boolean methods.
- Remove temporary variables/imports introduced by changes if no longer used.
- Avoid opportunistic refactors outside the requested scope.

## Review checklist
1. Is each modified function still single-purpose?
2. Are hot-path loops free of avoidable allocations/sqrt calls?
3. Are dependencies explicit (signals/refs) instead of fragile tree-path traversal?
4. Are tuning values in Resources instead of hardcoded literals?
5. Are debug-heavy operations gated when debug output is disabled?
