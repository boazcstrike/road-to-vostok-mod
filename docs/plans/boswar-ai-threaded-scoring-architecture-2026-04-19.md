# BosWar AI Threaded Scoring Architecture (Sketch)

## Problem Statement
- Current lag spikes are short main-thread bursts during combat perception and reaction.
- The hotspots are synchronous LOS checks, target scan loops, and teammate communication-driven decision churn.
- Goal is to reduce frame-time spikes without breaking deterministic gameplay behavior.

## Design Goals
1. Keep gameplay authority on main thread.
2. Offload only pure compute work to worker threads.
3. Bound per-frame AI work with explicit budgets.
4. Preserve current behavior envelope (no major tactical redesign).

## Non-Goals
- No threaded `Node` mutation.
- No threaded physics/world queries.
- No direct worker-thread access to live scene objects.

## Threading Model
- Main thread remains authoritative for:
  - AI state transitions
  - LOS/raycast checks
  - movement/animation/nav updates
  - teammate message apply/switch
- Worker threads handle:
  - candidate scoring/ranking over immutable snapshots
  - tactical weighting calculations (distance, quality, team pressure, hysteresis factor)
  - optional aggregation (top-k target shortlist)

## Core Pattern
### 1) Snapshot (Main Thread)
- At AI update tick, build lightweight immutable snapshot:
  - `self`: position, forward, team/faction, current target id, quality
  - `candidates`: ids + cached positions + tags (alive/paused/hostile precomputed)
  - settings multipliers and tactical flags
- Do not include raw `Node` references in worker payload.

### 2) Score Job (Worker Thread)
- Input: snapshot struct + frame stamp.
- Output:
  - ranked candidate ids with scores
  - reasoning flags (`requires_los`, `priority_seen_heard_25m`, `retain_current`)
- Worker performs no scene reads and no physics calls.

### 3) Validate + Commit (Main Thread)
- Consume latest completed job (drop stale frame-stamp results).
- For top-N (small N) candidates only, run LOS/visibility checks.
- Apply existing target lock/hysteresis/quality rules.
- Commit state changes (`currentAITarget`, `target_type`, `Decision/ChangeState`) only here.

## Queue + Scheduling Contract
- Per-AI single in-flight job max.
- If previous job not done, skip submission this tick.
- Use staggered cohorts (e.g. `ai_id % 4`) so only a fraction of AIs submit per frame.
- Hard budgets:
  - max LOS validations per AI tick
  - max teammate reaction commits per frame (overflow deferred one frame)

## Teammate Comms Integration
- Keep broadcast as event enqueue, not immediate heavy reaction.
- On receive:
  - dedupe by `(target_id, quality, position bucket, timestamp window)`
  - push to small ring buffer
- Apply queue during AI behavior tick with per-frame cap.

## Safety Invariants
1. Worker job must be pure and side-effect free.
2. Main thread owns all authoritative state writes.
3. Stale worker results are discarded.
4. Any candidate id from worker must be revalidated as live/hostile on commit.

## Observability
- Add counters (debug/perf mode):
  - jobs submitted/completed/dropped-stale
  - LOS checks per second
  - teammate events enqueued/applied/deduped
  - per-frame AI commit count
- Track p50/p95 frame time and worst-frame spikes during detection-heavy scenarios.

## Rollout Plan
1. Phase 0: Main-thread shaping only (already aligned with current fixes)
   - dedupe comms
   - reduce redundant visibility calls
   - prefilter scan candidates before LOS
2. Phase 1: Worker-based scoring prototype
   - single AI cohort
   - no gameplay commit changes yet (shadow mode compare only)
3. Phase 2: Authoritative commit from worker shortlist
   - top-N LOS validation on main thread
   - stale-result dropping and fail-safe fallback to existing path
4. Phase 3: Enable by default with guardrails and perf telemetry

## Acceptance Criteria
1. No cross-thread scene access warnings/errors.
2. No gameplay regressions in target lock/priority behavior.
3. Reduced frame spikes in 2-8 AI detection scenarios (p95 frame time improvement).
4. Stable behavior under stress (no queue runaway, no stale-target commits).

## Risks and Mitigations
- Risk: nondeterministic behavior from async timing.
  - Mitigation: frame stamps + stale-drop + authoritative revalidation.
- Risk: extra complexity with little gain if LOS remains dominant.
  - Mitigation: keep LOS budgeting and prefiltering first; thread only score stage.
- Risk: hidden allocations in snapshot serialization.
  - Mitigation: pooled snapshot structs/arrays, fixed-size buffers where practical.

## Practical Recommendation
- Treat multithreading as phase 2 optimization, not first-line fix.
- First-line fixes are burst flattening and budget enforcement on main thread.
- If profiling still shows score math as significant, then move scoring to workers using this contract.
