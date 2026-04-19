# Debug Logging Protocol

## Purpose
Define mandatory rules for debug log emission in Bo's War runtime code.

## Required Rules
1. Emit raw Bo's War debug log lines via `DebugUtils` wrappers:
- `DebugUtils._debug_log(message)` for standard debug logs.
- `DebugUtils._debug_log_ai_audio(key, message)` for high-frequency audio diagnostics.
2. Do not call `print(...)`, `printerr(...)`, `push_error(...)`, or `push_warning(...)` directly in `BosWar/*.gd` runtime scripts.
3. Keep log messages concise and operationally useful:
- Include actor/system context (`AI`, `Spawner`, `Config`, etc.).
- Include key IDs/values for diagnostics (faction, team id, counts, distances, reason codes).
4. Respect runtime toggles:
- `show_debug_logs` controls whether debug lines are emitted.
- `show_debug_overlay` controls whether overlay text is visible.
5. Use `Main.gd` overlay metric/event methods (`begin_map`, `record_spawn`, `update_status`, `record_hit`, `record_suspicious_spawn`) for structured HUD telemetry.

## Approved Logging Paths
- `DebugUtils._debug_log(...)`
- `DebugUtils._debug_log_ai_audio(...)`
- `Main.gd` overlay metric/event methods for HUD telemetry only

## Compliance Check
Use this check after changes touching runtime logs:

```powershell
Get-ChildItem -Recurse -File BosWar | Select-String -Pattern '\bprint\s*\(|\bprinterr\s*\(|\bpush_error\s*\(|\bpush_warning\s*\('
```

Expected result: direct calls only in `BosWar/DebugUtils.gd`.
