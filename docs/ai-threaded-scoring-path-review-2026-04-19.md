# AI Threaded Scoring Path Review (2026-04-19)

## Scope
- File: `BosWar/AI.gd`
- Functions reviewed:
  - `_submit_shadow_scoring_job_if_due()` (dispatch equivalent)
  - `_shadow_scoring_worker()`
  - `_consume_shadow_scoring_result()` (poll equivalent)
  - `_clear_shadow_scoring_runtime_state()` / `_on_tree_exited_shadow_scoring_cleanup()`

## Assumptions
- User's requested names map to current symbols:
  - `_dispatch_shadow_scoring_if_due` -> `_submit_shadow_scoring_job_if_due`
  - `_poll_shadow_scoring_result` -> `_consume_shadow_scoring_result`
- Goal is performance optimization with minimal behavior change.

## Findings (Performance/Concurrency)

1. **High thread lifecycle overhead per scoring job**
   - Evidence:
     - New thread created per dispatch: `BosWar/AI.gd:891`
     - Started immediately: `BosWar/AI.gd:892`
     - Joined per result: `BosWar/AI.gd:913`
   - Impact:
     - Thread create/start/join overhead can dominate when candidate count is small/moderate.
     - With many AIs, this pattern amplifies scheduler churn.

2. **Main-thread blocking risk on cleanup paths**
   - Evidence:
     - Dead/pause path waits synchronously: `BosWar/AI.gd:806`, `BosWar/AI.gd:1112`
     - Tree-exit cleanup always waits: `BosWar/AI.gd:1129`
   - Impact:
     - `wait_to_finish()` can stall the frame when transitions happen under load (death/pause/despawn bursts).

3. **No bounded queueing; many AIs can dispatch in same frame cohort**
   - Evidence:
     - Cohort gating exists: `BosWar/AI.gd:880-885`
     - But each eligible AI still creates its own thread (`BosWar/AI.gd:891`)
   - Impact:
     - Cohorts spread work across frames but do not cap concurrent worker count globally.
     - Contention risk scales with AI count.

4. **Payload build is unbounded over hostile set before threading**
   - Evidence:
     - Iterates all agent children: `BosWar/AI.gd:951`
     - Appends candidate dictionary per valid hostile: `BosWar/AI.gd:958`
     - `top_k` only affects output slice in worker: `BosWar/AI.gd:982`, `BosWar/AI.gd:1044-1045`
   - Impact:
     - Large allocation/copy cost happens on main thread before worker starts.
     - Worker still loops all candidates even if only top few are needed.

## Minimal-Change Optimization Sketch

### A) Add adaptive inline fallback for small payloads
- Rationale: Avoid thread lifecycle cost when candidate count is low.
- Minimal change:
  - In `_submit_shadow_scoring_job_if_due()`, after payload build:
    - `var candidate_count = payload.get("candidates", []).size()`
    - If below threshold (new setting, e.g. `threaded_scoring_min_candidates_for_thread = 10`), run `_shadow_scoring_worker(payload)` directly and consume result path without creating thread.
- Expected effect:
  - Removes create/start/join overhead on cheap jobs.

### B) Add global in-flight budget gate (soft queueing)
- Rationale: Limit simultaneous worker launches across all AIs without redesign.
- Minimal change:
  - Add static/global counters in `AI.gd`:
    - `static var _global_shadow_jobs_in_flight = 0`
    - `const MAX_GLOBAL_SHADOW_JOBS = 4` (or settings-backed)
  - Before thread start, if budget reached, skip this frame.
  - Increment on successful start; decrement when consumed/cleared.
- Expected effect:
  - Caps contention and scheduler pressure while preserving current logic.

### C) Bound candidate payload before worker
- Rationale: Reduce main-thread allocations and worker loop size.
- Minimal change:
  - Add candidate cap setting (e.g. `threaded_scoring_candidate_cap = 24`).
  - In `_build_shadow_scoring_payload()`, stop appending once cap reached.
  - Keep deterministic ordering by distance-first prefilter if needed.
- Expected effect:
  - Predictable per-frame cost for scoring prep and worker execution.

### D) Avoid blocking wait on non-critical runtime clear
- Rationale: Prevent frame hitch during dead/pause transitions.
- Minimal change:
  - Keep tree-exit hard wait (`_on_tree_exited_shadow_scoring_cleanup()`).
  - For runtime dead/pause path (`BosWar/AI.gd:806`), switch to non-blocking clear and let result be dropped when polled.
- Expected effect:
  - Reduces worst-case stutter during mass state transitions.

## Verification Plan (Binary)
1. Add inline fallback threshold -> Verify: no thread created when candidate count < threshold.
2. Add global in-flight budget -> Verify: concurrent shadow jobs never exceed cap.
3. Add candidate cap -> Verify: payload candidate length never exceeds cap.
4. Adjust runtime clear wait behavior -> Verify: no `wait_to_finish()` call on dead/pause path, but still called on tree exit.

