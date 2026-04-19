# system-map-observability-and-debugging

## Scope
Observability and Debugging

## Owned Responsibilities
- Normalize debug logging output.
- Render aggregate runtime overlay status.

## Dependencies In
- Domain events from bootstrap, spawner, and AI.
- Shared settings flags for visibility controls.

## Dependencies Out
- Human-readable logs and live status output.

## Boundary Contracts
- Consumes published metrics; should not mutate business logic state.
- All Bo's War debug logs must be emitted through `BosWar/DebugUtils.gd`.
- Runtime scripts in `BosWar/` must not emit direct debug prints outside `DebugUtils`.
- Protocol reference: `logging-protocol.md`.

## Known Risks
- Logging noise can impact readability during high-activity sessions.
