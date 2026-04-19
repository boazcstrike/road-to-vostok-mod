# system-map-runtime-bootstrap-and-compat

## Scope
Runtime Bootstrap and Compatibility

## Owned Responsibilities
- Initialize runtime script overrides.
- Schedule and apply compatibility patches.
- Maintain debug root availability.

## Dependencies In
- Base script resources.
- MCM compatibility targets.
- Shared settings resource.

## Dependencies Out
- Patched runtime scripts.
- Debug and status context for other domains.

## Boundary Contracts
- Exposes runtime environment that all other domains depend on.

## Known Risks
- Runtime patch ordering failures can break downstream behavior.

