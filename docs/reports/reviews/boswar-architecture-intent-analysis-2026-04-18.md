# BosWar Architectural Intent Analysis (2026-04-18)

## Task
Analyze architectural intent, module boundaries, and dependency management for:
- `BosWar/AI.gd`
- `BosWar/AISpawner.gd`
- `BosWar/Main.gd`
- `BosWar/Config.gd`
- `BosWar/EnemyAISettings.gd`

No source code edits requested.

## Assumptions
- `Road to Vostok/` remains read-only reference and was not modified.
- Base scripts under `res://Scripts/*.gd` are external contracts that BosWar overrides.
- `EnemyAISettings.tres` is intentionally used as shared mutable runtime settings.

## Observed Architectural Intent
- Runtime patch/bootstrap entrypoint in `Main.gd` takes over base scripts and applies MCM compatibility patching.
- `Config.gd` acts as MCM schema + persistence adapter writing values to `EnemyAISettings.tres`.
- `EnemyAISettings.gd` is a central configuration resource.
- `AISpawner.gd` manages pool creation, spawn cadence, team spawning, and spawn audit telemetry.
- `AI.gd` handles per-agent sensing/decision/combat and faction targeting behaviors.

## Key Findings (Summary)
1. Clear functional partition exists, but modules are coupled by runtime globals (`/root/EnemyAIMain`), mutable shared resource, and string metadata contracts.
2. AI domain and spawning domain are partially entangled (AI mutates spawner counters and replenishment directly).
3. Config-to-settings mapping is explicit but highly duplicated, creating drift risk.
4. Dependency management relies heavily on dynamic runtime behaviors (`take_over_path`, `set_meta/get_meta`) and weakly typed interfaces.
5. Performance-aware behaviors are present (refresh cycles by active count, team spawning controls), indicating intentional scalability concerns.

## Anti-Patterns / Risks Logged
- Stringly-typed cross-module contracts (meta keys, target type strings, faction literals).
- Domain logic coupled to debug overlay plumbing and node path lookup.
- Runtime monkey-patching of external scripts as a hard dependency path.
- Potential weighting intent loss in faction pool due deduplication after weighted append.

## Outcome
- Produced evidence-backed architectural review with strengths, boundary violations, and top recommendations.
- No code changes were made under `BosWar/` source files.
