# Observability and Debugging

## Purpose
Owns debug logging, event emission, and runtime overlay metrics presentation.

## Owned By
`BosWar/DebugUtils.gd`, debug overlay portions of `BosWar/Main.gd`

## Boundaries
- In scope: Debug telemetry rendering and log utilities.
- Out of scope: Spawn/AI business logic and settings persistence implementation.
- Note: This domain consumes runtime settings toggles (`show_debug_logs`, `show_debug_overlay`) but does not own persistence.

## Interfaces
- Inputs: Status and event callbacks from AI, spawner, and bootstrap domains.
- Outputs: Console logs and runtime debug overlay.

## Operating Protocol
- Follow `logging-protocol.md` for required logging behavior and compliance checks.
- Treat `BosWar/DebugUtils.gd` as the sole debug log emission utility for Bo's War runtime scripts.

## Dependencies
- Upstream: AI and spawner event publishers.
- Downstream: Developer troubleshooting workflows.

## Change Process
1. Create an RFC for cross-domain contract changes.
2. Record accepted architecture choices in ADRs.
3. Update `system-map.md` for any boundary change.
