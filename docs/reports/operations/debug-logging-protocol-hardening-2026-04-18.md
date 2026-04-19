# debug-logging-protocol-hardening-2026-04-18

## Task
Ensure the Bo's War debug logging system is properly documented as instructions and ensure code paths follow the debug logging protocol.

## Date
2026-04-18

## Scope
- `BosWar/DebugUtils.gd`
- `BosWar/EnemyAISettings.gd`
- `BosWar/Config.gd`
- `docs/domains/observability-and-debugging/*`

## Assumptions
- Bo's War debug output should be centralized through `DebugUtils._debug_log(...)`.
- `show_debug_logs` is the intended runtime control for enabling/disabling debug log emission.
- Runtime overlay visibility (`show_debug_overlay`) and log emission (`show_debug_logs`) are separate controls.

## Design Decisions
1. Treat `DebugUtils._debug_log(...)` as the only approved entrypoint for debug log lines.
2. Make `show_debug_logs` explicit and configurable in both resource schema and MCM config flow.
3. Document the protocol in domain docs so future changes have a single policy reference.

## Tradeoffs
- Disabling `show_debug_logs` now suppresses all debug log lines, including low-priority migration/info lines.
- Enforcing a single logging path slightly increases coupling to `DebugUtils` but improves consistency and auditability.

## Anti-Patterns Tracked
- Direct `print(...)` in `BosWar/Config.gd` bypassing `DebugUtils`.
- Implicit/undocumented setting (`show_debug_logs`) present in `.tres` without explicit schema/config wiring.

## Changes Made
1. Added `@export var show_debug_logs = true` to `BosWar/EnemyAISettings.gd`.
2. Added MCM config entry for `show_debug_logs` and synced it in `_on_config_updated(...)`.
3. Replaced direct `print(...)` in `_sync_saved_mod_version(...)` with `DebugUtils._debug_log(...)`.
4. Updated `DebugUtils._debug_log(...)` to respect `show_debug_logs` before emitting any debug line.
5. Added `docs/domains/observability-and-debugging/logging-protocol.md`.
6. Updated observability domain docs to reference protocol and boundary expectations.
7. Resolved protocol wording ambiguity:
- Clarified approved paths in `logging-protocol.md` so `DebugUtils` wrappers are the raw log entrypoints and `Main.gd` methods are for structured overlay telemetry.
- Added explicit protocol reference in observability `system-map.md`.
- Clarified settings ownership wording in observability `README.md`.
8. Fixed startup edge case in `BosWar/Config.gd`:
- `_sync_saved_mod_version(...)` now checks config `show_debug_logs` before emitting version-sync debug logs.

## Verification
- Scanned `BosWar/` for direct logging calls (`print`, `printerr`, `push_error`, `push_warning`).
- Confirmed remaining direct `print(...)` is centralized in `BosWar/DebugUtils.gd` only.
- Ran delegated sub-agent audits for runtime-code compliance and docs consistency, then applied their actionable findings.

## Outcome
- Debug logging behavior is now documented with concrete instructions.
- Core settings and config paths are aligned with the protocol.
- Bo's War runtime scripts now route debug logs through a single governed utility.

## Cross-References
- `docs/domains/observability-and-debugging/README.md`
- `docs/domains/observability-and-debugging/system-map.md`
- `docs/domains/observability-and-debugging/logging-protocol.md`
- `docs/reports/reviews/boswar-code-review-2026-04-18.md`
