# Target acquire log throttle (2026-04-19)

## Scope
- Reduce repetitive target-acquisition spam in runtime logs.
- Keep acquisition visibility, but emit less frequently.

## Change
- In `BosWar/AI.gd`, switched these logs from `_debug_log(...)` to `_debug_log_rate_limited(...)`:
  - `Hostile target acquired: ...`
  - `AI ... Acquired AI ... target ...`
- Used shared keys with `1.0s` cooldown to reduce burst repetition across agents.

## Verification
1. Confirm both calls now use rate-limited logger.
2. Runtime check: acquisition logs still appear, but no longer spam every frame/tick burst.
