# system-map-configuration-and-settings

## Scope
Configuration and Settings

## Owned Responsibilities
- Define setting schema and defaults.
- Load, migrate, and persist configuration.
- Publish runtime settings resource values.

## Dependencies In
- MCM helper APIs.
- User config files.

## Dependencies Out
- Shared runtime settings consumed by all core domains.

## Boundary Contracts
- Changes to setting keys are contract changes requiring RFC and map updates.

## Known Risks
- Schema drift between config definitions and runtime consumption.

