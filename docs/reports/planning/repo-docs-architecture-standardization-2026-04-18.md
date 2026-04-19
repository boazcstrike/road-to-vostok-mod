# repo-docs-architecture-standardization-2026-04-18

## Task
Create a standardized documentation hierarchy and templated domain skeletons based on current repository architecture.

## Date
2026-04-18

## Scope
- Analyze repository structure and identify core architectural domains and service boundaries.
- Approve and implement a standardized markdown hierarchy (ADRs, RFCs, System Maps).
- Standardize naming conventions and templates for future updates.
- Create domain skeleton files for each identified core domain.

## Assumptions
- User approval for the standardized hierarchy is explicit in the request.
- Existing `docs/` content remains valid and should not be moved in this task.
- `Road to Vostok/` is read-only reference and must not be edited.

## Identified Core Domains
1. Runtime Bootstrap and Compatibility
2. AI Decision and Targeting
3. Spawn Orchestration and Population
4. Configuration and Settings
5. Player Character Safety
6. Observability and Debugging

## Service Boundary Notes
- `Main.gd` owns runtime override/bootstrap and mod compatibility patching.
- `AI.gd` owns per-agent sensing, target selection, and combat behavior decisions.
- `AISpawner.gd` owns pool lifecycle, spawn cadence, and team spawn orchestration.
- `Config.gd` and `EnemyAISettings.*` own configuration schema and runtime settings distribution.
- `Character.gd` owns player-protection behavior overrides.
- `DebugUtils.gd` plus `Main.gd` overlay logic own observability surface.

## Tradeoffs
- Added parallel domain docs instead of restructuring existing docs files to reduce migration risk.
- Introduced index files for each architecture artifact type to reduce search overhead.

## Progress Log
- Completed repository scan and domain extraction from `BosWar/*.gd`.
- Created standardized docs hierarchy and templates.
- Created domain skeleton files with prefilled boundaries.

## Outcome
- New structure is in place under `docs/` for ADR/RFC/System Map workflows.
- Domain-level skeleton files are ready for incremental updates.
- Existing docs preserved without disruptive reorganization.

## Cross-References
- `docs/context/README.md`
- `docs/reports/reviews/boswar-architecture-intent-analysis-2026-04-18.md`
- `docs/reports/reviews/codebase-architecture-review-2026-04-18.md`
