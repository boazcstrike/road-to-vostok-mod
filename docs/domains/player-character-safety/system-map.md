# system-map-player-character-safety

## Scope
Player Character Safety

## Owned Responsibilities
- Gate character damage pathways when protection is enabled.
- Keep core player survival stats in protected range during spectator mode.

## Dependencies In
- Shared settings values.
- Base character behavior hooks.

## Dependencies Out
- Effective player damage behavior at runtime.

## Boundary Contracts
- Reads settings flags only; does not own settings persistence.

## Known Risks
- Partial overrides can leave gaps in uncommon damage pathways.

