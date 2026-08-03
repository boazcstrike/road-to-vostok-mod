# Full-Auto Aiming Correction Context (2026-04-22)

## Problem
- During full-auto fire, AI aim appears to drift upward ("spraying the sky") instead of staying aligned to the active target.
- Requested behavior: AI should keep aiming at the target (player and hostile AI), while still missing slightly due to spread/inaccuracy.
- Current symptom suggests misses are being introduced by aim-anchor drift, not by controlled shot spread around the target line.

## Assumptions
- Scope is limited to BosWar full-auto aiming/fire behavior (no unrelated combat refactors).
- Single-shot and non-full-auto behavior should remain unchanged unless they share the same broken helper.
- Miss behavior should come from spread/dispersion around a target-centered aim vector, not from lifting the aim point into the sky.
- "Miss a little bit" means near-target misses that still look like suppression, not large vertical overshoot.
- `Road to Vostok/` remains read-only and out of scope.

## Minimal Solution
1. Keep the full-auto aim anchor locked to the current valid target point (player center-mass or hostile AI center-mass).
2. Apply inaccuracy at shot-direction generation (or final hit sample), not by offsetting the base aim anchor.
3. Use symmetric spread around the target vector with bounded vertical deviation so misses are nearby, not strongly up-biased.
4. Reuse the same full-auto spread path for player-target and AI-vs-AI targeting to prevent split behavior.

## Tradeoffs
- Tighter vertical bounds reduce sky-spray risk but can make AI feel too accurate if horizontal spread is not tuned.
- Higher spread increases believable misses but can make DPS too low or feel random/unfair.
- A single shared spread helper improves consistency across target types, but any tuning change affects both player-facing and AI-vs-AI outcomes.
- Keeping this minimal avoids wider weapon-system redesign, but leaves deeper recoil-model improvements for a separate task.

## Runtime Verification Checklist

### Player Target (Full-Auto)
- [ ] Scenario: hostile AI full-auto at player (10-25m, clear LOS).
  - Verify: muzzle/upper-body aim remains target-centered; no persistent upward sky aiming.
- [ ] Scenario: same encounter with player moving laterally.
  - Verify: shot pattern is centered around player path with small misses, not a vertical-only miss pattern.
- [ ] Scenario: sustained full-auto (3-5 seconds).
  - Verify: misses distribute around target (left/right/up/down), with no cumulative upward drift over burst duration.

### AI-vs-AI Target (Full-Auto)
- [ ] Scenario: two hostile factions engage at 10-30m.
  - Verify: both sides keep aim on opposing AI bodies; no "aim at sky" behavior while firing full-auto.
- [ ] Scenario: moving AI-vs-AI engagement with partial cover transitions.
  - Verify: aim remains tied to visible hostile target position; near misses occur but remain target-adjacent.
- [ ] Scenario: repeated engagements across several fights.
  - Verify: behavior is consistent across factions/weapons using full-auto, with no target-type-specific upward bias.

## Pass Criteria
- Full-auto aim visually tracks the intended target for both player-target and AI-vs-AI cases.
- Misses increase via controlled spread, not by raising the aim line above target height.
- No new regressions observed in non-full-auto engagements.
