# system-map-ai-decision-and-targeting

## Scope
AI Decision and Targeting

## Owned Responsibilities
- Acquire and prioritize targets.
- Drive behavior state machine transitions.
- Execute attack and damage application flow.

## Dependencies In
- Active agents from spawner.
- Runtime settings from configuration.
- World and sensor data.

## Dependencies Out
- Combat and state events.
- Target telemetry and status data.

## Boundary Contracts
- Consumes only published settings and active entity context.
- Applies hostility in layers: team ID hostility first, faction hostility fallback second.

## Known Risks
- Cross-domain coupling through globals or metadata keys can drift over time.
